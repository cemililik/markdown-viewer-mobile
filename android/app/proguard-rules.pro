# ProGuard / R8 rules for MarkdownViewer release builds.
#
# Wired in via `buildTypes.release.proguardFiles(...)` in
# `android/app/build.gradle.kts`. Every keep rule below exists
# because the target symbol is accessed via reflection, native code,
# or an interop path that R8's static analysis cannot see — without
# the rule, a release build renames or strips the symbol and the
# dependency breaks at runtime.

# ── Flutter framework ────────────────────────────────────────────
# Flutter engine's JNI glue loads these symbols by name. The
# upstream Flutter tooling ships this as a best-practice default;
# keeping it here future-proofs us against engine revisions that
# touch new reflective call-sites. A single broad pattern covers
# every narrower `io.flutter.*.**` surface — kept that way so a
# future engine-internal package rename does not surprise us.
-keep class io.flutter.** { *; }

# ── Play Core (Flutter deferred components + Play Feature Delivery) ──
# Flutter's tree-shaking for assets and deferred loading leans on
# these entry points. Even if we don't ship feature modules, the
# Flutter engine still imports the classes and R8 flags them as
# missing without the explicit `dontwarn` directive.
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# ── Sentry ────────────────────────────────────────────────────────
# sentry-android reflects on session-replay and breadcrumb handlers
# so the SDK surface works without the consumer shipping every
# optional dependency. `@Keep`-annotated classes are kept; the wild-
# card guards the less-obvious reflective paths inside the native
# JNI bridge.
-keep class io.sentry.** { *; }
-keepnames class io.sentry.** { *; }
-keep class * implements io.sentry.IScopesStorage { *; }
-keepclassmembers class * {
    @io.sentry.** *;
}

# ── Drift (moor SQLite codegen) ──────────────────────────────────
# Drift generates reflective accessors for the DAOs; the moor_ffi
# bridge also loads native symbols by name.
-keep class com.simolus3.drift.** { *; }
-keep class com.simolus3.sqlite3_flutter_libs.** { *; }
-keep class io.github.simolus3.** { *; }

# ── OkHttp transitive (Play services auth / Sentry HTTP client) ──
# Both Sentry-Android and several Flutter network plugins transitively
# pull OkHttp. Its logging interceptor is lazily loaded by class name.
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn org.conscrypt.**
-keep class okhttp3.** { *; }

# ── Kotlin reflection / metadata ─────────────────────────────────
# kotlin-reflect is linked by several codegen libraries (json_serializable,
# freezed, drift). Keep Kotlin metadata so class-name reflection keeps
# working under R8's aggressive default.
-keep class kotlin.Metadata { *; }
-keepattributes *Annotation*,InnerClasses,Signature,EnclosingMethod

# ── Strip debug / verbose logs from release ──────────────────────
# android.util.Log.d/v are already conditionally gated by our own
# logger (docs/standards/observability-standards.md), but this
# directive removes the stubs as a defence-in-depth pass so nothing
# PII-adjacent survives into the release binary. `isLoggable` is
# deliberately *not* listed — third-party libraries guard branches
# on it (`if (Log.isLoggable(TAG, INFO)) expensiveCall()`), and
# collapsing the return value to the default would silently dead-
# strip those branches. Keeping isLoggable live costs a handful of
# call sites and avoids that footgun entirely.
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
}

# ── Our own app code ─────────────────────────────────────────────
# Dart-side lives entirely inside libflutter.so — nothing on the
# Kotlin side needs explicit keeps. Our MainActivity and
# MethodChannel plugin classes are referenced from the manifest
# and Flutter engine's plugin registrar, both of which R8 sees.
