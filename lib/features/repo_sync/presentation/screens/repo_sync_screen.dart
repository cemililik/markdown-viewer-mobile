import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:markdown_viewer/app/router.dart';
import 'package:markdown_viewer/core/errors/failure.dart';
import 'package:markdown_viewer/core/l10n/build_context_l10n.dart';
import 'package:markdown_viewer/core/logging/logger.dart';
import 'package:markdown_viewer/features/library/application/active_library_source_provider.dart';
import 'package:markdown_viewer/features/repo_sync/application/repo_sync_notifier.dart';
import 'package:markdown_viewer/features/repo_sync/application/repo_sync_providers.dart';
import 'package:markdown_viewer/features/repo_sync/domain/entities/sync_result.dart';

/// Full-page screen for syncing a remote git repository.
///
/// Layout:
/// 1. URL input — validated in real-time; sync button enabled only
///    when the URL is a recognisable GitHub shape.
/// 2. Optional PAT section — collapsed by default; expands when
///    the user taps "Need a token?".  The section contains a
///    security note and a how-to dialog link.
/// 3. Progress area — swaps between idle hint, spinner, and result.
///    The result card auto-dismisses after 4 seconds.
///
/// An optional [initialUrl] pre-populates the URL field, used when
/// the screen is opened from the library AppBar re-sync action or
/// the drawer long-press "Update" option.
class RepoSyncScreen extends ConsumerStatefulWidget {
  const RepoSyncScreen({super.key, this.initialUrl});

  final String? initialUrl;

  @override
  ConsumerState<RepoSyncScreen> createState() => _RepoSyncScreenState();
}

class _RepoSyncScreenState extends ConsumerState<RepoSyncScreen> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _patController = TextEditingController();
  bool _showPat = false;
  bool _urlValid = false;
  Timer? _resultTimer;

  static final _githubPattern = RegExp(
    r'^https://github\.com/[^/]+/[^/]+',
    caseSensitive: false,
  );

  @override
  void initState() {
    super.initState();
    if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      _urlController.text = widget.initialUrl!;
      _urlValid = _githubPattern.hasMatch(widget.initialUrl!.trim());
    }
  }

  @override
  void dispose() {
    _resultTimer?.cancel();
    _urlController.dispose();
    _patController.dispose();
    super.dispose();
  }

  void _onUrlChanged(String value) {
    final valid = _githubPattern.hasMatch(value.trim());
    if (valid != _urlValid) {
      setState(() => _urlValid = valid);
    }
  }

  Future<void> _startSync() async {
    final url = _urlController.text.trim();
    if (url.isEmpty || !_urlValid) return;

    final pat = _patController.text.trim();
    if (pat.isNotEmpty) {
      await ref.read(patStoreProvider).write(pat);
    }

    if (!mounted) return;
    await ref.read(repoSyncNotifierProvider.notifier).startSync(url);
  }

  Future<void> _clearPat() async {
    final logger = ref.read(appLoggerProvider);
    try {
      await ref.read(patStoreProvider).delete();
      _patController.clear();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.syncPatCleared)));
      }
    } on Object catch (e, st) {
      logger.e('Failed to clear PAT', error: e, stackTrace: st);
    }
  }

  void _showHowToDialog() {
    final l10n = context.l10n;
    showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(l10n.syncPatHowToTitle),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _HowToStep(number: 1, text: l10n.syncPatHowToStep1),
                  _HowToStep(number: 2, text: l10n.syncPatHowToStep2),
                  _HowToStep(number: 3, text: l10n.syncPatHowToStep3),
                  _HowToStep(number: 4, text: l10n.syncPatHowToStep4),
                  _HowToStep(number: 5, text: l10n.syncPatHowToStep5),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(dialogContext).colorScheme.primaryContainer,
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                    ),
                    child: Text(
                      l10n.syncPatHowToPermissionNote,
                      style: Theme.of(
                        dialogContext,
                      ).textTheme.bodySmall?.copyWith(
                        color:
                            Theme.of(
                              dialogContext,
                            ).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.syncPatHowToClose),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final syncState = ref.watch(repoSyncNotifierProvider);
    final isRunning =
        syncState is SyncDiscovering || syncState is SyncDownloading;

    // Auto-dismiss the result card after 4 seconds.
    ref.listen<RepoSyncState>(repoSyncNotifierProvider, (_, next) {
      if (next is SyncComplete) {
        _resultTimer?.cancel();
        _resultTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) {
            ref.read(repoSyncNotifierProvider.notifier).reset();
          }
        });
      } else {
        _resultTimer?.cancel();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navRepoSync),
        actions: [
          if (isRunning)
            TextButton(
              onPressed:
                  () => ref.read(repoSyncNotifierProvider.notifier).cancel(),
              child: Text(l10n.actionCancel),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── URL input ──────────────────────────────────────────
            TextField(
              controller: _urlController,
              onChanged: _onUrlChanged,
              enabled: !isRunning,
              keyboardType: TextInputType.url,
              autocorrect: false,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _urlValid ? _startSync() : null,
              decoration: InputDecoration(
                labelText: l10n.syncUrlHint,
                prefixIcon: const Icon(Icons.link),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // ── PAT toggle ─────────────────────────────────────────
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: Icon(
                  _showPat ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                ),
                label: Text(l10n.syncPatToggle),
                onPressed: () => setState(() => _showPat = !_showPat),
              ),
            ),

            if (_showPat) ...[
              const SizedBox(height: 4),
              TextField(
                controller: _patController,
                enabled: !isRunning,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.syncPatLabel,
                  hintText: l10n.syncPatHint,
                  prefixIcon: const Icon(Icons.key_outlined),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: l10n.syncPatClearButton,
                    onPressed: _clearPat,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.syncPatSubtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              _PatSecurityNote(onHowTo: _showHowToDialog),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 8),

            // ── Start button ───────────────────────────────────────
            FilledButton.icon(
              icon: const Icon(Icons.cloud_download_outlined),
              label: Text(l10n.syncStart),
              onPressed: (!isRunning && _urlValid) ? _startSync : null,
            ),

            const SizedBox(height: 32),

            // ── Progress / result area ─────────────────────────────
            _SyncStatusArea(syncState: syncState),
          ],
        ),
      ),
    );
  }
}

// ── Security note + how-to ─────────────────────────────────────────────────

class _PatSecurityNote extends StatelessWidget {
  const _PatSecurityNote({required this.onHowTo});

  final VoidCallback onHowTo;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.security_outlined, size: 16, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.syncPatSecurityNote,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onHowTo,
            child: Text(
              l10n.syncPatHowToButton,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.primary,
                decoration: TextDecoration.underline,
                decorationColor: scheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HowToStep extends StatelessWidget {
  const _HowToStep({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

// ── Status area ────────────────────────────────────────────────────────────

class _SyncStatusArea extends StatelessWidget {
  const _SyncStatusArea({required this.syncState});

  final RepoSyncState syncState;

  @override
  Widget build(BuildContext context) {
    return switch (syncState) {
      SyncIdle() => const SizedBox.shrink(),
      SyncDiscovering() => _StatusCard(
        icon: const CircularProgressIndicator.adaptive(strokeWidth: 2),
        message: context.l10n.syncDiscovering,
      ),
      SyncDownloading(:final current, :final total) => _DownloadCard(
        current: current,
        total: total,
      ),
      SyncComplete(:final result) => _ResultCard(result: result),
      SyncError(:final failure) => _ErrorCard(failure: failure),
    };
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.icon, required this.message});

  final Widget icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
      ),
      child: Row(
        children: [
          SizedBox(width: 24, height: 24, child: icon),
          const SizedBox(width: 16),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _DownloadCard extends StatelessWidget {
  const _DownloadCard({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final progress = total == 0 ? 0.0 : current / total;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.syncProgress(current, total),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            borderRadius: const BorderRadius.all(Radius.circular(4)),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends ConsumerWidget {
  const _ResultCard({required this.result});

  final SyncResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final isPartial = result.isPartial;
    final color =
        isPartial ? scheme.tertiaryContainer : scheme.primaryContainer;
    final onColor =
        isPartial ? scheme.onTertiaryContainer : scheme.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPartial
                    ? Icons.warning_amber_outlined
                    : Icons.check_circle_outline,
                color: onColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isPartial ? l10n.syncPartial : l10n.syncCompleted,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: onColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            result.isIncremental
                ? l10n.syncStatsIncremental(
                  result.downloadedCount,
                  result.skippedCount,
                )
                : l10n.syncFilesFound(result.syncedCount),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: onColor),
          ),
          const SizedBox(height: 16),
          // G — navigate to the synced repo in the library.
          Row(
            children: [
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: onColor.withValues(alpha: 0.15),
                  foregroundColor: onColor,
                ),
                onPressed: () {
                  ref
                      .read(activeLibrarySourceProvider.notifier)
                      .selectSyncedRepo(result.repo);
                  context.go(LibraryRoute.location());
                },
                child: Text(l10n.syncOpenInLibrary),
              ),
              const SizedBox(width: 8),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: onColor),
                onPressed:
                    () => ref.read(repoSyncNotifierProvider.notifier).reset(),
                child: Text(l10n.syncSyncAnotherButton),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends ConsumerWidget {
  const _ErrorCard({required this.failure});

  final Failure failure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final message = switch (failure) {
      NetworkUnavailableFailure() => l10n.errorNetworkUnavailable,
      RateLimitedFailure() => l10n.errorRateLimited,
      RepoNotFoundFailure() => l10n.errorRepoNotFound,
      _ => l10n.errorUnknown,
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: scheme.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed:
                () => ref.read(repoSyncNotifierProvider.notifier).reset(),
            child: Text(l10n.actionRetry),
          ),
        ],
      ),
    );
  }
}
