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
  final String _baseUrl = 'https://iot-ptit-bff.onrender.com/api';

  // Hardcoded device ID - user will provide this
  static const String deviceId = 'b8efca70-518c-11f1-befc-1dd22c41a268';

  Future<Map<String, dynamic>?> getLatestTelemetry() async {
    try {
      final token = await _authService.getToken();
      if (token == null) return null;

      final response = await _dio.get(
        '$_baseUrl/devices/$deviceId/telemetry/latest',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
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

      String rangeStr;
      switch (range) {
        case TimeRange.oneMinute:
          rangeStr = 'oneMinute';
          break;
        case TimeRange.oneHour:
          rangeStr = 'oneHour';
          break;
        case TimeRange.oneDay:
          rangeStr = 'oneDay';
          break;
        case TimeRange.oneWeek:
          rangeStr = 'oneWeek';
          break;
      }

      final response = await _dio.get(
        '$_baseUrl/devices/$deviceId/telemetry/history',
        queryParameters: {
          'range': rangeStr,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
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
          // Sort to chronological
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

  Future<bool> setMist(bool enabled) async {
    return await _sendRpcCommand('setMist', enabled);
  }

  Future<List<dynamic>?> fetchAlertHistory() async {
    try {
      final token = await _authService.getToken();
      if (token == null) return null;

      final response = await _dio.get(
        '$_baseUrl/devices/$deviceId/alerts/history',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<dynamic>?> fetchThresholdHistory() async {
    try {
      final token = await _authService.getToken();
      if (token == null) return null;

      final response = await _dio.get(
        '$_baseUrl/devices/$deviceId/thresholds/history',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> _sendRpcCommand(String method, dynamic params) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return false;

      final response = await _dio.post(
        '$_baseUrl/devices/$deviceId/rpc',
        data: {
          'method': method,
          'params': params,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
