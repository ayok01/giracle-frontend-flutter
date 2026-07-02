import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';
import '../stores/providers.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _nameCtl = TextEditingController();
  final _introCtl = TextEditingController();
  final _curPassCtl = TextEditingController();
  final _newPassCtl = TextEditingController();
  bool _busyProfile = false;
  bool _busyPass = false;
  String? _profileMsg;
  String? _passMsg;

  @override
  void initState() {
    super.initState();
    final me = ref.read(myUserProvider);
    _nameCtl.text = me.name;
    _introCtl.text = me.selfIntroduction;
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _introCtl.dispose();
    _curPassCtl.dispose();
    _newPassCtl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() {
      _busyProfile = true;
      _profileMsg = null;
    });
    try {
      await ref.read(userApiProvider).updateProfile(
            name: _nameCtl.text.trim(),
            selfIntroduction: _introCtl.text.trim(),
          );
      final me = ref.read(myUserProvider);
      ref.read(myUserProvider.notifier).set(me.copyWith(
            name: _nameCtl.text.trim(),
            selfIntroduction: _introCtl.text.trim(),
          ));
      setState(() => _profileMsg = '保存しました');
    } on ApiException catch (e) {
      setState(() => _profileMsg = 'エラー: ${e.message}');
    } finally {
      if (mounted) setState(() => _busyProfile = false);
    }
  }

  Future<void> _changePassword() async {
    if (_curPassCtl.text.isEmpty || _newPassCtl.text.isEmpty) return;
    setState(() {
      _busyPass = true;
      _passMsg = null;
    });
    try {
      await ref
          .read(userApiProvider)
          .changePassword(_curPassCtl.text, _newPassCtl.text);
      _curPassCtl.clear();
      _newPassCtl.clear();
      setState(() => _passMsg = 'パスワードを変更しました');
    } on ApiException catch (e) {
      setState(() => _passMsg = 'エラー: ${e.message}');
    } finally {
      if (mounted) setState(() => _busyPass = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/app/config'),
        ),
        title: const Text('プロフィール'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('プロフィール',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtl,
            decoration: const InputDecoration(labelText: '表示名'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _introCtl,
            decoration: const InputDecoration(labelText: '自己紹介'),
            minLines: 2,
            maxLines: 6,
          ),
          if (_profileMsg != null) ...[
            const SizedBox(height: 8),
            Text(_profileMsg!),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busyProfile ? null : _saveProfile,
            child: _busyProfile
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('プロフィールを保存'),
          ),
          const Divider(height: 40),
          Text('パスワード変更',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _curPassCtl,
            decoration: const InputDecoration(labelText: '現在のパスワード'),
            obscureText: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newPassCtl,
            decoration: const InputDecoration(labelText: '新しいパスワード'),
            obscureText: true,
          ),
          if (_passMsg != null) ...[
            const SizedBox(height: 8),
            Text(_passMsg!),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busyPass ? null : _changePassword,
            child: _busyPass
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('パスワードを変更'),
          ),
        ],
      ),
    );
  }
}
