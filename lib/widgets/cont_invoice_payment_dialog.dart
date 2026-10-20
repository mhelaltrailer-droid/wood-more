import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../core/cont_invoices_constants.dart';
import '../models/cont_invoice_model.dart';
import '../models/user_model.dart';

class ContInvoicePaymentDraft {
  final double amount;
  final String comment;
  final List<Map<String, dynamic>> attachments;

  const ContInvoicePaymentDraft({
    required this.amount,
    required this.comment,
    required this.attachments,
  });
}

bool canRecordContInvoicePayment(UserModel user, ContInvoiceModel inv) {
  if (inv.id == null) return false;
  if (inv.status != contStatusApproved &&
      inv.status != contStatusPartiallyPaid) {
    return false;
  }
  if (inv.remainingAmount <= 0.009) return false;
  return isContInvoicesAhAminEmail(user.email) || user.isPrimaryAppAdmin;
}

Future<ContInvoicePaymentDraft?> showContInvoicePaymentDialog({
  required BuildContext context,
  required double remaining,
  required NumberFormat moneyFmt,
  String? invoiceLabel,
}) async {
  if (remaining <= 0) return null;
  final amountC = TextEditingController(
    text: remaining == remaining.roundToDouble()
        ? remaining.toInt().toString()
        : remaining.toStringAsFixed(2),
  );
  final noteC = TextEditingController();
  final vouchers = <Map<String, dynamic>>[];
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('تسجيل دفعة صرف'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (invoiceLabel != null && invoiceLabel.trim().isNotEmpty)
                  Text(
                    invoiceLabel,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                Text(
                  'باقي هذا المستخلص فقط: ${moneyFmt.format(remaining)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                const Text(
                  'الصرف على المستخلص ده وحده. مستند الاستلام إلزامي مع أي صرف جزئي أو كلي.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountC,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    _PaymentMaxValueFormatter(remaining),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'المبلغ المصروف الآن',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteC,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظة (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: vouchers.length >= contPaymentVoucherMaxFiles
                      ? null
                      : () async {
                          final files = await _pickPaymentVouchers(
                            context: ctx,
                            alreadyCount: vouchers.length,
                          );
                          if (files.isEmpty) return;
                          setLocal(() => vouchers.addAll(files));
                        },
                  icon: const Icon(Icons.attach_file),
                  label: Text(
                    vouchers.isEmpty
                        ? 'إرفاق مستند الاستلام (إلزامي)'
                        : 'إضافة ملف (${vouchers.length})',
                  ),
                ),
                ...vouchers.asMap().entries.map(
                  (e) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.insert_drive_file_outlined),
                    title: Text(
                      e.value['file_name'] as String? ?? 'مرفق',
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setLocal(() => vouchers.removeAt(e.key)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed:
                  vouchers.isEmpty ? null : () => Navigator.pop(ctx, true),
              child: const Text('تأكيد الصرف'),
            ),
          ],
        ),
      ),
    ),
  );
  if (ok != true) return null;
  final amount = double.tryParse(amountC.text.replaceAll(',', '').trim());
  if (amount == null || amount <= 0) return null;
  if (vouchers.isEmpty) return null;
  return ContInvoicePaymentDraft(
    amount: amount,
    comment: noteC.text.trim(),
    attachments: List<Map<String, dynamic>>.from(vouchers),
  );
}

String _paymentMimeFromExtension(String? ext) {
  switch ((ext ?? '').toLowerCase()) {
    case 'pdf':
      return 'application/pdf';
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    default:
      return '';
  }
}

Future<List<Map<String, dynamic>>> _pickPaymentVouchers({
  required BuildContext context,
  required int alreadyCount,
}) async {
  final remaining = contPaymentVoucherMaxFiles - alreadyCount;
  if (remaining <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('الحد الأقصى $contPaymentVoucherMaxFiles ملفات')),
    );
    return const [];
  }
  final result = await FilePicker.pickFiles(
    allowMultiple: true,
    type: FileType.custom,
    allowedExtensions: contPaymentVoucherExtensions,
    withData: true,
  );
  if (result == null || result.files.isEmpty) return const [];
  final out = <Map<String, dynamic>>[];
  for (final f in result.files) {
    if (out.length >= remaining) break;
    final bytes = f.bytes;
    if (bytes == null) continue;
    if (bytes.length > contPaymentVoucherMaxBytes) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('الملف ${f.name} أكبر من 10 ميجا'),
            backgroundColor: Colors.red,
          ),
        );
      }
      continue;
    }
    final mime = _paymentMimeFromExtension(f.extension);
    if (mime.isEmpty) continue;
    out.add({
      'file_name': f.name,
      'mime_type': mime,
      'data_base64': base64Encode(bytes),
      'size_bytes': bytes.length,
    });
  }
  return out;
}

class _PaymentMaxValueFormatter extends TextInputFormatter {
  final double max;

  _PaymentMaxValueFormatter(this.max);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final t = newValue.text.replaceAll(',', '').trim();
    if (t.isEmpty || t == '.') return newValue;
    final v = double.tryParse(t);
    if (v == null) return oldValue;
    if (v > max) {
      final capped = max == max.roundToDouble()
          ? max.toInt().toString()
          : max.toString();
      return TextEditingValue(
        text: capped,
        selection: TextSelection.collapsed(offset: capped.length),
      );
    }
    return newValue;
  }
}
