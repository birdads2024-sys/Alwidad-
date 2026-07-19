import 'package:flutter/material.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../services/screen_security_service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../services/download_manager_service.dart';
import '../services/hls_download_service.dart';
import '../services/local_hls_server.dart';
import '../models/download_task_model.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String? downloadUrl;
  final bool isDrm;

  const VideoPlayerScreen({
    Key? key,
    required this.videoUrl,
    required this.title,
    this.downloadUrl,
    this.isDrm = false,
  }) : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  BetterPlayerController? _betterPlayerController;
  bool _isLoading = true;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    // تفعيل حماية الشاشة عند فتح مشغل الفيديو (منع لقطات الشاشة وتسجيل الصوت والصورة)
    ScreenSecurityService.enableSecureMode();

    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    BetterPlayerConfiguration betterPlayerConfiguration = const BetterPlayerConfiguration(
      aspectRatio: 16 / 9,
      fit: BoxFit.contain,
      autoPlay: true,
      looping: false,
      handleLifecycle: true,
      controlsConfiguration: BetterPlayerControlsConfiguration(
        enableSkips: true,
        enableFullscreen: true,
        enablePlayPause: true,
        enableMute: true,
        enableAudioTracks: true,
        enablePlaybackSpeed: true,
        enableQualities: true,
        enableSubtitles: true,
        showControlsOnInitialize: true,
        controlBarColor: Colors.black54,
        textColor: Colors.white,
        playIcon: Icons.play_arrow,
        pauseIcon: Icons.pause,
      ),
    );

    String? localFilePath;
    String? localHlsUrl;

    if (widget.downloadUrl != null || widget.videoUrl.contains('.m3u8')) {
      try {
        if (widget.downloadUrl != null && !widget.downloadUrl!.contains('.m3u8')) {
          final dir = await getApplicationDocumentsDirectory();
          final bytes = utf8.encode(widget.downloadUrl!);
          final hash = sha256.convert(bytes).toString();
          final savePath = '${dir.path}/$hash.mp4';
          
          if (await File(savePath).exists()) {
            if (!Hive.isBoxOpen('downloads')) {
              await Hive.openBox<DownloadTaskModel>('downloads');
            }
            final task = Hive.box<DownloadTaskModel>('downloads').get(widget.videoUrl);
            if (task?.status == 'completed') {
              localFilePath = savePath;
              _isOffline = true;
              debugPrint('[Player] Playing offline from local direct MP4 file: $localFilePath');
            }
          }
        }

        if (!_isOffline && ((widget.downloadUrl != null && widget.downloadUrl!.contains('.m3u8')) || widget.videoUrl.contains('.m3u8'))) {
          final localPath = await HlsDownloadService().getLocalM3u8Path(widget.videoUrl);
          if (localPath != null) {
            if (localPath.endsWith('.mp4') || localPath.endsWith('.mkv')) {
              localFilePath = localPath;
              _isOffline = true;
              debugPrint('[Player] Playing offline from local fMP4 file: $localFilePath');
            } else {
              await LocalHlsServer().startIfNeeded();
              localHlsUrl = await LocalHlsServer().toLocalUrl(localPath);
              _isOffline = true;
              debugPrint('[Player] Playing offline from local HLS: $localHlsUrl');
            }
          }
        }
      } catch (e) {
        debugPrint('Error checking local file: $e');
      }
    }

    BetterPlayerDrmConfiguration? drmConfiguration;
    if (widget.isDrm) {
      final gumletRegExp = RegExp(r'video\.gumlet\.io/([a-fA-F0-9]{24})/([a-fA-F0-9]{24})');
      final match = gumletRegExp.firstMatch(widget.videoUrl);
      if (match != null) {
        final orgId = match.group(1)!;
        final assetId = match.group(2)!;
        
        if (Platform.isAndroid) {
          drmConfiguration = BetterPlayerDrmConfiguration(
            drmType: BetterPlayerDrmType.widevine,
            licenseUrl: 'https://widevine.gumlet.com/licence/$orgId/$assetId',
            headers: const {
              "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
              "Referer": "https://video.gumlet.io/",
              "Origin": "https://video.gumlet.io/",
            },
          );
        } else if (Platform.isIOS) {
          drmConfiguration = BetterPlayerDrmConfiguration(
            drmType: BetterPlayerDrmType.fairplay,
            licenseUrl: 'https://fairplay.gumlet.com/licence/$orgId/$assetId',
            certificateUrl: 'https://fairplay.gumlet.com/certificate/$orgId',
            headers: const {
              "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
              "Referer": "https://video.gumlet.io/",
              "Origin": "https://video.gumlet.io/",
            },
          );
        }
      }
    }

    BetterPlayerDataSource dataSource;
    if (localHlsUrl != null) {
      dataSource = BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        localHlsUrl,
        videoFormat: BetterPlayerVideoFormat.hls,
        useAsmsTracks: true,
        useAsmsSubtitles: true,
      );
    } else if (localFilePath != null) {
      dataSource = BetterPlayerDataSource(
        BetterPlayerDataSourceType.file,
        localFilePath,
      );
    } else {
      dataSource = BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        widget.videoUrl,
        videoFormat: BetterPlayerVideoFormat.hls,
        useAsmsSubtitles: true,
        useAsmsTracks: true,
        drmConfiguration: drmConfiguration,
        headers: const {
          "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
          "Referer": "https://video.gumlet.io/",
          "Origin": "https://video.gumlet.io/",
        },
      );
    }

    _betterPlayerController = BetterPlayerController(betterPlayerConfiguration);
    _betterPlayerController!.setupDataSource(dataSource);
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    // إيقاف حماية الشاشة عند الخروج من مشغل الفيديو
    ScreenSecurityService.disableSecureMode();
    _betterPlayerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          '${widget.title} ${_isOffline ? "(محلي 💾)" : "(إنترنت 🌐)"}',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (widget.downloadUrl != null)
            ValueListenableBuilder(
              valueListenable: Hive.box<DownloadTaskModel>('downloads').listenable(),
              builder: (context, box, child) {
                final task = box.get(widget.videoUrl);
                
                if (task != null && task.status == 'downloading') {
                  double progress = task.totalBytes > 0 
                      ? task.downloadedBytes / task.totalBytes 
                      : 0;
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          Text('${(progress * 100).toStringAsFixed(1)}%'),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                } else if (task != null && task.status == 'completed') {
                  final sizeMB = (task.totalBytes / (1024 * 1024)).toStringAsFixed(2);
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        '$sizeMB MB\nمُحمل',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10, color: Colors.greenAccent),
                      ),
                    ),
                  );
                }
                
                return IconButton(
                  icon: const Icon(Icons.download),
                  tooltip: 'تحميل الفيديو',
                  onPressed: () async {
                    try {
                      final isHls = (widget.downloadUrl != null && widget.downloadUrl!.contains('.m3u8')) ||
                          widget.videoUrl.contains('.m3u8');
                      if (isHls && widget.downloadUrl != null) {
                        await HlsDownloadService().startHlsDownload(
                          taskId: widget.videoUrl,
                          m3u8Url: widget.downloadUrl!,
                          onProgress: (progress, downloaded, total) {},
                        );
                      } else if (widget.downloadUrl != null) {
                        final dir = await getApplicationDocumentsDirectory();
                        final bytes = utf8.encode(widget.downloadUrl!);
                        final hash = sha256.convert(bytes).toString();
                        final savePath = '${dir.path}/$hash.mp4';
                        
                        final downloadService = DownloadManagerService();
                        downloadService.startDownload(widget.videoUrl, widget.downloadUrl!, savePath);
                      }
                      
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('بدأ التحميل...')),
                        );
                      }
                    } catch (e) {
                      debugPrint('Download error: $e');
                    }
                  },
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: _isLoading 
              ? const CircularProgressIndicator(color: Colors.white)
              : AspectRatio(
                  aspectRatio: 16 / 9,
                  child: BetterPlayer(
                    controller: _betterPlayerController!,
                  ),
                ),
        ),
      ),
    );
  }
}
