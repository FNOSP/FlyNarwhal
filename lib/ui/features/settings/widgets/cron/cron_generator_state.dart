/// Pure state model of the cron expression generator dialog, replicating the
/// field/option logic of the bejson Quartz cron builder: seven fields
/// (second minute hour day-of-month month day-of-week [year]), each one of a
/// small set of option shapes, assembled by joining the per-field fragments
/// with single spaces.
///
/// Two deliberate improvements over the reference page:
/// * day-of-month and day-of-week are kept mutually exclusive automatically
///   (exactly one of them is `?`), so the builder can never emit a combination
///   Quartz rejects;
/// * an empty "specific" selection falls back to `*` (or `?` for day/week),
///   matching the reference behavior.
library;

/// Option shapes a single cron field can take. Not every shape is valid for
/// every field; the dialog only offers the valid ones per tab.
enum CronOptionType {
  /// `*`
  every,

  /// `?` (day-of-month / day-of-week) or omitted (year).
  unspecified,

  /// `from-to`
  range,

  /// `from/step`
  increment,

  /// `1,5,9…` — an explicit multi-selection.
  specific,

  /// `dW` — nearest weekday to day-of-month `d` (day-of-month only).
  nearestWeekday,

  /// `L` — last day of the month (day-of-month only).
  lastDayOfMonth,

  /// `weekday#nth` — the nth weekday of the month (day-of-week only).
  nthWeekday,

  /// `weekdayL` — the last weekday of the month (day-of-week only).
  lastWeekday,
}

/// Which of the seven cron fields a [CronFieldState] describes; carries the
/// value bounds of that field.
enum CronFieldKind {
  second(0, 59),
  minute(0, 59),
  hour(0, 23),
  dayOfMonth(1, 31),
  month(1, 12),
  dayOfWeek(1, 7),
  year(2000, 3000);

  const CronFieldKind(this.minValue, this.maxValue);

  final int minValue;
  final int maxValue;
}

/// Editable state of one cron field: the chosen shape plus its parameters.
class CronFieldState {
  CronFieldState({
    required this.kind,
    required this.type,
    int? from,
    int? to,
    int? step,
    int? nth,
    this.starBase = false,
    Set<int>? specific,
  })  : from = from ?? kind.minValue,
        to = to ?? kind.maxValue,
        step = step ?? 1,
        nth = nth ?? 1,
        specific = specific ?? <int>{};

  final CronFieldKind kind;
  CronOptionType type;

  /// Range start, increment start, or the single parameter of
  /// [CronOptionType.nearestWeekday] / [CronOptionType.lastWeekday].
  int from;

  /// Range end.
  int to;

  /// Increment step.
  int step;

  /// True when an increment was parsed from the `*/N` spelling; the fragment
  /// then rebuilds with `*` instead of an explicit start (round-trip fidelity
  /// for hand-typed expressions — Quartz treats both the same).
  bool starBase;

  /// The "nth" of [CronOptionType.nthWeekday] (1…5); for
  /// [CronOptionType.nthWeekday] the weekday itself lives in [from].
  int nth;

  /// Checked values of [CronOptionType.specific].
  final Set<int> specific;

  int clamp(int value) => value.clamp(kind.minValue, kind.maxValue);

  CronFieldState copyWith({
    CronOptionType? type,
    int? from,
    int? to,
    int? step,
    int? nth,
    bool? starBase,
    Set<int>? specific,
  }) {
    return CronFieldState(
      kind: kind,
      type: type ?? this.type,
      from: from ?? this.from,
      to: to ?? this.to,
      step: step ?? this.step,
      nth: nth ?? this.nth,
      starBase: starBase ?? this.starBase,
      specific: specific ?? Set<int>.of(this.specific),
    );
  }

  /// The cron fragment for this field, bounds-clamped like the reference page.
  String buildFragment() {
    switch (type) {
      case CronOptionType.every:
        return '*';
      case CronOptionType.unspecified:
        return kind == CronFieldKind.year ? '' : '?';
      case CronOptionType.range:
        final lo = clamp(from);
        var hi = clamp(to);
        if (hi <= lo) hi = lo + 1 > kind.maxValue ? lo : lo + 1;
        return '$lo-$hi';
      case CronOptionType.increment:
        final start = starBase ? '*' : '${clamp(from)}';
        final stepValue = step.clamp(1, kind.maxValue);
        return '$start/$stepValue';
      case CronOptionType.specific:
        final values = specific.where((v) =>
            v >= kind.minValue && v <= kind.maxValue).toList()..sort();
        if (values.isEmpty) {
          // Reference behavior: an empty selection means "all"; for the two
          // optional fields "all" must still yield to the sibling field, so
          // day-of-week falls back to '?'.
          return kind == CronFieldKind.dayOfWeek ? '?' : '*';
        }
        return values.join(',');
      case CronOptionType.nearestWeekday:
        return '${clamp(from)}W';
      case CronOptionType.lastDayOfMonth:
        return 'L';
      case CronOptionType.nthWeekday:
        // Quartz: <day-of-week>#<nth>, weekday numbering 1=Sunday…7=Saturday.
        return '${clamp(from)}#${nth.clamp(1, 5)}';
      case CronOptionType.lastWeekday:
        return '${clamp(from)}L';
    }
  }
}

/// The whole seven-field generator state. Immutable snapshots are produced by
/// [copyWith]; the dialog holds one instance and rebuilds on change.
class CronGeneratorState {
  const CronGeneratorState({
    required this.second,
    required this.minute,
    required this.hour,
    required this.dayOfMonth,
    required this.month,
    required this.dayOfWeek,
    required this.year,
  });

  /// 每天 03:00 — the dialog's reset/default expression `0 0 3 * * ?`.
  factory CronGeneratorState.dailyAt3Am() =>
      CronGeneratorState.fromExpression('0 0 3 * * ?') ?? CronGeneratorState.defaults();

  factory CronGeneratorState.defaults() {
    return CronGeneratorState(
      second: CronFieldState(
          kind: CronFieldKind.second, type: CronOptionType.specific, specific: {0}),
      minute: CronFieldState(
          kind: CronFieldKind.minute, type: CronOptionType.specific, specific: {0}),
      hour: CronFieldState(
          kind: CronFieldKind.hour, type: CronOptionType.specific, specific: {3}),
      dayOfMonth:
          CronFieldState(kind: CronFieldKind.dayOfMonth, type: CronOptionType.every),
      month: CronFieldState(kind: CronFieldKind.month, type: CronOptionType.every),
      dayOfWeek: CronFieldState(
          kind: CronFieldKind.dayOfWeek, type: CronOptionType.unspecified),
      year: CronFieldState(kind: CronFieldKind.year, type: CronOptionType.unspecified),
    );
  }

  final CronFieldState second;
  final CronFieldState minute;
  final CronFieldState hour;
  final CronFieldState dayOfMonth;
  final CronFieldState month;
  final CronFieldState dayOfWeek;
  final CronFieldState year;

  CronFieldState field(CronFieldKind kind) {
    switch (kind) {
      case CronFieldKind.second:
        return second;
      case CronFieldKind.minute:
        return minute;
      case CronFieldKind.hour:
        return hour;
      case CronFieldKind.dayOfMonth:
        return dayOfMonth;
      case CronFieldKind.month:
        return month;
      case CronFieldKind.dayOfWeek:
        return dayOfWeek;
      case CronFieldKind.year:
        return year;
    }
  }

  CronGeneratorState copyWithField(CronFieldKind kind, CronFieldState field) {
    var next = _copyWith(kind, field);
    // Mutual exclusion: giving day-of-month a concrete value forces
    // day-of-week to '?', and vice versa — exactly one of the two may be
    // unspecified in a valid Quartz expression.
    if (kind == CronFieldKind.dayOfMonth &&
        field.type != CronOptionType.unspecified &&
        next.dayOfWeek.type != CronOptionType.unspecified) {
      next = next._copyWith(
          CronFieldKind.dayOfWeek,
          CronFieldState(
              kind: CronFieldKind.dayOfWeek, type: CronOptionType.unspecified));
    }
    if (kind == CronFieldKind.dayOfWeek &&
        field.type != CronOptionType.unspecified &&
        next.dayOfMonth.type != CronOptionType.unspecified) {
      next = next._copyWith(
          CronFieldKind.dayOfMonth,
          CronFieldState(
              kind: CronFieldKind.dayOfMonth, type: CronOptionType.unspecified));
    }
    return next;
  }

  CronGeneratorState _copyWith(CronFieldKind kind, CronFieldState field) {
    return CronGeneratorState(
      second: kind == CronFieldKind.second ? field : second,
      minute: kind == CronFieldKind.minute ? field : minute,
      hour: kind == CronFieldKind.hour ? field : hour,
      dayOfMonth: kind == CronFieldKind.dayOfMonth ? field : dayOfMonth,
      month: kind == CronFieldKind.month ? field : month,
      dayOfWeek: kind == CronFieldKind.dayOfWeek ? field : dayOfWeek,
      year: kind == CronFieldKind.year ? field : year,
    );
  }

  /// The assembled expression: six fields, or seven when a year is specified.
  String buildExpression() {
    var day = dayOfMonth.buildFragment();
    var week = dayOfWeek.buildFragment();
    if (day != '?' && week != '?') week = '?';
    if (day == '?' && week == '?') day = '*';
    final parts = [
      second.buildFragment(),
      minute.buildFragment(),
      hour.buildFragment(),
      day,
      month.buildFragment(),
      week,
    ];
    final yearFragment = year.buildFragment();
    if (yearFragment.isNotEmpty) parts.add(yearFragment);
    return parts.join(' ');
  }

  /// Reverse-fill from an existing expression (the reference page's "反解析").
  /// Returns null when any token is not one of the shapes the generator can
  /// produce — the dialog then keeps the user's hand-written text untouched.
  static CronGeneratorState? fromExpression(String expression) {
    final tokens = expression.trim().split(RegExp(r'\s+'));
    if (tokens.length != 6 && tokens.length != 7) return null;
    final second = _parseField(CronFieldKind.second, tokens[0]);
    final minute = _parseField(CronFieldKind.minute, tokens[1]);
    final hour = _parseField(CronFieldKind.hour, tokens[2]);
    final dayOfMonth = _parseField(CronFieldKind.dayOfMonth, tokens[3]);
    final month = _parseField(CronFieldKind.month, tokens[4]);
    final dayOfWeek = _parseField(CronFieldKind.dayOfWeek, tokens[5]);
    final year = tokens.length == 7
        ? _parseField(CronFieldKind.year, tokens[6])
        : CronFieldState(
            kind: CronFieldKind.year, type: CronOptionType.unspecified);
    if (second == null ||
        minute == null ||
        hour == null ||
        dayOfMonth == null ||
        month == null ||
        dayOfWeek == null ||
        year == null) {
      return null;
    }
    return CronGeneratorState(
      second: second,
      minute: minute,
      hour: hour,
      dayOfMonth: dayOfMonth,
      month: month,
      dayOfWeek: dayOfWeek,
      year: year,
    );
  }

  static final RegExp _rangePattern = RegExp(r'^(\d+)-(\d+)$');
  static final RegExp _incrementPattern = RegExp(r'^(\d+)/(\d+)$');
  static final RegExp _starIncrementPattern = RegExp(r'^\*/(\d+)$');
  static final RegExp _listPattern = RegExp(r'^\d+(,\d+)*$');
  static final RegExp _nearestWeekdayPattern = RegExp(r'^(\d+)W$');
  static final RegExp _nthWeekdayPattern = RegExp(r'^(\d+)#(\d+)$');
  static final RegExp _lastWeekdayPattern = RegExp(r'^(\d+)L$');

  static CronFieldState? _parseField(CronFieldKind kind, String token) {
    bool inRange(int v) => v >= kind.minValue && v <= kind.maxValue;

    if (token == '*') {
      if (kind == CronFieldKind.dayOfWeek) {
        // '*' is a legal week fragment only when day carries the schedule;
        // represent it as "every", the mutual-exclusion rule fixes the pair.
        return CronFieldState(kind: kind, type: CronOptionType.every);
      }
      return CronFieldState(kind: kind, type: CronOptionType.every);
    }
    if (token == '?') {
      if (kind != CronFieldKind.dayOfMonth &&
          kind != CronFieldKind.dayOfWeek &&
          kind != CronFieldKind.year) {
        return null;
      }
      return CronFieldState(kind: kind, type: CronOptionType.unspecified);
    }
    if (token == 'L' && kind == CronFieldKind.dayOfMonth) {
      return CronFieldState(kind: kind, type: CronOptionType.lastDayOfMonth);
    }

    RegExpMatch? match;
    if ((match = _nearestWeekdayPattern.firstMatch(token)) != null &&
        kind == CronFieldKind.dayOfMonth) {
      final day = int.parse(match!.group(1)!);
      if (!inRange(day)) return null;
      return CronFieldState(
          kind: kind, type: CronOptionType.nearestWeekday, from: day);
    }
    if ((match = _nthWeekdayPattern.firstMatch(token)) != null &&
        kind == CronFieldKind.dayOfWeek) {
      final weekday = int.parse(match!.group(1)!);
      final nth = int.parse(match.group(2)!);
      if (!inRange(weekday) || nth < 1 || nth > 5) return null;
      return CronFieldState(
          kind: kind,
          type: CronOptionType.nthWeekday,
          from: weekday,
          nth: nth);
    }
    if ((match = _lastWeekdayPattern.firstMatch(token)) != null &&
        kind == CronFieldKind.dayOfWeek) {
      final weekday = int.parse(match!.group(1)!);
      if (!inRange(weekday)) return null;
      return CronFieldState(
          kind: kind, type: CronOptionType.lastWeekday, from: weekday);
    }
    if ((match = _rangePattern.firstMatch(token)) != null) {
      final lo = int.parse(match!.group(1)!);
      final hi = int.parse(match.group(2)!);
      if (!inRange(lo) || !inRange(hi) || lo >= hi) return null;
      return CronFieldState(
          kind: kind, type: CronOptionType.range, from: lo, to: hi);
    }
    if ((match = _incrementPattern.firstMatch(token)) != null) {
      final start = int.parse(match!.group(1)!);
      final step = int.parse(match.group(2)!);
      if (!inRange(start) || step < 1) return null;
      return CronFieldState(
          kind: kind, type: CronOptionType.increment, from: start, step: step);
    }
    if ((match = _starIncrementPattern.firstMatch(token)) != null) {
      final step = int.parse(match!.group(1)!);
      if (step < 1) return null;
      return CronFieldState(
          kind: kind,
          type: CronOptionType.increment,
          from: kind.minValue,
          step: step,
          starBase: true);
    }
    if (_listPattern.hasMatch(token)) {
      final values = token.split(',').map(int.parse).toSet();
      if (values.any((v) => !inRange(v))) return null;
      return CronFieldState(
          kind: kind, type: CronOptionType.specific, specific: values);
    }
    return null;
  }
}
