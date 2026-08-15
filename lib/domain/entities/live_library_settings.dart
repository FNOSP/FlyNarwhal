import 'dart:convert';

/// 直播库页面布局，与 Web 端持久化在 user data 里的 `view_type` 取值一致。
enum LiveViewType {
  verticalPoster('vertical_poster'),
  horizontalPoster('horizontal_poster'),
  list('list');

  final String value;

  const LiveViewType(this.value);

  static LiveViewType parse(String? raw) {
    return LiveViewType.values.firstWhere(
      (e) => e.value == raw,
      orElse: () => LiveViewType.verticalPoster,
    );
  }
}

/// 直播库（IPTV）页面的浏览偏好，镜像 Web 端 `mdb:list:setting` /
/// `iptv:list:setting` 的 value 结构 {sort_type, sort_field, view_type}。
/// Web 端直播页的 schema 校验会把 sort_field 强制为标题（其它字段不可选），
/// 仅 sort_type / view_type 真正持久化生效；默认按标题升序，与其它媒体库
/// （添加日期降序）不同。
class LiveLibrarySettings {
  final String sortType;
  final String sortField;
  final LiveViewType viewType;

  const LiveLibrarySettings({
    this.sortType = 'ASC',
    this.sortField = 'sort_title',
    this.viewType = LiveViewType.verticalPoster,
  });

  factory LiveLibrarySettings.fromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return const LiveLibrarySettings();
    try {
      final json = jsonDecode(raw);
      if (json is Map<String, dynamic>) {
        return LiveLibrarySettings(
          sortType:
              json['sort_type'] is String ? json['sort_type'] as String : 'ASC',
          sortField:
              json['sort_field'] is String ? json['sort_field'] as String : 'sort_title',
          viewType: LiveViewType.parse(json['view_type'] as String?),
        );
      }
    } catch (_) {}
    return const LiveLibrarySettings();
  }

  String toJsonString() => jsonEncode({
        'sort_type': sortType,
        'sort_field': sortField,
        'view_type': viewType.value,
      });

  LiveLibrarySettings copyWith({
    String? sortType,
    String? sortField,
    LiveViewType? viewType,
  }) {
    return LiveLibrarySettings(
      sortType: sortType ?? this.sortType,
      sortField: sortField ?? this.sortField,
      viewType: viewType ?? this.viewType,
    );
  }
}
