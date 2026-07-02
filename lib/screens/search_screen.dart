import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../models/message.dart';
import '../stores/providers.dart';

const _searchPageSize = 30;
const _channelFilterAll = '__all__';

enum _SortOrder { desc, asc }
enum _FileFilter { any, withFile, withoutFile }

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _queryCtl = TextEditingController();
  String _channelId = _channelFilterAll;
  _SortOrder _sort = _SortOrder.desc;
  _FileFilter _fileFilter = _FileFilter.any;

  List<Message> _results = [];
  bool _busy = false;
  bool _searched = false;
  int _loadIndex = 1;
  int _lastFetched = 0;
  String _lastKey = '';

  @override
  void dispose() {
    _queryCtl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _currentCondition() => {
        'content': _queryCtl.text.trim(),
        'channelId': _channelId == _channelFilterAll ? null : _channelId,
        'sort': _sort.name,
        'hasFileAttachment': switch (_fileFilter) {
          _FileFilter.any => null,
          _FileFilter.withFile => true,
          _FileFilter.withoutFile => false,
        },
      };

  Future<void> _search({bool append = false}) async {
    if (_busy) return;
    final nextIndex = append ? _loadIndex + 1 : 1;
    final key = _currentCondition().toString();
    setState(() => _busy = true);
    try {
      final cond = _currentCondition();
      final res = await ref.read(messageApiProvider).search(
            content: cond['content'] as String?,
            channelId: cond['channelId'] as String?,
            sort: cond['sort'] as String?,
            hasFileAttachment: cond['hasFileAttachment'] as bool?,
            loadIndex: nextIndex,
          );
      final filtered = res.where((m) => m.userId != 'SYSTEM').toList();
      setState(() {
        _lastFetched = res.length;
        if (append) {
          _results = [..._results, ...filtered];
          _loadIndex = nextIndex;
        } else {
          _loadIndex = 1;
          _results = filtered;
        }
        _lastKey = key;
        _searched = true;
      });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _canLoadMore =>
      _searched &&
      _lastFetched == _searchPageSize &&
      _lastKey == _currentCondition().toString();

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(myUserProvider);
    final channels = ref.watch(channelInfoProvider);
    final userCache = ref.watch(userCacheProvider);
    final channelOptions = [
      _channelFilterAll,
      ...{for (final c in me.channelJoin) c.channelId},
    ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/app'),
        ),
        title: const Text('メッセージ検索'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryCtl,
                    decoration: const InputDecoration(
                      labelText: 'メッセージ文を検索',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _busy ? null : () => _search(),
                  icon: _busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.search),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                DropdownButton<String>(
                  value: channelOptions.contains(_channelId)
                      ? _channelId
                      : _channelFilterAll,
                  onChanged: (v) =>
                      setState(() => _channelId = v ?? _channelFilterAll),
                  items: channelOptions
                      .map((id) => DropdownMenuItem(
                            value: id,
                            child: Text(
                              id == _channelFilterAll
                                  ? 'すべてのチャンネル'
                                  : channels[id]?.name ?? id,
                            ),
                          ))
                      .toList(),
                ),
                DropdownButton<_SortOrder>(
                  value: _sort,
                  onChanged: (v) => setState(() => _sort = v ?? _SortOrder.desc),
                  items: const [
                    DropdownMenuItem(value: _SortOrder.desc, child: Text('新しい順')),
                    DropdownMenuItem(value: _SortOrder.asc, child: Text('古い順')),
                  ],
                ),
                DropdownButton<_FileFilter>(
                  value: _fileFilter,
                  onChanged: (v) =>
                      setState(() => _fileFilter = v ?? _FileFilter.any),
                  items: const [
                    DropdownMenuItem(value: _FileFilter.any, child: Text('指定なし')),
                    DropdownMenuItem(
                        value: _FileFilter.withFile, child: Text('添付あり')),
                    DropdownMenuItem(
                        value: _FileFilter.withoutFile, child: Text('添付なし')),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 8),
          Expanded(
            child: !_searched
                ? const Center(child: Text('メッセージ文を検索してください。'))
                : _results.isEmpty
                    ? const Center(child: Text('結果が見つかりませんでした...'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _results.length + (_canLoadMore ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i >= _results.length) {
                            return Padding(
                              padding: const EdgeInsets.all(8),
                              child: OutlinedButton(
                                onPressed:
                                    _busy ? null : () => _search(append: true),
                                child: const Text('もっと読み込む'),
                              ),
                            );
                          }
                          final m = _results[i];
                          final senderName =
                              userCache[m.userId]?.name ?? m.userId;
                          final channelName =
                              channels[m.channelId]?.name ?? m.channelId;
                          return Card(
                            child: ListTile(
                              title: Text('$senderName · #$channelName'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(m.content,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('yyyy/MM/dd HH:mm')
                                        .format(m.createdAt.toLocal()),
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () =>
                                  context.go('/app/channel/${m.channelId}'),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
