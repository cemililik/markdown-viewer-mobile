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
  String get libraryRecentsEmptyTitle => 'Son açılan belge yok';

  @override
  String get libraryRecentsEmptySubtitle =>
      'Kayıtlı bir kaynağa göz atın veya yeni bir dosya açın.';

  @override
  String get libraryRecentsEmptySources => 'Kaynaklarınız';

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
      'Bir git deposundan markdown dosyalarını çek';

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
  String get settingsThemeSystem => 'Sistem';

  @override
  String get settingsThemeSepia => 'Sepya';

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
  String get mermaidDiagramLabel =>
      'Mermaid diyagramı. Yakınlaştırmak için sıkıştırın, kaydırmak için sürükleyin.';

  @override
  String viewerReadingTime(int minutes) {
    return '$minutes dk okuma';
  }

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
  String get viewerShareTooltip => 'Belgeyi paylaş';

  @override
  String get viewerShareMenuTitle => 'Farklı paylaş…';

  @override
  String get viewerShareMenuText => 'Metin olarak paylaş';

  @override
  String get viewerShareMenuPdf => 'PDF olarak dışa aktar';

  @override
  String get viewerPdfGenerating => 'PDF oluşturuluyor…';

  @override
  String get viewerPdfError => 'PDF oluşturulamadı. Lütfen tekrar deneyin.';

  @override
  String get viewerTocOpenTooltip => 'İçindekiler';

  @override
  String get viewerTocEmpty => 'Bu belgede başlık yok';

  @override
  String get viewerTocNavigateHint => 'Başlığa git';

  @override
  String get viewerSearchOpenTooltip => 'Belgede ara';

  @override
  String get viewerSearchCloseTooltip => 'Aramayı kapat';

  @override
  String get viewerSearchPreviousTooltip => 'Önceki eşleşme';

  @override
  String get viewerSearchNextTooltip => 'Sonraki eşleşme';

  @override
  String viewerSearchMatchCount(int current, int total) {
    return '$current / $total';
  }

  @override
  String get viewerSearchNoResults => 'Eşleşme yok';

  @override
  String get settingsReadingTitle => 'Okuma';

  @override
  String get settingsReadingFontScaleTitle => 'Yazı boyutu';

  @override
  String settingsReadingFontScaleValue(int percent) {
    return '%$percent';
  }

  @override
  String get settingsReadingWidthTitle => 'Okuma genişliği';

  @override
  String get settingsReadingWidthComfortable => 'Rahat';

  @override
  String get settingsReadingWidthWide => 'Geniş';

  @override
  String get settingsReadingWidthFull => 'Tam';

  @override
  String get settingsReadingLineHeightTitle => 'Satır aralığı';

  @override
  String get settingsReadingLineHeightCompact => 'Sıkı';

  @override
  String get settingsReadingLineHeightStandard => 'Standart';

  @override
  String get settingsReadingLineHeightAiry => 'Ferah';

  @override
  String get settingsDisplayTitle => 'Görünüm';

  @override
  String get settingsKeepScreenOnTitle => 'Ekranı açık tut';

  @override
  String get settingsKeepScreenOnSubtitle =>
      'Okurken ekran kilidi devreye girmez';

  @override
  String get settingsResetButton => 'Varsayılana sıfırla';

  @override
  String get settingsResetConfirmTitle => 'Ayarlar sıfırlansın mı?';

  @override
  String get settingsResetConfirmBody =>
      'Tema, dil ve okuma rahatlığı ayarları varsayılan değerlerine döner. Son açılanlar, işaretler ve klasörler etkilenmez.';

  @override
  String get settingsResetConfirmAction => 'Sıfırla';

  @override
  String get settingsResetSnack => 'Ayarlar varsayılana döndürüldü';

  @override
  String get viewerReadingPanelOpenTooltip => 'Okuma ayarları';

  @override
  String get viewerReadingPanelTitle => 'Okuma';

  @override
  String get viewerReadingPanelResetButton => 'Okuma ayarlarını sıfırla';

  @override
  String get viewerReadingPanelAllSettings => 'Tüm ayarlar';

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
  String get syncDiscovering => 'Dosyalar keşfediliyor…';

  @override
  String get syncSyncAnotherButton => 'Başka depo';

  @override
  String get syncOpenInLibrary => 'Kütüphanede aç';

  @override
  String syncStatsIncremental(int downloaded, int unchanged) {
    return '$downloaded güncellendi · $unchanged değişmedi';
  }

  @override
  String get syncUpdateRepo => 'Güncelle';

  @override
  String get syncPatToggle => 'Kişisel erişim belirteci ekle (opsiyonel)';

  @override
  String get syncPatLabel => 'Kişisel erişim belirteci';

  @override
  String get syncPatHint => 'ghp_xxxxxxxxxxxxxxxxxxxx';

  @override
  String get syncPatSubtitle =>
      'İstek limitini saatte 5.000\'e çıkarır ve özel depolara erişim sağlar.';

  @override
  String get syncPatSecurityNote =>
      'Tokeniniz cihazınızın güvenli anahtarlığında saklanır. Sunucularımıza hiçbir zaman iletilmez ve yalnızca belirttiğiniz depoya erişmek için kullanılır.';

  @override
  String get syncPatHowToButton => 'Token nasıl alınır?';

  @override
  String get syncPatHowToTitle => 'GitHub token alma';

  @override
  String get syncPatHowToStep1 =>
      'github.com → Ayarlar → Geliştirici ayarları → Kişisel erişim belirteçleri sayfasını açın';

  @override
  String get syncPatHowToStep2 =>
      'Hassas belirteçler\'i seçin, ardından Yeni belirteç oluştur\'a tıklayın';

  @override
  String get syncPatHowToStep3 =>
      'Bir ad, son kullanma tarihi ve hedef deponuzu seçin';

  @override
  String get syncPatHowToStep4 =>
      'İzinler → Depo izinleri → İçerik bölümünde Salt okunur\'u seçin';

  @override
  String get syncPatHowToStep5 =>
      'Belirteç oluştur\'a tıklayın, kopyalayıp bu alana yapıştırın';

  @override
  String get syncPatHowToPermissionNote =>
      'Yalnızca İçerik: Salt okunur izni gereklidir — yazma veya yönetici izni vermeyin.';

  @override
  String get syncPatHowToClose => 'Anladım';

  @override
  String get syncPatClearButton => 'Belirteci temizle';

  @override
  String get syncPatCleared => 'Belirteç silindi';

  @override
  String get syncRemoveRepo => 'Senkronize depoyu kaldır';

  @override
  String get syncRemovedRepoSnack => 'Depo kaldırıldı';

  @override
  String get syncRefreshTooltip => 'Yeniden senkronize et';

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
  String get syncLastSyncedJustNow => 'Az önce senkronize edildi';

  @override
  String syncLastSyncedMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dk önce senkronize edildi',
      one: '1 dk önce senkronize edildi',
    );
    return '$_temp0';
  }

  @override
  String syncLastSyncedHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saat önce senkronize edildi',
      one: '1 saat önce senkronize edildi',
    );
    return '$_temp0';
  }

  @override
  String syncLastSyncedDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gün önce senkronize edildi',
      one: 'Dün senkronize edildi',
    );
    return '$_temp0';
  }

  @override
  String get errorRateLimited =>
      'GitHub istek limitine ulaşıldı. Ayarlar\'dan kişisel erişim belirteci ekleyin veya daha sonra tekrar deneyin.';

  @override
  String get errorRepoNotFound =>
      'Depo veya yol bulunamadı. URL\'yi kontrol edip tekrar deneyin.';

  @override
  String get errorNetworkUnavailable =>
      'Ağ bağlantısı yok. Senkronizasyon için internet gerekli.';

  @override
  String get errorAuthFailed =>
      'Kimlik doğrulama başarısız. Ayarlar\'daki kişisel erişim anahtarınızı kontrol edip tekrar deneyin.';

  @override
  String get errorCrashReportingToggleFailed =>
      'Çökme raporlama tercihi güncellenemedi. Lütfen tekrar deneyin.';

  @override
  String get errorUnsupportedProvider =>
      'Bu URL desteklenmiyor. Şu an yalnızca GitHub depo URL\'leri kabul edilmektedir.';

  @override
  String errorPartialSync(int syncedCount, int failedCount) {
    return 'Senkronizasyon kısmen tamamlandı: $syncedCount dosya kaydedildi, $failedCount başarısız oldu.';
  }

  @override
  String get onboardingSkip => 'Atla';

  @override
  String onboardingPageIndicator(int current, int total) {
    return 'Sayfa $current / $total';
  }

  @override
  String get onboardingNext => 'İleri';

  @override
  String get onboardingGetStarted => 'Başlayalım';

  @override
  String get onboardingWelcomeTitle => 'Markdown Viewer\'a hoş geldiniz';

  @override
  String get onboardingWelcomeBody =>
      'Not, döküman ve bilgi tabanınız için odaklanmış bir mobil okuyucu — editör yok, dikkat dağıtıcı unsur yok.';

  @override
  String get onboardingRenderingTitle => 'Zengin içerik, kusursuz gösterim';

  @override
  String get onboardingRenderingBody =>
      'Tablolar, sözdizimi vurgulamalı kod, LaTeX matematik, Mermaid diyagramları, bilgi kutuları ve dipnotlar — hepsi kutudan çıktığı gibi çalışır.';

  @override
  String get onboardingPersonalizeTitle => 'Kendi tarzınızda okuyun';

  @override
  String get onboardingPersonalizeBody =>
      'Yazı boyutu, satır aralığı, tema ve dili ayarlayın — ya da yer imi bırakıp okurken ekranı açık tutun.';

  @override
  String get onboardingGetStartedTitle => 'Başlamak için bir klasör açın';

  @override
  String get onboardingGetStartedBody =>
      'Markdown dosyalarının bulunduğu bir klasöre erişim verin veya açık bir GitHub deposunu senkronize edin — kütüphaneniz hazır olduğunda sizi bekliyor.';

  @override
  String get settingsDebugResetOnboarding =>
      'Onboarding\'i tekrar göster (debug)';

  @override
  String get settingsCrashReportingTitle => 'Hata raporları gönder';

  @override
  String get settingsCrashReportingSubtitle =>
      'Anonim hata verileri göndererek uygulamanın geliştirilmesine yardımcı olun. Dosya içerikleri veya kişisel bilgiler asla toplanmaz.';

  @override
  String get syncTryItTitle => 'MarkdownViewer dokümanlarıyla deneyin';

  @override
  String get syncTryItBody =>
      'Bu uygulamanın kendi dokümanlarını senkronize ederek özelliği keşfedin.';

  @override
  String get syncTryItFileCount => '~30 markdown dosyası';

  @override
  String get syncTryItButton => 'Deneyin';

  @override
  String get syncRecentSyncsHeader => 'Senkronize edilmiş depolar';

  @override
  String syncRecentFileCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dosya',
      one: '1 dosya',
    );
    return '$_temp0';
  }

  @override
  String get syncRecentResync => 'Güncelle';

  @override
  String get syncRecentOpen => 'Aç';
}
