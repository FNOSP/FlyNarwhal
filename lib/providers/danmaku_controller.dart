import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/remote/fly_narwhal_remote_data_source.dart';
import '../data/models/fly_narwhal/index.dart';

class DanmakuState {
  final List<Danmaku> danmakuList;
  final bool isVisible;

  const DanmakuState({
    this.danmakuList = const [],
    this.isVisible = true,
  });

  DanmakuState copyWith({
    List<Danmaku>? danmakuList,
    bool? isVisible,
  }) {
    return DanmakuState(
      danmakuList: danmakuList ?? this.danmakuList,
      isVisible: isVisible ?? this.isVisible,
    );
  }
}

class DanmakuController extends StateNotifier<DanmakuState> {
  final FlyNarwhalRemoteDataSource _remoteDataSource;

  DanmakuController(this._remoteDataSource) : super(const DanmakuState());

  Future<void> loadDanmaku(DanmakuRequest request) async {
    try {
      final map = (await _remoteDataSource.getDanmaku(request)).getOrThrow();
      final episodeKey = request.episodeNumber.toString();
      final selectedList = map[episodeKey] ??
          map['default'] ??
          (map.values.isNotEmpty ? map.values.first : const <Danmaku>[]);
      state = state.copyWith(danmakuList: selectedList);
    } catch (_) {
      state = state.copyWith(danmakuList: const []);
    }
  }

  void toggleVisibility() {
    state = state.copyWith(isVisible: !state.isVisible);
  }

  void clear() {
    state = state.copyWith(danmakuList: const []);
  }
}
