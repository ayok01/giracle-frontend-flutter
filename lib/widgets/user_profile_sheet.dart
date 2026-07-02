import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../stores/providers.dart';

Future<void> showUserProfileSheet(
    BuildContext context, WidgetRef ref, String userId) async {
  var user = ref.read(userCacheProvider)[userId];
  if (user == null) {
    try {
      user = await ref.read(userApiProvider).info(userId);
      ref.read(userCacheProvider.notifier).upsert(user);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    }
  }

  if (!context.mounted) return;
  final base = ref.read(apiClientProvider).baseUrl;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: CachedNetworkImageProvider(
                      '$base/user/icon/${user!.id}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name, style: theme.textTheme.titleMedium),
                        Text('@${user.id}', style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (user.selfIntroduction.isNotEmpty) ...[
                Text('自己紹介', style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                SelectableText(user.selfIntroduction),
                const SizedBox(height: 16),
              ],
              Text('参加チャンネル: ${user.channelJoin.length} 件',
                  style: theme.textTheme.bodySmall),
              Text('割当ロール: ${user.roleLink.length} 件',
                  style: theme.textTheme.bodySmall),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    },
  );
}
