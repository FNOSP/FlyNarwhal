import 'talker_file_history_backend_base.dart';
import 'talker_file_history_backend_stub.dart'
    if (dart.library.io) 'talker_file_history_backend_io.dart';

TalkerFileHistoryBackend createTalkerFileHistoryBackend() =>
    createPlatformTalkerFileHistoryBackend();
