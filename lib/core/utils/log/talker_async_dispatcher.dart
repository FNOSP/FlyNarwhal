export 'talker_async_dispatcher_stub.dart'
    if (dart.library.io) 'talker_async_dispatcher_io.dart';

import 'talker_async_dispatcher_stub.dart'
    if (dart.library.io) 'talker_async_dispatcher_io.dart' as dispatcher_impl;

typedef TalkerAsyncDispatcher = dispatcher_impl.TalkerAsyncDispatcher;

final TalkerAsyncDispatcher sharedTalkerAsyncDispatcher =
    dispatcher_impl.createPlatformTalkerAsyncDispatcher();

TalkerAsyncDispatcher createTalkerAsyncDispatcher() =>
    dispatcher_impl.createPlatformTalkerAsyncDispatcher();
