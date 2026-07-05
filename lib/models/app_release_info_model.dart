class AppReleaseInfoModel {
  final bool hasRelease;
  final bool hasUpdate;
  final int? releaseId;
  final String? versionLabel;
  final int? versionCode;
  final String? fileName;
  final int? sizeBytes;
  final String? uploadedByEmail;
  final String? createdAt;

  const AppReleaseInfoModel({
    required this.hasRelease,
    required this.hasUpdate,
    this.releaseId,
    this.versionLabel,
    this.versionCode,
    this.fileName,
    this.sizeBytes,
    this.uploadedByEmail,
    this.createdAt,
  });

  factory AppReleaseInfoModel.fromMap(Map<String, dynamic> map) {
    return AppReleaseInfoModel(
      hasRelease: map['hasRelease'] == true,
      hasUpdate: map['hasUpdate'] == true,
      releaseId: (map['releaseId'] as num?)?.toInt(),
      versionLabel: map['versionLabel'] as String?,
      versionCode: (map['versionCode'] as num?)?.toInt(),
      fileName: map['fileName'] as String?,
      sizeBytes: (map['sizeBytes'] as num?)?.toInt(),
      uploadedByEmail: map['uploadedByEmail'] as String?,
      createdAt: map['createdAt'] as String?,
    );
  }

  factory AppReleaseInfoModel.none() {
    return const AppReleaseInfoModel(hasRelease: false, hasUpdate: false);
  }
}

class AppReleaseDownloadModel {
  final int releaseId;
  final String versionLabel;
  final String fileName;
  final int sizeBytes;
  final String fileData;

  const AppReleaseDownloadModel({
    required this.releaseId,
    required this.versionLabel,
    required this.fileName,
    required this.sizeBytes,
    required this.fileData,
  });

  factory AppReleaseDownloadModel.fromMap(Map<String, dynamic> map) {
    return AppReleaseDownloadModel(
      releaseId: (map['releaseId'] as num?)?.toInt() ?? 0,
      versionLabel: map['versionLabel'] as String? ?? '',
      fileName: map['fileName'] as String? ?? 'app-release.apk',
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      fileData: map['fileData'] as String? ?? '',
    );
  }
}

class AppReleaseDownloadInfoModel {
  final bool hasRelease;
  final int releaseId;
  final String versionLabel;
  final String fileName;
  final int sizeBytes;
  final int chunkSize;
  final int totalChunks;

  const AppReleaseDownloadInfoModel({
    required this.hasRelease,
    required this.releaseId,
    required this.versionLabel,
    required this.fileName,
    required this.sizeBytes,
    required this.chunkSize,
    required this.totalChunks,
  });

  factory AppReleaseDownloadInfoModel.fromMap(Map<String, dynamic> map) {
    return AppReleaseDownloadInfoModel(
      hasRelease: map['hasRelease'] == true,
      releaseId: (map['releaseId'] as num?)?.toInt() ?? 0,
      versionLabel: map['versionLabel'] as String? ?? '',
      fileName: map['fileName'] as String? ?? 'app-release.apk',
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      chunkSize: (map['chunkSize'] as num?)?.toInt() ?? 0,
      totalChunks: (map['totalChunks'] as num?)?.toInt() ?? 0,
    );
  }
}

class AppReleaseDownloadResult {
  final String fileName;
  final List<int> bytes;

  const AppReleaseDownloadResult({
    required this.fileName,
    required this.bytes,
  });
}
