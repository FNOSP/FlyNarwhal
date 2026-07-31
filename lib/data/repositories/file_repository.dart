import '../datasources/remote/file_remote_data_source.dart';
import '../datasources/remote/subtitle_remote_data_source.dart';
import '../models/file_models.dart';
import '../models/movie_detail_models.dart';
import '../models/subtitle_models.dart';

/// Thin repository that delegates all network calls to the dedicated remote
/// data sources. It performs no URL construction or response parsing of its
/// own (see the remote-api-development skill for the layering rules).
class FileRepository {
  final FileRemoteDataSource _fileDataSource;
  final SubtitleRemoteDataSource _subtitleDataSource;

  FileRepository({
    required FileRemoteDataSource fileDataSource,
    required SubtitleRemoteDataSource subtitleDataSource,
  })  : _fileDataSource = fileDataSource,
        _subtitleDataSource = subtitleDataSource;

  Future<List<AuthDir>> getAuthorizedDirs() async {
    return (await _fileDataSource.getAuthorizedDirs()).getOrThrow();
  }

  Future<List<ServerPathResponse>> getFilesByServerPath(String path) async {
    return (await _fileDataSource.getFilesByServerPath(path)).getOrThrow();
  }

  Future<SubtitleMarkResponse> markSubtitle(
    String mediaGuid,
    List<String> filePaths,
  ) async {
    return (await _subtitleDataSource.markSubtitle(
      SubtitleMarkRequest(mediaGuid: mediaGuid, filePaths: filePaths),
    ))
        .getOrThrow();
  }

  Future<SubtitleSearchResponse> searchSubtitles({
    required String mediaGuid,
    String language = 'zh-CN',
  }) async {
    return (await _subtitleDataSource.searchSubtitles(
      SubtitleSearchRequest(lan: language, mediaGuid: mediaGuid),
    ))
        .getOrThrow();
  }

  Future<SubtitleStream> downloadSubtitle({
    required String mediaGuid,
    required String trimId,
    int syncDownload = 1,
  }) async {
    return (await _subtitleDataSource.downloadSubtitle(
      SubtitleDownloadRequest(
        mediaGuid: mediaGuid,
        trimId: trimId,
        syncDownload: syncDownload,
      ),
    ))
        .getOrThrow();
  }

  // Queue a server-side task that downloads the same subtitle for the other
  // episodes of the current series ("为其他集下载相似字幕").
  Future<void> predownloadSimilarSubtitle({
    required String mediaGuid,
    required String subtitleGuid,
  }) async {
    (await _subtitleDataSource.predownloadSimilarSubtitle(
      SubtitlePredownloadRequest(
        mediaGuid: mediaGuid,
        subtitleGuid: subtitleGuid,
      ),
    ))
        .getOrThrow();
  }

  Future<SubtitleStream> uploadSubtitle({
    required String guid,
    required List<int> bytes,
    required String fileName,
  }) async {
    return (await _subtitleDataSource
            .uploadSubtitle(guid: guid, bytes: bytes, fileName: fileName))
        .getOrThrow();
  }
}
