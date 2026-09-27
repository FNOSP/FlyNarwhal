import 'dart:async';
import 'dart:io' show X509Certificate;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// What the user chose when asked to trust a certificate that failed
/// verification.
enum SslTrustDecision {
  /// Refuse: the original error is propagated unchanged.
  reject,

  /// Trust for this process only; forgotten on restart.
  allowTemporary,

  /// Trust and persist, so later launches skip verification for this entry.
  allowPersist,
}

/// A single accepted (host, certificate) pair.
///
/// The fingerprint is what makes this stricter than the KMP original, which
/// keys on the bare hostname: replacing the certificate on an already-trusted
/// host re-prompts instead of being silently accepted.
@immutable
class SslTrustEntry {
  const SslTrustEntry({
    required this.host,
    required this.fingerprintSha256,
    this.addedAt,
  });

  final String host;
  final String fingerprintSha256;

  /// When the user trusted this certificate. Null for entries written before
  /// the field existed, or by the driver's auto-trust.
  final DateTime? addedAt;

  /// Identity is host + fingerprint; [addedAt] must not take part, or rewriting
  /// an entry would look like a different one.
  @override
  bool operator ==(Object other) =>
      other is SslTrustEntry &&
      other.host == host &&
      other.fingerprintSha256 == fingerprintSha256;

  @override
  int get hashCode => Object.hash(host, fingerprintSha256);

  @override
  String toString() => 'SslTrustEntry($host, ${shortFingerprint(fingerprintSha256)})';
}

/// The question currently waiting for an answer, if any.
class SslTrustPrompt {
  SslTrustPrompt({required this.host, required this.fingerprintSha256});

  final String host;
  final String fingerprintSha256;
  final Completer<SslTrustDecision> completer = Completer<SslTrustDecision>();
}

/// First 8 hex chars of a SHA-256 fingerprint, for display.
String shortFingerprint(String fingerprintSha256) {
  final normalized = fingerprintSha256.replaceAll(':', '').trim();
  return normalized.length <= 8 ? normalized : normalized.substring(0, 8);
}

/// Fingerprint value meaning "any certificate from this host".
///
/// Only ever inserted by the driver's `SSL_AUTO_TRUST_HOSTS` define; never
/// produced by a user decision and never persisted.
const String wildcardFingerprint = '*';

/// The process-wide registry of accepted certificates.
///
/// This is a plain singleton rather than a Riverpod notifier on purpose:
/// [HttpClient.badCertificateCallback] runs during the TLS handshake, where
/// there is no `Ref` and no `BuildContext`, and it must answer synchronously.
/// The UI observes [pendingPrompt] through a one-line provider instead.
///
/// Two very different callers use this:
///
/// * [isApproved] — the synchronous enforcement point, called from the
///   handshake. It only reads already-decided state and never prompts.
/// * [requestTrust] — the asynchronous prompting point, called from
///   `SslTrustInterceptor` when a request has already failed. It awaits the
///   user through [pendingPrompt] and then the caller retries.
///
/// Keeping those separate is what reconciles the KMP design (which can suspend
/// a request inside the handshake) with Dart's synchronous callback.
class SslTrustManager {
  SslTrustManager._();

  static final SslTrustManager instance = SslTrustManager._();

  /// How long a rejection suppresses further prompts for the same host. Without
  /// it, a screen that fires several parallel requests would re-prompt the user
  /// once per request after they hit "cancel".
  static const Duration _rejectSuppressionWindow = Duration(seconds: 2);

  /// The pending question, or null. The dialog host listens to this.
  final ValueNotifier<SslTrustPrompt?> pendingPrompt = ValueNotifier(null);

  /// The prompt awaiting an answer. Separate from [pendingPrompt] so
  /// [resolvePrompt] still works while a listener is being notified.
  SslTrustPrompt? _activePrompt;

  /// Approved for this process only.
  final Set<SslTrustEntry> _temporary = <SslTrustEntry>{};

  /// In-memory mirror of what is on disk, so the synchronous handshake callback
  /// never touches SharedPreferences.
  final Set<SslTrustEntry> _persisted = <SslTrustEntry>{};

  /// In-flight prompts keyed by host, so concurrent failures for the same host
  /// share one dialog instead of stacking.
  final Map<String, Future<SslTrustDecision>> _inFlight =
      <String, Future<SslTrustDecision>>{};

  /// Host -> when it was last rejected, for [_rejectSuppressionWindow].
  final Map<String, DateTime> _recentRejects = <String, DateTime>{};

  /// Host -> fingerprint of the certificate the handshake actually presented
  /// and that failed verification.
  ///
  /// This is the identity a trust decision must be pinned to. It cannot come
  /// from [probePeerCertificate]: Dart's [HttpClientResponse.certificate] is the
  /// *leaf*, whereas [HttpClient.badCertificateCallback] is handed whichever
  /// certificate the verifier could not chain — for a server whose chain does
  /// not reach a trusted root that is an intermediate, not the leaf. The two
  /// differ, so a trust entry recorded from the probe could never match the
  /// handshake and trust would silently never take effect.
  ///
  /// Written by [rememberRejectedCertificate] from inside the handshake
  /// callback, read by [SslTrustInterceptor] to build the prompt.
  final Map<String, String> _rejectedFingerprints = <String, String>{};

  /// Called once at startup, before the first request, so a previously trusted
  /// host does not prompt again on this launch.
  void hydrate(Set<SslTrustEntry> persisted) {
    _persisted
      ..clear()
      ..addAll(persisted);
  }

  /// Records the certificate a failed handshake presented for [host].
  ///
  /// The handshake callback is synchronous and cannot prompt, but it is the
  /// only place the authoritative certificate is visible, so it stashes the
  /// fingerprint here for [SslTrustInterceptor] to pick up moments later.
  void rememberRejectedCertificate(String host, String fingerprintSha256) {
    final key = normalizeHost(host);
    if (key.isEmpty) return;
    _rejectedFingerprints[key] = fingerprintSha256
        .replaceAll(':', '')
        .toLowerCase();
  }

  /// The fingerprint recorded by [rememberRejectedCertificate] for [host].
  String? rejectedFingerprintFor(String host) =>
      _rejectedFingerprints[normalizeHost(host)];

  /// Extracts the SHA-256 fingerprint of a peer certificate.
  static String fingerprintOf(X509Certificate certificate) {
    return sha256.convert(certificate.der).toString();
  }

  static String normalizeHost(String host) => host.trim().toLowerCase();

  /// The synchronous enforcement point. Never prompts, never awaits.
  bool isApproved(String host, String fingerprintSha256) {
    final key = normalizeHost(host);
    if (key.isEmpty) return false;
    final normalizedFingerprint =
        fingerprintSha256.replaceAll(':', '').toLowerCase();
    for (final entry in _temporary.followedBy(_persisted)) {
      if (entry.host != key) continue;
      if (entry.fingerprintSha256 == normalizedFingerprint) return true;
      // Test-only escape hatch used by the driver's auto-trust define.
      if (entry.fingerprintSha256 == wildcardFingerprint) return true;
    }
    return false;
  }

  /// Whether any certificate for [host] has been approved.
  ///
  /// The playback path has no access to the peer certificate (mpv does not
  /// expose it), so it can only ask about the host. Kept separate from
  /// [isApproved] to make that weaker guarantee explicit at the call site.
  bool isHostApproved(String host) {
    final key = normalizeHost(host);
    if (key.isEmpty) return false;
    return _temporary.any((e) => e.host == key) ||
        _persisted.any((e) => e.host == key);
  }

  Set<SslTrustEntry> get temporaryEntries => Set.unmodifiable(_temporary);
  Set<SslTrustEntry> get persistedEntries => Set.unmodifiable(_persisted);
  Set<SslTrustEntry> get allEntries =>
      Set.unmodifiable({..._persisted, ..._temporary});

  void addTemporary(SslTrustEntry entry) {
    _temporary.add(entry);
    _recentRejects.remove(entry.host);
  }

  void addPersisted(SslTrustEntry entry) {
    _persisted.add(entry);
    _recentRejects.remove(entry.host);
  }

  void remove(SslTrustEntry entry) {
    _temporary.remove(entry);
    _persisted.remove(entry);
  }

  void clear() {
    _temporary.clear();
    _persisted.clear();
  }

  /// Asks the user whether [host] with [fingerprintSha256] should be trusted.
  ///
  /// Concurrent calls for the same host share a single prompt. A host that was
  /// just rejected resolves to [SslTrustDecision.reject] without prompting, and
  /// a host that is already approved short-circuits.
  Future<SslTrustDecision> requestTrust(
    String host,
    String fingerprintSha256,
  ) {
    final key = normalizeHost(host);
    if (key.isEmpty) return Future.value(SslTrustDecision.reject);

    final entry = SslTrustEntry(
      host: key,
      fingerprintSha256: fingerprintSha256.replaceAll(':', '').toLowerCase(),
    );
    if (isApproved(key, fingerprintSha256)) {
      return Future.value(SslTrustDecision.allowTemporary);
    }

    final rejectedAt = _recentRejects[key];
    if (rejectedAt != null) {
      if (DateTime.now().difference(rejectedAt) < _rejectSuppressionWindow) {
        return Future.value(SslTrustDecision.reject);
      }
      _recentRejects.remove(key);
    }

    final existing = _inFlight[key];
    if (existing != null) return existing;

    final prompt = SslTrustPrompt(
      host: key,
      fingerprintSha256: entry.fingerprintSha256,
    );
    final future = prompt.completer.future;
    _inFlight[key] = future;
    _activePrompt = prompt;
    pendingPrompt.value = prompt;

    return future.whenComplete(() {
      _inFlight.remove(key);
      if (pendingPrompt.value == prompt) {
        // Clear the notifier first so listeners observe the "no prompt" state,
        // then drop the active reference. [resolvePrompt] consults the active
        // prompt rather than the notifier, so a listener reacting to this very
        // notification can still resolve it.
        pendingPrompt.value = null;
      }
      if (identical(_activePrompt, prompt)) {
        _activePrompt = null;
      }
    });
  }

  /// Answers the pending prompt. No-op when nothing is pending.
  ///
  /// Reads [_activePrompt] rather than [pendingPrompt], because a listener may
  /// call this while the notifier is mid-notification.
  void resolvePrompt(SslTrustDecision decision) {
    final prompt = _activePrompt;
    if (prompt == null || prompt.completer.isCompleted) return;
    if (decision == SslTrustDecision.reject) {
      _recentRejects[prompt.host] = DateTime.now();
    }
    prompt.completer.complete(decision);
  }

  /// Test seam: forget the suppression windows so tests do not leak state.
  @visibleForTesting
  void resetForTesting() {
    _temporary.clear();
    _persisted.clear();
    _inFlight.clear();
    _recentRejects.clear();
    _rejectedFingerprints.clear();
    _activePrompt = null;
    pendingPrompt.value = null;
  }
}
