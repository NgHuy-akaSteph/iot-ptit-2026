import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  final String _baseUrl = 'https://thingsboard.cloud/api';

  Future<bool> login(String email, String password) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/auth/login',
        data: {'username': email, 'password': password},
      );

      // Nếu ThingsBoard trả về 200 OK -> Đăng nhập thành công
      if (response.statusCode == 200) {
        // Rút trích chuỗi Token từ cục JSON trả về
        final String token = response.data['token'];

        // Cất Token vào vùng nhớ bảo mật của điện thoại
        await _storage.write(key: 'jwt_token', value: token);
        return true;
      }
      return false;
    } catch (e) {
      // Bắt lỗi sai pass, sai email, hoặc mất mạng
      return false;
    }
  }

  // Hàm tiện ích để móc Token ra dùng cho các API sau này
  Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  // Hàm Đăng xuất (xóa Token)
  Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
  }
  
}
