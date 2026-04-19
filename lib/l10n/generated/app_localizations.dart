import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
  ];

  /// The application name shown in the launcher and app bar.
  ///
  /// In en, this message translates to:
  /// **'Markdown Viewer'**
  String get appTitle;

  /// Bottom navigation label for the library / recent files screen.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get navLibrary;

  /// Bottom navigation label for the settings screen.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// Bottom navigation label for the repository sync screen.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get navRepoSync;

  /// Heading shown when the user has cleared their recents but still has folder or repo sources available.
  ///
  /// In en, this message translates to:
  /// **'No recent documents'**
  String get libraryRecentsEmptyTitle;

  /// Subtitle beneath libraryRecentsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Browse a saved source or open a new file.'**
  String get libraryRecentsEmptySubtitle;

  /// Section header above the list of saved sources in the recents-empty-with-sources state.
  ///
  /// In en, this message translates to:
  /// **'Your sources'**
  String get libraryRecentsEmptySources;

  /// Title shown when the library has no files.
  ///
  /// In en, this message translates to:
  /// **'No documents yet'**
  String get libraryEmptyTitle;

  /// Body shown beneath libraryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Open a markdown file or sync a repository to get started.'**
  String get libraryEmptyMessage;

  /// Section header above the list of recently opened markdown documents on the library home screen.
  ///
  /// In en, this message translates to:
  /// **'Recent documents'**
  String get libraryRecentTitle;

  /// Action shown next to the Recent documents section header that wipes the recent list.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get libraryRecentClearAll;

  /// Title of the confirmation dialog before wiping the entire recent documents list.
  ///
  /// In en, this message translates to:
  /// **'Clear recent documents?'**
  String get libraryRecentClearConfirmTitle;

  /// Body of the confirmation dialog before wiping the entire recent documents list.
  ///
  /// In en, this message translates to:
  /// **'This removes every entry from the Recent documents list. The files themselves are not deleted.'**
  String get libraryRecentClearConfirmBody;

  /// Long-press / context menu action to remove a single document from the Recent documents list.
  ///
  /// In en, this message translates to:
  /// **'Remove from recents'**
  String get libraryRecentRemove;

  /// Snackbar shown after a single recent document entry is removed.
  ///
  /// In en, this message translates to:
  /// **'Removed from recents'**
  String get libraryRecentRemoved;

  /// Snackbar shown when the user taps a recent document whose underlying file no longer exists.
  ///
  /// In en, this message translates to:
  /// **'This file is no longer available — removed from recents.'**
  String get libraryRecentFileMissing;

  /// Relative time label for documents opened less than a minute ago.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get libraryRecentJustNow;

  /// Plural relative time label for documents opened a few minutes ago.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute ago} other{{count} minutes ago}}'**
  String libraryRecentMinutesAgo(int count);

  /// Plural relative time label for documents opened a few hours ago.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour ago} other{{count} hours ago}}'**
  String libraryRecentHoursAgo(int count);

  /// Relative time label for documents opened roughly one day ago.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get libraryRecentYesterday;

  /// Plural relative time label for documents opened several days ago.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} days ago}}'**
  String libraryRecentDaysAgo(int count);

  /// Fallback relative time label for documents opened more than a week ago.
  ///
  /// In en, this message translates to:
  /// **'A while back'**
  String get libraryRecentLongAgo;

  /// Library home screen greeting shown between 05:00 and 11:59 local time.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get libraryGreetingMorning;

  /// Library home screen greeting shown between 12:00 and 17:59 local time.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get libraryGreetingAfternoon;

  /// Library home screen greeting shown between 18:00 and 04:59 local time.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get libraryGreetingEvening;

  /// Library greeting subtitle shown when the user has never opened a document.
  ///
  /// In en, this message translates to:
  /// **'No recent documents yet'**
  String get libraryGreetingSubtitleEmpty;

  /// Library greeting subtitle showing the number of recent documents.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 recent document} other{{count} recent documents}}'**
  String libraryGreetingSubtitle(int count);

  /// Placeholder shown inside the library search field.
  ///
  /// In en, this message translates to:
  /// **'Search recents'**
  String get librarySearchHint;

  /// Tooltip on the clear-search icon inside the library search field.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get librarySearchClear;

  /// Empty state shown below the search field when the current query matches zero recents.
  ///
  /// In en, this message translates to:
  /// **'No matching documents'**
  String get librarySearchNoResults;

  /// Section header shown above the content-search hits below the name-match list. Distinguishes 'match inside a file' results from filename matches.
  ///
  /// In en, this message translates to:
  /// **'In document contents'**
  String get libraryContentSearchHeader;

  /// Empty state shown under the library search field when the name search returned nothing AND the cross-library full-text scan also returned nothing.
  ///
  /// In en, this message translates to:
  /// **'No matches in any document'**
  String get libraryContentSearchEmpty;

  /// Loading label shown while the debounced cross-library full-text search is running inside its compute() isolate.
  ///
  /// In en, this message translates to:
  /// **'Scanning documents…'**
  String get libraryContentSearchLoading;

  /// Badge on a content-search result tile showing the total number of matches for the active query inside that single document.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 match} other{{count} matches}}'**
  String libraryContentSearchMoreMatches(int count);

  /// Badge label on a content-search result that came from the user's recent-documents list.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get libraryContentSearchSourceRecent;

  /// Badge label on a content-search result that came from a library-registered folder source.
  ///
  /// In en, this message translates to:
  /// **'Folder: {name}'**
  String libraryContentSearchSourceFolder(String name);

  /// Badge label on a content-search result that came from a synced GitHub repository.
  ///
  /// In en, this message translates to:
  /// **'Repo: {name}'**
  String libraryContentSearchSourceRepo(String name);

  /// Snackbar shown when a pull-to-refresh against a folder or synced-repo source fails — e.g. the bookmark went stale, network dropped, or the GitHub API returned an error mid-sync.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh this source. Try again.'**
  String get libraryRefreshFailed;

  /// Semantics label announced by screen readers (VoiceOver / TalkBack) while the pull-to-refresh spinner is active on any library surface (Recents, folder, synced repo).
  ///
  /// In en, this message translates to:
  /// **'Refresh library'**
  String get libraryRefreshSemantic;

  /// Snackbar shown when the OS hands us a share-intent or Open-In file that exceeds the per-file 10 MB cap enforced by FileOpenChannel on both platforms. The native side returns a FILE_TOO_LARGE error code and the Dart listener in app.dart surfaces this localised message so the user knows why the share tap appeared to do nothing.
  ///
  /// In en, this message translates to:
  /// **'File too large to open.'**
  String get fileOpenTooLarge;

  /// Header above the section holding user-pinned recent documents.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get libraryRecentPinnedSection;

  /// Group header for documents opened on the current calendar day.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get libraryRecentGroupToday;

  /// Group header for documents opened on the previous calendar day.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get libraryRecentGroupYesterday;

  /// Group header for documents opened within the last seven days but not today or yesterday.
  ///
  /// In en, this message translates to:
  /// **'Earlier this week'**
  String get libraryRecentGroupThisWeek;

  /// Group header for documents opened more than a week ago.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get libraryRecentGroupEarlier;

  /// Long-press / context menu action to pin a recent document to the top of the library.
  ///
  /// In en, this message translates to:
  /// **'Pin to top'**
  String get libraryRecentPin;

  /// Long-press / context menu action to unpin a previously pinned recent document.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get libraryRecentUnpin;

  /// Snackbar shown after a recent document is pinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned to top'**
  String get libraryRecentPinnedSnack;

  /// Snackbar shown after a pinned recent document is unpinned.
  ///
  /// In en, this message translates to:
  /// **'Removed pin'**
  String get libraryRecentUnpinnedSnack;

  /// Header of the folder explorer drawer slid in from the left of the library home screen.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get libraryFoldersDrawerTitle;

  /// Action that opens the platform directory picker to add a new library root.
  ///
  /// In en, this message translates to:
  /// **'Add folder'**
  String get libraryFoldersAdd;

  /// Title shown inside the folder explorer drawer when the user has not added any library roots.
  ///
  /// In en, this message translates to:
  /// **'No folders yet'**
  String get libraryFoldersEmptyTitle;

  /// Body shown inside the folder explorer drawer beneath libraryFoldersEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a folder of markdown files to browse them here.'**
  String get libraryFoldersEmptyMessage;

  /// Tooltip on the AppBar hamburger that opens the folder explorer drawer.
  ///
  /// In en, this message translates to:
  /// **'Open folders'**
  String get libraryFoldersOpenDrawerTooltip;

  /// Snackbar shown after the user picks a directory to add as a library root.
  ///
  /// In en, this message translates to:
  /// **'Folder added'**
  String get libraryFoldersAddedSnack;

  /// Snackbar shown after the user removes a library root from the drawer.
  ///
  /// In en, this message translates to:
  /// **'Folder removed'**
  String get libraryFoldersRemovedSnack;

  /// Long-press / context menu action to remove a library root from the drawer.
  ///
  /// In en, this message translates to:
  /// **'Remove folder'**
  String get libraryFoldersRemove;

  /// Snackbar shown when the directory picker is dismissed without a selection.
  ///
  /// In en, this message translates to:
  /// **'Folder selection cancelled'**
  String get libraryFoldersAddCancelled;

  /// Snackbar shown when the platform directory picker fails to open.
  ///
  /// In en, this message translates to:
  /// **'Could not open the folder picker. Please try again.'**
  String get libraryFoldersAddFailed;

  /// Snackbar shown when the user tries to add a directory that is already a library root.
  ///
  /// In en, this message translates to:
  /// **'This folder is already in the library.'**
  String get libraryFoldersAlreadyAdded;

  /// Inline label shown inside an expanded folder when listing its contents fails.
  ///
  /// In en, this message translates to:
  /// **'Could not read this folder.'**
  String get libraryFoldersEnumerationFailed;

  /// Inline label shown inside an expanded folder when the directory holds no markdown files or subfolders.
  ///
  /// In en, this message translates to:
  /// **'No markdown files in this folder'**
  String get libraryFoldersEmptyFolder;

  /// Speed dial entry that opens the platform file picker.
  ///
  /// In en, this message translates to:
  /// **'Open file'**
  String get libraryActionMenuOpenFile;

  /// Speed dial entry that opens the platform directory picker and adds the result as a library root.
  ///
  /// In en, this message translates to:
  /// **'Open folder'**
  String get libraryActionMenuOpenFolder;

  /// Speed dial entry that triggers the repo sync flow (Phase 4.5 — currently disabled).
  ///
  /// In en, this message translates to:
  /// **'Sync repository'**
  String get libraryActionMenuSyncRepo;

  /// Tooltip on the populated-state plus FAB that expands the speed dial menu.
  ///
  /// In en, this message translates to:
  /// **'Add documents'**
  String get libraryActionMenuTooltip;

  /// Tooltip on the populated-state FAB while the speed dial menu is open.
  ///
  /// In en, this message translates to:
  /// **'Close menu'**
  String get libraryActionMenuCloseTooltip;

  /// Drawer entry that switches the library body back to the time-grouped recents view.
  ///
  /// In en, this message translates to:
  /// **'Recents'**
  String get librarySourceRecents;

  /// Section header inside the drawer above the list of user-added folders (and future synced repositories).
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get librarySourceSectionHeader;

  /// Drawer bottom button that opens the Add source bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'Add source'**
  String get libraryAddSourceButton;

  /// Title of the Add source bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'Add a new source'**
  String get libraryAddSourceSheetTitle;

  /// Placeholder inside the folder source search field. Scoped to the active folder's name so the user knows the search is not over the whole library.
  ///
  /// In en, this message translates to:
  /// **'Search in {folderName}'**
  String libraryFolderSourceSearchHint(String folderName);

  /// Empty state shown inside the folder source body when the folder has no markdown files at any depth.
  ///
  /// In en, this message translates to:
  /// **'This folder has no markdown files'**
  String get libraryFolderSourceEmpty;

  /// Error state shown inside the folder source body when enumerating the folder throws.
  ///
  /// In en, this message translates to:
  /// **'Could not read this folder. Check that it still exists on disk.'**
  String get libraryFolderSourceError;

  /// Empty state shown inside the folder source body when a recursive search query matches no files.
  ///
  /// In en, this message translates to:
  /// **'No matching files in {folderName}'**
  String libraryFolderSourceSearchNoResults(String folderName);

  /// Loading label shown while the folder source recursively walks its directory tree for the first time.
  ///
  /// In en, this message translates to:
  /// **'Scanning folder…'**
  String get libraryFolderSourceSearchLoading;

  /// Subtitle beneath the Add folder tile in the Add source bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'Add a directory from this device'**
  String get libraryAddSourceFolderSubtitle;

  /// Subtitle beneath the Sync repository tile in the Add source bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'Pull markdown files from a git repository'**
  String get libraryAddSourceRepoSubtitle;

  /// Button label that opens a file picker on the device.
  ///
  /// In en, this message translates to:
  /// **'Open file'**
  String get actionOpenFile;

  /// Button label that starts the repo sync flow.
  ///
  /// In en, this message translates to:
  /// **'Sync repository'**
  String get actionSyncRepo;

  /// Generic cancel button label.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// Generic retry button label, e.g. on an error screen.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// Section title for the theme selector in settings.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsThemeTitle;

  /// Label of the 'light' option in the theme selector on the settings screen.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// Label of the 'dark' option in the theme selector on the settings screen.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// Option in the theme selector that follows the OS light/dark preference.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// Option in the theme selector that applies a warm parchment colour scheme.
  ///
  /// In en, this message translates to:
  /// **'Sepia'**
  String get settingsThemeSepia;

  /// Section title for the language selector in settings.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageTitle;

  /// Option in the language selector that follows the OS language.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsLanguageSystem;

  /// Label for the English option in the settings language selector.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// Label for the Turkish option in the settings language selector.
  ///
  /// In en, this message translates to:
  /// **'Turkish'**
  String get settingsLanguageTurkish;

  /// Section title for the reading font size selector.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get settingsFontSizeTitle;

  /// Title of the table of contents drawer.
  ///
  /// In en, this message translates to:
  /// **'Contents'**
  String get viewerTocTitle;

  /// Placeholder text in the in-document search field.
  ///
  /// In en, this message translates to:
  /// **'Search in document'**
  String get viewerSearchHint;

  /// Title shown on an admonition rendered from a GitHub alert of kind `note`, e.g. `> [!NOTE]`.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get admonitionNoteTitle;

  /// Title shown on an admonition rendered from a GitHub alert of kind `tip`.
  ///
  /// In en, this message translates to:
  /// **'Tip'**
  String get admonitionTipTitle;

  /// Title shown on an admonition rendered from a GitHub alert of kind `important`.
  ///
  /// In en, this message translates to:
  /// **'Important'**
  String get admonitionImportantTitle;

  /// Title shown on an admonition rendered from a GitHub alert of kind `warning`.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get admonitionWarningTitle;

  /// Title shown on an admonition rendered from a GitHub alert of kind `caution`.
  ///
  /// In en, this message translates to:
  /// **'Caution'**
  String get admonitionCautionTitle;

  /// Semantic label and placeholder text shown while a mermaid diagram is being rendered by the sandboxed WebView.
  ///
  /// In en, this message translates to:
  /// **'Rendering diagram…'**
  String get mermaidLoading;

  /// Title of the inline error placeholder shown when a mermaid diagram fails to render (parse error, missing asset, sandbox failure).
  ///
  /// In en, this message translates to:
  /// **'Diagram could not be rendered'**
  String get mermaidRenderErrorTitle;

  /// Body of the inline error placeholder shown when a mermaid diagram fails to render.
  ///
  /// In en, this message translates to:
  /// **'Check the diagram syntax and try again.'**
  String get mermaidRenderErrorBody;

  /// Tooltip / semantic label for the button that resets a panned or zoomed mermaid diagram back to its default position.
  ///
  /// In en, this message translates to:
  /// **'Reset view'**
  String get mermaidReset;

  /// Tooltip on the expand icon overlaid on each rendered Mermaid diagram. Tapping it pushes the dedicated fullscreen viewer.
  ///
  /// In en, this message translates to:
  /// **'Open fullscreen'**
  String get diagramFullscreenOpenTooltip;

  /// Tooltip / aria-label on the close (X) button in the Mermaid fullscreen viewer top bar.
  ///
  /// In en, this message translates to:
  /// **'Close fullscreen'**
  String get diagramFullscreenCloseTooltip;

  /// Semantic label for a successfully rendered mermaid diagram image, announced by screen readers.
  ///
  /// In en, this message translates to:
  /// **'Mermaid diagram. Pinch to zoom, drag to pan.'**
  String get mermaidDiagramLabel;

  /// Reading-time estimate shown at the top of the document content. Always shows at least 1 min.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min read'**
  String viewerReadingTime(int minutes);

  /// Tooltip for the floating action button that scrolls a markdown document back to the very top.
  ///
  /// In en, this message translates to:
  /// **'Back to top'**
  String get viewerBackToTopTooltip;

  /// Tooltip for the viewer AppBar bookmark action. Tapping it always writes the current scroll offset, whether a prior position was saved or not; the long-press menu handles removal.
  ///
  /// In en, this message translates to:
  /// **'Save or update reading position'**
  String get viewerBookmarkSaveTooltip;

  /// Snackbar confirmation shown after the user saves a bookmark at the current scroll position for the first time in a document.
  ///
  /// In en, this message translates to:
  /// **'Reading position saved'**
  String get viewerBookmarkSaved;

  /// Snackbar confirmation shown when the user taps bookmark on a document that already had a saved position, so the save acts as an update rather than a first write.
  ///
  /// In en, this message translates to:
  /// **'Reading position updated'**
  String get viewerBookmarkUpdated;

  /// Snackbar confirmation shown after the user clears a previously saved bookmark via the long-press menu.
  ///
  /// In en, this message translates to:
  /// **'Bookmark cleared'**
  String get viewerBookmarkCleared;

  /// Secondary coach-mark line appended to the first-ever bookmark save confirmation, teaching the user that long-press opens an options menu.
  ///
  /// In en, this message translates to:
  /// **'Long-press the bookmark icon for options.'**
  String get viewerBookmarkLongPressHint;

  /// Bottom sheet action that animates the scroll back to the previously saved reading position.
  ///
  /// In en, this message translates to:
  /// **'Go to saved position'**
  String get viewerBookmarkMenuGoTo;

  /// Bottom sheet action that clears the saved reading position for the active document.
  ///
  /// In en, this message translates to:
  /// **'Remove bookmark'**
  String get viewerBookmarkMenuRemove;

  /// Tooltip on the viewer AppBar share action.
  ///
  /// In en, this message translates to:
  /// **'Share document'**
  String get viewerShareTooltip;

  /// Title of the bottom sheet that lets the user choose how to share the document.
  ///
  /// In en, this message translates to:
  /// **'Share as…'**
  String get viewerShareMenuTitle;

  /// Option in the share menu that shares the raw markdown source.
  ///
  /// In en, this message translates to:
  /// **'Share as text'**
  String get viewerShareMenuText;

  /// Option in the share menu that converts the document to PDF and opens the share sheet.
  ///
  /// In en, this message translates to:
  /// **'Export as PDF'**
  String get viewerShareMenuPdf;

  /// Snackbar message shown while the PDF is being generated.
  ///
  /// In en, this message translates to:
  /// **'Generating PDF…'**
  String get viewerPdfGenerating;

  /// Snackbar message shown when PDF generation fails.
  ///
  /// In en, this message translates to:
  /// **'Could not generate PDF. Please try again.'**
  String get viewerPdfError;

  /// Tooltip on the viewer AppBar action that opens the right-side TOC drawer.
  ///
  /// In en, this message translates to:
  /// **'Table of contents'**
  String get viewerTocOpenTooltip;

  /// Placeholder shown inside the TOC drawer when the active document has no headings the parser could extract.
  ///
  /// In en, this message translates to:
  /// **'No headings in this document'**
  String get viewerTocEmpty;

  /// Accessibility hint on each TOC entry button, read by screen readers after the heading label to clarify the tap action.
  ///
  /// In en, this message translates to:
  /// **'Navigate to heading'**
  String get viewerTocNavigateHint;

  /// Tooltip on the viewer AppBar action that replaces the title with the in-document search field.
  ///
  /// In en, this message translates to:
  /// **'Search in document'**
  String get viewerSearchOpenTooltip;

  /// Tooltip on the close button that returns the viewer AppBar to its document-title state.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get viewerSearchCloseTooltip;

  /// Tooltip on the chevron that jumps to the previous in-document search match.
  ///
  /// In en, this message translates to:
  /// **'Previous match'**
  String get viewerSearchPreviousTooltip;

  /// Tooltip on the chevron that jumps to the next in-document search match.
  ///
  /// In en, this message translates to:
  /// **'Next match'**
  String get viewerSearchNextTooltip;

  /// Counter shown next to the in-document search field: 1-based current match index over total matches.
  ///
  /// In en, this message translates to:
  /// **'{current} / {total}'**
  String viewerSearchMatchCount(int current, int total);

  /// Inline label shown next to the in-document search field when the current query matches no lines.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get viewerSearchNoResults;

  /// Section header above the reading comfort controls on the settings screen.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get settingsReadingTitle;

  /// Label above the font size slider in the reading comfort section.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get settingsReadingFontScaleTitle;

  /// Format string for the font size slider's current value, e.g. '115%'.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String settingsReadingFontScaleValue(int percent);

  /// Label above the reading-column width segmented button.
  ///
  /// In en, this message translates to:
  /// **'Reading width'**
  String get settingsReadingWidthTitle;

  /// Reading width preset that caps the column at roughly 680 dp for long-form prose.
  ///
  /// In en, this message translates to:
  /// **'Comfort'**
  String get settingsReadingWidthComfortable;

  /// Reading width preset that caps the column at roughly 840 dp so code blocks breathe on tablets.
  ///
  /// In en, this message translates to:
  /// **'Wide'**
  String get settingsReadingWidthWide;

  /// Reading width preset that removes the cap and lets the column stretch to the full viewport width.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get settingsReadingWidthFull;

  /// Label above the line-height segmented button.
  ///
  /// In en, this message translates to:
  /// **'Line spacing'**
  String get settingsReadingLineHeightTitle;

  /// Line height preset that tightens paragraph line spacing for dense layouts.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get settingsReadingLineHeightCompact;

  /// Default line height preset matching Material 3 body-medium.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get settingsReadingLineHeightStandard;

  /// Loosest line height preset with the most breathing room between lines.
  ///
  /// In en, this message translates to:
  /// **'Airy'**
  String get settingsReadingLineHeightAiry;

  /// Section header above display-related controls on the settings screen.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get settingsDisplayTitle;

  /// Label for the switch that prevents the screen from sleeping while the viewer is open.
  ///
  /// In en, this message translates to:
  /// **'Keep screen on'**
  String get settingsKeepScreenOnTitle;

  /// Subtitle beneath the keep-screen-on switch explaining when it is active.
  ///
  /// In en, this message translates to:
  /// **'Prevents sleep while reading'**
  String get settingsKeepScreenOnSubtitle;

  /// Settings screen action that restores theme, language, and reading comfort to their initial values.
  ///
  /// In en, this message translates to:
  /// **'Reset to defaults'**
  String get settingsResetButton;

  /// Title of the confirmation dialog before wiping every user preference back to the platform defaults.
  ///
  /// In en, this message translates to:
  /// **'Reset settings?'**
  String get settingsResetConfirmTitle;

  /// Body of the confirmation dialog explaining what reset touches and what it leaves alone.
  ///
  /// In en, this message translates to:
  /// **'Theme, language, and reading comfort settings will all return to their defaults. Recents, bookmarks, and folders are not affected.'**
  String get settingsResetConfirmBody;

  /// Confirm button on the reset dialog.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get settingsResetConfirmAction;

  /// Snackbar shown after a successful reset.
  ///
  /// In en, this message translates to:
  /// **'Settings reset to defaults'**
  String get settingsResetSnack;

  /// Tooltip on the viewer AppBar action that opens the Aa reading-comfort bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'Reading settings'**
  String get viewerReadingPanelOpenTooltip;

  /// Header text shown at the top of the viewer reading-comfort bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get viewerReadingPanelTitle;

  /// Bottom sheet action that resets just the three reading knobs (font scale, width, line spacing) to their defaults, without touching theme or language.
  ///
  /// In en, this message translates to:
  /// **'Reset reading defaults'**
  String get viewerReadingPanelResetButton;

  /// Bottom sheet link that pushes the full settings screen so the user can reach preferences not exposed in the reading panel (e.g. language).
  ///
  /// In en, this message translates to:
  /// **'All settings'**
  String get viewerReadingPanelAllSettings;

  /// Snackbar shown when a document opens and the viewer automatically restores the scroll position from a saved bookmark.
  ///
  /// In en, this message translates to:
  /// **'Resumed from your last reading position'**
  String get viewerResumedFromBookmark;

  /// Snackbar action button label used to scroll back to the beginning of the document (e.g. after an auto-restore snackbar).
  ///
  /// In en, this message translates to:
  /// **'Go to top'**
  String get actionGoToTop;

  /// Label shown next to the spinner while a markdown document is being read and parsed.
  ///
  /// In en, this message translates to:
  /// **'Loading document…'**
  String get viewerLoading;

  /// Fallback title shown in the viewer app bar when the document's basename cannot be determined.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get viewerUnnamedDocument;

  /// Snackbar shown when the user dismisses the native file picker without choosing a file.
  ///
  /// In en, this message translates to:
  /// **'No file was selected.'**
  String get libraryFilePickCancelled;

  /// Snackbar shown when the native file picker returns an error or an invalid path.
  ///
  /// In en, this message translates to:
  /// **'The file could not be opened. Please try again.'**
  String get libraryFilePickFailed;

  /// User-facing message when a file path is no longer valid.
  ///
  /// In en, this message translates to:
  /// **'This file no longer exists. It may have been moved or deleted.'**
  String get errorFileNotFound;

  /// User-facing message when the OS denies file access.
  ///
  /// In en, this message translates to:
  /// **'Permission to read this file was denied. Choose the file again from the picker.'**
  String get errorPermissionDenied;

  /// User-facing message when markdown parsing fails.
  ///
  /// In en, this message translates to:
  /// **'This document could not be read as markdown.'**
  String get errorParseFailed;

  /// User-facing message when a single block fails to render.
  ///
  /// In en, this message translates to:
  /// **'A part of this document could not be rendered.'**
  String get errorRenderFailed;

  /// Fallback user-facing message for unknown failures.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorUnknown;

  /// Placeholder in the repo sync URL input field.
  ///
  /// In en, this message translates to:
  /// **'Paste a public GitHub URL'**
  String get syncUrlHint;

  /// Button label to begin a repository sync.
  ///
  /// In en, this message translates to:
  /// **'Start sync'**
  String get syncStart;

  /// Status message shown while the Trees API call is in-flight.
  ///
  /// In en, this message translates to:
  /// **'Discovering files…'**
  String get syncDiscovering;

  /// Button shown after a successful sync to reset the screen and sync a different repo.
  ///
  /// In en, this message translates to:
  /// **'Sync another'**
  String get syncSyncAnotherButton;

  /// Button in the sync result card that navigates to the synced repo in the library.
  ///
  /// In en, this message translates to:
  /// **'Open in library'**
  String get syncOpenInLibrary;

  /// Result card detail line on a re-sync showing how many files were actually downloaded vs skipped (SHA match).
  ///
  /// In en, this message translates to:
  /// **'{downloaded} updated · {unchanged} unchanged'**
  String syncStatsIncremental(int downloaded, int unchanged);

  /// Long-press / context menu action to re-sync an already-synced repository.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get syncUpdateRepo;

  /// Expansion toggle that reveals the GitHub PAT input field.
  ///
  /// In en, this message translates to:
  /// **'Add personal access token (optional)'**
  String get syncPatToggle;

  /// Label for the GitHub PAT text field.
  ///
  /// In en, this message translates to:
  /// **'Personal access token'**
  String get syncPatLabel;

  /// Placeholder text inside the PAT field showing the expected token format.
  ///
  /// In en, this message translates to:
  /// **'ghp_xxxxxxxxxxxxxxxxxxxx'**
  String get syncPatHint;

  /// Caption beneath the PAT field explaining its purpose.
  ///
  /// In en, this message translates to:
  /// **'Increases the rate limit to 5,000 requests/hour and enables private repositories.'**
  String get syncPatSubtitle;

  /// Security disclosure note shown in the PAT section reassuring the user about local-only storage.
  ///
  /// In en, this message translates to:
  /// **'Your token is stored in your device\'s secure keychain. It is never sent to our servers and is used only to access the repository you specify.'**
  String get syncPatSecurityNote;

  /// Tappable link in the PAT security note that opens the how-to dialog.
  ///
  /// In en, this message translates to:
  /// **'How do I get a token?'**
  String get syncPatHowToButton;

  /// Title of the dialog explaining how to create a GitHub Personal Access Token.
  ///
  /// In en, this message translates to:
  /// **'Getting a GitHub token'**
  String get syncPatHowToTitle;

  /// Step 1 in the GitHub PAT how-to dialog.
  ///
  /// In en, this message translates to:
  /// **'Open github.com → Settings → Developer settings → Personal access tokens'**
  String get syncPatHowToStep1;

  /// Step 2 in the GitHub PAT how-to dialog.
  ///
  /// In en, this message translates to:
  /// **'Choose Fine-grained tokens, then tap Generate new token'**
  String get syncPatHowToStep2;

  /// Step 3 in the GitHub PAT how-to dialog.
  ///
  /// In en, this message translates to:
  /// **'Set a name, expiration date, and select your target repository'**
  String get syncPatHowToStep3;

  /// Step 4 in the GitHub PAT how-to dialog — specifies the minimum required scope.
  ///
  /// In en, this message translates to:
  /// **'Under Permissions → Repository permissions → Contents, choose Read-only'**
  String get syncPatHowToStep4;

  /// Step 5 in the GitHub PAT how-to dialog.
  ///
  /// In en, this message translates to:
  /// **'Tap Generate token, then copy and paste it into this field'**
  String get syncPatHowToStep5;

  /// Highlighted note in the PAT how-to dialog emphasising minimum required permissions.
  ///
  /// In en, this message translates to:
  /// **'Only Contents: Read-only is needed — do not grant write or admin permissions.'**
  String get syncPatHowToPermissionNote;

  /// Dismiss button in the PAT how-to dialog.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get syncPatHowToClose;

  /// Tooltip on the clear icon inside the PAT input field.
  ///
  /// In en, this message translates to:
  /// **'Clear token'**
  String get syncPatClearButton;

  /// Snackbar shown after the stored PAT is deleted.
  ///
  /// In en, this message translates to:
  /// **'Token cleared'**
  String get syncPatCleared;

  /// Long-press / context menu action to remove a synced repo from the library drawer.
  ///
  /// In en, this message translates to:
  /// **'Remove synced repository'**
  String get syncRemoveRepo;

  /// Snackbar shown after a synced repository is removed.
  ///
  /// In en, this message translates to:
  /// **'Repository removed'**
  String get syncRemovedRepoSnack;

  /// Tooltip on the refresh icon shown next to a synced repo in the library drawer.
  ///
  /// In en, this message translates to:
  /// **'Re-sync'**
  String get syncRefreshTooltip;

  /// Plural message showing how many .md files were discovered in a repo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No markdown files found} =1{1 markdown file found} other{{count} markdown files found}}'**
  String syncFilesFound(int count);

  /// Per-file progress indicator during a sync.
  ///
  /// In en, this message translates to:
  /// **'Downloading {current} of {total}'**
  String syncProgress(int current, int total);

  /// Confirmation shown when a repository sync finishes successfully.
  ///
  /// In en, this message translates to:
  /// **'Sync complete'**
  String get syncCompleted;

  /// Warning shown when a sync finishes with partial failures.
  ///
  /// In en, this message translates to:
  /// **'Some files could not be downloaded.'**
  String get syncPartial;

  /// Subtitle on a synced-repo drawer tile when the last sync was under a minute ago.
  ///
  /// In en, this message translates to:
  /// **'Synced just now'**
  String get syncLastSyncedJustNow;

  /// Subtitle on a synced-repo drawer tile: minutes since last sync.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Synced 1 min ago} other{Synced {count} min ago}}'**
  String syncLastSyncedMinutes(int count);

  /// Subtitle on a synced-repo drawer tile: hours since last sync.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Synced 1 hour ago} other{Synced {count} hours ago}}'**
  String syncLastSyncedHours(int count);

  /// Subtitle on a synced-repo drawer tile: days since last sync.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Synced yesterday} other{Synced {count} days ago}}'**
  String syncLastSyncedDays(int count);

  /// User-facing message when the GitHub API responds with 403 due to rate limiting.
  ///
  /// In en, this message translates to:
  /// **'GitHub rate limit reached. Add a personal access token in Settings or try again later.'**
  String get errorRateLimited;

  /// User-facing message when the GitHub repo or sub-path returns 404.
  ///
  /// In en, this message translates to:
  /// **'Repository or path not found. Check the URL and try again.'**
  String get errorRepoNotFound;

  /// User-facing message when the device has no connectivity during a sync.
  ///
  /// In en, this message translates to:
  /// **'No network connection. Sync needs internet access.'**
  String get errorNetworkUnavailable;

  /// User-facing message when the GitHub API responds with 401 (invalid or expired token) or a non-rate-limit 403 (private repository without sufficient access).
  ///
  /// In en, this message translates to:
  /// **'Authentication failed. Check your personal access token in Settings and try again.'**
  String get errorAuthFailed;

  /// Snackbar text shown when flipping the Settings > Send crash reports toggle throws — e.g. a full disk blocked SharedPreferences.setBool or Sentry.close() failed to tear down hooks cleanly.
  ///
  /// In en, this message translates to:
  /// **'Could not update crash-reporting preference. Please try again.'**
  String get errorCrashReportingToggleFailed;

  /// User-facing message when the entered URL is not a recognised sync provider.
  ///
  /// In en, this message translates to:
  /// **'This URL is not supported. Only GitHub repository URLs are currently accepted.'**
  String get errorUnsupportedProvider;

  /// User-facing message when a sync completes with some files failing.
  ///
  /// In en, this message translates to:
  /// **'Sync partially completed: {syncedCount} file(s) saved, {failedCount} failed.'**
  String errorPartialSync(int syncedCount, int failedCount);

  /// Label of the button in the onboarding flow top bar that dismisses the remaining pages and returns the user to the library.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// Screen-reader-only label for the page-indicator dot row on the onboarding screen. Announced as a single node so TalkBack / VoiceOver users hear the current position once rather than three separate dot widgets.
  ///
  /// In en, this message translates to:
  /// **'Page {current} of {total}'**
  String onboardingPageIndicator(int current, int total);

  /// Label of the primary button on every onboarding page except the last — advances to the next page.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// Label of the primary button on the final onboarding page — dismisses the flow and opens the library.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get onboardingGetStarted;

  /// Title of the first onboarding page, introducing the app.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Markdown Viewer'**
  String get onboardingWelcomeTitle;

  /// Body copy of the first onboarding page. Condensed to a single sentence that covers both the app's purpose (focused reader) and what it renders, so the rendering features no longer need a dedicated page.
  ///
  /// In en, this message translates to:
  /// **'A focused mobile reader for Mermaid, LaTeX math, code and tables — rendered cleanly, offline by default.'**
  String get onboardingWelcomeBody;

  /// Title of the second onboarding page, directing the user to add content from one of the three supported sources (file, folder, synced repo).
  ///
  /// In en, this message translates to:
  /// **'Bring your content'**
  String get onboardingSourcesTitle;

  /// Body copy of the second onboarding page. Mentions the three entry points into the library plus the offline-by-default guarantee.
  ///
  /// In en, this message translates to:
  /// **'Open a file, add a folder, or sync a public GitHub repo. Everything stays on-device.'**
  String get onboardingSourcesBody;

  /// Title of the third and final onboarding page that prompts the user to make Markdown Viewer the default handler for .md files.
  ///
  /// In en, this message translates to:
  /// **'Be your default .md reader'**
  String get onboardingDefaultTitle;

  /// Android body copy for the default-handler onboarding step. The CTA opens the per-app Open by default system screen.
  ///
  /// In en, this message translates to:
  /// **'Tap a markdown file, pick Markdown Viewer, choose Always — or open settings to set it now.'**
  String get onboardingDefaultBodyAndroid;

  /// iOS body copy for the default-handler onboarding step. iOS does not expose a default-app chooser for markdown, so the text explains the share-sheet flow.
  ///
  /// In en, this message translates to:
  /// **'Tap a markdown file in Files or AirDrop and pick Markdown Viewer from the share sheet — it stays at the top for next time.'**
  String get onboardingDefaultBodyIos;

  /// CTA label on the default-handler onboarding step (Android only). Opens the per-app Open by default settings screen.
  ///
  /// In en, this message translates to:
  /// **'Open system settings'**
  String get onboardingDefaultOpenSettings;

  /// Snackbar shown when the Open system settings CTA on the default-handler onboarding step fails to launch — e.g. an OEM that does not expose the default-apps intent.
  ///
  /// In en, this message translates to:
  /// **'Could not open the settings screen on this device.'**
  String get onboardingDefaultSettingsUnavailable;

  /// Label for the debug-only button in Settings that clears the stored onboarding completion marker and relaunches the flow. Only visible in debug builds; stripped from release binaries via kDebugMode.
  ///
  /// In en, this message translates to:
  /// **'Show onboarding again (debug)'**
  String get settingsDebugResetOnboarding;

  /// Title of the toggle in Settings that enables anonymous crash reporting via Sentry.
  ///
  /// In en, this message translates to:
  /// **'Send crash reports'**
  String get settingsCrashReportingTitle;

  /// Subtitle below the crash reporting toggle explaining what data is sent and what is not.
  ///
  /// In en, this message translates to:
  /// **'Help improve the app by sending anonymous crash data. No file contents or personal information are ever collected.'**
  String get settingsCrashReportingSubtitle;

  /// Title of the example card shown on the sync screen for first-time users.
  ///
  /// In en, this message translates to:
  /// **'Try it with MarkdownViewer examples'**
  String get syncTryItTitle;

  /// Body text of the try-it example card on the sync screen.
  ///
  /// In en, this message translates to:
  /// **'One sample MD per feature — sync and read them offline.'**
  String get syncTryItBody;

  /// Approximate file count shown in the try-it card.
  ///
  /// In en, this message translates to:
  /// **'~25 markdown examples'**
  String get syncTryItFileCount;

  /// Button label on the try-it card that starts syncing the example repo.
  ///
  /// In en, this message translates to:
  /// **'Try it'**
  String get syncTryItButton;

  /// Section header above the list of previously synced repos on the sync screen.
  ///
  /// In en, this message translates to:
  /// **'Synced repositories'**
  String get syncRecentSyncsHeader;

  /// File count shown in the recent syncs list.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file} other{{count} files}}'**
  String syncRecentFileCount(int count);

  /// Button label to re-sync a previously synced repo from the sync screen.
  ///
  /// In en, this message translates to:
  /// **'Re-sync'**
  String get syncRecentResync;

  /// Button label to open a synced repo in the library from the sync screen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get syncRecentOpen;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
