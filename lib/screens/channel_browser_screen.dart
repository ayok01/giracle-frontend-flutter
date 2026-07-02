import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../stores/providers.dart';

class ChannelBrowserScreen extends ConsumerWidget {
  const ChannelBrowserScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(channelListProvider);
    final me = ref.watch(myUserProvider);
    final joinedIds = me.channelJoin.map((e) => e.channelId).toSet();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/app'),
        ),
        title: const Text('チャンネル一覧'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final list = await ref.read(channelApiProvider).list();
          ref.read(channelListProvider.notifier).set(list);
        },
        child: ListView.separated(
          itemCount: channels.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final c = channels[i];
            final joined = joinedIds.contains(c.id);
            return ListTile(
              leading: const Icon(Icons.tag),
              title: Text(c.name),
              subtitle: c.description.isEmpty
                  ? null
                  : Text(c.description,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: joined
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () => context.go('/app/channel/${c.id}'),
            );
          },
        ),
      ),
    );
  }
}
