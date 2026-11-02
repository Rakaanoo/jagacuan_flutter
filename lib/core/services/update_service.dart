import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppUpdateInfo {
  final String latestVersion;
  final int buildNumber;
  final String releaseDate;
  final String title;
  final String description;
  final List<String> changelog;
  final String apkUrl;
  final double apkSizeMb;
  final bool isForceUpdate;
  final bool hasUpdate;

  AppUpdateInfo({
    required this.latestVersion,
    required this.buildNumber,
    required this.releaseDate,
    required this.title,
    required this.description,
    required this.changelog,
    required this.apkUrl,
    required this.apkSizeMb,
    required this.isForceUpdate,
    required this.hasUpdate,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json, {required bool isForceUpdate, required bool hasUpdate}) {
    return AppUpdateInfo(
      latestVersion: json['latest_version'] ?? '1.0.0',
      buildNumber: json['build_number'] is int ? json['build_number'] : int.tryParse(json['build_number']?.toString() ?? '0') ?? 0,
      releaseDate: json['release_date'] ?? '',
      title: json['title'] ?? 'Pembaruan Tersedia',
      description: json['description'] ?? '',
      changelog: (json['changelog'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      apkUrl: json['apk_url'] ?? '',
      apkSizeMb: (json['apk_size_mb'] as num?)?.toDouble() ?? 59.0,
      isForceUpdate: isForceUpdate,
      hasUpdate: hasUpdate,
    );
  }
}

class UpdateService {
  // Current installed app build number
  static const int currentBuildNumber = 13;
  static const String currentVersionName = '1.0.12';

  static const String versionCheckUrl = 'https://jagacuan-app.vercel.app/version.json';
  static const MethodChannel _installerChannel = MethodChannel('com.jagacuan.app/package_installer');

  /// Check whether a new update is available and determine Day 1 vs Day 2+ (force update).
  static Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(Uri.parse(versionCheckUrl));
      final response = await request.close().timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        return null;
      }

      final body = await response.transform(utf8.decoder).join();
      final Map<String, dynamic> data = jsonDecode(body);

      final remoteBuildNumber = data['build_number'] is int
          ? data['build_number'] as int
          : int.tryParse(data['build_number']?.toString() ?? '0') ?? 0;

      final hasUpdate = remoteBuildNumber > currentBuildNumber;
      if (!hasUpdate) {
        return null;
      }

      // Check 2-day progressive update logic
      final prefs = await SharedPreferences.getInstance();
      final key = 'update_first_prompted_$remoteBuildNumber';
      final storedTimestamp = prefs.getInt(key);

      bool isForceUpdate = false;
      final now = DateTime.now().millisecondsSinceEpoch;

      if (storedTimestamp == null) {
        // Day 1: First time detected
        await prefs.setInt(key, now);
        isForceUpdate = false;
      } else {
        // Check if 24 hours (1 day) have passed since first detection
        final elapsed = now - storedTimestamp;
        const oneDayMillis = 24 * 60 * 60 * 1000;
        if (elapsed >= oneDayMillis) {
          isForceUpdate = true; // Day 2+: force update
        } else {
          isForceUpdate = false; // Still within Day 1
        }
      }

      return AppUpdateInfo.fromJson(
        data,
        isForceUpdate: isForceUpdate,
        hasUpdate: true,
      );
    } catch (_) {
      // Silently fail if offline or unreachable
      return null;
    }
  }

  /// Download the APK with progress callback
  static Future<File> downloadApk({
    required String apkUrl,
    required int buildNumber,
    required void Function(double progress, int receivedBytes, int totalBytes) onProgress,
  }) async {
    final client = HttpClient();
    final request = await client.getUrl(Uri.parse(apkUrl));
    final response = await request.close();

    if (response.statusCode != 200) {
      throw Exception('Gagal mengunduh APK (HTTP ${response.statusCode})');
    }

    final totalBytes = response.contentLength;
    final tempDir = Directory.systemTemp;
    final saveFile = File('${tempDir.path}/jagacuan_update_$buildNumber.apk');

    if (await saveFile.exists()) {
      await saveFile.delete();
    }

    final sink = saveFile.openWrite();
    int received = 0;

    try {
      await for (final chunk in response) {
        received += chunk.length;
        sink.add(chunk);
        final progress = totalBytes > 0 ? (received / totalBytes).clamp(0.0, 1.0) : 0.0;
        onProgress(progress, received, totalBytes);
      }
    } finally {
      await sink.flush();
      await sink.close();
    }

    return saveFile;
  }

  /// Trigger native package installer via Android MethodChannel
  static Future<bool> installApk(String filePath) async {
    try {
      final bool? result = await _installerChannel.invokeMethod<bool>('installApk', {
        'filePath': filePath,
      });
      return result ?? false;
    } catch (e) {
      return false;
    }
  }
}
