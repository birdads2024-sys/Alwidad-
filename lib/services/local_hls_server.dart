import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';
import 'package:path_provider/path_provider.dart';

class LocalHlsServer {
  static HttpServer? _server;
  static int _port = 8765;

  static final LocalHlsServer _instance = LocalHlsServer._internal();
  factory LocalHlsServer() => _instance;
  LocalHlsServer._internal();

  Future<void> startIfNeeded() async {
    if (_server != null) return;
    if (kIsWeb) return;

    final dir = await getApplicationDocumentsDirectory();
    final handler = createStaticHandler(
      dir.path,
      serveFilesOutsidePath: false,
    );

    try {
      _server = await shelf_io.serve(
        logRequests()(handler),
        InternetAddress.loopbackIPv4,
        _port,
      );
      debugPrint('[LocalHlsServer] Started on http://127.0.0.1:$_port');
    } catch (e) {
      debugPrint('[LocalHlsServer] Port $_port busy or failed ($e), trying dynamic port...');
      try {
        _server = await shelf_io.serve(
          logRequests()(handler),
          InternetAddress.loopbackIPv4,
          0,
        );
        _port = _server!.port;
        debugPrint('[LocalHlsServer] Started on dynamic port http://127.0.0.1:$_port');
      } catch (e2) {
        debugPrint('[LocalHlsServer] Failed to start server: $e2');
      }
    }
  }

  Future<String> toLocalUrl(String absolutePath) async {
    final dir = await getApplicationDocumentsDirectory();
    final normAbs = absolutePath.replaceAll('\\', '/');
    final normDir = dir.path.replaceAll('\\', '/');
    final relativePath = normAbs.replaceFirst(normDir, '');
    final cleanPath = relativePath.startsWith('/') ? relativePath.substring(1) : relativePath;
    return 'http://127.0.0.1:$_port/$cleanPath';
  }

  void stop() {
    _server?.close(force: true);
    _server = null;
  }
}
