import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_viewer/core/l10n/build_context_l10n.dart';
import 'package:markdown_viewer/features/settings/application/settings_providers.dart';
import 'package:markdown_viewer/features/settings/domain/app_locale.dart';
import 'package:markdown_viewer/features/settings/domain/reading_settings.dart';

/// Screen offering the two v1 personalisation knobs: theme mode and
/// language. Lives on its own `/settings` route pushed from the
/// library screen's AppBar. Intentionally a simple vertical list —
/// no grouping tiles, no custom layouts — so adding more settings
/// later (font size, reading width, etc.) is a single `ListView`
/// child addition.
///
/// Uses the `RadioGroup` ancestor API introduced post-Flutter 3.32
/// so the tiles don't rely on the deprecated `groupValue` /
/// `onChanged` properties on `RadioListTile` itself — the group
/// state lives on the wrapping widget.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final themeMode = ref.watch(themeModeControllerProvider);
    final locale = ref.watch(localeControllerProvider);
    final readingSettings = ref.watch(readingSettingsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: ListView(
        children: [
          _SectionHeader(title: l10n.settingsThemeTitle),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text(l10n.settingsThemeSystem),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text(l10n.settingsThemeLight),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text(l10n.settingsThemeDark),
                ),
              ],
              selected: {themeMode},
              onSelectionChanged: (selection) {
                ref
                    .read(themeModeControllerProvider.notifier)
                    .set(selection.first);
              },
            ),
          ),
          const Divider(),
          _SectionHeader(title: l10n.settingsLanguageTitle),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: SegmentedButton<AppLocale>(
              segments: [
                ButtonSegment(
                  value: AppLocale.system,
                  label: Text(l10n.settingsLanguageSystem),
                ),
                ButtonSegment(
                  value: AppLocale.english,
                  label: Text(l10n.settingsLanguageEnglish),
                ),
                ButtonSegment(
                  value: AppLocale.turkish,
                  label: Text(l10n.settingsLanguageTurkish),
                ),
              ],
              selected: {locale},
              onSelectionChanged: (selection) {
                ref
                    .read(localeControllerProvider.notifier)
                    .set(selection.first);
              },
            ),
          ),
          const Divider(),
          _SectionHeader(title: l10n.settingsReadingTitle),
          _ReadingSettingsSection(settings: readingSettings),
        ],
      ),
    );
  }
}

/// Reading-comfort section of the settings screen: font scale
/// slider + reading width segmented button + line height
/// segmented button. Each control wires straight to
/// [ReadingSettingsController] so a drag / tap re-renders the
/// viewer body through Riverpod without a manual invalidation.
class _ReadingSettingsSection extends ConsumerWidget {
  const _ReadingSettingsSection({required this.settings});

  final ReadingSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final controller = ref.read(readingSettingsControllerProvider.notifier);

    final percent = (settings.fontScale * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.settingsReadingFontScaleTitle,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              Text(
                l10n.settingsReadingFontScaleValue(percent),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Slider(
            value: settings.fontScale,
            min: ReadingSettings.minFontScale,
            max: ReadingSettings.maxFontScale,
            // Step in 5% increments so the live preview snaps to
            // readable values instead of turning into a
            // fractional pixel mess — users generally want
            // "115%", not "114.73%".
            divisions:
                ((ReadingSettings.maxFontScale - ReadingSettings.minFontScale) /
                        0.05)
                    .round(),
            label: '$percent%',
            onChanged: controller.setFontScale,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Text(
            l10n.settingsReadingWidthTitle,
            style: theme.textTheme.bodyLarge,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<ReadingWidth>(
            segments: [
              ButtonSegment(
                value: ReadingWidth.comfortable,
                label: Text(l10n.settingsReadingWidthComfortable),
              ),
              ButtonSegment(
                value: ReadingWidth.wide,
                label: Text(l10n.settingsReadingWidthWide),
              ),
              ButtonSegment(
                value: ReadingWidth.full,
                label: Text(l10n.settingsReadingWidthFull),
              ),
            ],
            selected: {settings.width},
            onSelectionChanged: (selection) {
              controller.setWidth(selection.first);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Text(
            l10n.settingsReadingLineHeightTitle,
            style: theme.textTheme.bodyLarge,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SegmentedButton<ReadingLineHeight>(
            segments: [
              ButtonSegment(
                value: ReadingLineHeight.compact,
                label: Text(l10n.settingsReadingLineHeightCompact),
              ),
              ButtonSegment(
                value: ReadingLineHeight.standard,
                label: Text(l10n.settingsReadingLineHeightStandard),
              ),
              ButtonSegment(
                value: ReadingLineHeight.airy,
                label: Text(l10n.settingsReadingLineHeightAiry),
              ),
            ],
            selected: {settings.lineHeight},
            onSelectionChanged: (selection) {
              controller.setLineHeight(selection.first);
            },
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
