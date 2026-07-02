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

  Future<void> addReaction(String channelId, String messageId, String emojiCode) =>
      _api.postJson('/message/emoji-reaction', body: {
        'messageId': messageId,
        'channelId': channelId,
        'emojiCode': emojiCode,
      });

  Future<void> removeReaction(
          String channelId, String messageId, String emojiCode) =>
      _api.deleteJson('/message/delete-emoji-reaction', body: {
        'messageId': messageId,
        'channelId': channelId,
        'emojiCode': emojiCode,
      });

  Future<List<InboxItem>> inbox() async {
    final json = await _api.getJson('/message/inbox');
    return (json['data'] as List<dynamic>? ?? [])
        .map((e) => InboxItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markInboxRead(String messageId) =>
      _api.postJson('/message/inbox/read', body: {'messageId': messageId});

  Future<void> updateReadTime(String channelId, String readTime) =>
      _api.postJson('/message/read-time/update',
          body: {'channelId': channelId, 'readTime': readTime});

  Future<Map<String, String>> getReadTimes() async {
    final json = await _api.getJson('/message/read-time/get');
    final list = json['data'] as List<dynamic>? ?? [];
    return {
      for (final e in list)
        (e as Map<String, dynamic>)['channelId'] as String:
            e['readTime'] as String,
    };
  }

  Future<Map<String, bool>> getNewFlags() async {
    final json = await _api.getJson('/message/get-new');
    final map = json['data'] as Map<String, dynamic>? ?? {};
    return {for (final entry in map.entries) entry.key: entry.value as bool};
  }

  Future<List<Message>> search({
    String? content,
    String? channelId,
    String? userId,
    bool? hasUrlPreview,
    bool? hasFileAttachment,
    int? loadIndex,
    String? sort,
  }) async {
    final json = await _api.getJson('/message/search', query: {
      if (content != null && content.isNotEmpty) 'content': content,
      if (channelId != null) 'channelId': channelId,
      if (userId != null) 'userId': userId,
      if (hasUrlPreview != null) 'hasUrlPreview': hasUrlPreview.toString(),
      if (hasFileAttachment != null)
        'hasFileAttachment': hasFileAttachment.toString(),
      if (loadIndex != null) 'loadIndex': loadIndex.toString(),
      if (sort != null) 'sort': sort,
    });
    return (json['data'] as List<dynamic>? ?? [])
        .map((e) => Message.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
