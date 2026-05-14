import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/order_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/helpers.dart';

class PickerDetailScreen extends StatelessWidget {
  final AssignedUser picker;
  const PickerDetailScreen({super.key, required this.picker});

  String get _initials => picker.name.trim().split(' ')
      .map((w) => w.isNotEmpty ? w[0] : '')
      .take(2)
      .join()
      .toUpperCase();

  Color get _loadColor {
    if (picker.activeOrders == 0) return AppTheme.textMuted;
    if (picker.activeOrders <= 2) return AppTheme.success;
    if (picker.activeOrders <= 4) return AppTheme.warning;
    return AppTheme.error;
  }

  String get _loadLabel {
    if (picker.activeOrders == 0) return 'Free';
    if (picker.activeOrders <= 2) return 'Low';
    if (picker.activeOrders <= 4) return 'Medium';
    return 'High';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Picker Details',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _ProfileHeader(
            initials: _initials,
            name: picker.name,
            email: picker.email,
            role: picker.role ?? 'picker',
            isActive: picker.isActive ?? true,
            activeOrders: picker.activeOrders,
            loadColor: _loadColor,
            loadLabel: _loadLabel,
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Account',
            icon: Icons.badge_rounded,
            children: [
              _CopyRow(label: 'Picker ID', value: picker.id, monospace: true),
              _InfoRow(label: 'Name', value: picker.name),
              _CopyRow(label: 'Email', value: picker.email),
              _CopyRow(label: 'Phone', value: picker.phone ?? '—'),
              _InfoRow(label: 'Role', value: _humanRole(picker.role)),
              _InfoRow(
                label: 'Status',
                valueWidget: _StatusPill(active: picker.isActive ?? true),
              ),
              if (!(picker.isActive ?? true))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.warning),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Picker has paused themselves — round-robin will skip them until they resume.',
                            style: TextStyle(fontSize: 12, color: AppTheme.warning, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Assignment Scope',
            icon: Icons.store_rounded,
            children: [
              _InfoRow(label: 'Project Code', value: picker.projectCode ?? '—'),
              _InfoRow(
                label: 'Store Codes',
                valueWidget: picker.storeCodes.isEmpty
                    ? const Text('—', style: _valueStyle)
                    : Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: picker.storeCodes
                            .map((s) => _StoreChip(code: s))
                            .toList(),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Workload',
            icon: Icons.work_rounded,
            children: [
              _InfoRow(label: 'Active Orders', value: '${picker.activeOrders}'),
              _InfoRow(label: 'Load', value: _loadLabel),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'System',
            icon: Icons.dns_rounded,
            children: [
              _InfoRow(
                label: 'FCM Token',
                value: picker.fcmToken == null || picker.fcmToken!.isEmpty
                    ? 'Not registered'
                    : '${picker.fcmToken!.substring(0, picker.fcmToken!.length.clamp(0, 18))}…',
                trailing: picker.fcmToken != null && picker.fcmToken!.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        tooltip: 'Copy full token',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: picker.fcmToken!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('FCM token copied')),
                          );
                        },
                      )
                    : null,
              ),
              _InfoRow(
                label: 'Created',
                value: picker.createdAt != null ? formatDateTime(picker.createdAt) : '—',
              ),
              _InfoRow(
                label: 'Updated',
                value: picker.updatedAt != null ? formatDateTime(picker.updatedAt) : '—',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _humanRole(String? r) {
    switch (r) {
      case 'picker': return 'Picker';
      case 'store_manager': return 'Store Manager';
      default: return r ?? '—';
    }
  }
}

const _labelStyle = TextStyle(fontSize: 14, color: AppTheme.textSecondary);
const _valueStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary);

class _ProfileHeader extends StatelessWidget {
  final String initials, name, email, role, loadLabel;
  final bool isActive;
  final int activeOrders;
  final Color loadColor;

  const _ProfileHeader({
    required this.initials,
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
    required this.activeOrders,
    required this.loadColor,
    required this.loadLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary.withValues(alpha: 0.95), AppTheme.primary.withValues(alpha: 0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    initials.isEmpty ? '?' : initials,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
