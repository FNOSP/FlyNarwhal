/// Action result for operations like favorite/watched toggle
class ActionResult {
  final String guid;
  final bool success;
  final String message;
  final bool previousState;

  const ActionResult({
    required this.guid,
    required this.success,
    required this.message,
    required this.previousState,
  });

  ActionResult copyWith({
    String? guid,
    bool? success,
    String? message,
    bool? previousState,
  }) {
    return ActionResult(
      guid: guid ?? this.guid,
      success: success ?? this.success,
      message: message ?? this.message,
      previousState: previousState ?? this.previousState,
    );
  }
}