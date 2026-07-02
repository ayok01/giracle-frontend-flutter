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

  Future<void> updateProfile({String? name, String? selfIntroduction}) =>
      _api.postJson('/user/profile-update', body: {
        if (name != null) 'name': name,
        if (selfIntroduction != null) 'selfIntroduction': selfIntroduction,
      });

  Future<void> changePassword(String current, String newPassword) =>
      _api.postJson('/user/change-password', body: {
        'currentPassword': current,
        'newPassword': newPassword,
      });

  Future<List<User>> search(String q) async {
    final json = await _api.getJson('/user/search', query: {'q': q});
    return (json['data'] as List<dynamic>? ?? [])
        .map((e) => User.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
