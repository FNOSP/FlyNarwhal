import '../../core/network/api_result.dart';
import '../entities/index.dart';
import '../repositories/i_tag_repository.dart';

/// Parameters for genres query
class GenresParams {
  final String? language;
  final bool force;

  const GenresParams({
    this.language = 'zh-CN',
    this.force = false,
  });
}

/// Use case for getting genres
class GetGenresUseCase implements UseCase<List<GenreEntity>, GenresParams> {
  final ITagRepository _repository;

  GetGenresUseCase(this._repository);

  @override
  Future<ApiResult<List<GenreEntity>>> call(GenresParams params) {
    return _repository.getGenres(
      language: params.language,
      force: params.force,
    );
  }
}

/// Parameters for tag query
class TagParams {
  final String tag;
  final String? language;
  final bool force;

  const TagParams({
    required this.tag,
    this.language = 'zh-CN',
    this.force = false,
  });
}

/// Use case for getting tag map
class GetTagUseCase implements UseCase<Map<String, String>, TagParams> {
  final ITagRepository _repository;

  GetTagUseCase(this._repository);

  @override
  Future<ApiResult<Map<String, String>>> call(TagParams params) {
    return _repository.getTag(
      params.tag,
      language: params.language,
      force: params.force,
    );
  }
}

/// Parameters for tag list query
class TagListParams {
  final String? ancestorGuid;
  final int isFavorite;
  final String? type;

  const TagListParams({
    this.ancestorGuid,
    required this.isFavorite,
    this.type,
  });
}

/// Use case for getting tag list
class GetTagListUseCase implements UseCase<TagListEntity, TagListParams> {
  final ITagRepository _repository;

  GetTagListUseCase(this._repository);

  @override
  Future<ApiResult<TagListEntity>> call(TagListParams params) {
    return _repository.getTagList(
      ancestorGuid: params.ancestorGuid,
      isFavorite: params.isFavorite,
      type: params.type,
    );
  }
}

/// Base use case interface
abstract class UseCase<T, Params> {
  Future<ApiResult<T>> call(Params params);
}