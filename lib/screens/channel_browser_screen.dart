import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';
import '../stores/providers.dart';

class ChannelBrowserScreen extends ConsumerWidget {
  const ChannelBrowserScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    final list = await ref.read(channelApiProvider).list();
    ref.read(channelListProvider.notifier).set(list);
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final nameCtl = TextEditingController();
    final descCtl = TextEditingController();
    final created = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('チャンネルを作成'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtl,
              decoration: const InputDecoration(labelText: 'チャンネル名'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descCtl,
              decoration: const InputDecoration(labelText: '説明 (任意)'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameCtl.text.trim().isEmpty) return;
              try {
                final id = await ref
                    .read(channelApiProvider)
                    .create(nameCtl.text.trim(), descCtl.text.trim());
                if (ctx.mounted) Navigator.pop(ctx, id);
              } on ApiException catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx)
                      .showSnackBar(SnackBar(content: Text(e.message)));
                }
              }
            },
            child: const Text('作成'),
          ),
        ],
      ),
    );
    if (created != null) {
      await _refresh(ref);
      if (context.mounted) context.go('/app/channel/$created');
    }
  }

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
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('作成'),
        onPressed: () => _create(context, ref),
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
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
