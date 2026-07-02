import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/env.dart';

class ApiClient {
  ApiClient._(this.dio, this._cookieJar, this._prefs, this._baseUrl);

  final Dio dio;
  final PersistCookieJar _cookieJar;
  final SharedPreferences _prefs;
  String _baseUrl;

  String get baseUrl => _baseUrl;

  static Future<ApiClient> create() async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl =
        prefs.getString(Env.serverUrlPrefKey) ?? Env.defaultServerUrl;

    final docs = await getApplicationDocumentsDirectory();
    final cookieDir = Directory('${docs.path}/.cookies');
    if (!cookieDir.existsSync()) {
      cookieDir.createSync(recursive: true);
    }
    final cookieJar =
        PersistCookieJar(storage: FileStorage(cookieDir.path), ignoreExpires: true);

    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
      responseType: ResponseType.json,
    ));
    dio.interceptors.add(CookieManager(cookieJar));

    return ApiClient._(dio, cookieJar, prefs, baseUrl);
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = url;
    dio.options.baseUrl = url;
    await _prefs.setString(Env.serverUrlPrefKey, url);
  }

  Future<void> clearCookies() => _cookieJar.deleteAll();

  Future<Map<String, dynamic>> _handle(
    Future<Response<dynamic>> Function() send,
  ) async {
    try {
      final res = await send();
      final data = res.data;
      if (data is Map<String, dynamic>) return data;
      if (data is String) return {'message': data};
      return {'message': 'ok'};
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is String
          ? data
          : data is Map<String, dynamic>
              ? (data['message']?.toString() ?? e.message ?? 'error')
              : (e.message ?? 'error');
      throw ApiException(message, statusCode: e.response?.statusCode);
    }
  }

  Future<Map<String, dynamic>> getJson(String path,
          {Map<String, dynamic>? query}) =>
      _handle(() => dio.get(path, queryParameters: query));

  Future<Map<String, dynamic>> postJson(String path,
          {Object? body, Map<String, dynamic>? query}) =>
      _handle(() => dio.post(path, data: body, queryParameters: query));

  Future<Map<String, dynamic>> putJson(String path, {Object? body}) =>
      _handle(() => dio.put(path, data: body));

  Future<Map<String, dynamic>> deleteJson(String path, {Object? body}) =>
      _handle(() => dio.delete(path, data: body));
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => 'ApiException($statusCode): $message';
}

final apiClientProvider = Provider<ApiClient>((ref) {
  throw UnimplementedError('apiClientProvider must be overridden');
});
