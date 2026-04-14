/// How wide the main reading column is allowed to stretch.
///
/// Only meaningful on wide viewports (tablets, landscape
/// phones): on a narrow phone every option collapses to the full
/// available width. The three presets mirror the common "comfy /
/// wide / full" triad used by reader apps like Readwise and
/// Apple Books.
enum ReadingWidth {
  /// ~680 dp cap — the classic 65-character prose measure, best
  /// for long-form reading where line length is the dominant
  /// comfort variable.
  comfortable,

  /// ~840 dp cap — still bounded, but lets code blocks and wide
  /// tables breathe on a tablet without clipping. Sensible
  /// default for technical documentation.
  wide,

  /// No cap — the reading column stretches to the full viewport
  /// width. Users who specifically want their device's real
  /// estate (e.g. external monitor, side-by-side layout) can
  /// pick this.
  full;

  /// Persistent string tag used by [SettingsStore] so a future
  /// migration does not have to reach for the enum index.
  String get tag {
    switch (this) {
      case ReadingWidth.comfortable:
        return 'comfortable';
      case ReadingWidth.wide:
        return 'wide';
      case ReadingWidth.full:
        return 'full';
    }
  }

  static ReadingWidth fromTag(String? tag) {
    switch (tag) {
      case 'wide':
        return ReadingWidth.wide;
      case 'full':
        return ReadingWidth.full;
      case 'comfortable':
      default:
        return ReadingWidth.comfortable;
    }
  }

  /// Logical pixel cap the reading column should honour on
  /// wide viewports. Returned as `double.infinity` for the
  /// "full" option so a `ConstrainedBox` collapses to "no
  /// constraint".
  double get maxWidth {
    switch (this) {
      case ReadingWidth.comfortable:
        return 680;
      case ReadingWidth.wide:
        return 840;
      case ReadingWidth.full:
        return double.infinity;
    }
  }
}

/// How tall each line of prose should render relative to the
/// typographic baseline. Mapped through to the markdown config's
/// `pConfig.textStyle.height` so paragraph text responds
/// immediately when the user flips between options.
enum ReadingLineHeight {
  /// ~1.35× — tighter layout, fits more content on screen.
  /// Useful on small phones when the user wants to see the
  /// structure of the document at a glance.
  compact,

  /// ~1.55× — the default, matching Material 3 body-medium.
  standard,

  /// ~1.8× — looser layout with extra breathing room between
  /// lines. Best for long-form reading or for users who find
  /// the default too dense.
  airy;

  String get tag {
    switch (this) {
      case ReadingLineHeight.compact:
        return 'compact';
      case ReadingLineHeight.standard:
        return 'standard';
      case ReadingLineHeight.airy:
        return 'airy';
    }
  }

  static ReadingLineHeight fromTag(String? tag) {
    switch (tag) {
      case 'compact':
        return ReadingLineHeight.compact;
      case 'airy':
        return ReadingLineHeight.airy;
      case 'standard':
      default:
        return ReadingLineHeight.standard;
    }
  }

  double get multiplier {
    switch (this) {
      case ReadingLineHeight.compact:
        return 1.35;
      case ReadingLineHeight.standard:
        return 1.55;
      case ReadingLineHeight.airy:
        return 1.8;
    }
  }
}

/// Reading comfort settings: font scale, line height, reading
/// width cap. A single value object so the controller hands it
/// out atomically to widgets that need to rebuild when any of
/// the three change together.
class ReadingSettings {
  const ReadingSettings({
    required this.fontScale,
    required this.width,
    required this.lineHeight,
  });

  /// Text scale factor applied on top of the system's dynamic
  /// type setting. Kept in `[minFontScale, maxFontScale]` so the
  /// layout cannot completely break on extreme values.
  final double fontScale;
  final ReadingWidth width;
  final ReadingLineHeight lineHeight;

  /// Default for a fresh install: 1.0x scale, comfortable width,
  /// standard line height. Matches the legacy viewer rendering
  /// so existing users see no visual delta after the feature
  /// lands.
  static const ReadingSettings defaults = ReadingSettings(
    fontScale: 1,
    width: ReadingWidth.comfortable,
    lineHeight: ReadingLineHeight.standard,
  );

  static const double minFontScale = 0.85;
  static const double maxFontScale = 1.5;

  ReadingSettings copyWith({
    double? fontScale,
    ReadingWidth? width,
    ReadingLineHeight? lineHeight,
  }) {
    return ReadingSettings(
      fontScale: fontScale ?? this.fontScale,
      width: width ?? this.width,
      lineHeight: lineHeight ?? this.lineHeight,
    );
  }
}
