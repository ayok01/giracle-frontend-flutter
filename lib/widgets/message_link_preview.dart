import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/message.dart';
import '../stores/providers.dart';
import 'authed_image.dart';
import 'message_text.dart';

/// Compact card that previews a message referenced by a `&<channel:message>`
/// token in another message. Mirrors Solid `MessageLinkPreview.tsx`.
class MessageLinkPreview extends ConsumerStatefulWidget {
  const MessageLinkPreview({
    super.key,
    required this.channelId,
    required this.messageId,
    required this.baseUrl,
  });
  final String channelId;
  final String messageId;
  final String baseUrl;

  @override
  ConsumerState<MessageLinkPreview> createState() =>
      _MessageLinkPreviewState();
}

class _MessageLinkPreviewState extends ConsumerState<MessageLinkPreview> {
  Message? _msg;
  bool _loading = false;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  void _hydrate() {
    // Look in the fetch cache first, then any loaded channel history, then
    // fall back to a network fetch.
    final cache = ref.read(messageCacheProvider);
    final hit = cache[widget.messageId];
    if (hit != null) {
      _msg = hit;
      return;
    }
    for (final entry in ref.read(historyProvider).values) {
      for (final m in entry.history) {
        if (m.id == widget.messageId) {
          _msg = m;
          ref.read(messageCacheProvider.notifier).upsert(m);
          return;
        }
      }
    }
    setState(() => _loading = true);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final res = await ref
          .read(messageApiProvider)
          .getOne(widget.channelId, widget.messageId);
      if (!mounted) return;
      if (res == null) {
        setState(() {
          _loading = false;
          _notFound = true;
        });
        ref
            .read(messageCacheProvider.notifier)
            .markDeleted(widget.messageId);
      } else {
        ref.read(messageCacheProvider.notifier).upsert(res);
        setState(() {
          _msg = res;
          _loading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return _wrap(child: const _Loading());
    }
    if (_notFound) {
      return _wrap(
        child: Row(
          children: [
            Icon(Icons.link_off, size: 16, color: theme.colorScheme.outline),
            const SizedBox(width: 6),
            Text('メッセージが見つかりません', style: theme.textTheme.bodySmall),
          ],
        ),
      );
    }
    final msg = _msg;
    if (msg == null) return const SizedBox.shrink();

    final sender = ref.watch(userCacheProvider)[msg.userId];
    final channel = ref.watch(channelInfoProvider)[msg.channelId];
    final senderName = sender?.name ?? msg.userId;
    final channelName = channel?.name ?? msg.channelId;
    final trimmed = msg.content.length > 150
        ? '${msg.content.substring(0, 150)}...'
        : msg.content;
    final ts = DateFormat('yyyy/M/d HH:mm').format(msg.createdAt.toLocal());

    return _wrap(
      child: InkWell(
        onTap: () => context.go('/app/channel/${msg.channelId}'),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AuthedAvatar(
                    url: '${widget.baseUrl}/user/icon/${msg.userId}',
                    radius: 12,
                    fallback: Text(
                      senderName.isNotEmpty
                          ? senderName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(senderName,
                      style:
                          const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 6),
                  Text('・', style: theme.textTheme.bodySmall),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '#$channelName',
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Divider(),
              MessageText(content: trimmed),
              if (msg.files.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.attach_file,
                        size: 14, color: theme.colorScheme.outline),
                    const SizedBox(width: 4),
                    Text('${msg.files.length} 件の添付ファイル',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(ts, style: theme.textTheme.bodySmall),
                  if (msg.isEdited)
                    Text(' ・ 編集済み', style: theme.textTheme.bodySmall),
                  const Spacer(),
                  Icon(Icons.arrow_forward,
                      size: 14, color: theme.colorScheme.outline),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _wrap({required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 384),
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(12),
      child: Row(
        children: [
          SizedBox(
            height: 14,
            width: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text('メッセージを取得中…'),
        ],
      ),
    );
  }
}
