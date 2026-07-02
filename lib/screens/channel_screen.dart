import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../models/message.dart';
import '../stores/providers.dart';
import '../widgets/authed_image.dart';
import '../widgets/message_content.dart';
import '../widgets/message_link_preview.dart';
import '../widgets/message_text.dart';
import '../widgets/user_profile_sheet.dart';

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

  Message? _replyingTo;
  Message? _editing;

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
      _replyingTo = null;
      _editing = null;
      _textCtl.clear();
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
      try {
        final info = await ref.read(channelApiProvider).info(widget.channelId);
        ref.read(channelInfoProvider.notifier).upsert(info);
      } catch (_) {}
      // If we hit the latest, mark this channel read.
      if (res.history.isNotEmpty && res.atEnd) {
        final newest = res.history.first.createdAt.toIso8601String();
        _markRead(newest);
      }
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

  Future<void> _submit() async {
    final text = _textCtl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      if (_editing != null) {
        await ref
            .read(messageApiProvider)
            .edit(_editing!.id, text);
      } else {
        final msg = await ref.read(messageApiProvider).send(
              widget.channelId,
              text,
              replyingMessageId: _replyingTo?.id,
            );
        ref.read(historyProvider.notifier).addNew(msg);
      }
      _textCtl.clear();
      setState(() {
        _editing = null;
        _replyingTo = null;
      });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _renameChannel() async {
    final current = ref.read(channelInfoProvider)[widget.channelId];
    if (current == null) return;
    final nameCtl = TextEditingController(text: current.name);
    final descCtl = TextEditingController(text: current.description);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('チャンネルを編集'),
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
              decoration: const InputDecoration(labelText: '説明'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(channelApiProvider).update(
            channelId: widget.channelId,
            name: nameCtl.text.trim(),
            description: descCtl.text.trim(),
          );
      final info = await ref.read(channelApiProvider).info(widget.channelId);
      ref.read(channelInfoProvider.notifier).upsert(info);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _leaveChannel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('チャンネルから抜ける'),
        content: const Text('このチャンネルの購読を解除しますか?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('抜ける'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(channelApiProvider).leave(widget.channelId);
      final myId = ref.read(myUserProvider).id;
      if (myId.isNotEmpty) {
        final me = await ref.read(userApiProvider).info(myId);
        ref.read(myUserProvider.notifier).set(me);
      }
      if (mounted) context.go('/app');
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _deleteChannel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('チャンネルを削除'),
        content:
            const Text('この操作は取り消せません。チャンネルとメッセージが失われます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(channelApiProvider).delete(widget.channelId);
      ref.read(channelListProvider.notifier).remove(widget.channelId);
      if (mounted) context.go('/app');
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _markRead(String readTime) async {
    try {
      await ref
          .read(messageApiProvider)
          .updateReadTime(widget.channelId, readTime);
      ref
          .read(readTimeProvider.notifier)
          .update(widget.channelId, readTime);
      ref
          .read(hasNewMessageProvider.notifier)
          .mark(widget.channelId, false);
    } catch (_) {}
  }

  Future<void> _joinChannel() async {
    try {
      await ref.read(channelApiProvider).join(widget.channelId);
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

  void _startReply(Message m) {
    setState(() {
      _editing = null;
      _replyingTo = m;
    });
  }

  void _startEdit(Message m) {
    setState(() {
      _editing = m;
      _replyingTo = null;
      _textCtl.text = m.content;
      _textCtl.selection =
          TextSelection.collapsed(offset: _textCtl.text.length);
    });
  }

  Future<void> _delete(Message m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('メッセージを削除'),
        content: const Text('この操作は取り消せません。削除しますか?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(messageApiProvider).delete(m.id);
      ref.read(historyProvider.notifier).removeMessage(m.channelId, m.id);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  void _openActions(Message m) {
    final myId = ref.read(myUserProvider).id;
    final isMine = m.userId == myId;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('返信'),
              onTap: () {
                Navigator.pop(ctx);
                _startReply(m);
              },
            ),
            ListTile(
              leading: const Icon(Icons.emoji_emotions_outlined),
              title: const Text('リアクションを追加'),
              onTap: () {
                Navigator.pop(ctx);
                _openReactionPicker(m);
              },
            ),
            if (isMine)
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('編集'),
                onTap: () {
                  Navigator.pop(ctx);
                  _startEdit(m);
                },
              ),
            if (isMine)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('削除'),
                onTap: () {
                  Navigator.pop(ctx);
                  _delete(m);
                },
              ),
          ],
        ),
      ),
    );
  }

  static const List<String> _quickReactions = [
    '👍', '❤️', '😂', '😮', '😢', '🎉',
    '🙏', '🔥', '✅', '👀', '💯', '👏',
  ];

  Future<void> _openReactionPicker(Message m) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickReactions
                .map((e) => InkWell(
                      onTap: () => Navigator.pop(ctx, e),
                      borderRadius: BorderRadius.circular(24),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(e, style: const TextStyle(fontSize: 24)),
                      ),
                    ))
                .toList(),
          ),
        ),
      ),
    );
    if (chosen == null) return;
    await _toggleReaction(m, chosen, forceAdd: true);
  }

  Future<void> _toggleReaction(
    Message m,
    String emojiCode, {
    bool forceAdd = false,
  }) async {
    final existing = m.reactionSummary
        .where((r) => r.emojiCode == emojiCode)
        .toList();
    final alreadyMine = existing.isNotEmpty && existing.first.includingYou;
    final shouldRemove = alreadyMine && !forceAdd;
    try {
      if (shouldRemove) {
        await ref
            .read(messageApiProvider)
            .removeReaction(m.channelId, m.id, emojiCode);
      } else if (!alreadyMine) {
        // Solid enforces at most 10 self reactions per message.
        final myCount =
            m.reactionSummary.where((r) => r.includingYou).length;
        if (myCount >= 10) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('同一メッセージへのリアクションは 10 件までです'),
              ),
            );
          }
          return;
        }
        await ref
            .read(messageApiProvider)
            .addReaction(m.channelId, m.id, emojiCode);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Message? _findMessage(String id) {
    final entry = ref.read(historyProvider)[widget.channelId];
    if (entry == null) return null;
    for (final m in entry.history) {
      if (m.id == id) return m;
    }
    return null;
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
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              switch (v) {
                case 'rename':
                  _renameChannel();
                  break;
                case 'leave':
                  _leaveChannel();
                  break;
                case 'delete':
                  _deleteChannel();
                  break;
              }
            },
            itemBuilder: (_) => [
              if (joined)
                const PopupMenuItem(
                    value: 'rename', child: Text('チャンネル名を変更')),
              if (joined)
                const PopupMenuItem(
                    value: 'leave', child: Text('チャンネルから抜ける')),
              const PopupMenuItem(
                  value: 'delete', child: Text('チャンネルを削除')),
            ],
          ),
        ],
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
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }
                      final m = entry.history[i];
                      final older = i + 1 < entry.history.length
                          ? entry.history[i + 1]
                          : null;
                      final sameSenderAsOlder = older != null &&
                          older.userId == m.userId &&
                          m.createdAt
                                  .difference(older.createdAt)
                                  .inMinutes
                                  .abs() <=
                              5;
                      final replyTarget = m.replyingMessageId == null
                          ? null
                          : _findMessage(m.replyingMessageId!);
                      final emojiMap = ref.watch(customEmojiProvider);
                      return MessageBubble(
                        message: m,
                        senderName: userCache[m.userId]?.name ?? m.userId,
                        baseUrl: ref.read(apiClientProvider).baseUrl,
                        customEmojiCodes: emojiMap.keys.toSet(),
                        showAvatar: !sameSenderAsOlder,
                        replyTarget: replyTarget,
                        replyTargetSenderName: replyTarget == null
                            ? null
                            : userCache[replyTarget.userId]?.name ??
                                replyTarget.userId,
                        onFetchUser: () => _fetchUser(m.userId),
                        onLongPress: () => _openActions(m),
                        onToggleReaction: (code) => _toggleReaction(m, code),
                        onAddReaction: () => _openReactionPicker(m),
                        onSenderTap: () =>
                            showUserProfileSheet(context, ref, m.userId),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: joined
                ? _buildComposer(userCache)
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

  Widget _buildComposer(Map<String, dynamic> userCache) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_editing != null)
            _ComposerBanner(
              icon: Icons.edit,
              label: '編集中',
              detail: _editing!.content,
              onClear: () {
                setState(() => _editing = null);
                _textCtl.clear();
              },
            ),
          if (_replyingTo != null)
            _ComposerBanner(
              icon: Icons.reply,
              label: '返信先: '
                  '${(userCache[_replyingTo!.userId] as dynamic)?.name ?? _replyingTo!.userId}',
              detail: _replyingTo!.content,
              onClear: () => setState(() => _replyingTo = null),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _textCtl,
                  minLines: 1,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: _editing != null
                        ? 'メッセージを編集'
                        : 'メッセージを入力',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: _sending
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(_editing != null ? Icons.check : Icons.send),
                onPressed: _sending ? null : _submit,
              ),
            ],
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

class _ComposerBanner extends StatelessWidget {
  const _ComposerBanner({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onClear,
  });
  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.senderName,
    required this.baseUrl,
    required this.customEmojiCodes,
    required this.showAvatar,
    required this.onFetchUser,
    required this.onLongPress,
    required this.onToggleReaction,
    required this.onAddReaction,
    required this.onSenderTap,
    this.replyTarget,
    this.replyTargetSenderName,
  });

  final Message message;
  final String senderName;
  final String baseUrl;
  final Set<String> customEmojiCodes;
  final bool showAvatar;
  final Message? replyTarget;
  final String? replyTargetSenderName;
  final VoidCallback onFetchUser;
  final VoidCallback onLongPress;
  final ValueChanged<String> onToggleReaction;
  final VoidCallback onAddReaction;
  final VoidCallback onSenderTap;

  String _smartTime(DateTime dt) {
    final t = dt.toLocal();
    final now = DateTime.now();
    if (t.year != now.year) return DateFormat('yyyy/M/d HH:mm').format(t);
    if (t.month != now.month || t.day != now.day) {
      return DateFormat('M/d HH:mm').format(t);
    }
    return DateFormat('HH:mm:ss').format(t);
  }

  @override
  Widget build(BuildContext context) {
    onFetchUser();
    final theme = Theme.of(context);
    // avatar column: 40px + 5px gap = 45px (matches Solid `w-[40px]` + gap).
    const avatarColumn = 40.0;
    const gap = 5.0;

    return InkWell(
      onLongPress: onLongPress,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            12, showAvatar ? 8 : 1, 12, 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (replyTarget != null)
              Padding(
                padding: const EdgeInsets.only(
                    left: avatarColumn + gap, bottom: 2),
                child: _ReplyLine(
                  target: replyTarget!,
                  senderName:
                      replyTargetSenderName ?? replyTarget!.userId,
                  baseUrl: baseUrl,
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: avatarColumn,
                  child: showAvatar
                      ? GestureDetector(
                          onTap: onSenderTap,
                          child: AuthedAvatar(
                            url: '$baseUrl/user/icon/${message.userId}',
                            radius: 20,
                            fallback: Text(
                              message.userId.isNotEmpty
                                  ? message.userId
                                      .substring(0, message.userId.length > 2 ? 2 : 1)
                                      .toUpperCase()
                                  : '?',
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(width: gap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showAvatar)
                        InkWell(
                          onTap: onSenderTap,
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  senderName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _smartTime(message.createdAt),
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      if (message.content.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(
                              top: showAvatar ? 2 : 0),
                          child: Consumer(
                            builder: (_, ref, __) => MessageText(
                              content: message.content,
                              myUserId: ref.watch(myUserProvider).id,
                            ),
                          ),
                        ),
                      ...extractMessageLinks(message.content).map(
                        (pair) => MessageLinkPreview(
                          channelId: pair.$1,
                          messageId: pair.$2,
                          baseUrl: baseUrl,
                        ),
                      ),
                      if (message.files.isNotEmpty)
                        MessageAttachments(
                            files: message.files, baseUrl: baseUrl),
                      if (message.urlPreviews.isNotEmpty)
                        MessageUrlPreviews(previews: message.urlPreviews),
                      if (message.isEdited)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '編集済み',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ),
                      if (message.reactionSummary.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              ...message.reactionSummary.map((r) {
                                final isCustom =
                                    customEmojiCodes.contains(r.emojiCode);
                                return _ReactionChip(
                                  code: r.emojiCode,
                                  count: r.count,
                                  includingYou: r.includingYou,
                                  isCustom: isCustom,
                                  baseUrl: baseUrl,
                                  onTap: () =>
                                      onToggleReaction(r.emojiCode),
                                );
                              }),
                              InkWell(
                                onTap: onAddReaction,
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: theme.colorScheme.outlineVariant),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.add, size: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplyLine extends StatelessWidget {
  const _ReplyLine({
    required this.target,
    required this.senderName,
    required this.baseUrl,
  });
  final Message target;
  final String senderName;
  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.subdirectory_arrow_right,
            size: 16, color: theme.colorScheme.outline),
        const SizedBox(width: 4),
        AuthedAvatar(
          url: '$baseUrl/user/icon/${target.userId}',
          radius: 10,
          fallback: Text(
            target.userId.isNotEmpty ? target.userId[0].toUpperCase() : '?',
            style: const TextStyle(fontSize: 10),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          senderName,
          style: theme.textTheme.bodySmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            target.content,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ),
      ],
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    required this.code,
    required this.count,
    required this.includingYou,
    required this.isCustom,
    required this.baseUrl,
    required this.onTap,
  });
  final String code;
  final int count;
  final bool includingYou;
  final bool isCustom;
  final String baseUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: includingYou
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          border: Border.all(
            color: includingYou
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCustom)
              SizedBox(
                height: 18,
                child: AuthedNetworkImage(
                  url: '$baseUrl/server/custom-emoji/$code',
                  height: 18,
                  errorWidget: (_, __) => Text(':$code:'),
                ),
              )
            else
              Text(code, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
