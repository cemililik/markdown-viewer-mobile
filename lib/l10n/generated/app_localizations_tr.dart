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
  String get libraryRecentTitle => 'Son açılan dökümanlar';

  @override
  String get libraryRecentClearAll => 'Tümünü temizle';

  @override
  String get libraryRecentClearConfirmTitle => 'Son dökümanlar silinsin mi?';

  @override
  String get libraryRecentClearConfirmBody =>
      'Bu işlem son açılanlar listesindeki tüm girdileri siler. Dosyaların kendileri silinmez.';

  @override
  String get libraryRecentRemove => 'Listeden kaldır';

  @override
  String get libraryRecentRemoved => 'Listeden kaldırıldı';

  @override
  String get libraryRecentFileMissing =>
      'Bu dosya artık mevcut değil — listeden kaldırıldı.';

  @override
  String get libraryRecentJustNow => 'Az önce';

  @override
  String libraryRecentMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dakika önce',
      one: '1 dakika önce',
    );
    return '$_temp0';
  }

  @override
  String libraryRecentHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saat önce',
      one: '1 saat önce',
    );
    return '$_temp0';
  }

  @override
  String get libraryRecentYesterday => 'Dün';

  @override
  String libraryRecentDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gün önce',
    );
    return '$_temp0';
  }

  @override
  String get libraryRecentLongAgo => 'Bir süre önce';

  @override
  String get libraryGreetingMorning => 'Günaydın';

  @override
  String get libraryGreetingAfternoon => 'İyi günler';

  @override
  String get libraryGreetingEvening => 'İyi akşamlar';

  @override
  String get libraryGreetingSubtitleEmpty => 'Henüz son açılan belge yok';

  @override
  String libraryGreetingSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count son belge',
      one: '1 son belge',
    );
    return '$_temp0';
  }

  @override
  String get librarySearchHint => 'Son belgelerde ara';

  @override
  String get librarySearchClear => 'Aramayı temizle';

  @override
  String get librarySearchNoResults => 'Eşleşen belge yok';

  @override
  String get libraryRecentPinnedSection => 'Sabitlenenler';

  @override
  String get libraryRecentGroupToday => 'Bugün';

  @override
  String get libraryRecentGroupYesterday => 'Dün';

  @override
  String get libraryRecentGroupThisWeek => 'Bu hafta içinde';

  @override
  String get libraryRecentGroupEarlier => 'Daha önce';

  @override
  String get libraryRecentPin => 'Yukarı sabitle';

  @override
  String get libraryRecentUnpin => 'Sabitlemeyi kaldır';

  @override
  String get libraryRecentPinnedSnack => 'Yukarı sabitlendi';

  @override
  String get libraryRecentUnpinnedSnack => 'Sabitleme kaldırıldı';

  @override
  String get libraryFoldersDrawerTitle => 'Klasörler';

  @override
  String get libraryFoldersAdd => 'Klasör ekle';

  @override
  String get libraryFoldersEmptyTitle => 'Henüz klasör yok';

  @override
  String get libraryFoldersEmptyMessage =>
      'İçinde markdown dosyaları olan bir klasör ekleyin, burada gezinin.';

  @override
  String get libraryFoldersOpenDrawerTooltip => 'Klasörleri aç';

  @override
  String get libraryFoldersAddedSnack => 'Klasör eklendi';

  @override
  String get libraryFoldersRemovedSnack => 'Klasör kaldırıldı';

  @override
  String get libraryFoldersRemove => 'Klasörü kaldır';

  @override
  String get libraryFoldersAddCancelled => 'Klasör seçimi iptal edildi';

  @override
  String get libraryFoldersAddFailed =>
      'Klasör seçici açılamadı. Tekrar deneyin.';

  @override
  String get libraryFoldersAlreadyAdded => 'Bu klasör zaten kütüphanede.';

  @override
  String get libraryFoldersEnumerationFailed => 'Bu klasör okunamadı.';

  @override
  String get libraryFoldersEmptyFolder => 'Bu klasörde markdown dosyası yok';

  @override
  String get libraryActionMenuOpenFile => 'Dosya aç';

  @override
  String get libraryActionMenuOpenFolder => 'Klasör aç';

  @override
  String get libraryActionMenuSyncRepo => 'Depoyu senkronize et';

  @override
  String get libraryActionMenuTooltip => 'Belge ekle';

  @override
  String get libraryActionMenuCloseTooltip => 'Menüyü kapat';

  @override
  String get librarySourceRecents => 'Son açılanlar';

  @override
  String get librarySourceSectionHeader => 'Kaynaklar';

  @override
  String get libraryAddSourceButton => 'Kaynak ekle';

  @override
  String get libraryAddSourceSheetTitle => 'Yeni kaynak ekle';

  @override
  String libraryFolderSourceSearchHint(String folderName) {
    return '$folderName içinde ara';
  }

  @override
  String get libraryFolderSourceEmpty => 'Bu klasörde markdown dosyası yok';

  @override
  String get libraryFolderSourceError =>
      'Bu klasör okunamadı. Diskte hâlâ olup olmadığını kontrol edin.';

  @override
  String libraryFolderSourceSearchNoResults(String folderName) {
    return '$folderName içinde eşleşen dosya yok';
  }

  @override
  String get libraryFolderSourceSearchLoading => 'Klasör taranıyor…';

  @override
  String get libraryAddSourceFolderSubtitle => 'Bu cihazdan bir dizin ekle';

  @override
  String get libraryAddSourceRepoSubtitle =>
      'Bir git deposundan markdown dosyalarını çek (yakında)';

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
  String get settingsLanguageEnglish => 'İngilizce';

  @override
  String get settingsLanguageTurkish => 'Türkçe';

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
  String get mermaidLoading => 'Diyagram oluşturuluyor…';

  @override
  String get mermaidRenderErrorTitle => 'Diyagram görüntülenemedi';

  @override
  String get mermaidRenderErrorBody =>
      'Diyagram söz dizimini kontrol edip tekrar deneyin.';

  @override
  String get mermaidReset => 'Görünümü sıfırla';

  @override
  String get viewerBackToTopTooltip => 'Başa dön';

  @override
  String get viewerBookmarkSaveTooltip => 'Kaldığın yeri kaydet veya güncelle';

  @override
  String get viewerBookmarkSaved => 'Kaldığın yer kaydedildi';

  @override
  String get viewerBookmarkUpdated => 'Kaldığın yer güncellendi';

  @override
  String get viewerBookmarkCleared => 'İşaret silindi';

  @override
  String get viewerBookmarkLongPressHint => 'Kaldırmak için ikona uzun bas.';

  @override
  String get viewerBookmarkMenuGoTo => 'Kaldığın yere dön';

  @override
  String get viewerBookmarkMenuRemove => 'İşareti kaldır';

  @override
  String get viewerResumedFromBookmark => 'Son okuduğun yerden devam ediliyor';

  @override
  String get actionGoToTop => 'Başa dön';

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
