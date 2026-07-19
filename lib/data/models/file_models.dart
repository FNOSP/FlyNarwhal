class AuthDir {
  final String path;

  AuthDir({required this.path});

  factory AuthDir.fromJson(Map<String, dynamic> json) {
    return AuthDir(path: json['path'] ?? '');
  }
}

class ServerPathResponse {
  final String filename;
  final bool isDir;

  ServerPathResponse({required this.filename, required this.isDir});

  factory ServerPathResponse.fromJson(Map<String, dynamic> json) {
    return ServerPathResponse(
      filename: json['filename'] ?? '',
      isDir: json['isDir'] ?? false,
    );
  }
}

class SubtitleMarkRequest {
  final String mediaGuid;
  final List<String> filePaths;

  SubtitleMarkRequest({required this.mediaGuid, required this.filePaths});

  Map<String, dynamic> toJson() => {
        'mediaGuid': mediaGuid,
        'filePaths': filePaths,
      };
}
