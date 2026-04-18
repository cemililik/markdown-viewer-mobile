package com.cemililik.markdown_viewer

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Platform side of the `com.cemililik.markdown_viewer/default_handler`
 * method channel used by the onboarding flow to nudge the user toward
 * making the app the default handler for `.md` files.
 *
 * Android does not expose a programmatic API to claim the default role
 * for an arbitrary file type — the user must pick "Always" on an
 * "Open with" dialog, or clear an existing default from
 * Settings → Apps → <app> → "Open by default". This channel opens the
 * per-app "Open by default" screen so the user can inspect or reset
 * their current associations in one tap.
 *
 * Falls back to the generic "Default apps" settings screen when the
 * per-app screen isn't exposed by the OEM — and to a plain `false`
 * result when neither intent resolves, so the Dart side can collapse
 * the CTA.
 */
class DefaultHandlerChannel : FlutterPlugin, ActivityAware {

    companion object {
        const val CHANNEL_NAME = "com.cemililik.markdown_viewer/default_handler"
    }

    private var channel: MethodChannel? = null
    private var activityBinding: ActivityPluginBinding? = null

    // MARK: - FlutterPlugin

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel?.setMethodCallHandler(::onMethodCall)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    // MARK: - ActivityAware

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activityBinding = binding
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding = null
    }

    override fun onDetachedFromActivity() {
        activityBinding = null
    }

    // MARK: - Method dispatch

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "openDefaultHandlerSettings" -> result.success(openSettings())
            else -> result.notImplemented()
        }
    }

    private fun openSettings(): Boolean {
        val activity = activityBinding?.activity ?: return false
        // Per-app "Open by default" — the only screen that lists the
        // specific MIME-type associations the user can clear.
        val perApp = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.fromParts("package", activity.packageName, null),
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (perApp.resolveActivity(activity.packageManager) != null &&
            tryStart(activity, perApp)
        ) {
            return true
        }
        // Rare OEM fallback — global default-apps picker.
        val global = Intent(Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (global.resolveActivity(activity.packageManager) != null &&
            tryStart(activity, global)
        ) {
            return true
        }
        return false
    }

    /**
     * Launches [intent] on [activity], swallowing the two exceptions
     * that can fire in the race window between
     * `PackageManager.resolveActivity` reporting a handler and the
     * OS actually routing the intent — the resolved activity can
     * disappear (package update / disabled component) and some OEMs
     * advertise system surfaces that reject third-party callers with
     * a `SecurityException`. In either case we return `false` so the
     * caller falls back to the next intent instead of letting the
     * exception cross the Flutter method-channel boundary.
     */
    private fun tryStart(
        activity: android.app.Activity,
        intent: Intent,
    ): Boolean {
        return try {
            activity.startActivity(intent)
            true
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: SecurityException) {
            false
        }
    }
}
