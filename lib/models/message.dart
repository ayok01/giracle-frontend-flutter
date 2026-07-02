class ReactionSummary {
  final String emojiCode;
  final int count;
  final bool includingYou;

  const ReactionSummary({
    required this.emojiCode,
    required this.count,
    required this.includingYou,
  });

  factory ReactionSummary.fromJson(Map<String, dynamic> json) =>
      ReactionSummary(
        emojiCode: json['emojiCode'] as String,
        count: json['count'] as int,
        includingYou: json['includingYou'] as bool? ?? false,
      );
}

class MessageFileAttached {
  final String id;
  final String userId;
  final String channelId;
  final String? messageId;
  final String actualFileName;
  final String savedFileName;
  final int size;
  final String type;

  const MessageFileAttached({
    required this.id,
    required this.userId,
    required this.channelId,
    required this.messageId,
    required this.actualFileName,
    required this.savedFileName,
    required this.size,
    required this.type,
  });

  factory MessageFileAttached.fromJson(Map<String, dynamic> json) =>
      MessageFileAttached(
        id: json['id'] as String,
        userId: json['userId'] as String,
        channelId: json['channelId'] as String,
        messageId: json['messageId'] as String?,
        actualFileName: json['actualFileName'] as String? ?? '',
        savedFileName: json['savedFileName'] as String? ?? '',
        size: (json['size'] as num?)?.toInt() ?? 0,
        type: json['type'] as String? ?? '',
      );
}

class MessageUrlPreview {
  final int id;
  final String url;
  final String title;
  final String description;
  final String faviconLink;
  final String? imageLink;
  final String? videoLink;
  final String type;

  const MessageUrlPreview({
    required this.id,
    required this.url,
    required this.title,
    required this.description,
    required this.faviconLink,
    required this.imageLink,
    required this.videoLink,
    required this.type,
  });

  factory MessageUrlPreview.fromJson(Map<String, dynamic> json) =>
      MessageUrlPreview(
        id: (json['id'] as num).toInt(),
        url: json['url'] as String? ?? '',
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        faviconLink: json['faviconLink'] as String? ?? '',
        imageLink: json['imageLink'] as String?,
        videoLink: json['videoLink'] as String?,
        type: json['type'] as String? ?? 'UNKNOWN',
      );
}

class Message {
  final String id;
  final String channelId;
  final String userId;
  final String content;
  final bool isEdited;
  final DateTime createdAt;
  final bool isSystemMessage;
  final String? replyingMessageId;
  final List<MessageUrlPreview> urlPreviews;
  final List<MessageFileAttached> files;
  final List<ReactionSummary> reactionSummary;

  const Message({
    required this.id,
    required this.channelId,
    required this.userId,
    required this.content,
    required this.isEdited,
    required this.createdAt,
    required this.isSystemMessage,
    required this.replyingMessageId,
    required this.urlPreviews,
    required this.files,
    required this.reactionSummary,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['createdAt'];
    return Message(
      id: json['id'] as String,
      channelId: json['channelId'] as String,
      userId: json['userId'] as String? ?? '',
      content: json['content'] as String? ?? '',
      isEdited: json['isEdited'] as bool? ?? false,
      createdAt: createdAtRaw is String
          ? DateTime.tryParse(createdAtRaw) ?? DateTime.now()
          : DateTime.now(),
      isSystemMessage: json['isSystemMessage'] as bool? ?? false,
      replyingMessageId: json['replyingMessageId'] as String?,
      urlPreviews: (json['MessageUrlPreview'] as List<dynamic>? ?? [])
          .map((e) => MessageUrlPreview.fromJson(e as Map<String, dynamic>))
          .toList(),
      files: (json['MessageFileAttached'] as List<dynamic>? ?? [])
          .map((e) => MessageFileAttached.fromJson(e as Map<String, dynamic>))
          .toList(),
      reactionSummary: (json['reactionSummary'] as List<dynamic>? ?? [])
          .map((e) => ReactionSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CustomEmoji {
  final String id;
  final String code;
  final String uploadedUserId;

  const CustomEmoji({
    required this.id,
    required this.code,
    required this.uploadedUserId,
  });

  factory CustomEmoji.fromJson(Map<String, dynamic> json) => CustomEmoji(
        id: json['id'] as String,
        code: json['code'] as String,
        uploadedUserId: json['uploadedUserId'] as String? ?? '',
      );
}

class InboxItem {
  final String type;
  final String userId;
  final String messageId;
  final Message message;
  final DateTime happenedAt;

  const InboxItem({
    required this.type,
    required this.userId,
    required this.messageId,
    required this.message,
    required this.happenedAt,
  });

  factory InboxItem.fromJson(Map<String, dynamic> json) => InboxItem(
        type: json['type'] as String,
        userId: json['userId'] as String,
        messageId: json['messageId'] as String,
        message: Message.fromJson(json['Message'] as Map<String, dynamic>),
        happenedAt:
            DateTime.tryParse(json['happendAt'] as String? ?? '') ??
                DateTime.now(),
      );
}
