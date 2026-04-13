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
  String get libraryEmptyTitle => 'No documents yet';

  @override
  String get libraryEmptyMessage =>
      'Open a markdown file or sync a repository to get started.';

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
  String get settingsThemeSystem => 'System default';

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
  String get viewerBackToTopTooltip => 'Back to top';

  @override
  String get viewerBookmarkSaveTooltip => 'Bookmark reading position';

  @override
  String get viewerBookmarkClearTooltip => 'Clear bookmark';

  @override
  String get viewerBookmarkSaved => 'Reading position saved';

  @override
  String get viewerBookmarkCleared => 'Bookmark cleared';

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
  String get errorRateLimited =>
      'GitHub rate limit reached. Add a personal access token in Settings or try again later.';

  @override
  String get errorRepoNotFound =>
      'Repository or path not found. Check the URL and try again.';

  @override
  String get errorNetworkUnavailable =>
      'No network connection. Sync needs internet access.';
}
