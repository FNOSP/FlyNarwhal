/// Smart skip analysis configuration, mirrored from the server-side
/// SmartSkipConfig (intro-skipper aligned defaults).
class SmartSkipConfig {
  final bool scanIntroduction;
  final bool scanCredits;
  final bool scanRecap;
  final bool scanPreview;
  final bool scanCommercial;

  final int analysisPercent;
  final int analysisLengthLimit;

  final int minimumIntroDuration;
  final int maximumIntroDuration;
  final int minimumCreditsDuration;
  final int maximumCreditsDuration;
  final int maximumMovieCreditsDuration;
  final int minimumRecapDuration;
  final int maximumRecapDuration;
  final int minimumPreviewDuration;
  final int maximumPreviewDuration;
  final int minimumCommercialDuration;
  final int maximumCommercialDuration;

  final bool adjustIntroBasedOnChapters;
  final bool adjustIntroBasedOnSilence;
  final int silenceDetectionMaximumNoise;
  final double silenceDetectionMinimumDuration;
  final int introEndOffset;
  final int introStartOffset;
  final int creditsEndOffset;

  final String chapterAnalyzerIntroductionPattern;
  final String chapterAnalyzerEndCreditsPattern;
  final String chapterAnalyzerRecapPattern;
  final String chapterAnalyzerPreviewPattern;
  final String chapterAnalyzerCommercialPattern;

  final bool preferChromaprint;
  final int maximumFingerprintPointDifferences;
  final double maximumTimeSkip;

  final bool useAlternativeBlackFrameAnalyzer;
  final int blackFrameMinimumPercentage;
  final int blackFrameThreshold;

  final bool animeDetection;

  const SmartSkipConfig({
    this.scanIntroduction = true,
    this.scanCredits = true,
    this.scanRecap = true,
    this.scanPreview = true,
    this.scanCommercial = false,
    this.analysisPercent = 25,
    this.analysisLengthLimit = 10,
    this.minimumIntroDuration = 15,
    this.maximumIntroDuration = 120,
    this.minimumCreditsDuration = 15,
    this.maximumCreditsDuration = 450,
    this.maximumMovieCreditsDuration = 900,
    this.minimumRecapDuration = 15,
    this.maximumRecapDuration = 120,
    this.minimumPreviewDuration = 15,
    this.maximumPreviewDuration = 120,
    this.minimumCommercialDuration = 15,
    this.maximumCommercialDuration = 120,
    this.adjustIntroBasedOnChapters = true,
    this.adjustIntroBasedOnSilence = true,
    this.silenceDetectionMaximumNoise = -50,
    this.silenceDetectionMinimumDuration = 0.33,
    this.introEndOffset = 0,
    this.introStartOffset = 0,
    this.creditsEndOffset = 0,
    this.chapterAnalyzerIntroductionPattern =
        r'^(Intro|Introduction|OP|Opening)(?!\sEnd)(\s|$)',
    this.chapterAnalyzerEndCreditsPattern =
        r'^(Credits?|ED|Ending|Outro)(?!\sEnd)(\s|$)',
    this.chapterAnalyzerRecapPattern = r'^(Recap|Summary|Previously)(\s|$)',
    this.chapterAnalyzerPreviewPattern =
        r'^(Preview|PV|Sneak Peek|Coming Soon)(\s|$)',
    this.chapterAnalyzerCommercialPattern =
        r'^(Advertisement|Commercial)(\s|$)',
    this.preferChromaprint = false,
    this.maximumFingerprintPointDifferences = 6,
    this.maximumTimeSkip = 3.5,
    this.useAlternativeBlackFrameAnalyzer = false,
    this.blackFrameMinimumPercentage = 85,
    this.blackFrameThreshold = 28,
    this.animeDetection = false,
  });

  factory SmartSkipConfig.fromJson(Map<String, dynamic> json) {
    return SmartSkipConfig(
      scanIntroduction: json['scanIntroduction'] as bool? ?? true,
      scanCredits: json['scanCredits'] as bool? ?? true,
      scanRecap: json['scanRecap'] as bool? ?? true,
      scanPreview: json['scanPreview'] as bool? ?? true,
      scanCommercial: json['scanCommercial'] as bool? ?? false,
      analysisPercent: _readInt(json['analysisPercent'], 25),
      analysisLengthLimit: _readInt(json['analysisLengthLimit'], 10),
      minimumIntroDuration: _readInt(json['minimumIntroDuration'], 15),
      maximumIntroDuration: _readInt(json['maximumIntroDuration'], 120),
      minimumCreditsDuration: _readInt(json['minimumCreditsDuration'], 15),
      maximumCreditsDuration: _readInt(json['maximumCreditsDuration'], 450),
      maximumMovieCreditsDuration:
          _readInt(json['maximumMovieCreditsDuration'], 900),
      minimumRecapDuration: _readInt(json['minimumRecapDuration'], 15),
      maximumRecapDuration: _readInt(json['maximumRecapDuration'], 120),
      minimumPreviewDuration: _readInt(json['minimumPreviewDuration'], 15),
      maximumPreviewDuration: _readInt(json['maximumPreviewDuration'], 120),
      minimumCommercialDuration:
          _readInt(json['minimumCommercialDuration'], 15),
      maximumCommercialDuration:
          _readInt(json['maximumCommercialDuration'], 120),
      adjustIntroBasedOnChapters:
          json['adjustIntroBasedOnChapters'] as bool? ?? true,
      adjustIntroBasedOnSilence:
          json['adjustIntroBasedOnSilence'] as bool? ?? true,
      silenceDetectionMaximumNoise:
          _readInt(json['silenceDetectionMaximumNoise'], -50),
      silenceDetectionMinimumDuration:
          _readDouble(json['silenceDetectionMinimumDuration'], 0.33),
      introEndOffset: _readInt(json['introEndOffset'], 0),
      introStartOffset: _readInt(json['introStartOffset'], 0),
      creditsEndOffset: _readInt(json['creditsEndOffset'], 0),
      chapterAnalyzerIntroductionPattern:
          json['chapterAnalyzerIntroductionPattern']?.toString() ??
              r'^(Intro|Introduction|OP|Opening)(?!\sEnd)(\s|$)',
      chapterAnalyzerEndCreditsPattern:
          json['chapterAnalyzerEndCreditsPattern']?.toString() ??
              r'^(Credits?|ED|Ending|Outro)(?!\sEnd)(\s|$)',
      chapterAnalyzerRecapPattern:
          json['chapterAnalyzerRecapPattern']?.toString() ??
              r'^(Recap|Summary|Previously)(\s|$)',
      chapterAnalyzerPreviewPattern:
          json['chapterAnalyzerPreviewPattern']?.toString() ??
              r'^(Preview|PV|Sneak Peek|Coming Soon)(\s|$)',
      chapterAnalyzerCommercialPattern:
          json['chapterAnalyzerCommercialPattern']?.toString() ??
              r'^(Advertisement|Commercial)(\s|$)',
      preferChromaprint: json['preferChromaprint'] as bool? ?? false,
      maximumFingerprintPointDifferences:
          _readInt(json['maximumFingerprintPointDifferences'], 6),
      maximumTimeSkip: _readDouble(json['maximumTimeSkip'], 3.5),
      useAlternativeBlackFrameAnalyzer:
          json['useAlternativeBlackFrameAnalyzer'] as bool? ?? false,
      blackFrameMinimumPercentage:
          _readInt(json['blackFrameMinimumPercentage'], 85),
      blackFrameThreshold: _readInt(json['blackFrameThreshold'], 28),
      animeDetection: json['animeDetection'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'scanIntroduction': scanIntroduction,
      'scanCredits': scanCredits,
      'scanRecap': scanRecap,
      'scanPreview': scanPreview,
      'scanCommercial': scanCommercial,
      'analysisPercent': analysisPercent,
      'analysisLengthLimit': analysisLengthLimit,
      'minimumIntroDuration': minimumIntroDuration,
      'maximumIntroDuration': maximumIntroDuration,
      'minimumCreditsDuration': minimumCreditsDuration,
      'maximumCreditsDuration': maximumCreditsDuration,
      'maximumMovieCreditsDuration': maximumMovieCreditsDuration,
      'minimumRecapDuration': minimumRecapDuration,
      'maximumRecapDuration': maximumRecapDuration,
      'minimumPreviewDuration': minimumPreviewDuration,
      'maximumPreviewDuration': maximumPreviewDuration,
      'minimumCommercialDuration': minimumCommercialDuration,
      'maximumCommercialDuration': maximumCommercialDuration,
      'adjustIntroBasedOnChapters': adjustIntroBasedOnChapters,
      'adjustIntroBasedOnSilence': adjustIntroBasedOnSilence,
      'silenceDetectionMaximumNoise': silenceDetectionMaximumNoise,
      'silenceDetectionMinimumDuration': silenceDetectionMinimumDuration,
      'introEndOffset': introEndOffset,
      'introStartOffset': introStartOffset,
      'creditsEndOffset': creditsEndOffset,
      'chapterAnalyzerIntroductionPattern':
          chapterAnalyzerIntroductionPattern,
      'chapterAnalyzerEndCreditsPattern': chapterAnalyzerEndCreditsPattern,
      'chapterAnalyzerRecapPattern': chapterAnalyzerRecapPattern,
      'chapterAnalyzerPreviewPattern': chapterAnalyzerPreviewPattern,
      'chapterAnalyzerCommercialPattern': chapterAnalyzerCommercialPattern,
      'preferChromaprint': preferChromaprint,
      'maximumFingerprintPointDifferences': maximumFingerprintPointDifferences,
      'maximumTimeSkip': maximumTimeSkip,
      'useAlternativeBlackFrameAnalyzer': useAlternativeBlackFrameAnalyzer,
      'blackFrameMinimumPercentage': blackFrameMinimumPercentage,
      'blackFrameThreshold': blackFrameThreshold,
      'animeDetection': animeDetection,
    };
  }

  SmartSkipConfig copyWith({
    bool? scanIntroduction,
    bool? scanCredits,
    bool? scanRecap,
    bool? scanPreview,
    bool? scanCommercial,
    int? analysisPercent,
    int? analysisLengthLimit,
    int? minimumIntroDuration,
    int? maximumIntroDuration,
    int? minimumCreditsDuration,
    int? maximumCreditsDuration,
    int? maximumMovieCreditsDuration,
    int? minimumRecapDuration,
    int? maximumRecapDuration,
    int? minimumPreviewDuration,
    int? maximumPreviewDuration,
    int? minimumCommercialDuration,
    int? maximumCommercialDuration,
    bool? adjustIntroBasedOnChapters,
    bool? adjustIntroBasedOnSilence,
    int? silenceDetectionMaximumNoise,
    double? silenceDetectionMinimumDuration,
    int? introEndOffset,
    int? introStartOffset,
    int? creditsEndOffset,
    String? chapterAnalyzerIntroductionPattern,
    String? chapterAnalyzerEndCreditsPattern,
    String? chapterAnalyzerRecapPattern,
    String? chapterAnalyzerPreviewPattern,
    String? chapterAnalyzerCommercialPattern,
    bool? preferChromaprint,
    int? maximumFingerprintPointDifferences,
    double? maximumTimeSkip,
    bool? useAlternativeBlackFrameAnalyzer,
    int? blackFrameMinimumPercentage,
    int? blackFrameThreshold,
    bool? animeDetection,
  }) {
    return SmartSkipConfig(
      scanIntroduction: scanIntroduction ?? this.scanIntroduction,
      scanCredits: scanCredits ?? this.scanCredits,
      scanRecap: scanRecap ?? this.scanRecap,
      scanPreview: scanPreview ?? this.scanPreview,
      scanCommercial: scanCommercial ?? this.scanCommercial,
      analysisPercent: analysisPercent ?? this.analysisPercent,
      analysisLengthLimit: analysisLengthLimit ?? this.analysisLengthLimit,
      minimumIntroDuration: minimumIntroDuration ?? this.minimumIntroDuration,
      maximumIntroDuration: maximumIntroDuration ?? this.maximumIntroDuration,
      minimumCreditsDuration:
          minimumCreditsDuration ?? this.minimumCreditsDuration,
      maximumCreditsDuration:
          maximumCreditsDuration ?? this.maximumCreditsDuration,
      maximumMovieCreditsDuration:
          maximumMovieCreditsDuration ?? this.maximumMovieCreditsDuration,
      minimumRecapDuration: minimumRecapDuration ?? this.minimumRecapDuration,
      maximumRecapDuration: maximumRecapDuration ?? this.maximumRecapDuration,
      minimumPreviewDuration:
          minimumPreviewDuration ?? this.minimumPreviewDuration,
      maximumPreviewDuration:
          maximumPreviewDuration ?? this.maximumPreviewDuration,
      minimumCommercialDuration:
          minimumCommercialDuration ?? this.minimumCommercialDuration,
      maximumCommercialDuration:
          maximumCommercialDuration ?? this.maximumCommercialDuration,
      adjustIntroBasedOnChapters:
          adjustIntroBasedOnChapters ?? this.adjustIntroBasedOnChapters,
      adjustIntroBasedOnSilence:
          adjustIntroBasedOnSilence ?? this.adjustIntroBasedOnSilence,
      silenceDetectionMaximumNoise:
          silenceDetectionMaximumNoise ?? this.silenceDetectionMaximumNoise,
      silenceDetectionMinimumDuration: silenceDetectionMinimumDuration ??
          this.silenceDetectionMinimumDuration,
      introEndOffset: introEndOffset ?? this.introEndOffset,
      introStartOffset: introStartOffset ?? this.introStartOffset,
      creditsEndOffset: creditsEndOffset ?? this.creditsEndOffset,
      chapterAnalyzerIntroductionPattern: chapterAnalyzerIntroductionPattern ??
          this.chapterAnalyzerIntroductionPattern,
      chapterAnalyzerEndCreditsPattern: chapterAnalyzerEndCreditsPattern ??
          this.chapterAnalyzerEndCreditsPattern,
      chapterAnalyzerRecapPattern:
          chapterAnalyzerRecapPattern ?? this.chapterAnalyzerRecapPattern,
      chapterAnalyzerPreviewPattern:
          chapterAnalyzerPreviewPattern ?? this.chapterAnalyzerPreviewPattern,
      chapterAnalyzerCommercialPattern: chapterAnalyzerCommercialPattern ??
          this.chapterAnalyzerCommercialPattern,
      preferChromaprint: preferChromaprint ?? this.preferChromaprint,
      maximumFingerprintPointDifferences: maximumFingerprintPointDifferences ??
          this.maximumFingerprintPointDifferences,
      maximumTimeSkip: maximumTimeSkip ?? this.maximumTimeSkip,
      useAlternativeBlackFrameAnalyzer: useAlternativeBlackFrameAnalyzer ??
          this.useAlternativeBlackFrameAnalyzer,
      blackFrameMinimumPercentage:
          blackFrameMinimumPercentage ?? this.blackFrameMinimumPercentage,
      blackFrameThreshold: blackFrameThreshold ?? this.blackFrameThreshold,
      animeDetection: animeDetection ?? this.animeDetection,
    );
  }

  static int _readInt(Object? value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static double _readDouble(Object? value, double fallback) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }
}

/// Request body for POST /api/analysis/smart-skip-config.
class SaveSmartSkipConfigRequest {
  final String userGuid;
  final SmartSkipConfig config;

  const SaveSmartSkipConfigRequest({
    required this.userGuid,
    required this.config,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'user_guid': userGuid,
      'config': config.toJson(),
    };
  }
}
