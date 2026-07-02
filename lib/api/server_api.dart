import 'package:dio/dio.dart';

import '../models/message.dart';
import '../models/server.dart';
import 'api_client.dart';

class ServerConfigResult {
  final ServerInfo info;
  final bool isFirstUser;
  const ServerConfigResult({required this.info, required this.isFirstUser});
}

class ServerApi {
  ServerApi(this._api);
  final ApiClient _api;

  Future<ServerConfigResult> config() async {
    final json = await _api.getJson('/server/config');
    final raw = json['data'];
    if (raw is! Map) {
      throw ApiException(
        'サーバー応答が不正です (data missing)。URL に /api を含めているか確認してください',
      );
    }
    final data = Map<String, dynamic>.from(raw);
    final isFirstUser = data['isFirstUser'] as bool? ?? false;
    data.remove('isFirstUser');
    return ServerConfigResult(
      info: ServerInfo.fromJson(data),
      isFirstUser: isFirstUser,
    );
  }

  Future<List<CustomEmoji>> customEmojis() async {
    final json = await _api.getJson('/server/custom-emoji');
    return (json['data'] as List<dynamic>? ?? [])
        .map((e) => CustomEmoji.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Upload a new custom emoji. `bytes` is the raw image file body.
  Future<List<CustomEmoji>> uploadCustomEmoji({
    required String emojiCode,
    required List<int> bytes,
    required String filename,
  }) async {
    final form = FormData.fromMap({
      'emojiCode': emojiCode,
      'emoji': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await _api.dio.put('/server/custom-emoji/upload', data: form);
    final data = res.data;
    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .map((e) => CustomEmoji.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return const [];
  }

  Future<void> deleteCustomEmoji(String emojiCode) =>
      _api.deleteJson('/server/custom-emoji/delete',
          body: {'emojiCode': emojiCode});
}
