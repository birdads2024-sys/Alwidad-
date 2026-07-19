import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/course_model.dart';
import '../../models/download_task_model.dart';
import '../../services/download_manager_service.dart';
import '../video_player_screen.dart';

class CourseVideosScreen extends StatefulWidget {
  final CourseModel course;

  const CourseVideosScreen({
    Key? key,
    required this.course,
  }) : super(key: key);

  @override
  State<CourseVideosScreen> createState() => _CourseVideosScreenState();
}

class _CourseVideosScreenState extends State<CourseVideosScreen> {
  
  Future<void> _startDownload(VideoQuality quality) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final bytes = utf8.encode(quality.mp4Url);
      final hash = sha256.convert(bytes).toString();
      final savePath = '${dir.path}/$hash.mp4';
      
      await DownloadManagerService().startDownload(
        quality.mp4Url, 
        quality.mp4Url, 
        savePath,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('بدأ تحميل ${widget.course.title} (${quality.qualityName})... 📥')),
        );
      }
    } catch (e) {
      debugPrint('Download start error: $e');
    }
  }

  Future<void> _deleteDownload(VideoQuality quality) async {
    try {
      await DownloadManagerService().deleteDownload(quality.mp4Url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الملف من الذاكرة وتفريغ المساحة 🗑️')),
        );
      }
    } catch (e) {
      debugPrint('Delete error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course.title),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Course Banner/Thumbnail
            AspectRatio(
              aspectRatio: 16 / 9,
              child: widget.course.thumbnailUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: widget.course.thumbnailUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: theme.colorScheme.surface,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: theme.colorScheme.surface,
                        child: const Icon(Icons.broken_image, size: 50),
                      ),
                    )
                  : Container(
                      color: theme.primaryColor.withValues(alpha: 0.1),
                      child: Icon(Icons.school, size: 64, color: theme.primaryColor),
                    ),
            ),

            // Course Info
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // كارت تفاصيل الدرس
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: theme.dividerColor.withOpacity(0.2)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.course.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.course.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  const Text(
                    'الجودات المتاحة للفيديو للمشاهدة والتحميل:',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  // عرض الجودات
                  if (widget.course.qualities.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.0),
                        child: Text('لا توجد جودات متوفرة لهذا الدرس حالياً.'),
                      ),
                    )
                  else
                    ...widget.course.qualities.map((quality) {
                      return ValueListenableBuilder(
                        valueListenable: Hive.box<DownloadTaskModel>('downloads').listenable(),
                        builder: (context, box, child) {
                          final task = box.get(quality.mp4Url);
                          final isCompleted = task?.status == 'completed';
                          final isDownloading = task?.status == 'downloading';
                          final isPaused = task?.status == 'paused';
                          final isFailed = task?.status == 'failed';

                          double progress = 0;
                          String sizeText = '';
                          if (task != null && task.totalBytes > 0) {
                            progress = task.downloadedBytes / task.totalBytes;
                            sizeText = '${(task.totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
                          }

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isCompleted ? Colors.green : theme.dividerColor.withOpacity(0.3),
                                width: isCompleted ? 1.5 : 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.video_library, color: theme.primaryColor, size: 20),
                                          const SizedBox(width: 8),
                                          Text(
                                            'جودة ${quality.qualityName}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isCompleted
                                              ? Colors.green.withValues(alpha: 0.1)
                                              : Colors.blue.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          isCompleted ? '✅ مُحملة' : '🌐 أونلاين',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isCompleted ? Colors.green : Colors.blue,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  if (sizeText.isNotEmpty || isCompleted) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      isCompleted ? 'المساحة محلياً: $sizeText 💾' : 'الحجم: $sizeText 📦',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isCompleted ? Colors.green : Colors.blue,
                                      ),
                                    ),
                                  ],

                                  // مؤشر التحميل
                                  if (isDownloading || isPaused) ...[
                                    const SizedBox(height: 8),
                                    LinearProgressIndicator(
                                      value: progress > 0 ? progress : null,
                                      backgroundColor: theme.dividerColor.withValues(alpha: 0.2),
                                      color: isPaused ? Colors.amber.shade800 : Colors.blue,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          isPaused
                                              ? (progress > 0 ? 'متوقف مؤقتاً ⏸️ (${(progress * 100).toStringAsFixed(1)}%)' : 'متوقف مؤقتاً ⏸️')
                                              : (progress > 0 ? 'جاري التحميل... ${(progress * 100).toStringAsFixed(1)}%' : 'جاري التحميل...'),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isPaused ? Colors.amber.shade800 : Colors.blue,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (task != null)
                                          Text(
                                            '${(task.downloadedBytes / (1024 * 1024)).toStringAsFixed(1)} / $sizeText',
                                            style: TextStyle(fontSize: 11, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5)),
                                          ),
                                      ],
                                    ),
                                  ],
                                  if (isFailed) ...[
                                    const SizedBox(height: 4),
                                    const Text('⚠️ فشل التحميل، يرجى المحاولة مرة أخرى.',
                                        style: TextStyle(color: Colors.red, fontSize: 11)),
                                  ],

                                  const SizedBox(height: 12),

                                  // أزرار التحكم
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            backgroundColor: theme.primaryColor,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                          icon: const Icon(Icons.play_arrow, size: 18),
                                          label: const Text(
                                            'مشاهدة 🌐',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => VideoPlayerScreen(
                                                    videoUrl: quality.hlsUrl,
                                                    title: '${widget.course.title} (${quality.qualityName})',
                                                    isDrm: quality.isDrm,
                                                  ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // خيارات الأوفلاين والتحميل
                                      if (!quality.isDrm) ...[
                                        if (isCompleted) ...[
                                          Expanded(
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(vertical: 8),
                                                backgroundColor: Colors.green.shade700,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                              child: const Text(
                                                'أوفلاين 💾',
                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => VideoPlayerScreen(
                                                      videoUrl: quality.mp4Url,
                                                      title: '${widget.course.title} (${quality.qualityName})',
                                                      downloadUrl: quality.mp4Url,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                            tooltip: 'حذف التحميل',
                                            onPressed: () => _deleteDownload(quality),
                                          ),
                                        ] else if (isDownloading) ...[
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(vertical: 8),
                                                backgroundColor: Colors.amber.shade800,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                              icon: const Icon(Icons.pause, size: 18),
                                              label: const Text(
                                                'إيقاف مؤقت',
                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
                                              onPressed: () {
                                                DownloadManagerService().pauseDownload(quality.mp4Url);
                                              },
                                            ),
                                          ),
                                        ] else if (isPaused || isFailed) ...[
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(vertical: 8),
                                                backgroundColor: Colors.blue.shade700,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                              icon: Icon(isPaused ? Icons.play_arrow : Icons.refresh, size: 18),
                                              label: Text(
                                                isPaused ? 'استكمال' : 'إعادة التحميل',
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
                                              onPressed: () {
                                                if (isPaused) {
                                                  DownloadManagerService().resumeDownload(quality.mp4Url);
                                                } else {
                                                  _startDownload(quality);
                                                }
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                            tooltip: 'إلغاء التحميل',
                                            onPressed: () => _deleteDownload(quality),
                                          ),
                                        ] else ...[
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(vertical: 8),
                                                backgroundColor: Colors.grey.shade800,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
                                              ),
                                              icon: const Icon(Icons.download, size: 18),
                                              label: const Text(
                                                'تحميل 📥',
                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
                                              onPressed: () => _startDownload(quality),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
