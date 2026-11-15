import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/ui/features/settings/widgets/cron/cron_generator_state.dart';

void main() {
  group('CronGeneratorState.buildExpression', () {
    test('defaults describe 每天 03:00 with an omitted year', () {
      final state = CronGeneratorState.defaults();
      expect(state.buildExpression(), '0 0 3 * * ?');
    });

    test('every/increment/range fragments per field', () {
      var state = CronGeneratorState.defaults();
      state = state.copyWithField(
        CronFieldKind.second,
        CronFieldState(kind: CronFieldKind.second, type: CronOptionType.every),
      );
      state = state.copyWithField(
        CronFieldKind.minute,
        CronFieldState(
            kind: CronFieldKind.minute,
            type: CronOptionType.increment,
            from: 0,
            step: 30),
      );
      expect(state.buildExpression(), '* 0/30 3 * * ?');
    });

    test('day-of-month special shapes', () {
      var state = CronGeneratorState.defaults();
      state = state.copyWithField(
        CronFieldKind.dayOfMonth,
        CronFieldState(
            kind: CronFieldKind.dayOfMonth, type: CronOptionType.lastDayOfMonth),
      );
      expect(state.buildExpression(), '0 0 3 L * ?');

      state = state.copyWithField(
        CronFieldKind.dayOfMonth,
        CronFieldState(
            kind: CronFieldKind.dayOfMonth,
            type: CronOptionType.nearestWeekday,
            from: 15),
      );
      expect(state.buildExpression(), '0 0 3 15W * ?');
    });

    test('day-of-week shapes force day-of-month to ?', () {
      var state = CronGeneratorState.defaults();
      // day-of-month starts as '*'; picking a week shape must flip it to '?'.
      state = state.copyWithField(
        CronFieldKind.dayOfWeek,
        CronFieldState(
            kind: CronFieldKind.dayOfWeek,
            type: CronOptionType.nthWeekday,
            from: 2,
            nth: 1),
      );
      expect(state.buildExpression(), '0 0 3 ? * 2#1');

      state = state.copyWithField(
        CronFieldKind.dayOfWeek,
        CronFieldState(
            kind: CronFieldKind.dayOfWeek,
            type: CronOptionType.lastWeekday,
            from: 6),
      );
      expect(state.buildExpression(), '0 0 3 ? * 6L');
    });

    test('giving day-of-month a value forces day-of-week back to ?', () {
      var state = CronGeneratorState.fromExpression('0 0 3 ? * 6L')!;
      state = state.copyWithField(
        CronFieldKind.dayOfMonth,
        CronFieldState(
            kind: CronFieldKind.dayOfMonth,
            type: CronOptionType.specific,
            specific: {1, 15}),
      );
      expect(state.buildExpression(), '0 0 3 1,15 * ?');
    });

    test('both day fields unspecified collapse to day=*', () {
      var state = CronGeneratorState.defaults();
      state = state.copyWithField(
        CronFieldKind.dayOfMonth,
        CronFieldState(
            kind: CronFieldKind.dayOfMonth,
            type: CronOptionType.unspecified),
      );
      expect(state.buildExpression(), '0 0 3 * * ?');
    });

    test('a specified year produces seven fields', () {
      var state = CronGeneratorState.defaults();
      state = state.copyWithField(
        CronFieldKind.year,
        CronFieldState(
            kind: CronFieldKind.year,
            type: CronOptionType.range,
            from: 2027,
            to: 2030),
      );
      expect(state.buildExpression(), '0 0 3 * * ? 2027-2030');
    });

    test('an empty specific selection falls back to the wildcard', () {
      var state = CronGeneratorState.defaults();
      state = state.copyWithField(
        CronFieldKind.minute,
        CronFieldState(
            kind: CronFieldKind.minute, type: CronOptionType.specific),
      );
      expect(state.buildExpression(), '0 * 3 * * ?');
    });

    test('range bounds are ordered and clamped', () {
      var state = CronGeneratorState.defaults();
      state = state.copyWithField(
        CronFieldKind.hour,
        CronFieldState(
            kind: CronFieldKind.hour,
            type: CronOptionType.range,
            from: 20,
            to: 3),
      );
      expect(state.buildExpression().split(' ')[2], '20-21');
    });
  });

  group('CronGeneratorState.fromExpression round trips', () {
    const expressions = [
      '0 0 3 * * ?',
      '0 0/30 * * * ?',
      '0 0 0 1,15 * ?',
      '0 0 0 ? * 2#1',
      '0 0 0 L * ?',
      '0 0 0 15W * ?',
      '0 0 0 ? * 6L',
      '0 0 0 1 1 ? 2027',
      '0 15 10 ? * 2-6',
      '0/2 * * * * ?',
      '0 0 12 */3 * ?',
    ];
    for (final expression in expressions) {
      test('build(parse("$expression")) == "$expression"', () {
        final state = CronGeneratorState.fromExpression(expression);
        expect(state, isNotNull);
        expect(state!.buildExpression(), expression);
      });
    }

    test('garbage input is rejected without state', () {
      expect(CronGeneratorState.fromExpression('not a cron'), isNull);
      expect(CronGeneratorState.fromExpression('0 0'), isNull);
      expect(CronGeneratorState.fromExpression('0 61 * * * ?'), isNull);
      expect(CronGeneratorState.fromExpression(''), isNull);
    });
  });
}
