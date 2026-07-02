import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../stores/providers.dart';
import 'user_profile_sheet.dart';

/// One matched token in a message body. Order preserved by index.
class _Token {
  final int index;
  final int length;
  final String type; // link | messageLink | mention | channel | code
  final String value; // meaning depends on type

  const _Token(this.index, this.length, this.type, this.value);
}

/// Uuid-like id used by all `@<id>`, `#<id>`, `&<c:m>` tokens.
final _idPattern = RegExp(r'[0-9a-fA-F-]{8,}');

final _urlPattern = RegExp(
  r'(\b(https?|ftp|file)://[-A-Za-z0-9+&@#/%?=~_|!:,.;()*\[\]]*[-A-Za-z0-9+&@#/%=~_|])',
);
final _messageLinkPattern =
    RegExp(r'&<([0-9a-fA-F-]{8,}):([0-9a-fA-F-]{8,})>');
final _mentionPattern = RegExp(r'@<([0-9a-fA-F-]{8,})>');
final _channelPattern = RegExp(r'#<([0-9a-fA-F-]{8,})>');
final _codePattern = RegExp(r'`([^`\n]+)`');

/// Extract the channel/message id pairs referenced from a message body.
List<(String channelId, String messageId)> extractMessageLinks(String body) {
  final out = <(String, String)>{};
  for (final m in _messageLinkPattern.allMatches(body)) {
    out.add((m.group(1)!, m.group(2)!));
  }
  return out.toList();
}

/// Rich-text view of a Giracle message body. Renders URLs, `@<id>`,
/// `#<id>` and `` `code` `` inline. Message-link tokens (`&<c:m>`) are
/// stripped — they're shown as a card underneath the body by
/// `MessageLinkPreview`, mirroring Solid's `MessageRender.tsx`.
class MessageText extends ConsumerWidget {
  const MessageText({super.key, required this.content, this.myUserId});
  final String content;
  final String? myUserId;

  List<_Token> _tokenize(String s) {
    final tokens = <_Token>[];
    void collect(RegExp re, String type) {
      for (final m in re.allMatches(s)) {
        String value;
        switch (type) {
          case 'messageLink':
            value = '${m.group(1)}/${m.group(2)}';
            break;
          case 'mention':
          case 'channel':
          case 'code':
            value = m.group(1)!;
            break;
          default:
            value = m.group(0)!;
        }
        tokens.add(_Token(m.start, m.end - m.start, type, value));
      }
    }

    collect(_urlPattern, 'link');
    collect(_messageLinkPattern, 'messageLink');
    collect(_mentionPattern, 'mention');
    collect(_channelPattern, 'channel');
    collect(_codePattern, 'code');
    tokens.sort((a, b) => a.index.compareTo(b.index));

    // Remove overlaps (keep the earliest).
    final filtered = <_Token>[];
    var lastEnd = 0;
    for (final t in tokens) {
      if (t.index < lastEnd) continue;
      filtered.add(t);
      lastEnd = t.index + t.length;
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (content.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final userCache = ref.watch(userCacheProvider);
    final channelInfo = ref.watch(channelInfoProvider);
    final tokens = _tokenize(content);

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final t in tokens) {
      if (t.index > cursor) {
        spans.add(TextSpan(text: content.substring(cursor, t.index)));
      }
      switch (t.type) {
        case 'link':
          spans.add(TextSpan(
            text: t.value,
            style: TextStyle(
              color: theme.colorScheme.primary,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () async {
                final uri = Uri.tryParse(t.value);
                if (uri == null) return;
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
          ));
          break;
        case 'mention':
          final id = t.value;
          final name = userCache[id]?.name ?? id;
          final isMe = id == myUserId;
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: _InlineBadge(
              text: '@$name',
              color: isMe
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainerHighest,
              foreground: isMe ? theme.colorScheme.onPrimary : null,
              onTap: () => showUserProfileSheet(context, ref, id),
            ),
          ));
          break;
        case 'channel':
          final id = t.value;
          final name = channelInfo[id]?.name ?? id;
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: _InlineBadge(
              text: '#$name',
              color: theme.colorScheme.surfaceContainerHighest,
              onTap: () => context.go('/app/channel/$id'),
            ),
          ));
          break;
        case 'code':
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                t.value,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: (theme.textTheme.bodyMedium?.fontSize ?? 14) - 1,
                ),
              ),
            ),
          ));
          break;
        case 'messageLink':
          // Stripped from body; a card is rendered underneath.
          break;
      }
      cursor = t.index + t.length;
    }
    if (cursor < content.length) {
      spans.add(TextSpan(text: content.substring(cursor)));
    }

    return SelectableText.rich(
      TextSpan(
        style: theme.textTheme.bodyMedium,
        children: spans,
      ),
    );
  }
}

class _InlineBadge extends StatelessWidget {
  const _InlineBadge({
    required this.text,
    required this.color,
    this.foreground,
    this.onTap,
  });
  final String text;
  final Color color;
  final Color? foreground;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: foreground,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
