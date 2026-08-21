class SmartAnalysisResult<T> {
  final int code;
  final String msg;
  final T? data;
  final bool? success;
  final bool? encrypted;

  const SmartAnalysisResult({
    this.code = 0,
    this.msg = '',
    this.data,
    this.success,
    this.encrypted,
  });

  bool isSuccess() => isSuccessResponse(code: code, success: success);

  /// Public helper to align with Kotlin [SmartAnalysisResult.isSuccess].
  static bool isSuccessResponse({int code = 0, bool? success}) {
    return success == true || code == 0 || (code >= 200 && code <= 299);
  }

  factory SmartAnalysisResult.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) {
    final rawData = json['data'];
    return SmartAnalysisResult<T>(
      code: _readInt(json['code']) ?? 0,
      msg: json['msg']?.toString() ?? '',
      data: rawData == null ? null : fromJsonT(rawData),
      success: json['success'] as bool?,
      encrypted: json['encrypted'] as bool?,
    );
  }

  Map<String, dynamic> toJson(Object? Function(T value) toJsonT) {
    return <String, dynamic>{
      'code': code,
      'msg': msg,
      'data': data == null ? null : toJsonT(data as T),
      'success': success,
      'encrypted': encrypted,
    };
  }

  static int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
