// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'Markdown Viewer';

  @override
  String get navLibrary => 'Kütüphane';

  @override
  String get navSettings => 'Ayarlar';

  @override
  String get navRepoSync => 'Senkronizasyon';

  @override
  String get libraryEmptyTitle => 'Henüz doküman yok';

  @override
  String get libraryEmptyMessage =>
      'Başlamak için bir markdown dosyası açın veya bir depoyu senkronize edin.';

  @override
  String get actionOpenFile => 'Dosya aç';

  @override
  String get actionSyncRepo => 'Depoyu senkronize et';

  @override
  String get actionCancel => 'İptal';

  @override
  String get actionRetry => 'Yeniden dene';

  @override
  String get settingsThemeTitle => 'Tema';

  @override
  String get settingsThemeLight => 'Açık';

  @override
  String get settingsThemeDark => 'Koyu';

  @override
  String get settingsThemeSystem => 'Sistem varsayılanı';

  @override
  String get settingsLanguageTitle => 'Dil';

  @override
  String get settingsLanguageSystem => 'Sistem varsayılanı';

  @override
  String get settingsFontSizeTitle => 'Yazı tipi boyutu';

  @override
  String get viewerTocTitle => 'İçindekiler';

  @override
  String get viewerSearchHint => 'Dokümanda ara';

  @override
  String get admonitionNoteTitle => 'Not';

  @override
  String get admonitionTipTitle => 'İpucu';

  @override
  String get admonitionImportantTitle => 'Önemli';

  @override
  String get admonitionWarningTitle => 'Uyarı';

  @override
  String get admonitionCautionTitle => 'Dikkat';

  @override
  String get viewerLoading => 'Doküman yükleniyor…';

  @override
  String get viewerUnnamedDocument => 'Doküman';

  @override
  String get libraryFilePickCancelled => 'Hiçbir dosya seçilmedi.';

  @override
  String get libraryFilePickFailed => 'Dosya açılamadı. Lütfen tekrar deneyin.';

  @override
  String get errorFileNotFound =>
      'Bu dosya artık mevcut değil. Taşınmış veya silinmiş olabilir.';

  @override
  String get errorPermissionDenied =>
      'Bu dosyayı okuma izni reddedildi. Lütfen dosyayı seçiciden tekrar seçin.';

  @override
  String get errorParseFailed => 'Bu doküman markdown olarak okunamadı.';

  @override
  String get errorRenderFailed => 'Bu dokümanın bir kısmı görüntülenemedi.';

  @override
  String get errorUnknown => 'Bir sorun oluştu. Lütfen tekrar deneyin.';

  @override
  String get syncUrlHint => 'Herkese açık bir GitHub URL\'si yapıştırın';

  @override
  String get syncStart => 'Senkronizasyonu başlat';

  @override
  String syncFilesFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count markdown dosyası bulundu',
      one: '1 markdown dosyası bulundu',
      zero: 'Markdown dosyası bulunamadı',
    );
    return '$_temp0';
  }

  @override
  String syncProgress(int current, int total) {
    return '$total dosyadan $current tanesi indiriliyor';
  }

  @override
  String get syncCompleted => 'Senkronizasyon tamamlandı';

  @override
  String get syncPartial => 'Bazı dosyalar indirilemedi.';

  @override
  String get errorRateLimited =>
      'GitHub istek limitine ulaşıldı. Ayarlar\'dan kişisel erişim belirteci ekleyin veya daha sonra tekrar deneyin.';

  @override
  String get errorRepoNotFound =>
      'Depo veya yol bulunamadı. URL\'yi kontrol edip tekrar deneyin.';

  @override
  String get errorNetworkUnavailable =>
      'Ağ bağlantısı yok. Senkronizasyon için internet gerekli.';
}
