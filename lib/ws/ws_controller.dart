import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import '../api/api_client.dart';

class WsEvent {
  final String signal;
  final dynamic data;
  const WsEvent(this.signal, this.data);
}

class WsController {
  WsController(this._api);

  final ApiClient _api;
  IOWebSocketChannel? _channel;
  final _events = StreamController<WsEvent>.broadcast();
  final _connectionState = StreamController<bool>.broadcast();
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _stopped = false;
  bool _fatalError = false;

  Stream<WsEvent> get events => _events.stream;
  Stream<bool> get connection => _connectionState.stream;
  bool get isOpen => _channel != null;

  Future<void> connect() async {
    _stopped = false;
    await _open();
  }

  Future<void> _open() async {
    if (_stopped || _fatalError) return;

    final base = _api.baseUrl;
    final uri = Uri.parse(base);
    final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final wsUri = uri.replace(scheme: wsScheme, path: '/ws');

    try {
      final headers = <String, dynamic>{};
      final cookieHeader = await _cookieHeader(uri);
      if (cookieHeader.isNotEmpty) {
        headers[HttpHeaders.cookieHeader] = cookieHeader;
      }

      final socket = await WebSocket.connect(wsUri.toString(), headers: headers);
      _channel = IOWebSocketChannel(socket);
      _connectionState.add(true);

      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onClosed,
        cancelOnError: false,
      );

      _startPing();
    } catch (e) {
      debugPrint('WS connect failed: $e');
      _scheduleReconnect();
    }
  }

  Future<String> _cookieHeader(Uri uri) async {
    // Read cookies via the shared cookie jar mounted on the Dio client.
    // We do this by inspecting the Dio interceptors.
    final interceptors = _api.dio.interceptors;
    for (final i in interceptors) {
      if (i.runtimeType.toString() == 'CookieManager') {
        try {
          // ignore: avoid_dynamic_calls
          final dynamic mgr = i;
          // ignore: avoid_dynamic_calls
          final CookieJar jar = mgr.cookieJar as CookieJar;
          final list = await jar.loadForRequest(uri);
          return list.map((c) => '${c.name}=${c.value}').join('; ');
        } catch (_) {}
      }
    }
    return '';
  }

  void _onMessage(dynamic raw) {
    try {
      final str = raw is String ? raw : utf8.decode(raw as List<int>);
      final json = jsonDecode(str) as Map<String, dynamic>;
      final signal = json['signal'] as String? ?? '';
      final data = json['data'];
      if (signal == 'ERROR' && data == 'token not valid') {
        _fatalError = true;
      }
      _events.add(WsEvent(signal, data));
    } catch (e) {
      debugPrint('WS decode error: $e');
    }
  }

  void _onError(Object e) {
    debugPrint('WS error: $e');
  }

  void _onClosed() {
    _connectionState.add(false);
    _pingTimer?.cancel();
    _channel = null;
    if (_fatalError || _stopped) return;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(
      Duration(milliseconds: 1000 + (500 * (DateTime.now().millisecond / 1000)).toInt()),
      () => _open(),
    );
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      final ch = _channel;
      if (ch == null) return;
      try {
        ch.sink.add(jsonEncode({'signal': 'ping', 'data': 'ping'}));
      } catch (_) {}
    });
  }

  Future<void> close() async {
    _stopped = true;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    await _channel?.sink.close(ws_status.normalClosure);
    _channel = null;
    _connectionState.add(false);
  }

  void dispose() {
    close();
    _events.close();
    _connectionState.close();
  }
}
