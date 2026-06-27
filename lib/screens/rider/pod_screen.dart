import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:signature/signature.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/order_model.dart';
import '../../services/rider_service.dart';
import '../../utils/app_theme.dart';

class PodScreen extends StatefulWidget {
  final DeliveryAssignment assignment;
  final bool otpRequired;

  const PodScreen({
    super.key,
    required this.assignment,
    this.otpRequired = false,
  });

  @override
  State<PodScreen> createState() => _PodScreenState();
}

class _PodScreenState extends State<PodScreen> {
  bool _loading = false;
  final _notesCtrl = TextEditingController();
  final _recipientCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final List<File> _photos = [];
  final _picker = ImagePicker();
  final _signatureCtrl = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  @override
  void dispose() {
    _notesCtrl.dispose();
    _recipientCtrl.dispose();
    _otpCtrl.dispose();
    _signatureCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 75);
    if (file != null && mounted) setState(() => _photos.add(File(file.path)));
  }

  Future<String?> _uploadSignature() async {
    if (_signatureCtrl.isEmpty) return null;
    final Uint8List? bytes = await _signatureCtrl.toPngBytes();
    if (bytes == null || bytes.isEmpty) return null;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/sig_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(bytes);
    return RiderService.uploadPodPhoto(file);
  }

  Future<void> _submit() async {
    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one delivery photo'), backgroundColor: AppTheme.error),
      );
      return;
    }
    if (widget.otpRequired && _otpCtrl.text.trim().length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the customer OTP'), backgroundColor: AppTheme.error),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final urls = <String>[];
      for (final f in _photos) {
        urls.add(await RiderService.uploadPodPhoto(f));
      }
      final signatureUrl = await _uploadSignature();

      String? lat;
      String? lng;
      try {
        final pos = await Geolocator.getCurrentPosition();
        lat = pos.latitude.toString();
        lng = pos.longitude.toString();
      } catch (_) {}

      await RiderService.completeDelivery(
        widget.assignment.id,
        photoUrls: urls,
        notes: _notesCtrl.text.trim(),
        recipientName: _recipientCtrl.text.trim(),
        latitude: lat,
        longitude: lng,
        signatureUrl: signatureUrl,
        otp: widget.otpRequired ? _otpCtrl.text.trim() : null,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text('POD · #${widget.assignment.ordersIdorders}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Photos', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._photos.map((f) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(f, width: 72, height: 72, fit: BoxFit.cover),
                  )),
              OutlinedButton.icon(
                onPressed: _pickPhoto,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Add photo'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Customer signature (optional)', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Signature(
                controller: _signatureCtrl,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: () => _signatureCtrl.clear(), child: const Text('Clear signature')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _recipientCtrl,
            decoration: const InputDecoration(
              labelText: 'Recipient name (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          if (widget.otpRequired) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: 'Customer OTP',
                border: OutlineInputBorder(),
                helperText: 'Ask the customer for their delivery code',
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _loading ? null : _submit,
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
              child: _loading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Submit proof of delivery'),
            ),
          ),
        ],
      ),
    );
  }
}
