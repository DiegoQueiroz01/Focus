import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:focus/config/api_config.dart';
import 'package:focus/models/dashboard_resumo.dart';
import 'package:focus/models/pagina.dart';
import 'package:focus/models/treino_model.dart';
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

  static final ApiService instance = ApiService();

  final Dio _dio;
  final TokenStorage _tokens;

  /// Chamado quando a API rejeita o token (expirado/revogado). O app usa para voltar ao login.
  VoidCallback? onUnauthorized;

  // Evita disparar onUnauthorized várias vezes quando requisições paralelas recebem 401.
  bool _sessaoEncerrada = false;

  void _notificarSessaoEncerrada() {
    if (_sessaoEncerrada) return;
    _sessaoEncerrada = true;
    onUnauthorized?.call();
  }

  Future<bool> isAuthenticated() async => await _tokens.read() != null;

  Future<void> login(String username, String password) async {
    final data = await _request<Map<String, dynamic>>(() => _dio.post(
          '/login',
          data: {'username': username, 'password': password},
          options: Options(extra: {_AuthInterceptor.skipAuthKey: true}),
        ));
    await _tokens.save(
      data['access_token'] as String,
      Duration(seconds: (data['expires_in'] as num).toInt()),
    );
    _sessaoEncerrada = false;
  }

  Future<void> logout() => _tokens.clear();

  Future<DashboardResumo> getResumo({int? dias}) async {
    final data = await _request<Map<String, dynamic>>(() => _dio.get(
          '/dashboard/summary',
          queryParameters: {'days': ?dias},
        ));
    return DashboardResumo.fromJson(data);
  }

  Future<Pagina<Treino>> getTreinos({int offset = 0, int limit = ApiConfig.pageSize}) async {
    final data = await _request<Map<String, dynamic>>(() => _dio.get(
          '/workouts',
          queryParameters: {'offset': offset, 'limit': limit},
        ));
    return Pagina.fromJson(data, Treino.fromJson);
  }

  Future<Treino> criarTreino(Treino treino) async {
    final data = await _request<Map<String, dynamic>>(
      () => _dio.post('/workouts', data: treino.toJson()),
    );
    return Treino.fromJson(data);
  }

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
