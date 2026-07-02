import '../models/role.dart';
import 'api_client.dart';

class RoleApi {
  RoleApi(this._api);
  final ApiClient _api;

  Future<List<Role>> list() async {
    final json = await _api.getJson('/role/list');
    return (json['data'] as List<dynamic>? ?? [])
        .map((e) => Role.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
