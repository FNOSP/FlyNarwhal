import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// Range offsets describe wire bytes; transparent decompression changes them.
HttpClientAdapter createExternalHttpAdapter() => IOHttpClientAdapter(
      createHttpClient: () => HttpClient()..autoUncompress = false,
    );
