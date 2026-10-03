import '../../core/network/api_result.dart';
import '../../domain/entities/index.dart';
import '../../domain/repositories/i_tag_repository.dart';
import '../datasources/remote/tag_remote_data_source.dart';
import '../mappers/tag_mapper.dart';

/// Implementation of ITagRepository
class TagRepositoryImpl implements ITagRepository {
  final TagRemoteDataSource _remoteDataSource;

  /// 当前 tag 接口语言（`lan` 参数）。由 provider 随界面语言变化重建而更新；
  /// 显式传入 `language` 的调用优先。
  final String _language;

  TagRepositoryImpl(this._remoteDataSource, {required String language})
      : _language = language;

  @override
  Future<ApiResult<List<GenreEntity>>> getGenres({
    String? language,
    bool force = false,
  }) async {
    final result = await _remoteDataSource.getGenres(
      language: language ?? _language,
      force: force,
    );
    return result.map((data) => TagMapper.toGenreEntityList(data));
  }

  @override
  Future<ApiResult<Map<String, String>>> getTag(
    String tag, {
    String? language,
    bool force = false,
  }) async {
    return _remoteDataSource.getTag(
      tag,
      language: language ?? _language,
      force: force,
    );
  }

  @override
  Future<ApiResult<TagListEntity>> getTagList({
    String? ancestorGuid,
    String? parentGuid,
    required int isFavorite,
    String? type,
  }) async {
    // Convert filter metadata into the domain entity used by the screens.
    final result = await _remoteDataSource.getTagList(
      ancestorGuid: ancestorGuid,
      parentGuid: parentGuid,
      isFavorite: isFavorite,
      type: type,
    );
    return result.map((data) => TagMapper.toTagListEntity(data));
  }
}
