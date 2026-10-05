import '../../core/constants/app_constants.dart';
import '../../core/utils/json.dart';

enum FocalMode {
  none('None'),
  bold('Emphasise'),
  accent('Accent colour');

  const FocalMode(this.label);
  final String label;
}

enum ReaderFont {
  sans('Sans'),
  serif('Serif'),
  mono('Mono');

  const ReaderFont(this.label);
  final String label;
}

enum ReaderWeight {
  regular('Regular', 400),
  medium('Medium', 500),
  semibold('Semibold', 600),
  bold('Bold', 700);

  const ReaderWeight(this.label, this.value);
  final String label;
  final int value;
}

enum ReaderThemeId { midnight, graphite, sepia, paper }

class ReaderSettings {
  const ReaderSettings({
    this.defaultWpm = ReaderConstants.defaultWpm,
    this.fontScale = 1.0,
    this.font = ReaderFont.sans,
    this.weight = ReaderWeight.medium,
    this.focalMode = FocalMode.accent,
    this.showFocalGuides = true,
    this.punctuationPauses = true,
    this.clauseMultiplier = ReaderConstants.defaultClauseMultiplier,
    this.sentencePauses = true,
    this.sentenceMultiplier = ReaderConstants.defaultSentenceMultiplier,
    this.paragraphPauses = true,
    this.paragraphMultiplier = ReaderConstants.defaultParagraphMultiplier,
    this.longWordAdjustment = true,
    this.hapticFeedback = true,
    this.autoStartNextChapter = true,
    this.keepScreenAwake = true,
    this.showContextWhenPaused = true,
    this.smoothSpeedChanges = true,
    this.themeId = ReaderThemeId.midnight,
  });

  final int defaultWpm;
  final double fontScale;
  final ReaderFont font;
  final ReaderWeight weight;
  final FocalMode focalMode;
  final bool showFocalGuides;
  final bool punctuationPauses;
  final double clauseMultiplier;
  final bool sentencePauses;
  final double sentenceMultiplier;
  final bool paragraphPauses;
  final double paragraphMultiplier;
  final bool longWordAdjustment;
  final bool hapticFeedback;
  final bool autoStartNextChapter;
  final bool keepScreenAwake;
  final bool showContextWhenPaused;
  final bool smoothSpeedChanges;
  final ReaderThemeId themeId;

  bool get usesStandardTiming =>
      !punctuationPauses && !sentencePauses && !paragraphPauses && !longWordAdjustment;

  ReaderSettings copyWith({
    int? defaultWpm,
    double? fontScale,
    ReaderFont? font,
    ReaderWeight? weight,
    FocalMode? focalMode,
    bool? showFocalGuides,
    bool? punctuationPauses,
    double? clauseMultiplier,
    bool? sentencePauses,
    double? sentenceMultiplier,
    bool? paragraphPauses,
    double? paragraphMultiplier,
    bool? longWordAdjustment,
    bool? hapticFeedback,
    bool? autoStartNextChapter,
    bool? keepScreenAwake,
    bool? showContextWhenPaused,
    bool? smoothSpeedChanges,
    ReaderThemeId? themeId,
  }) {
    return ReaderSettings(
      defaultWpm: defaultWpm ?? this.defaultWpm,
      fontScale: fontScale ?? this.fontScale,
      font: font ?? this.font,
      weight: weight ?? this.weight,
      focalMode: focalMode ?? this.focalMode,
      showFocalGuides: showFocalGuides ?? this.showFocalGuides,
      punctuationPauses: punctuationPauses ?? this.punctuationPauses,
      clauseMultiplier: clauseMultiplier ?? this.clauseMultiplier,
      sentencePauses: sentencePauses ?? this.sentencePauses,
      sentenceMultiplier: sentenceMultiplier ?? this.sentenceMultiplier,
      paragraphPauses: paragraphPauses ?? this.paragraphPauses,
      paragraphMultiplier: paragraphMultiplier ?? this.paragraphMultiplier,
      longWordAdjustment: longWordAdjustment ?? this.longWordAdjustment,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      autoStartNextChapter: autoStartNextChapter ?? this.autoStartNextChapter,
      keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
      showContextWhenPaused: showContextWhenPaused ?? this.showContextWhenPaused,
      smoothSpeedChanges: smoothSpeedChanges ?? this.smoothSpeedChanges,
      themeId: themeId ?? this.themeId,
    );
  }

  /// Turns every timing adjustment on or off at once.
  ReaderSettings withStandardTiming(bool standard) => copyWith(
        punctuationPauses: !standard,
        sentencePauses: !standard,
        paragraphPauses: !standard,
        longWordAdjustment: !standard,
      );

  JsonMap toJson() => {
        'defaultWpm': defaultWpm,
        'fontScale': fontScale,
        'font': font.name,
        'weight': weight.name,
        'focalMode': focalMode.name,
        'showFocalGuides': showFocalGuides,
        'punctuationPauses': punctuationPauses,
        'clauseMultiplier': clauseMultiplier,
        'sentencePauses': sentencePauses,
        'sentenceMultiplier': sentenceMultiplier,
        'paragraphPauses': paragraphPauses,
        'paragraphMultiplier': paragraphMultiplier,
        'longWordAdjustment': longWordAdjustment,
        'hapticFeedback': hapticFeedback,
        'autoStartNextChapter': autoStartNextChapter,
        'keepScreenAwake': keepScreenAwake,
        'showContextWhenPaused': showContextWhenPaused,
        'smoothSpeedChanges': smoothSpeedChanges,
        'themeId': themeId.name,
      };

  factory ReaderSettings.fromJson(JsonMap json) {
    const d = ReaderSettings();
    double multiplier(String key, double fallback) => json
        .dbl(key, fallback)
        .clamp(ReaderConstants.minPauseMultiplier, ReaderConstants.maxPauseMultiplier);
    return ReaderSettings(
      defaultWpm: json
          .integer('defaultWpm', d.defaultWpm)
          .clamp(ReaderConstants.minWpm, ReaderConstants.maxWpm),
      fontScale: json
          .dbl('fontScale', d.fontScale)
          .clamp(ReaderConstants.minFontScale, ReaderConstants.maxFontScale),
      font: json.enumValue('font', ReaderFont.values, d.font),
      weight: json.enumValue('weight', ReaderWeight.values, d.weight),
      focalMode: json.enumValue('focalMode', FocalMode.values, d.focalMode),
      showFocalGuides: json.boolean('showFocalGuides', d.showFocalGuides),
      punctuationPauses: json.boolean('punctuationPauses', d.punctuationPauses),
      clauseMultiplier: multiplier('clauseMultiplier', d.clauseMultiplier),
      sentencePauses: json.boolean('sentencePauses', d.sentencePauses),
      sentenceMultiplier: multiplier('sentenceMultiplier', d.sentenceMultiplier),
      paragraphPauses: json.boolean('paragraphPauses', d.paragraphPauses),
      paragraphMultiplier: multiplier('paragraphMultiplier', d.paragraphMultiplier),
      longWordAdjustment: json.boolean('longWordAdjustment', d.longWordAdjustment),
      hapticFeedback: json.boolean('hapticFeedback', d.hapticFeedback),
      autoStartNextChapter: json.boolean('autoStartNextChapter', d.autoStartNextChapter),
      keepScreenAwake: json.boolean('keepScreenAwake', d.keepScreenAwake),
      showContextWhenPaused:
          json.boolean('showContextWhenPaused', d.showContextWhenPaused),
      smoothSpeedChanges: json.boolean('smoothSpeedChanges', d.smoothSpeedChanges),
      themeId: json.enumValue('themeId', ReaderThemeId.values, d.themeId),
    );
  }
}
