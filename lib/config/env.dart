class Env {
  static const String defaultServerUrl = String.fromEnvironment(
    'GIRACLE_SERVER_URL',
    defaultValue: 'http://localhost:3000',
  );

  static const String serverUrlPrefKey = 'giracle.serverUrl';
  static const String tokenPrefKey = 'giracle.token';
}
