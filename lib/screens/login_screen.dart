import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';
import '../config/env.dart';
import '../models/server.dart';
import '../stores/init_load.dart';
import '../stores/providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _serverCtl = TextEditingController();
  late final TabController _tabCtl;
  ServerInfo? _serverPreview;
  bool _loadingServer = false;
  String? _serverError;

  @override
  void initState() {
    super.initState();
    _tabCtl = TabController(length: 2, vsync: this);
    _serverCtl.text = ref.read(apiClientProvider).baseUrl;
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchServer());
  }

  @override
  void dispose() {
    _serverCtl.dispose();
    _tabCtl.dispose();
    super.dispose();
  }

  Future<void> _fetchServer() async {
    final api = ref.read(apiClientProvider);
    final entered = _serverCtl.text.trim();
    if (entered.isNotEmpty) {
      await api.setBaseUrl(entered);
      // Reflect the normalized value (may have appended /api) back to the field.
      _serverCtl.text = api.baseUrl;
    }
    setState(() {
      _loadingServer = true;
      _serverError = null;
    });
    try {
      final res = await ref.read(serverApiProvider).config();
      ref.read(serverInfoProvider.notifier).set(res.info);
      setState(() => _serverPreview = res.info);
    } on ApiException catch (e) {
      setState(() => _serverError = e.message);
    } catch (e) {
      setState(() => _serverError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingServer = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final serverName =
        _serverPreview?.name.isNotEmpty == true ? _serverPreview!.name : 'Giracle';
    final registerAvailable = _serverPreview?.registerAvailable ?? false;
    final inviteOnly = _serverPreview?.registerInviteOnly ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(serverName)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _serverCtl,
                    decoration: InputDecoration(
                      labelText: 'サーバー URL',
                      hintText: 'https://chat.example.com (自動で /api を付与)',
                      suffixIcon: _loadingServer
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                height: 16,
                                width: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: _fetchServer,
                            ),
                    ),
                    keyboardType: TextInputType.url,
                    onSubmitted: (_) => _fetchServer(),
                  ),
                  if (_serverError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'インスタンス情報を取得できませんでした: $_serverError',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  TabBar(
                    controller: _tabCtl,
                    tabs: [
                      const Tab(text: 'ログイン'),
                      Tab(
                        text: registerAvailable ? '新規登録' : '新規登録 (無効)',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 340,
                    child: TabBarView(
                      controller: _tabCtl,
                      children: [
                        _LoginForm(),
                        registerAvailable
                            ? _RegisterForm(inviteOnly: inviteOnly)
                            : const _RegisterDisabled(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'server url は SharedPreferences (${Env.serverUrlPrefKey}) に保存されます',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginForm extends ConsumerStatefulWidget {
  @override
  ConsumerState<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<_LoginForm> {
  final _userCtl = TextEditingController();
  final _passCtl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _userCtl.dispose();
    _passCtl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final userId = await ref
          .read(userApiProvider)
          .signIn(_userCtl.text.trim(), _passCtl.text);
      await initLoad(ref, userId, initWsToo: true);
      if (!mounted) return;
      context.go('/app');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _userCtl,
          decoration: const InputDecoration(labelText: 'ユーザー名'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passCtl,
          decoration: const InputDecoration(labelText: 'パスワード'),
          obscureText: true,
          onSubmitted: (_) => _login(),
        ),
        const SizedBox(height: 12),
        if (_error != null)
          Text(
            'ログインエラー: $_error',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed:
                _busy || _passCtl.text.isEmpty ? null : _login,
            child: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('ログイン'),
          ),
        ),
      ],
    );
  }
}

class _RegisterForm extends ConsumerStatefulWidget {
  const _RegisterForm({required this.inviteOnly});
  final bool inviteOnly;
  @override
  ConsumerState<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends ConsumerState<_RegisterForm> {
  final _userCtl = TextEditingController();
  final _passCtl = TextEditingController();
  final _inviteCtl = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _success = false;

  @override
  void dispose() {
    _userCtl.dispose();
    _passCtl.dispose();
    _inviteCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(userApiProvider).signUp(
            _userCtl.text.trim(),
            _passCtl.text,
            inviteCode: widget.inviteOnly ? _inviteCtl.text.trim() : null,
          );
      setState(() => _success = true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.inviteOnly) ...[
          TextField(
            controller: _inviteCtl,
            decoration: const InputDecoration(labelText: '招待コード'),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _userCtl,
          decoration: const InputDecoration(labelText: 'ユーザー名'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passCtl,
          decoration: const InputDecoration(labelText: 'パスワード'),
          obscureText: true,
        ),
        const SizedBox(height: 12),
        if (_error != null)
          Text('登録エラー: $_error',
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (_success)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '成功! ${_userCtl.text.trim()} でログインしてください',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: (_busy || _passCtl.text.isEmpty || _success)
                ? null
                : _submit,
            child: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('登録する'),
          ),
        ),
      ],
    );
  }
}

class _RegisterDisabled extends StatelessWidget {
  const _RegisterDisabled();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          'このインスタンスは新規登録を受け付けていません',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
