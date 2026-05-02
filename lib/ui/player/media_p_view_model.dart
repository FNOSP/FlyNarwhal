import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/player_models.dart';
import '../../providers/providers.dart';

class MediaPState {
  final bool isLoading;
  final MediaTranscodeResponse? transcodeStatus;
  final MediaResetQualityResponse? resetQualityResponse;
  final MediaResetQualityResponse? resetAudioResponse;
  final MediaResetQualityResponse? resetSubtitleResponse;
  final MediaResetQualityResponse? quitResponse;
  final String? error;

  const MediaPState({
    this.isLoading = false,
    this.transcodeStatus,
    this.resetQualityResponse,
    this.resetAudioResponse,
    this.resetSubtitleResponse,
    this.quitResponse,
    this.error,
  });

  MediaPState copyWith({
    bool? isLoading,
    MediaTranscodeResponse? transcodeStatus,
    MediaResetQualityResponse? resetQualityResponse,
    MediaResetQualityResponse? resetAudioResponse,
    MediaResetQualityResponse? resetSubtitleResponse,
    MediaResetQualityResponse? quitResponse,
    String? error,
  }) {
    return MediaPState(
      isLoading: isLoading ?? this.isLoading,
      transcodeStatus: transcodeStatus ?? this.transcodeStatus,
      resetQualityResponse: resetQualityResponse ?? this.resetQualityResponse,
      resetAudioResponse: resetAudioResponse ?? this.resetAudioResponse,
      resetSubtitleResponse:
          resetSubtitleResponse ?? this.resetSubtitleResponse,
      quitResponse: quitResponse ?? this.quitResponse,
      error: error,
    );
  }
}

class MediaPViewModel extends StateNotifier<MediaPState> {
  MediaPViewModel(this.ref) : super(const MediaPState());

  final Ref ref;

  static const String _transcodeStatusReqId = '1234567890ABCDEF';
  static const String _resetQualityReqId = '1234567890ABCDEF2s';
  static const String _resetAudioReqId = '1234567890ABCDEF2a';
  static const String _resetSubtitleReqId = '1234567890ABCDEF';
  static const String _quitReqId = '1234567890ABCDEF';

  MediaPRequest _withReq(
    MediaPRequest request, {
    required String req,
    required String reqId,
  }) {
    return request.copyWith(req: req, reqId: reqId);
  }

  void _setLoading(bool value) {
    state = state.copyWith(isLoading: value, error: null);
  }

  void _setError(Object error) {
    state = state.copyWith(
      isLoading: false,
      error: error.toString(),
    );
  }

  Future<MediaTranscodeResponse> fetchTranscodeStatus(
      MediaPRequest request) async {
    _setLoading(true);
    try {
      final remote = ref.read(mediaRemoteDataSourceProvider);
      final response = await remote.fetchTranscodeStatus(
        _withReq(
          request,
          req: 'media.transcodeStatis',
          reqId: _transcodeStatusReqId,
        ),
      );
      final data = response.getOrThrow();
      state = state.copyWith(
        isLoading: false,
        transcodeStatus: data,
        error: null,
      );
      return data;
    } catch (e) {
      _setError(e);
      rethrow;
    }
  }

  Future<MediaResetQualityResponse> resetQuality(MediaPRequest request) async {
    _setLoading(true);
    try {
      final remote = ref.read(mediaRemoteDataSourceProvider);
      final response = await remote.resetQuality(
        _withReq(
          request,
          req: 'media.resetQuality',
          reqId: _resetQualityReqId,
        ),
      );
      final data = response.getOrThrow();
      state = state.copyWith(
        isLoading: false,
        resetAudioResponse: data,
        error: null,
      );
      return data;
    } catch (e) {
      _setError(e);
      rethrow;
    }
  }

  Future<MediaResetQualityResponse> resetAudio(MediaPRequest request) async {
    _setLoading(true);
    try {
      final remote = ref.read(mediaRemoteDataSourceProvider);
      final response = await remote.resetAudio(
        _withReq(
          request,
          req: 'media.resetAudio',
          reqId: _resetAudioReqId,
        ),
      );
      final data = response.getOrThrow();
      state = state.copyWith(
        isLoading: false,
        resetQualityResponse: data,
        error: null,
      );
      return data;
    } catch (e) {
      _setError(e);
      rethrow;
    }
  }

  Future<MediaResetQualityResponse> resetSubtitle(MediaPRequest request) async {
    _setLoading(true);
    try {
      final remote = ref.read(mediaRemoteDataSourceProvider);
      final response = await remote.resetSubtitle(
        _withReq(
          request,
          req: 'media.resetSubtitle',
          reqId: _resetSubtitleReqId,
        ),
      );
      final data = response.getOrThrow();
      state = state.copyWith(
        isLoading: false,
        resetSubtitleResponse: data,
        error: null,
      );
      return data;
    } catch (e) {
      _setError(e);
      rethrow;
    }
  }

  Future<MediaResetQualityResponse> quit(
    MediaPRequest request, {
    bool updateState = true,
  }) async {
    if (updateState) {
      _setLoading(true);
    } else {
      state = state.copyWith(error: null);
    }

    try {
      final remote = ref.read(mediaRemoteDataSourceProvider);
      final response = await remote.quit(
        _withReq(
          request,
          req: 'media.quit',
          reqId: _quitReqId,
        ),
      );
      final data = response.getOrThrow();
      if (updateState) {
        state = state.copyWith(
          isLoading: false,
          quitResponse: data,
          error: null,
        );
      }
      return data;
    } catch (e) {
      if (updateState) {
        _setError(e);
      } else {
        state = state.copyWith(error: e.toString());
      }
      rethrow;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  void clearResetQualityResponse() {
    state = MediaPState(
      isLoading: state.isLoading,
      transcodeStatus: state.transcodeStatus,
      resetAudioResponse: state.resetAudioResponse,
      resetSubtitleResponse: state.resetSubtitleResponse,
      quitResponse: state.quitResponse,
      error: state.error,
    );
  }

  void clearResetAudioResponse() {
    state = MediaPState(
      isLoading: state.isLoading,
      transcodeStatus: state.transcodeStatus,
      resetQualityResponse: state.resetQualityResponse,
      resetSubtitleResponse: state.resetSubtitleResponse,
      quitResponse: state.quitResponse,
      error: state.error,
    );
  }

  void clearResetSubtitleResponse() {
    state = MediaPState(
      isLoading: state.isLoading,
      transcodeStatus: state.transcodeStatus,
      resetQualityResponse: state.resetQualityResponse,
      resetAudioResponse: state.resetAudioResponse,
      quitResponse: state.quitResponse,
      error: state.error,
    );
  }

  void clearQuitResponse() {
    state = MediaPState(
      isLoading: state.isLoading,
      transcodeStatus: state.transcodeStatus,
      resetQualityResponse: state.resetQualityResponse,
      resetAudioResponse: state.resetAudioResponse,
      resetSubtitleResponse: state.resetSubtitleResponse,
      error: state.error,
    );
  }
}

final mediaPViewModelProvider =
    StateNotifierProvider<MediaPViewModel, MediaPState>((ref) {
  return MediaPViewModel(ref);
});
