import 'package:flutter/material.dart';

Future<String?> showMaterialNamePicker({
  required BuildContext context,
  required List<String> materials,
  String? initialValue,
  String title = 'اختر الخامة',
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _MaterialNamePickerDialog(
      materials: materials,
      initialValue: initialValue,
      title: title,
    ),
  );
}

class MaterialNamePickerField extends StatelessWidget {
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final InputDecoration decoration;
  final String placeholder;
  final bool enabled;

  const MaterialNamePickerField({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.decoration = const InputDecoration(labelText: 'اسم الخامة'),
    this.placeholder = '— اختر الخامة —',
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final display = (value != null && value!.trim().isNotEmpty) ? value! : placeholder;
    return InkWell(
      onTap: !enabled
          ? null
          : () async {
              final picked = await showMaterialNamePicker(
                context: context,
                materials: options,
                initialValue: value,
              );
              if (picked == null) return;
              onChanged(picked);
            },
      child: InputDecorator(
        decoration: decoration.copyWith(
          suffixIcon: const Icon(Icons.search),
        ),
        isEmpty: value == null || value!.trim().isEmpty,
        child: Text(
          display,
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
          textDirection: TextDirection.ltr,
        ),
      ),
    );
  }
}

class _MaterialNamePickerDialog extends StatefulWidget {
  final List<String> materials;
  final String? initialValue;
  final String title;

  const _MaterialNamePickerDialog({
    required this.materials,
    required this.initialValue,
    required this.title,
  });

  @override
  State<_MaterialNamePickerDialog> createState() => _MaterialNamePickerDialogState();
}

class _MaterialNamePickerDialogState extends State<_MaterialNamePickerDialog> {
  late final TextEditingController _searchController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.materials;
    return widget.materials
        .where((name) => name.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.55;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        height: maxHeight,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'بحث',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              textDirection: TextDirection.ltr,
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('لا توجد خامات مطابقة للبحث'))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final name = filtered[index];
                        final selected = name == widget.initialValue;
                        return ListTile(
                          title: Text(
                            name,
                            textDirection: TextDirection.ltr,
                          ),
                          selected: selected,
                          onTap: () => Navigator.pop(context, name),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
      ],
    );
  }
}
