import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:markdown_viewer/app/router.dart';
import 'package:markdown_viewer/core/errors/failure.dart';
import 'package:markdown_viewer/core/l10n/build_context_l10n.dart';
import 'package:markdown_viewer/core/widgets/error_view.dart';
import 'package:markdown_viewer/core/widgets/loading_view.dart';
import 'package:markdown_viewer/features/library/application/preview_extractor.dart';
import 'package:markdown_viewer/features/library/application/recent_documents_provider.dart';
import 'package:markdown_viewer/features/settings/application/settings_providers.dart';
import 'package:markdown_viewer/features/viewer/application/mermaid_renderer_provider.dart';
import 'package:markdown_viewer/features/viewer/application/pdf_extract.dart';
import 'package:markdown_viewer/features/viewer/application/reading_position_store_provider.dart';
import 'package:markdown_viewer/features/viewer/application/viewer_document.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/reading_position.dart';
import 'package:markdown_viewer/features/viewer/domain/services/mermaid_renderer.dart';
import 'package:markdown_viewer/features/viewer/presentation/failure_message_mapper.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/markdown_view.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/toc_drawer.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/viewer_reading_panel.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/viewer_search_bar.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';
import 'package:markdown_widget/markdown_widget.dart' show Toc;
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Screen that loads and renders a single markdown document.
///
/// Owns a [NestedScrollView] so the [SliverAppBar] can float in and
/// out as the user scrolls, giving the document the full viewport
/// height while reading. The inner scroll controller — obtained from
/// [NestedScrollViewState.innerController] after the first frame —
/// drives the back-to-top FAB, reading-position bookmark, and
/// in-document search jump.
///
/// On the first build of the data state the screen checks the
/// [ReadingPositionStore] for a saved position. If one exists the
/// scroll controller animates to that offset inside a post-frame
/// callback and a snackbar lets the user jump back to the top in
/// case the auto-restore was unwanted.
///
/// If the user has "Keep screen on" enabled in settings the screen
/// calls [WakelockPlus.enable] when it mounts and
/// [WakelockPlus.disable] when it disposes, so the display never
/// sleeps mid-read.
class ViewerScreen extends ConsumerStatefulWidget {
  const ViewerScreen({required this.documentId, super.key});

  final DocumentId documentId;

  @override
  ConsumerState<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends ConsumerState<ViewerScreen> {
  static const double _backToTopThreshold = 200;

  /// Key used to reach [NestedScrollViewState.innerController] after
  /// the first frame. The inner controller is what the back-to-top
  /// FAB, bookmark save/restore, and in-doc search all drive.
  final GlobalKey<NestedScrollViewState> _nestedKey = GlobalKey();

  /// Inner scroll controller, lazily obtained from [_nestedKey] in a
  /// post-frame callback scheduled from [initState]. Null until then.
  ScrollController? _scrollController;

  late final ValueNotifier<bool> _isBookmarked;
  bool _showBackToTop = false;
  bool _restoreAttempted = false;

  /// Previous scroll offset used to detect scroll direction for the
  /// immersive FAB hide — when the user is actively scrolling down
  /// past the back-to-top threshold the FAB slides away alongside
  /// the SliverAppBar.
  double _lastScrollOffset = 0;
  bool _isScrollingDown = false;

  /// GlobalKeys attached to each rendered block in the
  /// `markdown_widget` output. Keyed by `widgetIndex` — the
  /// same index space `markdown_widget` uses internally, not
  /// the parser-side block index. Grows lazily inside
  /// [MarkdownView.build] via `putIfAbsent`, so we do not need
  /// to know the final widget count ahead of time.
  ///
  /// The TOC drawer + in-doc search both look up keys here
  /// before driving `Scrollable.ensureVisible`.
  final Map<int, GlobalKey> _blockKeys = {};

  /// Maps each [HeadingRef] in the current document to the
  /// `widgetIndex` of its rendered widget inside
  /// `markdown_widget`'s output list. Populated on every
  /// [MarkdownView] build via the `onTocList` callback.
  ///
  /// This map replaces the old practice of reading
  /// `HeadingRef.blockIndex` (which comes from our own
  /// `MarkdownParser` and counts blocks in a different index
  /// space than `markdown_widget`'s render list). Because
  /// `markdown_widget` parses with `encodeHtml: false` + a
  /// private split regex while our parser uses
  /// `encodeHtml: true` + `LineSplitter`, the two block lists
  /// could diverge — headings further down the document would
  /// either silently fail to scroll (out-of-range lookup) or
  /// land on the wrong block.
  Map<HeadingRef, int> _headingToWidgetIndex = const {};

  /// In-document search state. `_searchActive` flips the AppBar
  /// title slot between the document basename and the
  /// [InDocSearchBar]; `_searchMatches` is a flat list of
  /// source character offsets that match the current query,
  /// used to drive the counter and prev/next chevrons; the
  /// text controller + focus node are owned here so the field
  /// survives rebuilds while the viewer loads more bytes.
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _searchActive = false;
  List<int> _searchMatches = const <int>[];
  int _currentMatchIndex = 0;

  @override
  void initState() {
    super.initState();
    // Defer inner controller setup to after the first frame so the
    // NestedScrollView is mounted and _nestedKey.currentState is
    // valid. The callback is registered before the first build, so
    // it always fires before any restore-position callback that
    // _maybeRestoreReadingPosition may schedule.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final inner = _nestedKey.currentState?.innerController;
      if (inner != null) {
        _scrollController = inner;
        inner.addListener(_onScroll);
      }
    });
    final saved = ref
        .read(readingPositionStoreProvider)
        .read(widget.documentId);
    _isBookmarked = ValueNotifier<bool>(saved != null);

    // Apply wakelock for the initial setting. A ref.listen in build
    // will handle subsequent changes while the screen is open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyWakelock(ref.read(keepScreenOnControllerProvider));
    });
  }

  void _applyWakelock(bool enabled) {
    if (enabled) {
      WakelockPlus.enable().ignore();
    } else {
      WakelockPlus.disable().ignore();
    }
  }

  void _onScroll() {
    final controller = _scrollController;
    if (controller == null || !controller.hasClients) return;
    final offset = controller.offset;

    final shouldShow = offset > _backToTopThreshold;
    // Hide the FAB when the user is actively scrolling down past
    // the threshold — it mimics the SliverAppBar.floating behaviour
    // so both chrome elements disappear together.
    final scrollingDown =
        offset > _lastScrollOffset && offset > _backToTopThreshold;
    _lastScrollOffset = offset;

    if (shouldShow != _showBackToTop || scrollingDown != _isScrollingDown) {
      setState(() {
        _showBackToTop = shouldShow;
        _isScrollingDown = scrollingDown;
      });
    }
  }

  @override
  void dispose() {
    // Remove the listener but do NOT dispose the controller — it is
    // owned by NestedScrollView, not by this state.
    _scrollController?.removeListener(_onScroll);
    _isBookmarked.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    // Always release the wakelock when leaving the viewer so the OS
    // can sleep normally again. Fire-and-forget is fine here.
    WakelockPlus.disable().ignore();
    super.dispose();
  }

  void _scrollToTop() {
    HapticFeedback.lightImpact().ignore();
    final controller = _scrollController;
    if (controller == null || !controller.hasClients) return;
    controller.animateTo(
      0,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  void _maybeRestoreReadingPosition() {
    if (_restoreAttempted) {
      return;
    }
    _restoreAttempted = true;
    final saved = ref
        .read(readingPositionStoreProvider)
        .read(widget.documentId);
    if (saved == null || saved.offset <= 0) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _scrollController?.hasClients != true) {
        return;
      }
      _animateToSavedPosition(saved);
      _showLocalizedSnackBar((l10n) => l10n.viewerResumedFromBookmark);
    });
  }

  /// Saves the current scroll offset as the reading-position
  /// bookmark, whether or not one already exists for this
  /// document. Tap semantics are deliberately "do what I mean":
  /// the user taps to say "remember where I am right now", and
  /// the button no longer acts as a toggle — removal is a
  /// long-press affordance handled by [_showBookmarkMenu].
  ///
  /// The snackbar wording reflects "saved for the first time on
  /// this document" vs "updated over a previous save" by checking
  /// the store before writing. A separate one-shot coach mark
  /// (`viewerBookmarkLongPressHint`) is appended the very first
  /// time the user ever saves a bookmark — across all
  /// documents — so they learn that long-press opens the remove
  /// menu, then never see the hint again.
  Future<void> _saveBookmark() async {
    HapticFeedback.mediumImpact().ignore();
    final store = ref.read(readingPositionStoreProvider);
    final settingsStore = ref.read(settingsStoreProvider);
    final hadPrevious = store.read(widget.documentId) != null;
    final controller = _scrollController;
    final offset =
        (controller != null && controller.hasClients) ? controller.offset : 0.0;
    await store.write(
      ReadingPosition(
        documentId: widget.documentId,
        offset: offset,
        savedAt: DateTime.now(),
      ),
    );
    _isBookmarked.value = true;
    if (!mounted) return;

    final firstEver = !settingsStore.readHasSeenBookmarkHint();
    if (firstEver) {
      settingsStore.markBookmarkHintSeen().ignore();
    }
    _showBookmarkSaveConfirmation(
      hadPrevious: hadPrevious,
      includeHint: firstEver,
    );
  }

  /// Shows the Save/Update confirmation snackbar. When
  /// [includeHint] is true a second line teaching the long-press
  /// remove affordance is appended and the duration bumps from
  /// 3 s to 5 s so the user has time to actually read it.
  void _showBookmarkSaveConfirmation({
    required bool hadPrevious,
    required bool includeHint,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: Duration(seconds: includeHint ? 5 : 3),
        content: Builder(
          builder: (context) {
            final l10n = context.l10n;
            final headline =
                hadPrevious
                    ? l10n.viewerBookmarkUpdated
                    : l10n.viewerBookmarkSaved;
            if (!includeHint) {
              return Text(headline);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(headline),
                const SizedBox(height: 4),
                Text(
                  l10n.viewerBookmarkLongPressHint,
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Opens the bookmark long-press bottom sheet with two
  /// actions: animate back to the saved position, or clear the
  /// saved position entirely. No-op when no bookmark has been
  /// saved yet — the sheet would only show a disabled "Go to"
  /// and a pointless "Remove", so we short-circuit with a
  /// single-line save snackbar instead, mirroring the tap path.
  Future<void> _showBookmarkMenu() async {
    final store = ref.read(readingPositionStoreProvider);
    final saved = store.read(widget.documentId);
    if (saved == null) {
      await _saveBookmark();
      return;
    }
    HapticFeedback.selectionClick().ignore();
    final choice = await showModalBottomSheet<_BookmarkMenuAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final l10n = sheetContext.l10n;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.bookmark_outlined),
                title: Text(l10n.viewerBookmarkMenuGoTo),
                onTap:
                    () => Navigator.of(
                      sheetContext,
                    ).pop(_BookmarkMenuAction.goTo),
              ),
              ListTile(
                leading: const Icon(Icons.bookmark_remove_outlined),
                title: Text(l10n.viewerBookmarkMenuRemove),
                onTap:
                    () => Navigator.of(
                      sheetContext,
                    ).pop(_BookmarkMenuAction.remove),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case _BookmarkMenuAction.goTo:
        _animateToSavedPosition(saved);
      case _BookmarkMenuAction.remove:
        await store.clear(widget.documentId);
        _isBookmarked.value = false;
        if (!mounted) return;
        _showLocalizedSnackBar((l10n) => l10n.viewerBookmarkCleared);
    }
  }

  /// Animates the scroll back to [position]. Shared by the
  /// long-press menu and the first-frame auto-restore so the
  /// two paths land on the same motion.
  void _animateToSavedPosition(ReadingPosition position) {
    final controller = _scrollController;
    if (controller == null || !controller.hasClients) return;
    final maxOffset = controller.position.maxScrollExtent;
    final target = position.offset.clamp(0.0, maxOffset);
    controller.animateTo(
      target,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }

  /// Handles `markdown_widget`'s `onTocList` callback by rebuilding
  /// [_headingToWidgetIndex] against the current document's heading
  /// list. Both lists walk the document in order, so the N-th entry
  /// in each corresponds to the same heading.
  ///
  /// This method is called synchronously from inside
  /// [MarkdownView.build] via the `onTocList` forwarding, so it
  /// MUST NOT call `setState` — mutating the map directly is fine
  /// because only `_scrollToHeading` reads it, and that happens on
  /// user interaction (long after the build completes).
  void _captureHeadingIndex(Document document, List<Toc> tocs) {
    if (tocs.isEmpty && _headingToWidgetIndex.isEmpty) return;
    final map = <HeadingRef, int>{};
    final headings = document.headings;
    final count = headings.length < tocs.length ? headings.length : tocs.length;
    for (var i = 0; i < count; i += 1) {
      map[headings[i]] = tocs[i].widgetIndex;
    }
    _headingToWidgetIndex = map;
  }

  /// Animates the scroll so the widget containing [heading] is
  /// pinned near the top of the viewport. Uses
  /// `Scrollable.ensureVisible` against the `GlobalKey` that
  /// `MarkdownView` attached to the matching block, so the jump
  /// is pixel-perfect without any offset measuring on our side.
  ///
  /// The lookup goes through [_headingToWidgetIndex] (populated on
  /// every `MarkdownView` build via `onTocList`) so the widget
  /// index matches `markdown_widget`'s internal block list rather
  /// than the parser's. Using `HeadingRef.blockIndex` directly
  /// would desync whenever the two parsers disagree on how to
  /// split the document — the bug that originally sent TOC taps
  /// to the wrong place (or to the top of the document).
  void _scrollToHeading(HeadingRef heading) {
    final widgetIndex = _headingToWidgetIndex[heading];
    if (widgetIndex == null) return;
    final key = _blockKeys[widgetIndex];
    final target = key?.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      // `alignment: 0` pins the heading at the top of the
      // visible area, mirroring how browser anchor navigation
      // feels.
      alignment: 0,
    );
  }

  /// Activates the bottom search bar and scrolls the SliverAppBar back
  /// into view so the document title stays visible while searching.
  void _openSearch() {
    setState(() {
      _searchActive = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Float the SliverAppBar back in so the reader always sees the
      // document title while the search bar is open at the bottom.
      _nestedKey.currentState?.outerController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
      _searchFocusNode.requestFocus();
    });
  }

  /// Closes the bottom search bar and resets all search state.
  void _closeSearch() {
    setState(() {
      _searchActive = false;
      _searchController.clear();
      _searchMatches = const <int>[];
      _currentMatchIndex = 0;
    });
    _searchFocusNode.unfocus();
  }

  /// Recomputes the match list for [query] against [document.source].
  /// Case-insensitive substring scan; auto-jumps to the first match.
  void _onSearchQueryChanged(String query, Document document) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _searchMatches = const <int>[];
        _currentMatchIndex = 0;
      });
      return;
    }
    final matches = <int>[];
    final lowerSource = document.source.toLowerCase();
    final lowerQuery = trimmed.toLowerCase();
    var index = lowerSource.indexOf(lowerQuery);
    while (index != -1) {
      matches.add(index);
      index = lowerSource.indexOf(lowerQuery, index + 1);
    }
    setState(() {
      _searchMatches = matches;
      _currentMatchIndex = 0;
    });
    if (matches.isNotEmpty) {
      _jumpToMatch(matches.first, document);
    }
  }

  /// Advances to the next match, wrapping around at the end.
  void _nextMatch(Document document) {
    if (_searchMatches.isEmpty) return;
    HapticFeedback.selectionClick().ignore();
    final nextIndex = (_currentMatchIndex + 1) % _searchMatches.length;
    setState(() => _currentMatchIndex = nextIndex);
    _jumpToMatch(_searchMatches[nextIndex], document);
  }

  /// Retreats to the previous match, wrapping around at the start.
  void _previousMatch(Document document) {
    if (_searchMatches.isEmpty) return;
    HapticFeedback.selectionClick().ignore();
    final prevIndex =
        (_currentMatchIndex - 1 + _searchMatches.length) %
        _searchMatches.length;
    setState(() => _currentMatchIndex = prevIndex);
    _jumpToMatch(_searchMatches[prevIndex], document);
  }

  /// Scrolls to an approximate offset based on the fraction of
  /// the matched position in the source.
  void _jumpToMatch(int sourceOffset, Document document) {
    final controller = _scrollController;
    if (controller == null || !controller.hasClients) return;
    final total = document.source.length;
    if (total == 0) return;
    final maxOffset = controller.position.maxScrollExtent;
    final fraction = sourceOffset / total;
    final target = (fraction * maxOffset).clamp(0.0, maxOffset);
    controller.animateTo(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  /// Routes a link tap from [MarkdownView].
  ///
  /// Anchor links (`#slug`) look up the matching [HeadingRef] and
  /// scroll to it via [_scrollToHeading]. All other hrefs are
  /// handed to the platform via [launchUrl] — `externalApplication`
  /// mode keeps the viewer open in the background on both iOS and
  /// Android.
  void _onLinkTap(String href, Document document) {
    if (href.startsWith('#')) {
      final slug = href.substring(1);
      final heading =
          document.headings.where((h) => h.anchor == slug).firstOrNull;
      if (heading != null) _scrollToHeading(heading);
      return;
    }
    final uri = Uri.tryParse(href);
    if (uri != null) {
      launchUrl(uri, mode: LaunchMode.externalApplication).ignore();
    }
  }

  /// Shows a bottom sheet that lets the user choose between sharing the
  /// raw markdown source or exporting a PDF via the platform share sheet.
  void _showShareMenu(Document document) {
    final l10n = context.l10n;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    l10n.viewerShareMenuTitle,
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.text_snippet_outlined),
                  title: Text(l10n.viewerShareMenuText),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _shareAsText(document);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf_outlined),
                  title: Text(l10n.viewerShareMenuPdf),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _shareAsPdf(document);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _shareAsText(Document document) {
    final fallbackTitle = _titleFor(widget.documentId, '');
    // Prefer the document's first H1 so hash-based filenames
    // (files opened via share-intent) get a meaningful subject.
    final title = extractPdfTitle(document.source, fallbackTitle);
    SharePlus.instance.share(
      ShareParams(text: document.source, subject: title),
    );
  }

  Future<void> _shareAsPdf(Document document) async {
    final l10n = context.l10n;
    _showLocalizedSnackBar((_) => l10n.viewerPdfGenerating);
    try {
      final fallbackTitle = _titleFor(widget.documentId, '');
      final prerendered = await _prerenderMermaidDiagrams(document.source);
      if (!mounted) return;
      final bytes = await exportToPdf(
        fallbackTitle,
        document.source,
        mermaidImages: prerendered.images,
        mermaidErrors: prerendered.errors,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      // Prefer the document's H1 as the filename so hash-based filenames
      // (e.g. files opened via share-intent) get a meaningful PDF name.
      final displayTitle = extractPdfTitle(document.source, fallbackTitle);
      // Strip characters that are invalid in filenames on iOS / Android.
      final safeName =
          displayTitle
              .replaceAll(RegExp(r'\.(md|markdown)$', caseSensitive: false), '')
              .replaceAll(RegExp(r'[<>:"/\\|?*]'), '-')
              .trim();
      await Printing.sharePdf(bytes: bytes, filename: '$safeName.pdf');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showLocalizedSnackBar((_) => l10n.viewerPdfError);
    }
  }

  /// Scans [source] for mermaid fenced code blocks and renders each
  /// unique diagram through [mermaidRendererProvider], returning a
  /// record of `(images, errors)` keyed by trimmed diagram source.
  /// Diagrams that render successfully populate `images`; diagrams
  /// that fail populate `errors` with the renderer's diagnostic
  /// message so the PDF placeholder can surface the reason instead
  /// of dropping the information on the floor.
  Future<({Map<String, Uint8List> images, Map<String, String> errors})>
  _prerenderMermaidDiagrams(String source) async {
    final codes = extractMermaidCodes(source);
    if (codes.isEmpty) {
      return (images: <String, Uint8List>{}, errors: <String, String>{});
    }

    final renderer = ref.read(mermaidRendererProvider);
    final images = <String, Uint8List>{};
    final errors = <String, String>{};
    // Minimal per-diagram init directive: `look: 'classic'` matches the
    // global `mermaid.initialize` call and keeps the PDF render path in
    // its own LRU cache slot (distinct from the viewer's Material-3
    // themed renders). No theme override — Mermaid's default theme
    // renders cleanly on a white PDF page.
    //
    // Suppressed when the diagram already carries its own %%{init:...}%%
    // directive — user intent wins, matching the MermaidBlock widget's
    // _sourceHasOwnDirective behaviour.
    const pdfInit = '%%{init: {"look": "classic"}}%%\n';
    for (final code in codes) {
      final hasOwnDirective = code.trimLeft().startsWith('%%{init:');
      final r = await renderer.render(
        code,
        initDirective: hasOwnDirective ? '' : pdfInit,
      );
      if (r is MermaidRenderSuccess) {
        images[code] = r.pngBytes;
      } else if (r is MermaidRenderFailure) {
        errors[code] = r.message;
      }
    }
    return (images: images, errors: errors);
  }

  /// Shows a snackbar whose content reads its localized string on
  /// every rebuild.
  void _showLocalizedSnackBar(String Function(AppLocalizations l10n) resolve) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Builder(builder: (context) => Text(resolve(context.l10n))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // Keep wakelock in sync if the user changes the setting
    // while the viewer is open.
    ref.listen<bool>(keepScreenOnControllerProvider, (_, keep) {
      _applyWakelock(keep);
    });

    ref.listen<AsyncValue<Document>>(
      viewerDocumentProvider(widget.documentId),
      (previous, next) {
        next.whenData((document) {
          ref
              .read(recentDocumentsControllerProvider.notifier)
              .touch(
                widget.documentId,
                preview: extractPreviewSnippet(document.source),
              );
        });
      },
    );

    final async = ref.watch(viewerDocumentProvider(widget.documentId));
    final readingSettings = ref.watch(readingSettingsControllerProvider);
    final recents = ref.watch(recentDocumentsControllerProvider);
    String? recentDisplayName;
    for (final entry in recents) {
      if (entry.documentId.value == widget.documentId.value) {
        recentDisplayName = entry.displayName;
        break;
      }
    }

    final dataDocument = async.asData?.value;

    return Scaffold(
      endDrawer:
          dataDocument == null
              ? null
              : TocDrawer(
                document: dataDocument,
                onHeadingSelected: _scrollToHeading,
              ),
      // `IgnorePointer` guard because `AnimatedScale(scale: 0)` still
      // participates in hit-testing at its original bounds — without
      // the guard, invisible taps near the bottom-right of the
      // viewport would fire `_scrollToTop` even when the FAB is not
      // supposed to be there. The FAB also hides while scrolling down
      // to complement the SliverAppBar.floating immersive behaviour.
      floatingActionButton: IgnorePointer(
        ignoring: !_showBackToTop || _isScrollingDown,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          scale: (_showBackToTop && !_isScrollingDown) ? 1 : 0,
          child: FloatingActionButton.small(
            tooltip: l10n.viewerBackToTopTooltip,
            onPressed: _scrollToTop,
            child: const Icon(Icons.arrow_upward),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: NestedScrollView(
        key: _nestedKey,
        // `floatHeaderSlivers: true` is required so the SliverAppBar
        // can overlay the body scroll view when it floats back in —
        // without it the body would shift down to make room, causing
        // a visible layout jump on every show/hide cycle.
        floatHeaderSlivers: true,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              floating: true,
              snap: true,
              // Explicit leading: on a push-navigated viewer the
              // default back button already shows, but deep links
              // land with an empty stack — `canPop` falls through
              // to the library.
              leading: BackButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(LibraryRoute.location());
                  }
                },
              ),
              title: Text(
                recentDisplayName ??
                    _titleFor(widget.documentId, l10n.viewerUnnamedDocument),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.share_outlined),
                  tooltip: l10n.viewerShareTooltip,
                  onPressed:
                      dataDocument == null
                          ? null
                          : () => _showShareMenu(dataDocument),
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: l10n.viewerSearchOpenTooltip,
                  onPressed: dataDocument == null ? null : _openSearch,
                ),
                Builder(
                  builder:
                      (context) => IconButton(
                        icon: const Icon(Icons.format_list_bulleted),
                        tooltip: l10n.viewerTocOpenTooltip,
                        onPressed:
                            dataDocument == null
                                ? null
                                : () => Scaffold.of(context).openEndDrawer(),
                      ),
                ),
                IconButton(
                  icon: const Icon(Icons.text_format),
                  tooltip: l10n.viewerReadingPanelOpenTooltip,
                  onPressed:
                      dataDocument == null
                          ? null
                          : () => showViewerReadingPanel(context),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: _isBookmarked,
                  builder: (context, bookmarked, _) {
                    return Tooltip(
                      message: l10n.viewerBookmarkSaveTooltip,
                      child: Semantics(
                        button: true,
                        onLongPressHint: l10n.viewerBookmarkLongPressHint,
                        child: InkResponse(
                          onTap: _saveBookmark,
                          onLongPress: _showBookmarkMenu,
                          radius: 24,
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: Icon(
                              bookmarked
                                  ? Icons.bookmark
                                  : Icons.bookmark_outline,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ];
        },
        body: async.when(
          loading: () => LoadingView(label: l10n.viewerLoading),
          error: (error, stackTrace) {
            final failure =
                error is Failure
                    ? error
                    : UnknownFailure(
                      message: 'Unexpected error in viewer',
                      cause: error,
                    );
            return ErrorView(
              message: mapFailureToViewerMessage(failure, l10n),
              retryLabel: l10n.actionRetry,
              onRetry:
                  () =>
                      ref.invalidate(viewerDocumentProvider(widget.documentId)),
            );
          },
          data: (document) {
            _maybeRestoreReadingPosition();
            final queryLength = _searchController.text.trim().length;
            return Column(
              children: [
                Expanded(
                  // controller: null → SingleChildScrollView inside
                  // MarkdownView uses the primary scroll controller
                  // that NestedScrollView injects, coordinating body
                  // scroll with the floating SliverAppBar.
                  child: MarkdownView(
                    document: document,
                    controller: null,
                    blockKeys: _blockKeys,
                    readingSettings: readingSettings,
                    onLinkTap: (href) => _onLinkTap(href, document),
                    // `onTocList` fires synchronously from inside
                    // `MarkdownGenerator.buildWidgets`. The handler
                    // mutates `_headingToWidgetIndex` directly
                    // (no `setState`) because the map is read by
                    // `_scrollToHeading` on user interaction, not
                    // during the build — rebuilding here would
                    // provoke a setState-during-build exception.
                    onTocList: (tocs) => _captureHeadingIndex(document, tocs),
                    searchHighlight:
                        (_searchActive && _searchMatches.isNotEmpty)
                            ? SearchHighlightState(
                              matchOffsets: _searchMatches,
                              queryLength: queryLength,
                              currentMatchIndex: _currentMatchIndex,
                            )
                            : null,
                  ),
                ),
                // AnimatedSize drives the slide-in / slide-out of the
                // bottom search bar. Height collapses to zero when
                // search is inactive so the document fills the full
                // viewport; expands to the bar's natural height when
                // the user opens search.
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child:
                      _searchActive
                          ? ViewerSearchBar(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            matchCount: _searchMatches.length,
                            currentMatchIndex: _currentMatchIndex,
                            onQueryChanged:
                                (q) => _onSearchQueryChanged(q, document),
                            onPrevious: () => _previousMatch(document),
                            onNext: () => _nextMatch(document),
                            onClose: _closeSearch,
                          )
                          : const SizedBox.shrink(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _titleFor(DocumentId id, String fallback) {
    final basename = p.basename(id.value);
    return basename.isEmpty ? fallback : basename;
  }
}

/// Two-entry menu surfaced by the bookmark long-press.
enum _BookmarkMenuAction { goTo, remove }
