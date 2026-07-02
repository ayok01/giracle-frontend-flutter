class ChannelViewableRoleRef {
  final String roleId;
  const ChannelViewableRoleRef({required this.roleId});

  factory ChannelViewableRoleRef.fromJson(Map<String, dynamic> json) =>
      ChannelViewableRoleRef(roleId: json['roleId'] as String);
}

class Channel {
  final String id;
  final String name;
  final String description;
  final String createdUserId;
  final bool isArchived;
  final List<ChannelViewableRoleRef> viewableRole;

  const Channel({
    required this.id,
    required this.name,
    required this.description,
    required this.createdUserId,
    required this.isArchived,
    required this.viewableRole,
  });

  factory Channel.fromJson(Map<String, dynamic> json) => Channel(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        createdUserId: json['createdUserId'] as String? ?? '',
        isArchived: json['isArchived'] as bool? ?? false,
        viewableRole: (json['ChannelViewableRole'] as List<dynamic>? ?? [])
            .map((e) =>
                ChannelViewableRoleRef.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
