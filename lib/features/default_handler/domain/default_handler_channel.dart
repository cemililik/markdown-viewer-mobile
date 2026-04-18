/// Port for the platform-native "default handler" affordance shown
/// during onboarding.
///
/// Neither iOS nor Android exposes a programmatic API to claim the
/// "default app" role for arbitrary file types — that decision always
/// rests with the user. The best both platforms offer is deep-linking
/// the user into a system settings screen where the current defaults
/// are visible and can be cleared or re-assigned.
///
/// Implementations live in `data/` and are bound in `main.dart`.
abstract class DefaultHandlerChannel {
  /// Opens the platform screen where the user can manage which app
  /// handles `.md` files.
  ///
  /// - **Android**: `Settings.ACTION_APPLICATION_DETAILS_SETTINGS` for
  ///   the app's own package so the user can enter "Open by default"
  ///   and clear or re-assign the markdown associations.
  /// - **iOS**: no equivalent exists. Returns `false` without opening
  ///   anything; callers must hide the CTA on this platform.
  ///
  /// Returns `true` when a settings screen was launched, `false` when
  /// the platform has no suitable target or the launch failed.
  Future<bool> openDefaultHandlerSettings();
}
