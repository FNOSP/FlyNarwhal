import 'dart:io';

import 'update_models.dart';

/// Immutable install input created only after the pre-install verification pass.
final class VerifiedUpdateArtifact {
  const VerifiedUpdateArtifact({
    required this.candidate,
    required this.file,
    required this.length,
    required this.sha256,
    required this.verifiedAt,
  });

  final UpdateCandidate candidate;
  final File file;
  final int length;
  final String sha256;
  final DateTime verifiedAt;
}
