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
            // Camera
            Positioned.fill(
              child: MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                errorBuilder: (context, error) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Camera error: ${error.errorDetails?.message ?? error.errorCode.name}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),

            // Reticle
            Center(
              child: Container(
                width: 260,
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),

            // Top bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.black.withValues(alpha: 0),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context, _anyChange),
                    ),
                    const Expanded(
                      child: Text(
                        'Scan barcode',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Toggle torch',
                      icon: const Icon(Icons.flash_on_rounded, color: Colors.white),
                      onPressed: () => _controller.toggleTorch(),
                    ),
                    IconButton(
                      tooltip: 'Switch camera',
                      icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white),
                      onPressed: () => _controller.switchCamera(),
                    ),
                  ],
                ),
              ),
            ),

            // Result banner
            if (result != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 88,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Container(
                    key: ValueKey('${result.message}_${result.picked}_${result.itemName}'),
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      color: _bannerColor(result.kind),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(_bannerIcon(result.kind), color: Colors.white, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (result.itemName != null)
                                Text(
                                  result.itemName!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              Text(
                                result.picked != null && result.ordered != null
                                    ? '${result.message} — ${result.picked}/${result.ordered}'
                                    : result.message,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_busy)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

            // Bottom Done button
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Done',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(context, _anyChange),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
