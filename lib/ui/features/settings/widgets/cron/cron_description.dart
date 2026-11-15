import '../../../../../l10n/generated/app_localizations.dart';

/// Human-readable summary of the cron expressions the generator produces.
///
/// Server-side descriptions would need cron-utils' i18n resource bundles,
/// which are a native-image reflection liability, so the summary is rendered
/// locally for the common shapes; anything else falls back to a generic
/// "custom schedule" label next to the raw expression.
String? describeCron(String expression, AppLocalizations l10n) {
  final tokens = expression.trim().split(RegExp(r'\s+'));
  if (tokens.length != 6 && tokens.length != 7) return null;
  final second = tokens[0];
  final minute = tokens[1];
  final hour = tokens[2];
  final day = tokens[3];
  final month = tokens[4];
  final week = tokens[5];
  if (month != '*') return null;

  int? single(String token) =>
      RegExp(r'^\d+$').hasMatch(token) ? int.tryParse(token) : null;

  // 每 N 秒 / 每 N 分钟 / 每 N 小时（其余字段全放开）
  final stepMinute = RegExp(r'^(\d+)/(\d+)$').firstMatch(minute);
  final stepHour = RegExp(r'^(\d+)/(\d+)$').firstMatch(hour);
  final stepSecond = RegExp(r'^(\d+)/(\d+)$').firstMatch(second);
  if (stepSecond != null && minute == '*' && hour == '*' && day == '*' && week == '?') {
    return l10n.cronDescEveryNSeconds(int.parse(stepSecond.group(2)!));
  }
  if (stepMinute != null && hour == '*' && day == '*' && week == '?') {
    return l10n.cronDescEveryNMinutes(int.parse(stepMinute.group(2)!));
  }
  if (stepHour != null && single(minute) != null && day == '*' && week == '?') {
    return l10n.cronDescEveryNHours(int.parse(stepHour.group(2)!));
  }

  final m = single(minute);
  final h = single(hour);
  if (second != '0' || m == null || h == null) return null;
  final time = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  // 每天 HH:MM
  if ((day == '*' || day == '?') && (week == '?' || week == '*')) {
    return l10n.cronDescDaily(time);
  }
  // 每周[几…] HH:MM —— 周字段是 Quartz 编号（1=周日…7=周六）的列表或区间
  if (day == '?' && week != '?' && week != '*') {
    final days = _expandWeek(week);
    if (days != null && days.isNotEmpty) {
      final names = days
          .map((d) => switch (d) {
                1 => l10n.cronWeekdaySun,
                2 => l10n.cronWeekdayMon,
                3 => l10n.cronWeekdayTue,
                4 => l10n.cronWeekdayWed,
                5 => l10n.cronWeekdayThu,
                6 => l10n.cronWeekdayFri,
                _ => l10n.cronWeekdaySat,
              })
          .join('、');
      return l10n.cronDescWeekly(names, time);
    }
  }
  // 每月 N 号 HH:MM
  if (week == '?' && day != '*' && day != '?') {
    final days = _expandNumericList(day, 1, 31);
    if (days != null && days.isNotEmpty) {
      return l10n.cronDescMonthly(days.join('、'), time);
    }
  }
  return null;
}

/// Expands a Quartz day-of-week token (list or range, numbers 1-7) to its
/// values; null when the token contains shapes the summary does not cover.
List<int>? _expandWeek(String token) => _expandNumericList(token, 1, 7);

List<int>? _expandNumericList(String token, int min, int max) {
  final values = <int>[];
  for (final part in token.split(',')) {
    final range = RegExp(r'^(\d+)-(\d+)$').firstMatch(part);
    if (range != null) {
      final lo = int.parse(range.group(1)!);
      final hi = int.parse(range.group(2)!);
      if (lo < min || hi > max || lo > hi) return null;
      values.addAll(List.generate(hi - lo + 1, (i) => lo + i));
      continue;
    }
    final value = int.tryParse(part);
    if (value == null || value < min || value > max) return null;
    values.add(value);
  }
  return values..sort();
}
