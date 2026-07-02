import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/channel_api.dart';
import '../api/message_api.dart';
import '../api/role_api.dart';
import '../api/server_api.dart';
import '../api/user_api.dart';
import '../models/channel.dart';
import '../models/message.dart';
import '../models/role.dart';
import '../models/server.dart';
import '../models/user.dart';
import '../ws/ws_controller.dart';

final userApiProvider = Provider<UserApi>((ref) => UserApi(ref.watch(apiClientProvider)));
final channelApiProvider = Provider<ChannelApi>((ref) => ChannelApi(ref.watch(apiClientProvider)));
final messageApiProvider = Provider<MessageApi>((ref) => MessageApi(ref.watch(apiClientProvider)));
final serverApiProvider = Provider<ServerApi>((ref) => ServerApi(ref.watch(apiClientProvider)));
final roleApiProvider = Provider<RoleApi>((ref) => RoleApi(ref.watch(apiClientProvider)));

final wsControllerProvider = Provider<WsController>((ref) {
  final ws = WsController(ref.watch(apiClientProvider));
  ref.onDispose(ws.dispose);
  return ws;
});

class AppStatus {
  final bool wsConnected;
  final bool loggedIn;
  final bool hasServerInfo;

  const AppStatus({
    this.wsConnected = false,
    this.loggedIn = false,
    this.hasServerInfo = false,
  });

  AppStatus copyWith({bool? wsConnected, bool? loggedIn, bool? hasServerInfo}) =>
      AppStatus(
        wsConnected: wsConnected ?? this.wsConnected,
        loggedIn: loggedIn ?? this.loggedIn,
        hasServerInfo: hasServerInfo ?? this.hasServerInfo,
      );
}

class AppStatusNotifier extends StateNotifier<AppStatus> {
  AppStatusNotifier() : super(const AppStatus());

  void setLoggedIn(bool v) => state = state.copyWith(loggedIn: v);
  void setWsConnected(bool v) => state = state.copyWith(wsConnected: v);
  void setHasServerInfo(bool v) => state = state.copyWith(hasServerInfo: v);
}

final appStatusProvider = StateNotifierProvider<AppStatusNotifier, AppStatus>(
    (ref) => AppStatusNotifier());

class MyUserNotifier extends StateNotifier<User> {
  MyUserNotifier() : super(User.empty());
  void set(User u) => state = u;
  void reset() => state = User.empty();

  bool hasRolePower(String term, Map<String, Role> roles) {
    for (final link in state.roleLink) {
      if (link.roleId == 'HOST') return true;
      final role = roles[link.roleId];
      if (role == null) continue;
      switch (term) {
        case 'manageRole':
          if (role.manageRole) return true;
          break;
        case 'manageChannel':
          if (role.manageChannel) return true;
          break;
        case 'manageUser':
          if (role.manageUser) return true;
          break;
        case 'manageServer':
          if (role.manageServer) return true;
          break;
        case 'manageEmoji':
          if (role.manageEmoji) return true;
          break;
      }
    }
    return false;
  }
}

final myUserProvider =
    StateNotifierProvider<MyUserNotifier, User>((ref) => MyUserNotifier());

class ServerInfoNotifier extends StateNotifier<ServerInfo> {
  ServerInfoNotifier() : super(ServerInfo.empty());
  void set(ServerInfo v) => state = v;
}

final serverInfoProvider =
    StateNotifierProvider<ServerInfoNotifier, ServerInfo>((ref) => ServerInfoNotifier());

class ChannelListNotifier extends StateNotifier<List<Channel>> {
  ChannelListNotifier() : super(const []);
  void set(List<Channel> v) => state = v;
  void upsert(Channel c) {
    final idx = state.indexWhere((e) => e.id == c.id);
    if (idx < 0) {
      state = [...state, c];
    } else {
      final copy = [...state];
      copy[idx] = c;
      state = copy;
    }
  }

  void remove(String id) {
    state = state.where((e) => e.id != id).toList();
  }
}

final channelListProvider =
    StateNotifierProvider<ChannelListNotifier, List<Channel>>(
        (ref) => ChannelListNotifier());

class ChannelInfoNotifier extends StateNotifier<Map<String, Channel>> {
  ChannelInfoNotifier() : super(const {});
  void upsert(Channel c) => state = {...state, c.id: c};
}

final channelInfoProvider =
    StateNotifierProvider<ChannelInfoNotifier, Map<String, Channel>>(
        (ref) => ChannelInfoNotifier());

class RoleInfoNotifier extends StateNotifier<Map<String, Role>> {
  RoleInfoNotifier() : super(const {});
  void set(Map<String, Role> v) => state = v;
  void upsert(Role r) => state = {...state, r.id: r};
}

final roleInfoProvider =
    StateNotifierProvider<RoleInfoNotifier, Map<String, Role>>(
        (ref) => RoleInfoNotifier());

class UserCacheNotifier extends StateNotifier<Map<String, User>> {
  UserCacheNotifier() : super(const {});
  void upsert(User u) => state = {...state, u.id: u};
}

final userCacheProvider =
    StateNotifierProvider<UserCacheNotifier, Map<String, User>>(
        (ref) => UserCacheNotifier());

class HistoryEntry {
  final List<Message> history;
  final bool atTop;
  final bool atEnd;
  const HistoryEntry({
    required this.history,
    required this.atTop,
    required this.atEnd,
  });

  HistoryEntry copyWith({List<Message>? history, bool? atTop, bool? atEnd}) =>
      HistoryEntry(
        history: history ?? this.history,
        atTop: atTop ?? this.atTop,
        atEnd: atEnd ?? this.atEnd,
      );
}

class HistoryNotifier extends StateNotifier<Map<String, HistoryEntry>> {
  HistoryNotifier() : super(const {});

  void setHistory(String channelId, HistoryEntry entry) {
    state = {...state, channelId: entry};
  }

  void prepend(String channelId, List<Message> older) {
    final current = state[channelId] ??
        const HistoryEntry(history: [], atTop: false, atEnd: false);
    state = {
      ...state,
      channelId: current.copyWith(
        history: [...current.history, ...older],
      ),
    };
  }

  void addNew(Message msg) {
    final current = state[msg.channelId];
    if (current == null) return;
    if (!current.atEnd) return;
    if (current.history.any((m) => m.id == msg.id)) return;
    state = {
      ...state,
      msg.channelId: current.copyWith(history: [msg, ...current.history]),
    };
  }

  void removeMessage(String channelId, String messageId) {
    final current = state[channelId];
    if (current == null) return;
    state = {
      ...state,
      channelId: current.copyWith(
          history: current.history.where((m) => m.id != messageId).toList()),
    };
  }
}

final historyProvider =
    StateNotifierProvider<HistoryNotifier, Map<String, HistoryEntry>>(
        (ref) => HistoryNotifier());

class OnlineUsersNotifier extends StateNotifier<Set<String>> {
  OnlineUsersNotifier() : super(const {});
  void set(Iterable<String> ids) => state = ids.toSet();
  void add(String id) => state = {...state, id};
  void remove(String id) => state = {...state}..remove(id);
}

final onlineUsersProvider =
    StateNotifierProvider<OnlineUsersNotifier, Set<String>>(
        (ref) => OnlineUsersNotifier());
