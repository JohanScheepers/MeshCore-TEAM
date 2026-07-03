// Copyright (c) 2026 tmacinc
// Licensed under CC BY-NC-SA 4.0

/// Formats a message timestamp for display in chat bubbles.
///
/// - Same calendar day: HH:mm
/// - Within the past 7 days: Weekday HH:mm  (e.g. "Thursday 14:32")
/// - Older: Mon DD HH:mm  (e.g. "Jun 18 14:32")
String formatMessageTime(DateTime timestamp) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final msgDay = DateTime(timestamp.year, timestamp.month, timestamp.day);
  final hhmm =
      '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';

  if (msgDay == today) return hhmm;

  final daysAgo = today.difference(msgDay).inDays;
  if (daysAgo < 7) {
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    return '${weekdays[timestamp.weekday - 1]} $hhmm';
  }

  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[timestamp.month - 1]} ${timestamp.day} $hhmm';
}
