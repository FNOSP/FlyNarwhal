import 'media_entity.dart';

/// Media library entity
class MediaLibraryEntity {
  final String guid;
  final String title;
  final List<String> posters;
  final String category;
  final int viewType;

  const MediaLibraryEntity({
    required this.guid,
    required this.title,
    this.posters = const [],
    required this.category,
    this.viewType = 0,
  });

  /// Check if has poster
  bool get hasPoster => posters.isNotEmpty;

  /// Get first poster URL
  String? get firstPoster => posters.isNotEmpty ? posters.first : null;

  MediaLibraryEntity copyWith({
    String? guid,
    String? title,
    List<String>? posters,
    String? category,
    int? viewType,
  }) {
    return MediaLibraryEntity(
      guid: guid ?? this.guid,
      title: title ?? this.title,
      posters: posters ?? this.posters,
      category: category ?? this.category,
      viewType: viewType ?? this.viewType,
    );
  }
}

/// Item list query result entity
class ItemListEntity {
  final List<MediaEntity> items;
  final int total;
  final String? mediaDbName;

  const ItemListEntity({
    this.items = const [],
    this.total = 0,
    this.mediaDbName,
  });

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
  int get length => items.length;

  ItemListEntity copyWith({
    List<MediaEntity>? items,
    int? total,
    String? mediaDbName,
  }) {
    return ItemListEntity(
      items: items ?? this.items,
      total: total ?? this.total,
      mediaDbName: mediaDbName ?? this.mediaDbName,
    );
  }
}