import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';

class LocalServerService {
  HttpServer? _server;

  Future<void> startServer(String directoryPath, {int port = 8080}) async {
    if (kIsWeb) {
      print('LocalServerService is not supported on Web.');
      return;
    }

    if (_server != null) {
      print('Server is already running on port ${_server!.port}');
      return;
    }

    // Serve files from the specified directory
    final handler = createStaticHandler(
      directoryPath,
      defaultDocument: 'index.html',
      listDirectories: true,
    );

    final pipeline = const Pipeline().addMiddleware(logRequests()).addHandler(handler);

    try {
      _server = await shelf_io.serve(pipeline, InternetAddress.anyIPv4, port);
      print('Local server started on http://${_server!.address.host}:${_server!.port}');
    } catch (e) {
      print('Failed to start local server: $e');
    }
  }

  Future<void> stopServer() async {
    if (kIsWeb) return;
    
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
      print('Local server stopped.');
    }
  }
}
