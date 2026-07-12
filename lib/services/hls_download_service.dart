import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive_ce/hive.dart';
import '../models/download_task_model.dart';

class _PlaylistData {
  final String qualityUrl;
  final String content;
  final List<String> segments;
  _PlaylistData(this.qualityUrl, this.content, this.segments);
}

class HlsDownloadService {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 5),
  ));

  static final HlsDownloadService _instance = HlsDownloadService._internal();
  factory HlsDownloadService() => _instance;
  HlsDownloadService._internal();

  final Map<String, CancelToken> _cancelTokens = {};

  // ============================================================
  // STEP 1: Parse the .m3u8 (master or quality) and extract all segment URLs
  // ============================================================
  Future<List<String>> parseM3u8Segments(String m3u8Url) async {
    final data = await _fetchQualityPlaylist(m3u8Url);
    return data.segments;
  }

  Future<String?> _findAudioPlaylistUrl(String anyM3u8Url) async {
    try {
      final uri = Uri.parse(anyM3u8Url);
      final baseUrl = '${uri.scheme}://${uri.host}${uri.path.substring(0, uri.path.lastIndexOf('/') + 1)}';
      final masterUrl = anyM3u8Url.endsWith('main.m3u8') ? anyM3u8Url : '${baseUrl}main.m3u8';
      
      final response = await _dio.get<String>(masterUrl);
      final content = response.data ?? '';
      for (final line in content.split('\n')) {
        if (line.contains('TYPE=AUDIO') && line.contains('URI="')) {
          final start = line.indexOf('URI="') + 5;
          final end = line.indexOf('"', start);
          if (start > 4 && end > start) {
            final uriPart = line.substring(start, end);
            return (uriPart.startsWith('http://') || uriPart.startsWith('https://'))
                ? uriPart
                : '$baseUrl$uriPart';
          }
        }
      }
    } catch (e) {
      debugPrint('[HLS] Could not find audio playlist: $e');
    }
    return null;
  }

  String _rewriteFmp4Playlist(String content, String baseUrl, String onlineUrl, String localFilename) {
    var res = content;
    if (onlineUrl.isNotEmpty) {
      res = res.replaceAll(onlineUrl, localFilename);
      if (onlineUrl.startsWith(baseUrl)) {
        final relUrl = onlineUrl.substring(baseUrl.length);
        res = res.replaceAll(relUrl, localFilename);
      }
    }
    return res;
  }

  Future<int> estimateHlsSize(String m3u8Url) async {
    try {
      final data = await _fetchQualityPlaylist(m3u8Url);
      final uniqueSegments = data.segments.toSet().toList();
      int totalSize = 0;
      if (uniqueSegments.isNotEmpty) {
        if (uniqueSegments.length == 1) {
          final res = await _dio.head<void>(uniqueSegments.first);
          final lenStr = res.headers.value('content-length');
          totalSize += lenStr != null ? (int.tryParse(lenStr) ?? 0) : 0;
        } else {
          final res = await _dio.head<void>(uniqueSegments.first);
          final lenStr = res.headers.value('content-length');
          final segSize = lenStr != null ? (int.tryParse(lenStr) ?? 0) : 0;
          totalSize += segSize > 0 ? segSize * uniqueSegments.length : 0;
        }
      }

      final audioUrl = await _findAudioPlaylistUrl(m3u8Url);
      if (audioUrl != null) {
        final audioData = await _fetchQualityPlaylist(audioUrl);
        final audioSegments = audioData.segments.toSet().toList();
        if (audioSegments.isNotEmpty) {
          if (audioSegments.length == 1) {
            final res = await _dio.head<void>(audioSegments.first);
            final lenStr = res.headers.value('content-length');
            totalSize += lenStr != null ? (int.tryParse(lenStr) ?? 0) : 0;
          } else {
            final res = await _dio.head<void>(audioSegments.first);
            final lenStr = res.headers.value('content-length');
            final segSize = lenStr != null ? (int.tryParse(lenStr) ?? 0) : 0;
            totalSize += segSize > 0 ? segSize * audioSegments.length : 0;
          }
        }
      }
      return totalSize;
    } catch (e) {
      debugPrint('[HLS] Error estimating size: $e');
      return 0;
    }
  }

  Future<_PlaylistData> _fetchQualityPlaylist(String m3u8Url) async {
    debugPrint('[HLS] Fetching m3u8: $m3u8Url');
    final response = await _dio.get<String>(m3u8Url);
    final content = response.data ?? '';

    final uri = Uri.parse(m3u8Url);
    final baseUrl = '${uri.scheme}://${uri.host}${uri.path.substring(0, uri.path.lastIndexOf('/') + 1)}';
    debugPrint('[HLS] Base URL: $baseUrl');

    final lines = content.split('\n');

    if (content.contains('#EXT-X-STREAM-INF')) {
      String? bestSubPlaylist;
      final candidates = <String>[];
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        if (trimmed.contains('.m3u8') && !trimmed.contains('_iframe') && !trimmed.contains('_audio') && !trimmed.contains('_en_') && !trimmed.contains('_ar_')) {
          candidates.add(trimmed);
        }
      }
      if (candidates.isNotEmpty) {
        for (final q in ['1080p', '720p', '540p', '480p', '360p', '240p']) {
          for (final c in candidates) {
            if (c.contains(q)) {
              bestSubPlaylist = c;
              break;
            }
          }
          if (bestSubPlaylist != null) break;
        }
        bestSubPlaylist ??= candidates.first;
        final subUrl = (bestSubPlaylist.startsWith('http://') || bestSubPlaylist.startsWith('https://'))
            ? bestSubPlaylist
            : '$baseUrl$bestSubPlaylist';
        debugPrint('[HLS] Master playlist detected. Selected best video quality: $subUrl');
        return await _fetchQualityPlaylist(subUrl);
      }
    }

    final segments = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        segments.add(trimmed);
      } else {
        segments.add('$baseUrl$trimmed');
      }
    }

    debugPrint('[HLS] Found ${segments.length} segments in $m3u8Url');
    return _PlaylistData(m3u8Url, content, segments);
  }

  // ============================================================
  // STEP 2: Download all segments + save local file
  // ============================================================
  Future<void> startHlsDownload({
    required String taskId,
    required String m3u8Url,
    required void Function(double progress, int downloaded, int total) onProgress,
  }) async {
    if (_cancelTokens.containsKey(taskId)) {
      debugPrint('[HLS] Already downloading: $taskId');
      return;
    }

    final box = Hive.isBoxOpen('downloads')
        ? Hive.box<DownloadTaskModel>('downloads')
        : await Hive.openBox<DownloadTaskModel>('downloads');

    final dir = await getApplicationDocumentsDirectory();
    final hash = taskId.hashCode.abs().toRadixString(16);
    final segmentsDir = Directory('${dir.path}/hls/$hash');
    await segmentsDir.create(recursive: true);

    final cancelToken = CancelToken();
    _cancelTokens[taskId] = cancelToken;

    DownloadTaskModel? task;

    try {
      final audioUrl = await _findAudioPlaylistUrl(m3u8Url);
      final playlistData = await _fetchQualityPlaylist(m3u8Url);
      final segments = playlistData.segments;
      final uniqueSegments = segments.toSet().toList();

      final uri = Uri.parse(playlistData.qualityUrl);
      final baseUrl = '${uri.scheme}://${uri.host}${uri.path.substring(0, uri.path.lastIndexOf('/') + 1)}';

      if (uniqueSegments.length == 1) {
        final videoMediaUrl = uniqueSegments.first;
        debugPrint('[HLS] Single-file fMP4 video stream detected: $videoMediaUrl');

        if (audioUrl != null) {
          final audioData = await _fetchQualityPlaylist(audioUrl);
          final audioSegments = audioData.segments.toSet().toList();
          if (audioSegments.isNotEmpty) {
            final audioMediaUrl = audioSegments.first;
            debugPrint('[HLS] Separate audio stream detected: $audioMediaUrl');

            final videoFile = File('${segmentsDir.path}/video.mp4');
            final audioFile = File('${segmentsDir.path}/audio.mp4');
            final savePath = '${segmentsDir.path}/local.m3u8'.replaceAll('\\', '/');

            task = box.get(taskId) ?? DownloadTaskModel(id: taskId, url: m3u8Url, savePath: savePath);
            task.status = 'downloading';
            task.url = m3u8Url;
            task.savePath = savePath;
            await box.put(taskId, task);

            int videoTotal = 0;
            int audioTotal = 0;
            try {
              final vHead = await _dio.head<void>(videoMediaUrl);
              videoTotal = int.tryParse(vHead.headers.value('content-length') ?? '0') ?? 0;
              final aHead = await _dio.head<void>(audioMediaUrl);
              audioTotal = int.tryParse(aHead.headers.value('content-length') ?? '0') ?? 0;
            } catch (_) {}
            final combinedTotal = (videoTotal + audioTotal) > 0 ? (videoTotal + audioTotal) : 100000;
            task.totalBytes = combinedTotal;
            await task.save();

            int videoDownloaded = 0;
            if (!await videoFile.exists() || await videoFile.length() == 0) {
              int lastUpdate = 0;
              await _dio.download(
                videoMediaUrl,
                videoFile.path,
                cancelToken: cancelToken,
                deleteOnError: true,
                onReceiveProgress: (received, total) {
                  videoDownloaded = received;
                  if (videoTotal == 0 && total > 0) videoTotal = total;
                  final now = DateTime.now().millisecondsSinceEpoch;
                  if (now - lastUpdate > 300 || received == total) {
                    lastUpdate = now;
                    if (task != null) {
                      task.downloadedBytes = videoDownloaded;
                      task.totalBytes = (videoTotal + audioTotal) > 0 ? (videoTotal + audioTotal) : total;
                      task.save();
                    }
                    final tot = (videoTotal + audioTotal) > 0 ? (videoTotal + audioTotal) : total;
                    onProgress(videoDownloaded / tot, videoDownloaded, tot);
                  }
                },
              );
            } else {
              videoDownloaded = await videoFile.length();
            }

            if (cancelToken.isCancelled) {
              if (task != null) {
                task.status = 'paused';
                await task.save();
              }
              return;
            }

            int audioDownloaded = 0;
            if (!await audioFile.exists() || await audioFile.length() == 0) {
              int lastUpdate = 0;
              await _dio.download(
                audioMediaUrl,
                audioFile.path,
                cancelToken: cancelToken,
                deleteOnError: true,
                onReceiveProgress: (received, total) {
                  audioDownloaded = received;
                  if (audioTotal == 0 && total > 0) audioTotal = total;
                  final now = DateTime.now().millisecondsSinceEpoch;
                  if (now - lastUpdate > 300 || received == total) {
                    lastUpdate = now;
                    if (task != null) {
                      task.downloadedBytes = videoDownloaded + audioDownloaded;
                      task.totalBytes = (videoTotal + audioTotal) > 0 ? (videoTotal + audioTotal) : (videoDownloaded + total);
                      task.save();
                    }
                    final tot = (videoTotal + audioTotal) > 0 ? (videoTotal + audioTotal) : (videoDownloaded + total);
                    onProgress((videoDownloaded + audioDownloaded) / tot, videoDownloaded + audioDownloaded, tot);
                  }
                },
              );
            } else {
              audioDownloaded = await audioFile.length();
            }

            if (cancelToken.isCancelled) {
              if (task != null) {
                task.status = 'paused';
                await task.save();
              }
              return;
            }

            final localVideoContent = _rewriteFmp4Playlist(playlistData.content, baseUrl, videoMediaUrl, 'video.mp4');
            await File('${segmentsDir.path}/video.m3u8').writeAsString(localVideoContent);

            final localAudioContent = _rewriteFmp4Playlist(audioData.content, baseUrl, audioMediaUrl, 'audio.mp4');
            await File('${segmentsDir.path}/audio.m3u8').writeAsString(localAudioContent);

            final localMasterContent = '''#EXTM3U
#EXT-X-VERSION:6
#EXT-X-INDEPENDENT-SEGMENTS
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="Default",DEFAULT=YES,AUTOSELECT=YES,URI="audio.m3u8"
#EXT-X-STREAM-INF:BANDWIDTH=1500000,AUDIO="audio"
video.m3u8
''';
            await File('${segmentsDir.path}/local.m3u8').writeAsString(localMasterContent);

            int actualTotalBytes = 0;
            if (await segmentsDir.exists()) {
              await for (final file in segmentsDir.list(recursive: true, followLinks: false)) {
                if (file is File) actualTotalBytes += await file.length();
              }
            }

            if (task != null) {
              task.status = 'completed';
              task.totalBytes = actualTotalBytes > 0 ? actualTotalBytes : (videoDownloaded + audioDownloaded);
              task.downloadedBytes = task.totalBytes;
              await task.save();
              debugPrint('[HLS] Video+Audio download complete! Saved at: ${task.savePath} (${task.totalBytes} bytes)');
            }
            return;
          }
        }

        final targetFile = File('${segmentsDir.path}/video.mp4');
        final savePath = targetFile.path.replaceAll('\\', '/');
        
        task = box.get(taskId) ?? DownloadTaskModel(id: taskId, url: m3u8Url, savePath: savePath);
        task.status = 'downloading';
        task.url = m3u8Url;
        task.savePath = savePath;
        await box.put(taskId, task);

        if (await targetFile.exists() && await targetFile.length() > 0) {
          debugPrint('[HLS] Skipping existing single file.');
        } else {
          int lastUpdate = 0;
          await _dio.download(
            videoMediaUrl,
            targetFile.path,
            cancelToken: cancelToken,
            deleteOnError: true,
            onReceiveProgress: (received, total) {
              final now = DateTime.now().millisecondsSinceEpoch;
              if (now - lastUpdate > 300 || received == total) {
                lastUpdate = now;
                if (total > 0 && task != null) {
                  task.downloadedBytes = received;
                  task.totalBytes = total;
                  task.save();
                  onProgress(received / total, received, total);
                }
              }
            },
          );
        }

        if (cancelToken.isCancelled) {
          if (task != null) {
            task.status = 'paused';
            await task.save();
          }
          return;
        }

        int actualTotalBytes = 0;
        if (await targetFile.exists()) {
          actualTotalBytes = await targetFile.length();
        }

        if (task != null) {
          task.status = 'completed';
          task.totalBytes = actualTotalBytes > 0 ? actualTotalBytes : task.totalBytes;
          task.downloadedBytes = task.totalBytes;
          await task.save();
          debugPrint('[HLS] Single-file download complete! Saved at: $savePath (${task.totalBytes} bytes)');
        }
        return;
      }

      final savePath = '${segmentsDir.path}/local.m3u8'.replaceAll('\\', '/');
      task = box.get(taskId) ?? DownloadTaskModel(id: taskId, url: m3u8Url, savePath: savePath);
      task.status = 'downloading';
      task.url = m3u8Url;
      task.savePath = savePath;
      final total = segments.length;
      task.totalBytes = total;
      await box.put(taskId, task);

      for (int i = 0; i < segments.length; i++) {
        if (cancelToken.isCancelled) break;

        final segUrl = segments[i];
        final segFile = File('${segmentsDir.path}/seg_${i.toString().padLeft(5, '0')}.ts');

        if (await segFile.exists() && await segFile.length() > 0) {
          if ((i + 1) % 5 == 0 || i == segments.length - 1) {
            if (task != null) {
              task.downloadedBytes = i + 1;
              await task.save();
            }
            onProgress((i + 1) / total, i + 1, total);
          }
          continue;
        }

        try {
          await _dio.download(
            segUrl,
            segFile.path,
            cancelToken: cancelToken,
            deleteOnError: true,
          );
        } catch (e) {
          if (e is DioException && CancelToken.isCancel(e)) rethrow;
          debugPrint('[HLS] Failed to download segment $i: $e');
        }

        if (task != null) {
          task.downloadedBytes = i + 1;
          await task.save();
        }
        onProgress((i + 1) / total, i + 1, total);
      }

      if (cancelToken.isCancelled) {
        if (task != null) {
          task.status = 'paused';
          await task.save();
        }
        return;
      }

      await _writeLocalM3u8(segmentsDir.path, playlistData.content, total);

      int actualTotalBytes = 0;
      if (await segmentsDir.exists()) {
        await for (final file in segmentsDir.list(recursive: true, followLinks: false)) {
          if (file is File) {
            actualTotalBytes += await file.length();
          }
        }
      }

      if (task != null) {
        task.status = 'completed';
        task.totalBytes = actualTotalBytes > 0 ? actualTotalBytes : total;
        task.downloadedBytes = task.totalBytes;
        await task.save();
        debugPrint('[HLS] Download complete! Local playlist: $savePath (${task.totalBytes} bytes)');
      }

    } on DioException catch (e) {
      if (task != null) {
        if (CancelToken.isCancel(e)) {
          task.status = 'paused';
        } else {
          task.status = 'failed';
          debugPrint('[HLS] DioException: ${e.message}');
        }
        await task.save();
      }
    } catch (e) {
      if (task != null) {
        task.status = 'failed';
        await task.save();
      }
      debugPrint('[HLS] Unexpected error: $e');
    } finally {
      _cancelTokens.remove(taskId);
    }
  }

  // ============================================================
  // STEP 3: Write local M3U8 playlist pointing to local files
  // ============================================================
  Future<void> _writeLocalM3u8(String dir, String originalContent, int segmentCount) async {
    final buffer = StringBuffer();
    int segIdx = 0;
    for (final line in originalContent.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('#')) {
        buffer.writeln(trimmed);
      } else {
        if (segIdx < segmentCount) {
          buffer.writeln('seg_${segIdx.toString().padLeft(5, '0')}.ts');
          segIdx++;
        }
      }
    }
    // Fallback if no segment lines were replaced
    if (segIdx == 0 && segmentCount > 0) {
      buffer.clear();
      buffer.writeln('#EXTM3U');
      buffer.writeln('#EXT-X-VERSION:3');
      buffer.writeln('#EXT-X-TARGETDURATION:10');
      buffer.writeln('#EXT-X-MEDIA-SEQUENCE:0');
      for (int i = 0; i < segmentCount; i++) {
        buffer.writeln('#EXTINF:10.0,');
        buffer.writeln('seg_${i.toString().padLeft(5, '0')}.ts');
      }
      buffer.writeln('#EXT-X-ENDLIST');
    }
    final savePath = '$dir/local.m3u8'.replaceAll('\\', '/');
    await File(savePath).writeAsString(buffer.toString());
    debugPrint('[HLS] local.m3u8 written with $segIdx segments at $savePath');
  }

  // ============================================================
  // Pause / Resume / Delete
  // ============================================================
  Future<void> pauseDownload(String taskId) async {
    final token = _cancelTokens[taskId];
    if (token != null && !token.isCancelled) {
      token.cancel('paused by user');
      _cancelTokens.remove(taskId);
    }
    final box = Hive.isBoxOpen('downloads')
        ? Hive.box<DownloadTaskModel>('downloads')
        : await Hive.openBox<DownloadTaskModel>('downloads');
    final task = box.get(taskId);
    if (task != null && task.status == 'downloading') {
      task.status = 'paused';
      await task.save();
    }
  }

  Future<void> resumeDownload({
    required String taskId,
    required void Function(double, int, int) onProgress,
  }) async {
    final box = Hive.isBoxOpen('downloads')
        ? Hive.box<DownloadTaskModel>('downloads')
        : await Hive.openBox<DownloadTaskModel>('downloads');
    final task = box.get(taskId);
    if (task != null && (task.status == 'paused' || task.status == 'failed')) {
      await startHlsDownload(
        taskId: taskId,
        m3u8Url: task.url,
        onProgress: onProgress,
      );
    }
  }

  Future<void> deleteDownload(String taskId) async {
    final token = _cancelTokens[taskId];
    if (token != null && !token.isCancelled) {
      token.cancel('deleted by user');
      _cancelTokens.remove(taskId);
    }
    final box = Hive.isBoxOpen('downloads')
        ? Hive.box<DownloadTaskModel>('downloads')
        : await Hive.openBox<DownloadTaskModel>('downloads');
    final task = box.get(taskId);
    if (task != null) {
      final localM3u8 = task.savePath;
      try {
        final f = File(localM3u8);
        final segDir = f.parent;
        if (await segDir.exists()) {
          await segDir.delete(recursive: true);
          debugPrint('[HLS] Deleted folder: ${segDir.path}');
        }
      } catch (e) {
        debugPrint('[HLS] Error deleting parent folder: $e');
      }
      await box.delete(taskId);
    } else {
      // Fallback: delete folder by hash if task was missing or path invalid
      try {
        final dir = await getApplicationDocumentsDirectory();
        final hash = taskId.hashCode.abs().toRadixString(16);
        final fallbackDir = Directory('${dir.path}/hls/$hash');
        if (await fallbackDir.exists()) {
          await fallbackDir.delete(recursive: true);
          debugPrint('[HLS] Deleted fallback folder: ${fallbackDir.path}');
        }
      } catch (e) {
        debugPrint('[HLS] Error deleting fallback folder: $e');
      }
    }
  }

  // ============================================================
  // Helper: Get local M3U8 path (if downloaded)
  // ============================================================
  Future<String?> getLocalM3u8Path(String taskId) async {
    final box = Hive.isBoxOpen('downloads')
        ? Hive.box<DownloadTaskModel>('downloads')
        : await Hive.openBox<DownloadTaskModel>('downloads');
    final task = box.get(taskId);
    if (task?.status == 'completed') {
      final f = File(task!.savePath);
      if (await f.exists()) return task.savePath;
    }
    return null;
  }
}
