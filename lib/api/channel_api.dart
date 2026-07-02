import '../models/channel.dart';
import '../models/message.dart';
import 'api_client.dart';

class ChannelHistory {
  final List<Message> history;
  final bool atTop;
  final bool atEnd;
  const ChannelHistory(
      {required this.history, required this.atTop, required this.atEnd});
}

class ChannelApi {
  ChannelApi(this._api);
  final ApiClient _api;

  Future<List<Channel>> list() async {
    final json = await _api.getJson('/channel/list');
    return (json['data'] as List<dynamic>? ?? [])
        .map((e) => Channel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Channel> info(String channelId) async {
    final json = await _api.getJson('/channel/info/$channelId');
    return Channel.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<ChannelHistory> getHistory(
    String channelId, {
    String? messageIdFrom,
    String? messageTimeFrom,
    int? fetchLength,
    String? fetchDirection,
  }) async {
    final json = await _api.postJson('/channel/get-history/$channelId', body: {
      if (messageIdFrom != null) 'messageIdFrom': messageIdFrom,
      if (messageTimeFrom != null) 'messageTimeFrom': messageTimeFrom,
      if (fetchLength != null) 'fetchLength': fetchLength,
      if (fetchDirection != null) 'fetchDirection': fetchDirection,
    });
    final data = json['data'] as Map<String, dynamic>;
    final history = (data['history'] as List<dynamic>? ?? [])
        .map((e) => Message.fromJson(e as Map<String, dynamic>))
        .toList();
    return ChannelHistory(
      history: history,
      atTop: data['atTop'] as bool? ?? false,
      atEnd: data['atEnd'] as bool? ?? false,
    );
  }

  Future<void> join(String channelId) =>
      _api.postJson('/channel/join', body: {'channelId': channelId});

  Future<void> leave(String channelId) =>
      _api.postJson('/channel/leave', body: {'channelId': channelId});
}
