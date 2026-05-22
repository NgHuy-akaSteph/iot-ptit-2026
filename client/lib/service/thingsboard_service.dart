import 'package:dio/dio.dart';
import 'auth_service.dart';

enum TimeRange { oneMinute, oneHour, oneDay, oneWeek }

class TelemetryEntry {
  final DateTime timestamp;
  final double value;

  TelemetryEntry(this.timestamp, this.value);
}

class ThingsBoardService {
  final Dio _dio = Dio();
  final AuthService _authService = AuthService();
  final String _baseUrl = 'https://thingsboard.cloud/api';

  // Hardcoded device ID - user will provide this
  static const String deviceId = 'b8efca70-518c-11f1-befc-1dd22c41a268';

  Future<Map<String, dynamic>?> getLatestTelemetry() async {
    try {
      final token = await _authService.getToken();
      if (token == null) return null;

      final response = await _dio.get(
        '$_baseUrl/plugins/telemetry/DEVICE/$deviceId/values/timeseries',
        queryParameters: {
          'keys': 'temperature,humidity,dust_ug,gas_ppm,auto_mode,fan_level',
        },
        options: Options(
          headers: {'X-Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, List<TelemetryEntry>>?> fetchHistoricalTelemetry(
      TimeRange range) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return null;

      final now = DateTime.now().millisecondsSinceEpoch;
      int startTs;
      int limit;

      switch (range) {
        case TimeRange.oneMinute:
          startTs = now - 60 * 1000;
          limit = 10;
          break;
        case TimeRange.oneHour:
          startTs = now - 60 * 60 * 1000;
          limit = 60;
          break;
        case TimeRange.oneDay:
          startTs = now - 24 * 60 * 60 * 1000;
          limit = 144;
          break;
        case TimeRange.oneWeek:
          startTs = now - 7 * 24 * 60 * 60 * 1000;
          limit = 168;
          break;
      }

      final response = await _dio.get(
        '$_baseUrl/plugins/telemetry/DEVICE/$deviceId/values/timeseries',
        queryParameters: {
          'keys': 'temperature,humidity,dust_ug,gas_ppm',
          'startTs': startTs,
          'endTs': now,
          'limit': limit,
          'orderBy': 'DESC',
        },
        options: Options(
          headers: {'X-Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final result = <String, List<TelemetryEntry>>{};

        for (final entry in data.entries) {
          final key = entry.key;
          final values = entry.value as List;
          result[key] = values.map((v) {
            final ts = v['ts'] as int;
            final rawValue = v['value'];
            final value = rawValue is num ? rawValue.toDouble() : double.tryParse(rawValue.toString()) ?? 0.0;
            return TelemetryEntry(DateTime.fromMillisecondsSinceEpoch(ts), value);
          }).toList();
          // ThingsBoard returns DESC order; reverse to chronological
          result[key]!.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        }

        return result;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> setAutoMode(bool enabled) async {
    return await _sendRpcCommand('setAutoMode', enabled);
  }

  Future<bool> setFanLevel(int level) async {
    return await _sendRpcCommand('setFan', level);
  }

  Future<bool> _sendRpcCommand(String method, dynamic params) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return false;

      final response = await _dio.post(
        '$_baseUrl/plugins/rpc/twoway/$deviceId',
        data: {
          'method': method,
          'params': params,
        },
        options: Options(
          headers: {'X-Authorization': 'Bearer $token'},
        ),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
