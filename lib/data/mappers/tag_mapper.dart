import '../../domain/entities/index.dart';
import '../models/tag_models.dart';

/// Mapper for converting tag models to entities
class TagMapper {
  const TagMapper._();

  /// Convert GenresResponse model to GenreEntity
  static GenreEntity toGenreEntity(GenresResponse model) {
    return GenreEntity(
      id: model.id,
      name: model.value,
    );
  }

  /// Convert QueryTagResponse model to TagEntity
  static TagEntity toTagEntity(QueryTagResponse model) {
    return TagEntity(
      key: model.key,
      value: model.value,
    );
  }

  /// Convert TagListResponse model to TagListEntity
  static TagListEntity toTagListEntity(TagListResponse model) {
    return TagListEntity(
      genres: model.genres,
      resolutions: model.resolutions,
      colorRanges: model.colorRange,
      audioTypes: model.audioType,
      locations: model.locate,
      decades: model.decades,
      recognitionStatuses: model.recognitionStatus,
    );
  }

  /// Convert list of GenresResponse models to list of GenreEntity
  static List<GenreEntity> toGenreEntityList(List<GenresResponse> models) {
    return models.map(toGenreEntity).toList();
  }

  /// Convert list of QueryTagResponse models to list of TagEntity
  static List<TagEntity> toTagEntityList(List<QueryTagResponse> models) {
    return models.map(toTagEntity).toList();
  }

  /// Convert list of QueryTagResponse models to map
  static Map<String, String> toTagMap(List<QueryTagResponse> models) {
    return {for (final model in models) model.key: model.value};
  }
}