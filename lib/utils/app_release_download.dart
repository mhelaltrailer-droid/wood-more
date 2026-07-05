export 'app_release_download_stub.dart'
    if (dart.library.io) 'app_release_download_io.dart'
    if (dart.library.html) 'app_release_download_web.dart';
