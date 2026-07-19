/// Date utility functions
class DateTimeUtils {
  const DateTimeUtils._();

  /// Format timestamp to readable date string
  /// Format: YYYY-MM-DD HH:mm
  static String formatTimestamp(int timestamp) {
    if (timestamp == 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Format timestamp to date only (YYYY-MM-DD)
  static String formatDateOnly(int timestamp) {
    if (timestamp == 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Format timestamp to time only (HH:mm:ss)
  static String formatTimeOnly(int timestamp) {
    if (timestamp == 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
  }

  /// Format seconds to Chinese readable duration
  /// Example: 3661 -> "1 小时 1 分钟 1 秒"
  static String formatSecondsToCNDateTime(int seconds) {
    if (seconds <= 0) return '0 分钟';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    if (hours > 0 && minutes > 0) {
      return '$hours 小时 $minutes 分钟';
    } else if (hours > 0) {
      return '$hours 小时';
    } else if (minutes > 0 && remainingSeconds > 0) {
      return '$minutes 分钟 $remainingSeconds 秒';
    } else {
      return '$minutes 分钟';
    }
  }

  /// Format seconds to standard duration (HH:mm:ss)
  static String formatSecondsToDuration(int seconds) {
    if (seconds <= 0) return '00:00';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Check if timestamp is today
  static bool isToday(int timestamp) {
    if (timestamp == 0) return false;
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  /// Get relative time string (e.g., "2 hours ago", "just now")
  static String getRelativeTime(int timestamp, {String locale = 'zh'}) {
    if (timestamp == 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (locale == 'zh') {
      if (difference.inSeconds < 60) {
        return '刚刚';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes} 分钟前';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} 小时前';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} 天前';
      } else if (difference.inDays < 30) {
        return '${difference.inDays ~/ 7} 周前';
      } else if (difference.inDays < 365) {
        return '${difference.inDays ~/ 30} 月前';
      } else {
        return '${difference.inDays ~/ 365} 年前';
      }
    } else {
      if (difference.inSeconds < 60) {
        return 'just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes} minutes ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} hours ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else if (difference.inDays < 30) {
        return '${difference.inDays ~/ 7} weeks ago';
      } else if (difference.inDays < 365) {
        return '${difference.inDays ~/ 30} months ago';
      } else {
        return '${difference.inDays ~/ 365} years ago';
      }
    }
  }
}