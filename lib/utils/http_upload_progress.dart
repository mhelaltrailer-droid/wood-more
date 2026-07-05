export 'http_upload_progress_stub.dart'
    if (dart.library.io) 'http_upload_progress_io.dart'
    if (dart.library.html) 'http_upload_progress_web.dart';
