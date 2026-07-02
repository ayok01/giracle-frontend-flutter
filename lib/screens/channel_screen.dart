import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../models/message.dart';
import '../stores/providers.dart';

class ChannelScreen extends ConsumerStatefulWidget {
  const ChannelScreen({super.key, required this.channelId});
  final String channelId;

  @override
  ConsumerState<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends ConsumerState<ChannelScreen> {
  final _textCtl = TextEditingController();
  final _scrollCtl = ScrollController();
  bool _sending = false;
  bool _loadingHistory = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitial());
    _scrollCtl.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant ChannelScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channelId != widget.channelId) {
      _loadInitial();
    }
  }

  @override
  void dispose() {
    _scrollCtl.removeListener(_onScroll);
    _scrollCtl.dispose();
    _textCtl.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    final entry = ref.read(historyProvider)[widget.channelId];
    if (entry != null && entry.history.isNotEmpty) return;
    setState(() => _loadingHistory = true);
    try {
      final res = await ref
          .read(channelApiProvider)
          .getHistory(widget.channelId, fetchLength: 30);
      ref.read(historyProvider.notifier).setHistory(
            widget.channelId,
            HistoryEntry(
              history: res.history,
              atTop: res.atTop,
              atEnd: res.atEnd,
            ),
          );
      // Ensure channel info populated.
      try {
        final info =
            await ref.read(channelApiProvider).info(widget.channelId);
        ref.read(channelInfoProvider.notifier).upsert(info);
      } catch (_) {}
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _loadOlder() async {
    if (_loadingHistory) return;
    final entry = ref.read(historyProvider)[widget.channelId];
    if (entry == null || entry.atTop || entry.history.isEmpty) return;
    setState(() => _loadingHistory = true);
    try {
      final oldest = entry.history.last;
      final res = await ref.read(channelApiProvider).getHistory(
            widget.channelId,
            messageIdFrom: oldest.id,
            fetchLength: 30,
            fetchDirection: 'older',
          );
      final combined = [
        ...entry.history,
        ...res.history.where((m) => m.id != oldest.id)
      ];
      ref.read(historyProvider.notifier).setHistory(
            widget.channelId,
            HistoryEntry(
              history: combined,
              atTop: res.atTop,
              atEnd: entry.atEnd,
            ),
          );
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  void _onScroll() {
    if (_scrollCtl.position.pixels >=
        _scrollCtl.position.maxScrollExtent - 200) {
      _loadOlder();
    }
  }

  Future<void> _send() async {
    final text = _textCtl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final msg =
          await ref.read(messageApiProvider).send(widget.channelId, text);
      ref.read(historyProvider.notifier).addNew(msg);
      _textCtl.clear();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _joinChannel() async {
    try {
      await ref.read(channelApiProvider).join(widget.channelId);
      // Refetch my user info so joined channels update.
      final myId = ref.read(myUserProvider).id;
      if (myId.isNotEmpty) {
        final me = await ref.read(userApiProvider).info(myId);
        ref.read(myUserProvider.notifier).set(me);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final channel = ref.watch(channelInfoProvider)[widget.channelId];
    final entry = ref.watch(historyProvider)[widget.channelId];
    final myUser = ref.watch(myUserProvider);
    final userCache = ref.watch(userCacheProvider);
    final joined =
        myUser.channelJoin.any((e) => e.channelId == widget.channelId);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/app'),
        ),
        title: Text(channel?.name ?? 'Loading...'),
      ),
      body: Column(
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          Expanded(
            child: entry == null
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollCtl,
                    reverse: true,
                    itemCount:
                        entry.history.length + (_loadingHistory ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i >= entry.history.length) {
                        return const Padding(
                          padding: EdgeInsets.all(12),
                          child: Center(
                              child: SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )),
                        );
                      }
                      final m = entry.history[i];
                      return _MessageBubble(
                        message: m,
                        senderName: userCache[m.userId]?.name ?? m.userId,
                        onFetchUser: () => _fetchUser(m.userId),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: joined
                ? _buildComposer()
                : Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.remove_red_eye_outlined),
                        const SizedBox(width: 8),
                        const Expanded(child: Text('チャンネルプレビュー中')),
                        FilledButton.icon(
                          icon: const Icon(Icons.login),
                          onPressed: _joinChannel,
                          label: const Text('参加する'),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _textCtl,
              minLines: 1,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'メッセージを入力',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            icon: _sending
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send),
            onPressed: _sending ? null : _send,
          ),
        ],
      ),
    );
  }

  Future<void> _fetchUser(String userId) async {
    if (ref.read(userCacheProvider).containsKey(userId)) return;
    try {
      final u = await ref.read(userApiProvider).info(userId);
      ref.read(userCacheProvider.notifier).upsert(u);
    } catch (_) {}
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.senderName,
    required this.onFetchUser,
  });

  final Message message;
  final String senderName;
  final VoidCallback onFetchUser;

  @override
  Widget build(BuildContext context) {
    onFetchUser();
    final ts = DateFormat('HH:mm').format(message.createdAt.toLocal());
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(senderName,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Text(ts, style: Theme.of(context).textTheme.bodySmall),
              if (message.isEdited) ...[
                const SizedBox(width: 4),
                Text('(編集済み)',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
          const SizedBox(height: 2),
          SelectableText(message.content),
          if (message.reactionSummary.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 4,
                children: message.reactionSummary
                    .map((r) => Chip(
                          padding: EdgeInsets.zero,
                          label: Text('${r.emojiCode} ${r.count}'),
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}
