class ChannelJoinRef {
  final String channelId;
  const ChannelJoinRef({required this.channelId});

  factory ChannelJoinRef.fromJson(Map<String, dynamic> json) =>
      ChannelJoinRef(channelId: json['channelId'] as String);
}

class RoleLinkRef {
  final String roleId;
  const RoleLinkRef({required this.roleId});

  factory RoleLinkRef.fromJson(Map<String, dynamic> json) =>
      RoleLinkRef(roleId: json['roleId'] as String);
}

class User {
  final String id;
  final String name;
  final bool isBanned;
  final String selfIntroduction;
  final List<ChannelJoinRef> channelJoin;
  final List<RoleLinkRef> roleLink;

  const User({
    required this.id,
    required this.name,
    required this.isBanned,
    required this.selfIntroduction,
    required this.channelJoin,
    required this.roleLink,
  });

  factory User.empty() => const User(
        id: '',
        name: 'ユーザー',
        isBanned: false,
        selfIntroduction: '',
        channelJoin: [],
        roleLink: [],
      );

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        isBanned: json['isBanned'] as bool? ?? false,
        selfIntroduction: json['selfIntroduction'] as String? ?? '',
        channelJoin: (json['ChannelJoin'] as List<dynamic>? ?? [])
            .map((e) => ChannelJoinRef.fromJson(e as Map<String, dynamic>))
            .toList(),
        roleLink: (json['RoleLink'] as List<dynamic>? ?? [])
            .map((e) => RoleLinkRef.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  User copyWith({
    String? id,
    String? name,
    bool? isBanned,
    String? selfIntroduction,
    List<ChannelJoinRef>? channelJoin,
    List<RoleLinkRef>? roleLink,
  }) =>
      User(
        id: id ?? this.id,
        name: name ?? this.name,
        isBanned: isBanned ?? this.isBanned,
        selfIntroduction: selfIntroduction ?? this.selfIntroduction,
        channelJoin: channelJoin ?? this.channelJoin,
        roleLink: roleLink ?? this.roleLink,
      );
}
