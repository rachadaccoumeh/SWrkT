import 'package:intl/intl.dart';

extension Date on DateTime {
  String get formatted => DateFormat('MMM dd, yyyy').format(this);
  String get timeAgo {
    final diff = DateTime.now().difference(this);
    if (diff.inDays > 365) return '${(diff.inDays / 365).floor()}y ago';
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  String get weekdayShort => DateFormat.E().format(this);
}

extension Double on double {
  String get clean => toStringAsFixed(truncateToDouble() == this ? 0 : 1);
}

extension Int on int {
  String get clean => toString();
}
