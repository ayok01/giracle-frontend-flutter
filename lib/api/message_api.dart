import '../models/message.dart';
import 'api_client.dart';

class MessageApi {
  MessageApi(this._api);
  final ApiClient _api;

  Future<Message> send(
    String channelId,
    String message, {
    List<String> fileIds = const [],
    String? replyingMessageId,
  }) async {
    final json = await _api.postJson('/message/send', body: {
      'channelId': channelId,
      'message': message,
      'fileIds': fileIds,
      if (replyingMessageId != null) 'replyingMessageId': replyingMessageId,
    });
    return Message.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<void> delete(String messageId) =>
      _api.deleteJson('/message/delete', body: {'messageId': messageId});

  Future<void> edit(String messageId, String content) =>
      _api.postJson('/message/edit',
          body: {'messageId': messageId, 'message': content});

  Future<void> addReaction(String messageId, String emojiCode) =>
      _api.postJson('/message/reaction',
          body: {'messageId': messageId, 'emojiCode': emojiCode});

  Future<void> removeReaction(String messageId, String emojiCode) =>
      _api.deleteJson('/message/reaction',
          body: {'messageId': messageId, 'emojiCode': emojiCode});

  Future<List<InboxItem>> inbox() async {
    final json = await _api.getJson('/message/inbox');
    return (json['data'] as List<dynamic>? ?? [])
        .map((e) => InboxItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateReadTime(String channelId, String readTime) =>
      _api.postJson('/message/update-readtime',
          body: {'channelId': channelId, 'readTime': readTime});
}
