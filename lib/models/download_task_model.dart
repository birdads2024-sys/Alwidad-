import 'package:hive_ce/hive.dart';

part 'download_task_model.g.dart';

@HiveType(typeId: 0)
class DownloadTaskModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String url;

  @HiveField(2)
  String savePath;

  @HiveField(3)
  int downloadedBytes;

  @HiveField(4)
  int totalBytes;

  @HiveField(5)
  String status; // 'pending', 'downloading', 'paused', 'completed', 'failed'

  DownloadTaskModel({
    required this.id,
    required this.url,
    required this.savePath,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.status = 'pending',
  });
}
