/// Client request to (re)generate the trickplay sprite sheets of one media file.
class ThumbnailGenerateRequest {
  final String guid;
  final String filePath;

  const ThumbnailGenerateRequest({required this.guid, required this.filePath});

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'guid': guid,
      'file_path': filePath,
    };
  }
}
