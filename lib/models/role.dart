class Role {
  final String id;
  final String name;
  final String color;
  final String createdUserId;
  final bool manageServer;
  final bool manageChannel;
  final bool manageRole;
  final bool manageUser;
  final bool manageEmoji;

  const Role({
    required this.id,
    required this.name,
    required this.color,
    required this.createdUserId,
    required this.manageServer,
    required this.manageChannel,
    required this.manageRole,
    required this.manageUser,
    required this.manageEmoji,
  });

  factory Role.fromJson(Map<String, dynamic> json) => Role(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        color: json['color'] as String? ?? '',
        createdUserId: json['createdUserId'] as String? ?? '',
        manageServer: json['manageServer'] as bool? ?? false,
        manageChannel: json['manageChannel'] as bool? ?? false,
        manageRole: json['manageRole'] as bool? ?? false,
        manageUser: json['manageUser'] as bool? ?? false,
        manageEmoji: json['manageEmoji'] as bool? ?? false,
      );
}
