import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../models/message.dart';
import '../stores/providers.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  bool _groupByChannel = false;

  Future<void> _markRead(InboxItem item) async {
    try {
      await ref.read(messageApiProvider).markInboxRead(item.messageId);
      ref.read(inboxProvider.notifier).removeByMessage(item.messageId);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inbox = ref.watch(inboxProvider);
    final channels = ref.watch(channelInfoProvider);
    final users = ref.watch(userCacheProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/app'),
        ),
        title: const Text('通知'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                const Text('チャンネル別'),
                Switch(
                  value: _groupByChannel,
                  onChanged: (v) => setState(() => _groupByChannel = v),
                ),
              ],
            ),
          ),
        ],
      ),
      body: inbox.isEmpty
          ? const _EmptyState()
          : _groupByChannel
              ? _ByChannel(inbox: inbox, channels: channels, users: users, onRead: _markRead)
              : _ByDate(inbox: inbox, channels: channels, users: users, onRead: _markRead),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bedtime, size: 48),
          SizedBox(height: 8),
          Text('通知はありません'),
        ],
      ),
    );
  }
}

class _ByDate extends StatelessWidget {
  const _ByDate({
    required this.inbox,
    required this.channels,
    required this.users,
    required this.onRead,
  });

  final List<InboxItem> inbox;
  final Map<String, dynamic> channels;
  final Map<String, dynamic> users;
  final void Function(InboxItem) onRead;

  @override
  Widget build(BuildContext context) {
    final sorted = [...inbox]
      ..sort((a, b) => b.happenedAt.compareTo(a.happenedAt));
    return ListView.separated(
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) => _InboxTile(
        item: sorted[i],
        channel: channels[sorted[i].message.channelId],
        sender: users[sorted[i].message.userId],
        onRead: onRead,
      ),
    );
  }
}

class _ByChannel extends StatelessWidget {
  const _ByChannel({
    required this.inbox,
    required this.channels,
    required this.users,
    required this.onRead,
  });

  final List<InboxItem> inbox;
  final Map<String, dynamic> channels;
  final Map<String, dynamic> users;
  final void Function(InboxItem) onRead;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<InboxItem>>{};
    for (final item in inbox) {
      groups.putIfAbsent(item.message.channelId, () => []).add(item);
    }
    final keys = groups.keys.toList();
    return ListView.builder(
      itemCount: keys.length,
      itemBuilder: (_, i) {
        final channelId = keys[i];
        final channel = channels[channelId];
        final items = groups[channelId]!
          ..sort((a, b) => b.happenedAt.compareTo(a.happenedAt));
        return ExpansionTile(
          initiallyExpanded: true,
          title: Text('#${channel?.name ?? channelId}'),
          subtitle: Text('${items.length} 件'),
          children: items
              .map((item) => _InboxTile(
                    item: item,
                    channel: channel,
                    sender: users[item.message.userId],
                    onRead: onRead,
                  ))
              .toList(),
        );
      },
    );
  }
}

class _InboxTile extends StatelessWidget {
  const _InboxTile({
    required this.item,
    required this.channel,
    required this.sender,
    required this.onRead,
  });
  final InboxItem item;
  final dynamic channel;
  final dynamic sender;
  final void Function(InboxItem) onRead;

  @override
  Widget build(BuildContext context) {
    final ts = DateFormat('MM/dd HH:mm').format(item.happenedAt.toLocal());
    final typeIcon = switch (item.type) {
      'reply' => Icons.reply,
      'mention' => Icons.alternate_email,
      _ => Icons.notifications,
    };
    final senderName = (sender?.name as String?) ?? item.message.userId;
    final channelName = (channel?.name as String?) ?? item.message.channelId;
    return ListTile(
      leading: Icon(typeIcon),
      title: Text('#$channelName · $senderName'),
      subtitle: Text(
        item.message.content,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(ts, style: Theme.of(context).textTheme.bodySmall),
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: '既読にする',
            onPressed: () => onRead(item),
          ),
        ],
      ),
      onTap: () => context.go('/app/channel/${item.message.channelId}'),
    );
  }
}
