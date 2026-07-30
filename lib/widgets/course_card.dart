import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../models/course_model.dart';
import '../models/download_task_model.dart';

class CourseCard extends StatelessWidget {
  final CourseModel course;
  final bool isSubscribed;
  final VoidCallback onTap;

  const CourseCard({
    super.key,
    required this.course,
    required this.isSubscribed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAccess = course.isFree || isSubscribed;
    final isIos = Platform.isIOS;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasAccess
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : Colors.grey.shade800,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Thumbnail
                Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: course.thumbnailUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: course.thumbnailUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Colors.grey.shade900,
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey.shade900,
                                child: Icon(
                                  Icons.movie_creation_outlined,
                                  size: 48,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            )
                          : Container(
                              color: Colors.grey.shade900,
                              child: Icon(
                                Icons.movie_creation_outlined,
                                size: 48,
                                color: Colors.grey.shade700,
                              ),
                            ),
                    ),
                    // Gradient overlay
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.8),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    // Badge: Free/Premium
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: course.isFree
                              ? Colors.green.shade700
                              : Colors.blueGrey.shade700,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          course.isFree
                              ? 'مفتوح مجاناً 🆓'
                              : 'محتوى مخصص 🔒',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    // Lock icon overlay for premium courses if not subscribed
                    if (!hasAccess && !isIos)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.5),
                          child: Center(
                            child: CircleAvatar(
                              backgroundColor: Colors.black.withValues(alpha: 0.8),
                              radius: 28,
                              child: const Icon(
                                Icons.lock_outline_rounded,
                                color: Colors.amber,
                                size: 30,
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Downloaded status indicator
                    if (hasAccess)
                      Positioned(
                        bottom: 12,
                        left: 12,
                        child: ValueListenableBuilder(
                          valueListenable: Hive.box<DownloadTaskModel>('downloads').listenable(),
                          builder: (context, box, child) {
                            final isDownloaded = box.get(course.hlsUrl)?.status == 'completed' ||
                                box.get(course.mp4Url)?.status == 'completed';
                            if (isDownloaded) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade800,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.greenAccent, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      'جاهز للمشاهدة دون اتصال',
                                      style: TextStyle(color: Colors.white, fontSize: 10),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                  ],
                ),
                // Details
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        course.description,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade400,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.play_circle_outline_rounded,
                                size: 16,
                                color: hasAccess ? theme.colorScheme.primary : Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                hasAccess
                                    ? 'ابدأ المشاهدة الآن'
                                    : 'مخصص للطلاب المسجلين',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: hasAccess ? theme.colorScheme.primary : Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
