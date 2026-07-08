import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'excel_sheet_controller.dart';

/// Mobile / desktop implementation backed by a native WebView.
Widget createExcelSheetView({
  required String base64Data,
  required bool editable,
  ExcelSheetController? controller,
  VoidCallback? onReady,
  void Function(String message)? onError,
}) {
  return _ExcelSheetMobile(
    base64Data: base64Data,
    editable: editable,
    controller: controller,
    onReady: onReady,
    onError: onError,
  );
}

class _ExcelSheetMobile extends StatefulWidget {
  final String base64Data;
  final bool editable;
  final ExcelSheetController? controller;
  final VoidCallback? onReady;
  final void Function(String message)? onError;

  const _ExcelSheetMobile({
    required this.base64Data,
    required this.editable,
    this.controller,
    this.onReady,
    this.onError,
  });

  @override
  State<_ExcelSheetMobile> createState() => _ExcelSheetMobileState();
}

class _ExcelSheetMobileState extends State<_ExcelSheetMobile> {
  late final WebViewController _web;
  bool _ready = false;
  Completer<String>? _exportCompleter;

  @override
  void initState() {
    super.initState();
    _attachController(widget.controller);
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel('Bridge', onMessageReceived: _onBridgeMessage)
      ..loadFlutterAsset('assets/spreadsheet/index.html');
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

  @override
  void didUpdateWidget(covariant _ExcelSheetMobile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _detachController(oldWidget.controller);
      _attachController(widget.controller);
    }
    if (_ready &&
        (oldWidget.base64Data != widget.base64Data ||
            oldWidget.editable != widget.editable)) {
      _loadWorkbook();
    }
  }

  @override
  void dispose() {
    _detachController(widget.controller);
    super.dispose();
  }

  void _onBridgeMessage(JavaScriptMessage message) {
    Map<String, dynamic> data;
    try {
      data = Map<String, dynamic>.from(jsonDecode(message.message) as Map);
    } catch (_) {
      return;
    }
    final type = data['type']?.toString();
    switch (type) {
      case 'ready':
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

  void _loadWorkbook() {
    final b64 = jsonEncode(widget.base64Data);
    final editable = widget.editable ? 'true' : 'false';
    _web.runJavaScript('window.WM.loadWorkbook($b64, $editable);');
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
    _web.runJavaScript('window.WM.exportWorkbook();');
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw TimeoutException('انتهت مهلة تصدير الشيت'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _web);
  }
}
