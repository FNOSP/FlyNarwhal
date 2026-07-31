import 'movie_detail_models.dart';

class AuthDir {
  final String path;

  /// Server storage category: 0 = external, 1 = share, 2 = remote mount,
  /// 3 = local storage volume, 4 = app share. Drives the sidebar label
  /// (matching the web player's file picker).
  final int storageType;

  /// Remote mount metadata used to build root labels that match the web UI.
  final String uname;
  final String address;
  final String comment;
  final int type;
  final String proto;
  final String username;
  final int cloudStorageType;

  AuthDir({
    required this.path,
    this.storageType = 3,
    this.uname = '',
    this.address = '',
    this.comment = '',
    this.type = 0,
    this.proto = '',
    this.username = '',
    this.cloudStorageType = 0,
  });

  factory AuthDir.fromJson(Map<String, dynamic> json) {
    return AuthDir(
      path: json['path'] ?? '',
      storageType: json['storageType'] ?? json['storage_type'] ?? 3,
      uname: json['uname']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      comment: json['comment']?.toString() ?? '',
      type: json['type'] ?? 0,
      proto: json['proto']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      cloudStorageType:
          json['cloudStorageType'] ?? json['cloud_storage_type'] ?? 0,
    );
  }
}

class ServerPathResponse {
  final String filename;
  final bool isDir;

  ServerPathResponse({required this.filename, required this.isDir});

  factory ServerPathResponse.fromJson(Map<String, dynamic> json) {
    return ServerPathResponse(
      filename: json['filename'] ?? '',
      isDir: json['is_dir'] ?? json['isDir'] ?? false,
    );
  }
}

class SubtitleMarkRequest {
  final String mediaGuid;
  final List<String> filePaths;

  SubtitleMarkRequest({required this.mediaGuid, required this.filePaths});

  Map<String, dynamic> toJson() => {
        'media_guid': mediaGuid,
        'filepaths': filePaths,
      };
}

/// Response of PUT /v/api/v1/subtitle/mark — the subtitle entry the server
/// registered for the media item. Used to auto-switch to the newly added
/// subtitle.
class SubtitleMarkResponse {
  final String mediaGuid;
  final String title;
  final String guid;
  final String codecName;
  final String codecType;
  final String language;
  final int forced;
  final int index;
  final int isDefault;
  final int isExternal;
  final String format;
  final String trimId;
  final String sourceId;
  final String source;
  final int createTime;
  final int updateTime;
  final int extraFile;
  final int isBitmap;
  final int fileSize;

  SubtitleMarkResponse({
    required this.mediaGuid,
    required this.title,
    required this.guid,
    required this.codecName,
    required this.codecType,
    required this.language,
    required this.forced,
    required this.index,
    required this.isDefault,
    required this.isExternal,
    required this.format,
    required this.trimId,
    required this.sourceId,
    required this.source,
    required this.createTime,
    required this.updateTime,
    required this.extraFile,
    required this.isBitmap,
    required this.fileSize,
  });

  factory SubtitleMarkResponse.fromJson(Map<String, dynamic> json) {
    return SubtitleMarkResponse(
      mediaGuid: json['media_guid']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      guid: json['guid']?.toString() ?? '',
      codecName: json['codec_name']?.toString() ?? '',
      codecType: json['codec_type']?.toString() ?? '',
      language: json['language']?.toString() ?? '',
      forced: json['forced'] ?? 0,
      index: json['index'] ?? 0,
      isDefault: json['is_default'] ?? 0,
      isExternal: json['is_external'] ?? 0,
      format: json['format']?.toString() ?? '',
      trimId: json['trim_id']?.toString() ?? '',
      sourceId: json['source_id']?.toString() ?? '',
      source: json['Source']?.toString() ?? '',
      createTime: json['create_time'] ?? 0,
      updateTime: json['update_time'] ?? 0,
      extraFile: json['extra_file'] ?? 0,
      isBitmap: json['is_bitmap'] ?? 0,
      fileSize: json['file_size'] ?? 0,
    );
  }

  SubtitleStream toSubtitleStream() => SubtitleStream(
        mediaGuid: mediaGuid,
        title: title,
        guid: guid,
        codecName: codecName,
        codecType: codecType,
        language: language,
        forced: forced,
        index: index,
        isDefault: isDefault,
        isExternal: isExternal,
        format: format,
        trimId: trimId,
        sourceId: sourceId,
        source: source,
        createTime: createTime,
        updateTime: updateTime,
        extraFile: extraFile,
        isBitmap: isBitmap,
        fileSize: fileSize,
      );
}
