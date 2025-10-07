import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:institutation_payment_system/widgets/responsive_dialog.dart';

class PaymentSubmissionResult {
  final String method;
  final String? note;
  final Uint8List? proofBytes;
  final String? proofExtension; // e.g., 'png', 'jpg'
  PaymentSubmissionResult({required this.method, this.note, this.proofBytes, this.proofExtension});
}

class PaymentSubmissionDialog extends StatefulWidget {
  final String title;
  final bool showAdminHint;
  const PaymentSubmissionDialog({super.key, required this.title, this.showAdminHint = false});
  @override
  State<PaymentSubmissionDialog> createState() => _PaymentSubmissionDialogState();
}

class _PaymentSubmissionDialogState extends State<PaymentSubmissionDialog> {
  String _method = 'cash';
  final TextEditingController _note = TextEditingController();
  Uint8List? _bytes; String? _ext; bool _picking = false;

  @override
  void dispose() { _note.dispose(); super.dispose(); }

  Future<void> _pickImage() async {
    setState(() => _picking = true);
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (file != null) {
        final b = await file.readAsBytes();
        final name = file.name.toLowerCase();
        String ext = 'jpg';
        if (name.endsWith('.png')) ext = 'png'; else if (name.endsWith('.webp')) ext = 'webp'; else if (name.endsWith('.jpeg')) ext = 'jpg';
        setState(() { _bytes = b; _ext = ext; });
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _submit() {
    Navigator.pop<PaymentSubmissionResult>(context, PaymentSubmissionResult(method: _method, note: _note.text.trim().isEmpty ? null : _note.text.trim(), proofBytes: _bytes, proofExtension: _ext));
  }

  @override
  Widget build(BuildContext context) {
    final content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: _method, decoration: const InputDecoration(labelText: 'Mode of Payment', border: OutlineInputBorder()), items: const [
          DropdownMenuItem(value: 'cash', child: Text('Cash')),
          DropdownMenuItem(value: 'upi', child: Text('UPI')),
          DropdownMenuItem(value: 'netbanking', child: Text('Netbanking')),
        ], onChanged: (v) => setState(() => _method = v ?? _method)),
        const SizedBox(height: 8),
        TextField(controller: _note, decoration: const InputDecoration(labelText: 'Comment (optional)', border: OutlineInputBorder()), maxLines: 2),
        const SizedBox(height: 8),
        Row(children: [
          OutlinedButton.icon(onPressed: _picking ? null : _pickImage, icon: const Icon(Icons.attachment, color: Colors.blue), label: const Text('Attach screenshot')),
          const SizedBox(width: 8),
          if (_bytes != null) const Icon(Icons.check_circle, color: Colors.green),
          if (_bytes != null) const SizedBox(width: 4),
          if (_bytes != null) const Expanded(child: Text('Attached', overflow: TextOverflow.ellipsis)) else const SizedBox.shrink(),
          if (_picking) const Padding(padding: EdgeInsets.only(left: 8), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
        ]),
        if (widget.showAdminHint) Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: const [Icon(Icons.info_outline, color: Colors.blue, size: 18), SizedBox(width: 6), Expanded(child: Text('Institution Admin submission will be marked paid immediately, receipt generated.'))])),
      ]),
    );

    return AppResponsiveDialog(
      titleText: widget.title,
      content: content,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Submit')),
      ],
    );
  }
}
