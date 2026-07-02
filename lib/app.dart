import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'screens/channel_browser_screen.dart';
import 'screens/channel_screen.dart';
import 'screens/config_screen.dart';
import 'screens/home_screen.dart';
import 'screens/inbox_screen.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';

class GiracleApp extends ConsumerStatefulWidget {
  const GiracleApp({super.key});

  @override
  ConsumerState<GiracleApp> createState() => _GiracleAppState();
}

class _GiracleAppState extends ConsumerState<GiracleApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
        GoRoute(path: '/auth', builder: (_, __) => const LoginScreen()),
        GoRoute(
          path: '/app',
          builder: (_, __) => const HomeScreen(),
          routes: [
            GoRoute(
              path: 'channel/:channelId',
              builder: (_, state) =>
                  ChannelScreen(channelId: state.pathParameters['channelId']!),
            ),
            GoRoute(
              path: 'channel-browser',
              builder: (_, __) => const ChannelBrowserScreen(),
            ),
            GoRoute(path: 'config', builder: (_, __) => const ConfigScreen()),
            GoRoute(path: 'inbox', builder: (_, __) => const InboxScreen()),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Giracle',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7E22CE)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7E22CE),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}
