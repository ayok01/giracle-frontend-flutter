import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/message.dart';
import '../models/role.dart';
import '../ws/ws_controller.dart';
import 'providers.dart';

Future<void> initLoad(WidgetRef ref, String userId,
    {bool initWsToo = false}) async {
  try {
    final me = await ref.read(userApiProvider).info(userId);
    ref.read(myUserProvider.notifier).set(me);
  } catch (e) {
    debugPrint('initLoad user info err: $e');
  }

  try {
    final config = await ref.read(serverApiProvider).config();
    ref.read(serverInfoProvider.notifier).set(config.info);
    ref.read(appStatusProvider.notifier).setHasServerInfo(true);
  } catch (e) {
    debugPrint('initLoad server config err: $e');
  }

  try {
    final roles = await ref.read(roleApiProvider).list();
    final map = <String, Role>{for (final r in roles) r.id: r};
    ref.read(roleInfoProvider.notifier).set(map);
  } catch (e) {
    debugPrint('initLoad role list err: $e');
  }

  try {
    final channels = await ref.read(channelApiProvider).list();
    ref.read(channelListProvider.notifier).set(channels);
    for (final c in channels) {
      ref.read(channelInfoProvider.notifier).upsert(c);
    }
  } catch (e) {
    debugPrint('initLoad channel list err: $e');
  }

  try {
    final online = await ref.read(userApiProvider).onlineUsers();
    ref.read(onlineUsersProvider.notifier).set(online);
  } catch (e) {
    debugPrint('initLoad online users err: $e');
  }

  try {
    final inbox = await ref.read(messageApiProvider).inbox();
    ref.read(inboxProvider.notifier).set(inbox);
  } catch (e) {
    debugPrint('initLoad inbox err: $e');
  }

  ref.read(appStatusProvider.notifier).setLoggedIn(true);

  if (initWsToo) {
    _wireWs(ref);
    await ref.read(wsControllerProvider).connect();
  }
}

void _wireWs(WidgetRef ref) {
  final ws = ref.read(wsControllerProvider);
  ws.connection.listen((connected) {
    ref.read(appStatusProvider.notifier).setWsConnected(connected);
  });
  ws.events.listen((event) => _handleWsEvent(ref, event));
}

void _handleWsEvent(WidgetRef ref, WsEvent event) {
  final data = event.data;
  switch (event.signal) {
    case 'message::SendMessage':
      if (data is Map<String, dynamic>) {
        try {
          final msg = Message.fromJson(data);
          ref.read(historyProvider.notifier).addNew(msg);
        } catch (e) {
          debugPrint('SendMessage decode err: $e');
        }
      }
      break;
    case 'message::MessageDeleted':
      if (data is Map<String, dynamic>) {
        final channelId = data['channelId'] as String?;
        final messageId = data['messageId'] as String?;
        if (channelId != null && messageId != null) {
          ref
              .read(historyProvider.notifier)
              .removeMessage(channelId, messageId);
        }
      }
      break;
    case 'message::UpdateMessage':
      if (data is Map<String, dynamic>) {
        try {
          final msg = Message.fromJson(data);
          ref.read(historyProvider.notifier).updateMessage(msg);
        } catch (e) {
          debugPrint('UpdateMessage decode err: $e');
        }
      }
      break;
    case 'message::AddReaction':
    case 'message::DeleteReaction':
      if (data is Map<String, dynamic>) {
        final channelId = data['channelId'] as String?;
        final messageId = data['messageId'] as String?;
        final emojiCode = data['emojiCode'] as String?;
        final actorId = data['userId'] as String? ?? '';
        if (channelId == null || messageId == null || emojiCode == null) break;
        final myId = ref.read(myUserProvider).id;
        ref.read(historyProvider.notifier).applyReaction(
              channelId: channelId,
              messageId: messageId,
              emojiCode: emojiCode,
              add: event.signal == 'message::AddReaction',
              actorUserId: actorId,
              myUserId: myId,
            );
      }
      break;
    case 'inbox::Added':
      if (data is Map<String, dynamic>) {
        try {
          final type = data['type'] as String? ?? 'mention';
          final msg =
              Message.fromJson(data['message'] as Map<String, dynamic>);
          ref.read(inboxProvider.notifier).add(InboxItem(
                type: type,
                userId: '',
                messageId: msg.id,
                message: msg,
                happenedAt: msg.createdAt,
              ));
        } catch (e) {
          debugPrint('inbox::Added decode err: $e');
        }
      }
      break;
    case 'inbox::Deleted':
      if (data is Map<String, dynamic>) {
        final id = data['messageId'] as String?;
        if (id != null) {
          ref.read(inboxProvider.notifier).removeByMessage(id);
        }
      }
      break;
    case 'user::Connected':
      if (data is Map<String, dynamic>) {
        final id = data['userId'] as String?;
        if (id != null) ref.read(onlineUsersProvider.notifier).add(id);
      }
      break;
    case 'user::Disconnected':
      if (data is Map<String, dynamic>) {
        final id = data['userId'] as String?;
        if (id != null) ref.read(onlineUsersProvider.notifier).remove(id);
      }
      break;
    case 'channel::UpdateChannel':
      // Left for future implementation.
      break;
    default:
      break;
  }
}
