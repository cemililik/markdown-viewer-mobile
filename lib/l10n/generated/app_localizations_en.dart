// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Markdown Viewer';

  @override
  String get navLibrary => 'Library';

  @override
  String get navSettings => 'Settings';

  @override
  String get navRepoSync => 'Sync';

  @override
  String get libraryRecentsEmptyTitle => 'No recent documents';

  @override
  String get libraryRecentsEmptySubtitle =>
      'Browse a saved source or open a new file.';

  @override
  String get libraryRecentsEmptySources => 'Your sources';

  @override
  String get libraryEmptyTitle => 'No documents yet';

  @override
  String get libraryEmptyMessage =>
      'Open a markdown file or sync a repository to get started.';

  @override
  String get libraryRecentTitle => 'Recent documents';

  @override
  String get libraryRecentClearAll => 'Clear all';

  @override
  String get libraryRecentClearConfirmTitle => 'Clear recent documents?';

  @override
  String get libraryRecentClearConfirmBody =>
      'This removes every entry from the Recent documents list. The files themselves are not deleted.';

  @override
  String get libraryRecentRemove => 'Remove from recents';

  @override
  String get libraryRecentRemoved => 'Removed from recents';

  @override
  String get libraryRecentFileMissing =>
      'This file is no longer available — removed from recents.';

  @override
  String get libraryRecentJustNow => 'Just now';

  @override
  String libraryRecentMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String libraryRecentHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String get libraryRecentYesterday => 'Yesterday';

  @override
  String libraryRecentDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
    );
    return '$_temp0';
  }

  @override
  String get libraryRecentLongAgo => 'A while back';

  @override
  String get libraryGreetingMorning => 'Good morning';

  @override
  String get libraryGreetingAfternoon => 'Good afternoon';

  @override
  String get libraryGreetingEvening => 'Good evening';

  @override
  String get libraryGreetingSubtitleEmpty => 'No recent documents yet';

  @override
  String libraryGreetingSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recent documents',
      one: '1 recent document',
    );
    return '$_temp0';
  }

  @override
  String get librarySearchHint => 'Search recents';

  @override
  String get librarySearchClear => 'Clear search';

  @override
  String get librarySearchNoResults => 'No matching documents';

  @override
  String get libraryRecentPinnedSection => 'Pinned';

  @override
  String get libraryRecentGroupToday => 'Today';

  @override
  String get libraryRecentGroupYesterday => 'Yesterday';

  @override
  String get libraryRecentGroupThisWeek => 'Earlier this week';

  @override
  String get libraryRecentGroupEarlier => 'Earlier';

  @override
  String get libraryRecentPin => 'Pin to top';

  @override
  String get libraryRecentUnpin => 'Unpin';

  @override
  String get libraryRecentPinnedSnack => 'Pinned to top';

  @override
  String get libraryRecentUnpinnedSnack => 'Removed pin';

  @override
  String get libraryFoldersDrawerTitle => 'Folders';

  @override
  String get libraryFoldersAdd => 'Add folder';

  @override
  String get libraryFoldersEmptyTitle => 'No folders yet';

  @override
  String get libraryFoldersEmptyMessage =>
      'Add a folder of markdown files to browse them here.';

  @override
  String get libraryFoldersOpenDrawerTooltip => 'Open folders';

  @override
  String get libraryFoldersAddedSnack => 'Folder added';

  @override
  String get libraryFoldersRemovedSnack => 'Folder removed';

  @override
  String get libraryFoldersRemove => 'Remove folder';

  @override
  String get libraryFoldersAddCancelled => 'Folder selection cancelled';

  @override
  String get libraryFoldersAddFailed =>
      'Could not open the folder picker. Please try again.';

  @override
  String get libraryFoldersAlreadyAdded =>
      'This folder is already in the library.';

  @override
  String get libraryFoldersEnumerationFailed => 'Could not read this folder.';

  @override
  String get libraryFoldersEmptyFolder => 'No markdown files in this folder';

  @override
  String get libraryActionMenuOpenFile => 'Open file';

  @override
  String get libraryActionMenuOpenFolder => 'Open folder';

  @override
  String get libraryActionMenuSyncRepo => 'Sync repository';

  @override
  String get libraryActionMenuTooltip => 'Add documents';

  @override
  String get libraryActionMenuCloseTooltip => 'Close menu';

  @override
  String get librarySourceRecents => 'Recents';

  @override
  String get librarySourceSectionHeader => 'Sources';

  @override
  String get libraryAddSourceButton => 'Add source';

  @override
  String get libraryAddSourceSheetTitle => 'Add a new source';

  @override
  String libraryFolderSourceSearchHint(String folderName) {
    return 'Search in $folderName';
  }

  @override
  String get libraryFolderSourceEmpty => 'This folder has no markdown files';

  @override
  String get libraryFolderSourceError =>
      'Could not read this folder. Check that it still exists on disk.';

  @override
  String libraryFolderSourceSearchNoResults(String folderName) {
    return 'No matching files in $folderName';
  }

  @override
  String get libraryFolderSourceSearchLoading => 'Scanning folder…';

  @override
  String get libraryAddSourceFolderSubtitle =>
      'Add a directory from this device';

  @override
  String get libraryAddSourceRepoSubtitle =>
      'Pull markdown files from a git repository';

  @override
  String get actionOpenFile => 'Open file';

  @override
  String get actionSyncRepo => 'Sync repository';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionRetry => 'Retry';

  @override
  String get settingsThemeTitle => 'Theme';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeSepia => 'Sepia';

  @override
  String get settingsLanguageTitle => 'Language';

  @override
  String get settingsLanguageSystem => 'System default';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageTurkish => 'Turkish';

  @override
  String get settingsFontSizeTitle => 'Font size';

  @override
  String get viewerTocTitle => 'Contents';

  @override
  String get viewerSearchHint => 'Search in document';

  @override
  String get admonitionNoteTitle => 'Note';

  @override
  String get admonitionTipTitle => 'Tip';

  @override
  String get admonitionImportantTitle => 'Important';

  @override
  String get admonitionWarningTitle => 'Warning';

  @override
  String get admonitionCautionTitle => 'Caution';

  @override
  String get mermaidLoading => 'Rendering diagram…';

  @override
  String get mermaidRenderErrorTitle => 'Diagram could not be rendered';

  @override
  String get mermaidRenderErrorBody =>
      'Check the diagram syntax and try again.';

  @override
  String get mermaidReset => 'Reset view';

  @override
  String get mermaidDiagramLabel =>
      'Mermaid diagram. Pinch to zoom, drag to pan.';

  @override
  String viewerReadingTime(int minutes) {
    return '$minutes min read';
  }

  @override
  String get viewerBackToTopTooltip => 'Back to top';

  @override
  String get viewerBookmarkSaveTooltip => 'Save or update reading position';

  @override
  String get viewerBookmarkSaved => 'Reading position saved';

  @override
  String get viewerBookmarkUpdated => 'Reading position updated';

  @override
  String get viewerBookmarkCleared => 'Bookmark cleared';

  @override
  String get viewerBookmarkLongPressHint =>
      'Long-press the bookmark icon for options.';

  @override
  String get viewerBookmarkMenuGoTo => 'Go to saved position';

  @override
  String get viewerBookmarkMenuRemove => 'Remove bookmark';

  @override
  String get viewerShareTooltip => 'Share document';

  @override
  String get viewerShareMenuTitle => 'Share as…';

  @override
  String get viewerShareMenuText => 'Share as text';

  @override
  String get viewerShareMenuPdf => 'Export as PDF';

  @override
  String get viewerPdfGenerating => 'Generating PDF…';

  @override
  String get viewerPdfError => 'Could not generate PDF. Please try again.';

  @override
  String get viewerTocOpenTooltip => 'Table of contents';

  @override
  String get viewerTocEmpty => 'No headings in this document';

  @override
  String get viewerTocNavigateHint => 'Navigate to heading';

  @override
  String get viewerSearchOpenTooltip => 'Search in document';

  @override
  String get viewerSearchCloseTooltip => 'Close search';

  @override
  String get viewerSearchPreviousTooltip => 'Previous match';

  @override
  String get viewerSearchNextTooltip => 'Next match';

  @override
  String viewerSearchMatchCount(int current, int total) {
    return '$current / $total';
  }

  @override
  String get viewerSearchNoResults => 'No matches';

  @override
  String get settingsReadingTitle => 'Reading';

  @override
  String get settingsReadingFontScaleTitle => 'Font size';

  @override
  String settingsReadingFontScaleValue(int percent) {
    return '$percent%';
  }

  @override
  String get settingsReadingWidthTitle => 'Reading width';

  @override
  String get settingsReadingWidthComfortable => 'Comfortable';

  @override
  String get settingsReadingWidthWide => 'Wide';

  @override
  String get settingsReadingWidthFull => 'Full';

  @override
  String get settingsReadingLineHeightTitle => 'Line spacing';

  @override
  String get settingsReadingLineHeightCompact => 'Compact';

  @override
  String get settingsReadingLineHeightStandard => 'Standard';

  @override
  String get settingsReadingLineHeightAiry => 'Airy';

  @override
  String get settingsDisplayTitle => 'Display';

  @override
  String get settingsKeepScreenOnTitle => 'Keep screen on';

  @override
  String get settingsKeepScreenOnSubtitle => 'Prevents sleep while reading';

  @override
  String get settingsResetButton => 'Reset to defaults';

  @override
  String get settingsResetConfirmTitle => 'Reset settings?';

  @override
  String get settingsResetConfirmBody =>
      'Theme, language, and reading comfort settings will all return to their defaults. Recents, bookmarks, and folders are not affected.';

  @override
  String get settingsResetConfirmAction => 'Reset';

  @override
  String get settingsResetSnack => 'Settings reset to defaults';

  @override
  String get viewerReadingPanelOpenTooltip => 'Reading settings';

  @override
  String get viewerReadingPanelTitle => 'Reading';

  @override
  String get viewerReadingPanelResetButton => 'Reset reading defaults';

  @override
  String get viewerReadingPanelAllSettings => 'All settings';

  @override
  String get viewerResumedFromBookmark =>
      'Resumed from your last reading position';

  @override
  String get actionGoToTop => 'Go to top';

  @override
  String get viewerLoading => 'Loading document…';

  @override
  String get viewerUnnamedDocument => 'Document';

  @override
  String get libraryFilePickCancelled => 'No file was selected.';

  @override
  String get libraryFilePickFailed =>
      'The file could not be opened. Please try again.';

  @override
  String get errorFileNotFound =>
      'This file no longer exists. It may have been moved or deleted.';

  @override
  String get errorPermissionDenied =>
      'Permission to read this file was denied. Choose the file again from the picker.';

  @override
  String get errorParseFailed => 'This document could not be read as markdown.';

  @override
  String get errorRenderFailed =>
      'A part of this document could not be rendered.';

  @override
  String get errorUnknown => 'Something went wrong. Please try again.';

  @override
  String get syncUrlHint => 'Paste a public GitHub URL';

  @override
  String get syncStart => 'Start sync';

  @override
  String get syncDiscovering => 'Discovering files…';

  @override
  String get syncSyncAnotherButton => 'Sync another';

  @override
  String get syncOpenInLibrary => 'Open in library';

  @override
  String syncStatsIncremental(int downloaded, int unchanged) {
    return '$downloaded updated · $unchanged unchanged';
  }

  @override
  String get syncUpdateRepo => 'Update';

  @override
  String get syncPatToggle => 'Add personal access token (optional)';

  @override
  String get syncPatLabel => 'Personal access token';

  @override
  String get syncPatHint => 'ghp_xxxxxxxxxxxxxxxxxxxx';

  @override
  String get syncPatSubtitle =>
      'Increases the rate limit to 5,000 requests/hour and enables private repositories.';

  @override
  String get syncPatSecurityNote =>
      'Your token is stored in your device\'s secure keychain. It is never sent to our servers and is used only to access the repository you specify.';

  @override
  String get syncPatHowToButton => 'How do I get a token?';

  @override
  String get syncPatHowToTitle => 'Getting a GitHub token';

  @override
  String get syncPatHowToStep1 =>
      'Open github.com → Settings → Developer settings → Personal access tokens';

  @override
  String get syncPatHowToStep2 =>
      'Choose Fine-grained tokens, then tap Generate new token';

  @override
  String get syncPatHowToStep3 =>
      'Set a name, expiration date, and select your target repository';

  @override
  String get syncPatHowToStep4 =>
      'Under Permissions → Repository permissions → Contents, choose Read-only';

  @override
  String get syncPatHowToStep5 =>
      'Tap Generate token, then copy and paste it into this field';

  @override
  String get syncPatHowToPermissionNote =>
      'Only Contents: Read-only is needed — do not grant write or admin permissions.';

  @override
  String get syncPatHowToClose => 'Got it';

  @override
  String get syncPatClearButton => 'Clear token';

  @override
  String get syncPatCleared => 'Token cleared';

  @override
  String get syncRemoveRepo => 'Remove synced repository';

  @override
  String get syncRemovedRepoSnack => 'Repository removed';

  @override
  String get syncRefreshTooltip => 'Re-sync';

  @override
  String syncFilesFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count markdown files found',
      one: '1 markdown file found',
      zero: 'No markdown files found',
    );
    return '$_temp0';
  }

  @override
  String syncProgress(int current, int total) {
    return 'Downloading $current of $total';
  }

  @override
  String get syncCompleted => 'Sync complete';

  @override
  String get syncPartial => 'Some files could not be downloaded.';

  @override
  String get syncLastSyncedJustNow => 'Synced just now';

  @override
  String syncLastSyncedMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Synced $count min ago',
      one: 'Synced 1 min ago',
    );
    return '$_temp0';
  }

  @override
  String syncLastSyncedHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Synced $count hours ago',
      one: 'Synced 1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String syncLastSyncedDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Synced $count days ago',
      one: 'Synced yesterday',
    );
    return '$_temp0';
  }

  @override
  String get errorRateLimited =>
      'GitHub rate limit reached. Add a personal access token in Settings or try again later.';

  @override
  String get errorRepoNotFound =>
      'Repository or path not found. Check the URL and try again.';

  @override
  String get errorNetworkUnavailable =>
      'No network connection. Sync needs internet access.';

  @override
  String get errorUnsupportedProvider =>
      'This URL is not supported. Only GitHub repository URLs are currently accepted.';

  @override
  String errorPartialSync(int syncedCount, int failedCount) {
    return 'Sync partially completed: $syncedCount file(s) saved, $failedCount failed.';
  }

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingGetStarted => 'Get started';

  @override
  String get onboardingWelcomeTitle => 'Welcome to Markdown Viewer';

  @override
  String get onboardingWelcomeBody =>
      'A focused mobile reader for your markdown notes, docs, and knowledge base — no editor, no distractions.';

  @override
  String get onboardingRenderingTitle => 'Rich content, beautifully rendered';

  @override
  String get onboardingRenderingBody =>
      'Tables, syntax-highlighted code, LaTeX math, Mermaid diagrams, admonitions and footnotes — all handled out of the box.';

  @override
  String get onboardingPersonalizeTitle => 'Read the way you like';

  @override
  String get onboardingPersonalizeBody =>
      'Adjust font size, line spacing, theme and language — or pin a bookmark and keep the screen awake while you read.';

  @override
  String get onboardingGetStartedTitle => 'Open a folder to begin';

  @override
  String get onboardingGetStartedBody =>
      'Grant access to a folder of markdown files, or sync a public GitHub repository — your library is ready whenever you are.';

  @override
  String get settingsDebugResetOnboarding => 'Show onboarding again (debug)';

  @override
  String get settingsCrashReportingTitle => 'Send crash reports';

  @override
  String get settingsCrashReportingSubtitle =>
      'Help improve the app by sending anonymous crash data. No file contents or personal information are ever collected.';
}
