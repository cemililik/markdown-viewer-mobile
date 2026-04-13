import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_viewer/core/l10n/build_context_l10n.dart';
import 'package:markdown_viewer/features/settings/application/settings_providers.dart';
import 'package:markdown_viewer/features/settings/domain/app_locale.dart';

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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: ListView(
        children: [
          _SectionHeader(title: l10n.settingsThemeTitle),
          RadioGroup<ThemeMode>(
            groupValue: themeMode,
            onChanged: (value) {
              if (value != null) {
                ref.read(themeModeControllerProvider.notifier).set(value);
              }
            },
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  title: Text(l10n.settingsThemeSystem),
                  value: ThemeMode.system,
                ),
                RadioListTile<ThemeMode>(
                  title: Text(l10n.settingsThemeLight),
                  value: ThemeMode.light,
                ),
                RadioListTile<ThemeMode>(
                  title: Text(l10n.settingsThemeDark),
                  value: ThemeMode.dark,
                ),
              ],
            ),
          ),
          const Divider(),
          _SectionHeader(title: l10n.settingsLanguageTitle),
          RadioGroup<AppLocale>(
            groupValue: locale,
            onChanged: (value) {
              if (value != null) {
                ref.read(localeControllerProvider.notifier).set(value);
              }
            },
            child: Column(
              children: [
                RadioListTile<AppLocale>(
                  title: Text(l10n.settingsLanguageSystem),
                  value: AppLocale.system,
                ),
                RadioListTile<AppLocale>(
                  title: Text(l10n.settingsLanguageEnglish),
                  value: AppLocale.english,
                ),
                RadioListTile<AppLocale>(
                  title: Text(l10n.settingsLanguageTurkish),
                  value: AppLocale.turkish,
                ),
              ],
            ),
          ),
        ],
      ),
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
