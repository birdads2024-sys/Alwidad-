import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import '../models/download_task_model.dart';
import 'hls_download_service.dart';

class DownloadManagerService {
  // Use a single Dio instance with no interceptors
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 30),
    sendTimeout: const Duration(seconds: 30),
    // No custom headers at all - let Dio use its default Android headers
    // Gumlet and most CDNs work fine with default headers
  ));

  // Singleton pattern so CancelTokens are shared across instances
  static final DownloadManagerService _instance = DownloadManagerService._internal();
  factory DownloadManagerService() => _instance;
  DownloadManagerService._internal();

  final Map<String, CancelToken> _cancelTokens = {};

  Future<Box<DownloadTaskModel>> _getBox() async {
    if (!Hive.isBoxOpen('downloads')) {
      return await Hive.openBox<DownloadTaskModel>('downloads');
    }
    return Hive.box<DownloadTaskModel>('downloads');
  }

  Future<void> init() async {
    await _getBox();
  }

  Future<int> getFileSize(String url) async {
    try {
      final response = await _dio.head(url);
      final contentLength = response.headers.value('content-length');
      if (contentLength != null) {
        final size = int.tryParse(contentLength);
        if (size != null && size > 0) return size;
      }
    } catch (_) {}
    try {
      final response = await _dio.get(
        url,
        options: Options(
          headers: {'Range': 'bytes=0-0'},
          responseType: ResponseType.stream,
        ),
      );
      final contentRange = response.headers.value('content-range');
      if (contentRange != null && contentRange.contains('/')) {
        final parts = contentRange.split('/');
        final size = int.tryParse(parts.last);
        if (size != null && size > 0) return size;
      } else {
        final contentLength = response.headers.value('content-length');
        if (contentLength != null) {
          final size = int.tryParse(contentLength);
          if (size != null && size > 0) return size;
        }
      }
    } catch (_) {}
    return -1;
  }

  Future<void> deleteDownload(String id) async {
    if (kIsWeb) return;
    final box = await _getBox();
    final task = box.get(id);
    if (task != null && (task.savePath.endsWith('local.m3u8') || task.url.contains('.m3u8'))) {
      await HlsDownloadService().deleteDownload(id);
      return;
    }

    final cancelToken = _cancelTokens[id];
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('Deleted by user');
      _cancelTokens.remove(id);
    }
    if (task != null) {
      final savePath = task.savePath;
      try {
        final file = File(savePath);
        if (await file.exists()) {
          await file.delete();
          debugPrint('Physically deleted file: $savePath');
        }
      } catch (e) {
        debugPrint('Error deleting physical file ($savePath): $e');
      }
      await box.delete(id);
      debugPrint('Removed task from Hive: $id');
    }
  }

  Future<void> startDownload(String id, String url, String savePath) async {
    if (kIsWeb) {
      debugPrint('DownloadManagerService: Web not supported.');
      return;
    }

    if (url.contains('.m3u8') || savePath.endsWith('local.m3u8')) {
      await HlsDownloadService().startHlsDownload(
        taskId: id,
        m3u8Url: url,
        onProgress: (progress, downloaded, total) {},
      );
      return;
    }

    // If already downloading this id, skip
    if (_cancelTokens.containsKey(id)) {
      debugPrint('Already downloading: $id');
      return;
    }

    final box = await _getBox();
    var task = box.get(id);
    if (task == null) {
      task = DownloadTaskModel(id: id, url: url, savePath: savePath);
      await box.put(id, task);
      debugPrint('startDownload: NEW task created. url=$url');
    } else {
      final oldUrl = task.url;
      task.url = url;
      task.savePath = savePath;
      await task.save();
      debugPrint('startDownload: UPDATED task url from $oldUrl → $url');
    }

    final file = File(task.savePath);
    int existingBytes = 0;
    if (await file.exists()) {
      existingBytes = await file.length();
    }

    // If already completed and file exists, do nothing
    if (task.status == 'completed') {
      if (existingBytes > 0) {
        debugPrint('Already downloaded: $id');
        return;
      }
      task.status = 'pending';
      task.downloadedBytes = 0;
      task.totalBytes = 0;
      existingBytes = 0;
    }

    // When resuming a paused or failed download, check if the file exists on disk and has length > 0.
    // Do NOT delete the file!
    if (task.status == 'failed' || task.status == 'paused') {
      if (existingBytes == 0) {
        task.status = 'pending';
        task.downloadedBytes = 0;
        if (await file.exists()) {
          try { await file.delete(); } catch (_) {}
        }
      } else {
        debugPrint('Resuming download from $existingBytes bytes... id=$id');
        task.downloadedBytes = existingBytes;
      }
    } else if (existingBytes == 0) {
      if (await file.exists()) {
        try { await file.delete(); } catch (_) {}
      }
      task.downloadedBytes = 0;
      task.totalBytes = 0;
    } else {
      debugPrint('Existing partial file found ($existingBytes bytes). Resuming download... id=$id');
      task.downloadedBytes = existingBytes;
    }

    task.status = 'downloading';
    await task.save();

    final cancelToken = CancelToken();
    _cancelTokens[id] = cancelToken;

    try {
      bool resumedSuccessfully = false;
      if (existingBytes > 0) {
        try {
          debugPrint('Attempting Range request: bytes=$existingBytes-');
          final response = await _dio.get<ResponseBody>(
            url,
            options: Options(
              headers: {'Range': 'bytes=$existingBytes-'},
              responseType: ResponseType.stream,
            ),
            cancelToken: cancelToken,
          );

          if (response.statusCode == 206) {
            resumedSuccessfully = true;
            int total = task.totalBytes;
            final contentRange = response.headers.value('content-range');
            if (contentRange != null && contentRange.contains('/')) {
              final parts = contentRange.split('/');
              final parsedTotal = int.tryParse(parts.last);
              if (parsedTotal != null && parsedTotal > 0) {
                total = parsedTotal;
              }
            } else {
              final len = int.tryParse(response.headers.value('content-length') ?? '');
              if (len != null && len > 0) {
                total = existingBytes + len;
              }
            }
            if (total > 0) {
              task.totalBytes = total;
            }

            final sink = file.openWrite(mode: FileMode.append);
            int received = 0;
            int lastSaveMs = 0;
            try {
              await for (final chunk in response.data!.stream) {
                if (cancelToken.isCancelled) break;
                sink.add(chunk);
                received += chunk.length;
                task.downloadedBytes = existingBytes + received;
                final now = DateTime.now().millisecondsSinceEpoch;
                if (now - lastSaveMs > 300) {
                  lastSaveMs = now;
                  task.save();
                }
              }
            } finally {
              await sink.flush();
              await sink.close();
            }

            if (cancelToken.isCancelled) {
              throw DioException.requestCancelled(
                requestOptions: response.requestOptions,
                reason: 'User cancelled download',
              );
            }
          } else {
            debugPrint('Server returned status ${response.statusCode} instead of 206. Restarting from scratch.');
            resumedSuccessfully = false;
          }
        } on DioException catch (e) {
          if (CancelToken.isCancel(e)) {
            rethrow;
          }
          debugPrint('Range request failed: ${e.message}, falling back to full download');
          resumedSuccessfully = false;
        } catch (e) {
          debugPrint('Error during resume: $e, falling back to full download');
          resumedSuccessfully = false;
        }
      }

      if (!resumedSuccessfully) {
        if (await file.exists()) {
          try { await file.delete(); } catch (_) {}
        }
        task.downloadedBytes = 0;
        task.totalBytes = 0;
        await task.save();

        int lastSaveMs = 0;
        await _dio.download(
          url,
          savePath,
          cancelToken: cancelToken,
          deleteOnError: false,
          onReceiveProgress: (received, total) {
            task?.downloadedBytes = received;
            if (total > 0) {
              task?.totalBytes = total;
            }
            final now = DateTime.now().millisecondsSinceEpoch;
            if (now - lastSaveMs > 300) {
              lastSaveMs = now;
              task?.save();
            }
          },
        );
      }

      final savedFile = File(savePath);
      if (await savedFile.exists() && await savedFile.length() > 0) {
        task.status = 'completed';
        task.totalBytes = await savedFile.length();
        task.downloadedBytes = task.totalBytes;
        debugPrint('Download completed: $id (${task.totalBytes} bytes)');
      } else {
        task.status = 'failed';
        debugPrint('Download failed (empty file): $id');
      }
      await task.save();
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        task.status = 'paused';
        debugPrint('Download paused/cancelled: $id');
      } else {
        task.status = 'failed';
        debugPrint('Download DioException: id=$id url=$url | status=${e.response?.statusCode} | ${e.message}');
      }
      await task.save();
    } catch (e) {
      task.status = 'failed';
      await task.save();
      debugPrint('Download unexpected error: $id | $e');
    } finally {
      _cancelTokens.remove(id);
    }
  }

  Future<void> pauseDownload(String id) async {
    if (kIsWeb) return;
    final box = await _getBox();
    final task = box.get(id);
    if (task != null && (task.savePath.endsWith('local.m3u8') || task.url.contains('.m3u8'))) {
      await HlsDownloadService().pauseDownload(id);
      return;
    }

    final cancelToken = _cancelTokens[id];
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('User cancelled download');
      _cancelTokens.remove(id);
    }
    if (task != null && task.status == 'downloading') {
      task.status = 'paused';
      await task.save();
    }
  }

  Future<void> resumeDownload(String id, {void Function(double, int, int)? onProgress}) async {
    if (kIsWeb) return;
    final box = await _getBox();
    final task = box.get(id);
    if (task != null && (task.savePath.endsWith('local.m3u8') || task.url.contains('.m3u8'))) {
      await HlsDownloadService().resumeDownload(
        taskId: id,
        onProgress: onProgress ?? (progress, downloaded, total) {},
      );
      return;
    }

    if (task != null && (task.status == 'paused' || task.status == 'failed')) {
      await startDownload(task.id, task.url, task.savePath);
    }
  }
}
