import 'package:fluent_ui/fluent_ui.dart';

/// Design tokens for the TV big-screen mode, transcribed from
/// `design/tv-ui/shared.css` (1920×1080 reference canvas).
///
/// The TV mode always renders dark regardless of the app theme, mirroring the
/// fixed dark palette of the design.
abstract final class TvTheme {
  // ---- Canvas / letterbox ----
  /// Page background behind the letterboxed 16:9 canvas (`html, body`).
  static const Color letterboxBlack = Color(0xFF0A0A0B);

  /// Screen background (`--bg-base`).
  static const Color bgBase = Color(0xFF101011);
  static const Color bgSurface = Color(0xFF19191A);
  static const Color bgElevated = Color(0xFF202021);
  static const Color bgRaised = Color(0xFF2A2A2B);

  // ---- Brand ----
  static const Color brand = Color(0xFF3388FF);
  static const Color brandDeep = Color(0xFF0066FF);
  static const Color brandBright = Color(0xFF66A8FF);
  static const Color brandGlow = Color(0x733388FF); // rgba(51,136,255,.45)
  static const Color brandSoft = Color(0x243388FF); // rgba(51,136,255,.14)

  // ---- Text ----
  static const Color text0 = Color(0xFFFFFFFF);
  static const Color text1 = Color(0xCCFFFFFF); // 80%
  static const Color text2 = Color(0x99FFFFFF); // 60%
  static const Color text3 = Color(0x59FFFFFF); // 35%

  // ---- Borders / fills ----
  static const Color border = Color(0x1AFFFFFF); // 10%
  static const Color borderStrong = Color(0x2EFFFFFF); // 18%
  static const Color fill = Color(0x0FFFFFFF); // 6%
  static const Color fill2 = Color(0x1FFFFFFF); // 12%

  // ---- Accents ----
  /// Rating gold (`#f9c064`).
  static const Color ratingGold = Color(0xFFF9C064);
  static const Color ratingGoldText = Color(0xFF17181A);

  // ---- Shadows ----
  static const List<BoxShadow> shadowCard = [
    BoxShadow(color: Color(0x73000000), blurRadius: 24, offset: Offset(0, 8)),
  ];
  static const List<BoxShadow> shadowFocus = [
    BoxShadow(
      color: Color(0x8C000000),
      blurRadius: 48,
      offset: Offset(0, 16),
    ),
    BoxShadow(color: brandGlow, blurRadius: 32),
  ];

  // ---- Radii ----
  static const double radiusPoster = 8; // `.poster` hardcodes 8 (not 12)
  static const double radiusCard = 16;
  static const double radiusLg = 24;
  static const double radiusPill = 999;

  // ---- Canvas metrics (design px) ----
  static const double canvasWidth = 1920;
  static const double canvasHeight = 1080;
  static const double sidePadding = 72;

  // ---- Rail ----
  static const double railHeight = 96;
  static const double navItemHeight = 52;

  // ---- Hero ----
  static const double heroHeight = 580; // home.html inline override
  static const double heroBodyMaxWidth = 720;
  static const double heroBodyLeft = 72;
  static const double heroBodyBottom = 76;

  // ---- Shelves ----
  static const double shelfBottomMargin = 52;
  static const double shelfFirstTopMargin = 44;
  static const double shelfHeadBottomMargin = 22;
  static const double cardGap = 24;
  static const double shelfFadeWidth = 120;

  // ---- Cards ----
  static const double wideCardWidth = 400;
  static const double wideThumbHeight = 225;
  static const double posterCardWidth = 240;
  static const double posterHeight = 360;

  // ---- Buttons ----
  static const double buttonHeight = 64;
  static const double buttonSmallHeight = 52;

  // ---- Key hints ----
  static const double keyHintsHeight = 72;

  // ---- Focus frame ----
  /// CSS `outline-offset: 4px` + `outline-width: 3px`: the focus ring is
  /// drawn 3px wide, 4px outside the card box, i.e. a 7px halo around it.
  static const double focusRingWidth = 3;
  static const double focusRingOffset = 4;
  static const double focusHaloExtent = focusRingWidth + focusRingOffset;
  static const double focusScaleCard = 1.06;
  static const double focusScaleNav = 1.04;
  static const Duration focusTransition = Duration(milliseconds: 220);
  static const Curve focusCurve = Cubic(0.2, 0.8, 0.25, 1);

  // ---- Text styles (design px, latin numerals use the same family here) ----
  static const String fontFamily = 'PingFang SC';

  static const TextStyle heroKicker = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: brandBright,
    letterSpacing: 17 * 0.06,
  );
  static const TextStyle heroTitle = TextStyle(
    fontSize: 72,
    fontWeight: FontWeight.w900,
    color: text0,
    height: 1.08,
    letterSpacing: 72 * 0.01,
    shadows: [
      Shadow(color: Color(0x99000000), blurRadius: 32, offset: Offset(0, 4))
    ],
  );
  static const TextStyle heroMeta = TextStyle(
    fontSize: 19,
    color: text1,
    letterSpacing: 19 * 0.02,
  );
  static const TextStyle heroRatingNum = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: ratingGold,
  );
  static const TextStyle heroRatingOf = TextStyle(fontSize: 13, color: text3);
  static const TextStyle heroDesc = TextStyle(
    fontSize: 19,
    height: 1.65,
    color: text2,
  );

  static const TextStyle buttonLabel = TextStyle(
    fontSize: 21,
    fontWeight: FontWeight.w600,
    color: text0,
  );
  static const TextStyle buttonLabelSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: text0,
  );

  static const TextStyle shelfTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: text0,
    letterSpacing: 28 * 0.01,
  );
  static const TextStyle shelfCount = TextStyle(fontSize: 17, color: text3);
  static const TextStyle shelfMore = TextStyle(fontSize: 16, color: text3);

  static const TextStyle wideCardTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: text1,
  );
  static const TextStyle wideCardSubtitle = TextStyle(
    fontSize: 14,
    color: text3,
  );
  static const TextStyle resumeLabel = TextStyle(fontSize: 15, color: text1);
  static const TextStyle epTag = TextStyle(fontSize: 14, color: text0);

  static const TextStyle posterCardTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: text2,
  );
  static const TextStyle posterCardTitleFocused = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: text0,
  );
  static const TextStyle posterCardSubtitle = TextStyle(
    fontSize: 13,
    color: text3,
    letterSpacing: 13 * 0.03,
  );
  static const TextStyle posterRate = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w800,
    color: ratingGoldText,
    letterSpacing: 13 * 0.02,
  );
  static const TextStyle posterRes = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: text0,
    letterSpacing: 12 * 0.04,
  );

  static const TextStyle navItem = TextStyle(fontSize: 18, color: text2);
  static const TextStyle navItemActive = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: text0,
  );
  static const TextStyle logoName = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: text0,
    letterSpacing: 20 * 0.02,
  );
  static const TextStyle logoSub = TextStyle(
    fontSize: 10,
    color: text3,
    letterSpacing: 10 * 0.16,
  );
  static const TextStyle clock = TextStyle(
    fontSize: 18,
    color: text2,
    letterSpacing: 18 * 0.04,
  );
  static const TextStyle userName = TextStyle(fontSize: 15, color: text1);

  static const TextStyle keyHint = TextStyle(fontSize: 15, color: text3);
  static const TextStyle keyCap = TextStyle(fontSize: 13, color: text1);

  static const TextStyle emptyTitle = TextStyle(
    fontSize: 44,
    fontWeight: FontWeight.w800,
    color: text0,
  );
  static const TextStyle emptyDesc = TextStyle(
    fontSize: 19,
    height: 1.65,
    color: text2,
  );
}
