import '../../core/network/api_result.dart';
import '../entities/index.dart';

/// Tag repository interface
abstract class ITagRepository {
  /// Get genres list
  Future<ApiResult<List<GenreEntity>>> getGenres({String? language, bool force = false});

  /// Get tag map by tag name
  Future<ApiResult<Map<String, String>>> getTag(String tag, {String? language, bool force = false});

  /// Get tag list for filtering
  Future<ApiResult<TagListEntity>> getTagList({
    String? ancestorGuid,
    String? parentGuid,
    required int isFavorite,
    String? type,
  });
}