import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../stores/providers.dart';
import '../widgets/sidebar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverInfo = ref.watch(serverInfoProvider);
    final channels = ref.watch(channelListProvider);
    final me = ref.watch(myUserProvider);
    final joinedIds = me.channelJoin.map((e) => e.channelId).toSet();
    final joined = channels.where((c) => joinedIds.contains(c.id)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(serverInfo.name.isEmpty ? 'Giracle' : serverInfo.name),
      ),
      drawer: const GiracleSidebar(),
      body: joined.isEmpty
          ? const Center(child: Text('参加中のチャンネルはありません'))
          : ListView.separated(
              itemCount: joined.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final c = joined[i];
                return ListTile(
                  leading: const Icon(Icons.tag),
                  title: Text(c.name),
                  subtitle: c.description.isEmpty
                      ? null
                      : Text(
                          c.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                  onTap: () => context.go('/app/channel/${c.id}'),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.list),
        label: const Text('チャンネル一覧'),
        onPressed: () => context.go('/app/channel-browser'),
      ),
    );
  }
}
