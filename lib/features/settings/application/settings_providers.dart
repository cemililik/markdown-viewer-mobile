import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_viewer/features/settings/data/settings_store.dart';
import 'package:markdown_viewer/features/settings/domain/app_locale.dart';
import 'package:markdown_viewer/features/settings/domain/app_theme_mode.dart';
import 'package:markdown_viewer/features/settings/domain/reading_settings.dart';

/// Application-layer binding for the [SettingsStore] port. Thrown by
/// default so a missing composition-root override (tests that forget
/// to wire a fake, a build that forgets to preload
/// `SharedPreferences`) fails loudly instead of silently persisting
/// nothing.
final settingsStoreProvider = Provider<SettingsStore>((ref) {
  throw UnimplementedError(
    'settingsStoreProvider must be overridden in the composition '
    'root (lib/main.dart) after `SharedPreferences.getInstance()` '
    'completes, or in tests with a fake-backed SettingsStore.',
  );
});

/// Notifier that owns the user's chosen [AppThemeMode]. The initial
/// value is seeded from the injected [SettingsStore] on first build
/// so [MaterialApp] renders the correct theme on the very first
/// frame — no flash of wrong theme after launch.
///
/// Mutations go through [set], which updates the in-memory state
/// synchronously and fires a persistence write in the background.
/// The UI does not wait on disk I/O.
class ThemeModeController extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() {
    final store = ref.watch(settingsStoreProvider);
    return store.readAppThemeMode();
  }

  void set(AppThemeMode mode) {
    if (state == mode) {
      return;
    }
    state = mode;
    ref.read(settingsStoreProvider).writeAppThemeMode(mode).ignore();
  }
}

final themeModeControllerProvider =
    NotifierProvider<ThemeModeController, AppThemeMode>(
      ThemeModeController.new,
    );

/// Notifier that owns the user's chosen [AppLocale]. Mirrors
/// [ThemeModeController]'s shape so the composition root can
/// override them the same way.
class LocaleController extends Notifier<AppLocale> {
  @override
  AppLocale build() {
    final store = ref.watch(settingsStoreProvider);
    return store.readLocale();
  }

  void set(AppLocale locale) {
    if (state == locale) {
      return;
    }
    state = locale;
    ref.read(settingsStoreProvider).writeLocale(locale).ignore();
  }
}

final localeControllerProvider = NotifierProvider<LocaleController, AppLocale>(
  LocaleController.new,
);

/// Notifier that owns the user's [ReadingSettings]. The three
/// knobs (font scale, reading width cap, line height) live in
/// one notifier so a widget that cares about the reading layout
/// can rebuild once when any of them change, rather than three
/// times through three providers.
///
/// Mutations go through granular setters that short-circuit when
/// the incoming value matches the current state — `Slider`
/// callbacks fire continuously during a drag, and we do not
/// want to schedule a prefs write on every pointer event.
class ReadingSettingsController extends Notifier<ReadingSettings> {
  @override
  ReadingSettings build() {
    final store = ref.watch(settingsStoreProvider);
    return store.readReadingSettings();
  }

  void setFontScale(double value) {
    final clamped = value.clamp(
      ReadingSettings.minFontScale,
      ReadingSettings.maxFontScale,
    );
    if ((clamped - state.fontScale).abs() < 1e-6) return;
    state = state.copyWith(fontScale: clamped);
    ref.read(settingsStoreProvider).writeReadingSettings(state).ignore();
  }

  void setWidth(ReadingWidth width) {
    if (width == state.width) return;
    state = state.copyWith(width: width);
    ref.read(settingsStoreProvider).writeReadingSettings(state).ignore();
  }

  void setLineHeight(ReadingLineHeight lineHeight) {
    if (lineHeight == state.lineHeight) return;
    state = state.copyWith(lineHeight: lineHeight);
    ref.read(settingsStoreProvider).writeReadingSettings(state).ignore();
  }

  /// Restores all three reading knobs to [ReadingSettings.defaults].
  /// Used by the "Reset reading defaults" affordance in the
  /// reading panel and the settings screen.
  void resetToDefaults() {
    if (state.fontScale == ReadingSettings.defaults.fontScale &&
        state.width == ReadingSettings.defaults.width &&
        state.lineHeight == ReadingSettings.defaults.lineHeight) {
      return;
    }
    state = ReadingSettings.defaults;
    ref.read(settingsStoreProvider).writeReadingSettings(state).ignore();
  }
}

final readingSettingsControllerProvider =
    NotifierProvider<ReadingSettingsController, ReadingSettings>(
      ReadingSettingsController.new,
    );

/// Notifier that owns whether the screen should stay awake while
/// the viewer is open. Mutations are synchronous in-memory and fire
/// a background prefs write — same shape as the other controllers.
class KeepScreenOnController extends Notifier<bool> {
  @override
  bool build() {
    final store = ref.watch(settingsStoreProvider);
    return store.readKeepScreenOn();
  }

  void set(bool value) {
    if (state == value) return;
    state = value;
    ref.read(settingsStoreProvider).writeKeepScreenOn(value).ignore();
  }
}

final keepScreenOnControllerProvider =
    NotifierProvider<KeepScreenOnController, bool>(KeepScreenOnController.new);
