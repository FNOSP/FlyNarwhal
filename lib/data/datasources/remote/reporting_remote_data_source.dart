import '../../../core/network/api_result.dart';
import '../../../core/network/dio_client.dart';

final class ReportingRemoteDataSource {
  const ReportingRemoteDataSource(this._dioClient);

  final DioClient _dioClient;

  Future<ApiResult<bool>> reportLaunch({
    required String reportUrl,
    required Map<String, dynamic> body,
  }) {
    return _dioClient.post<bool>(
      reportUrl,
      data: body,
      converter: (_) => true,
    );
  }
}
