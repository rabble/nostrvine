// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'Divine';

  @override
  String get settingsTitle => 'Ayarlar';

  @override
  String get settingsSecureAccount => 'Hesabını Güvenceye Al';

  @override
  String get settingsSessionExpired => 'Oturum Sona Erdi';

  @override
  String get settingsSessionExpiredSubtitle =>
      'Tam erişimi geri almak için tekrar giriş yap';

  @override
  String get settingsCreatorAnalytics => 'İçerik Üretici Analitikleri';

  @override
  String get settingsSupportCenter => 'Destek Merkezi';

  @override
  String get settingsNotifications => 'Bildirimler';

  @override
  String get settingsContentPreferences => 'İçerik Tercihleri';

  @override
  String get settingsModerationControls => 'Moderasyon Kontrolleri';

  @override
  String get settingsBlueskyPublishing => 'Bluesky Yayınlama';

  @override
  String get settingsBlueskyPublishingSubtitle =>
      'Bluesky\'a çapraz paylaşımı yönet';

  @override
  String get settingsNostrSettings => 'Nostr Ayarları';

  @override
  String get settingsIntegratedApps => 'Entegre Uygulamalar';

  @override
  String get settingsIntegratedAppsSubtitle =>
      'Divine içinde çalışan onaylı üçüncü taraf uygulamalar';

  @override
  String get settingsExperimentalFeatures => 'Deneysel Özellikler';

  @override
  String get settingsExperimentalFeaturesSubtitle =>
      'Takılabilecek düzenlemeler—meraklıysan deneyebilirsin.';

  @override
  String get settingsLegal => 'Yasal';

  @override
  String get settingsIntegrationPermissions => 'Entegrasyon İzinleri';

  @override
  String get settingsIntegrationPermissionsSubtitle =>
      'Hatırlanan entegrasyon onaylarını gözden geçir ve iptal et';

  @override
  String settingsVersion(String version) {
    return 'Sürüm $version';
  }

  @override
  String get settingsVersionEmpty => 'Sürüm';

  @override
  String get settingsDeveloperModeAlreadyEnabled =>
      'Geliştirici modu zaten etkin';

  @override
  String get settingsDeveloperModeEnabled =>
      'Geliştirici modu etkinleştirildi!';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    return 'Geliştirici modunu etkinleştirmek için $count dokunuş daha';
  }

  @override
  String get settingsInvites => 'Davetler';

  @override
  String get settingsSwitchAccount => 'Hesap değiştir';

  @override
  String get settingsAddAnotherAccount => 'Başka hesap ekle';

  @override
  String get settingsUnsavedDraftsTitle => 'Kaydedilmemiş Taslaklar';

  @override
  String settingsUnsavedDraftsMessage(int count) {
    return '$count kaydedilmemiş taslağınız var. Hesap değiştirmek taslağınızı saklayacaktır, ancak önce yayınlamak veya gözden geçirmek isteyebilirsiniz.';
  }

  @override
  String get settingsCancel => 'İptal';

  @override
  String get settingsSwitchAnyway => 'Yine de Değiştir';

  @override
  String get settingsAppVersionLabel => 'Uygulama sürümü';

  @override
  String get settingsAppLanguage => 'Uygulama Dili';

  @override
  String settingsAppLanguageDeviceDefault(String language) {
    return '$language (cihaz varsayılanı)';
  }

  @override
  String get settingsAppLanguageTitle => 'Uygulama Dili';

  @override
  String get settingsAppLanguageDescription => 'Uygulama arayüzü için dili seç';

  @override
  String get settingsAppLanguageUseDeviceLanguage => 'Cihaz dilini kullan';

  @override
  String get settingsGeneralTitle => 'General Settings';

  @override
  String get settingsContentSafetyTitle => 'Content & Safety';

  @override
  String get generalSettingsSectionIntegrations => 'INTEGRATIONS';

  @override
  String get generalSettingsSectionViewing => 'VIEWING';

  @override
  String get generalSettingsSectionCreating => 'CREATING';

  @override
  String get generalSettingsSectionApp => 'APP';

  @override
  String get generalSettingsClosedCaptions => 'Closed Captions';

  @override
  String get generalSettingsClosedCaptionsSubtitle =>
      'Show captions when videos include them';

  @override
  String get generalSettingsVideoShape => 'Video Shape';

  @override
  String get generalSettingsVideoShapeSquareOnly => 'Square videos only';

  @override
  String get generalSettingsVideoShapeSquareAndPortrait =>
      'Square and portrait';

  @override
  String get generalSettingsVideoShapeSquareAndPortraitSubtitle =>
      'Show the full mix of Divine videos';

  @override
  String get generalSettingsVideoShapeSquareOnlySubtitle =>
      'Keep feeds in the classic square format';

  @override
  String get contentPreferencesTitle => 'İçerik Tercihleri';

  @override
  String get contentPreferencesContentFilters => 'İçerik Filtreleri';

  @override
  String get contentPreferencesContentFiltersSubtitle =>
      'İçerik uyarı filtrelerini yönet';

  @override
  String get contentPreferencesContentLanguage => 'İçerik Dili';

  @override
  String contentPreferencesContentLanguageDeviceDefault(String language) {
    return '$language (cihaz varsayılanı)';
  }

  @override
  String get contentPreferencesTagYourVideos =>
      'İzleyicilerin içeriği filtreleyebilmesi için videolarını bir dille etiketle.';

  @override
  String get contentPreferencesUseDeviceLanguage =>
      'Cihaz dilini kullan (varsayılan)';

  @override
  String get contentPreferencesAudioSharing => 'Sesimi yeniden kullanıma aç';

  @override
  String get contentPreferencesAudioSharingSubtitle =>
      'Etkinleştirildiğinde başkaları videolarındaki sesi kullanabilir';

  @override
  String get contentPreferencesAccountLabels => 'Hesap Etiketleri';

  @override
  String get contentPreferencesAccountLabelsEmpty =>
      'İçeriğini kendin etiketle';

  @override
  String get contentPreferencesAccountContentLabels =>
      'Hesap İçerik Etiketleri';

  @override
  String get contentPreferencesClearAll => 'Tümünü Temizle';

  @override
  String get contentPreferencesSelectAllThatApply =>
      'Hesabın için geçerli olanların hepsini seç';

  @override
  String get contentPreferencesDoneNoLabels => 'Bitti (Etiket Yok)';

  @override
  String contentPreferencesDoneCount(int count) {
    return 'Bitti ($count seçildi)';
  }

  @override
  String get contentPreferencesAudioInputDevice => 'Ses Giriş Cihazı';

  @override
  String get contentPreferencesAutoRecommended => 'Otomatik (önerilen)';

  @override
  String get contentPreferencesAutoSelectsBest =>
      'En iyi mikrofonu otomatik olarak seçer';

  @override
  String get contentPreferencesSelectAudioInput => 'Ses Girişi Seç';

  @override
  String get contentPreferencesUnknownMicrophone => 'Bilinmeyen Mikrofon';

  @override
  String get contentFiltersAdultContent => 'ADULT CONTENT';

  @override
  String get contentFiltersViolenceGore => 'VIOLENCE & GORE';

  @override
  String get contentFiltersSubstances => 'SUBSTANCES';

  @override
  String get contentFiltersOther => 'OTHER';

  @override
  String get contentFiltersAgeGateMessage =>
      'Verify your age in Safety & Privacy settings to unlock adult content filters';

  @override
  String get contentFiltersShow => 'Show';

  @override
  String get contentFiltersWarn => 'Warn';

  @override
  String get contentFiltersFilterOut => 'Filter Out';

  @override
  String get profileBlockedAccountNotAvailable => 'Bu hesap kullanılamıyor';

  @override
  String profileErrorPrefix(Object error) {
    return 'Hata: $error';
  }

  @override
  String get profileInvalidId => 'Geçersiz profil kimliği';

  @override
  String profileShareText(String displayName, String npub) {
    return '$displayName adlı kişiye Divine\'de göz at!\n\nhttps://divine.video/profile/$npub';
  }

  @override
  String profileShareSubject(String displayName) {
    return 'Divine\'de $displayName';
  }

  @override
  String profileShareFailed(Object error) {
    return 'Profil paylaşılamadı: $error';
  }

  @override
  String get profileEditProfile => 'Profili düzenle';

  @override
  String get profileCreatorAnalytics => 'İçerik üretici analitikleri';

  @override
  String get profileShareProfile => 'Profili paylaş';

  @override
  String get profileCopyPublicKey => 'Açık anahtarı (npub) kopyala';

  @override
  String get profileGetEmbedCode => 'Gömme kodunu al';

  @override
  String get profilePublicKeyCopied => 'Açık anahtar panoya kopyalandı';

  @override
  String get profileEmbedCodeCopied => 'Gömme kodu panoya kopyalandı';

  @override
  String get profileRefreshTooltip => 'Yenile';

  @override
  String get profileRefreshSemanticLabel => 'Profili yenile';

  @override
  String get profileMoreTooltip => 'Daha fazla';

  @override
  String get profileMoreSemanticLabel => 'Daha fazla seçenek';

  @override
  String get profileAvatarLightboxBarrierLabel => 'Avatarı kapat';

  @override
  String get profileAvatarLightboxCloseSemanticLabel =>
      'Avatar önizlemesini kapat';

  @override
  String get profileFollowingLabel => 'Takip ediliyor';

  @override
  String get profileFollowLabel => 'Takip et';

  @override
  String get profileBlockedLabel => 'Engellendi';

  @override
  String get profileFollowersLabel => 'Takipçiler';

  @override
  String get profileFollowingStatLabel => 'Takip edilen';

  @override
  String get profileVideosLabel => 'Videolar';

  @override
  String profileFollowerCountUsers(int count) {
    return '$count kullanıcı';
  }

  @override
  String profileBlockTitle(String displayName) {
    return '$displayName engellensin mi?';
  }

  @override
  String get profileBlockExplanation => 'Bir kullanıcıyı engellediğinde:';

  @override
  String get profileBlockBulletHidePosts =>
      'Gönderileri akışında görünmeyecek.';

  @override
  String get profileBlockBulletCantView =>
      'Profilini görüntüleyemeyecek, seni takip edemeyecek veya gönderilerini göremeyecek.';

  @override
  String get profileBlockBulletNoNotify =>
      'Bu değişiklik hakkında bilgilendirilmeyecek.';

  @override
  String get profileBlockBulletYouCanView =>
      'Onun profilini görüntülemeye devam edebileceksin.';

  @override
  String profileBlockConfirmButton(String displayName) {
    return '$displayName engelle';
  }

  @override
  String get profileCancelButton => 'İptal';

  @override
  String get profileLearnMore => 'Daha Fazla Bilgi';

  @override
  String profileUnblockTitle(String displayName) {
    return '$displayName engeli kaldırılsın mı?';
  }

  @override
  String get profileUnblockExplanation =>
      'Bu kullanıcının engelini kaldırdığında:';

  @override
  String get profileUnblockBulletShowPosts => 'Gönderileri akışında görünecek.';

  @override
  String get profileUnblockBulletCanView =>
      'Profilini görüntüleyebilecek, seni takip edebilecek ve gönderilerini görebilecek.';

  @override
  String get profileUnblockBulletNoNotify =>
      'Bu değişiklik hakkında bilgilendirilmeyecek.';

  @override
  String get profileLearnMoreAt => 'Daha fazla bilgi: ';

  @override
  String get profileUnblockButton => 'Engeli kaldır';

  @override
  String profileUnfollowDisplayName(String displayName) {
    return '$displayName takipten çık';
  }

  @override
  String profileBlockDisplayName(String displayName) {
    return '$displayName engelle';
  }

  @override
  String profileUnblockDisplayName(String displayName) {
    return '$displayName engelini kaldır';
  }

  @override
  String profileAddToListDisplayName(String displayName) {
    return '$displayName kişisini listeye ekle';
  }

  @override
  String get profileUserBlockedTitle => 'Kullanıcı Engellendi';

  @override
  String get profileUserBlockedContent =>
      'Bu kullanıcının içeriğini artık akışında görmeyeceksin.';

  @override
  String get profileUserBlockedUnblockHint =>
      'Profilinden veya Ayarlar > Güvenlik\'ten istediğin zaman engelini kaldırabilirsin.';

  @override
  String get profileCloseButton => 'Kapat';

  @override
  String get profileNoCollabsTitle => 'Henüz İşbirliği Yok';

  @override
  String get profileCollabsOwnEmpty =>
      'İşbirliği yaptığın videolar burada görünecek';

  @override
  String get profileCollabsOtherEmpty =>
      'İşbirliği yaptıkları videolar burada görünecek';

  @override
  String get profileErrorLoadingCollabs =>
      'İşbirliği videoları yüklenirken hata';

  @override
  String get profileNoSavedVideosTitle => 'Nothing saved yet';

  @override
  String get profileSavedOwnEmpty =>
      'Bookmark videos from the share sheet and they\'ll show up here.';

  @override
  String get profileErrorLoadingSaved => 'Error loading saved videos';

  @override
  String get profileNoCommentsOwnTitle => 'Henüz Yorum Yok';

  @override
  String get profileNoCommentsOtherTitle => 'Yorum Yok';

  @override
  String get profileCommentsOwnEmpty =>
      'Yorumların ve yanıtların burada görünecek';

  @override
  String get profileCommentsOtherEmpty =>
      'Yorumları ve yanıtları burada görünecek';

  @override
  String get profileErrorLoadingComments => 'Yorumlar yüklenirken hata';

  @override
  String get profileVideoRepliesSection => 'Video Yanıtları';

  @override
  String get profileCommentsSection => 'Yorumlar';

  @override
  String get profileEditLabel => 'Düzenle';

  @override
  String get profileLibraryLabel => 'Kütüphane';

  @override
  String get profileNoLikedVideosTitle => 'Henüz Beğenilen Video Yok';

  @override
  String get profileLikedOwnEmpty => 'Beğendiğin videolar burada görünecek';

  @override
  String get profileLikedOtherEmpty => 'Beğendikleri videolar burada görünecek';

  @override
  String get profileErrorLoadingLiked => 'Beğenilen videolar yüklenirken hata';

  @override
  String get profileNoRepostsTitle => 'Henüz Yeniden Paylaşım Yok';

  @override
  String get profileRepostsOwnEmpty =>
      'Yeniden paylaştığın videolar burada görünecek';

  @override
  String get profileRepostsOtherEmpty =>
      'Yeniden paylaştıkları videolar burada görünecek';

  @override
  String get profileErrorLoadingReposts =>
      'Yeniden paylaşılan videolar yüklenirken hata';

  @override
  String get profileLoadingTitle => 'Profil yükleniyor...';

  @override
  String get profileLoadingSubtitle => 'Bu birkaç saniye sürebilir';

  @override
  String get profileLoadingVideos => 'Videolar yükleniyor...';

  @override
  String get profileNoVideosTitle => 'Henüz Video Yok';

  @override
  String get profileNoVideosOwnSubtitle =>
      'İlk videonu paylaş ki burada görelim';

  @override
  String get profileNoVideosOtherSubtitle =>
      'Bu kullanıcı henüz video paylaşmadı';

  @override
  String profileVideoThumbnailLabel(int number) {
    return 'Video küçük resmi $number';
  }

  @override
  String get profileShowMore => 'Daha fazla göster';

  @override
  String get profileShowLess => 'Daha az göster';

  @override
  String get profileCompleteYourProfile => 'Profilini Tamamla';

  @override
  String get profileCompleteSubtitle =>
      'Başlamak için adını, biyografini ve resmini ekle';

  @override
  String get profileSetUpButton => 'Ayarla';

  @override
  String get profileVerifyingEmail => 'E-posta Doğrulanıyor...';

  @override
  String profileCheckEmailVerification(String email) {
    return 'Doğrulama bağlantısı için $email adresini kontrol et';
  }

  @override
  String get profileWaitingForVerification => 'E-posta doğrulaması bekleniyor';

  @override
  String get profileVerificationFailed => 'Doğrulama Başarısız';

  @override
  String get profilePleaseTryAgain => 'Lütfen tekrar dene';

  @override
  String get profileSecureYourAccount => 'Hesabını Güvenceye Al';

  @override
  String get profileSecureSubtitle =>
      'Hesabını her cihazdan kurtarmak için e-posta ve parola ekle';

  @override
  String get profileRetryButton => 'Tekrar Dene';

  @override
  String get profileRegisterButton => 'Kaydol';

  @override
  String get profileSessionExpired => 'Oturum Sona Erdi';

  @override
  String get profileSignInToRestore =>
      'Tam erişimi geri almak için tekrar giriş yap';

  @override
  String get profileSignInButton => 'Giriş yap';

  @override
  String get profileMaybeLaterLabel => 'Maybe Later';

  @override
  String get profileSecurePrimaryButton => 'Add Email & Password';

  @override
  String get profileCompletePrimaryButton => 'Update Your Profile';

  @override
  String get profileLoopsLabel => 'Loops';

  @override
  String get profileLikesLabel => 'Likes';

  @override
  String get profileMyLibraryLabel => 'My Library';

  @override
  String get profileMessageLabel => 'Message';

  @override
  String get profileUserFallback => 'user';

  @override
  String get profileDismissTooltip => 'Kapat';

  @override
  String get profileLinkCopied => 'Profil bağlantısı kopyalandı';

  @override
  String get profileSetupEditProfileTitle => 'Profili Düzenle';

  @override
  String get profileSetupBackLabel => 'Geri';

  @override
  String get profileSetupAboutNostr => 'Nostr Hakkında';

  @override
  String get profileSetupProfilePublished => 'Profil başarıyla yayınlandı!';

  @override
  String get profileSetupCreateNewProfile => 'Yeni profil oluşturulsun mu?';

  @override
  String get profileSetupNoExistingProfile =>
      'Rölelerinizde mevcut bir profil bulamadık. Yayınlamak yeni bir profil oluşturacak. Devam edilsin mi?';

  @override
  String get profileSetupPublishButton => 'Yayınla';

  @override
  String get profileSetupUsernameTaken =>
      'Kullanıcı adı az önce alındı. Lütfen başka birini seç.';

  @override
  String get profileSetupClaimFailed =>
      'Kullanıcı adı alınamadı. Lütfen tekrar dene.';

  @override
  String get profileSetupPublishFailed =>
      'Profil yayınlanamadı. Lütfen tekrar dene.';

  @override
  String get profileSetupNoRelaysConnected =>
      'Ağa ulaşılamadı. Bağlantını kontrol et ve tekrar dene.';

  @override
  String get profileSetupRetryLabel => 'Tekrar dene';

  @override
  String get profileSetupDisplayNameLabel => 'Görünen Ad';

  @override
  String get profileSetupDisplayNameHint => 'Seni nasıl tanısınlar?';

  @override
  String get profileSetupDisplayNameHelper =>
      'İstediğin herhangi bir ad veya etiket. Benzersiz olması gerekmez.';

  @override
  String get profileSetupDisplayNameRequired => 'Lütfen bir görünen ad gir';

  @override
  String get profileSetupBioLabel => 'Biyografi (Opsiyonel)';

  @override
  String get profileSetupBioHint => 'İnsanlara kendinden bahset...';

  @override
  String get profileSetupPublicKeyLabel => 'Açık anahtar (npub)';

  @override
  String get profileSetupUsernameLabel => 'Kullanıcı Adı (Opsiyonel)';

  @override
  String get profileSetupUsernameHint => 'kullanıcıadı';

  @override
  String get profileSetupUsernameHelper => 'Divine\'deki benzersiz kimliğin';

  @override
  String get profileSetupProfileColorLabel => 'Profil Rengi (Opsiyonel)';

  @override
  String get profileSetupSaveButton => 'Kaydet';

  @override
  String get profileSetupSavingButton => 'Kaydediliyor...';

  @override
  String get profileSetupImageUrlTitle => 'Görsel URL\'si ekle';

  @override
  String get profileSetupPictureUploaded => 'Profil resmi başarıyla yüklendi!';

  @override
  String get profileSetupImageSelectionFailed =>
      'Görsel seçimi başarısız oldu. Lütfen aşağıya bir görsel URL\'si yapıştır.';

  @override
  String get profileSetupImagesTypeGroup => 'images';

  @override
  String profileSetupCameraAccessFailed(Object error) {
    return 'Kamera erişimi başarısız: $error';
  }

  @override
  String get profileSetupGotItButton => 'Anlaşıldı';

  @override
  String profileSetupUploadFailedGeneric(Object error) {
    return 'Görsel yüklenemedi: $error';
  }

  @override
  String get profileSetupUploadNetworkError =>
      'Ağ hatası: Lütfen internet bağlantını kontrol et ve tekrar dene.';

  @override
  String get profileSetupUploadAuthError =>
      'Kimlik doğrulama hatası: Lütfen çıkış yapıp tekrar giriş yap.';

  @override
  String get profileSetupUploadFileTooLarge =>
      'Dosya çok büyük: Lütfen daha küçük bir görsel seç (maks. 10MB).';

  @override
  String get profileSetupUsernameChecking => 'Uygunluk kontrol ediliyor...';

  @override
  String get profileSetupUsernameAvailable => 'Kullanıcı adı uygun!';

  @override
  String get profileSetupUsernameTakenIndicator =>
      'Kullanıcı adı zaten alınmış';

  @override
  String get profileSetupUsernameReserved => 'Kullanıcı adı ayrılmış';

  @override
  String get profileSetupContactSupport => 'Destek ile iletişime geç';

  @override
  String get profileSetupCheckAgain => 'Tekrar kontrol et';

  @override
  String get profileSetupUsernameBurned =>
      'Bu kullanıcı adı artık kullanılamıyor';

  @override
  String get profileSetupUsernameInvalidFormat =>
      'Sadece harfler, rakamlar ve tire kullanılabilir';

  @override
  String get profileSetupUsernameInvalidLength =>
      'Kullanıcı adı 3-20 karakter olmalı';

  @override
  String get profileSetupUsernameNetworkError =>
      'Uygunluk kontrol edilemedi. Lütfen tekrar dene.';

  @override
  String get profileSetupUsernameInvalidFormatGeneric =>
      'Geçersiz kullanıcı adı formatı';

  @override
  String get profileSetupUsernameCheckFailed => 'Uygunluk kontrolü başarısız';

  @override
  String get profileSetupUsernameReservedTitle => 'Kullanıcı adı ayrılmış';

  @override
  String profileSetupUsernameReservedBody(String username) {
    return '$username adı ayrılmış. Neden senin olması gerektiğini anlat.';
  }

  @override
  String get profileSetupUsernameReservedHint =>
      'örn. Marka adım, sahne adım vb.';

  @override
  String get profileSetupUsernameReservedCheckHint =>
      'Desteğe zaten başvurdun mu? Sana verilip verilmediğini görmek için \"Tekrar kontrol et\"e dokun.';

  @override
  String get profileSetupSupportRequestSent =>
      'Destek talebi gönderildi! Kısa sürede döneriz.';

  @override
  String get profileSetupCouldntOpenEmail =>
      'E-posta açılamadı. Şuraya gönder: names@divine.video';

  @override
  String get profileSetupSendRequest => 'Talebi gönder';

  @override
  String get profileSetupPickColorTitle => 'Bir renk seç';

  @override
  String get profileSetupSelectButton => 'Seç';

  @override
  String get profileSetupUseOwnNip05 => 'Kendi NIP-05 adresini kullan';

  @override
  String get profileSetupNip05AddressLabel => 'NIP-05 Adresi';

  @override
  String get profileSetupExternalNip05InvalidFormat =>
      'Invalid NIP-05 format (e.g., name@domain.com)';

  @override
  String get profileSetupExternalNip05DivineDomain =>
      'Use the username field above for divine.video';

  @override
  String get profileSetupProfilePicturePreview => 'Profil resmi önizlemesi';

  @override
  String get nostrInfoIntroBuiltOn => 'DiVine Nostr üzerine kuruludur,';

  @override
  String get nostrInfoIntroDescription =>
      ' tek bir şirkete veya platforma bağlı kalmadan insanların çevrimiçi iletişim kurmasını sağlayan, sansüre dayanıklı açık bir protokoldür. ';

  @override
  String get nostrInfoIntroIdentity =>
      'Divine\'e kaydolduğunda yeni bir Nostr kimliği alırsın.';

  @override
  String get nostrInfoOwnership =>
      'Nostr, içeriğine, kimliğine ve sosyal grafiğine sahip olmana izin verir ve bunları birçok uygulamada kullanabilirsin. Sonuç: daha fazla seçenek, daha az kilitlenme ve daha sağlıklı, dayanıklı bir sosyal internet.';

  @override
  String get nostrInfoLingo => 'Nostr terimleri:';

  @override
  String get nostrInfoNpubLabel => 'npub:';

  @override
  String get nostrInfoNpubDescription =>
      ' Genel Nostr adresin. Paylaşmak güvenlidir; başkalarının seni bulmasını, takip etmesini veya mesaj göndermesini sağlar.';

  @override
  String get nostrInfoNsecLabel => 'nsec:';

  @override
  String get nostrInfoNsecDescription =>
      ' Özel anahtarın ve sahiplik kanıtın. Nostr kimliğin üzerinde tam kontrol verir, bu yüzden ';

  @override
  String get nostrInfoNsecWarning => 'her zaman gizli tut!';

  @override
  String get nostrInfoUsernameLabel => 'Nostr kullanıcı adı:';

  @override
  String get nostrInfoUsernameDescription =>
      ' Npub\'ına bağlanan insan tarafından okunabilir bir ad (örneğin @ad.divine.video). Nostr kimliğini tanımayı ve doğrulamayı kolaylaştırır, tıpkı bir e-posta adresi gibi.';

  @override
  String get nostrInfoLearnMoreAt => 'Daha fazla bilgi: ';

  @override
  String get nostrInfoGotIt => 'Anlaşıldı!';

  @override
  String get profileTabRefreshTooltip => 'Yenile';

  @override
  String get videoGridRefreshLabel => 'Daha fazla video aranıyor';

  @override
  String get videoGridOptionsTitle => 'Video Seçenekleri';

  @override
  String get videoGridEditVideo => 'Videoyu Düzenle';

  @override
  String get videoGridEditVideoSubtitle =>
      'Başlık, açıklama ve etiketleri güncelle';

  @override
  String get videoGridDeleteVideo => 'Videoyu Sil';

  @override
  String get videoGridDeleteVideoSubtitle => 'Bu içeriği kalıcı olarak kaldır';

  @override
  String get videoGridDeleteConfirmTitle => 'Videoyu Sil';

  @override
  String get videoGridDeleteConfirmMessage =>
      'Bu videoyu silmek istediğinden emin misin?';

  @override
  String get videoGridDeleteConfirmNote =>
      'Bu işlem tüm rölelere bir silme isteği (NIP-09) gönderir. Bazı röleler içeriği saklamaya devam edebilir.';

  @override
  String get videoGridDeleteCancel => 'İptal';

  @override
  String get videoGridDeleteConfirm => 'Sil';

  @override
  String get videoGridDeletingContent => 'İçerik siliniyor...';

  @override
  String get videoGridDeleteSuccess => 'Silme isteği başarıyla gönderildi';

  @override
  String videoGridDeleteFailure(Object error) {
    return 'İçerik silinemedi: $error';
  }

  @override
  String get exploreTabClassics => 'Klasikler';

  @override
  String get exploreTabNew => 'Yeni';

  @override
  String get exploreTabPopular => 'Popüler';

  @override
  String get exploreTabCategories => 'Kategoriler';

  @override
  String get exploreTabForYou => 'Sana Özel';

  @override
  String get exploreTabLists => 'Listeler';

  @override
  String get exploreTabIntegratedApps => 'Entegre Uygulamalar';

  @override
  String get exploreNoVideosAvailable => 'Hiç video yok';

  @override
  String exploreErrorPrefix(Object error) {
    return 'Hata: $error';
  }

  @override
  String get exploreDiscoverLists => 'Listeleri Keşfet';

  @override
  String get exploreAboutLists => 'Listeler Hakkında';

  @override
  String get exploreAboutListsDescription =>
      'Listeler, Divine içeriğini iki şekilde düzenlemene ve derlemene yardımcı olur:';

  @override
  String get explorePeopleLists => 'Kişi Listeleri';

  @override
  String get explorePeopleListsDescription =>
      'İçerik üretici gruplarını takip et ve en son videolarını gör';

  @override
  String get exploreVideoLists => 'Video Listeleri';

  @override
  String get exploreVideoListsDescription =>
      'Sonra izlemek için favori videolarından oynatma listeleri oluştur';

  @override
  String get exploreMyLists => 'Listelerim';

  @override
  String get exploreSubscribedLists => 'Abone Olunan Listeler';

  @override
  String exploreErrorLoadingLists(Object error) {
    return 'Listeler yüklenirken hata: $error';
  }

  @override
  String exploreNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count yeni video',
      one: '1 yeni video',
    );
    return '$_temp0';
  }

  @override
  String exploreLoadNewVideosLabel(int count) {
    return '$count yeni video yükle';
  }

  @override
  String get videoPlayerLoadingVideo => 'Video yükleniyor...';

  @override
  String get videoPlayerPlayVideo => 'Videoyu oynat';

  @override
  String get videoPlayerMute => 'Videoyu sessize al';

  @override
  String get videoPlayerUnmute => 'Videonun sesini aç';

  @override
  String get videoPlayerEditVideo => 'Videoyu düzenle';

  @override
  String get videoPlayerEditVideoTooltip => 'Videoyu düzenle';

  @override
  String get contentWarningLabel => 'İçerik Uyarısı';

  @override
  String get contentWarningNudity => 'Çıplaklık';

  @override
  String get contentWarningSexualContent => 'Cinsel İçerik';

  @override
  String get contentWarningPornography => 'Pornografi';

  @override
  String get contentWarningGraphicMedia => 'Açık Görüntüler';

  @override
  String get contentWarningViolence => 'Şiddet';

  @override
  String get contentWarningSelfHarm => 'Kendine Zarar Verme';

  @override
  String get contentWarningDrugUse => 'Uyuşturucu Kullanımı';

  @override
  String get contentWarningAlcohol => 'Alkol';

  @override
  String get contentWarningTobacco => 'Tütün';

  @override
  String get contentWarningGambling => 'Kumar';

  @override
  String get contentWarningProfanity => 'Küfür';

  @override
  String get contentWarningFlashingLights => 'Yanıp Sönen Işıklar';

  @override
  String get contentWarningAiGenerated => 'Yapay Zeka Üretimi';

  @override
  String get contentWarningSpoiler => 'Spoiler';

  @override
  String get contentWarningSensitiveContent => 'Hassas İçerik';

  @override
  String get contentWarningDescNudity =>
      'Çıplaklık veya kısmi çıplaklık içerir';

  @override
  String get contentWarningDescSexual => 'Cinsel içerik barındırır';

  @override
  String get contentWarningDescPorn => 'Açık pornografik içerik barındırır';

  @override
  String get contentWarningDescGraphicMedia =>
      'Açık veya rahatsız edici görüntüler içerir';

  @override
  String get contentWarningDescViolence => 'Şiddet içeriği barındırır';

  @override
  String get contentWarningDescSelfHarm =>
      'Kendine zarar verme referansları içerir';

  @override
  String get contentWarningDescDrugs =>
      'Uyuşturucuyla ilgili içerik barındırır';

  @override
  String get contentWarningDescAlcohol => 'Alkolle ilgili içerik barındırır';

  @override
  String get contentWarningDescTobacco => 'Tütünle ilgili içerik barındırır';

  @override
  String get contentWarningDescGambling => 'Kumarla ilgili içerik barındırır';

  @override
  String get contentWarningDescProfanity => 'Ağır dil içerir';

  @override
  String get contentWarningDescFlashingLights =>
      'Yanıp sönen ışıklar içerir (fotosensitivite uyarısı)';

  @override
  String get contentWarningDescAiGenerated =>
      'Bu içerik yapay zeka tarafından oluşturulmuştur';

  @override
  String get contentWarningDescSpoiler => 'Spoiler içerir';

  @override
  String get contentWarningDescContentWarning =>
      'İçerik üretici bunu hassas olarak işaretledi';

  @override
  String get contentWarningDescDefault =>
      'İçerik üretici bu içeriği işaretledi';

  @override
  String get contentWarningDetailsTitle => 'İçerik Uyarıları';

  @override
  String get contentWarningDetailsSubtitle =>
      'İçerik üretici bu etiketleri uyguladı:';

  @override
  String get contentWarningManageFilters => 'İçerik filtrelerini yönet';

  @override
  String get contentWarningViewAnyway => 'Yine de Görüntüle';

  @override
  String get contentWarningReportContentTooltip => 'Report Content';

  @override
  String get contentWarningBlockUserTooltip => 'Block User';

  @override
  String get contentWarningBlockedTitle => 'Content Blocked';

  @override
  String get contentWarningBlockedPolicy =>
      'This content has been blocked due to policy violations.';

  @override
  String get contentWarningNoticeTitle => 'Content Notice';

  @override
  String get contentWarningPotentiallyHarmfulTitle =>
      'Potentially Harmful Content';

  @override
  String get contentWarningView => 'View';

  @override
  String get contentWarningReportAction => 'Report';

  @override
  String get contentWarningHideAllLikeThis => 'Bunun gibi tüm içerikleri gizle';

  @override
  String get contentWarningNoFilterYet =>
      'Bu uyarı için henüz kayıtlı filtre yok.';

  @override
  String get contentWarningHiddenConfirmation =>
      'Bundan sonra böyle gönderileri gizleyeceğiz.';

  @override
  String get videoErrorNotFound => 'Video bulunamadı';

  @override
  String get videoErrorNetwork => 'Ağ hatası';

  @override
  String get videoErrorTimeout => 'Yükleme zaman aşımı';

  @override
  String get videoErrorFormat =>
      'Video format hatası\n(Tekrar dene veya farklı tarayıcı kullan)';

  @override
  String get videoErrorUnsupportedFormat => 'Desteklenmeyen video formatı';

  @override
  String get videoErrorPlayback => 'Video oynatma hatası';

  @override
  String get videoErrorAgeRestricted => 'Yaş kısıtlamalı içerik';

  @override
  String get videoErrorVerifyAge => 'Yaşı Doğrula';

  @override
  String get videoErrorRetry => 'Tekrar Dene';

  @override
  String get videoErrorContentRestricted => 'İçerik kısıtlandı';

  @override
  String get videoErrorContentRestrictedBody =>
      'Bu video röle tarafından kısıtlanmış.';

  @override
  String get videoErrorVerifyAgeBody =>
      'Bu videoyu görüntülemek için yaşını doğrula.';

  @override
  String get videoErrorSkip => 'Atla';

  @override
  String get videoErrorVerifyAgeButton => 'Yaşı doğrula';

  @override
  String get videoFollowButtonFollowing => 'Takip ediliyor';

  @override
  String get videoFollowButtonFollow => 'Takip et';

  @override
  String get audioAttributionOriginalSound => 'Orijinal ses';

  @override
  String videoInspiredByAttribution(String creatorName) {
    return '@$creatorName tarafından ilham alındı';
  }

  @override
  String videoCollaboratorWithOne(String name) {
    return '@$name ile';
  }

  @override
  String videoCollaboratorWithMore(String name, int count) {
    return '@$name +$count ile';
  }

  @override
  String videoCollaboratorCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count işbirlikçi',
      one: '1 işbirlikçi',
    );
    return '$_temp0. Profili görmek için dokun.';
  }

  @override
  String get listAttributionFallback => 'Liste';

  @override
  String get shareVideoLabel => 'Videoyu paylaş';

  @override
  String sharePostSharedWith(String recipientName) {
    return 'Gönderi $recipientName ile paylaşıldı';
  }

  @override
  String get shareFailedToSend => 'Video gönderilemedi';

  @override
  String get shareAddedToBookmarks => 'Yer imlerine eklendi';

  @override
  String get shareRemovedFromBookmarks => 'Yer imlerinden kaldırıldı';

  @override
  String get shareFailedToAddBookmark => 'Yer imi eklenemedi';

  @override
  String get shareFailedToRemoveBookmark => 'Yer imi kaldırılamadı';

  @override
  String get shareActionFailed => 'İşlem başarısız';

  @override
  String get shareWithTitle => 'Şununla paylaş';

  @override
  String get shareFindPeople => 'Kişi bul';

  @override
  String get shareFindPeopleMultiline => 'Kişi\nbul';

  @override
  String get shareSent => 'Gönderildi';

  @override
  String get shareContactFallback => 'Kişi';

  @override
  String get shareUserFallback => 'Kullanıcı';

  @override
  String shareSendingTo(String name) {
    return '$name kişisine gönderiliyor';
  }

  @override
  String get shareMessageHint => 'Opsiyonel mesaj ekle...';

  @override
  String get videoActionUnlike => 'Beğenmekten vazgeç';

  @override
  String get videoActionLike => 'Videoyu beğen';

  @override
  String get videoActionAutoLabel => 'Otomatik';

  @override
  String get videoActionLikeLabel => 'Like';

  @override
  String get videoActionReplyLabel => 'Reply';

  @override
  String get videoActionRepostLabel => 'Repost';

  @override
  String get videoActionShareLabel => 'Share';

  @override
  String get videoActionAboutLabel => 'About';

  @override
  String get videoActionEnableAutoAdvance => 'Otomatik ilerlemeyi etkinleştir';

  @override
  String get videoActionDisableAutoAdvance =>
      'Otomatik ilerlemeyi devre dışı bırak';

  @override
  String get videoActionRemoveRepost => 'Yeniden paylaşımı kaldır';

  @override
  String get videoActionRepost => 'Videoyu yeniden paylaş';

  @override
  String get videoActionViewComments => 'Yorumları görüntüle';

  @override
  String get videoActionMoreOptions => 'Daha fazla seçenek';

  @override
  String get videoActionHideSubtitles => 'Altyazıları gizle';

  @override
  String get videoActionShowSubtitles => 'Altyazıları göster';

  @override
  String get videoOverlayOpenMetadataFromTitle => 'Open video details';

  @override
  String get videoOverlayOpenMetadataFromDescription => 'Open video details';

  @override
  String videoDescriptionLoops(String count) {
    return '$count döngü';
  }

  @override
  String videoFeedLoopCountLine(String compactCount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'döngüler',
      one: 'döngü',
    );
    return '$compactCount $_temp0';
  }

  @override
  String get metadataBadgeNotDivine => 'Divine Değil';

  @override
  String get metadataBadgeHumanMade => 'İnsan Yapımı';

  @override
  String get metadataSoundsLabel => 'Sesler';

  @override
  String get metadataOriginalSound => 'Orijinal ses';

  @override
  String get metadataVerificationLabel => 'Doğrulama';

  @override
  String get metadataDeviceAttestation => 'Cihaz tasdik';

  @override
  String get metadataProofManifest => 'Kanıt manifestosu';

  @override
  String get metadataCreatorLabel => 'İçerik üretici';

  @override
  String get metadataCollaboratorsLabel => 'İşbirlikçiler';

  @override
  String get metadataInspiredByLabel => 'İlham alındı';

  @override
  String get metadataRepostedByLabel => 'Yeniden paylaşan';

  @override
  String metadataLoopsLabel(int count) {
    return 'Döngüler';
  }

  @override
  String get metadataLikesLabel => 'Beğeniler';

  @override
  String get metadataCommentsLabel => 'Yorumlar';

  @override
  String get metadataRepostsLabel => 'Yeniden Paylaşımlar';

  @override
  String metadataPostedDateSemantics(String date) {
    return '$date tarihinde paylaşıldı';
  }

  @override
  String get devOptionsTitle => 'Geliştirici Seçenekleri';

  @override
  String get devOptionsPageLoadTimes => 'Sayfa Yükleme Süreleri';

  @override
  String get devOptionsNoPageLoads =>
      'Henüz sayfa yüklemesi kaydedilmedi.\nZamanlama verisini görmek için uygulamada gezin.';

  @override
  String devOptionsPageLoadVisible(String visibleMs, String dataMs) {
    return 'Görünür: ${visibleMs}ms  |  Veri: ${dataMs}ms';
  }

  @override
  String get devOptionsSlowestScreens => 'En Yavaş Ekranlar';

  @override
  String get devOptionsVideoPlaybackFormat => 'Video Oynatma Formatı';

  @override
  String get devOptionsSwitchEnvironmentTitle => 'Ortam Değiştirilsin mi?';

  @override
  String devOptionsSwitchEnvironmentMessage(String envName) {
    return '$envName ortamına geçilsin mi?\n\nBu işlem önbelleğe alınmış video verisini temizleyecek ve yeni röleye bağlanacaktır.';
  }

  @override
  String get devOptionsCancel => 'İptal';

  @override
  String get devOptionsSwitch => 'Değiştir';

  @override
  String devOptionsSwitchedTo(String envName) {
    return '$envName ortamına geçildi';
  }

  @override
  String devOptionsSwitchedFormat(String formatName) {
    return '$formatName formatına geçildi — önbellek temizlendi';
  }

  @override
  String get featureFlagTitle => 'Özellik Bayrakları';

  @override
  String get featureFlagResetAllTooltip =>
      'Tüm bayrakları varsayılanlara sıfırla';

  @override
  String get featureFlagResetToDefault => 'Varsayılana sıfırla';

  @override
  String get featureFlagAppRecovery => 'Uygulama Kurtarma';

  @override
  String get featureFlagAppRecoveryDescription =>
      'Uygulama çöküyor veya tuhaf davranıyorsa, önbelleği temizlemeyi dene.';

  @override
  String get featureFlagClearAllCache => 'Tüm Önbelleği Temizle';

  @override
  String get featureFlagCacheInfo => 'Önbellek Bilgisi';

  @override
  String get featureFlagClearCacheTitle => 'Tüm Önbellek Temizlensin mi?';

  @override
  String get featureFlagClearCacheMessage =>
      'Bu işlem önbelleğe alınmış tüm verileri temizleyecektir:\n• Bildirimler\n• Kullanıcı profilleri\n• Yer imleri\n• Geçici dosyalar\n\nTekrar giriş yapman gerekecek. Devam edilsin mi?';

  @override
  String get featureFlagClearCache => 'Önbelleği Temizle';

  @override
  String get featureFlagClearingCache => 'Önbellek temizleniyor...';

  @override
  String get featureFlagSuccess => 'Başarılı';

  @override
  String get featureFlagError => 'Hata';

  @override
  String get featureFlagClearCacheSuccess =>
      'Önbellek başarıyla temizlendi. Lütfen uygulamayı yeniden başlat.';

  @override
  String get featureFlagClearCacheFailure =>
      'Bazı önbellek öğeleri temizlenemedi. Ayrıntılar için günlükleri kontrol et.';

  @override
  String get featureFlagOk => 'Tamam';

  @override
  String get featureFlagCacheInformation => 'Önbellek Bilgisi';

  @override
  String featureFlagTotalCacheSize(String size) {
    return 'Toplam önbellek boyutu: $size';
  }

  @override
  String get featureFlagCacheIncludes =>
      'Önbellek şunları içerir:\n• Bildirim geçmişi\n• Kullanıcı profil verileri\n• Video küçük resimleri\n• Geçici dosyalar\n• Veritabanı dizinleri';

  @override
  String get relaySettingsTitle => 'Röleler';

  @override
  String get relaySettingsInfoTitle =>
      'Divine açık bir sistemdir - bağlantılarını sen kontrol edersin';

  @override
  String get relaySettingsInfoDescription =>
      'Bu röleler içeriğini merkeziyetsiz Nostr ağı üzerinde dağıtır. İstediğin kadar röle ekleyebilir veya kaldırabilirsin.';

  @override
  String get relaySettingsLearnMoreNostr => 'Nostr hakkında daha fazla bilgi →';

  @override
  String get relaySettingsFindPublicRelays =>
      'Herkese açık röleleri nostr.co.uk adresinde bul →';

  @override
  String get relaySettingsAppNotFunctional => 'Uygulama Çalışmıyor';

  @override
  String get relaySettingsRequiresRelay =>
      'Divine, videoları yüklemek, içerik paylaşmak ve veriyi senkronize etmek için en az bir röleye ihtiyaç duyar.';

  @override
  String get relaySettingsRestoreDefaultRelay => 'Varsayılan Röleyi Geri Yükle';

  @override
  String get relaySettingsAddCustomRelay => 'Özel Röle Ekle';

  @override
  String get relaySettingsAddRelay => 'Röle Ekle';

  @override
  String get relaySettingsRetry => 'Tekrar Dene';

  @override
  String get relaySettingsNoStats => 'Henüz istatistik mevcut değil';

  @override
  String get relaySettingsConnection => 'Bağlantı';

  @override
  String get relaySettingsConnected => 'Bağlı';

  @override
  String get relaySettingsDisconnected => 'Bağlantı Kesildi';

  @override
  String get relaySettingsSessionDuration => 'Oturum Süresi';

  @override
  String get relaySettingsLastConnected => 'Son Bağlantı';

  @override
  String get relaySettingsDisconnectedLabel => 'Bağlantı Kesildi';

  @override
  String get relaySettingsReason => 'Sebep';

  @override
  String get relaySettingsActiveSubscriptions => 'Aktif Abonelikler';

  @override
  String get relaySettingsTotalSubscriptions => 'Toplam Abonelikler';

  @override
  String get relaySettingsEventsReceived => 'Alınan Olaylar';

  @override
  String get relaySettingsEventsSent => 'Gönderilen Olaylar';

  @override
  String get relaySettingsRequestsThisSession => 'Bu Oturumdaki İstekler';

  @override
  String get relaySettingsFailedRequests => 'Başarısız İstekler';

  @override
  String relaySettingsLastError(String error) {
    return 'Son Hata: $error';
  }

  @override
  String get relaySettingsLoadingRelayInfo => 'Röle bilgisi yükleniyor...';

  @override
  String get relaySettingsAboutRelay => 'Röle Hakkında';

  @override
  String get relaySettingsSupportedNips => 'Desteklenen NIP\'ler';

  @override
  String get relaySettingsSoftware => 'Yazılım';

  @override
  String get relaySettingsViewWebsite => 'Web Sitesini Görüntüle';

  @override
  String get relaySettingsRemoveRelayTitle => 'Röle Kaldırılsın mı?';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return 'Bu röleyi kaldırmak istediğinden emin misin?\n\n$relayUrl';
  }

  @override
  String get relaySettingsCancel => 'İptal';

  @override
  String get relaySettingsRemove => 'Kaldır';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return 'Röle kaldırıldı: $relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay => 'Röle kaldırılamadı';

  @override
  String get relaySettingsForcingReconnection =>
      'Röle yeniden bağlantısı zorlanıyor...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    return '$count röleye bağlandı!';
  }

  @override
  String get relaySettingsFailedToConnectCheck =>
      'Rölelere bağlanılamadı. Lütfen ağ bağlantını kontrol et.';

  @override
  String get relaySettingsAddRelayTitle => 'Röle Ekle';

  @override
  String get relaySettingsAddRelayPrompt =>
      'Eklemek istediğin rölenin WebSocket URL\'sini gir:';

  @override
  String get relaySettingsBrowsePublicRelays =>
      'Herkese açık rölelere nostr.co.uk adresinden göz at';

  @override
  String get relaySettingsAdd => 'Ekle';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return 'Röle eklendi: $relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay =>
      'Röle eklenemedi. Lütfen URL\'yi kontrol et ve tekrar dene.';

  @override
  String get relaySettingsInvalidUrl =>
      'Röle URL\'si wss:// veya ws:// ile başlamalı';

  @override
  String get relaySettingsInsecureUrl =>
      'Relay URL must use wss:// (ws:// is allowed only for localhost)';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return 'Varsayılan röle geri yüklendi: $defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault =>
      'Varsayılan röle geri yüklenemedi. Lütfen ağ bağlantını kontrol et.';

  @override
  String get relaySettingsCouldNotOpenBrowser => 'Tarayıcı açılamadı';

  @override
  String get relaySettingsFailedToOpenLink => 'Bağlantı açılamadı';

  @override
  String get relaySettingsExternalRelay => 'External relay';

  @override
  String get relaySettingsNotConnected => 'Not connected';

  @override
  String relaySettingsDisconnectedAgo(String duration) {
    return 'Disconnected $duration ago';
  }

  @override
  String relaySettingsSubscriptionsSummary(int count) {
    return '$count subs';
  }

  @override
  String relaySettingsEventsSummary(String count) {
    return '$count events';
  }

  @override
  String relaySettingsTimeAgo(String duration) {
    return '$duration ago';
  }

  @override
  String get nostrSettingsIntro =>
      'Divine uses the Nostr protocol for decentralized publishing. Your content lives on relays you choose, and your keys are your identity.';

  @override
  String get nostrSettingsSectionNetwork => 'Network';

  @override
  String get nostrSettingsSectionAccount => 'Account';

  @override
  String get nostrSettingsSectionDangerZone => 'Danger Zone';

  @override
  String get nostrSettingsRelays => 'Relays';

  @override
  String get nostrSettingsRelaysSubtitle => 'Manage Nostr relay connections';

  @override
  String get nostrSettingsRelayDiagnostics => 'Relay Diagnostics';

  @override
  String get nostrSettingsRelayDiagnosticsSubtitle =>
      'Debug relay connectivity and network issues';

  @override
  String get nostrSettingsMediaServers => 'Media Servers';

  @override
  String get nostrSettingsMediaServersSubtitle =>
      'Configure Blossom upload servers';

  @override
  String get nostrSettingsDeveloperOptions => 'Developer Options';

  @override
  String get nostrSettingsDeveloperOptionsSubtitle =>
      'Environment switcher and debug settings';

  @override
  String get nostrSettingsExperimentalFeaturesSubtitle =>
      'Toggle feature flags that may hiccup.';

  @override
  String get nostrSettingsKeyManagement => 'Key Management';

  @override
  String get nostrSettingsKeyManagementSubtitle =>
      'Export, backup, and restore your Nostr keys';

  @override
  String get nostrSettingsRemoveKeys => 'Remove Keys from Device';

  @override
  String get nostrSettingsRemoveKeysSubtitle =>
      'Delete your private key from this device only. Your content stays on relays, but you\'ll need your nsec backup to access your account again.';

  @override
  String get nostrSettingsCouldNotRemoveKeys =>
      'Could not remove keys from this device. Please try again.';

  @override
  String nostrSettingsFailedToRemoveKeys(String error) {
    return 'Failed to remove keys: $error';
  }

  @override
  String get nostrSettingsDeleteAccount => 'Delete Account and Data';

  @override
  String get nostrSettingsDeleteAccountSubtitle =>
      'PERMANENTLY delete your account and ALL content from Nostr relays. This cannot be undone.';

  @override
  String get relayDiagnosticTitle => 'Röle Tanılamaları';

  @override
  String get relayDiagnosticRefreshTooltip => 'Tanılamaları yenile';

  @override
  String relayDiagnosticLastRefresh(String time) {
    return 'Son yenileme: $time';
  }

  @override
  String get relayDiagnosticRelayStatus => 'Röle Durumu';

  @override
  String get relayDiagnosticInitialized => 'Başlatıldı';

  @override
  String get relayDiagnosticReady => 'Hazır';

  @override
  String get relayDiagnosticNotInitialized => 'Başlatılmadı';

  @override
  String get relayDiagnosticDatabaseEvents => 'Veritabanı Olayları';

  @override
  String get relayDiagnosticActiveSubscriptions => 'Aktif Abonelikler';

  @override
  String get relayDiagnosticExternalRelays => 'Harici Röleler';

  @override
  String get relayDiagnosticConfigured => 'Yapılandırıldı';

  @override
  String relayDiagnosticRelayCount(int count) {
    return '$count röle';
  }

  @override
  String get relayDiagnosticConnectedLabel => 'Bağlı';

  @override
  String relayDiagnosticConnectedRatio(int connected, int total) {
    return '$connected/$total';
  }

  @override
  String get relayDiagnosticVideoEvents => 'Video Olayları';

  @override
  String get relayDiagnosticHomeFeed => 'Ana Akış';

  @override
  String relayDiagnosticVideosCount(int count) {
    return '$count video';
  }

  @override
  String get relayDiagnosticDiscovery => 'Keşif';

  @override
  String get relayDiagnosticLoading => 'Yükleniyor';

  @override
  String get relayDiagnosticYes => 'Evet';

  @override
  String get relayDiagnosticNo => 'Hayır';

  @override
  String get relayDiagnosticTestDirectQuery => 'Doğrudan Sorguyu Test Et';

  @override
  String get relayDiagnosticNetworkConnectivity => 'Ağ Bağlantısı';

  @override
  String get relayDiagnosticRunNetworkTest => 'Ağ Testini Çalıştır';

  @override
  String get relayDiagnosticBlossomServer => 'Blossom Sunucusu';

  @override
  String get relayDiagnosticTestAllEndpoints => 'Tüm Uç Noktaları Test Et';

  @override
  String get relayDiagnosticStatus => 'Durum';

  @override
  String get relayDiagnosticUrl => 'URL';

  @override
  String get relayDiagnosticError => 'Hata';

  @override
  String get relayDiagnosticFunnelCakeApi => 'FunnelCake API';

  @override
  String get relayDiagnosticBaseUrl => 'Temel URL';

  @override
  String get relayDiagnosticSummary => 'Özet';

  @override
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  ) {
    return '$successCount/$totalCount başarılı (ort. ${avgMs}ms)';
  }

  @override
  String get relayDiagnosticRetestAll => 'Hepsini Yeniden Test Et';

  @override
  String get relayDiagnosticRetrying => 'Yeniden deneniyor...';

  @override
  String get relayDiagnosticRetryConnection => 'Bağlantıyı Yeniden Dene';

  @override
  String get relayDiagnosticTroubleshooting => 'Sorun Giderme';

  @override
  String get relayDiagnosticTroubleshootingGuide =>
      '• Yeşil durum = Bağlı ve çalışıyor\n• Kırmızı durum = Bağlantı başarısız\n• Ağ testi başarısız olursa, internet bağlantısını kontrol et\n• Röleler yapılandırılmış ancak bağlı değilse \"Bağlantıyı Yeniden Dene\"ye dokun\n• Hata ayıklama için bu ekranın ekran görüntüsünü al';

  @override
  String get relayDiagnosticAllEndpointsHealthy =>
      'Tüm REST uç noktaları sağlıklı!';

  @override
  String get relayDiagnosticSomeEndpointsFailed =>
      'Bazı REST uç noktaları başarısız oldu - ayrıntıları yukarıda gör';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    return 'Veritabanında $count video olayı bulundu';
  }

  @override
  String relayDiagnosticQueryFailed(String error) {
    return 'Sorgu başarısız: $error';
  }

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    return '$count röleye bağlandı!';
  }

  @override
  String get relayDiagnosticFailedToConnect => 'Hiçbir röleye bağlanılamadı';

  @override
  String relayDiagnosticConnectionRetryFailed(String error) {
    return 'Bağlantı yeniden denemesi başarısız: $error';
  }

  @override
  String get relayDiagnosticConnectedAuthenticated =>
      'Bağlı ve Kimlik Doğrulandı';

  @override
  String get relayDiagnosticConnectedOnly => 'Bağlı';

  @override
  String get relayDiagnosticNotConnected => 'Bağlı değil';

  @override
  String get relayDiagnosticNoRelaysConfigured => 'Yapılandırılmış röle yok';

  @override
  String get relayDiagnosticFailed => 'Başarısız';

  @override
  String get notificationSettingsTitle => 'Bildirimler';

  @override
  String get notificationSettingsResetTooltip => 'Varsayılanlara sıfırla';

  @override
  String get notificationSettingsTypes => 'Bildirim Türleri';

  @override
  String get notificationSettingsLikes => 'Beğeniler';

  @override
  String get notificationSettingsLikesSubtitle =>
      'Biri videolarını beğendiğinde';

  @override
  String get notificationSettingsComments => 'Yorumlar';

  @override
  String get notificationSettingsCommentsSubtitle =>
      'Biri videolarına yorum yaptığında';

  @override
  String get notificationSettingsFollows => 'Takipler';

  @override
  String get notificationSettingsFollowsSubtitle => 'Biri seni takip ettiğinde';

  @override
  String get notificationSettingsMentions => 'Bahsetmeler';

  @override
  String get notificationSettingsMentionsSubtitle => 'Senden bahsedildiğinde';

  @override
  String get notificationSettingsReposts => 'Yeniden Paylaşımlar';

  @override
  String get notificationSettingsRepostsSubtitle =>
      'Biri videolarını yeniden paylaştığında';

  @override
  String get notificationSettingsSystem => 'Sistem';

  @override
  String get notificationSettingsSystemSubtitle =>
      'Uygulama güncellemeleri ve sistem mesajları';

  @override
  String get notificationSettingsPushNotificationsSection =>
      'Anlık Bildirimler';

  @override
  String get notificationSettingsPushNotifications => 'Anlık Bildirimler';

  @override
  String get notificationSettingsPushNotificationsSubtitle =>
      'Uygulama kapalıyken bildirim al';

  @override
  String get notificationSettingsSound => 'Ses';

  @override
  String get notificationSettingsSoundSubtitle => 'Bildirimler için ses çal';

  @override
  String get notificationSettingsVibration => 'Titreşim';

  @override
  String get notificationSettingsVibrationSubtitle =>
      'Bildirimler için titreşim';

  @override
  String get notificationSettingsActions => 'İşlemler';

  @override
  String get notificationSettingsMarkAllAsRead =>
      'Tümünü Okundu Olarak İşaretle';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle =>
      'Tüm bildirimleri okundu olarak işaretle';

  @override
  String get notificationSettingsAllMarkedAsRead =>
      'Tüm bildirimler okundu olarak işaretlendi';

  @override
  String get notificationSettingsResetToDefaults =>
      'Ayarlar varsayılanlara sıfırlandı';

  @override
  String get notificationSettingsAbout => 'Bildirimler Hakkında';

  @override
  String get notificationSettingsAboutDescription =>
      'Bildirimler Nostr protokolüyle desteklenir. Gerçek zamanlı güncellemeler Nostr rölelerine olan bağlantına bağlıdır. Bazı bildirimler gecikebilir.';

  @override
  String get safetySettingsTitle => 'Güvenlik ve Gizlilik';

  @override
  String get safetySettingsLabel => 'AYARLAR';

  @override
  String get safetySettingsWhatYouSee => 'WHAT YOU SEE';

  @override
  String get safetySettingsWhatYouPublish => 'WHAT YOU PUBLISH';

  @override
  String get safetySettingsShowDivineHostedOnly =>
      'Yalnızca Divine\'de barındırılan videoları göster';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle =>
      'Diğer medya sunucularından sunulan videoları gizle';

  @override
  String get safetySettingsModeration => 'MODERASYON';

  @override
  String get safetySettingsBlockedUsers => 'ENGELLENEN KULLANICILAR';

  @override
  String get safetySettingsAgeVerification => 'YAŞ DOĞRULAMA';

  @override
  String get safetySettingsAgeConfirmation =>
      '18 yaş veya üzerinde olduğumu onaylıyorum';

  @override
  String get safetySettingsAgeRequired =>
      'Yetişkin içeriği görüntülemek için gereklidir';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle =>
      'Resmi moderasyon hizmeti (varsayılan olarak açık)';

  @override
  String get safetySettingsPeopleIFollow => 'Takip ettiğim kişiler';

  @override
  String get safetySettingsPeopleIFollowSubtitle =>
      'Takip ettiğin kişilerin etiketlerine abone ol';

  @override
  String get safetySettingsAddCustomLabeler => 'Özel Etiketleyici Ekle';

  @override
  String get safetySettingsAddCustomLabelerHint => 'npub gir...';

  @override
  String get safetySettingsAddCustomLabelerListTitle =>
      'Özel etiketleyici ekle';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle => 'npub adresi gir';

  @override
  String get safetySettingsNoBlockedUsers => 'Engellenmiş kullanıcı yok';

  @override
  String get safetySettingsUnblock => 'Engeli kaldır';

  @override
  String get safetySettingsUserUnblocked => 'Kullanıcının engeli kaldırıldı';

  @override
  String get safetySettingsCancel => 'İptal';

  @override
  String get safetySettingsAdd => 'Ekle';

  @override
  String get analyticsTitle => 'İçerik Üretici Analitikleri';

  @override
  String get analyticsDiagnosticsTooltip => 'Tanılamalar';

  @override
  String get analyticsDiagnosticsSemanticLabel => 'Tanılamaları aç/kapat';

  @override
  String get analyticsRetry => 'Tekrar Dene';

  @override
  String get analyticsUnableToLoad => 'Analitikler yüklenemiyor.';

  @override
  String get analyticsSignInRequired =>
      'İçerik üretici analitiklerini görmek için giriş yap.';

  @override
  String get analyticsViewDataUnavailable =>
      'Görüntüleme verileri bu gönderiler için röleden şu anda alınamıyor. Beğeni/yorum/yeniden paylaşım metrikleri hala doğrudur.';

  @override
  String get analyticsViewDataTitle => 'Görüntüleme Verileri';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return 'Güncellendi $time • Skorlar mümkün olduğunda Funnelcake\'ten gelen beğeni, yorum, yeniden paylaşım ve görüntüleme/döngü verilerini kullanır.';
  }

  @override
  String get analyticsVideos => 'Videolar';

  @override
  String get analyticsViews => 'Görüntülenme';

  @override
  String get analyticsInteractions => 'Etkileşimler';

  @override
  String get analyticsEngagement => 'Etkileşim Oranı';

  @override
  String get analyticsFollowers => 'Takipçiler';

  @override
  String get analyticsAvgPerPost => 'Gönderi Ort.';

  @override
  String get analyticsInteractionMix => 'Etkileşim Dağılımı';

  @override
  String get analyticsLikes => 'Beğeniler';

  @override
  String get analyticsComments => 'Yorumlar';

  @override
  String get analyticsReposts => 'Yeniden Paylaşımlar';

  @override
  String get analyticsPerformanceHighlights => 'Performans Öne Çıkanları';

  @override
  String get analyticsMostViewed => 'En çok görüntülenen';

  @override
  String get analyticsMostDiscussed => 'En çok tartışılan';

  @override
  String get analyticsMostReposted => 'En çok yeniden paylaşılan';

  @override
  String get analyticsNoVideosYet => 'Henüz video yok';

  @override
  String get analyticsViewDataUnavailableShort => 'Görüntüleme verileri yok';

  @override
  String analyticsViewsCount(String count) {
    return '$count görüntülenme';
  }

  @override
  String analyticsCommentsCount(String count) {
    return '$count yorum';
  }

  @override
  String analyticsRepostsCount(String count) {
    return '$count yeniden paylaşım';
  }

  @override
  String get analyticsTopContent => 'En İyi İçerik';

  @override
  String get analyticsPublishPrompt =>
      'Sıralamaları görmek için birkaç video yayınla.';

  @override
  String get analyticsEngagementRateExplainer =>
      'Sağ taraftaki % = Etkileşim Oranı (etkileşimlerin görüntülenmeye bölümü).';

  @override
  String get analyticsEngagementRateNoViews =>
      'Etkileşim Oranı görüntüleme verisi gerektirir; değerler görüntüleme mevcut olana kadar Yok olarak görünür.';

  @override
  String get analyticsEngagementLabel => 'Etkileşim';

  @override
  String get analyticsViewsUnavailable => 'görüntüleme yok';

  @override
  String analyticsInteractionsCount(String count) {
    return '$count etkileşim';
  }

  @override
  String get analyticsPostAnalytics => 'Gönderi Analitikleri';

  @override
  String get analyticsOpenPost => 'Gönderiyi Aç';

  @override
  String get analyticsRecentDailyInteractions => 'Son Günlük Etkileşimler';

  @override
  String get analyticsNoActivityYet => 'Bu aralıkta henüz etkinlik yok.';

  @override
  String get analyticsDailyInteractionsExplainer =>
      'Etkileşimler = gönderi tarihine göre beğeni + yorum + yeniden paylaşım.';

  @override
  String get analyticsDailyBarExplainer =>
      'Çubuk uzunluğu bu penceredeki en yüksek gününe göredir.';

  @override
  String get analyticsAudienceSnapshot => 'Kitle Özeti';

  @override
  String analyticsFollowersCount(String count) {
    return 'Takipçiler: $count';
  }

  @override
  String analyticsFollowingCount(String count) {
    return 'Takip edilenler: $count';
  }

  @override
  String get analyticsAudiencePlaceholder =>
      'Kaynak/coğrafya/zaman ayrıntıları, Funnelcake kitle analitik uç noktalarını ekledikçe doldurulacak.';

  @override
  String get analyticsRetention => 'Elde Tutma';

  @override
  String get analyticsRetentionWithViews =>
      'Elde tutma eğrisi ve izleme süresi dağılımı, Funnelcake\'ten saniye/kova başına elde tutma geldiğinde görünecek.';

  @override
  String get analyticsRetentionWithoutViews =>
      'Elde tutma verileri, Funnelcake tarafından görüntüleme + izleme süresi analitikleri dönene kadar mevcut değildir.';

  @override
  String get analyticsDiagnostics => 'Tanılamalar';

  @override
  String analyticsDiagnosticsTotalVideos(int count) {
    return 'Toplam video: $count';
  }

  @override
  String analyticsDiagnosticsWithViews(int count) {
    return 'Görüntülenmeli: $count';
  }

  @override
  String analyticsDiagnosticsMissingViews(int count) {
    return 'Görüntülenme eksik: $count';
  }

  @override
  String analyticsDiagnosticsHydratedBulk(int count) {
    return 'Beslenmiş (toplu): $count';
  }

  @override
  String analyticsDiagnosticsHydratedViews(int count) {
    return 'Beslenmiş (/views): $count';
  }

  @override
  String analyticsDiagnosticsSources(String sources) {
    return 'Kaynaklar: $sources';
  }

  @override
  String get analyticsDiagnosticsUseFixture => 'Sabit test verisini kullan';

  @override
  String get analyticsNa => 'Yok';

  @override
  String get authCreateNewAccount => 'Yeni bir Divine hesabı oluştur';

  @override
  String get authSignInDifferentAccount => 'Farklı bir hesapla giriş yap';

  @override
  String get authSignBackIn => 'Tekrar giriş yap';

  @override
  String get authTermsPrefix =>
      'Yukarıdaki bir seçeneği seçerek en az 16 yaşında olduğunu onayladığını ve ';

  @override
  String get authTermsOfService => 'Hizmet Şartları';

  @override
  String get authPrivacyPolicy => 'Gizlilik Politikası';

  @override
  String get authTermsAnd => ' ve ';

  @override
  String get authSafetyStandards => 'Güvenlik Standartları';

  @override
  String get authAmberNotInstalled => 'Amber uygulaması yüklü değil';

  @override
  String get authAmberConnectionFailed => 'Amber ile bağlanılamadı';

  @override
  String get authPasswordResetSent =>
      'Bu e-posta ile bir hesap varsa, bir parola sıfırlama bağlantısı gönderildi.';

  @override
  String get authSignInTitle => 'Giriş yap';

  @override
  String get authEmailLabel => 'E-posta';

  @override
  String get authPasswordLabel => 'Parola';

  @override
  String get authForgotPassword => 'Parolanı mı unuttun?';

  @override
  String get authImportNostrKey => 'Nostr anahtarını içe aktar';

  @override
  String get authConnectSignerApp => 'Bir imzalama uygulaması ile bağlan';

  @override
  String get authSignInWithAmber => 'Amber ile giriş yap';

  @override
  String get authSignInOptionsTitle => 'Giriş seçenekleri';

  @override
  String get authInfoEmailPasswordTitle => 'E-posta ve Parola';

  @override
  String get authInfoEmailPasswordDescription =>
      'Divine hesabınla giriş yap. E-posta ve parolayla kaydoldunsa onları burada kullan.';

  @override
  String get authInfoImportNostrKeyDescription =>
      'Zaten bir Nostr kimliğin var mı? nsec özel anahtarını başka bir istemciden içe aktar.';

  @override
  String get authInfoSignerAppTitle => 'İmzalama Uygulaması';

  @override
  String get authInfoSignerAppDescription =>
      'Geliştirilmiş anahtar güvenliği için nsecBunker gibi NIP-46 uyumlu bir uzaktan imzalayıcı kullanarak bağlan.';

  @override
  String get authInfoAmberTitle => 'Amber';

  @override
  String get authInfoAmberDescription =>
      'Nostr anahtarlarını güvenli şekilde yönetmek için Android\'deki Amber imzalama uygulamasını kullan.';

  @override
  String get authCreateAccountTitle => 'Hesap oluştur';

  @override
  String get authBackToInviteCode => 'Davet koduna geri dön';

  @override
  String get authUseDivineNoBackup => 'Yedek olmadan Divine kullan';

  @override
  String get authSkipConfirmTitle => 'Son bir şey...';

  @override
  String get authSkipConfirmKeyCreated =>
      'İçerisin! Divine hesabını güçlendirecek güvenli bir anahtar oluşturalım.';

  @override
  String get authSkipConfirmKeyOnly =>
      'E-posta olmadan, anahtarın Divine\'ın bu hesabın sana ait olduğunu anlayabileceği tek yoldur.';

  @override
  String get authSkipConfirmRecommendEmail =>
      'Anahtarına uygulama içinden ulaşabilirsin, ancak teknik değilsen şimdi bir e-posta ve parola eklemeni öneririz. Bu cihazı kaybeder veya sıfırlarsan hesabına giriş yapmayı ve geri yüklemeyi kolaylaştırır.';

  @override
  String get authAddEmailPassword => 'E-posta ve parola ekle';

  @override
  String get authUseThisDeviceOnly => 'Yalnızca bu cihazı kullan';

  @override
  String get authCompleteRegistration => 'Kaydını tamamla';

  @override
  String get authVerifying => 'Doğrulanıyor...';

  @override
  String get authVerificationLinkSent =>
      'Şu adrese doğrulama bağlantısı gönderdik:';

  @override
  String get authClickVerificationLink =>
      'Kaydı tamamlamak için\nlütfen e-postandaki bağlantıya tıkla.';

  @override
  String get authPleaseWaitVerifying =>
      'Lütfen e-postan doğrulanırken bekle...';

  @override
  String get authWaitingForVerification => 'Doğrulama bekleniyor';

  @override
  String get authOpenEmailApp => 'E-posta uygulamasını aç';

  @override
  String get authWelcomeToDivine => 'Divine\'a Hoş Geldin!';

  @override
  String get authEmailVerified => 'E-postan doğrulandı.';

  @override
  String get authSigningYouIn => 'Giriş yapılıyor';

  @override
  String get authErrorTitle => 'Olamaz.';

  @override
  String get authVerificationFailed =>
      'E-postanı doğrulayamadık.\nLütfen tekrar dene.';

  @override
  String get authStartOver => 'Baştan başla';

  @override
  String get authEmailVerifiedLogin =>
      'E-posta doğrulandı! Devam etmek için giriş yap.';

  @override
  String get authVerificationLinkExpired =>
      'Bu doğrulama bağlantısı artık geçerli değil.';

  @override
  String get authVerificationConnectionError =>
      'E-posta doğrulanamıyor. Lütfen bağlantını kontrol et ve tekrar dene.';

  @override
  String get authWaitlistConfirmTitle => 'İçerisin!';

  @override
  String authWaitlistUpdatesAt(String email) {
    return 'Güncellemeleri $email adresine göndereceğiz.\nDaha fazla davet kodu çıktığında sana göndereceğiz.';
  }

  @override
  String get authOk => 'Tamam';

  @override
  String get authInviteUnavailable =>
      'Davet erişimi geçici olarak kullanılamıyor.';

  @override
  String get authInviteUnavailableBody =>
      'Biraz sonra tekrar dene veya yardım gerekiyorsa destek ile iletişime geç.';

  @override
  String get authTryAgain => 'Tekrar dene';

  @override
  String get authContactSupport => 'Destekle iletişime geç';

  @override
  String authCouldNotOpenEmail(String email) {
    return '$email açılamadı';
  }

  @override
  String get authAddInviteCode => 'Davet kodunu ekle';

  @override
  String get authInviteCodeLabel => 'Davet kodu';

  @override
  String get authEnterYourCode => 'Kodunu gir';

  @override
  String get authNext => 'İleri';

  @override
  String get authJoinWaitlist => 'Bekleme listesine katıl';

  @override
  String get authJoinWaitlistTitle => 'Bekleme listesine katıl';

  @override
  String get authJoinWaitlistDescription =>
      'E-postanı paylaş, erişim açıldıkça güncelleme gönderelim.';

  @override
  String get authInviteAccessHelp => 'Davet erişimi yardımı';

  @override
  String get authGeneratingConnection => 'Bağlantı oluşturuluyor...';

  @override
  String get authConnectedAuthenticating => 'Bağlandı! Kimlik doğrulanıyor...';

  @override
  String get authConnectionTimedOut => 'Bağlantı zaman aşımı';

  @override
  String get authApproveConnection =>
      'İmzalama uygulamanda bağlantıyı onayladığından emin ol.';

  @override
  String get authConnectionCancelled => 'Bağlantı iptal edildi';

  @override
  String get authConnectionCancelledMessage => 'Bağlantı iptal edildi.';

  @override
  String get authConnectionFailed => 'Bağlantı başarısız';

  @override
  String get authUnknownError => 'Bilinmeyen bir hata oluştu.';

  @override
  String get authUrlCopied => 'URL panoya kopyalandı';

  @override
  String get authConnectToDivine => 'Divine\'a Bağlan';

  @override
  String get authPasteBunkerUrl => 'bunker:// URL\'sini yapıştır';

  @override
  String get authBunkerUrlHint => 'bunker:// URL';

  @override
  String get authInvalidBunkerUrl =>
      'Geçersiz bunker URL\'si. bunker:// ile başlamalıdır';

  @override
  String get authScanSignerApp => 'Bağlanmak için\nimzalama uygulamanla tara.';

  @override
  String authWaitingForConnection(int seconds) {
    return 'Bağlantı bekleniyor... ${seconds}sn';
  }

  @override
  String get authCopyUrl => 'URL\'yi Kopyala';

  @override
  String get authShare => 'Paylaş';

  @override
  String get authAddBunker => 'Bunker ekle';

  @override
  String get authCompatibleSignerApps => 'Uyumlu imzalama uygulamaları';

  @override
  String get authFailedToConnect => 'Bağlanılamadı';

  @override
  String get authResetPasswordTitle => 'Parolayı Sıfırla';

  @override
  String get authResetPasswordSubtitle =>
      'Lütfen yeni parolanı gir. En az 8 karakter olmalıdır.';

  @override
  String get authNewPasswordLabel => 'Yeni Parola';

  @override
  String get authPasswordTooShort => 'Parola en az 8 karakter olmalı';

  @override
  String get authPasswordResetSuccess =>
      'Parola sıfırlama başarılı. Lütfen giriş yap.';

  @override
  String get authPasswordResetFailed => 'Parola sıfırlama başarısız';

  @override
  String get authUnexpectedError =>
      'Beklenmeyen bir hata oluştu. Lütfen tekrar dene.';

  @override
  String get authUpdatePassword => 'Parolayı güncelle';

  @override
  String get authSecureAccountTitle => 'Güvenli hesap';

  @override
  String get authUnableToAccessKeys =>
      'Anahtarlarına erişilemiyor. Lütfen tekrar dene.';

  @override
  String get authRegistrationFailed => 'Kayıt başarısız';

  @override
  String get authRegistrationComplete =>
      'Kayıt tamamlandı. Lütfen e-postanı kontrol et.';

  @override
  String get authVerificationFailedTitle => 'Doğrulama Başarısız';

  @override
  String get authClose => 'Kapat';

  @override
  String get authAccountSecured => 'Hesap Güvenceye Alındı!';

  @override
  String get authAccountLinkedToEmail => 'Hesabın artık e-postana bağlı.';

  @override
  String get authVerifyYourEmail => 'E-Postanı Doğrula';

  @override
  String get authClickLinkContinue =>
      'Kaydı tamamlamak için e-postandaki bağlantıya tıkla. Bu arada uygulamayı kullanmaya devam edebilirsin.';

  @override
  String get authWaitingForVerificationEllipsis => 'Doğrulama bekleniyor...';

  @override
  String get authContinueToApp => 'Uygulamaya Devam Et';

  @override
  String get authResetPassword => 'Parolayı sıfırla';

  @override
  String get authResetPasswordDescription =>
      'E-posta adresini gir, parolanı sıfırlamak için sana bir bağlantı gönderelim.';

  @override
  String get authFailedToSendResetEmail => 'Sıfırlama e-postası gönderilemedi.';

  @override
  String get authUnexpectedErrorShort => 'Beklenmeyen bir hata oluştu.';

  @override
  String get authSending => 'Gönderiliyor...';

  @override
  String get authSendResetLink => 'Sıfırlama bağlantısı gönder';

  @override
  String get authEmailSent => 'E-posta gönderildi!';

  @override
  String authResetLinkSentTo(String email) {
    return '$email adresine bir parola sıfırlama bağlantısı gönderdik. Parolanı güncellemek için lütfen e-postandaki bağlantıya tıkla.';
  }

  @override
  String get authSignInButton => 'Giriş yap';

  @override
  String get authVerificationErrorTimeout =>
      'Doğrulama zaman aşımına uğradı. Lütfen tekrar kaydolmayı dene.';

  @override
  String get authVerificationErrorMissingCode =>
      'Doğrulama başarısız — yetkilendirme kodu eksik.';

  @override
  String get authVerificationErrorPollFailed =>
      'Doğrulama başarısız. Lütfen tekrar dene.';

  @override
  String get authVerificationErrorNetworkExchange =>
      'Giriş sırasında ağ hatası. Lütfen tekrar dene.';

  @override
  String get authVerificationErrorOAuthExchange =>
      'Doğrulama başarısız. Lütfen tekrar kaydolmayı dene.';

  @override
  String get authVerificationErrorSignInFailed =>
      'Giriş başarısız. Lütfen manuel olarak giriş yapmayı dene.';

  @override
  String get authInviteErrorAlreadyUsed =>
      'Bu davet kodu artık kullanılamıyor. Davet koduna geri dön, bekleme listesine katıl veya destekle iletişime geç.';

  @override
  String get authInviteErrorInvalid =>
      'Bu davet kodu şu anda kullanılamıyor. Davet koduna geri dön, bekleme listesine katıl veya destekle iletişime geç.';

  @override
  String get authInviteErrorTemporary =>
      'Davetini şu anda doğrulayamadık. Davet koduna geri dönüp tekrar dene veya destekle iletişime geç.';

  @override
  String get authInviteErrorUnknown =>
      'Davetini etkinleştiremedik. Davet koduna geri dön, bekleme listesine katıl veya destekle iletişime geç.';

  @override
  String get shareSheetSave => 'Kaydet';

  @override
  String get shareSheetSaveToGallery => 'Galeriye Kaydet';

  @override
  String get shareSheetSaveWithWatermark => 'Filigranlı Kaydet';

  @override
  String get shareSheetSaveVideo => 'Videoyu Kaydet';

  @override
  String get shareSheetAddToClips => 'Kliplere ekle';

  @override
  String get shareSheetAddedToClips => 'Kliplere eklendi';

  @override
  String get shareSheetAddToClipsFailed => 'Kliplere eklenemedi';

  @override
  String get shareSheetAddToList => 'Listeye Ekle';

  @override
  String get shareSheetCopy => 'Kopyala';

  @override
  String get shareSheetShareVia => 'Şununla paylaş';

  @override
  String get shareSheetReport => 'Bildir';

  @override
  String get shareSheetEventJson => 'Olay JSON\'u';

  @override
  String get shareSheetEventId => 'Olay Kimliği';

  @override
  String get shareSheetMoreActions => 'Daha fazla işlem';

  @override
  String get watermarkDownloadSavedToCameraRoll => 'Kamera Rulosuna Kaydedildi';

  @override
  String get watermarkDownloadShare => 'Paylaş';

  @override
  String get watermarkDownloadDone => 'Bitti';

  @override
  String get watermarkDownloadPhotosAccessNeeded =>
      'Fotoğraf Erişimi Gerekiyor';

  @override
  String get watermarkDownloadPhotosAccessDescription =>
      'Videoları kaydetmek için Ayarlar\'dan Fotoğraf erişimine izin ver.';

  @override
  String get watermarkDownloadOpenSettings => 'Ayarları Aç';

  @override
  String get watermarkDownloadNotNow => 'Şimdi Değil';

  @override
  String get watermarkDownloadFailed => 'İndirme Başarısız';

  @override
  String get watermarkDownloadDismiss => 'Kapat';

  @override
  String get watermarkDownloadStageDownloading => 'Video İndiriliyor';

  @override
  String get watermarkDownloadStageWatermarking => 'Filigran Ekleniyor';

  @override
  String get watermarkDownloadStageSaving => 'Kamera Rulosuna Kaydediliyor';

  @override
  String get watermarkDownloadStageDownloadingDesc => 'Video ağdan alınıyor...';

  @override
  String get watermarkDownloadStageWatermarkingDesc =>
      'Divine filigranı uygulanıyor...';

  @override
  String get watermarkDownloadStageSavingDesc =>
      'Filigranlı video kamera rulosuna kaydediliyor...';

  @override
  String get uploadProgressVideoUpload => 'Video Yüklemesi';

  @override
  String get uploadProgressPause => 'Duraklat';

  @override
  String get uploadProgressResume => 'Devam Et';

  @override
  String get uploadProgressGoBack => 'Geri Dön';

  @override
  String uploadProgressRetryWithCount(int count) {
    return 'Tekrar Dene ($count kaldı)';
  }

  @override
  String get uploadProgressDelete => 'Sil';

  @override
  String uploadProgressDaysAgo(int count) {
    return '${count}g önce';
  }

  @override
  String uploadProgressHoursAgo(int count) {
    return '${count}sa önce';
  }

  @override
  String uploadProgressMinutesAgo(int count) {
    return '${count}dk önce';
  }

  @override
  String get uploadProgressJustNow => 'Az önce';

  @override
  String uploadProgressUploadingPercent(int percent) {
    return 'Yükleniyor %$percent';
  }

  @override
  String uploadProgressPausedPercent(int percent) {
    return 'Duraklatıldı %$percent';
  }

  @override
  String get badgeExplanationClose => 'Kapat';

  @override
  String get badgeExplanationOriginalVineArchive => 'Orijinal Vine Arşivi';

  @override
  String get badgeExplanationCameraProof => 'Kamera Kanıtı';

  @override
  String get badgeExplanationAuthenticitySignals => 'Gerceklik Sinyalleri';

  @override
  String get badgeExplanationVineArchiveIntro =>
      'Bu video, Internet Archive\'dan kurtarılmış orijinal bir Vine\'dır.';

  @override
  String get badgeExplanationVineArchiveHistory =>
      'Vine 2017\'de kapanmadan önce, ArchiveTeam ve Internet Archive milyonlarca Vine\'ı gelecek için korumak amacıyla çalıştı. Bu içerik, o tarihi koruma çabasının bir parçasıdır.';

  @override
  String badgeExplanationOriginalStats(int loops) {
    return 'Orijinal istatistikler: $loops döngü';
  }

  @override
  String get badgeExplanationLearnVineArchive =>
      'Vine arşivi koruması hakkında daha fazla bilgi';

  @override
  String get badgeExplanationLearnProofmode =>
      'Proofmode doğrulaması hakkında daha fazla bilgi';

  @override
  String get badgeExplanationLearnAuthenticity =>
      'Divine gerçeklik sinyalleri hakkında daha fazla bilgi';

  @override
  String get badgeExplanationInspectProofCheck => 'ProofCheck Aracı ile İncele';

  @override
  String get badgeExplanationInspectMedia => 'Medya ayrıntılarını incele';

  @override
  String get badgeExplanationProofmodeVerified =>
      'Bu videonun orijinalliği Proofmode teknolojisi ile doğrulandı.';

  @override
  String get badgeExplanationDivineHostedHumanMade =>
      'Bu video Divine\'de barındırılıyor ve yapay zeka tespiti muhtemelen insan yapımı olduğunu gösteriyor, ancak kriptografik kamera doğrulama verisi içermiyor.';

  @override
  String get badgeExplanationHumanMadeNoCrypto =>
      'Yapay zeka tespiti bu videonun muhtemelen insan yapımı olduğunu gösteriyor, ancak kriptografik kamera doğrulama verisi içermiyor.';

  @override
  String get badgeExplanationDivineHostedNoCrypto =>
      'Bu video Divine\'de barındırılıyor, ancak henüz kriptografik kamera doğrulama verisi içermiyor.';

  @override
  String get badgeExplanationExternalNoCrypto =>
      'Bu video Divine dışında barındırılıyor ve kriptografik kamera doğrulama verisi içermiyor.';

  @override
  String get badgeExplanationDeviceAttestation => 'Cihaz tasdik';

  @override
  String get badgeExplanationPgpSignature => 'PGP imzası';

  @override
  String get badgeExplanationC2paCredentials => 'C2PA İçerik Kimlik Bilgileri';

  @override
  String get badgeExplanationProofManifest => 'Kanıt manifestosu';

  @override
  String get badgeExplanationAiDetection => 'Yapay Zeka Tespiti';

  @override
  String get badgeExplanationAiNotScanned =>
      'Yapay zeka taraması: Henüz taranmadı';

  @override
  String get badgeExplanationNoScanResults =>
      'Henüz tarama sonucu mevcut değil.';

  @override
  String get badgeExplanationCheckAiGenerated =>
      'Yapay zeka üretimi mi kontrol et';

  @override
  String badgeExplanationAiLikelihood(int percentage) {
    return 'Yapay zeka üretimi olma olasılığı %$percentage';
  }

  @override
  String badgeExplanationScannedBy(String source) {
    return 'Tarayıcı: $source';
  }

  @override
  String get badgeExplanationVerifiedByModerator =>
      'İnsan moderatör tarafından doğrulandı';

  @override
  String get badgeExplanationVerificationPlatinum =>
      'Platin: Cihaz donanımı tasdik, kriptografik imzalar, İçerik Kimlik Bilgileri (C2PA) ve yapay zeka taraması insan kökenini doğrular.';

  @override
  String get badgeExplanationVerificationGold =>
      'Altın: Donanım tasdik, kriptografik imzalar ve İçerik Kimlik Bilgileri (C2PA) ile gerçek bir cihazda çekildi.';

  @override
  String get badgeExplanationVerificationSilver =>
      'Gümüş: Kriptografik imzalar bu videonun kayıttan bu yana değiştirilmediğini kanıtlar.';

  @override
  String get badgeExplanationVerificationBronze =>
      'Bronz: Temel meta veri imzaları mevcut.';

  @override
  String get badgeExplanationVerificationSilverAiScan =>
      'Gümüş: Yapay zeka taraması bu videonun muhtemelen insan tarafından oluşturulduğunu doğrular.';

  @override
  String get badgeExplanationNoVerification =>
      'Bu video için doğrulama verisi mevcut değil.';

  @override
  String get shareMenuTitle => 'Videoyu Paylaş';

  @override
  String get shareMenuReportAiContent => 'Yapay Zeka İçeriği Bildir';

  @override
  String get shareMenuReportAiContentSubtitle =>
      'Şüpheli yapay zeka üretimi içeriği hızlı bildir';

  @override
  String get shareMenuReportingAiContent =>
      'Yapay zeka içeriği bildiriliyor...';

  @override
  String shareMenuFailedToReportContent(String error) {
    return 'İçerik bildirilemedi: $error';
  }

  @override
  String shareMenuFailedToReportAiContent(String error) {
    return 'Yapay zeka içeriği bildirilemedi: $error';
  }

  @override
  String get shareMenuVideoStatus => 'Video Durumu';

  @override
  String get shareMenuViewAllLists => 'Tüm listeleri görüntüle →';

  @override
  String get shareMenuShareWith => 'Şununla Paylaş';

  @override
  String get shareMenuShareViaOtherApps => 'Diğer uygulamalar üzerinden paylaş';

  @override
  String get shareMenuShareViaOtherAppsSubtitle =>
      'Diğer uygulamalar ile paylaş veya bağlantıyı kopyala';

  @override
  String get shareMenuSaveToGallery => 'Galeriye Kaydet';

  @override
  String get shareMenuSaveOriginalSubtitle =>
      'Orijinal videoyu kamera rulosuna kaydet';

  @override
  String get shareMenuSaveWithWatermark => 'Filigranlı Kaydet';

  @override
  String get shareMenuSaveVideo => 'Videoyu Kaydet';

  @override
  String get shareMenuDownloadWithWatermark => 'Divine filigranı ile indir';

  @override
  String get shareMenuSaveVideoSubtitle => 'Videoyu kamera rulosuna kaydet';

  @override
  String get shareMenuLists => 'Listeler';

  @override
  String get shareMenuAddToList => 'Listeye Ekle';

  @override
  String get shareMenuAddToListSubtitle => 'Derlenmiş listelerine ekle';

  @override
  String get shareMenuCreateNewList => 'Yeni Liste Oluştur';

  @override
  String get shareMenuCreateNewListSubtitle => 'Yeni bir derleme başlat';

  @override
  String get shareMenuRemovedFromList => 'Listeden kaldırıldı';

  @override
  String get shareMenuFailedToRemoveFromList => 'Listeden kaldırılamadı';

  @override
  String get shareMenuBookmarks => 'Yer İmleri';

  @override
  String get shareMenuAddToBookmarks => 'Yer İmlerine Ekle';

  @override
  String get shareMenuAddToBookmarksSubtitle => 'Sonra izlemek için kaydet';

  @override
  String get shareMenuAddToBookmarkSet => 'Yer İmi Setine Ekle';

  @override
  String get shareMenuAddToBookmarkSetSubtitle =>
      'Koleksiyonlar halinde düzenle';

  @override
  String get shareMenuFollowSets => 'Takip Setleri';

  @override
  String get shareMenuCreateFollowSet => 'Takip Seti Oluştur';

  @override
  String get shareMenuCreateFollowSetSubtitle =>
      'Bu üretici ile yeni koleksiyon başlat';

  @override
  String get shareMenuAddToFollowSet => 'Takip Setine Ekle';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    return '$count takip seti mevcut';
  }

  @override
  String get peopleListsAddToList => 'Listeye ekle';

  @override
  String get peopleListsAddToListSubtitle =>
      'Bu içerik üreticisini listelerinden birine ekle';

  @override
  String get peopleListsSheetTitle => 'Listeye ekle';

  @override
  String get peopleListsEmptyTitle => 'Henüz liste yok';

  @override
  String get peopleListsEmptySubtitle =>
      'Kişileri gruplamaya başlamak için bir liste oluştur.';

  @override
  String get peopleListsCreateList => 'Liste oluştur';

  @override
  String get peopleListsNewListTitle => 'Yeni liste';

  @override
  String get peopleListsRouteTitle => 'Kişi listesi';

  @override
  String get peopleListsListNameLabel => 'Liste adı';

  @override
  String get peopleListsListNameHint => 'Yakın arkadaşlar';

  @override
  String get peopleListsCreateButton => 'Oluştur';

  @override
  String get peopleListsAddPeopleTitle => 'Kişi ekle';

  @override
  String get peopleListsAddPeopleTooltip => 'Kişi ekle';

  @override
  String get peopleListsAddPeopleSemanticLabel => 'Listeye kişi ekle';

  @override
  String get peopleListsListNotFoundTitle => 'Liste bulunamadı';

  @override
  String get peopleListsListNotFoundSubtitle =>
      'Liste bulunamadı. Silinmiş olabilir.';

  @override
  String get peopleListsListDeletedSubtitle => 'Bu liste silinmiş olabilir.';

  @override
  String get peopleListsNoPeopleTitle => 'Bu listede kişi yok';

  @override
  String get peopleListsNoPeopleSubtitle => 'Başlamak için kişi ekle';

  @override
  String get peopleListsNoVideosTitle => 'Henüz video yok';

  @override
  String get peopleListsNoVideosSubtitle =>
      'Liste üyelerinin videoları burada görünecek';

  @override
  String get peopleListsNoVideosAvailable => 'Kullanılabilir video yok';

  @override
  String get peopleListsFailedToLoadVideos => 'Videolar yüklenemedi';

  @override
  String get peopleListsVideoNotAvailable => 'Video kullanılamıyor';

  @override
  String get peopleListsBackToGridTooltip => 'Izgaraya dön';

  @override
  String get peopleListsErrorLoadingVideos =>
      'Videolar yüklenirken hata oluştu';

  @override
  String get peopleListsNoPeopleToAdd => 'Eklenecek kişi bulunamadı.';

  @override
  String peopleListsAddToListName(String name) {
    return '$name listesine ekle';
  }

  @override
  String get peopleListsAddPeopleSearchHint => 'Kişi ara';

  @override
  String get peopleListsAddPeopleError =>
      'Kişiler yüklenemedi. Lütfen tekrar dene.';

  @override
  String get peopleListsAddPeopleRetry => 'Tekrar dene';

  @override
  String get peopleListsAddButton => 'Ekle';

  @override
  String peopleListsAddButtonWithCount(int count) {
    return '$count ekle';
  }

  @override
  String peopleListsInNLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count listede',
      one: '1 listede',
    );
    return '$_temp0';
  }

  @override
  String peopleListsRemoveConfirmTitle(String name) {
    return '$name kaldırılsın mı?';
  }

  @override
  String get peopleListsRemoveConfirmBody => 'Bu kişi listeden kaldırılacak.';

  @override
  String get peopleListsRemove => 'Kaldır';

  @override
  String peopleListsRemovedFromList(String name) {
    return '$name listeden kaldırıldı';
  }

  @override
  String get peopleListsUndo => 'Geri al';

  @override
  String peopleListsProfileLongPressHint(String name) {
    return '$name profili. Kaldırmak için uzun bas.';
  }

  @override
  String peopleListsViewProfileHint(String name) {
    return '$name profilini görüntüle';
  }

  @override
  String get shareMenuAddedToBookmarks => 'Yer imlerine eklendi!';

  @override
  String get shareMenuFailedToAddBookmark => 'Yer imi eklenemedi';

  @override
  String shareMenuCreatedListAndAddedVideo(String name) {
    return '\"$name\" listesi oluşturuldu ve video eklendi';
  }

  @override
  String get shareMenuManageContent => 'İçeriği Yönet';

  @override
  String get shareMenuEditVideo => 'Videoyu Düzenle';

  @override
  String get shareMenuEditVideoSubtitle =>
      'Başlık, açıklama ve etiketleri güncelle';

  @override
  String get shareMenuDeleteVideo => 'Videoyu Sil';

  @override
  String get shareMenuDeleteVideoSubtitle => 'Bu içeriği kalıcı olarak kaldır';

  @override
  String get shareMenuDeleteWarning =>
      'Bu işlem tüm rölelere bir silme isteği (NIP-09) gönderir. Bazı röleler içeriği saklamaya devam edebilir.';

  @override
  String get shareMenuVideoInTheseLists => 'Video şu listelerde:';

  @override
  String shareMenuVideoCount(int count) {
    return '$count video';
  }

  @override
  String get shareMenuClose => 'Kapat';

  @override
  String get shareMenuDeleteConfirmation =>
      'Bu videoyu silmek istediğinden emin misin?';

  @override
  String get shareMenuCancel => 'İptal';

  @override
  String get shareMenuDelete => 'Sil';

  @override
  String get shareMenuDeletingContent => 'İçerik siliniyor...';

  @override
  String shareMenuFailedToDeleteContent(String error) {
    return 'İçerik silinemedi: $error';
  }

  @override
  String get shareMenuDeleteRequestSent => 'Silme isteği başarıyla gönderildi';

  @override
  String get shareMenuDeleteFailedNotInitialized =>
      'Silme henüz hazır değil. Birazdan tekrar dene.';

  @override
  String get shareMenuDeleteFailedNotOwner =>
      'Yalnızca kendi videolarını silebilirsin.';

  @override
  String get shareMenuDeleteFailedNotAuthenticated =>
      'Tekrar giriş yap, sonra silmeyi dene.';

  @override
  String get shareMenuDeleteFailedCouldNotSign =>
      'Silme isteği imzalanamadı. Tekrar dene.';

  @override
  String get shareMenuDeleteFailedRelayRejected =>
      'Couldn\'t reach the relay. Check your connection and try again.';

  @override
  String get shareMenuDeleteFailedGeneric =>
      'Bu video silinemedi. Tekrar dene.';

  @override
  String get shareMenuFollowSetName => 'Takip Seti Adı';

  @override
  String get shareMenuFollowSetNameHint =>
      'örn. İçerik Üreticileri, Müzisyenler vb.';

  @override
  String get shareMenuDescriptionOptional => 'Açıklama (opsiyonel)';

  @override
  String get shareMenuCreate => 'Oluştur';

  @override
  String shareMenuCreatedFollowSetAndAddedCreator(String name) {
    return '\"$name\" takip seti oluşturuldu ve üretici eklendi';
  }

  @override
  String get shareMenuDone => 'Bitti';

  @override
  String get shareMenuEditTitle => 'Başlık';

  @override
  String get shareMenuEditTitleHint => 'Video başlığını gir';

  @override
  String get shareMenuEditDescription => 'Açıklama';

  @override
  String get shareMenuEditDescriptionHint => 'Video açıklamasını gir';

  @override
  String get shareMenuEditHashtags => 'Etiketler';

  @override
  String get shareMenuEditHashtagsHint => 'virgülle, ayırılmış, etiketler';

  @override
  String get shareMenuEditMetadataNote =>
      'Not: Yalnızca meta veriler düzenlenebilir. Video içeriği değiştirilemez.';

  @override
  String get shareMenuDeleting => 'Siliniyor...';

  @override
  String get shareMenuUpdate => 'Güncelle';

  @override
  String get shareMenuVideoUpdated => 'Video başarıyla güncellendi';

  @override
  String shareMenuFailedToUpdateVideo(String error) {
    return 'Video güncellenemedi: $error';
  }

  @override
  String shareMenuFailedToDeleteVideo(String error) {
    return 'Video silinemedi: $error';
  }

  @override
  String get shareMenuDeleteVideoQuestion => 'Video Silinsin mi?';

  @override
  String get shareMenuDeleteRelayWarning =>
      'Bu işlem rölelere bir silme isteği gönderir. Not: Bazı rölelerin hala önbelleğe alınmış kopyaları olabilir.';

  @override
  String get shareMenuVideoDeletionRequested => 'Video silme isteği alındı';

  @override
  String get shareMenuContentLabels => 'İçerik etiketleri';

  @override
  String get shareMenuAddContentLabels => 'İçerik etiketleri ekle';

  @override
  String get shareMenuClearAll => 'Tümünü temizle';

  @override
  String get shareMenuCollaborators => 'İşbirlikçiler';

  @override
  String get shareMenuAddCollaborator => 'İşbirlikçi ekle';

  @override
  String shareMenuMutualFollowRequired(String name) {
    return '$name kişisini işbirlikçi olarak eklemek için karşılıklı takip etmeniz gerekir.';
  }

  @override
  String get shareMenuLoading => 'Yükleniyor...';

  @override
  String get shareMenuInspiredBy => 'İlham alındı';

  @override
  String get shareMenuAddInspirationCredit => 'İlham kaynağı ekle';

  @override
  String get shareMenuCreatorCannotBeReferenced =>
      'Bu üreticiye referans verilemez.';

  @override
  String get shareMenuUnknown => 'Bilinmeyen';

  @override
  String get shareMenuCreateBookmarkSet => 'Yer İmi Seti Oluştur';

  @override
  String get shareMenuSetName => 'Set Adı';

  @override
  String get shareMenuSetNameHint => 'örn. Favoriler, Sonra İzle vb.';

  @override
  String get shareMenuCreateNewSet => 'Yeni Set Oluştur';

  @override
  String get shareMenuStartNewBookmarkCollection =>
      'Yeni bir yer imi koleksiyonu başlat';

  @override
  String get shareMenuNoBookmarkSets =>
      'Henüz yer imi seti yok. İlk setini oluştur!';

  @override
  String get shareMenuError => 'Hata';

  @override
  String get shareMenuFailedToLoadBookmarkSets => 'Yer imi setleri yüklenemedi';

  @override
  String shareMenuCreatedSetAndAddedVideo(String name) {
    return '\"$name\" oluşturuldu ve video eklendi';
  }

  @override
  String get shareMenuUseThisSound => 'Bu sesi kullan';

  @override
  String get shareMenuOriginalSound => 'Orijinal ses';

  @override
  String get authSessionExpired =>
      'Oturumun sona erdi. Lütfen tekrar giriş yap.';

  @override
  String get authSignInFailed => 'Giriş başarısız. Lütfen tekrar dene.';

  @override
  String get localeAppLanguage => 'Uygulama Dili';

  @override
  String get localeDeviceDefault => 'Cihaz varsayılanı';

  @override
  String get localeSelectLanguage => 'Dil Seç';

  @override
  String get webAuthNotSupportedSecureMode =>
      'Web kimlik doğrulaması güvenli modda desteklenmiyor. Güvenli anahtar yönetimi için lütfen mobil uygulamayı kullan.';

  @override
  String webAuthIntegrationFailed(String error) {
    return 'Kimlik doğrulama entegrasyonu başarısız: $error';
  }

  @override
  String webAuthUnexpectedError(String error) {
    return 'Beklenmeyen hata: $error';
  }

  @override
  String get webAuthEnterBunkerUri => 'Lütfen bir bunker URI\'si gir';

  @override
  String get webAuthConnectTitle => 'Divine\'a Bağlan';

  @override
  String get webAuthChooseMethod =>
      'Tercih ettiğin Nostr kimlik doğrulama yöntemini seç';

  @override
  String get webAuthBrowserExtension => 'Tarayıcı Uzantısı';

  @override
  String get webAuthRecommended => 'ÖNERİLEN';

  @override
  String get webAuthNsecBunker => 'nsec bunker';

  @override
  String get webAuthConnectRemoteSigner => 'Uzak bir imzalayıcıya bağlan';

  @override
  String get webAuthBunkerHint => 'bunker://pubkey?relay=wss://...';

  @override
  String get webAuthPasteFromClipboard => 'Panodan yapıştır';

  @override
  String get webAuthConnectToBunker => 'Bunker\'a Bağlan';

  @override
  String get webAuthNewToNostr => 'Nostr\'da yeni misin?';

  @override
  String get webAuthNostrHelp =>
      'En kolay deneyim için Alby veya nos2x gibi bir tarayıcı uzantısı yükle veya güvenli uzaktan imzalama için nsec bunker kullan.';

  @override
  String get soundsTitle => 'Sesler';

  @override
  String get soundsSearchHint => 'Ses ara...';

  @override
  String get soundsPreviewUnavailable => 'Ses önizlenemiyor - ses mevcut değil';

  @override
  String soundsPreviewFailed(String error) {
    return 'Önizleme oynatılamadı: $error';
  }

  @override
  String get soundsFeaturedSounds => 'Öne Çıkan Sesler';

  @override
  String get soundsTrendingSounds => 'Trend Sesler';

  @override
  String get soundsAllSounds => 'Tüm Sesler';

  @override
  String get soundsSearchResults => 'Arama Sonuçları';

  @override
  String get soundsNoSoundsAvailable => 'Hiç ses yok';

  @override
  String get soundsNoSoundsDescription =>
      'İçerik üreticiler ses paylaştığında burada görünecek';

  @override
  String get soundsNoSoundsFound => 'Hiç ses bulunamadı';

  @override
  String get soundsNoSoundsFoundDescription => 'Farklı bir arama terimi dene';

  @override
  String get soundsFailedToLoad => 'Sesler yüklenemedi';

  @override
  String get soundsRetry => 'Tekrar Dene';

  @override
  String get soundsScreenLabel => 'Sesler ekranı';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileRefresh => 'Yenile';

  @override
  String get profileRefreshLabel => 'Profili yenile';

  @override
  String get profileMoreOptions => 'Daha fazla seçenek';

  @override
  String profileBlockedUser(String name) {
    return '$name engellendi';
  }

  @override
  String profileUnblockedUser(String name) {
    return '$name engeli kaldırıldı';
  }

  @override
  String profileUnfollowedUser(String name) {
    return '$name takipten çıkarıldı';
  }

  @override
  String profileError(String error) {
    return 'Hata: $error';
  }

  @override
  String get notificationsTabAll => 'Tümü';

  @override
  String get notificationsTabLikes => 'Beğeniler';

  @override
  String get notificationsTabComments => 'Yorumlar';

  @override
  String get notificationsTabFollows => 'Takipler';

  @override
  String get notificationsTabReposts => 'Yeniden Paylaşımlar';

  @override
  String get notificationsFailedToLoad => 'Bildirimler yüklenemedi';

  @override
  String get notificationsRetry => 'Tekrar Dene';

  @override
  String get notificationsCheckingNew => 'yeni bildirimler kontrol ediliyor';

  @override
  String get notificationsNoneYet => 'Henüz bildirim yok';

  @override
  String notificationsNoneForType(String type) {
    return '$type bildirimi yok';
  }

  @override
  String get notificationsEmptyDescription =>
      'İnsanlar içeriğinle etkileşime geçtiğinde burada göreceksin';

  @override
  String get notificationsUnreadPrefix => 'Okunmamış bildirim';

  @override
  String notificationsViewProfileSemanticLabel(String displayName) {
    return '$displayName profilini görüntüle';
  }

  @override
  String get notificationsViewProfilesSemanticLabel => 'Profilleri görüntüle';

  @override
  String notificationsLoadingType(String type) {
    return '$type bildirimleri yükleniyor...';
  }

  @override
  String get notificationsInviteSingular =>
      'Bir arkadaşınla paylaşacak 1 davetin var!';

  @override
  String notificationsInvitePlural(int count) {
    return 'Arkadaşlarınla paylaşacak $count davetin var!';
  }

  @override
  String get notificationsVideoNotFound => 'Video bulunamadı';

  @override
  String get notificationsVideoUnavailable => 'Video kullanılamıyor';

  @override
  String get notificationsFromNotification => 'Bildirimden';

  @override
  String get feedFailedToLoadVideos => 'Videolar yüklenemedi';

  @override
  String get feedRetry => 'Tekrar Dene';

  @override
  String get feedNoFollowedUsers =>
      'Takip edilen kullanıcı yok.\nVideolarını burada görmek için birini takip et.';

  @override
  String get feedForYouEmpty =>
      'Sana Özel akışın boş.\nVideolar keşfet ve içerik üreticileri takip ederek akışını şekillendir.';

  @override
  String get feedFollowingEmpty =>
      'Takip ettiğin kişilerden henüz video yok.\nBeğendiğin içerik üreticilerini bulup takip et.';

  @override
  String get feedLatestEmpty =>
      'Henüz yeni video yok.\nYakında tekrar kontrol et.';

  @override
  String get feedExploreVideos => 'Videoları Keşfet';

  @override
  String get feedExternalVideoSlow => 'Harici video yavaş yükleniyor';

  @override
  String get feedSkip => 'Atla';

  @override
  String get uploadWaitingToUpload => 'Yüklemek için bekleniyor';

  @override
  String get uploadUploadingVideo => 'Video yükleniyor';

  @override
  String get uploadProcessingVideo => 'Video işleniyor';

  @override
  String get uploadProcessingComplete => 'İşleme tamamlandı';

  @override
  String get uploadPublishedSuccessfully => 'Başarıyla yayınlandı';

  @override
  String get uploadFailed => 'Yükleme başarısız';

  @override
  String get uploadRetrying => 'Yükleme yeniden deneniyor';

  @override
  String get uploadPaused => 'Yükleme duraklatıldı';

  @override
  String uploadPercentComplete(int percent) {
    return '%$percent tamamlandı';
  }

  @override
  String get uploadQueuedMessage => 'Videon yükleme kuyruğunda';

  @override
  String get uploadUploadingMessage => 'Sunucuya yükleniyor...';

  @override
  String get uploadProcessingMessage =>
      'Video işleniyor - bu birkaç dakika sürebilir';

  @override
  String get uploadReadyToPublishMessage =>
      'Video başarıyla işlendi ve yayınlamaya hazır';

  @override
  String get uploadPublishedMessage => 'Video profiline yayınlandı';

  @override
  String get uploadFailedMessage => 'Yükleme başarısız - lütfen tekrar dene';

  @override
  String get uploadRetryingMessage => 'Yükleme yeniden deneniyor...';

  @override
  String get uploadPausedMessage => 'Yükleme kullanıcı tarafından duraklatıldı';

  @override
  String get uploadRetryButton => 'YENİDEN DENE';

  @override
  String uploadRetryFailed(String error) {
    return 'Yükleme yeniden denenemedi: $error';
  }

  @override
  String get userSearchPrompt => 'Kullanıcı ara';

  @override
  String get userSearchNoResults => 'Kullanıcı bulunamadı';

  @override
  String get userSearchFailed => 'Arama başarısız';

  @override
  String get userPickerSearchByName => 'Ada göre ara';

  @override
  String get userPickerFilterByNameHint => 'Ada göre filtrele...';

  @override
  String get userPickerSearchByNameHint => 'Ada göre ara...';

  @override
  String userPickerAlreadyAddedSemantics(String name) {
    return '$name zaten eklendi';
  }

  @override
  String userPickerSelectSemantics(String name) {
    return '$name seç';
  }

  @override
  String get userPickerEmptyFollowListTitle => 'Ekibin dışarıda';

  @override
  String get userPickerEmptyFollowListBody =>
      'Aynı frekansta olduğun kişileri takip et. Onlar da seni takip ettiğinde birlikte üretim yapabilirsiniz.';

  @override
  String get userPickerGoBack => 'Geri dön';

  @override
  String get userPickerTypeNameToSearch => 'Aramak için bir isim yaz';

  @override
  String get userPickerUnavailable =>
      'Kullanıcı araması kullanılamıyor. Lütfen daha sonra tekrar dene.';

  @override
  String get userPickerSearchFailedTryAgain =>
      'Arama başarısız oldu. Lütfen tekrar dene.';

  @override
  String get forgotPasswordTitle => 'Parolayı Sıfırla';

  @override
  String get forgotPasswordDescription =>
      'E-posta adresini gir, parolanı sıfırlamak için sana bir bağlantı gönderelim.';

  @override
  String get forgotPasswordEmailLabel => 'E-posta Adresi';

  @override
  String get forgotPasswordCancel => 'İptal';

  @override
  String get forgotPasswordSendLink => 'Sıfırlama Bağlantısı Gönder';

  @override
  String get ageVerificationContentWarning => 'İçerik Uyarısı';

  @override
  String get ageVerificationTitle => 'Yaş Doğrulama';

  @override
  String get ageVerificationAdultDescription =>
      'Bu içerik potansiyel olarak yetişkin içeriği barındırmak üzere işaretlendi. Görüntülemek için 18 yaş veya üzerinde olmalısın.';

  @override
  String get ageVerificationCreationDescription =>
      'Kamerayı kullanmak ve içerik oluşturmak için en az 16 yaşında olmalısın.';

  @override
  String get ageVerificationAdultQuestion => '18 yaşında veya üzerinde misin?';

  @override
  String get ageVerificationCreationQuestion =>
      '16 yaşında veya üzerinde misin?';

  @override
  String get ageVerificationNo => 'Hayır';

  @override
  String get ageVerificationYes => 'Evet';

  @override
  String get shareLinkCopied => 'Bağlantı panoya kopyalandı';

  @override
  String get shareFailedToCopy => 'Bağlantı kopyalanamadı';

  @override
  String get shareVideoSubject => 'Divine\'deki bu videoya bir göz at';

  @override
  String get shareFailedToShare => 'Paylaşılamadı';

  @override
  String get shareVideoTitle => 'Videoyu Paylaş';

  @override
  String get shareToApps => 'Uygulamalarla Paylaş';

  @override
  String get shareToAppsSubtitle => 'Mesajlaşma, sosyal uygulamalarla paylaş';

  @override
  String get shareCopyWebLink => 'Web Bağlantısını Kopyala';

  @override
  String get shareCopyWebLinkSubtitle =>
      'Paylaşılabilir web bağlantısını kopyala';

  @override
  String get shareCopyNostrLink => 'Nostr Bağlantısını Kopyala';

  @override
  String get shareCopyNostrLinkSubtitle =>
      'Nostr istemcileri için nevent bağlantısını kopyala';

  @override
  String get navHome => 'Ana Sayfa';

  @override
  String get navExplore => 'Keşfet';

  @override
  String get navInbox => 'Gelen Kutusu';

  @override
  String get navProfile => 'Profil';

  @override
  String get navSearch => 'Ara';

  @override
  String get navSearchTooltip => 'Ara';

  @override
  String get navMyProfile => 'Profilim';

  @override
  String get navNotifications => 'Bildirimler';

  @override
  String get navOpenCamera => 'Kamerayı aç';

  @override
  String get navUnknown => 'Bilinmeyen';

  @override
  String get navExploreClassics => 'Klasikler';

  @override
  String get navExploreNewVideos => 'Yeni Videolar';

  @override
  String get navExploreTrending => 'Trend';

  @override
  String get navExploreForYou => 'Sana Özel';

  @override
  String get navExploreLists => 'Listeler';

  @override
  String get routeErrorTitle => 'Hata';

  @override
  String get routeInvalidHashtag => 'Geçersiz etiket';

  @override
  String get routeInvalidConversationId => 'Geçersiz sohbet kimliği';

  @override
  String get routeInvalidRequestId => 'Geçersiz istek kimliği';

  @override
  String get routeInvalidListId => 'Geçersiz liste kimliği';

  @override
  String get routeInvalidUserId => 'Geçersiz kullanıcı kimliği';

  @override
  String get routeInvalidVideoId => 'Geçersiz video kimliği';

  @override
  String get routeInvalidSoundId => 'Geçersiz ses kimliği';

  @override
  String get routeInvalidCategory => 'Geçersiz kategori';

  @override
  String get routeNoVideosToDisplay => 'Gösterilecek video yok';

  @override
  String get routeInvalidProfileId => 'Geçersiz profil kimliği';

  @override
  String get routeDefaultListName => 'Liste';

  @override
  String get supportTitle => 'Destek Merkezi';

  @override
  String get supportContactSupport => 'Destekle İletişime Geç';

  @override
  String get supportContactSupportSubtitle =>
      'Bir sohbet başlat veya geçmiş mesajları gör';

  @override
  String get supportReportBug => 'Hata Bildir';

  @override
  String get supportReportBugSubtitle => 'Uygulamayla ilgili teknik sorunlar';

  @override
  String get supportRequestFeature => 'Özellik İste';

  @override
  String get supportRequestFeatureSubtitle =>
      'Bir iyileştirme veya yeni özellik öner';

  @override
  String get supportSaveLogs => 'Günlükleri Kaydet';

  @override
  String get supportSaveLogsSubtitle =>
      'Manuel göndermek için günlükleri dosyaya aktar';

  @override
  String get supportFaq => 'SSS';

  @override
  String get supportFaqSubtitle => 'Sık sorulan sorular ve cevapları';

  @override
  String get supportProofMode => 'ProofMode';

  @override
  String get supportProofModeSubtitle =>
      'Doğrulama ve gerçeklik hakkında bilgi edin';

  @override
  String get supportLoginRequired => 'Destekle iletişime geçmek için giriş yap';

  @override
  String get supportExportingLogs => 'Günlükler dışa aktarılıyor...';

  @override
  String get supportExportLogsFailed => 'Günlükler dışa aktarılamadı';

  @override
  String get supportChatNotAvailable => 'Destek sohbeti kullanılamıyor';

  @override
  String get supportCouldNotOpenMessages => 'Destek mesajları açılamadı';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return '$pageName açılamadı';
  }

  @override
  String supportErrorOpeningPage(String pageName, Object error) {
    return '$pageName açılırken hata: $error';
  }

  @override
  String get reportTitle => 'İçeriği Bildir';

  @override
  String get reportWhyReporting => 'Bu içeriği neden bildiriyorsun?';

  @override
  String get reportPolicyNotice =>
      'Divine, içerik bildirimlerine 24 saat içinde içeriği kaldırarak ve söz konusu içeriği sağlayan kullanıcıyı çıkararak işlem yapar.';

  @override
  String get reportAdditionalDetails => 'Ek ayrıntılar (opsiyonel)';

  @override
  String get reportBlockUser => 'Bu kullanıcıyı engelle';

  @override
  String get reportCancel => 'İptal';

  @override
  String get reportSubmit => 'Bildir';

  @override
  String get reportSelectReason =>
      'Lütfen bu içeriği bildirmek için bir sebep seç';

  @override
  String get reportReasonSpam => 'Spam veya İstenmeyen İçerik';

  @override
  String get reportReasonHarassment => 'Taciz, Zorbalık veya Tehdit';

  @override
  String get reportReasonViolence => 'Şiddet veya Aşırı İçerik';

  @override
  String get reportReasonSexualContent => 'Cinsel veya Yetişkin İçerik';

  @override
  String get reportReasonCopyright => 'Telif Hakkı İhlali';

  @override
  String get reportReasonFalseInfo => 'Yanlış Bilgi';

  @override
  String get reportReasonCsam => 'Çocuk Güvenliği İhlali';

  @override
  String get reportReasonAiGenerated => 'Yapay Zeka Üretimi İçerik';

  @override
  String get reportReasonOther => 'Diğer Politika İhlali';

  @override
  String reportFailed(Object error) {
    return 'İçerik bildirilemedi: $error';
  }

  @override
  String get reportReceivedTitle => 'Bildirim Alındı';

  @override
  String get reportReceivedThankYou =>
      'Divine\'ı güvenli tutmaya yardımcı olduğun için teşekkürler.';

  @override
  String get reportReceivedReviewNotice =>
      'Ekibimiz bildirimini inceleyecek ve uygun adımı atacak. Direkt mesaj yoluyla güncelleme alabilirsin.';

  @override
  String get reportLearnMore => 'Daha Fazla Bilgi';

  @override
  String get reportSafetyUrl => 'divine.video/safety';

  @override
  String get reportClose => 'Kapat';

  @override
  String get listAddToList => 'Listeye Ekle';

  @override
  String listVideoCount(int count) {
    return '$count video';
  }

  @override
  String listPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
    );
    return '$_temp0';
  }

  @override
  String get listByAuthorPrefix => 'By ';

  @override
  String get listNewList => 'Yeni Liste';

  @override
  String get listDone => 'Bitti';

  @override
  String get listErrorLoading => 'Listeler yüklenirken hata';

  @override
  String listRemovedFrom(String name) {
    return '$name listesinden kaldırıldı';
  }

  @override
  String listAddedTo(String name) {
    return '$name listesine eklendi';
  }

  @override
  String get listCreateNewList => 'Yeni Liste Oluştur';

  @override
  String get listNewPeopleList => 'Yeni kişi listesi';

  @override
  String get listCollaboratorsNone => 'Yok';

  @override
  String get listAddCollaboratorTitle => 'Ortak ekle';

  @override
  String get listCollaboratorSearchHint => 'diVine\'da ara...';

  @override
  String get listNameLabel => 'Liste Adı';

  @override
  String get listDescriptionLabel => 'Açıklama (opsiyonel)';

  @override
  String get listPublicList => 'Herkese Açık Liste';

  @override
  String get listPublicListSubtitle =>
      'Diğerleri bu listeyi takip edebilir ve görebilir';

  @override
  String get listCancel => 'İptal';

  @override
  String get listCreate => 'Oluştur';

  @override
  String get listCreateFailed => 'Liste oluşturulamadı';

  @override
  String get keyManagementTitle => 'Nostr Anahtarları';

  @override
  String get keyManagementWhatAreKeys => 'Nostr anahtarları nedir?';

  @override
  String get keyManagementExplanation =>
      'Nostr kimliğin bir kriptografik anahtar çiftidir:\n\n• Açık anahtarın (npub) kullanıcı adın gibidir - gönül rahatlığıyla paylaş\n• Özel anahtarın (nsec) parolan gibidir - gizli tut!\n\nnsec\'in herhangi bir Nostr uygulamasında hesabına erişmeni sağlar.';

  @override
  String get keyManagementImportTitle => 'Mevcut Anahtarı İçe Aktar';

  @override
  String get keyManagementImportSubtitle =>
      'Zaten bir Nostr hesabın mı var? Özel anahtarını (nsec) yapıştırarak burada eriş.';

  @override
  String get keyManagementImportButton => 'Anahtarı İçe Aktar';

  @override
  String get keyManagementImportWarning => 'Bu mevcut anahtarını değiştirecek!';

  @override
  String get keyManagementBackupTitle => 'Anahtarını Yedekle';

  @override
  String get keyManagementBackupSubtitle =>
      'Hesabını diğer Nostr uygulamalarında kullanmak için özel anahtarını (nsec) kaydet.';

  @override
  String get keyManagementCopyNsec => 'Özel Anahtarımı (nsec) Kopyala';

  @override
  String get keyManagementNeverShare => 'nsec\'ini asla kimseyle paylaşma!';

  @override
  String get keyManagementPasteKey => 'Lütfen özel anahtarını yapıştır';

  @override
  String get keyManagementInvalidFormat =>
      'Geçersiz anahtar formatı. \"nsec1\" ile başlamalı';

  @override
  String get keyManagementConfirmImportTitle => 'Bu Anahtar İçe Aktarılsın mı?';

  @override
  String get keyManagementConfirmImportBody =>
      'Bu mevcut kimliğini içe aktarılan kimlikle değiştirecek.\n\nÖnce yedeklemediysen mevcut anahtarın kaybolacak.';

  @override
  String get keyManagementImportConfirm => 'İçe Aktar';

  @override
  String get keyManagementImportSuccess => 'Anahtar başarıyla içe aktarıldı!';

  @override
  String keyManagementImportFailed(Object error) {
    return 'Anahtar içe aktarılamadı: $error';
  }

  @override
  String get keyManagementExportSuccess =>
      'Özel anahtar panoya kopyalandı!\n\nGüvenli bir yerde sakla.';

  @override
  String keyManagementExportFailed(Object error) {
    return 'Anahtar dışa aktarılamadı: $error';
  }

  @override
  String get saveOriginalSavedToCameraRoll => 'Kamera Rulosuna Kaydedildi';

  @override
  String get saveOriginalShare => 'Paylaş';

  @override
  String get saveOriginalDone => 'Bitti';

  @override
  String get saveOriginalPhotosAccessNeeded => 'Fotoğraf Erişimi Gerekiyor';

  @override
  String get saveOriginalPhotosAccessMessage =>
      'Videoları kaydetmek için Ayarlar\'dan Fotoğraf erişimine izin ver.';

  @override
  String get saveOriginalOpenSettings => 'Ayarları Aç';

  @override
  String get saveOriginalNotNow => 'Şimdi Değil';

  @override
  String get cameraPermissionNotNow => 'Şimdi Değil';

  @override
  String get saveOriginalDownloadFailed => 'İndirme Başarısız';

  @override
  String get saveOriginalDismiss => 'Kapat';

  @override
  String get saveOriginalDownloadingVideo => 'Video İndiriliyor';

  @override
  String get saveOriginalSavingToCameraRoll => 'Kamera Rulosuna Kaydediliyor';

  @override
  String get saveOriginalFetchingVideo => 'Video ağdan alınıyor...';

  @override
  String get saveOriginalSavingVideo =>
      'Orijinal video kamera rulosuna kaydediliyor...';

  @override
  String get soundTitle => 'Ses';

  @override
  String get soundOriginalSound => 'Orijinal ses';

  @override
  String get soundVideosUsingThisSound => 'Bu sesi kullanan videolar';

  @override
  String get soundSourceVideo => 'Kaynak video';

  @override
  String get soundNoVideosYet => 'Henüz video yok';

  @override
  String get soundBeFirstToUse => 'Bu sesi kullanan ilk kişi ol!';

  @override
  String get soundFailedToLoadVideos => 'Videolar yüklenemedi';

  @override
  String get soundRetry => 'Tekrar Dene';

  @override
  String get soundVideosUnavailable => 'Videolar kullanılamıyor';

  @override
  String get soundCouldNotLoadDetails => 'Video ayrıntıları yüklenemedi';

  @override
  String get soundPreview => 'Önizleme';

  @override
  String get soundStop => 'Durdur';

  @override
  String get soundUseSound => 'Sesi Kullan';

  @override
  String get soundUntitled => 'Untitled sound';

  @override
  String get soundStopPreview => 'Stop preview';

  @override
  String soundPreviewSemanticLabel(String title) {
    return 'Preview $title';
  }

  @override
  String soundViewDetailsSemanticLabel(String title) {
    return 'View details for $title';
  }

  @override
  String get soundNoVideoCount => 'Henüz video yok';

  @override
  String get soundOneVideo => '1 video';

  @override
  String soundVideoCount(int count) {
    return '$count video';
  }

  @override
  String get soundUnableToPreview => 'Ses önizlenemiyor - ses mevcut değil';

  @override
  String soundPreviewFailed(Object error) {
    return 'Önizleme oynatılamadı: $error';
  }

  @override
  String get soundViewSource => 'Kaynağı gör';

  @override
  String get soundCloseTooltip => 'Kapat';

  @override
  String get exploreNotExploreRoute => 'Keşif rotası değil';

  @override
  String get legalTitle => 'Yasal';

  @override
  String get legalTermsOfService => 'Hizmet Şartları';

  @override
  String get legalTermsOfServiceSubtitle => 'Kullanım şartları ve koşulları';

  @override
  String get legalPrivacyPolicy => 'Gizlilik Politikası';

  @override
  String get legalPrivacyPolicySubtitle => 'Verilerini nasıl ele alıyoruz';

  @override
  String get legalSafetyStandards => 'Güvenlik Standartları';

  @override
  String get legalSafetyStandardsSubtitle => 'Topluluk kuralları ve güvenlik';

  @override
  String get legalDmca => 'DMCA';

  @override
  String get legalDmcaSubtitle => 'Telif hakkı ve kaldırma politikası';

  @override
  String get legalOpenSourceLicenses => 'Açık Kaynak Lisansları';

  @override
  String get legalOpenSourceLicensesSubtitle => 'Üçüncü taraf paket atıfları';

  @override
  String get legalAppName => 'Divine';

  @override
  String legalCouldNotOpenPage(String pageName) {
    return '$pageName açılamadı';
  }

  @override
  String legalErrorOpeningPage(String pageName, Object error) {
    return '$pageName açılırken hata: $error';
  }

  @override
  String get categoryAction => 'Aksiyon';

  @override
  String get categoryAdventure => 'Macera';

  @override
  String get categoryAnimals => 'Hayvanlar';

  @override
  String get categoryAnimation => 'Animasyon';

  @override
  String get categoryArchitecture => 'Mimari';

  @override
  String get categoryArt => 'Sanat';

  @override
  String get categoryAutomotive => 'Otomotiv';

  @override
  String get categoryAwardShow => 'Ödül Töreni';

  @override
  String get categoryAwards => 'Ödüller';

  @override
  String get categoryBaseball => 'Beyzbol';

  @override
  String get categoryBasketball => 'Basketbol';

  @override
  String get categoryBeauty => 'Güzellik';

  @override
  String get categoryBeverage => 'İçecek';

  @override
  String get categoryCars => 'Arabalar';

  @override
  String get categoryCelebration => 'Kutlama';

  @override
  String get categoryCelebrities => 'Ünlüler';

  @override
  String get categoryCelebrity => 'Ünlü';

  @override
  String get categoryCityscape => 'Şehir Manzarası';

  @override
  String get categoryComedy => 'Komedi';

  @override
  String get categoryConcert => 'Konser';

  @override
  String get categoryCooking => 'Yemek Pişirme';

  @override
  String get categoryCostume => 'Kostüm';

  @override
  String get categoryCrafts => 'El Sanatları';

  @override
  String get categoryCrime => 'Suç';

  @override
  String get categoryCulture => 'Kültür';

  @override
  String get categoryDance => 'Dans';

  @override
  String get categoryDiy => 'Kendin Yap';

  @override
  String get categoryDrama => 'Dram';

  @override
  String get categoryEducation => 'Eğitim';

  @override
  String get categoryEmotional => 'Duygusal';

  @override
  String get categoryEmotions => 'Duygular';

  @override
  String get categoryEntertainment => 'Eğlence';

  @override
  String get categoryEvent => 'Etkinlik';

  @override
  String get categoryFamily => 'Aile';

  @override
  String get categoryFans => 'Hayranlar';

  @override
  String get categoryFantasy => 'Fantastik';

  @override
  String get categoryFashion => 'Moda';

  @override
  String get categoryFestival => 'Festival';

  @override
  String get categoryFilm => 'Film';

  @override
  String get categoryFitness => 'Fitness';

  @override
  String get categoryFood => 'Yemek';

  @override
  String get categoryFootball => 'Amerikan Futbolu';

  @override
  String get categoryFurniture => 'Mobilya';

  @override
  String get categoryGaming => 'Oyun';

  @override
  String get categoryGolf => 'Golf';

  @override
  String get categoryGrooming => 'Bakım';

  @override
  String get categoryGuitar => 'Gitar';

  @override
  String get categoryHalloween => 'Cadılar Bayramı';

  @override
  String get categoryHealth => 'Sağlık';

  @override
  String get categoryHockey => 'Hokey';

  @override
  String get categoryHoliday => 'Tatil';

  @override
  String get categoryHome => 'Ev';

  @override
  String get categoryHomeImprovement => 'Ev Tadilatı';

  @override
  String get categoryHorror => 'Korku';

  @override
  String get categoryHospital => 'Hastane';

  @override
  String get categoryHumor => 'Mizah';

  @override
  String get categoryInteriorDesign => 'İç Tasarım';

  @override
  String get categoryInterview => 'Röportaj';

  @override
  String get categoryKids => 'Çocuklar';

  @override
  String get categoryLifestyle => 'Yaşam Tarzı';

  @override
  String get categoryMagic => 'Sihir';

  @override
  String get categoryMakeup => 'Makyaj';

  @override
  String get categoryMedical => 'Tıbbi';

  @override
  String get categoryMusic => 'Müzik';

  @override
  String get categoryMystery => 'Gizem';

  @override
  String get categoryNature => 'Doğa';

  @override
  String get categoryNews => 'Haberler';

  @override
  String get categoryOutdoor => 'Açık Hava';

  @override
  String get categoryParty => 'Parti';

  @override
  String get categoryPeople => 'İnsanlar';

  @override
  String get categoryPerformance => 'Performans';

  @override
  String get categoryPets => 'Evcil Hayvanlar';

  @override
  String get categoryPolitics => 'Siyaset';

  @override
  String get categoryPrank => 'Şaka';

  @override
  String get categoryPranks => 'Şakalar';

  @override
  String get categoryRealityShow => 'Reality Şov';

  @override
  String get categoryRelationship => 'İlişki';

  @override
  String get categoryRelationships => 'İlişkiler';

  @override
  String get categoryRomance => 'Romantik';

  @override
  String get categorySchool => 'Okul';

  @override
  String get categoryScienceFiction => 'Bilim Kurgu';

  @override
  String get categorySelfie => 'Selfie';

  @override
  String get categoryShopping => 'Alışveriş';

  @override
  String get categorySkateboarding => 'Kaykay';

  @override
  String get categorySkincare => 'Cilt Bakımı';

  @override
  String get categorySoccer => 'Futbol';

  @override
  String get categorySocialGathering => 'Sosyal Toplantı';

  @override
  String get categorySocialMedia => 'Sosyal Medya';

  @override
  String get categorySports => 'Spor';

  @override
  String get categoryTalkShow => 'Talk Şov';

  @override
  String get categoryTech => 'Tek';

  @override
  String get categoryTechnology => 'Teknoloji';

  @override
  String get categoryTelevision => 'Televizyon';

  @override
  String get categoryToys => 'Oyuncaklar';

  @override
  String get categoryTransportation => 'Ulaşım';

  @override
  String get categoryTravel => 'Seyahat';

  @override
  String get categoryUrban => 'Şehir';

  @override
  String get categoryViolence => 'Şiddet';

  @override
  String get categoryVlog => 'Vlog';

  @override
  String get categoryVlogging => 'Vlog';

  @override
  String get categoryWrestling => 'Güreş';

  @override
  String get profileSetupUploadSuccess =>
      'Profil fotoğrafı başarıyla yüklendi!';

  @override
  String inboxReportedUser(String displayName) {
    return '$displayName bildirildi';
  }

  @override
  String inboxBlockedUser(String displayName) {
    return '$displayName engellendi';
  }

  @override
  String inboxUnblockedUser(String displayName) {
    return '$displayName engeli kaldırıldı';
  }

  @override
  String get inboxRemovedConversation => 'Sohbet kaldırıldı';

  @override
  String get inboxEmptyTitle => 'Henüz mesaj yok';

  @override
  String get inboxEmptySubtitle => '+ tuşu ısırmaz.';

  @override
  String get inboxActionMute => 'Sohbeti sessize al';

  @override
  String inboxActionReport(String displayName) {
    return '$displayName kullanıcısını bildir';
  }

  @override
  String inboxActionBlock(String displayName) {
    return '$displayName kullanıcısını engelle';
  }

  @override
  String inboxActionUnblock(String displayName) {
    return '$displayName kullanıcısının engelini kaldır';
  }

  @override
  String get inboxActionRemove => 'Sohbeti kaldır';

  @override
  String get inboxRemoveConfirmTitle => 'Sohbet kaldırılsın mı?';

  @override
  String inboxRemoveConfirmBody(String displayName) {
    return 'Bu işlem, $displayName ile olan sohbetini siler. Bu işlem geri alınamaz.';
  }

  @override
  String get inboxRemoveConfirmConfirm => 'Kaldır';

  @override
  String get inboxConversationMuted => 'Sohbet sessize alındı';

  @override
  String get inboxConversationUnmuted => 'Sohbet sessizden çıkarıldı';

  @override
  String get inboxCollabInviteCardTitle => 'İşbirliği daveti';

  @override
  String inboxCollabInviteCardRoleLabel(String role) {
    return 'Bu gönderide $role';
  }

  @override
  String get inboxCollabInviteAcceptButton => 'Kabul et';

  @override
  String get inboxCollabInviteIgnoreButton => 'Yoksay';

  @override
  String get inboxCollabInviteAcceptedStatus => 'Kabul edildi';

  @override
  String get inboxCollabInviteIgnoredStatus => 'Yoksayıldı';

  @override
  String get inboxCollabInviteAcceptError => 'Kabul edilemedi. Tekrar dene.';

  @override
  String get inboxCollabInviteSentStatus => 'Davet gönderildi';

  @override
  String get inboxConversationCollabInvitePreview => 'İşbirliği daveti';

  @override
  String get reportDialogCancel => 'İptal';

  @override
  String get reportDialogReport => 'Bildir';

  @override
  String exploreVideoId(String id) {
    return 'ID: $id';
  }

  @override
  String exploreVideoTitle(String title) {
    return 'Başlık: $title';
  }

  @override
  String exploreVideoCounter(int current, int total) {
    return 'Video $current/$total';
  }

  @override
  String get exploreSearchHint => 'Search...';

  @override
  String categoryVideoCount(String count) {
    return '$count videos';
  }

  @override
  String discoverListsFailedToUpdateSubscription(String error) {
    return 'Abonelik güncellenemedi: $error';
  }

  @override
  String get discoverListsTitle => 'Discover Lists';

  @override
  String get discoverListsFailedToLoad => 'Failed to load lists';

  @override
  String discoverListsFailedToLoadWithError(String error) {
    return 'Failed to load lists: $error';
  }

  @override
  String get discoverListsLoading => 'Discovering public lists...';

  @override
  String get discoverListsEmptyTitle => 'No public lists found';

  @override
  String get discoverListsEmptySubtitle => 'Check back later for new lists';

  @override
  String get discoverListsByAuthorPrefix => 'by';

  @override
  String get curatedListEmptyTitle => 'No videos in this list';

  @override
  String get curatedListEmptySubtitle => 'Add some videos to get started';

  @override
  String get curatedListLoadingVideos => 'Loading videos...';

  @override
  String get curatedListFailedToLoad => 'Failed to load list';

  @override
  String get curatedListNoVideosAvailable => 'No videos available';

  @override
  String get curatedListVideoNotAvailable => 'Video not available';

  @override
  String get commonRetry => 'Tekrar dene';

  @override
  String get commonNext => 'İleri';

  @override
  String get commonDelete => 'Sil';

  @override
  String get commonCancel => 'İptal';

  @override
  String get commonBack => 'Back';

  @override
  String get commonClose => 'Close';

  @override
  String get videoMetadataTags => 'Etiketler';

  @override
  String get videoMetadataExpiration => 'Son Kullanma';

  @override
  String get videoMetadataExpirationNotExpire => 'Süresi dolmaz';

  @override
  String get videoMetadataExpirationOneDay => '1 gün';

  @override
  String get videoMetadataExpirationOneWeek => '1 hafta';

  @override
  String get videoMetadataExpirationOneMonth => '1 ay';

  @override
  String get videoMetadataExpirationOneYear => '1 yıl';

  @override
  String get videoMetadataExpirationOneDecade => '1 on yıl';

  @override
  String get videoMetadataContentWarnings => 'İçerik Uyarıları';

  @override
  String get videoEditorStickers => 'Çıkartmalar';

  @override
  String get trendingTitle => 'Gündemde';

  @override
  String get proofmodeCheckAiGenerated =>
      'Yapay zeka ile oluşturulup oluşturulmadığını kontrol et';

  @override
  String get libraryDeleteConfirm => 'Sil';

  @override
  String get libraryWebUnavailableHeadline => 'Kitaplık mobil uygulamada';

  @override
  String get libraryWebUnavailableDescription =>
      'Taslaklar ve klipler cihazında saklanır; yönetmek için Divine’ı telefonda aç.';

  @override
  String get libraryTabDrafts => 'Taslaklar';

  @override
  String get libraryTabClips => 'Klipler';

  @override
  String get librarySaveToCameraRollTooltip => 'Kamera kaydına kaydet';

  @override
  String get libraryDeleteSelectedClipsTooltip => 'Seçili klipleri sil';

  @override
  String get libraryDeleteClipsTitle => 'Klipleri sil';

  @override
  String libraryDeleteClipsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# seçili klibi',
      one: '# seçili klibi',
    );
    return '$_temp0 silmek istiyor musun?';
  }

  @override
  String get libraryDeleteClipsWarning =>
      'Geri alınamaz. Video dosyaları cihazından kalıcı olarak silinir.';

  @override
  String get libraryPreparingVideo => 'Video hazırlanıyor...';

  @override
  String get libraryCreateVideo => 'Video oluştur';

  @override
  String libraryClipsSavedToDestination(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klip',
      one: '1 klip',
    );
    return '$_temp0 $destination konumuna kaydedildi';
  }

  @override
  String libraryClipsSavePartialResult(int successCount, int failureCount) {
    return '$successCount kaydedildi, $failureCount başarısız';
  }

  @override
  String libraryGalleryPermissionDenied(String destination) {
    return '$destination izni reddedildi';
  }

  @override
  String libraryClipsDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klip silindi',
      one: '1 klip silindi',
    );
    return '$_temp0';
  }

  @override
  String get libraryCouldNotLoadDrafts => 'Taslaklar yüklenemedi';

  @override
  String get libraryCouldNotLoadClips => 'Klipler yüklenemedi';

  @override
  String get libraryOpenErrorDescription =>
      'Kitaplık açılırken bir sorun oldu. Tekrar deneyebilirsin.';

  @override
  String get libraryNoDraftsYetTitle => 'Henüz taslak yok';

  @override
  String get libraryNoDraftsYetSubtitle =>
      'Taslak olarak kaydettiğin videolar burada görünür';

  @override
  String get libraryNoClipsYetTitle => 'Henüz klip yok';

  @override
  String get libraryNoClipsYetSubtitle => 'Kaydettiğin videolar burada görünür';

  @override
  String get libraryDraftDeletedSnackbar => 'Taslak silindi';

  @override
  String get libraryDraftDeleteFailedSnackbar => 'Taslak silinemedi';

  @override
  String get libraryDraftActionPost => 'Paylaş';

  @override
  String get libraryDraftActionEdit => 'Düzenle';

  @override
  String get libraryDraftActionDelete => 'Taslağı sil';

  @override
  String get libraryDeleteDraftTitle => 'Taslağı sil';

  @override
  String libraryDeleteDraftMessage(String title) {
    return '\"$title\" silinsin mi?';
  }

  @override
  String get libraryDeleteClipTitle => 'Klibi sil';

  @override
  String get libraryDeleteClipMessage => 'Bu klibi silmek istiyor musun?';

  @override
  String get libraryClipSelectionTitle => 'Klipler';

  @override
  String librarySecondsRemaining(String seconds) {
    return '$seconds sn kaldı';
  }

  @override
  String get libraryAddClips => 'Ekle';

  @override
  String get libraryRecordVideo => 'Video kaydet';

  @override
  String get routerInvalidCreator => 'Geçersiz içerik üretici';

  @override
  String get routerInvalidHashtagRoute => 'Geçersiz hashtag rotası';

  @override
  String get categoryGalleryCouldNotLoadVideos => 'Videolar yüklenemedi';

  @override
  String get categoryGalleryNoVideosInCategory => 'No videos in this category';

  @override
  String get categoryGallerySortOptionsLabel => 'Category sort options';

  @override
  String get categoryGallerySortHot => 'Hot';

  @override
  String get categoryGallerySortNew => 'New';

  @override
  String get categoryGallerySortClassic => 'Classic';

  @override
  String get categoryGallerySortForYou => 'For You';

  @override
  String get categoriesCouldNotLoadCategories => 'Kategoriler yüklenemedi';

  @override
  String get categoriesNoCategoriesAvailable => 'No categories available';

  @override
  String get notificationsEmptyTitle => 'No activity yet';

  @override
  String get notificationsEmptySubtitle =>
      'When people interact with your content, you\'ll see it here';

  @override
  String get appsPermissionsTitle => 'Integration Permissions';

  @override
  String get appsPermissionsRevoke => 'Revoke';

  @override
  String get appsPermissionsEmptyTitle => 'No saved integration permissions';

  @override
  String get appsPermissionsEmptySubtitle =>
      'Approved integrations will appear here after you remember an access approval.';

  @override
  String nostrAppPermissionTitle(String appName) {
    return '$appName wants your approval';
  }

  @override
  String get nostrAppPermissionDescription =>
      'This app is requesting access through Divine\'s vetted sandbox.';

  @override
  String get nostrAppPermissionOrigin => 'Origin';

  @override
  String get nostrAppPermissionMethod => 'Method';

  @override
  String get nostrAppPermissionCapability => 'Capability';

  @override
  String get nostrAppPermissionEventKind => 'Event kind';

  @override
  String get nostrAppPermissionAllow => 'Allow';

  @override
  String get bugReportSendReport => 'Send Report';

  @override
  String get supportSubjectRequiredLabel => 'Subject *';

  @override
  String get supportRequiredHelper => 'Required';

  @override
  String get bugReportSubjectHint => 'Brief summary of the issue';

  @override
  String get bugReportDescriptionRequiredLabel => 'What happened? *';

  @override
  String get bugReportDescriptionHint => 'Describe the issue you encountered';

  @override
  String get bugReportStepsLabel => 'Steps to Reproduce';

  @override
  String get bugReportStepsHint => '1. Go to...\n2. Tap on...\n3. See error';

  @override
  String get bugReportExpectedBehaviorLabel => 'Expected Behavior';

  @override
  String get bugReportExpectedBehaviorHint =>
      'What should have happened instead?';

  @override
  String get bugReportDiagnosticsNotice =>
      'Device info and logs will be included automatically.';

  @override
  String get bugReportSuccessMessage =>
      'Thank you! We\'ve received your report and will use it to make Divine better.';

  @override
  String get bugReportSendFailed =>
      'Failed to send bug report. Please try again later.';

  @override
  String bugReportFailedWithError(String error) {
    return 'Bug report failed to send: $error';
  }

  @override
  String get featureRequestSendRequest => 'Send Request';

  @override
  String get featureRequestSubjectHint => 'Brief summary of your idea';

  @override
  String get featureRequestDescriptionRequiredLabel => 'What would you like? *';

  @override
  String get featureRequestDescriptionHint => 'Describe the feature you want';

  @override
  String get featureRequestUsefulnessLabel => 'How would this be useful?';

  @override
  String get featureRequestUsefulnessHint =>
      'Explain the benefit this feature would provide';

  @override
  String get featureRequestWhenLabel => 'When would you use this?';

  @override
  String get featureRequestWhenHint =>
      'Describe the situations where this would help';

  @override
  String get featureRequestSuccessMessage =>
      'Thank you! We\'ve received your feature request and will review it.';

  @override
  String get featureRequestSendFailed =>
      'Failed to send feature request. Please try again later.';

  @override
  String featureRequestFailedWithError(String error) {
    return 'Feature request failed to send: $error';
  }

  @override
  String get notificationFollowBack => 'Geri takip et';

  @override
  String get followingTitle => 'Following';

  @override
  String followingTitleForName(String displayName) {
    return '$displayName\'s Following';
  }

  @override
  String get followingFailedToLoadList => 'Takip edilen listesi yüklenemedi';

  @override
  String get followingEmptyTitle => 'Not following anyone yet';

  @override
  String get followersTitle => 'Followers';

  @override
  String followersTitleForName(String displayName) {
    return '$displayName\'s Followers';
  }

  @override
  String get followersFailedToLoadList => 'Takipçi listesi yüklenemedi';

  @override
  String get followersEmptyTitle => 'No followers yet';

  @override
  String get followersUpdateFollowFailed =>
      'Failed to update follow status. Please try again.';

  @override
  String get reportMessageTitle => 'Report Message';

  @override
  String get reportMessageWhyReporting => 'Why are you reporting this message?';

  @override
  String get reportMessageSelectReason =>
      'Please select a reason for reporting this message';

  @override
  String get newMessageTitle => 'New message';

  @override
  String get newMessageFindPeople => 'Find people';

  @override
  String get newMessageNoContacts =>
      'No contacts found.\nFollow people to see them here.';

  @override
  String get newMessageNoUsersFound => 'No users found';

  @override
  String get hashtagSearchTitle => 'Search for hashtags';

  @override
  String get hashtagSearchSubtitle => 'Discover trending topics and content';

  @override
  String hashtagSearchNoResults(String query) {
    return 'No hashtags found for \"$query\"';
  }

  @override
  String get hashtagSearchFailed => 'Search failed';

  @override
  String get userNotAvailableTitle => 'Account not available';

  @override
  String get userNotAvailableBody => 'This account isn\'t available right now.';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String blossomFailedToSaveSettings(String error) {
    return 'Ayarlar kaydedilemedi: $error';
  }

  @override
  String get blossomValidServerUrl =>
      'Please enter a valid server URL (e.g., https://blossom.band)';

  @override
  String get blossomSettingsSaved => 'Blossom settings saved';

  @override
  String get blossomSaveTooltip => 'Save';

  @override
  String get blossomAboutTitle => 'About Blossom';

  @override
  String get blossomAboutDescription =>
      'Blossom is a decentralized media storage protocol that allows you to upload videos to any compatible server. By default, videos are uploaded to Divine\'s Blossom server. Enable the option below to use a custom server instead.';

  @override
  String get blossomUseCustomServer => 'Use Custom Blossom Server';

  @override
  String get blossomCustomServerEnabledSubtitle =>
      'Videos will be uploaded to your custom Blossom server';

  @override
  String get blossomCustomServerDisabledSubtitle =>
      'Your videos are currently being uploaded to Divine\'s Blossom server';

  @override
  String get blossomCustomServerUrl => 'Custom Blossom Server URL';

  @override
  String get blossomCustomServerHelper =>
      'Enter the URL of your custom Blossom server';

  @override
  String get blossomPopularServers => 'Popular Blossom Servers';

  @override
  String get blueskyFailedToUpdateCrosspost =>
      'Çapraz gönderi ayarı güncellenemedi';

  @override
  String get blueskySignInRequired => 'Sign in to manage Bluesky settings';

  @override
  String get blueskyPublishVideos => 'Publish videos to Bluesky';

  @override
  String get blueskyEnabledSubtitle =>
      'Your videos will be published to Bluesky';

  @override
  String get blueskyDisabledSubtitle =>
      'Your videos will not be published to Bluesky';

  @override
  String get blueskyHandle => 'Bluesky Handle';

  @override
  String get blueskyStatus => 'Status';

  @override
  String get blueskyStatusReady => 'Account provisioned and ready';

  @override
  String get blueskyStatusPending => 'Account provisioning in progress...';

  @override
  String get blueskyStatusFailed => 'Account provisioning failed';

  @override
  String get blueskyStatusDisabled => 'Account disabled';

  @override
  String get blueskyStatusNotLinked => 'No Bluesky account linked';

  @override
  String get invitesTitle => 'Arkadaşları Davet Et';

  @override
  String invitesGenerateCardTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invites ready to generate',
      one: '1 invite ready to generate',
    );
    return '$_temp0';
  }

  @override
  String get invitesGenerateCardSubtitle =>
      'Generate a code when you are ready to share one.';

  @override
  String get invitesGenerateButtonLabel => 'Generate invite';

  @override
  String get invitesNoneAvailable => 'No invites available right now';

  @override
  String get invitesShareWithPeople => 'Share diVine with people you know';

  @override
  String get invitesUsedInvites => 'Used invites';

  @override
  String invitesShareMessage(String code) {
    return 'Join me on diVine! Use invite code $code to get started:\nhttps://divine.video/invite/$code';
  }

  @override
  String get invitesCopyInvite => 'Copy invite';

  @override
  String get invitesCopied => 'Invite copied!';

  @override
  String get invitesShareInvite => 'Share invite';

  @override
  String get invitesShareSubject => 'Join me on diVine';

  @override
  String get invitesClaimed => 'Claimed';

  @override
  String get invitesCouldNotLoad => 'Could not load invites';

  @override
  String get invitesRetry => 'Retry';

  @override
  String get searchSomethingWentWrong => 'Bir şeyler ters gitti';

  @override
  String get searchTryAgain => 'Tekrar dene';

  @override
  String get searchForLists => 'Liste ara';

  @override
  String get searchFindCuratedVideoLists => 'Küratörlü video listelerini bul';

  @override
  String get searchEnterQuery => 'Bir arama terimi girin';

  @override
  String get searchDiscoverSomethingInteresting => 'İlginç bir şey keşfet';

  @override
  String get searchPeopleSectionHeader => 'People';

  @override
  String get searchPeopleLoadingLabel => 'Loading people results';

  @override
  String get searchTagsSectionHeader => 'Tags';

  @override
  String get searchTagsLoadingLabel => 'Loading tag results';

  @override
  String get searchVideosSectionHeader => 'Videos';

  @override
  String get searchVideosLoadingLabel => 'Loading video results';

  @override
  String get searchListsSectionHeader => 'Listeler';

  @override
  String get searchListsLoadingLabel => 'Liste sonuçları yükleniyor';

  @override
  String get cameraAgeRestriction =>
      'İçerik oluşturmak için 16 yaşında veya daha büyük olmalısın';

  @override
  String get featureRequestCancel => 'İptal';

  @override
  String keyImportError(String error) {
    return 'Hata: $error';
  }

  @override
  String get keyImportInsecureBunkerRelay =>
      'Bunker relay must use wss:// (ws:// is allowed only for localhost)';

  @override
  String get timeNow => 'şimdi';

  @override
  String timeShortMinutes(int count) {
    return '${count}dk';
  }

  @override
  String timeShortHours(int count) {
    return '${count}sa';
  }

  @override
  String timeShortDays(int count) {
    return '${count}g';
  }

  @override
  String timeShortWeeks(int count) {
    return '${count}hf';
  }

  @override
  String timeShortMonths(int count) {
    return '${count}ay';
  }

  @override
  String timeShortYears(int count) {
    return '${count}yıl';
  }

  @override
  String get timeVerboseNow => 'Şimdi';

  @override
  String timeAgo(String time) {
    return '$time önce';
  }

  @override
  String get timeToday => 'Bugün';

  @override
  String get timeYesterday => 'Dün';

  @override
  String get timeJustNow => 'az önce';

  @override
  String timeMinutesAgo(int count) {
    return '${count}dk önce';
  }

  @override
  String timeHoursAgo(int count) {
    return '${count}sa önce';
  }

  @override
  String timeDaysAgo(int count) {
    return '${count}g önce';
  }

  @override
  String get draftTimeJustNow => 'Az önce';

  @override
  String get contentLabelNudity => 'Çıplaklık';

  @override
  String get contentLabelSexualContent => 'Cinsel İçerik';

  @override
  String get contentLabelPornography => 'Pornografi';

  @override
  String get contentLabelGraphicMedia => 'Rahatsız Edici İçerik';

  @override
  String get contentLabelViolence => 'Şiddet';

  @override
  String get contentLabelSelfHarm => 'Kendine Zarar Verme/İntihar';

  @override
  String get contentLabelDrugUse => 'Uyuşturucu Kullanımı';

  @override
  String get contentLabelAlcohol => 'Alkol';

  @override
  String get contentLabelTobacco => 'Tütün/Sigara';

  @override
  String get contentLabelGambling => 'Kumar';

  @override
  String get contentLabelProfanity => 'Küfür';

  @override
  String get contentLabelHateSpeech => 'Nefret Söylemi';

  @override
  String get contentLabelHarassment => 'Taciz';

  @override
  String get contentLabelFlashingLights => 'Yanıp Sönen Işıklar';

  @override
  String get contentLabelAiGenerated => 'Yapay Zekâ Üretimi';

  @override
  String get contentLabelDeepfake => 'Deepfake';

  @override
  String get contentLabelSpam => 'Spam';

  @override
  String get contentLabelScam => 'Dolandırıcılık';

  @override
  String get contentLabelSpoiler => 'Spoiler';

  @override
  String get contentLabelMisleading => 'Yanıltıcı';

  @override
  String get contentLabelSensitiveContent => 'Hassas İçerik';

  @override
  String notificationLikedYourVideo(String actorName) {
    return '$actorName videonu beğendi';
  }

  @override
  String notificationCommentedOnYourVideo(String actorName) {
    return '$actorName videona yorum yaptı';
  }

  @override
  String notificationStartedFollowing(String actorName) {
    return '$actorName seni takip etmeye başladı';
  }

  @override
  String notificationMentionedYou(String actorName) {
    return '$actorName senden bahsetti';
  }

  @override
  String notificationRepostedYourVideo(String actorName) {
    return '$actorName videonu paylaştı';
  }

  @override
  String get notificationRepliedToYourComment => 'yorumuna yanıt verdi';

  @override
  String get notificationAndConnector => 've';

  @override
  String notificationOthersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kişi daha',
      one: '1 kişi daha',
    );
    return '$_temp0';
  }

  @override
  String get commentReplyToPrefix => 'Yan:';

  @override
  String get draftUntitled => 'Başlıksız';

  @override
  String get contentWarningNone => 'Yok';

  @override
  String get textBackgroundNone => 'Yok';

  @override
  String get textBackgroundSolid => 'Opak';

  @override
  String get textBackgroundHighlight => 'Vurgulama';

  @override
  String get textBackgroundTransparent => 'Saydam';

  @override
  String get textAlignLeft => 'Sol';

  @override
  String get textAlignRight => 'Sağ';

  @override
  String get textAlignCenter => 'Ortala';

  @override
  String get cameraPermissionWebUnsupportedTitle =>
      'Kamera henüz web\'de desteklenmiyor';

  @override
  String get cameraPermissionWebUnsupportedDescription =>
      'Kamera ile çekim ve kayıt henüz web sürümünde kullanılamıyor.';

  @override
  String get cameraPermissionBackToFeed => 'Akışa geri dön';

  @override
  String get cameraPermissionErrorTitle => 'İzin hatası';

  @override
  String get cameraPermissionErrorDescription =>
      'İzinler kontrol edilirken bir sorun oluştu.';

  @override
  String get cameraPermissionRetry => 'Tekrar dene';

  @override
  String get cameraPermissionAllowAccessTitle =>
      'Kamera ve mikrofona erişime izin ver';

  @override
  String get cameraPermissionAllowAccessDescription =>
      'Bu, videoları doğrudan uygulama içinde çekip düzenlemeni sağlar, daha fazlasını değil.';

  @override
  String get cameraPermissionContinue => 'Devam et';

  @override
  String get cameraPermissionGoToSettings => 'Ayarlara git';

  @override
  String get videoRecorderWhySixSecondsTitle => 'Neden altı saniye?';

  @override
  String get videoRecorderWhySixSecondsSubtitle =>
      'Kısa klipler kendiliğindenlik için alan yaratır. 6 saniyelik format, anların gerçekleştiği anda otantik anları yakalamanıza yardımcı olur.';

  @override
  String get videoRecorderWhySixSecondsButton => 'Anladım!';

  @override
  String get videoRecorderAutosaveFoundTitle => 'Devam eden bir çalışma bulduk';

  @override
  String get videoRecorderAutosaveFoundSubtitle =>
      'Kaldığınız yerden devam etmek ister misiniz?';

  @override
  String get videoRecorderAutosaveContinueButton => 'Evet, devam et';

  @override
  String get videoRecorderAutosaveDiscardButton => 'Hayır, yeni video başlat';

  @override
  String get videoRecorderAutosaveRestoreFailure =>
      'Taslağınız geri yüklenemedi';

  @override
  String get videoRecorderStopRecordingTooltip => 'Kaydı durdur';

  @override
  String get videoRecorderStartRecordingTooltip => 'Kaydı başlat';

  @override
  String get videoRecorderRecordingTapToStopLabel =>
      'Kaydediliyor. Durdurmak için herhangi bir yere dokunun';

  @override
  String get videoRecorderTapToStartLabel =>
      'Kaydı başlatmak için herhangi bir yere dokunun';

  @override
  String get videoRecorderDeleteLastClipLabel => 'Son klibi sil';

  @override
  String get videoRecorderSwitchCameraLabel => 'Kamerayı değiştir';

  @override
  String get videoRecorderToggleGridLabel => 'Izgarayı değiştir';

  @override
  String get videoRecorderToggleGhostFrameLabel => 'Hayalet kareyi değiştir';

  @override
  String get videoRecorderGhostFrameEnabled => 'Hayalet kare etkin';

  @override
  String get videoRecorderGhostFrameDisabled => 'Hayalet kare devre dışı';

  @override
  String get videoRecorderClipDeletedMessage => 'Klip silindi';

  @override
  String get videoRecorderCloseLabel => 'Video kaydediciyi kapat';

  @override
  String get videoRecorderContinueToEditorLabel =>
      'Video düzenleyiciye devam et';

  @override
  String get videoRecorderCaptureCloseLabel => 'Kapat';

  @override
  String get videoRecorderCaptureNextLabel => 'İleri';

  @override
  String get videoRecorderToggleFlashLabel => 'Flaşı değiştir';

  @override
  String get videoRecorderCycleTimerLabel => 'Zamanlayıcıyı değiştir';

  @override
  String get videoRecorderToggleAspectRatioLabel => 'En-boy oranını değiştir';

  @override
  String get videoRecorderLibraryEmptyLabel => 'Klip kütüphanesi, klip yok';

  @override
  String videoRecorderLibraryOpenLabel(int clipCount) {
    String _temp0 = intl.Intl.pluralLogic(
      clipCount,
      locale: localeName,
      other: 'Klip kütüphanesini aç, $clipCount klip',
      one: 'Klip kütüphanesini aç, 1 klip',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorCameraLabel => 'Kamera';

  @override
  String get videoEditorOpenCameraSemanticLabel => 'Kamerayı aç';

  @override
  String get videoEditorLibraryLabel => 'Kütüphane';

  @override
  String get videoEditorTextLabel => 'Metin';

  @override
  String get videoEditorDrawLabel => 'Çiz';

  @override
  String get videoEditorFilterLabel => 'Filtre';

  @override
  String get videoEditorAudioLabel => 'Ses';

  @override
  String get videoEditorVolumeLabel => 'Ses seviyesi';

  @override
  String get videoEditorAddTitle => 'Ekle';

  @override
  String get videoEditorOpenLibrarySemanticLabel => 'Kütüphaneyi aç';

  @override
  String get videoEditorOpenAudioSemanticLabel => 'Ses düzenleyiciyi aç';

  @override
  String get videoEditorOpenTextSemanticLabel => 'Metin düzenleyiciyi aç';

  @override
  String get videoEditorOpenDrawSemanticLabel => 'Çizim düzenleyiciyi aç';

  @override
  String get videoEditorOpenFilterSemanticLabel => 'Filtre düzenleyiciyi aç';

  @override
  String get videoEditorOpenStickerSemanticLabel => 'Stiker düzenleyiciyi aç';

  @override
  String get videoEditorSaveDraftTitle => 'Taslağınızı kaydedin?';

  @override
  String get videoEditorSaveDraftSubtitle =>
      'Düzenlemelerinizi sonraya kaydedin veya atıp düzenleyiciden çıkın.';

  @override
  String get videoEditorSaveDraftButton => 'Taslağı kaydet';

  @override
  String get videoEditorDiscardChangesButton => 'Değişiklikleri sil';

  @override
  String get videoEditorKeepEditingButton => 'Düzenlemeye devam et';

  @override
  String get videoEditorDeleteLayerDropZone => 'Katman silme bırakma alanı';

  @override
  String get videoEditorReleaseToDeleteLayer => 'Katmanı silmek için bırak';

  @override
  String get videoEditorDoneLabel => 'Bitti';

  @override
  String get videoEditorPlayPauseSemanticLabel => 'Videoyu oynat veya duraklat';

  @override
  String get videoEditorCropSemanticLabel => 'Kırp';

  @override
  String get videoEditorCannotSplitProcessing =>
      'Klip işlenirken bölünemez. Lütfen bekleyin.';

  @override
  String videoEditorSplitPositionInvalid(int minDurationMs) {
    return 'Bölme konumu geçersiz. Her iki klip de en az ${minDurationMs}ms uzunluğunda olmalıdır.';
  }

  @override
  String get videoEditorAddClipFromLibrary => 'Kütüphaneden klip ekle';

  @override
  String get videoEditorSaveSelectedClip => 'Seçili klibi kaydet';

  @override
  String get videoEditorSplitClip => 'Klibi böl';

  @override
  String get videoEditorSaveClip => 'Klibi kaydet';

  @override
  String get videoEditorDeleteClip => 'Klibi sil';

  @override
  String get videoEditorClipSavedSuccess => 'Klip kütüphaneye kaydedildi';

  @override
  String get videoEditorClipSaveFailed => 'Klip kaydedilemedi';

  @override
  String get videoEditorClipDeleted => 'Klip silindi';

  @override
  String get videoEditorColorPickerSemanticLabel => 'Renk seçici';

  @override
  String get videoEditorUndoSemanticLabel => 'Geri al';

  @override
  String get videoEditorRedoSemanticLabel => 'Yinele';

  @override
  String get videoEditorTextColorSemanticLabel => 'Metin rengi';

  @override
  String get videoEditorTextAlignmentSemanticLabel => 'Metin hizalama';

  @override
  String get videoEditorTextBackgroundSemanticLabel => 'Metin arka planı';

  @override
  String get videoEditorFontSemanticLabel => 'Yazı tipi';

  @override
  String get videoEditorNoStickersFound => 'Çıkartma bulunamadı';

  @override
  String get videoEditorNoStickersAvailable => 'Kullanılabilir çıkartma yok';

  @override
  String get videoEditorFailedLoadStickers => 'Çıkartmalar yüklenemedi';

  @override
  String get videoEditorAdjustVolumeTitle => 'Ses seviyesini ayarla';

  @override
  String get videoEditorRecordedAudioLabel => 'Kaydedilmiş ses';

  @override
  String get videoEditorCustomAudioLabel => 'Özel ses';

  @override
  String get videoEditorPlaySemanticLabel => 'Oynat';

  @override
  String get videoEditorPauseSemanticLabel => 'Duraklat';

  @override
  String get videoEditorMuteAudioSemanticLabel => 'Sesi kapat';

  @override
  String get videoEditorUnmuteAudioSemanticLabel => 'Sesi aç';

  @override
  String get videoEditorDeleteLabel => 'Sil';

  @override
  String get videoEditorDeleteSelectedItemSemanticLabel => 'Seçili öğeyi sil';

  @override
  String get videoEditorEditLabel => 'Düzenle';

  @override
  String get videoEditorEditSelectedItemSemanticLabel => 'Seçili öğeyi düzenle';

  @override
  String get videoEditorDuplicateLabel => 'Çoğalt';

  @override
  String get videoEditorDuplicateSelectedItemSemanticLabel =>
      'Seçili öğeyi çoğalt';

  @override
  String get videoEditorSplitLabel => 'Böl';

  @override
  String get videoEditorSplitSelectedClipSemanticLabel => 'Seçili klibi böl';

  @override
  String get videoEditorFinishTimelineEditingSemanticLabel =>
      'Zaman çizelgesi düzenlemeyi bitir';

  @override
  String get videoEditorAudioPlayPreviewSemanticLabel => 'Önizlemeyi oynat';

  @override
  String get videoEditorAudioPausePreviewSemanticLabel => 'Önizlemeyi duraklat';

  @override
  String get videoEditorAudioUntitledSound => 'Başlıksız ses';

  @override
  String get videoEditorAudioUntitled => 'Başlıksız';

  @override
  String get videoEditorAudioAddAudio => 'Ses ekle';

  @override
  String get videoEditorAudioNoSoundsAvailableTitle => 'Kullanılabilir ses yok';

  @override
  String get videoEditorAudioNoSoundsAvailableSubtitle =>
      'İçerik üreticileri ses paylaştığında burada görünür';

  @override
  String get videoEditorAudioFailedToLoadTitle => 'Sesler yüklenemedi';

  @override
  String get videoEditorAudioSegmentInstruction =>
      'Videon için ses bölümünü seç';

  @override
  String get videoEditorAudioCategoryDivine => 'diVine';

  @override
  String get videoEditorAudioCategoryCommunity => 'Topluluk';

  @override
  String get videoEditorDrawToolArrowSemanticLabel => 'Ok aracı';

  @override
  String get videoEditorDrawToolEraserSemanticLabel => 'Silgi aracı';

  @override
  String get videoEditorDrawToolMarkerSemanticLabel => 'İşaretleyici aracı';

  @override
  String get videoEditorDrawToolPencilSemanticLabel => 'Kalem aracı';

  @override
  String videoEditorLayerReorderLabel(int index) {
    return 'Katman $index\'i yeniden sırala';
  }

  @override
  String get videoEditorLayerReorderHint => 'Yeniden sıralamak için basılı tut';

  @override
  String get videoEditorShowTimelineSemanticLabel => 'Zaman çizelgesini göster';

  @override
  String get videoEditorHideTimelineSemanticLabel => 'Zaman çizelgesini gizle';

  @override
  String get videoEditorFeedPreviewContent =>
      'Bu alanların arkasına içerik yerleştirmekten kaçının.';

  @override
  String get videoEditorStickersDivineOriginals => 'Divine Orijinaller';

  @override
  String get videoEditorStickerSearchHint => 'Çıkartma ara...';

  @override
  String get videoEditorSelectFontSemanticLabel => 'Yazı tipi seç';

  @override
  String get videoEditorFontUnknown => 'Bilinmiyor';

  @override
  String get videoEditorSplitPlayheadOutsideClip =>
      'Bölmek için oynatma kafası seçili klip içinde olmalıdır.';

  @override
  String get videoEditorTimelineTrimStartSemanticLabel => 'Başlangıcı kırp';

  @override
  String get videoEditorTimelineTrimEndSemanticLabel => 'Sonu kırp';

  @override
  String get videoEditorTimelineTrimClipSemanticLabel => 'Klibi kırp';

  @override
  String get videoEditorTimelineTrimClipHint =>
      'Klip süresini ayarlamak için tutamaçları sürükleyin';

  @override
  String videoEditorTimelineDraggingClipSemanticLabel(int index) {
    return '$index. klip sürükleniyor';
  }

  @override
  String videoEditorTimelineClipSemanticLabel(
    int index,
    int total,
    String duration,
  ) {
    return '$total klipten $index. klip, $duration saniye';
  }

  @override
  String get videoEditorTimelineClipReorderHint =>
      'Yeniden sıralamak için uzun basın';

  @override
  String get videoEditorClipGalleryInstruction =>
      'Düzenlemek için dokun. Yeniden sıralamak için basılı tutup sürükle.';

  @override
  String get videoEditorTimelineClipMoveLeft => 'Sola taşı';

  @override
  String get videoEditorTimelineClipMoveRight => 'Sağa taşı';

  @override
  String get videoEditorTimelineLongPressToDragHint =>
      'Sürüklemek için uzun basın';

  @override
  String get videoEditorVideoTimelineSemanticLabel => 'Video zaman çizelgesi';

  @override
  String videoEditorTimelinePositionFormat(int minutes, String seconds) {
    return '${minutes}d ${seconds}s';
  }

  @override
  String videoEditorColorSelectedSemanticLabel(String colorName) {
    return '$colorName, seçildi';
  }

  @override
  String get videoEditorCloseColorPickerSemanticLabel => 'Renk seçiciyi kapat';

  @override
  String get videoEditorPickColorTitle => 'Renk seç';

  @override
  String get videoEditorConfirmColorSemanticLabel => 'Rengi onayla';

  @override
  String get videoEditorSaturationBrightnessSemanticLabel =>
      'Doygunluk ve parlaklık';

  @override
  String videoEditorSaturationBrightnessValue(int saturation, int brightness) {
    return 'Doygunluk $saturation%, Parlaklık $brightness%';
  }

  @override
  String get videoEditorHueSemanticLabel => 'Ton';

  @override
  String get videoEditorAddElementSemanticLabel => 'Öğe ekle';

  @override
  String get videoEditorCloseSemanticLabel => 'Kapat';

  @override
  String get videoEditorDoneSemanticLabel => 'Bitti';

  @override
  String get videoEditorLevelSemanticLabel => 'Seviye';

  @override
  String get videoMetadataBackSemanticLabel => 'Geri';

  @override
  String get videoMetadataDismissHelpDialogSemanticLabel =>
      'Yardım iletişim kutusunu kapat';

  @override
  String get videoMetadataGotItButton => 'Anladım!';

  @override
  String get videoMetadataLimitReachedWarning =>
      '64KB sınırına ulaşıldı. Devam etmek için bazı içerikleri kaldırın.';

  @override
  String get videoMetadataExpirationLabel => 'Son kullanma tarihi';

  @override
  String get videoMetadataSelectExpirationSemanticLabel =>
      'Son kullanma zamanını seç';

  @override
  String get videoMetadataTitleLabel => 'Başlık';

  @override
  String get videoMetadataDescriptionLabel => 'Açıklama';

  @override
  String get videoMetadataTagsLabel => 'Etiketler';

  @override
  String get videoMetadataDeleteTagSemanticLabel => 'Sil';

  @override
  String videoMetadataDeleteTagHint(String tag) {
    return '$tag etiketini sil';
  }

  @override
  String get videoMetadataContentWarningLabel => 'İçerik Uyarısı';

  @override
  String get videoMetadataSelectContentWarningsSemanticLabel =>
      'İçerik uyarılarını seç';

  @override
  String get videoMetadataContentWarningSelectAllThatApply =>
      'İçeriğinize uyanların hepsini seçin';

  @override
  String get videoMetadataContentWarningDoneButton => 'Bitti';

  @override
  String get videoMetadataCollaboratorsLabel => 'Ortak çalışanlar';

  @override
  String get videoMetadataAddCollaboratorSemanticLabel => 'Ortak çalışan ekle';

  @override
  String get videoMetadataCollaboratorsHelpTooltip =>
      'Ortak çalışanlar nasıl çalışır?';

  @override
  String videoMetadataCollaboratorsCount(int count, int max) {
    return '$count/$max Ortak çalışan';
  }

  @override
  String get videoMetadataRemoveCollaboratorSemanticLabel =>
      'Ortak çalışanı kaldır';

  @override
  String get videoMetadataCollaboratorsHelpMessage =>
      'Ortak çalışanlar bu gönderide ortak içerik üretici olarak etiketlenir. Yalnızca karşılıklı takip ettiğiniz kişileri ekleyebilirsiniz; yayınlandığında gönderi meta verilerinde görünürler.';

  @override
  String get videoMetadataMutualFollowersSearchText => 'Karşılıklı takipçiler';

  @override
  String videoMetadataMustMutuallyFollowSnackbar(String name) {
    return '$name\'i ortak çalışan olarak eklemek için karşılıklı takipleşmeniz gerekiyor.';
  }

  @override
  String get videoMetadataInspiredByLabel => 'İlham kaynağı';

  @override
  String get videoMetadataSetInspiredBySemanticLabel =>
      'İlham kaynağını ayarla';

  @override
  String get videoMetadataInspiredByHelpTooltip =>
      'İlham kredileri nasıl çalışır?';

  @override
  String get videoMetadataInspiredByNone => 'Yok';

  @override
  String get videoMetadataInspiredByHelpMessage =>
      'Atıf vermek için kullanın. İlham kredisi ortak çalışanlardan farklıdır: etkiyi kabul eder, ancak birini ortak içerik üretici olarak etiketlemez.';

  @override
  String get videoMetadataCreatorCannotBeReferencedSnackbar =>
      'Bu içerik üreticisi referans alınamaz.';

  @override
  String get videoMetadataRemoveInspiredBySemanticLabel =>
      'İlham kaynağını kaldır';

  @override
  String get videoMetadataPostDetailsTitle => 'Gönderi ayrıntıları';

  @override
  String get videoMetadataSavedToLibrarySnackbar => 'Kütüphaneye kaydedildi';

  @override
  String get videoMetadataFailedToSaveSnackbar => 'Kaydedilemedi';

  @override
  String get videoMetadataGoToLibraryButton => 'Kütüphaneye git';

  @override
  String get videoMetadataSaveForLaterSemanticLabel => 'Sonra kaydet düğmesi';

  @override
  String get videoMetadataRenderingVideoHint => 'Video işleniyor...';

  @override
  String get videoMetadataSavingVideoHint => 'Video kaydediliyor...';

  @override
  String videoMetadataSaveToDraftsHint(String destination) {
    return 'Videoyu taslağa ve $destination\'a kaydet';
  }

  @override
  String get videoMetadataSaveForLaterButton => 'Sonra Kaydet';

  @override
  String get videoMetadataPostSemanticLabel => 'Paylaş düğmesi';

  @override
  String get videoMetadataPublishVideoHint => 'Videoyu akışa yayınla';

  @override
  String get videoMetadataFormNotReadyHint =>
      'Etkinleştirmek için formu doldurun';

  @override
  String get videoMetadataPostButton => 'Paylaş';

  @override
  String get videoMetadataOpenPreviewSemanticLabel =>
      'Gönderi önizleme ekranını aç';

  @override
  String get videoMetadataShareTitle => 'Paylaş';

  @override
  String get videoMetadataVideoDetailsSubtitle => 'Video ayrıntıları';

  @override
  String get videoMetadataClassicDoneButton => 'Bitti';

  @override
  String get videoMetadataPlayPreviewSemanticLabel => 'Önizlemeyi oynat';

  @override
  String get videoMetadataPausePreviewSemanticLabel => 'Önizlemeyi duraklat';

  @override
  String get videoMetadataClosePreviewSemanticLabel =>
      'Video önizlemesini kapat';

  @override
  String get videoMetadataRemoveSemanticLabel => 'Kaldır';

  @override
  String get metadataCaptionsLabel => 'Altyazılar';

  @override
  String get metadataCaptionsEnabledSemantics =>
      'Tüm videolar için altyazılar etkin';

  @override
  String get metadataCaptionsDisabledSemantics =>
      'Tüm videolar için altyazılar devre dışı';

  @override
  String get fullscreenFeedRemovedMessage => 'Video kaldırıldı';

  @override
  String get settingsBadgesTitle => 'Badges';

  @override
  String get settingsBadgesSubtitle =>
      'Accept awards and check issued badge status.';

  @override
  String get badgesTitle => 'Badges';

  @override
  String get badgesIntroTitle => 'Understand your badge trail';

  @override
  String get badgesIntroBody =>
      'See badge awards sent to you, choose what to pin to your Nostr profile, and check whether people accepted badges you issued.';

  @override
  String get badgesOpenApp => 'Open badges app';

  @override
  String get badgesLoadError => 'Could not load badges';

  @override
  String get badgesUpdateError => 'Could not update badge';

  @override
  String get badgesAwardedSectionTitle => 'Awarded to you';

  @override
  String get badgesAwardedEmptyTitle => 'No badge awards yet';

  @override
  String get badgesAwardedEmptySubtitle =>
      'When someone awards you a Nostr badge, it will land here.';

  @override
  String get badgesStatusAccepted => 'Accepted';

  @override
  String get badgesStatusNotAccepted => 'Not accepted';

  @override
  String get badgesActionRemove => 'Remove';

  @override
  String get badgesActionAccept => 'Accept';

  @override
  String get badgesActionReject => 'Reject';

  @override
  String get badgesIssuedSectionTitle => 'Issued by you';

  @override
  String get badgesIssuedEmptyTitle => 'No issued badges yet';

  @override
  String get badgesIssuedEmptySubtitle =>
      'Badges you issue will show acceptance status here.';

  @override
  String get badgesIssuedNoRecipients => 'No recipients found for this award.';

  @override
  String get badgesRecipientAcceptedStatus => 'Accepted by recipient';

  @override
  String get badgesRecipientWaitingStatus => 'Waiting for recipient';
}
