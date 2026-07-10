class UpdateSeasonStatusRequest {
  final List<String> seasonGuids;
  final String status;

  const UpdateSeasonStatusRequest({
    required this.seasonGuids,
    required this.status,
  });

  factory UpdateSeasonStatusRequest.fromJson(Map<String, dynamic> json) {
    final rawSeasonGuids = json['season_guids'] as List<dynamic>? ?? const [];
    return UpdateSeasonStatusRequest(
      seasonGuids: rawSeasonGuids.map((value) => value.toString()).toList(),
      status: json['status']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'season_guids': seasonGuids,
      'status': status,
    };
  }
}
