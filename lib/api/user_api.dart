import '../models/user.dart';
import 'api_client.dart';

class UserApi {
  UserApi(this._api);
  final ApiClient _api;

  Future<String> signIn(String username, String password) async {
    final json = await _api.postJson('/user/sign-in', body: {
      'username': username,
      'password': password,
    });
    return (json['data'] as Map<String, dynamic>)['userId'] as String;
  }

  Future<void> signUp(String username, String password, {String? inviteCode}) {
    return _api.putJson('/user/sign-up', body: {
      'username': username,
      'password': password,
      if (inviteCode != null) 'inviteCode': inviteCode,
    });
  }

  Future<String?> verifyToken() async {
    try {
      final json = await _api.getJson('/user/verify-token');
      return (json['data'] as Map<String, dynamic>)['userId'] as String?;
    } on ApiException {
      return null;
    }
  }

  Future<User> info(String userId) async {
    final json = await _api.getJson('/user/info/$userId');
    return User.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<List<String>> onlineUsers() async {
    final json = await _api.getJson('/user/online');
    return (json['data'] as List<dynamic>? ?? [])
        .map((e) => e as String)
        .toList();
  }
}
