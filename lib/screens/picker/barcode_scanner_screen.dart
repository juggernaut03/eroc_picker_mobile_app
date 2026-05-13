import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../models/item_model.dart';
import '../../services/picker_service.dart';
import '../../utils/app_theme.dart';

enum _ResultKind { picked, full, unknown, error }

class _ScanResult {
  final _ResultKind kind;
  final String message;
  final String? itemName;
  final int? picked;
  final int? ordered;

  _ScanResult({
    required this.kind,
    required this.message,
    this.itemName,
    this.picked,
    this.ordered,
  });
}

class BarcodeScannerScreen extends StatefulWidget {
  final String assignmentId;
  final List<OrderItem> items;

  const BarcodeScannerScreen({
    super.key,
    required this.assignmentId,
    required this.items,
  });

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.code93,
      BarcodeFormat.itf,
      BarcodeFormat.qrCode,
    ],
  );

  // Working copy of item picked quantities so we don't refetch after every scan.
  late Map<String, int> _pickedQty;
  // Debounce: ignore the same code within this window.
  final Map<String, DateTime> _lastSeen = {};
  static const _debounce = Duration(milliseconds: 1500);

  _ScanResult? _lastResult;
  bool _busy = false;
  // Set to true once we successfully save at least one item — the caller
  // refreshes its list when we pop with `true`.
  bool _anyChange = false;

  @override
  void initState() {
    super.initState();
    _pickedQty = {
      for (final i in widget.items)
        i.id: i.pickerStatus?.pickedQuantity ?? 0,
    };
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy || !mounted) return;
    final raw = capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    if (raw == null || raw.isEmpty) return;

    final now = DateTime.now();
    final last = _lastSeen[raw];
    if (last != null && now.difference(last) < _debounce) return;
    _lastSeen[raw] = now;

    final match = widget.items.where((i) => i.barcode == raw).toList();
    if (match.isEmpty) {
      HapticFeedback.heavyImpact();
      setState(() => _lastResult = _ScanResult(
            kind: _ResultKind.unknown,
            message: 'Barcode not in this order: $raw',
          ));
      return;
    }

    final item = match.first;
    final ordered = item.orderedQuantity;
    final current = _pickedQty[item.id] ?? 0;

    if (current >= ordered) {
      HapticFeedback.mediumImpact();
      setState(() => _lastResult = _ScanResult(
            kind: _ResultKind.full,
            message: 'Already fully picked',
            itemName: item.itemName,
            picked: current,
            ordered: ordered,
          ));
      return;
    }

    setState(() => _busy = true);
    try {
      final next = current + 1;
      await PickerService.updateItemStatus(
        assignmentId: widget.assignmentId,
        orderItemId: item.id,
        pickedStatus: 'picked',
        pickedQuantity: next,
      );
      HapticFeedback.lightImpact();
      if (!mounted) return;
      setState(() {
        _pickedQty[item.id] = next;
        _anyChange = true;
        _lastResult = _ScanResult(
          kind: _ResultKind.picked,
          message: next >= ordered ? 'Completed' : 'Picked',
          itemName: item.itemName,
          picked: next,
          ordered: ordered,
        );
      });
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      setState(() => _lastResult = _ScanResult(
            kind: _ResultKind.error,
            message: 'Save failed: $e',
            itemName: item.itemName,
          ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Color _bannerColor(_ResultKind k) {
    switch (k) {
      case _ResultKind.picked: return const Color(0xFF16A34A);
      case _ResultKind.full:   return const Color(0xFFD97706);
      case _ResultKind.unknown: return const Color(0xFFDC2626);
      case _ResultKind.error:  return const Color(0xFFDC2626);
    }
  }

  IconData _bannerIcon(_ResultKind k) {
    switch (k) {
      case _ResultKind.picked: return Icons.check_circle_rounded;
      case _ResultKind.full:   return Icons.task_alt_rounded;
      case _ResultKind.unknown: return Icons.error_rounded;
      case _ResultKind.error:  return Icons.warning_amber_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _lastResult;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
