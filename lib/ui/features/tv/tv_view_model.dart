import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Index of the continue-watching card whose focus drives the hero
/// spotlight. Plain (non-codegen) provider — build_runner is unavailable on
/// this machine, so TV mode adds no `.g.dart`.
final tvHeroFocusIndexProvider = StateProvider<int?>((ref) => null);
