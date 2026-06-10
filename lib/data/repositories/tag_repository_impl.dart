import '../../core/network/api_result.dart';
import '../../domain/entities/index.dart';
import '../../domain/repositories/i_tag_repository.dart';
import '../datasources/remote/tag_remote_data_source.dart';
import '../mappers/tag_mapper.dart';

/// Implementation of ITagRepository
class TagRepositoryImpl implements ITagRepository {
  final TagRemoteDataSource _remoteDataSource;

  TagRepositoryImpl(this._remoteDataSource);

  @override
  Future<ApiResult<List<GenreEntity>>> getGenres({
    String? language,
    bool force = false,
  }) async {
    // Map remote models into domain entities for UI consumption.
    final result = await _remoteDataSource.getGenres(
      language: language,
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
    // Keep tag maps unchanged because the domain shape matches the remote shape.
    final result = await _remoteDataSource.getTag(
      tag,
      language: language,
      force: force,
    );
    return result;
  }

  @override
  Future<ApiResult<TagListEntity>> getTagList({
    String? ancestorGuid,
    required int isFavorite,
    String? type,
  }) async {
    // Convert filter metadata into the domain entity used by the screens.
    final result = await _remoteDataSource.getTagList(
      ancestorGuid: ancestorGuid,
      isFavorite: isFavorite,
      type: type,
    );
    return result.map((data) => TagMapper.toTagListEntity(data));
  }
}
