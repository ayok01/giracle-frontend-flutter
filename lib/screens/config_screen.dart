import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';
import '../stores/providers.dart';

class ConfigScreen extends ConsumerWidget {
  const ConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(myUserProvider);
    final api = ref.watch(apiClientProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/app'),
        ),
        title: const Text('設定'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: Text(me.name),
            subtitle: Text(me.id.isEmpty ? '未ログイン' : me.id),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/app/config/profile'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.dns),
            title: const Text('サーバー URL'),
            subtitle: Text(api.baseUrl),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('ログアウト'),
            onTap: () async {
              await ref.read(wsControllerProvider).close();
              await ref.read(apiClientProvider).clearCookies();
              if (context.mounted) context.go('/auth');
            },
          ),
        ],
      ),
    );
  }
}
