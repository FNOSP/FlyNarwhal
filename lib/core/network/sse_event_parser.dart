class SseEvent {
  final String? name;
  final String data;

  const SseEvent(this.name, this.data);
}

class SseEventParser {
  const SseEventParser._();

  // Transform a UTF-8 line stream into SSE events.
  static Stream<SseEvent> parse(Stream<String> lines) async* {
    String? eventName;
    final dataLines = <String>[];

    await for (final line in lines) {
      if (line.isEmpty) {
        if (dataLines.isNotEmpty) {
          yield SseEvent(eventName, dataLines.join('\n'));
        }
        eventName = null;
        dataLines.clear();
        continue;
      }
      if (line.startsWith(':')) {
        continue;
      }
      if (line.startsWith('event:')) {
        eventName = line.substring('event:'.length).trim();
        continue;
      }
      if (line.startsWith('data:')) {
        dataLines.add(line.substring('data:'.length).trimLeft());
      }
    }
  }
}
