import 'package:flutter/foundation.dart';
import 'package:focus/models/saude.dart';
import 'package:focus/service/api_service.dart';
import 'package:health/health.dart';

enum EstadoRelogio {
  /// Health Connect só existe no Android.
  naoSuportado,
  semHealthConnect,
  atualizarHealthConnect,
  semPermissao,
  pronto,
}

/// Lê os dados do relógio no Health Connect (o app do relógio, ex.: Fitbeing, grava lá)
/// e envia um resumo por dia para a API.
class RelogioService {
  RelogioService._();

  static final instance = RelogioService._();

  final _health = Health();
  bool _configurado = false;

  /// Tipos que o app pede para ler. Cada um precisa da permissão equivalente no AndroidManifest.
  static const _tipos = {
    HealthDataType.STEPS: TipoAmostra.passos,
    HealthDataType.DISTANCE_DELTA: TipoAmostra.distancia,
    HealthDataType.ACTIVE_ENERGY_BURNED: TipoAmostra.caloriasAtivas,
    HealthDataType.TOTAL_CALORIES_BURNED: TipoAmostra.caloriasTotais,
    HealthDataType.HEART_RATE: TipoAmostra.frequencia,
    HealthDataType.RESTING_HEART_RATE: TipoAmostra.frequenciaRepouso,
    HealthDataType.SLEEP_SESSION: TipoAmostra.sonoSessao,
    HealthDataType.SLEEP_DEEP: TipoAmostra.sonoProfundo,
    HealthDataType.SLEEP_LIGHT: TipoAmostra.sonoLeve,
    HealthDataType.SLEEP_REM: TipoAmostra.sonoRem,
    HealthDataType.SLEEP_AWAKE: TipoAmostra.sonoAcordado,
    HealthDataType.BLOOD_OXYGEN: TipoAmostra.oxigenio,
  };

  static bool get suportado => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _configurar() async {
    if (_configurado) return;
    await _health.configure();
    _configurado = true;
  }

  Future<EstadoRelogio> verificar() async {
    if (!suportado) return EstadoRelogio.naoSuportado;
    await _configurar();
    final status = await _health.getHealthConnectSdkStatus();
    if (status == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
      return EstadoRelogio.atualizarHealthConnect;
    }
    if (status != HealthConnectSdkStatus.sdkAvailable) return EstadoRelogio.semHealthConnect;
    return (await _tiposPermitidos()).isEmpty ? EstadoRelogio.semPermissao : EstadoRelogio.pronto;
  }

  /// A pessoa pode liberar só parte dos dados; lemos o que foi liberado.
  Future<List<HealthDataType>> _tiposPermitidos() async {
    final permitidos = <HealthDataType>[];
    for (final tipo in _tipos.keys) {
      try {
        if (await _health.hasPermissions([tipo]) ?? false) permitidos.add(tipo);
      } catch (e) {
        debugPrint('Relógio: falha ao checar permissão de $tipo: $e');
      }
    }
    return permitidos;
  }

  /// Abre a tela do Health Connect para a pessoa liberar a leitura dos dados.
  Future<EstadoRelogio> conectar() async {
    await _configurar();
    await _health.requestAuthorization(_tipos.keys.toList());
    // Sem esta permissão, o Health Connect só entrega os últimos 30 dias.
    if (await _health.isHealthDataHistoryAvailable() && !await _health.isHealthDataHistoryAuthorized()) {
      await _health.requestHealthDataHistoryAuthorization();
    }
    return verificar();
  }

  Future<void> instalarHealthConnect() => _health.installHealthConnect();

  /// Lê o Health Connect desde o início de [desde] até agora e envia para a API.
  /// Devolve quantos dias tinham dados.
  Future<int> sincronizar({required DateTime desde}) async {
    final resumos = await lerResumos(desde: desde);
    if (resumos.isEmpty) return 0;
    await ApiService.instance.enviarResumosSaude(resumos);
    return resumos.length;
  }

  Future<List<ResumoSaudeDia>> lerResumos({required DateTime desde}) async {
    await _configurar();
    final inicio = DateTime(desde.year, desde.month, desde.day);
    final agora = DateTime.now();
    // Começa na tarde do dia anterior para pegar a noite de sono que termina em [inicio].
    final inicioLeitura = inicio.subtract(const Duration(hours: 12));
    final permitidos = await _tiposPermitidos();

    final amostras = <AmostraSaude>[];
    for (final tipo in permitidos) {
      try {
        final pontos = await _health.getHealthDataFromTypes(types: [tipo], startTime: inicioLeitura, endTime: agora);
        for (final p in pontos) {
          final valor = p.value;
          amostras.add(AmostraSaude(
            tipo: _tipos[tipo]!,
            inicio: p.dateFrom.toLocal(),
            fim: p.dateTo.toLocal(),
            valor: valor is NumericHealthValue ? valor.numericValue.toDouble() : 0,
            fonte: p.sourceName,
          ));
        }
      } catch (e) {
        debugPrint('Relógio: falha ao ler $tipo: $e');
      }
    }

    // Sem passos do relógio, usa o total do Health Connect, que não conta a mesma caminhada duas vezes.
    final passosAgregados = <DateTime, int>{};
    final temPassosDoRelogio = amostras.any((a) => a.tipo == TipoAmostra.passos && a.doRelogio);
    if (!temPassosDoRelogio && permitidos.contains(HealthDataType.STEPS)) {
      for (var dia = inicio; dia.isBefore(agora); dia = DateTime(dia.year, dia.month, dia.day + 1)) {
        final fimDia = DateTime(dia.year, dia.month, dia.day + 1);
        try {
          final total = await _health.getTotalStepsInInterval(dia, fimDia.isAfter(agora) ? agora : fimDia);
          if (total != null) passosAgregados[dia] = total;
        } catch (e) {
          debugPrint('Relógio: falha ao somar passos de $dia: $e');
        }
      }
    }

    return montarResumosDiarios(amostras, passosAgregados: passosAgregados)
        .where((r) => !r.data.isBefore(inicio))
        .toList();
  }
}
