import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../stores/providers.dart';

class GiracleSidebar extends ConsumerWidget {
  const GiracleSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(myUserProvider);
    final serverInfo = ref.watch(serverInfoProvider);
    final status = ref.watch(appStatusProvider);
    final onlineCount = ref.watch(onlineUsersProvider).length;
    final channels = ref.watch(channelListProvider);
    final joinedIds = me.channelJoin.map((e) => e.channelId).toSet();
    final joined = channels.where((c) => joinedIds.contains(c.id)).toList();

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              title: Text(serverInfo.name.isEmpty ? 'Giracle' : serverInfo.name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle,
                      size: 10,
                      color: status.wsConnected ? Colors.green : Colors.orange),
                  const SizedBox(width: 6),
                  Text(status.wsConnected
                      ? 'オンライン $onlineCount'
                      : '再接続中...'),
                ],
              ),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/app/online-user');
              },
            ),
            const Divider(),
            ListTile(
              leading: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_outlined),
                  Consumer(
                    builder: (_, ref, __) {
                      final count = ref.watch(inboxProvider).length;
                      if (count == 0) return const SizedBox.shrink();
                      return Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints:
                              const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              title: const Text('通知'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/app/inbox');
              },
            ),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('チャンネル一覧'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/app/channel-browser');
              },
            ),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('検索'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/app/search');
              },
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('参加チャンネル'),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: joined.length,
                itemBuilder: (_, i) {
                  final c = joined[i];
                  return ListTile(
                    leading: const Icon(Icons.tag),
                    title: Text(c.name),
                    onTap: () {
                      Navigator.of(context).pop();
                      context.go('/app/channel/${c.id}');
                    },
                  );
                },
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: Text(me.name.isEmpty ? '設定' : '${me.name} / 設定'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/app/config');
              },
            ),
          ],
        ),
      ),
    );
  }
}
