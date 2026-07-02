import 'channel.dart';

class ServerInfo {
  final String name;
  final String introduction;
  final bool registerAvailable;
  final bool registerInviteOnly;
  final String registerAnnounceChannelId;
  final int messageMaxLength;
  final int messageMaxFileSize;
  final List<Channel> defaultJoinChannel;

  const ServerInfo({
    required this.name,
    required this.introduction,
    required this.registerAvailable,
    required this.registerInviteOnly,
    required this.registerAnnounceChannelId,
    required this.messageMaxLength,
    required this.messageMaxFileSize,
    required this.defaultJoinChannel,
  });

  factory ServerInfo.empty() => const ServerInfo(
        name: '',
        introduction: '',
        registerAvailable: false,
        registerInviteOnly: false,
        registerAnnounceChannelId: '',
        messageMaxLength: 1,
        messageMaxFileSize: 1,
        defaultJoinChannel: [],
      );

  factory ServerInfo.fromJson(Map<String, dynamic> json) => ServerInfo(
        name: json['name'] as String? ?? '',
        introduction: json['introduction'] as String? ?? '',
        registerAvailable: json['RegisterAvailable'] as bool? ?? false,
        registerInviteOnly: json['RegisterInviteOnly'] as bool? ?? false,
        registerAnnounceChannelId:
            json['RegisterAnnounceChannelId'] as String? ?? '',
        messageMaxLength: (json['MessageMaxLength'] as num?)?.toInt() ?? 1,
        messageMaxFileSize:
            (json['MessageMaxFileSize'] as num?)?.toInt() ?? 1,
        defaultJoinChannel: (json['defaultJoinChannel'] as List<dynamic>? ?? [])
            .map((e) => Channel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
