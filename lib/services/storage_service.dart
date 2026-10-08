import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class StorageService {
  String _lastCheckedDirectory = "";
  String? _customPhotosPath;
  String? _customVideosPath;

  String get lastCheckedDirectory => _lastCheckedDirectory;
  String? get customPhotosPath => _customPhotosPath;
  String? get customVideosPath => _customVideosPath;

  StorageService() {
    _loadCustomFolderSettings();
  }

  /// Get active photos destination folder
  Future<String> getPhotosFolder() async {
    if (_customPhotosPath != null && _customPhotosPath!.trim().isNotEmpty) {
      Directory customDir = Directory(_customPhotosPath!.trim());
      if (!customDir.existsSync()) {
        try {
          customDir.createSync(recursive: true);
        } catch (_) {}
      }
      return customDir.path;
    }

    Directory appDocDir = await getApplicationDocumentsDirectory();
    String defaultFolder = p.join(appDocDir.path, 'synrec_photos');
    Directory(defaultFolder).createSync(recursive: true);
    return defaultFolder;
  }

  /// Get active videos destination folder
  Future<String> getVideosFolder() async {
    if (_customVideosPath != null && _customVideosPath!.trim().isNotEmpty) {
      Directory customDir = Directory(_customVideosPath!.trim());
      if (!customDir.existsSync()) {
        try {
          customDir.createSync(recursive: true);
        } catch (_) {}
      }
      return customDir.path;
    }

    Directory appDocDir = await getApplicationDocumentsDirectory();
    String defaultFolder = p.join(appDocDir.path, 'synrec_videos');
    Directory(defaultFolder).createSync(recursive: true);
    return defaultFolder;
  }

  /// Save custom folder settings
  Future<void> saveCustomFolderSettings(String? photosPath, String? videosPath) async {
    _customPhotosPath = photosPath?.trim();
    _customVideosPath = videosPath?.trim();

    try {
      Directory appDocDir = await getApplicationDocumentsDirectory();
      File settingsFile = File(p.join(appDocDir.path, 'folder_settings.json'));
      Map<String, dynamic> data = {
        'photos_folder': _customPhotosPath ?? '',
        'videos_folder': _customVideosPath ?? '',
      };
      await settingsFile.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint("Error saving folder settings: $e");
    }
  }

  /// Load custom folder settings
  Future<void> _loadCustomFolderSettings() async {
    try {
      Directory appDocDir = await getApplicationDocumentsDirectory();
      File settingsFile = File(p.join(appDocDir.path, 'folder_settings.json'));
      if (await settingsFile.exists()) {
        String content = await settingsFile.readAsString();
        Map<String, dynamic> data = jsonDecode(content);
        String photos = data['photos_folder'] ?? '';
        String videos = data['videos_folder'] ?? '';
        _customPhotosPath = photos.isNotEmpty ? photos : null;
        _customVideosPath = videos.isNotEmpty ? videos : null;
      }
    } catch (e) {
      debugPrint("Error loading folder settings: $e");
    }
  }

  /// Save favorites candidate list to `favorites.json`
  Future<void> saveFavorites(List<Map<String, String>> favorites) async {
    try {
      Directory appDocDir = await getApplicationDocumentsDirectory();
      File favFile = File(p.join(appDocDir.path, 'favorites.json'));
      await favFile.writeAsString(jsonEncode(favorites));
    } catch (e) {
      debugPrint("Error saving favorites: $e");
    }
  }

  /// Load favorites candidate list from `favorites.json`
  Future<List<Map<String, String>>> loadFavorites() async {
    try {
      Directory appDocDir = await getApplicationDocumentsDirectory();
      File favFile = File(p.join(appDocDir.path, 'favorites.json'));
      if (await favFile.exists()) {
        String content = await favFile.readAsString();
        List<dynamic> list = jsonDecode(content);
        return list.map((item) => Map<String, String>.from(item)).toList();
      }
    } catch (e) {
      debugPrint("Error loading favorites: $e");
    }
    return [];
  }

  /// Save the recorded video file with name `recxxxx.mp4`
  Future<String?> saveRecordedVideo(XFile videoFile) async {
    try {
      String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      String fileName = 'rec$timestamp.mp4';

      String targetFolder = await getVideosFolder();
      String targetPath = p.join(targetFolder, fileName);
      File savedFile = await File(videoFile.path).copy(targetPath);

      // Attempt saving to system gallery if on supported mobile/desktop platform
      try {
        if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
          bool hasAccess = await Gal.hasAccess();
          if (!hasAccess) {
            await Gal.requestAccess();
          }
          await Gal.putVideo(savedFile.path, album: 'SynRec');
        }
      } catch (e) {
        debugPrint('Gal gallery save notice: $e');
      }

      // Cleanup temporary source video file after successful save
      try {
        File sourceTempFile = File(videoFile.path);
        if (await sourceTempFile.exists() && sourceTempFile.path != savedFile.path) {
          await sourceTempFile.delete();
          debugPrint('Cleaned up temporary source video file: ${sourceTempFile.path}');
        }
      } catch (e) {
        debugPrint('Notice deleting temporary source video: $e');
      }

      return savedFile.path;
    } catch (e) {
      debugPrint('Error saving video: $e');
      return null;
    }
  }

  /// Save captured photo with name `photo_YYYYMMDD_HHmmss.jpg`
  Future<String?> savePhoto(XFile photoFile) async {
    try {
      String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      String fileName = 'photo_$timestamp.jpg';

      String targetFolder = await getPhotosFolder();
      String targetPath = p.join(targetFolder, fileName);
      File savedFile = await File(photoFile.path).copy(targetPath);

      // Save to public Downloads / Photos on Android as well
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          String pubFolder = '/storage/emulated/0/Download/synrec_photos';
          Directory(pubFolder).createSync(recursive: true);
          await File(photoFile.path).copy(p.join(pubFolder, fileName));
        } catch (e) {
          debugPrint('Public photo save notice: $e');
        }
      }

      // Save to system gallery via Gal
      try {
        if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
          bool hasAccess = await Gal.hasAccess();
          if (!hasAccess) {
            await Gal.requestAccess();
          }
          await Gal.putImage(savedFile.path, album: 'SynRec');
        }
      } catch (e) {
        debugPrint('Gal photo save notice: $e');
      }

      // Cleanup temporary source photo file after successful save
      try {
        File sourceTempFile = File(photoFile.path);
        if (await sourceTempFile.exists() && sourceTempFile.path != savedFile.path) {
          await sourceTempFile.delete();
          debugPrint('Cleaned up temporary source photo file: ${sourceTempFile.path}');
        }
      } catch (e) {
        debugPrint('Notice deleting temporary source photo: $e');
      }

      return savedFile.path;
    } catch (e) {
      debugPrint('Error saving photo: $e');
      return null;
    }
  }

  /// Returns the agreed public sync folder path on phone: `/storage/emulated/0/Download/synrec_sync`
  Future<Directory> getSyncFolder() async {
    Directory syncDir;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      syncDir = Directory('/storage/emulated/0/Download/synrec_sync');
      if (!syncDir.existsSync()) {
        try {
          syncDir.createSync(recursive: true);
        } catch (e) {
          Directory appDocDir = await getApplicationDocumentsDirectory();
          syncDir = Directory(p.join(appDocDir.path, 'synrec_sync'));
          syncDir.createSync(recursive: true);
        }
      }
    } else {
      Directory appDocDir = await getApplicationDocumentsDirectory();
      syncDir = Directory(p.join(appDocDir.path, 'synrec_sync'));
      if (!syncDir.existsSync()) {
        syncDir.createSync(recursive: true);
      }
    }
    _lastCheckedDirectory = syncDir.path;
    return syncDir;
  }

  /// Creates `start_photo.txt` for photo trigger or `start_video.txt` for video trigger
  Future<File> createStartFile({required bool isPhoto}) async {
    Directory syncDir = await getSyncFolder();
    String fileName = isPhoto ? 'start_photo.txt' : 'start_video.txt';
    String filePath = p.join(syncDir.path, fileName);
    File file = File(filePath);
    String command = isPhoto ? 'TAKE_PHOTO' : 'START_RECORDING';
    String content = '$command\n'
        'Timestamp: ${DateTime.now().toIso8601String()}\n'
        'Source: Master Target\n';
    await file.writeAsString(content);

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        File dlFile = File('/storage/emulated/0/Download/$fileName');
        await dlFile.writeAsString(content);
      } catch (e) {
        debugPrint('Public Download $fileName write notice: $e');
      }
    }

    return file;
  }

  /// Checks if `start_photo.txt` / `start_video.txt` (or legacy `start.txt`) exists
  Future<File?> checkAndGetStartFile() async {
    Directory syncDir = await getSyncFolder();
    _lastCheckedDirectory = syncDir.path;

    List<String> fileNames = [
      'start_photo.txt',
      'started_photo.txt',
      'start_video.txt',
      'started_video.txt',
      'start.txt',
      'started.txt',
    ];

    for (String name in fileNames) {
      File f = File(p.join(syncDir.path, name));
      if (await f.exists()) {
        return f;
      }
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      List<String> androidPaths = [];
      for (String name in fileNames) {
        androidPaths.add('/storage/emulated/0/Download/synrec_sync/$name');
        androidPaths.add('/storage/emulated/0/Download/$name');
        androidPaths.add('/storage/emulated/0/Bluetooth/$name');
      }

      for (String path in androidPaths) {
        File extFile = File(path);
        if (await extFile.exists()) {
          _lastCheckedDirectory = extFile.parent.path;
          return extFile;
        }
      }
    }

    return null;
  }

  /// Deletes specific sync file after Slave consumes the sync trigger
  Future<void> deleteStartFile([File? targetFile]) async {
    File? file = targetFile ?? await checkAndGetStartFile();
    if (file != null && await file.exists()) {
      try {
        await file.delete();
        debugPrint("Deleted sync file from ${file.path} for next time.");
      } catch (e) {
        debugPrint("Error deleting sync file: $e");
      }
    }
  }

  /// Creates `stop.txt` in the agreed public sync folder on phone
  Future<File> createStopFile() async {
    Directory syncDir = await getSyncFolder();
    String filePath = p.join(syncDir.path, 'stop.txt');
    File file = File(filePath);
    String content = 'STOP_RECORDING\n'
        'Timestamp: ${DateTime.now().toIso8601String()}\n';
    await file.writeAsString(content);

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        File dlFile = File('/storage/emulated/0/Download/stop.txt');
        await dlFile.writeAsString(content);
      } catch (e) {
        debugPrint('Public Download stop.txt write notice: $e');
      }
    }

    return file;
  }

  /// Checks if `stop.txt` or `stopped.txt` exists in public sync folder or Android Bluetooth/Download folders
  Future<File?> checkAndGetStopFile() async {
    Directory syncDir = await getSyncFolder();
    _lastCheckedDirectory = syncDir.path;

    for (String name in ['stop.txt', 'stopped.txt']) {
      File f = File(p.join(syncDir.path, name));
      if (await f.exists()) {
        return f;
      }
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      List<String> androidPaths = [
        '/storage/emulated/0/Download/synrec_sync/stop.txt',
        '/storage/emulated/0/Download/synrec_sync/stopped.txt',
        '/storage/emulated/0/Download/stop.txt',
        '/storage/emulated/0/Download/stopped.txt',
        '/storage/emulated/0/Bluetooth/stop.txt',
        '/storage/emulated/0/Bluetooth/stopped.txt',
      ];

      for (String path in androidPaths) {
        File extFile = File(path);
        if (await extFile.exists()) {
          _lastCheckedDirectory = extFile.parent.path;
          return extFile;
        }
      }
    }

    return null;
  }

  /// Deletes `stop.txt` / `stopped.txt` after sync trigger
  Future<void> deleteStopFile() async {
    File? file = await checkAndGetStopFile();
    if (file != null && await file.exists()) {
      try {
        await file.delete();
        debugPrint("Deleted stop.txt from ${file.path} for next time.");
      } catch (e) {
        debugPrint("Error deleting stop.txt: $e");
      }
    }
  }

  /// Cleans up leftover temporary files (.jpg, .mp4, .tmp) in `getTemporaryDirectory()`
  Future<void> cleanTempDirectory() async {
    try {
      Directory tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        List<FileSystemEntity> files = tempDir.listSync();
        for (FileSystemEntity entity in files) {
          if (entity is File) {
            String name = p.basename(entity.path).toLowerCase();
            if (name.startsWith('photo_') ||
                name.startsWith('virtual_') ||
                name.startsWith('rec') ||
                name.endsWith('.jpg') ||
                name.endsWith('.mp4') ||
                name.endsWith('.tmp')) {
              try {
                await entity.delete();
                debugPrint('Cleaned up temp file on startup: ${entity.path}');
              } catch (_) {}
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error cleaning temp directory: $e');
    }
  }
}
