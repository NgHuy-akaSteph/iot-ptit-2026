import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  final String _baseUrl = 'https://iot-ptit-bff.onrender.com/api';

  Future<bool> login(String email, String password) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/auth/login',
        data: {'username': email, 'password': password},
      );

      // Nếu ThingsBoard trả về 200 OK -> Đăng nhập thành công
      if (response.statusCode == 200) {
        final String token = response.data['token'];
        final String tbToken = response.data['tbToken'];

        await _storage.write(key: 'jwt_token', value: token);
        await _storage.write(key: 'tb_token', value: tbToken);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  Future<String?> getTbToken() async {
    return await _storage.read(key: 'tb_token');
  }

  Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'tb_token');
  }
  
}
