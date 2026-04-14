import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:markdown_viewer/app/router.dart';
import 'package:markdown_viewer/core/l10n/build_context_l10n.dart';
import 'package:markdown_viewer/features/settings/application/settings_providers.dart';
import 'package:markdown_viewer/features/settings/domain/reading_settings.dart';

/// Slides the reading-comfort knobs the user is most likely to
/// want to change *while* reading into a single bottom sheet
/// surfaced from the viewer AppBar.
///
/// Mounted via [showViewerReadingPanel] so the caller does not
/// have to know about `showModalBottomSheet` plumbing. The
/// sheet is intentionally non-blocking: each control writes to
/// the live providers (`themeModeControllerProvider` +
/// `readingSettingsControllerProvider`), so the document
/// re-renders behind the sheet as the user drags. A drag
/// handle + tap-outside-to-dismiss keep the sheet feeling like
/// a quick tweak panel rather than a modal route.
///
/// The sheet exposes:
///
/// - **Theme** (System / Light / Dark) — the most reading-
///   relevant non-typography preference.
/// - **Font size** slider — same range as the full settings
///   screen (0.85× → 1.5× in 5% steps).
/// - **Reading width** segmented button.
/// - **Line spacing** segmented button.
/// - A **Reset reading defaults** text button that pulls just
///   the three reading knobs back to their initial values
///   without touching theme.
/// - An **All settings** link that pushes the full settings
///   route — used for preferences not exposed here (language,
///   future settings).
Future<void> showViewerReadingPanel(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => const _ViewerReadingPanelBody(),
  );
}

class _ViewerReadingPanelBody extends ConsumerWidget {
  const _ViewerReadingPanelBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final themeMode = ref.watch(themeModeControllerProvider);
    final readingSettings = ref.watch(readingSettingsControllerProvider);
    final readingController = ref.read(
      readingSettingsControllerProvider.notifier,
    );
    final percent = (readingSettings.fontScale * 100).round();

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
              child: Text(
                l10n.viewerReadingPanelTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            // Theme — most reading-relevant non-typography knob.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                l10n.settingsThemeTitle,
                style: theme.textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 6),
            SegmentedButton<ThemeMode>(
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
            const SizedBox(height: 16),
            // Font size slider with live percentage readout.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
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
            Slider(
              value: readingSettings.fontScale,
              min: ReadingSettings.minFontScale,
              max: ReadingSettings.maxFontScale,
              divisions:
                  ((ReadingSettings.maxFontScale -
                              ReadingSettings.minFontScale) /
                          0.05)
                      .round(),
              label: '$percent%',
              onChanged: readingController.setFontScale,
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                l10n.settingsReadingWidthTitle,
                style: theme.textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 6),
            SegmentedButton<ReadingWidth>(
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
              selected: {readingSettings.width},
              onSelectionChanged: (selection) {
                readingController.setWidth(selection.first);
              },
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                l10n.settingsReadingLineHeightTitle,
                style: theme.textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 6),
            SegmentedButton<ReadingLineHeight>(
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
              selected: {readingSettings.lineHeight},
              onSelectionChanged: (selection) {
                readingController.setLineHeight(selection.first);
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: Text(l10n.viewerReadingPanelResetButton),
                  onPressed: readingController.resetToDefaults,
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  label: Text(l10n.viewerReadingPanelAllSettings),
                  onPressed: () {
                    Navigator.of(context).maybePop();
                    context.push(SettingsRoute.location());
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
