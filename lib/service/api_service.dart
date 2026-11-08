import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:focus/config/api_config.dart';
import 'package:focus/models/atividade_gps.dart';
import 'package:focus/models/catalogo_exercicio.dart';
import 'package:focus/models/grupo_muscular.dart';
import 'package:focus/models/pagina.dart';
import 'package:focus/models/sessao_treino.dart';
import 'package:focus/models/treino_model.dart';
import 'package:focus/models/usuario.dart';
import 'package:focus/models/visao_geral.dart';
import 'package:focus/service/token_storage.dart';

class ApiException implements Exception {
  final String mensagem;
  final int? statusCode;

  const ApiException(this.mensagem, {this.statusCode});

  @override
  String toString() => mensagem;
}

class ApiService {
  ApiService({Dio? dio, TokenStorage? tokenStorage})
      : _tokens = tokenStorage ?? TokenStorage(),
        _dio = dio ??
            Dio(BaseOptions(
              baseUrl: ApiConfig.baseUrl,
              connectTimeout: ApiConfig.connectTimeout,
              receiveTimeout: ApiConfig.receiveTimeout,
              contentType: Headers.jsonContentType,
              responseType: ResponseType.json,
            )) {
    _dio.interceptors.add(_AuthInterceptor(_tokens, _notificarSessaoEncerrada));
  }

  static ApiService _instance = ApiService();
  static ApiService get instance => _instance;

  /// Troca a instância global (usado nos testes para simular a API).
  @visibleForTesting
  static set instance(ApiService service) => _instance = service;

  final Dio _dio;
  final TokenStorage _tokens;
  Usuario? _usuario;

  /// Chamado quando a API rejeita o token (expirado/revogado). O app usa para voltar ao login.
  VoidCallback? onUnauthorized;

  // Evita disparar onUnauthorized várias vezes quando requisições paralelas recebem 401.
  bool _sessaoEncerrada = false;

  void _notificarSessaoEncerrada() {
    if (_sessaoEncerrada) return;
    _sessaoEncerrada = true;
    _usuario = null;
    onUnauthorized?.call();
  }

  static final _semAuth = Options(extra: {_AuthInterceptor.skipAuthKey: true});

  // --- Conta

  Future<bool> isAuthenticated() async => await _tokens.read() != null;

  Future<void> login(String email, String senha) async {
    final data = await _request<Map<String, dynamic>>(() => _dio.post(
          '/login',
          data: {'email': email, 'password': senha},
          options: _semAuth,
        ));
    await _salvarToken(data);
  }

  Future<void> cadastrar({required String nome, required String email, required String senha}) async {
    final data = await _request<Map<String, dynamic>>(() => _dio.post(
          '/register',
          data: {'name': nome, 'email': email, 'password': senha},
          options: _semAuth,
        ));
    await _salvarToken(data);
  }

  Future<void> _salvarToken(Map<String, dynamic> data) async {
    await _tokens.save(
      data['access_token'] as String,
      Duration(seconds: (data['expires_in'] as num).toInt()),
    );
    _usuario = null;
    _sessaoEncerrada = false;
  }

  Future<void> logout() async {
    _usuario = null;
    await _tokens.clear();
  }

  /// Dados do usuário logado. Fica em cache até o próximo login/logout.
  Future<Usuario> getUsuario() async {
    final emCache = _usuario;
    if (emCache != null) return emCache;
    final data = await _request<Map<String, dynamic>>(() => _dio.get('/me'));
    return _usuario = Usuario.fromJson(data);
  }

  // --- Painel

  Future<VisaoGeral> getVisaoGeral() async {
    final data = await _request<Map<String, dynamic>>(() => _dio.get(
          '/dashboard/overview',
          queryParameters: {'tz_offset_minutes': DateTime.now().timeZoneOffset.inMinutes},
        ));
    return VisaoGeral.fromJson(data);
  }

  // --- Treinos

  Future<Pagina<Treino>> getTreinos({int offset = 0, int limit = ApiConfig.pageSize}) async {
    final data = await _request<Map<String, dynamic>>(() => _dio.get(
          '/workouts',
          queryParameters: {'offset': offset, 'limit': limit},
        ));
    return Pagina.fromJson(data, Treino.fromJson);
  }

  Future<Treino> getTreino(int id) async {
    final data = await _request<Map<String, dynamic>>(() => _dio.get('/workouts/$id'));
    return Treino.fromJson(data);
  }

  Future<Treino> criarTreino(Treino treino) async {
    final data = await _request<Map<String, dynamic>>(
      () => _dio.post('/workouts', data: treino.toJson()),
    );
    return Treino.fromJson(data);
  }

  Future<Treino> atualizarTreino(int id, Treino treino) async {
    final data = await _request<Map<String, dynamic>>(
      () => _dio.put('/workouts/$id', data: treino.toJson()),
    );
    return Treino.fromJson(data);
  }

  Future<void> excluirTreino(int id) => _request<dynamic>(() => _dio.delete('/workouts/$id'));

  // --- Sessões

  Future<SessaoTreino> iniciarSessao(int treinoId) async {
    final data = await _request<Map<String, dynamic>>(() => _dio.post('/workouts/$treinoId/sessions'));
    return SessaoTreino.fromJson(data);
  }

  Future<SessaoTreino?> getSessaoAtiva() async {
    final data = await _request<Map<String, dynamic>?>(() => _dio.get('/sessions/active'));
    return data == null ? null : SessaoTreino.fromJson(data);
  }

  Future<SessaoTreino> finalizarSessao(
    int sessaoId, {
    required double volumeKg,
    required int series,
    GrupoMuscular? ultimoGrupo,
    Map<int, int> seriesPorExercicio = const {},
  }) async {
    final data = await _request<Map<String, dynamic>>(() => _dio.post(
          '/sessions/$sessaoId/finish',
          data: {
            'total_volume_kg': double.parse(volumeKg.toStringAsFixed(2)),
            'total_sets': series,
            'last_muscle_group': ultimoGrupo?.valorApi,
            'completed_sets': [
              for (final MapEntry(:key, :value) in seriesPorExercicio.entries)
                if (value > 0) {'exercise_id': key, 'sets': value},
            ],
          },
        ));
    return SessaoTreino.fromJson(data);
  }

  Future<void> descartarSessao(int sessaoId) => _request<dynamic>(() => _dio.delete('/sessions/$sessaoId'));

  /// Sessões iniciadas no intervalo [inicio, fim), da mais recente para a mais antiga.
  Future<List<SessaoTreino>> getSessoes({DateTime? inicio, DateTime? fim, int limite = 50}) async {
    final data = await _request<List<dynamic>>(() => _dio.get(
          '/sessions',
          queryParameters: {
            'start': ?inicio?.toUtc().toIso8601String(),
            'end': ?fim?.toUtc().toIso8601String(),
            'limit': limite,
          },
        ));
    return data.map((s) => SessaoTreino.fromJson(s as Map<String, dynamic>)).toList();
  }

  Future<List<SessaoTreino>> getSessoesDoDia(DateTime dia) {
    final inicio = DateTime(dia.year, dia.month, dia.day);
    return getSessoes(inicio: inicio, fim: DateTime(dia.year, dia.month, dia.day + 1));
  }

  // --- Catálogo de exercícios

  Future<Pagina<CatalogoExercicio>> getCatalogo({
    String? busca,
    TipoTreino? tipo,
    GrupoMuscular? grupo,
    int offset = 0,
    int limite = 30,
  }) async {
    final termo = busca?.trim();
    final data = await _request<Map<String, dynamic>>(() => _dio.get(
          '/catalog/exercises',
          queryParameters: {
            if (termo != null && termo.isNotEmpty) 'q': termo,
            'type': ?tipo?.valorApi,
            'muscle_group': ?grupo?.valorApi,
            'offset': offset,
            'limit': limite,
          },
        ));
    return Pagina.fromJson(data, CatalogoExercicio.fromJson);
  }

  final Map<String, Future<CatalogoExercicio>> _detalhesCatalogo = {};

  /// Detalhe de um exercício do catálogo. Fica em cache, pois o catálogo não muda.
  Future<CatalogoExercicio> getExercicioCatalogo(String id) {
    return _detalhesCatalogo[id] ??= _request<Map<String, dynamic>>(
      () => _dio.get('/catalog/exercises/${Uri.encodeComponent(id)}'),
    ).then(CatalogoExercicio.fromJson).catchError((Object erro) {
      _detalhesCatalogo.remove(id);
      throw erro;
    });
  }

  // --- Atividades por GPS

  Future<List<AtividadeGps>> getAtividadesGps({int offset = 0, int limite = 30}) async {
    final data = await _request<List<dynamic>>(() => _dio.get(
          '/gps-activities',
          queryParameters: {'offset': offset, 'limit': limite},
        ));
    return [for (final item in data) AtividadeGps.fromJson(item as Map<String, dynamic>)];
  }

  Future<AtividadeGps> getAtividadeGps(int id) async {
    final data = await _request<Map<String, dynamic>>(() => _dio.get('/gps-activities/$id'));
    return AtividadeGps.fromJson(data);
  }

  Future<AtividadeGps> salvarAtividadeGps(AtividadeGps atividade) async {
    final data = await _request<Map<String, dynamic>>(
      () => _dio.post('/gps-activities', data: atividade.toJson()),
    );
    return AtividadeGps.fromJson(data);
  }

  Future<AtividadeGps> atualizarComentarioGps(int id, String? comentario) async {
    final data = await _request<Map<String, dynamic>>(
      () => _dio.put('/gps-activities/$id/comment', data: {'comment': comentario}),
    );
    return AtividadeGps.fromJson(data);
  }

  Future<void> excluirAtividadeGps(int id) => _request<dynamic>(() => _dio.delete('/gps-activities/$id'));

  // --- Infra

  Future<T> _request<T>(Future<Response<dynamic>> Function() call) async {
    try {
      final response = await call();
      return response.data as T;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  ApiException _mapError(DioException e) {
    final response = e.response;
    if (response == null) {
      return const ApiException('Não foi possível conectar ao servidor. Verifique sua conexão.');
    }

    final detail = response.data is Map ? response.data['detail'] : null;
    final status = response.statusCode;
    final mensagem = switch (status) {
      401 => detail is String ? detail : 'Sessão expirada. Faça login novamente.',
      422 => 'Dados inválidos. Revise os campos e tente novamente.',
      _ when status != null && status >= 500 => 'Erro no servidor. Tente novamente em instantes.',
      _ => detail is String ? detail : 'Erro inesperado ($status).',
    };
    return ApiException(mensagem, statusCode: status);
  }
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._tokens, this._onUnauthorized);

  static const skipAuthKey = 'skipAuth';

  final TokenStorage _tokens;
  final VoidCallback _onUnauthorized;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra[skipAuthKey] != true) {
      final token = await _tokens.read();
      if (token == null) {
        _onUnauthorized();
        return handler.reject(DioException(
          requestOptions: options,
          response: Response(requestOptions: options, statusCode: 401),
          type: DioExceptionType.badResponse,
        ));
      }
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final authenticated = err.requestOptions.extra[skipAuthKey] != true;
    if (authenticated && err.response?.statusCode == 401) {
      await _tokens.clear();
      _onUnauthorized();
    }
    handler.next(err);
  }
}
