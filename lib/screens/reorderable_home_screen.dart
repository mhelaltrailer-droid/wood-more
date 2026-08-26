import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/home_icon_order_service.dart';
import '../services/storage_service.dart';
import '../widgets/home_icon_builder.dart';

class ReorderableHomeScreen extends StatefulWidget {
  final UserModel user;
  final Map<String, bool>? iconConfig;
  final int pendingReportsSysCount;
  final int pendingShopDrawingCount;
  final int pendingInvoicesOwnerCount;
  final int unreadMeetingsCount;
  final Future<void> Function()? onReportsSysReturn;
  final Future<void> Function()? onShopDrawingReturn;
  final Future<void> Function()? onInvoicesOwnerReturn;
  final Future<void> Function()? onMeetingsReturn;

  const ReorderableHomeScreen({
    super.key,
    required this.user,
    required this.iconConfig,
    this.pendingReportsSysCount = 0,
    this.pendingShopDrawingCount = 0,
    this.pendingInvoicesOwnerCount = 0,
    this.unreadMeetingsCount = 0,
    this.onReportsSysReturn,
    this.onShopDrawingReturn,
    this.onInvoicesOwnerReturn,
    this.onMeetingsReturn,
  });

  @override
  State<ReorderableHomeScreen> createState() => _ReorderableHomeScreenState();
}

class _ReorderableHomeScreenState extends State<ReorderableHomeScreen> {
  List<String> _orderedIconIds = const [];
  bool _loadingOrder = true;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  @override
  void didUpdateWidget(covariant ReorderableHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.iconConfig != widget.iconConfig ||
        oldWidget.user.id != widget.user.id) {
      _loadOrder();
    }
  }

  Future<void> _loadOrder() async {
    setState(() => _loadingOrder = true);
    try {
      final saved = await getStorage().getUserHomeIconOrder(widget.user.id);
      if (!mounted) return;
      setState(() {
        _orderedIconIds = resolveHomeIconOrder(
          user: widget.user,
          iconConfig: widget.iconConfig,
          savedOrder: saved,
        );
        _loadingOrder = false;
      });
    } catch (_) {
      if (!mounted) return;
      _applyResolvedOrder();
    }
  }

  void _applyResolvedOrder({List<String>? savedOrder}) {
    setState(() {
      _orderedIconIds = resolveHomeIconOrder(
        user: widget.user,
        iconConfig: widget.iconConfig,
        savedOrder: savedOrder ?? _orderedIconIds,
      );
      _loadingOrder = false;
    });
  }

  Future<void> _persistOrder() async {
    try {
      await getStorage().setUserHomeIconOrder(
        userId: widget.user.id,
        iconOrder: _orderedIconIds,
      );
    } catch (_) {}
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      var targetIndex = newIndex;
      if (targetIndex > oldIndex) targetIndex--;
      final moved = _orderedIconIds.removeAt(oldIndex);
      _orderedIconIds.insert(targetIndex, moved);
    });
    _persistOrder();
  }

  String? _roleFooterLabel() {
    if (widget.user.isSiteEngineer) return 'مهندس موقع';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final footerLabel = _roleFooterLabel();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Text(
            'مرحباً، ${widget.user.name}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          if (_loadingOrder)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_orderedIconIds.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text('لا توجد أيقونات ظاهرة في الواجهة الرئيسية.'),
                ),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _orderedIconIds.length,
              onReorder: _onReorder,
              itemBuilder: (context, index) {
                final iconId = _orderedIconIds[index];
                return ReorderableDelayedDragStartListener(
                  key: ValueKey(iconId),
                  index: index,
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: index == _orderedIconIds.length - 1 ? 0 : 20,
                    ),
                    child: HomeIconBuilder.build(
                      context: context,
                      user: widget.user,
                      iconId: iconId,
                      pendingReportsSysCount: widget.pendingReportsSysCount,
                      pendingShopDrawingCount: widget.pendingShopDrawingCount,
                      pendingInvoicesOwnerCount: widget.pendingInvoicesOwnerCount,
                      unreadMeetingsCount: widget.unreadMeetingsCount,
                      onReportsSysReturn: widget.onReportsSysReturn,
                      onShopDrawingReturn: widget.onShopDrawingReturn,
                      onInvoicesOwnerReturn: widget.onInvoicesOwnerReturn,
                      onMeetingsReturn: widget.onMeetingsReturn,
                    ),
                  ),
                );
              },
            ),
          if (footerLabel != null) ...[
            const SizedBox(height: 32),
            Text(
              footerLabel,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
