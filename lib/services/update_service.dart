import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'api_service.dart';

class UpdateService {
  /// Call once after splash navigation resolves.
  /// Silent on any error — never blocks the app unless force_update is true.
  static Future<void> check(BuildContext context) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentCode = int.tryParse(info.buildNumber) ?? 0;

      final res = await ApiService.getRaw('/app/version');
      if (res == null) return;

      final serverCode = (res['version_code'] as num?)?.toInt() ?? 0;
      if (serverCode <= currentCode) return;

      final force = res['force_update'] as bool? ?? false;

      if (context.mounted) {
        _show(
          context,
          versionName: res['version_name'] as String? ?? '',
          apkUrl: res['apk_url'] as String? ?? '',
          releaseNotes: res['release_notes'] as String? ?? '',
          force: force,
        );
      }
    } catch (_) {
      // Silent — update check must never crash the app
    }
  }

  static void _show(
    BuildContext context, {
    required String versionName,
    required String apkUrl,
    required String releaseNotes,
    required bool force,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: !force,
        child: _UpdateDialog(
          versionName: versionName,
          apkUrl: apkUrl,
          releaseNotes: releaseNotes,
          force: force,
        ),
      ),
    );
  }
}

class _UpdateDialog extends StatefulWidget {
  final String versionName, apkUrl, releaseNotes;
  final bool force;

  const _UpdateDialog({
    required this.versionName,
    required this.apkUrl,
    required this.releaseNotes,
    required this.force,
  });

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double _progress = 0;
  bool _downloading = false;
  String? _error;

  Future<void> _download() async {
    setState(() {
      _downloading = true;
      _error = null;
      _progress = 0;
    });

    try {
      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/picker_update.apk';

      await Dio().download(
        widget.apkUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() => _progress = received / total);
          }
        },
        options: Options(
          receiveTimeout: const Duration(minutes: 10),
          sendTimeout: const Duration(seconds: 30),
        ),
      );

      await OpenFilex.open(savePath);
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message ?? 'Download failed. Check your connection.';
          _downloading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed: $e';
          _downloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1D4ED8), Color(0xFF6C3CE1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.system_update_rounded, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 16),

            Text(
              widget.force ? 'Update Required' : 'Update Available',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            Text(
              'Version ${widget.versionName} is ready to install.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),

            if (widget.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  widget.releaseNotes,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
                ),
              ),
            ],

            if (widget.force) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFDC2626)),
                    SizedBox(width: 5),
                    Text(
                      'Required — you must update to continue',
                      style: TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Progress bar
            if (_downloading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF1D4ED8)),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Downloading…', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  Text('${(_progress * 100).round()}%',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8))),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Error
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_error!, style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
              ),
              const SizedBox(height: 12),
            ],

            // Buttons
            Row(
              children: [
                if (!widget.force && !_downloading) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      child: const Text('Later', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _downloading ? null : _download,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D4ED8),
                      disabledBackgroundColor: const Color(0xFFE2E8F0),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _downloading
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            _error != null ? 'Retry' : 'Update Now',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
