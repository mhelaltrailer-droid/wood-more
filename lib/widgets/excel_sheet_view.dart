import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Controller that lets the host screen trigger an export of the current
/// workbook shown inside [ExcelSheetView].
class ExcelSheetController {
  _ExcelSheetViewState? _state;

  bool get isReady => _state?._ready ?? false;

  /// Asks the embedded spreadsheet engine to serialize the current workbook
  /// back into an .xlsx file and returns it as a base64 string.
  Future<String> exportXlsx() {
    final state = _state;
    if (state == null) {
      throw StateError('ExcelSheetView غير جاهز');
    }
    return state._exportXlsx();
  }
}

/// Renders an .xlsx file (given as base64) inside a WebView using a real
/// spreadsheet engine (Luckysheet), preserving the original formatting.
/// When [editable] is true the user can edit cells and the host can export
/// the edited workbook back to .xlsx via [controller].
class ExcelSheetView extends StatefulWidget {
  final String base64Data;
  final bool editable;
  final ExcelSheetController? controller;
  final VoidCallback? onReady;
  final void Function(String message)? onError;

  const ExcelSheetView({
    super.key,
    required this.base64Data,
    this.editable = false,
    this.controller,
    this.onReady,
    this.onError,
  });

  @override
  State<ExcelSheetView> createState() => _ExcelSheetViewState();
}

class _ExcelSheetViewState extends State<ExcelSheetView> {
  late final WebViewController _web;
  bool _ready = false;
  Completer<String>? _exportCompleter;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel('Bridge', onMessageReceived: _onBridgeMessage)
      ..loadFlutterAsset('assets/spreadsheet/index.html');
  }

  @override
  void didUpdateWidget(covariant ExcelSheetView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?._state = null;
      widget.controller?._state = this;
    }
    if (_ready &&
        (oldWidget.base64Data != widget.base64Data ||
            oldWidget.editable != widget.editable)) {
      _loadWorkbook();
    }
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) {
      widget.controller?._state = null;
    }
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
