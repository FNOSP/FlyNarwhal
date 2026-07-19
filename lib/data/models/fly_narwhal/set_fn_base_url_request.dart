class SetFnBaseUrlRequest {
  final String baseUrl;

  const SetFnBaseUrlRequest({required this.baseUrl});

  factory SetFnBaseUrlRequest.fromJson(Map<String, dynamic> json) {
    return SetFnBaseUrlRequest(baseUrl: json['base_url']?.toString() ?? '');
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'base_url': baseUrl,
    };
  }
}
