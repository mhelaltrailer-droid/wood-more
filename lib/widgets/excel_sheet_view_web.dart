import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'excel_sheet_controller.dart';

/// Web implementation backed by an `<iframe>` that hosts the exact same
/// `assets/spreadsheet/index.html` Luckysheet engine used on mobile.
///
/// Communication with the iframe uses `window.postMessage` in both directions,
/// mirroring the JS bridge used inside the native WebView on mobile.
Widget createExcelSheetView({
  required String base64Data,
  required bool editable,
  ExcelSheetController? controller,
  VoidCallback? onReady,
  void Function(String message)? onError,
}) {
  return _ExcelSheetWeb(
    base64Data: base64Data,
    editable: editable,
    controller: controller,
    onReady: onReady,
    onError: onError,
  );
}

class _ExcelSheetWeb extends StatefulWidget {
  final String base64Data;
  final bool editable;
  final ExcelSheetController? controller;
  final VoidCallback? onReady;
  final void Function(String message)? onError;

  const _ExcelSheetWeb({
    required this.base64Data,
    required this.editable,
    this.controller,
    this.onReady,
    this.onError,
  });

  @override
  State<_ExcelSheetWeb> createState() => _ExcelSheetWebState();
}

class _ExcelSheetWebState extends State<_ExcelSheetWeb> {
  static int _seq = 0;

  late final String _viewType;
  html.IFrameElement? _iframe;
  StreamSubscription<html.MessageEvent>? _messageSub;
  bool _ready = false;
  bool _iframeReady = false;
  Completer<String>? _exportCompleter;

  @override
  void initState() {
    super.initState();
    _viewType = 'excel-sheet-view-${_seq++}';
    _attachController(widget.controller);
    _registerView();
  }

  void _attachController(ExcelSheetController? controller) {
    controller?.exportCallback = _exportXlsx;
    controller?.readyGetter = () => _ready;
  }

  void _detachController(ExcelSheetController? controller) {
    if (controller?.exportCallback == _exportXlsx) {
      controller?.exportCallback = null;
      controller?.readyGetter = null;
    }
  }

  void _registerView() {
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      final iframe = html.IFrameElement()
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = '#ffffff'
        ..allow = 'clipboard-read; clipboard-write';
      _iframe = iframe;
      _bootstrapIframe(iframe);
      return iframe;
    });
    _messageSub = html.window.onMessage.listen(_onMessage);
  }

  Future<void> _bootstrapIframe(html.IFrameElement iframe) async {
    try {
      final htmlText = await rootBundle.loadString(
        'assets/spreadsheet/index.html',
      );
      // srcdoc keeps the engine same-origin with the parent, so postMessage and
      // the CDN scripts inside the page work reliably.
      iframe.srcdoc = htmlText;
    } catch (e) {
      widget.onError?.call('تعذر تحميل محرك الشيت: $e');
    }
  }

  void _onMessage(html.MessageEvent event) {
    // Only accept messages coming from our own iframe.
    if (_iframe == null || event.source != _iframe!.contentWindow) return;
    final raw = event.data;
    if (raw is! String) return;
    Map<String, dynamic> data;
    try {
      data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return;
    }
    final type = data['type']?.toString();
    switch (type) {
      case 'ready':
        _iframeReady = true;
        _ready = true;
        _loadWorkbook();
        break;
      case 'loaded':
        widget.onReady?.call();
        break;
      case 'exported':
        if (!(_exportCompleter?.isCompleted ?? true)) {
          _exportCompleter?.complete(data['data']?.toString() ?? '');
        }
        break;
      case 'error':
        final msg = data['message']?.toString() ?? 'خطأ غير معروف';
        if (!(_exportCompleter?.isCompleted ?? true)) {
          _exportCompleter?.completeError(StateError(msg));
        }
        widget.onError?.call(msg);
        break;
    }
  }

  void _postToIframe(Map<String, dynamic> command) {
    final win = _iframe?.contentWindow;
    if (win == null) return;
    win.postMessage(jsonEncode(command), '*');
  }

  void _loadWorkbook() {
    _postToIframe({
      'cmd': 'load',
      'data': widget.base64Data,
      'editable': widget.editable,
    });
  }

  Future<String> _exportXlsx() {
    if (!_ready) {
      return Future.error(StateError('ExcelSheetView غير جاهز'));
    }
    final existing = _exportCompleter;
    if (existing != null && !existing.isCompleted) {
      return existing.future;
    }
    final completer = Completer<String>();
    _exportCompleter = completer;
    _postToIframe({'cmd': 'export'});
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw TimeoutException('انتهت مهلة تصدير الشيت'),
    );
  }

  @override
  void didUpdateWidget(covariant _ExcelSheetWeb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _detachController(oldWidget.controller);
      _attachController(widget.controller);
    }
    if (_iframeReady &&
        (oldWidget.base64Data != widget.base64Data ||
            oldWidget.editable != widget.editable)) {
      _loadWorkbook();
    }
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _detachController(widget.controller);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
