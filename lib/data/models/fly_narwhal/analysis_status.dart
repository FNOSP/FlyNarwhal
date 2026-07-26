enum AnalysisStatus {
  preparing,
  pending,
  inProgress,
  partialSuccess,
  completed,
  failed;

  static AnalysisStatus fromString(String? value) {
    switch (value) {
      case 'PREPARING':
        return AnalysisStatus.preparing;
      case 'PENDING':
        return AnalysisStatus.pending;
      case 'IN_PROGRESS':
        return AnalysisStatus.inProgress;
      case 'PARTIAL_SUCCESS':
        return AnalysisStatus.partialSuccess;
      case 'COMPLETED':
        return AnalysisStatus.completed;
      case 'FAILED':
        return AnalysisStatus.failed;
      default:
        throw FormatException('Unknown analysis status: $value');
    }
  }

  String toJsonValue() {
    switch (this) {
      case AnalysisStatus.preparing:
        return 'PREPARING';
      case AnalysisStatus.pending:
        return 'PENDING';
      case AnalysisStatus.inProgress:
        return 'IN_PROGRESS';
      case AnalysisStatus.partialSuccess:
        return 'PARTIAL_SUCCESS';
      case AnalysisStatus.completed:
        return 'COMPLETED';
      case AnalysisStatus.failed:
        return 'FAILED';
    }
  }

  bool get isRunning {
    return this == AnalysisStatus.preparing ||
        this == AnalysisStatus.pending ||
        this == AnalysisStatus.inProgress;
  }

  bool get isCompleted => this == AnalysisStatus.completed;
}
