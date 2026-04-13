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

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsThemeSystem;

  /// Section title for the language selector in settings.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageTitle;

  /// Option in the language selector that follows the OS language.
  ///
  /// In en, this message translates to:
  /// **'System default'**
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

  /// Tooltip for the floating action button that scrolls a markdown document back to the very top.
  ///
  /// In en, this message translates to:
  /// **'Back to top'**
  String get viewerBackToTopTooltip;

  /// Tooltip for the viewer AppBar action that saves the current reading position so it can be resumed later.
  ///
  /// In en, this message translates to:
  /// **'Bookmark reading position'**
  String get viewerBookmarkSaveTooltip;

  /// Tooltip for the viewer AppBar action that clears a previously saved reading position.
  ///
  /// In en, this message translates to:
  /// **'Clear bookmark'**
  String get viewerBookmarkClearTooltip;

  /// Snackbar confirmation shown after the user saves a bookmark at the current scroll position.
  ///
  /// In en, this message translates to:
  /// **'Reading position saved'**
  String get viewerBookmarkSaved;

  /// Snackbar confirmation shown after the user clears a previously saved bookmark.
  ///
  /// In en, this message translates to:
  /// **'Bookmark cleared'**
  String get viewerBookmarkCleared;

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
