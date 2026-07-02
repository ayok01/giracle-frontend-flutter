import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';
import '../config/env.dart';
import '../stores/init_load.dart';
import '../stores/providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _serverCtl = TextEditingController();
  final _userCtl = TextEditingController();
  final _passCtl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _serverCtl.text = ref.read(apiClientProvider).baseUrl;
  }

  @override
  void dispose() {
    _serverCtl.dispose();
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
      final api = ref.read(apiClientProvider);
      if (_serverCtl.text.trim() != api.baseUrl) {
        await api.setBaseUrl(_serverCtl.text.trim());
      }
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
    return Scaffold(
      appBar: AppBar(title: const Text('Giracle にログイン')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _serverCtl,
                  decoration: const InputDecoration(
                    labelText: 'サーバー URL',
                    hintText: 'http://localhost:3000',
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 16),
                if (_error != null)
                  Text(_error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _login,
                    child: _busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : const Text('ログイン'),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'server url は SharedPreferences に保存されます (${Env.serverUrlPrefKey})',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
