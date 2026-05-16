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
      case 'manager': return 'Manager';
      case 'admin': return 'Admin';
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
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            role == 'manager' ? 'Manager' : role == 'admin' ? 'Admin' : 'Picker',
                            style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: isActive
                                ? const Color(0xFF34D399).withValues(alpha: 0.3)
                                : AppTheme.error.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isActive ? 'Active' : 'Inactive',
                            style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Active Orders',
                  value: '$activeOrders',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: 'Load',
                  value: loadLabel,
                  valueColor: loadColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const _MetricTile({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                  color: valueColor != null ? Colors.white : Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                )),
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: AppTheme.primary),
                ),
                const SizedBox(width: 10),
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              ],
            ),
            const SizedBox(height: 10),
            Container(height: 1, color: AppTheme.border),
            const SizedBox(height: 6),
            ...children,
          ],
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? valueWidget;
  final Widget? trailing;
  const _InfoRow({required this.label, this.value, this.valueWidget, this.trailing})
      : assert(value != null || valueWidget != null);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 120, child: Text(label, style: _labelStyle)),
            Expanded(
              child: valueWidget ?? Text(value!, style: _valueStyle),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      );
}

class _CopyRow extends StatelessWidget {
  final String label, value;
  final bool monospace;
  const _CopyRow({required this.label, required this.value, this.monospace = false});

  @override
  Widget build(BuildContext context) => _InfoRow(
        label: label,
        value: value,
        trailing: value == '—'
            ? null
            : IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.copy_rounded, size: 18),
                tooltip: 'Copy',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$label copied')),
                  );
                },
              ),
      );
}

class _StoreChip extends StatelessWidget {
  final String code;
  const _StoreChip({required this.code});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.primaryLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
        ),
        child: Text(code,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primary)),
      );
}

class _StatusPill extends StatelessWidget {
  final bool active;
  const _StatusPill({required this.active});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: (active ? AppTheme.success : AppTheme.error).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          active ? 'Active' : 'Inactive',
          style: TextStyle(
            color: active ? AppTheme.success : AppTheme.error,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}
