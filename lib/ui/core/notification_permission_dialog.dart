import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Requests notification permission directly via native OS system prompt.
Future<bool> checkAndShowNotificationPermissionDialog(BuildContext context) async {
  var status = await Permission.notification.status;
  if (status.isGranted) return true;

  // Direct Native OS System Dialog Request (Android/iOS System Prompt)
  status = await Permission.notification.request();
  if (status.isGranted) return true;

  if (status.isPermanentlyDenied) {
    await openAppSettings();
  }

  return status.isGranted;
}
