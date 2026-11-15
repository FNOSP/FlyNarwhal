/// Client request to (re)generate the trickplay sprite sheets of one media file.
class ThumbnailGenerateRequest {
  final String guid;
  final String filePath;

  /// Regenerate even when the media file is unchanged. The server otherwise
  /// answers an unchanged COMPLETED task with its old row and queues nothing,
  /// which leaves the client with no new task to poll.
  final bool force;

  const ThumbnailGenerateRequest({
    required this.guid,
    required this.filePath,
    this.force = false,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'guid': guid,
      'file_path': filePath,
      'force': force,
    };
  }
}
