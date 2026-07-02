import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';
import '../stores/providers.dart';

class OnlineUsersScreen extends ConsumerStatefulWidget {
  const OnlineUsersScreen({super.key});

  @override
  ConsumerState<OnlineUsersScreen> createState() => _OnlineUsersScreenState();
}

class _OnlineUsersScreenState extends ConsumerState<OnlineUsersScreen> {
  final _queryCtl = TextEditingController();
  String _q = '';

  @override
  void initState() {
    super.initState();
    _queryCtl.addListener(() => setState(() => _q = _queryCtl.text.trim()));
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    try {
      final ids = await ref.read(userApiProvider).onlineUsers();
      ref.read(onlineUsersProvider.notifier).set(ids);
    } catch (_) {}
  }

  Future<void> _prefetch(String id) async {
    if (ref.read(userCacheProvider).containsKey(id)) return;
    try {
      final u = await ref.read(userApiProvider).info(id);
      ref.read(userCacheProvider.notifier).upsert(u);
    } catch (_) {}
  }

  @override
  void dispose() {
    _queryCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(onlineUsersProvider).toList();
    final userCache = ref.watch(userCacheProvider);
    final base = ref.watch(apiClientProvider).baseUrl;

    final filtered = _q.isEmpty
        ? online
        : online.where((id) {
            final u = userCache[id];
            return (u?.name ?? id).toLowerCase().contains(_q.toLowerCase());
          }).toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/app'),
        ),
        title: const Text('オンラインユーザー'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(child: Text('${online.length}人')),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                controller: _queryCtl,
                decoration: const InputDecoration(
                  labelText: 'ユーザーを検索',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final id = filtered[i];
                  final user = userCache[id];
                  _prefetch(id);
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage:
                          CachedNetworkImageProvider('$base/user/icon/$id'),
                      child: user == null
                          ? Text(id.isNotEmpty ? id[0].toUpperCase() : '?')
                          : null,
                    ),
                    title: Text(user?.name ?? id),
                    subtitle: Row(
                      children: const [
                        Icon(Icons.circle, size: 8, color: Colors.green),
                        SizedBox(width: 6),
                        Text('オンライン'),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
