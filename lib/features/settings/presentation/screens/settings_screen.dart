import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:markdown_viewer/app/router.dart';
import 'package:markdown_viewer/core/l10n/build_context_l10n.dart';
import 'package:markdown_viewer/features/observability/application/observability_providers.dart';
import 'package:markdown_viewer/features/onboarding/application/onboarding_providers.dart';
import 'package:markdown_viewer/features/settings/application/settings_providers.dart';
import 'package:markdown_viewer/features/settings/domain/app_locale.dart';
import 'package:markdown_viewer/features/settings/domain/app_theme_mode.dart';
import 'package:markdown_viewer/features/settings/domain/reading_settings.dart';

/// Screen offering the personalisation knobs: theme mode, language,
/// reading comfort, and display options. Lives on its own `/settings`
/// route pushed from the library screen's AppBar.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final themeMode = ref.watch(themeModeControllerProvider);
    final locale = ref.watch(localeControllerProvider);
    final readingSettings = ref.watch(readingSettingsControllerProvider);
    final keepScreenOn = ref.watch(keepScreenOnControllerProvider);
    final crashReporting = ref.watch(crashReportingControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: ListView(
        children: [
          _SectionHeader(title: l10n.settingsThemeTitle),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            // Four modes in one row — labels are kept to single words
            // ("System", "Light", "Dark", "Sepia") so the button fits
            // comfortably on narrow phones.
            child: SegmentedButton<AppThemeMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: AppThemeMode.system,
                  label: Text(l10n.settingsThemeSystem),
                ),
                ButtonSegment(
                  value: AppThemeMode.light,
                  label: Text(l10n.settingsThemeLight),
                ),
                ButtonSegment(
                  value: AppThemeMode.dark,
                  label: Text(l10n.settingsThemeDark),
                ),
                ButtonSegment(
                  value: AppThemeMode.sepia,
                  label: Text(l10n.settingsThemeSepia),
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
          const Divider(),
          _SectionHeader(title: l10n.settingsDisplayTitle),
          SwitchListTile(
            title: Text(l10n.settingsKeepScreenOnTitle),
            subtitle: Text(l10n.settingsKeepScreenOnSubtitle),
            value: keepScreenOn,
            onChanged: (value) {
              ref.read(keepScreenOnControllerProvider.notifier).set(value);
            },
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          SwitchListTile(
            title: Text(l10n.settingsCrashReportingTitle),
            subtitle: Text(l10n.settingsCrashReportingSubtitle),
            value: crashReporting,
            onChanged: (value) {
              ref
                  .read(crashReportingControllerProvider.notifier)
                  .setEnabled(value)
                  .ignore();
            },
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.restart_alt),
                label: Text(l10n.settingsResetButton),
                onPressed: () => _confirmReset(context, ref),
              ),
            ),
          ),
          // Debug-only affordance: relaunch the onboarding flow
          // without reinstalling the app. `kDebugMode` is a compile-
          // time constant, so the whole block — button, handler, and
          // the onboarding-provider import path — is tree-shaken out
          // of release builds.
          if (kDebugMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.replay_circle_filled_outlined),
                  label: Text(l10n.settingsDebugResetOnboarding),
                  onPressed: () => _resetOnboarding(context, ref),
                ),
              ),
            ),
          if (!kDebugMode) const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Clears the stored "seen" marker and navigates straight to the
  /// onboarding route so the developer can preview the flow on a
  /// physical device without wiping the whole app. Gated to
  /// `kDebugMode` at the call site so it cannot fire in a release
  /// build.
  void _resetOnboarding(BuildContext context, WidgetRef ref) {
    ref.read(onboardingControllerProvider.notifier).reset();
    // The router's redirect guard reads `shouldShowOnboardingProvider`
    // on every navigation; now that the controller state is back to
    // 0, sending the user to `/onboarding` will be allowed through
    // and the flow reappears immediately.
    context.go(OnboardingRoute.location());
  }

  /// Shows a confirmation dialog before wiping every user
  /// preference back to the platform defaults. Reset is always
  /// destructive — even if the user wanted it, an accidental
  /// tap on the wrong button would feel like data loss — so
  /// the dialog is mandatory rather than a quick snackbar
  /// undo.
  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(l10n.settingsResetConfirmTitle),
            content: Text(l10n.settingsResetConfirmBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.actionCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.settingsResetConfirmAction),
              ),
            ],
          ),
    );
    if (confirmed != true || !context.mounted) return;
    ref.read(themeModeControllerProvider.notifier).set(AppThemeMode.system);
    ref.read(localeControllerProvider.notifier).set(AppLocale.system);
    ref.read(readingSettingsControllerProvider.notifier).resetToDefaults();
    ref.read(keepScreenOnControllerProvider.notifier).set(false);
    ref
        .read(crashReportingControllerProvider.notifier)
        .setEnabled(false)
        .ignore();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.settingsResetSnack)));
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
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
