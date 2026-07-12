import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
    this.printRequestBody = false,
    this.printResponseBody = false,
    this.printError = true,
  }) : super(
          talker: talker ?? AppTalker.instance,
          settings: TalkerDioLoggerSettings(
            enabled: true,
            logLevel: LogLevel.info,
            printRequestData: printRequestBody,
            printRequestHeaders: kDebugMode,
            printRequestExtra: false,
            printResponseData: printResponseBody,
            printResponseHeaders: false,
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

  // Reuse the existing response preview logic to keep network logs compact.
  static String _formatResponseData(Response<dynamic> response) {
    return response_decoder.ResponseDecoder.formatForLogging(response.data);
  }
}
