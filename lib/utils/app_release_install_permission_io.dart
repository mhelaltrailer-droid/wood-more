import 'dart:io';

import 'package:flutter/services.dart';

const _channel = MethodChannel(
  'com.example.wood_and_more_app/app_release_install',
);

Future<bool> canInstallAppReleases() async {
  if (!Platform.isAndroid) return true;
  try {
    final granted = await _channel.invokeMethod<bool>('canInstallPackages');
    return granted ?? false;
  } on PlatformException {
    return false;
  }
}

Future<void> openAppReleaseInstallPermissionSettings() async {
  if (!Platform.isAndroid) return;
  await _channel.invokeMethod<void>('openInstallPermissionSettings');
}
