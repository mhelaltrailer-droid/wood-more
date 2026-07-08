/// بادئة رسالة إعلامية بعد فتح شاشة إعدادات Android (ليست خطأ).
const installSettingsOpenedPrefix = 'SETTINGS:';

bool isInstallSettingsMessage(String? message) {
  return message?.startsWith(installSettingsOpenedPrefix) == true;
}

String installSettingsUserMessage(String message) {
  return message.substring(installSettingsOpenedPrefix.length);
}
