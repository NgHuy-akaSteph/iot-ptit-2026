import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'auth_service.dart';
import 'thingsboard_service.dart';

class WebSocketService {
  final AuthService _authService = AuthService();
  WebSocketChannel? _channel;
  final _telemetryController = StreamController<Map<String, dynamic>>.broadcast();
  bool _isConnected = false;
  Timer? _reconnectTimer;

  Stream<Map<String, dynamic>> get telemetryStream => _telemetryController.stream;
  bool get isConnected => _isConnected;

  Future<void> connect() async {
    try {
      final token = await _authService.getToken();
      if (token == null) return;

      final uri = Uri.parse('wss://thingsboard.cloud/api/ws/plugins/telemetry?token=$token');
      _channel = WebSocketChannel.connect(uri);

      _isConnected = true;

      _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onError: (error) {
          _isConnected = false;
          _scheduleReconnect();
        },
        onDone: () {
          _isConnected = false;
          _scheduleReconnect();
        },
      );

      await Future.delayed(const Duration(milliseconds: 500));

      _sendAuthCommand(token);
      _subscribeTelemetry();
    } catch (e) {
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  void _sendAuthCommand(String token) {
    final authCmd = jsonEncode({
      'authCmd': {
        'cmdId': 0,
        'token': token,
      }
    });
    _channel?.sink.add(authCmd);
  }

  void _subscribeTelemetry() {
    final subscribeCmd = jsonEncode({
      'tsSubCmds': [
        {
          'entityType': 'DEVICE',
          'entityId': ThingsBoardService.deviceId,
          'scope': 'LATEST_TELEMETRY',
          'cmdId': 1,
        }
      ]
    });
    _channel?.sink.add(subscribeCmd);
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String);

      if (data.containsKey('data')) {
        _telemetryController.add(data['data'] as Map<String, dynamic>);
      }
    } catch (e) {
      // Ignore parse errors
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isConnected) {
        connect();
      }
    });
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _isConnected = false;
  }

  void dispose() {
    disconnect();
    _telemetryController.close();
  }
}
