import 'package:intl/intl.dart';

String formatDate(DateTime? dt) {
  if (dt == null) return '—';
  return DateFormat('dd MMM yyyy').format(dt.toLocal());
}

String formatDateTime(DateTime? dt) {
  if (dt == null) return '—';
  return DateFormat('dd MMM yyyy, hh:mm a').format(dt.toLocal());
}

String formatTime(DateTime? dt) {
  if (dt == null) return '—';
  return DateFormat('hh:mm a').format(dt.toLocal());
}
