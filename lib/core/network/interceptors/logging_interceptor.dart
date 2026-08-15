import 'package:dio/dio.dart';
import 'package:talker/talker.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';

import '../response_decoder.dart' as response_decoder;
import '../../utils/log/app_talker.dart';

const _hiddenHeaders = {
  'Authorization',
  'Cookie',
  'Authx',
  'Signx',
  'Keyx',
};

/// Logging interceptor backed by TalkerDioLogger.
class LoggingInterceptor extends TalkerDioLogger {
  LoggingInterceptor({
    Talker? talker,
    this.printRequestBody = true,
    this.printResponseBody = true,
    this.printError = true,
  }) : super(
          talker: talker ?? AppTalker.instance,
          settings: TalkerDioLoggerSettings(
            enabled: true,
            logLevel: LogLevel.info,
            printRequestData: printRequestBody,
            printRequestHeaders: true,
            printRequestExtra: false,
            printResponseData: printResponseBody,
            printResponseHeaders: true,
            printResponseMessage: true,
            printResponseTime: true,
            printErrorData: printError,
            printErrorHeaders: printError,
            printErrorMessage: printError,
            hiddenHeaders: _hiddenHeaders,
            responseDataConverter: _formatResponseData,
          ),
        );

  final bool printRequestBody;
  final bool printResponseBody;
  final bool printError;

  /// Redacts large / stream request bodies for logging only.
  ///
  /// TalkerDioLogger reads [RequestOptions.data] **synchronously** inside
  /// [super.onRequest] (via `DioRequestLog.generateTextMessage`), while dio
  /// reads it **asynchronously** in a later event-loop tick to send the
  /// request. We temporarily swap in a short summary string so the log shows
  /// `[stream upload]` or `[binary N bytes]` instead of attempting to
  /// jsonEncode / toString a multi-MB payload on the UI thread. The original
  /// data is restored immediately after super returns, before dio ever reads
  /// it.
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    final originalData = options.data;
    final needsRedaction = originalData is Stream ||
        (originalData is List<int> && originalData.length > 4096);
    if (needsRedaction) {
      options.data = originalData is Stream
          ? '[stream upload]'
          : '[binary ${(originalData as List<int>).length} bytes]';
    }
    super.onRequest(options, handler);
    if (needsRedaction) {
      options.data = originalData;
    }
  }

  // Reuse the existing response preview logic to keep network logs compact.
  static String _formatResponseData(Response<dynamic> response) {
    return response_decoder.ResponseDecoder.formatForLogging(response.data);
  }
}
