// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get feedTuningMoreLabel => 'More like this';

  @override
  String get feedTuningLessLabel => 'Less like this';

  @override
  String get feedTuningUndo => 'Undo';

  @override
  String get dmMessageBubbleVideoReplyHint => 'Buka video yang dirujuk';

  @override
  String get appTitle => 'Divine';

  @override
  String get settingsTitle => 'Pengaturan';

  @override
  String get settingsSecureAccount => 'Amankan Akunmu';

  @override
  String get settingsSessionExpired => 'Sesi Kedaluwarsa';

  @override
  String get settingsSessionExpiredSubtitle =>
      'Masuk lagi untuk memulihkan akses penuh';

  @override
  String get settingsCreatorAnalytics => 'Analitik Kreator';

  @override
  String get settingsSupportCenter => 'Pusat Bantuan';

  @override
  String get settingsNotifications => 'Notifikasi';

  @override
  String get settingsContentPreferences => 'Preferensi Konten';

  @override
  String get settingsModerationControls => 'Kontrol Moderasi';

  @override
  String get settingsBlueskyPublishing => 'Publikasi Bluesky';

  @override
  String get settingsBlueskyPublishingSubtitle =>
      'Atur crossposting ke Bluesky';

  @override
  String get settingsNostrSettings => 'Pengaturan Nostr';

  @override
  String get settingsIntegratedApps => 'Aplikasi Terintegrasi';

  @override
  String get settingsIntegratedAppsSubtitle =>
      'Aplikasi pihak ketiga yang disetujui dan berjalan di dalam Divine';

  @override
  String get settingsExperimentalFeatures => 'Fitur Eksperimental';

  @override
  String get settingsExperimentalFeaturesSubtitle =>
      'Penyesuaian yang bisa bermasalah—coba kalau penasaran.';

  @override
  String get settingsLegal => 'Legal';

  @override
  String get settingsIntegrationPermissions => 'Izin Integrasi';

  @override
  String get settingsIntegrationPermissionsSubtitle =>
      'Tinjau dan cabut izin integrasi yang disimpan';

  @override
  String settingsVersion(String version) {
    return 'Versi $version';
  }

  @override
  String get settingsVersionEmpty => 'Versi';

  @override
  String get settingsDeveloperModeAlreadyEnabled =>
      'Mode pengembang sudah aktif';

  @override
  String get settingsDeveloperModeEnabled => 'Mode pengembang aktif!';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    return '$count ketukan lagi untuk mengaktifkan mode pengembang';
  }

  @override
  String get settingsInvites => 'Undangan';

  @override
  String get settingsSwitchAccount => 'Ganti akun';

  @override
  String get settingsAddAnotherAccount => 'Tambah akun lain';

  @override
  String get settingsUnsavedDraftsTitle => 'Draf Belum Tersimpan';

  @override
  String settingsUnsavedDraftsMessage(int count) {
    return 'Kamu punya $count draf yang belum disimpan. Mengganti akun akan tetap menyimpan drafmu, tapi mungkin kamu ingin mempublikasikan atau meninjaunya dulu.';
  }

  @override
  String get settingsCancel => 'Batal';

  @override
  String get settingsSwitchAnyway => 'Tetap Ganti';

  @override
  String get settingsAppVersionLabel => 'Versi aplikasi';

  @override
  String get settingsAppLanguage => 'Bahasa Aplikasi';

  @override
  String settingsAppLanguageDeviceDefault(String language) {
    return '$language (bawaan perangkat)';
  }

  @override
  String get settingsAppLanguageTitle => 'Bahasa Aplikasi';

  @override
  String get settingsAppLanguageDescription =>
      'Pilih bahasa untuk antarmuka aplikasi';

  @override
  String get settingsAppLanguageUseDeviceLanguage => 'Pakai bahasa perangkat';

  @override
  String get settingsGeneralTitle => 'Pengaturan Umum';

  @override
  String get settingsContentSafetyTitle => 'Konten & Keamanan';

  @override
  String get generalSettingsSectionIntegrations => 'INTEGRASI';

  @override
  String get generalSettingsSectionViewing => 'MENONTON';

  @override
  String get generalSettingsSectionCreating => 'MEMBUAT';

  @override
  String get generalSettingsSectionApp => 'APLIKASI';

  @override
  String get generalSettingsClosedCaptions => 'Teks Tertutup';

  @override
  String get generalSettingsClosedCaptionsSubtitle =>
      'Tampilkan teks saat video menyertakannya';

  @override
  String get generalSettingsVideoShape => 'Bentuk Video';

  @override
  String get generalSettingsVideoShapeSquareOnly => 'Video persegi saja';

  @override
  String get generalSettingsVideoShapeSquareAndPortrait => 'Persegi dan potret';

  @override
  String get generalSettingsVideoShapeSquareAndPortraitSubtitle =>
      'Tampilkan semua jenis video Divine';

  @override
  String get generalSettingsVideoShapeSquareOnlySubtitle =>
      'Pertahankan feed dalam format persegi klasik';

  @override
  String get contentPreferencesTitle => 'Preferensi Konten';

  @override
  String get contentPreferencesContentFilters => 'Filter Konten';

  @override
  String get contentPreferencesContentFiltersSubtitle =>
      'Atur filter peringatan konten';

  @override
  String get contentPreferencesContentLanguage => 'Bahasa Konten';

  @override
  String contentPreferencesContentLanguageDeviceDefault(String language) {
    return '$language (bawaan perangkat)';
  }

  @override
  String get contentPreferencesTagYourVideos =>
      'Tandai videomu dengan bahasa supaya penonton bisa memfilter konten.';

  @override
  String get contentPreferencesUseDeviceLanguage =>
      'Pakai bahasa perangkat (bawaan)';

  @override
  String get contentPreferencesAudioSharing =>
      'Jadikan audioku bisa dipakai ulang';

  @override
  String get contentPreferencesAudioSharingSubtitle =>
      'Saat aktif, orang lain bisa memakai audio dari videomu';

  @override
  String get contentPreferencesAccountLabels => 'Label Akun';

  @override
  String get contentPreferencesAccountLabelsEmpty =>
      'Beri label sendiri pada kontenmu';

  @override
  String get contentPreferencesAccountContentLabels => 'Label Konten Akun';

  @override
  String get contentPreferencesClearAll => 'Hapus Semua';

  @override
  String get contentPreferencesSelectAllThatApply =>
      'Pilih semua yang sesuai dengan akunmu';

  @override
  String get contentPreferencesDoneNoLabels => 'Selesai (Tanpa Label)';

  @override
  String contentPreferencesDoneCount(int count) {
    return 'Selesai ($count dipilih)';
  }

  @override
  String get contentPreferencesAudioInputDevice => 'Perangkat Masukan Audio';

  @override
  String get contentPreferencesAutoRecommended => 'Otomatis (direkomendasikan)';

  @override
  String get contentPreferencesAutoSelectsBest =>
      'Pilih mikrofon terbaik secara otomatis';

  @override
  String get contentPreferencesSelectAudioInput => 'Pilih Masukan Audio';

  @override
  String get contentPreferencesUnknownMicrophone => 'Mikrofon Tidak Dikenal';

  @override
  String get contentFiltersAdultContent => 'KONTEN DEWASA';

  @override
  String get contentFiltersViolenceGore => 'KEKERASAN & SADIS';

  @override
  String get contentFiltersSubstances => 'ZAT TERLARANG';

  @override
  String get contentFiltersOther => 'LAINNYA';

  @override
  String get contentFiltersAgeGateMessage =>
      'Verifikasi usiamu di pengaturan Keamanan & Privasi untuk membuka filter konten dewasa';

  @override
  String get contentFiltersShow => 'Tampilkan';

  @override
  String get contentFiltersWarn => 'Peringatkan';

  @override
  String get contentFiltersFilterOut => 'Saring';

  @override
  String get profileBlockedAccountNotAvailable => 'Akun ini tidak tersedia';

  @override
  String get profileInvalidId => 'ID profil tidak valid';

  @override
  String profileShareText(String displayName, String npub) {
    return 'Lihat $displayName di Divine!\n\nhttps://divine.video/profile/$npub';
  }

  @override
  String profileShareSubject(String displayName) {
    return '$displayName di Divine';
  }

  @override
  String profileShareFailed(Object error) {
    return 'Gagal membagikan profil: $error';
  }

  @override
  String get profileEditProfile => 'Ubah profil';

  @override
  String get profileCreatorAnalytics => 'Analitik kreator';

  @override
  String get profileShareProfile => 'Bagikan profil';

  @override
  String get profileCopyPublicKey => 'Salin kunci publik (npub)';

  @override
  String get profileGetEmbedCode => 'Dapatkan kode sematan';

  @override
  String get profilePublicKeyCopied => 'Kunci publik disalin ke clipboard';

  @override
  String get profileEmbedCodeCopied => 'Kode sematan disalin ke clipboard';

  @override
  String get profileRefreshTooltip => 'Segarkan';

  @override
  String get profileRefreshSemanticLabel => 'Segarkan profil';

  @override
  String get profileMoreTooltip => 'Lainnya';

  @override
  String get profileMoreSemanticLabel => 'Opsi lainnya';

  @override
  String get profileAvatarLightboxBarrierLabel => 'Tutup avatar';

  @override
  String get profileAvatarLightboxCloseSemanticLabel =>
      'Tutup pratinjau avatar';

  @override
  String get profileFollowingLabel => 'Mengikuti';

  @override
  String get profileFollowLabel => 'Ikuti';

  @override
  String get profileBlockedLabel => 'Diblokir';

  @override
  String get profileFollowersLabel => 'Pengikut';

  @override
  String get profileFollowingStatLabel => 'Mengikuti';

  @override
  String get profileVideosLabel => 'Video';

  @override
  String profileCollaboratorInvitePendingHeadline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count collaborator invites still need to send',
      one: '1 collaborator invite still needs to send',
    );
    return '$_temp0';
  }

  @override
  String get profileCollaboratorInvitePendingDetail =>
      'We kept the invite queued. Retry it here.';

  @override
  String profileCollaboratorInvitePendingDetailWithTitle(String title) {
    return 'For \"$title\". Retry it here.';
  }

  @override
  String get profileCollaboratorInviteRetryAction => 'Retry';

  @override
  String get profileCollaboratorInviteRetryingAction => 'Retrying';

  @override
  String get profileCollaboratorInviteRetryUnavailable =>
      'Collaborator invite retry is unavailable right now.';

  @override
  String profileCollaboratorInviteRetryResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count collaborator invites still need to send.',
      one: '1 collaborator invite still needs to send.',
      zero: 'Collaborator invites sent.',
    );
    return '$_temp0';
  }

  @override
  String profileFollowerCountUsers(int count) {
    return '$count pengguna';
  }

  @override
  String profileBlockTitle(String displayName) {
    return 'Blokir $displayName?';
  }

  @override
  String get profileBlockExplanation => 'Saat kamu memblokir pengguna:';

  @override
  String get profileBlockBulletHidePosts =>
      'Postingan mereka tidak akan muncul di feed-mu.';

  @override
  String get profileBlockBulletCantView =>
      'Mereka tidak bisa melihat profilmu, mengikutimu, atau melihat postinganmu.';

  @override
  String get profileBlockBulletNoNotify =>
      'Mereka tidak akan diberi tahu tentang perubahan ini.';

  @override
  String get profileBlockBulletYouCanView =>
      'Kamu tetap bisa melihat profil mereka.';

  @override
  String profileBlockConfirmButton(String displayName) {
    return 'Blokir $displayName';
  }

  @override
  String get profileCancelButton => 'Batal';

  @override
  String get profileLearnMore => 'Pelajari Lebih Lanjut';

  @override
  String profileUnblockTitle(String displayName) {
    return 'Buka blokir $displayName?';
  }

  @override
  String get profileUnblockExplanation =>
      'Saat kamu membuka blokir pengguna ini:';

  @override
  String get profileUnblockBulletShowPosts =>
      'Postingan mereka akan muncul di feed-mu.';

  @override
  String get profileUnblockBulletCanView =>
      'Mereka bisa melihat profilmu, mengikutimu, dan melihat postinganmu.';

  @override
  String get profileUnblockBulletNoNotify =>
      'Mereka tidak akan diberi tahu tentang perubahan ini.';

  @override
  String get profileLearnMoreAt => 'Pelajari lebih lanjut di ';

  @override
  String get profileUnblockButton => 'Buka Blokir';

  @override
  String profileUnfollowDisplayName(String displayName) {
    return 'Berhenti mengikuti $displayName';
  }

  @override
  String profileBlockDisplayName(String displayName) {
    return 'Blokir $displayName';
  }

  @override
  String profileUnblockDisplayName(String displayName) {
    return 'Buka blokir $displayName';
  }

  @override
  String profileReportDisplayName(String displayName) {
    return 'Laporkan $displayName';
  }

  @override
  String profileAddToListDisplayName(String displayName) {
    return 'Tambahkan $displayName ke daftar';
  }

  @override
  String get profileUserBlockedTitle => 'Pengguna Diblokir';

  @override
  String get profileUserBlockedContent =>
      'Kamu tidak akan melihat konten dari pengguna ini di feed-mu.';

  @override
  String get profileUserBlockedUnblockHint =>
      'Kamu bisa membuka blokir mereka kapan saja dari profilnya atau di Pengaturan > Keamanan.';

  @override
  String get profileCloseButton => 'Tutup';

  @override
  String get profileNoCollabsTitle => 'Belum Ada Kolaborasi';

  @override
  String get profileCollabsOwnEmpty =>
      'Video yang kamu kolaborasikan akan muncul di sini';

  @override
  String get profileCollabsOtherEmpty =>
      'Video yang mereka kolaborasikan akan muncul di sini';

  @override
  String get profileErrorLoadingCollabs => 'Gagal memuat video kolaborasi';

  @override
  String get profileNoSavedVideosTitle => 'Belum ada yang disimpan';

  @override
  String get profileSavedOwnEmpty =>
      'Bookmark video dari menu bagikan dan akan muncul di sini.';

  @override
  String get profileErrorLoadingSaved => 'Gagal memuat video tersimpan';

  @override
  String get profileNoCommentsOwnTitle => 'Belum Ada Komentar';

  @override
  String get profileNoCommentsOtherTitle => 'Tidak Ada Komentar';

  @override
  String get profileCommentsOwnEmpty =>
      'Komentar dan balasanmu akan muncul di sini';

  @override
  String get profileCommentsOtherEmpty =>
      'Komentar dan balasan mereka akan muncul di sini';

  @override
  String get profileErrorLoadingComments => 'Gagal memuat komentar';

  @override
  String get profileVideoRepliesSection => 'Balasan Video';

  @override
  String get profileCommentsSection => 'Komentar';

  @override
  String get profileEditLabel => 'Ubah';

  @override
  String get profileLibraryLabel => 'Pustaka';

  @override
  String get profileNoLikedVideosTitle => 'Belum Ada Video yang Disukai';

  @override
  String get profileLikedOwnEmpty =>
      'Video yang kamu sukai akan muncul di sini';

  @override
  String get profileLikedOtherEmpty =>
      'Video yang mereka sukai akan muncul di sini';

  @override
  String get profileErrorLoadingLiked => 'Gagal memuat video yang disukai';

  @override
  String get profileNoRepostsTitle => 'Belum Ada Repost';

  @override
  String get profileRepostsOwnEmpty =>
      'Video yang kamu repost akan muncul di sini';

  @override
  String get profileRepostsOtherEmpty =>
      'Video yang mereka repost akan muncul di sini';

  @override
  String get profileErrorLoadingReposts => 'Gagal memuat video yang di-repost';

  @override
  String get profileNoVideosTitle => 'Belum Ada Video';

  @override
  String get profileNoVideosOwnSubtitle =>
      'Bagikan video pertamamu untuk melihatnya di sini';

  @override
  String get profileNoVideosOtherSubtitle =>
      'Pengguna ini belum membagikan video apa pun';

  @override
  String profileVideoThumbnailLabel(int number) {
    return 'Thumbnail video $number';
  }

  @override
  String get profileShowMore => 'Tampilkan lebih banyak';

  @override
  String get profileShowLess => 'Tampilkan lebih sedikit';

  @override
  String get profileCompleteYourProfile => 'Lengkapi Profilmu';

  @override
  String get profileCompleteSubtitle =>
      'Tambahkan nama, bio, dan foto untuk memulai';

  @override
  String get profileSetUpButton => 'Atur';

  @override
  String get profileVerifyingEmail => 'Memverifikasi Email...';

  @override
  String profileCheckEmailVerification(String email) {
    return 'Cek $email untuk tautan verifikasi';
  }

  @override
  String get profileWaitingForVerification => 'Menunggu verifikasi email';

  @override
  String get profileVerificationFailed => 'Verifikasi Gagal';

  @override
  String get profilePleaseTryAgain => 'Silakan coba lagi';

  @override
  String get profileSecureYourAccount => 'Amankan Akunmu';

  @override
  String get profileSecureSubtitle =>
      'Tambahkan email & kata sandi untuk memulihkan akunmu di perangkat mana pun';

  @override
  String get profileRetryButton => 'Coba Lagi';

  @override
  String get profileRegisterButton => 'Daftar';

  @override
  String get profileSessionExpired => 'Sesi Kedaluwarsa';

  @override
  String get profileSignInToRestore =>
      'Masuk lagi untuk memulihkan akses penuh';

  @override
  String get profileSignInButton => 'Masuk';

  @override
  String get profileMaybeLaterLabel => 'Nanti Saja';

  @override
  String get profileSecurePrimaryButton => 'Tambah Email & Kata Sandi';

  @override
  String get profileCompletePrimaryButton => 'Perbarui Profilmu';

  @override
  String get profileLoopsLabel => 'Loop';

  @override
  String get profileLikesLabel => 'Suka';

  @override
  String get profileMyLibraryLabel => 'Pustakaku';

  @override
  String get profileMessageLabel => 'Pesan';

  @override
  String get profileUserFallback => 'pengguna';

  @override
  String get profileDismissTooltip => 'Tutup';

  @override
  String get profileLinkCopied => 'Tautan profil disalin';

  @override
  String get profileSetupEditProfileTitle => 'Ubah Profil';

  @override
  String get profileSetupBackLabel => 'Kembali';

  @override
  String get profileSetupAboutNostr => 'Tentang Nostr';

  @override
  String get profileSetupProfilePublished => 'Profil berhasil dipublikasikan!';

  @override
  String get profileSetupCreateNewProfile => 'Buat profil baru?';

  @override
  String get profileSetupNoExistingProfile =>
      'Kami tidak menemukan profil yang ada di relay-mu. Mempublikasikan akan membuat profil baru. Lanjutkan?';

  @override
  String get profileSetupPublishButton => 'Publikasikan';

  @override
  String get profileSetupUsernameTaken =>
      'Username baru saja diambil. Pilih yang lain.';

  @override
  String get profileSetupClaimFailed =>
      'Gagal mengklaim username. Silakan coba lagi.';

  @override
  String get profileSetupPublishFailed =>
      'Gagal mempublikasikan profil. Silakan coba lagi.';

  @override
  String get profileSetupNoRelaysConnected =>
      'Tidak dapat menjangkau jaringan. Periksa koneksimu dan coba lagi.';

  @override
  String get profileSetupRetryLabel => 'Coba lagi';

  @override
  String get profileSetupDisplayNameLabel => 'Nama Tampilan';

  @override
  String get profileSetupDisplayNameHint => 'Bagaimana orang harus mengenalmu?';

  @override
  String get profileSetupDisplayNameHelper =>
      'Nama atau label apa pun yang kamu mau. Tidak harus unik.';

  @override
  String get profileSetupDisplayNameRequired =>
      'Silakan masukkan nama tampilan';

  @override
  String get profileSetupBioLabel => 'Bio (Opsional)';

  @override
  String get profileSetupBioHint => 'Ceritakan tentang dirimu...';

  @override
  String get profileSetupWebsiteLabel => 'Website (Optional)';

  @override
  String get profileSetupWebsiteHint => 'https://yoursite.com';

  @override
  String get profileSetupPublicKeyLabel => 'Kunci publik (npub)';

  @override
  String get profileSetupUsernameLabel => 'Username (Opsional)';

  @override
  String get profileSetupUsernameHint => 'username';

  @override
  String get profileSetupUsernameHelper => 'Identitas unikmu di Divine';

  @override
  String get profileSetupProfileColorLabel => 'Warna Profil (Opsional)';

  @override
  String get profileSetupSaveButton => 'Simpan';

  @override
  String get profileSetupSavingButton => 'Menyimpan...';

  @override
  String get profileSetupImageUrlTitle => 'Tambah URL gambar';

  @override
  String get profileSetupPictureUploaded => 'Foto profil berhasil diunggah!';

  @override
  String get profileSetupImageSelectionFailed =>
      'Pemilihan gambar gagal. Silakan tempel URL gambar di bawah.';

  @override
  String get profileSetupImagesTypeGroup => 'gambar';

  @override
  String profileSetupCameraAccessFailed(Object error) {
    return 'Akses kamera gagal: $error';
  }

  @override
  String get profileSetupGotItButton => 'Mengerti';

  @override
  String get profileSetupUploadFailedGeneric =>
      'Gagal mengunggah gambar. Coba lagi nanti.';

  @override
  String get profileSetupUploadNetworkError =>
      'Kesalahan jaringan: Silakan cek koneksi internetmu dan coba lagi.';

  @override
  String get profileSetupUploadAuthError =>
      'Kesalahan autentikasi: Silakan keluar dan masuk kembali.';

  @override
  String get profileSetupUploadFileTooLarge =>
      'File terlalu besar: Pilih gambar yang lebih kecil (maks 10MB).';

  @override
  String get profileSetupUploadServerError =>
      'Gagal mengunggah gambar. Server kami sedang tidak tersedia untuk sementara. Coba lagi sebentar lagi.';

  @override
  String get profileSetupUploadUnsupportedOnWeb =>
      'Unggah foto profil belum tersedia di web. Pakai aplikasi iOS atau Android, atau tempel URL gambar.';

  @override
  String get profileSetupBannerSectionTitle => 'Banner';

  @override
  String get profileSetupBannerUploadButton => 'Unggah foto';

  @override
  String get profileSetupBannerClearButton => 'Hapus banner';

  @override
  String get profileSetupBannerUploadSuccess => 'Banner diperbarui';

  @override
  String get profileSetupUsernameChecking => 'Mengecek ketersediaan...';

  @override
  String get profileSetupUsernameAvailable => 'Username tersedia!';

  @override
  String get profileSetupUsernameTakenIndicator => 'Username sudah diambil';

  @override
  String get profileSetupUsernameReserved => 'Username sudah dipesan';

  @override
  String get profileSetupContactSupport => 'Hubungi dukungan';

  @override
  String get profileSetupCheckAgain => 'Cek ulang';

  @override
  String get profileSetupUsernameBurned => 'Username ini tidak tersedia lagi';

  @override
  String get profileSetupUsernameInvalidFormat =>
      'Hanya huruf, angka, dan tanda hubung yang diperbolehkan';

  @override
  String get profileSetupUsernameInvalidLength =>
      'Username harus 3-63 karakter';

  @override
  String get profileSetupUsernameNetworkError =>
      'Tidak bisa mengecek ketersediaan. Silakan coba lagi.';

  @override
  String get profileSetupUsernameInvalidFormatGeneric =>
      'Format username tidak valid';

  @override
  String get profileSetupUsernameCheckFailed => 'Gagal mengecek ketersediaan';

  @override
  String get profileSetupUsernameReservedTitle => 'Username dipesan';

  @override
  String profileSetupUsernameReservedBody(String username) {
    return 'Nama $username sudah dipesan. Beri tahu kami kenapa itu seharusnya jadi milikmu.';
  }

  @override
  String get profileSetupUsernameReservedHint =>
      'contoh: Ini nama merekku, nama panggungku, dll.';

  @override
  String get profileSetupUsernameReservedCheckHint =>
      'Sudah menghubungi dukungan? Ketuk \"Cek ulang\" untuk melihat apakah sudah dirilis untukmu.';

  @override
  String get profileSetupSupportRequestSent =>
      'Permintaan dukungan terkirim! Kami akan segera menghubungi.';

  @override
  String get profileSetupCouldntOpenEmail =>
      'Tidak bisa membuka email. Kirim ke: names@divine.video';

  @override
  String get profileSetupSendRequest => 'Kirim permintaan';

  @override
  String get profileSetupPickColorTitle => 'Pilih warna';

  @override
  String get profileSetupSelectButton => 'Pilih';

  @override
  String get profileSetupUseOwnNip05 => 'Pakai alamat NIP-05 milikmu sendiri';

  @override
  String get profileSetupNip05AddressLabel => 'Alamat NIP-05';

  @override
  String get profileSetupExternalNip05InvalidFormat =>
      'Format NIP-05 tidak valid (contoh: nama@domain.com)';

  @override
  String get profileSetupExternalNip05DivineDomain =>
      'Pakai kolom username di atas untuk divine.video';

  @override
  String get nostrSettingsNip05Address => 'NIP-05 address';

  @override
  String get nostrSettingsNip05AddressSubtitle =>
      'Use your divine.video username, or point your handle at a NIP-05 address on a domain you control.';

  @override
  String get nostrSettingsNip05AddressHint => 'you@example.com';

  @override
  String get nostrSettingsNip05SaveAction => 'Save NIP-05';

  @override
  String get nostrSettingsNip05Saved => 'NIP-05 saved';

  @override
  String get nostrSettingsNip05SaveFailed =>
      'Couldn\'t save NIP-05. Please try again.';

  @override
  String get profileSetupNip05ConfirmTitle => 'Use your own NIP-05?';

  @override
  String get profileSetupNip05ConfirmBody =>
      'NIP-05 maps a name like you@yourdomain.com to your Nostr identity. You need to control the domain and host a verification file at the right path. If it\'s wrong, people can\'t find you and your verified handle disappears. Continue only if you\'ve set this up.';

  @override
  String get profileSetupNip05ConfirmContinue => 'Continue';

  @override
  String get profileSetupNip05ConfirmCancel => 'Cancel';

  @override
  String get profileSetupProfilePicturePreview => 'Pratinjau foto profil';

  @override
  String get nostrInfoIntroBuiltOn => 'DiVine dibangun di atas Nostr,';

  @override
  String get nostrInfoIntroDescription =>
      ' protokol terbuka yang tahan sensor, yang memungkinkan orang berkomunikasi online tanpa bergantung pada satu perusahaan atau platform. ';

  @override
  String get nostrInfoIntroIdentity =>
      'Saat kamu mendaftar di Divine, kamu mendapat identitas Nostr baru.';

  @override
  String get nostrInfoOwnership =>
      'Nostr memungkinkan kamu memiliki konten, identitas, dan grafik sosialmu, yang bisa kamu pakai di banyak aplikasi. Hasilnya adalah lebih banyak pilihan, lebih sedikit kunci platform, dan internet sosial yang lebih sehat dan tangguh.';

  @override
  String get nostrInfoLingo => 'Istilah Nostr:';

  @override
  String get nostrInfoNpubLabel => 'npub:';

  @override
  String get nostrInfoNpubDescription =>
      ' Alamat publik Nostr-mu. Aman untuk dibagikan dan memungkinkan orang lain menemukan, mengikuti, atau mengirim pesan kepadamu di berbagai aplikasi Nostr.';

  @override
  String get nostrInfoNsecLabel => 'nsec:';

  @override
  String get nostrInfoNsecDescription =>
      ' Kunci pribadi dan bukti kepemilikanmu. Ini memberi kendali penuh atas identitas Nostr-mu, jadi ';

  @override
  String get nostrInfoNsecWarning => 'selalu jaga kerahasiaannya!';

  @override
  String get nostrInfoUsernameLabel => 'Username Nostr:';

  @override
  String get nostrInfoUsernameDescription =>
      ' Nama yang mudah dibaca (seperti @name.divine.video) yang terhubung ke npub-mu. Ini memudahkan identitas Nostr-mu dikenali dan diverifikasi, mirip alamat email.';

  @override
  String get nostrInfoLearnMoreAt => 'Pelajari lebih lanjut di ';

  @override
  String get nostrInfoGotIt => 'Mengerti!';

  @override
  String get profileTabRefreshTooltip => 'Segarkan';

  @override
  String get videoGridRefreshLabel => 'Mencari video lainnya';

  @override
  String get videoGridOptionsTitle => 'Opsi Video';

  @override
  String get videoGridEditVideo => 'Ubah Video';

  @override
  String get videoGridEditVideoSubtitle =>
      'Perbarui judul, deskripsi, dan hashtag';

  @override
  String get videoGridDeleteVideo => 'Hapus Video';

  @override
  String get videoGridDeleteVideoSubtitle => 'Hapus konten ini secara permanen';

  @override
  String get videoGridDeleteConfirmTitle => 'Hapus Video';

  @override
  String get videoGridDeleteConfirmMessage => 'Yakin mau menghapus video ini?';

  @override
  String get videoGridDeleteConfirmNote =>
      'Ini akan mengirim permintaan hapus (NIP-09) ke semua relay. Beberapa relay mungkin masih menyimpan kontennya.';

  @override
  String get videoGridDeleteCancel => 'Batal';

  @override
  String get videoGridDeleteConfirm => 'Hapus';

  @override
  String get videoGridDeletingContent => 'Menghapus konten...';

  @override
  String get videoGridDeleteSuccess => 'Permintaan hapus berhasil dikirim';

  @override
  String videoGridDeleteFailure(Object error) {
    return 'Gagal menghapus konten: $error';
  }

  @override
  String get exploreTabClassics => 'Klasik';

  @override
  String get exploreTabNew => 'Baru';

  @override
  String get exploreTabPopular => 'Populer';

  @override
  String get exploreTabCategories => 'Kategori';

  @override
  String get exploreTabForYou => 'Untukmu';

  @override
  String get exploreTabLists => 'Daftar';

  @override
  String get exploreTabIntegratedApps => 'Aplikasi Terintegrasi';

  @override
  String get exploreNoVideosAvailable => 'Tidak ada video tersedia';

  @override
  String exploreErrorPrefix(Object error) {
    return 'Kesalahan: $error';
  }

  @override
  String get exploreDiscoverLists => 'Temukan Daftar';

  @override
  String get exploreAboutLists => 'Tentang Daftar';

  @override
  String get exploreAboutListsDescription =>
      'Daftar membantumu mengorganisir dan mengkurasi konten Divine dengan dua cara:';

  @override
  String get explorePeopleLists => 'Daftar Orang';

  @override
  String get explorePeopleListsDescription =>
      'Ikuti grup kreator dan lihat video terbaru mereka';

  @override
  String get exploreVideoLists => 'Daftar Video';

  @override
  String get exploreVideoListsDescription =>
      'Buat playlist video favoritmu untuk ditonton nanti';

  @override
  String get exploreMyLists => 'Daftarku';

  @override
  String get exploreSubscribedLists => 'Daftar yang Dilanggan';

  @override
  String exploreErrorLoadingLists(Object error) {
    return 'Gagal memuat daftar: $error';
  }

  @override
  String exploreNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count video baru',
    );
    return '$_temp0';
  }

  @override
  String exploreLoadNewVideosLabel(int count) {
    return 'Muat $count video baru';
  }

  @override
  String get videoPlayerLoadingVideo => 'Memuat video...';

  @override
  String get videoPlayerPlayVideo => 'Putar video';

  @override
  String get videoPlayerMute => 'Bisukan video';

  @override
  String get videoPlayerUnmute => 'Aktifkan suara video';

  @override
  String get videoPlayerEditVideo => 'Ubah video';

  @override
  String get videoPlayerEditVideoTooltip => 'Ubah video';

  @override
  String get videoPlayerTapHint =>
      'Ketuk untuk memutar atau menjeda. Ketuk dua kali untuk menyukai.';

  @override
  String get videoSettingsMenuOpen => 'Buka pengaturan pemutaran';

  @override
  String get videoSettingsMenuClose => 'Tutup pengaturan pemutaran';

  @override
  String get videoSettingsCaptionsEnable => 'Aktifkan teks';

  @override
  String get videoSettingsCaptionsDisable => 'Nonaktifkan teks';

  @override
  String get contentWarningLabel => 'Peringatan Konten';

  @override
  String get contentWarningNudity => 'Ketelanjangan';

  @override
  String get contentWarningSexualContent => 'Konten Seksual';

  @override
  String get contentWarningPornography => 'Pornografi';

  @override
  String get contentWarningGraphicMedia => 'Media Grafis';

  @override
  String get contentWarningViolence => 'Kekerasan';

  @override
  String get contentWarningSelfHarm => 'Menyakiti Diri';

  @override
  String get contentWarningDrugUse => 'Penggunaan Narkoba';

  @override
  String get contentWarningAlcohol => 'Alkohol';

  @override
  String get contentWarningTobacco => 'Tembakau';

  @override
  String get contentWarningGambling => 'Judi';

  @override
  String get contentWarningProfanity => 'Kata Kasar';

  @override
  String get contentWarningFlashingLights => 'Lampu Berkedip';

  @override
  String get contentWarningAiGenerated => 'Dihasilkan AI';

  @override
  String get contentWarningSpoiler => 'Spoiler';

  @override
  String get contentWarningSensitiveContent => 'Konten Sensitif';

  @override
  String get contentWarningDescNudity =>
      'Mengandung ketelanjangan atau ketelanjangan sebagian';

  @override
  String get contentWarningDescSexual => 'Mengandung konten seksual';

  @override
  String get contentWarningDescPorn => 'Mengandung konten pornografi eksplisit';

  @override
  String get contentWarningDescGraphicMedia =>
      'Mengandung gambar grafis atau mengganggu';

  @override
  String get contentWarningDescViolence => 'Mengandung konten kekerasan';

  @override
  String get contentWarningDescSelfHarm =>
      'Mengandung referensi tentang menyakiti diri';

  @override
  String get contentWarningDescDrugs => 'Mengandung konten terkait narkoba';

  @override
  String get contentWarningDescAlcohol => 'Mengandung konten terkait alkohol';

  @override
  String get contentWarningDescTobacco => 'Mengandung konten terkait tembakau';

  @override
  String get contentWarningDescGambling => 'Mengandung konten terkait judi';

  @override
  String get contentWarningDescProfanity => 'Mengandung bahasa kasar';

  @override
  String get contentWarningDescFlashingLights =>
      'Mengandung lampu berkedip (peringatan fotosensitivitas)';

  @override
  String get contentWarningDescAiGenerated => 'Konten ini dihasilkan oleh AI';

  @override
  String get contentWarningDescSpoiler => 'Mengandung spoiler';

  @override
  String get contentWarningDescContentWarning =>
      'Kreator menandai ini sebagai sensitif';

  @override
  String get contentWarningDescDefault => 'Kreator menandai konten ini';

  @override
  String get contentWarningDetailsTitle => 'Peringatan Konten';

  @override
  String get contentWarningDetailsSubtitle => 'Kreator menerapkan label ini:';

  @override
  String get contentWarningManageFilters => 'Atur filter konten';

  @override
  String get contentWarningViewAnyway => 'Tetap Lihat';

  @override
  String get contentWarningReportContentTooltip => 'Laporkan Konten';

  @override
  String get contentWarningBlockUserTooltip => 'Blokir Pengguna';

  @override
  String get contentWarningBlockedTitle => 'Konten Diblokir';

  @override
  String get contentWarningBlockedPolicy =>
      'Konten ini diblokir karena melanggar kebijakan.';

  @override
  String get contentWarningNoticeTitle => 'Pemberitahuan Konten';

  @override
  String get contentWarningPotentiallyHarmfulTitle =>
      'Konten Berpotensi Berbahaya';

  @override
  String get contentWarningView => 'Lihat';

  @override
  String get contentWarningReportAction => 'Laporkan';

  @override
  String get contentWarningHideAllLikeThis =>
      'Sembunyikan semua konten seperti ini';

  @override
  String get contentWarningNoFilterYet =>
      'Belum ada filter tersimpan untuk peringatan ini.';

  @override
  String get contentWarningHiddenConfirmation =>
      'Kami akan menyembunyikan postingan seperti ini mulai sekarang.';

  @override
  String get videoErrorNotFound => 'Video tidak ditemukan';

  @override
  String get videoErrorNetwork => 'Kesalahan jaringan';

  @override
  String get videoErrorTimeout => 'Waktu pemuatan habis';

  @override
  String get videoErrorFormat =>
      'Kesalahan format video\n(Coba lagi atau pakai browser lain)';

  @override
  String get videoErrorUnsupportedFormat => 'Format video tidak didukung';

  @override
  String get videoErrorPlayback => 'Kesalahan pemutaran video';

  @override
  String get videoErrorAgeRestricted => 'Konten dengan pembatasan usia';

  @override
  String get videoErrorVerifyAge => 'Verifikasi Usia';

  @override
  String get videoErrorRetry => 'Coba Lagi';

  @override
  String get videoErrorContentRestricted => 'Konten dibatasi';

  @override
  String get videoErrorContentRestrictedBody =>
      'Video ini dibatasi oleh relay.';

  @override
  String get videoErrorVerifyAgeBody =>
      'Verifikasi usiamu untuk melihat video ini.';

  @override
  String get videoErrorSkip => 'Lewati';

  @override
  String get videoErrorVerifyAgeButton => 'Verifikasi usia';

  @override
  String get videoErrorVerifyAgeFailed =>
      'Tidak dapat memverifikasi usia kamu. Silakan coba lagi.';

  @override
  String get videoErrorVerifyAgeSignerUnreachable =>
      'Waktu verifikasi habis. Periksa koneksi kamu atau coba lagi sebentar lagi.';

  @override
  String get videoFollowButtonFollowing => 'Mengikuti';

  @override
  String get videoFollowButtonFollow => 'Ikuti';

  @override
  String get audioAttributionOriginalSound => 'Suara asli';

  @override
  String videoInspiredByAttribution(String creatorName) {
    return 'Terinspirasi oleh @$creatorName';
  }

  @override
  String videoCollaboratorWithOne(String name) {
    return 'dengan @$name';
  }

  @override
  String videoCollaboratorWithMore(String name, int count) {
    return 'dengan @$name +$count';
  }

  @override
  String videoCollaboratorCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kolaborator',
    );
    return '$_temp0. Ketuk untuk melihat profil.';
  }

  @override
  String get videoCollaboratorPendingDecoration => 'Pending';

  @override
  String get videoCollaboratorPendingSemanticLabel => 'Pending collaborator';

  @override
  String videoCollaboratorWithPendingSuffix(String label, int pending) {
    return '$label ($pending pending)';
  }

  @override
  String profileChipTapHint(String name) {
    return '$name. Tap to view profile.';
  }

  @override
  String metadataHashtagChipTapHint(String hashtag) {
    return '#$hashtag. Tap to view videos with this hashtag.';
  }

  @override
  String get listAttributionFallback => 'Daftar';

  @override
  String get shareVideoLabel => 'Bagikan video';

  @override
  String sharePostSharedWith(String recipientName) {
    return 'Postingan dibagikan dengan $recipientName';
  }

  @override
  String get shareFailedToSend => 'Gagal mengirim video';

  @override
  String get shareAddedToBookmarks => 'Ditambahkan ke bookmark';

  @override
  String get shareRemovedFromBookmarks => 'Dihapus dari bookmark';

  @override
  String get shareFailedToAddBookmark => 'Gagal menambahkan bookmark';

  @override
  String get shareFailedToRemoveBookmark => 'Gagal menghapus bookmark';

  @override
  String get shareActionFailed => 'Aksi gagal';

  @override
  String get shareWithTitle => 'Bagikan dengan';

  @override
  String get shareFindPeople => 'Cari orang';

  @override
  String get shareFindPeopleMultiline => 'Cari\norang';

  @override
  String get shareSent => 'Terkirim';

  @override
  String get shareContactFallback => 'Kontak';

  @override
  String get shareUserFallback => 'Pengguna';

  @override
  String shareSendingTo(String name) {
    return 'Mengirim ke $name';
  }

  @override
  String get shareMessageHint => 'Tambahkan pesan opsional...';

  @override
  String get videoActionUnlike => 'Batalkan suka video';

  @override
  String get videoActionLike => 'Suka video';

  @override
  String get videoActionAutoLabel => 'Otomatis';

  @override
  String get videoActionLikeLabel => 'Suka';

  @override
  String get videoActionReplyLabel => 'Balas';

  @override
  String get videoActionRepostLabel => 'Repost';

  @override
  String get videoActionShareLabel => 'Bagikan';

  @override
  String get videoActionReportLabel => 'Laporkan';

  @override
  String get videoActionReport => 'Laporkan video';

  @override
  String get videoActionEditLabel => 'Edit';

  @override
  String get videoActionEdit => 'Edit video';

  @override
  String get videoActionAboutLabel => 'Tentang';

  @override
  String get videoActionEnableAutoAdvance => 'Aktifkan lanjut otomatis';

  @override
  String get videoActionDisableAutoAdvance => 'Nonaktifkan lanjut otomatis';

  @override
  String get videoActionRemoveRepost => 'Hapus repost';

  @override
  String get videoActionRepost => 'Repost video';

  @override
  String get videoActionViewComments => 'Lihat komentar';

  @override
  String get videoActionMoreOptions => 'Opsi lainnya';

  @override
  String get videoActionHideSubtitles => 'Sembunyikan subtitle';

  @override
  String get videoActionShowSubtitles => 'Tampilkan subtitle';

  @override
  String get videoEngagementLikersTitle => 'Disukai oleh';

  @override
  String get videoEngagementRepostersTitle => 'Direpost oleh';

  @override
  String get videoEngagementLikersEmpty => 'Belum ada suka';

  @override
  String get videoEngagementRepostersEmpty => 'Belum ada repost';

  @override
  String get videoEngagementLoadFailed => 'Tidak dapat memuat daftar';

  @override
  String get videoOverlayOpenMetadataFromTitle => 'Buka detail video';

  @override
  String get videoOverlayOpenMetadataFromDescription => 'Buka detail video';

  @override
  String get videoOverlayCommentBarHint => 'Add comment...';

  @override
  String get videoOverlayCommentBarSemanticLabel => 'Add a comment';

  @override
  String get videoOverlayCommentBarSendLabel => 'Send comment';

  @override
  String get videoOverlayCommentPostedSnackbar => 'Comment posted';

  @override
  String get videoOverlayCommentPostFailedSnackbar => 'Couldn\'t post comment';

  @override
  String videoDescriptionLoops(String count) {
    return '$count loop';
  }

  @override
  String videoFeedLoopCountLine(String compactCount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'loop',
      one: 'loop',
    );
    return '$compactCount $_temp0';
  }

  @override
  String get metadataBadgeNotDivine => 'Bukan Divine';

  @override
  String get metadataBadgeHumanMade => 'Buatan Manusia';

  @override
  String get metadataSoundsLabel => 'Suara';

  @override
  String get metadataOriginalSound => 'Suara asli';

  @override
  String get metadataVerificationLabel => 'Verifikasi';

  @override
  String get metadataDeviceAttestation => 'Atestasi perangkat';

  @override
  String get metadataPgpSignature => 'Tanda tangan PGP';

  @override
  String get metadataC2paCredentials => 'Kredensial Konten C2PA';

  @override
  String get metadataProofManifest => 'Manifes bukti';

  @override
  String get metadataCreatorLabel => 'Kreator';

  @override
  String get metadataCollaboratorsLabel => 'Kolaborator';

  @override
  String get metadataInspiredByLabel => 'Terinspirasi oleh';

  @override
  String get metadataRepostedByLabel => 'Di-repost oleh';

  @override
  String metadataLoopsLabel(int count) {
    return 'Loop';
  }

  @override
  String get metadataLikesLabel => 'Suka';

  @override
  String get metadataCommentsLabel => 'Komentar';

  @override
  String get metadataRepostsLabel => 'Repost';

  @override
  String metadataPostedDateSemantics(String date) {
    return 'Diposting pada $date';
  }

  @override
  String get devOptionsTitle => 'Opsi Pengembang';

  @override
  String get devOptionsPageLoadTimes => 'Waktu Muat Halaman';

  @override
  String get devOptionsNoPageLoads =>
      'Belum ada pemuatan halaman yang tercatat.\nNavigasi ke seluruh aplikasi untuk melihat data waktu.';

  @override
  String devOptionsPageLoadVisible(String visibleMs, String dataMs) {
    return 'Terlihat: ${visibleMs}ms  |  Data: ${dataMs}ms';
  }

  @override
  String get devOptionsSlowestScreens => 'Layar Paling Lambat';

  @override
  String get devOptionsVideoPlaybackFormat => 'Format Pemutaran Video';

  @override
  String get devOptionsSwitchEnvironmentTitle => 'Ganti Lingkungan?';

  @override
  String devOptionsSwitchEnvironmentMessage(String envName) {
    return 'Ganti ke $envName?\n\nIni akan menghapus data video yang tersimpan di cache dan menghubungkan ulang ke relay baru.';
  }

  @override
  String get devOptionsCancel => 'Batal';

  @override
  String get devOptionsSwitch => 'Ganti';

  @override
  String devOptionsSwitchedTo(String envName) {
    return 'Diganti ke $envName';
  }

  @override
  String devOptionsSwitchedFormat(String formatName) {
    return 'Diganti ke $formatName — cache dibersihkan';
  }

  @override
  String get featureFlagTitle => 'Feature Flags';

  @override
  String get featureFlagResetAllTooltip => 'Reset semua flag ke bawaan';

  @override
  String get featureFlagResetToDefault => 'Reset ke bawaan';

  @override
  String get featureFlagAppRecovery => 'Pemulihan Aplikasi';

  @override
  String get featureFlagAppRecoveryDescription =>
      'Kalau aplikasi crash atau berperilaku aneh, coba bersihkan cache.';

  @override
  String get featureFlagClearAllCache => 'Bersihkan Semua Cache';

  @override
  String get featureFlagCacheInfo => 'Info Cache';

  @override
  String get featureFlagClearCacheTitle => 'Bersihkan Semua Cache?';

  @override
  String get featureFlagClearCacheMessage =>
      'Ini akan menghapus semua data yang tersimpan di cache termasuk:\n• Notifikasi\n• Profil pengguna\n• Bookmark\n• File sementara\n\nKamu perlu masuk lagi. Lanjutkan?';

  @override
  String get featureFlagClearCache => 'Bersihkan Cache';

  @override
  String get featureFlagClearingCache => 'Membersihkan cache...';

  @override
  String get featureFlagSuccess => 'Berhasil';

  @override
  String get featureFlagError => 'Kesalahan';

  @override
  String get featureFlagClearCacheSuccess =>
      'Cache berhasil dibersihkan. Silakan restart aplikasi.';

  @override
  String get featureFlagClearCacheFailure =>
      'Gagal membersihkan beberapa item cache. Cek log untuk detail.';

  @override
  String get featureFlagOk => 'OK';

  @override
  String get featureFlagCacheInformation => 'Informasi Cache';

  @override
  String featureFlagTotalCacheSize(String size) {
    return 'Total ukuran cache: $size';
  }

  @override
  String get featureFlagCacheIncludes =>
      'Cache mencakup:\n• Riwayat notifikasi\n• Data profil pengguna\n• Thumbnail video\n• File sementara\n• Indeks database';

  @override
  String get relaySettingsTitle => 'Relay';

  @override
  String get relaySettingsInfoTitle =>
      'Divine adalah sistem terbuka - kamu mengontrol koneksimu';

  @override
  String get relaySettingsInfoDescription =>
      'Relay ini mendistribusikan kontenmu ke seluruh jaringan Nostr yang terdesentralisasi. Kamu bisa menambah atau menghapus relay sesukamu.';

  @override
  String get relaySettingsLearnMoreNostr =>
      'Pelajari lebih lanjut tentang Nostr →';

  @override
  String get relaySettingsFindPublicRelays =>
      'Temukan relay publik di nostr.co.uk →';

  @override
  String get relaySettingsAppNotFunctional => 'Aplikasi Tidak Berfungsi';

  @override
  String get relaySettingsRequiresRelay =>
      'Divine butuh minimal satu relay untuk memuat video, posting konten, dan sinkronisasi data.';

  @override
  String get relaySettingsRestoreDefaultRelay => 'Pulihkan Relay Bawaan';

  @override
  String get relaySettingsAddCustomRelay => 'Tambah Relay Kustom';

  @override
  String get relaySettingsAddRelay => 'Tambah Relay';

  @override
  String get relaySettingsRetry => 'Coba Lagi';

  @override
  String get relaySettingsNoStats => 'Belum ada statistik tersedia';

  @override
  String get relaySettingsConnection => 'Koneksi';

  @override
  String get relaySettingsConnected => 'Terhubung';

  @override
  String get relaySettingsDisconnected => 'Terputus';

  @override
  String get relaySettingsSessionDuration => 'Durasi Sesi';

  @override
  String get relaySettingsLastConnected => 'Terakhir Terhubung';

  @override
  String get relaySettingsDisconnectedLabel => 'Terputus';

  @override
  String get relaySettingsReason => 'Alasan';

  @override
  String get relaySettingsActiveSubscriptions => 'Langganan Aktif';

  @override
  String get relaySettingsTotalSubscriptions => 'Total Langganan';

  @override
  String get relaySettingsEventsReceived => 'Event Diterima';

  @override
  String get relaySettingsEventsSent => 'Event Dikirim';

  @override
  String get relaySettingsRequestsThisSession => 'Permintaan Sesi Ini';

  @override
  String get relaySettingsFailedRequests => 'Permintaan Gagal';

  @override
  String relaySettingsLastError(String error) {
    return 'Kesalahan Terakhir: $error';
  }

  @override
  String get relaySettingsLoadingRelayInfo => 'Memuat info relay...';

  @override
  String get relaySettingsAboutRelay => 'Tentang Relay';

  @override
  String get relaySettingsSupportedNips => 'NIP yang Didukung';

  @override
  String get relaySettingsSoftware => 'Perangkat Lunak';

  @override
  String get relaySettingsViewWebsite => 'Lihat Website';

  @override
  String get relaySettingsRemoveRelayTitle => 'Hapus Relay?';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return 'Yakin mau menghapus relay ini?\n\n$relayUrl';
  }

  @override
  String get relaySettingsCancel => 'Batal';

  @override
  String get relaySettingsRemove => 'Hapus';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return 'Relay dihapus: $relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay => 'Gagal menghapus relay';

  @override
  String get relaySettingsForcingReconnection =>
      'Memaksa koneksi ulang relay...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    return 'Terhubung ke $count relay!';
  }

  @override
  String get relaySettingsFailedToConnectCheck =>
      'Gagal terhubung ke relay. Silakan cek koneksi jaringanmu.';

  @override
  String get relaySettingsAddRelayTitle => 'Tambah Relay';

  @override
  String get relaySettingsAddRelayPrompt =>
      'Masukkan URL WebSocket relay yang ingin kamu tambahkan:';

  @override
  String get relaySettingsBrowsePublicRelays =>
      'Jelajahi relay publik di nostr.co.uk';

  @override
  String get relaySettingsAdd => 'Tambah';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return 'Relay ditambahkan: $relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay =>
      'Gagal menambah relay. Silakan cek URL dan coba lagi.';

  @override
  String get relaySettingsInvalidUrl =>
      'URL relay harus dimulai dengan wss:// atau ws://';

  @override
  String get relaySettingsInsecureUrl =>
      'URL relay harus pakai wss:// (ws:// hanya boleh untuk localhost)';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return 'Relay bawaan dipulihkan: $defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault =>
      'Gagal memulihkan relay bawaan. Silakan cek koneksi jaringanmu.';

  @override
  String get relaySettingsCouldNotOpenBrowser => 'Tidak bisa membuka browser';

  @override
  String get relaySettingsFailedToOpenLink => 'Gagal membuka tautan';

  @override
  String get relaySettingsExternalRelay => 'Relay eksternal';

  @override
  String get relaySettingsNotConnected => 'Tidak terhubung';

  @override
  String relaySettingsDisconnectedAgo(String duration) {
    return 'Terputus $duration lalu';
  }

  @override
  String relaySettingsSubscriptionsSummary(int count) {
    return '$count sub';
  }

  @override
  String relaySettingsEventsSummary(String count) {
    return '$count event';
  }

  @override
  String relaySettingsTimeAgo(String duration) {
    return '$duration lalu';
  }

  @override
  String get nostrSettingsIntro =>
      'Divine memakai protokol Nostr untuk publikasi terdesentralisasi. Kontenmu hidup di relay yang kamu pilih, dan kuncimu adalah identitasmu.';

  @override
  String get nostrSettingsSectionNetwork => 'Jaringan';

  @override
  String get nostrSettingsSectionAccount => 'Akun';

  @override
  String get nostrSettingsSectionDangerZone => 'Zona Berbahaya';

  @override
  String get nostrSettingsRelays => 'Relay';

  @override
  String get nostrSettingsRelaysSubtitle => 'Atur koneksi relay Nostr';

  @override
  String get nostrSettingsRelayDiagnostics => 'Diagnostik Relay';

  @override
  String get nostrSettingsRelayDiagnosticsSubtitle =>
      'Debug konektivitas relay dan masalah jaringan';

  @override
  String get nostrSettingsMediaServers => 'Server Media';

  @override
  String get nostrSettingsMediaServersSubtitle =>
      'Konfigurasi server upload Blossom';

  @override
  String get nostrSettingsDeveloperOptions => 'Opsi Pengembang';

  @override
  String get nostrSettingsDeveloperOptionsSubtitle =>
      'Pengubah environment dan pengaturan debug';

  @override
  String get nostrSettingsExperimentalFeaturesSubtitle =>
      'Aktifkan fitur eksperimen yang mungkin bermasalah.';

  @override
  String get nostrSettingsKeyManagement => 'Manajemen Kunci';

  @override
  String get nostrSettingsKeyManagementSubtitle =>
      'Ekspor, backup, dan pulihkan kunci Nostr-mu';

  @override
  String get nostrSettingsClientAttribution => 'Atribusi klien';

  @override
  String get nostrSettingsClientAttributionSubtitle =>
      'Tambahkan tag klien Divine ke event yang kamu publikasikan agar aplikasi Nostr lain bisa mengatribusikannya dengan benar.';

  @override
  String get nostrSettingsRemoveKeys => 'Hapus Kunci dari Perangkat';

  @override
  String get nostrSettingsRemoveKeysSubtitle =>
      'Hapus kunci privatmu hanya dari perangkat ini. Kontenmu tetap di relay, tapi kamu butuh backup nsec untuk masuk lagi.';

  @override
  String get nostrSettingsCouldNotRemoveKeys =>
      'Gagal menghapus kunci dari perangkat ini. Coba lagi.';

  @override
  String nostrSettingsFailedToRemoveKeys(String error) {
    return 'Gagal menghapus kunci: $error';
  }

  @override
  String get nostrSettingsDeleteAccount => 'Hapus Akun dan Data';

  @override
  String get nostrSettingsDeleteAccountSubtitle =>
      'Hapus PERMANEN akunmu dan SEMUA konten dari relay Nostr. Tindakan ini tidak bisa dibatalkan.';

  @override
  String get relayDiagnosticTitle => 'Diagnostik Relay';

  @override
  String get relayDiagnosticRefreshTooltip => 'Segarkan diagnostik';

  @override
  String relayDiagnosticLastRefresh(String time) {
    return 'Segar terakhir: $time';
  }

  @override
  String get relayDiagnosticRelayStatus => 'Status Relay';

  @override
  String get relayDiagnosticInitialized => 'Diinisialisasi';

  @override
  String get relayDiagnosticReady => 'Siap';

  @override
  String get relayDiagnosticNotInitialized => 'Belum diinisialisasi';

  @override
  String get relayDiagnosticDatabaseEvents => 'Event Database';

  @override
  String get relayDiagnosticActiveSubscriptions => 'Langganan Aktif';

  @override
  String get relayDiagnosticExternalRelays => 'Relay Eksternal';

  @override
  String get relayDiagnosticConfigured => 'Dikonfigurasi';

  @override
  String relayDiagnosticRelayCount(int count) {
    return '$count relay';
  }

  @override
  String get relayDiagnosticConnectedLabel => 'Terhubung';

  @override
  String relayDiagnosticConnectedRatio(int connected, int total) {
    return '$connected/$total';
  }

  @override
  String get relayDiagnosticVideoEvents => 'Event Video';

  @override
  String get relayDiagnosticHomeFeed => 'Feed Beranda';

  @override
  String relayDiagnosticVideosCount(int count) {
    return '$count video';
  }

  @override
  String get relayDiagnosticDiscovery => 'Penemuan';

  @override
  String get relayDiagnosticLoading => 'Memuat';

  @override
  String get relayDiagnosticYes => 'Ya';

  @override
  String get relayDiagnosticNo => 'Tidak';

  @override
  String get relayDiagnosticTestDirectQuery => 'Tes Query Langsung';

  @override
  String get relayDiagnosticNetworkConnectivity => 'Konektivitas Jaringan';

  @override
  String get relayDiagnosticRunNetworkTest => 'Jalankan Tes Jaringan';

  @override
  String get relayDiagnosticBlossomServer => 'Server Blossom';

  @override
  String get relayDiagnosticTestAllEndpoints => 'Tes Semua Endpoint';

  @override
  String get relayDiagnosticStatus => 'Status';

  @override
  String get relayDiagnosticUrl => 'URL';

  @override
  String get relayDiagnosticError => 'Kesalahan';

  @override
  String get relayDiagnosticFunnelCakeApi => 'FunnelCake API';

  @override
  String get relayDiagnosticBaseUrl => 'URL Dasar';

  @override
  String get relayDiagnosticSummary => 'Ringkasan';

  @override
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  ) {
    return '$successCount/$totalCount OK (rata-rata ${avgMs}ms)';
  }

  @override
  String get relayDiagnosticRetestAll => 'Tes Ulang Semua';

  @override
  String get relayDiagnosticRetrying => 'Mencoba lagi...';

  @override
  String get relayDiagnosticRetryConnection => 'Coba Sambung Ulang';

  @override
  String get relayDiagnosticTroubleshooting => 'Pemecahan Masalah';

  @override
  String get relayDiagnosticTroubleshootingGuide =>
      '• Status hijau = Terhubung dan bekerja\n• Status merah = Koneksi gagal\n• Kalau tes jaringan gagal, cek koneksi internet\n• Kalau relay dikonfigurasi tapi tidak terhubung, ketuk \"Coba Sambung Ulang\"\n• Screenshot layar ini untuk debugging';

  @override
  String get relayDiagnosticAllEndpointsHealthy => 'Semua endpoint REST sehat!';

  @override
  String get relayDiagnosticSomeEndpointsFailed =>
      'Beberapa endpoint REST gagal - lihat detail di atas';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    return 'Ditemukan $count event video di database';
  }

  @override
  String relayDiagnosticQueryFailed(String error) {
    return 'Query gagal: $error';
  }

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    return 'Terhubung ke $count relay!';
  }

  @override
  String get relayDiagnosticFailedToConnect =>
      'Gagal terhubung ke relay mana pun';

  @override
  String relayDiagnosticConnectionRetryFailed(String error) {
    return 'Percobaan koneksi ulang gagal: $error';
  }

  @override
  String get relayDiagnosticConnectedAuthenticated =>
      'Terhubung & Terautentikasi';

  @override
  String get relayDiagnosticConnectedOnly => 'Terhubung';

  @override
  String get relayDiagnosticNotConnected => 'Tidak terhubung';

  @override
  String get relayDiagnosticNoRelaysConfigured =>
      'Tidak ada relay yang dikonfigurasi';

  @override
  String get relayDiagnosticFailed => 'Gagal';

  @override
  String get notificationSettingsTitle => 'Notifikasi';

  @override
  String get notificationSettingsResetTooltip => 'Reset ke bawaan';

  @override
  String get notificationSettingsTypes => 'Jenis Notifikasi';

  @override
  String get notificationSettingsLikes => 'Suka';

  @override
  String get notificationSettingsLikesSubtitle =>
      'Saat ada yang menyukai videomu';

  @override
  String get notificationSettingsComments => 'Komentar';

  @override
  String get notificationSettingsCommentsSubtitle =>
      'Saat ada yang mengomentari videomu';

  @override
  String get notificationSettingsFollows => 'Pengikut';

  @override
  String get notificationSettingsFollowsSubtitle => 'Saat ada yang mengikutimu';

  @override
  String get notificationSettingsMentions => 'Sebutan';

  @override
  String get notificationSettingsMentionsSubtitle => 'Saat kamu disebut';

  @override
  String get notificationSettingsReposts => 'Repost';

  @override
  String get notificationSettingsRepostsSubtitle =>
      'Saat ada yang me-repost videomu';

  @override
  String get notificationSettingsSystem => 'System';

  @override
  String get notificationSettingsSystemSubtitle =>
      'App updates and system messages';

  @override
  String get notificationSettingsPushNotificationsSection =>
      'Push Notifications';

  @override
  String get notificationSettingsPushNotifications => 'Push Notifications';

  @override
  String get notificationSettingsPushNotificationsSubtitle =>
      'Receive notifications when app is closed';

  @override
  String get notificationSettingsSound => 'Sound';

  @override
  String get notificationSettingsSoundSubtitle =>
      'Play sound for notifications';

  @override
  String get notificationSettingsVibration => 'Vibration';

  @override
  String get notificationSettingsVibrationSubtitle =>
      'Vibrate for notifications';

  @override
  String get notificationSettingsActions => 'Aksi';

  @override
  String get notificationSettingsMarkAllAsRead => 'Tandai Semua Sudah Dibaca';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle =>
      'Tandai semua notifikasi sudah dibaca';

  @override
  String get notificationSettingsAllMarkedAsRead =>
      'Semua notifikasi ditandai sudah dibaca';

  @override
  String get notificationSettingsMarkAllAsReadFailed =>
      'Gagal menandai semua sudah dibaca';

  @override
  String get notificationSettingsResetToDefaults =>
      'Pengaturan direset ke bawaan';

  @override
  String get notificationSettingsAbout => 'Tentang Notifikasi';

  @override
  String get notificationSettingsAboutDescription =>
      'Notifikasi ditenagai oleh protokol Nostr. Pembaruan real-time bergantung pada koneksimu ke relay Nostr. Beberapa notifikasi mungkin tertunda.';

  @override
  String get safetySettingsTitle => 'Keamanan & Privasi';

  @override
  String get safetySettingsLabel => 'PENGATURAN';

  @override
  String get safetySettingsWhatYouSee => 'YANG KAMU LIHAT';

  @override
  String get safetySettingsWhatYouPublish => 'YANG KAMU PUBLIKASIKAN';

  @override
  String get safetySettingsShowDivineHostedOnly =>
      'Hanya tampilkan video yang di-host Divine';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle =>
      'Sembunyikan video yang disajikan dari host media lain';

  @override
  String get safetySettingsModeration => 'MODERASI';

  @override
  String get safetySettingsBlockedUsers => 'PENGGUNA DIBLOKIR';

  @override
  String get safetySettingsAgeVerification => 'VERIFIKASI USIA';

  @override
  String get safetySettingsAgeConfirmation =>
      'Saya konfirmasi saya berusia 18 tahun atau lebih';

  @override
  String get safetySettingsAgeRequired =>
      'Diperlukan untuk melihat konten dewasa';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle =>
      'Layanan moderasi resmi (aktif secara bawaan)';

  @override
  String get safetySettingsPeopleIFollow => 'Orang yang saya ikuti';

  @override
  String get safetySettingsPeopleIFollowSubtitle =>
      'Berlangganan label dari orang yang kamu ikuti';

  @override
  String get safetySettingsAddCustomLabeler => 'Tambah Labeler Kustom';

  @override
  String get safetySettingsAddCustomLabelerHint => 'Masukkan npub...';

  @override
  String get safetySettingsAddCustomLabelerListTitle => 'Tambah labeler kustom';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle =>
      'Masukkan alamat npub';

  @override
  String get safetySettingsNoBlockedUsers => 'Tidak ada pengguna yang diblokir';

  @override
  String get safetySettingsUnblock => 'Buka Blokir';

  @override
  String get safetySettingsUserUnblocked => 'Pengguna dibuka blokirnya';

  @override
  String get safetySettingsCancel => 'Batal';

  @override
  String get safetySettingsAdd => 'Tambah';

  @override
  String get analyticsTitle => 'Analitik Kreator';

  @override
  String get analyticsDiagnosticsTooltip => 'Diagnostik';

  @override
  String get analyticsDiagnosticsSemanticLabel => 'Toggle diagnostik';

  @override
  String get analyticsRetry => 'Coba Lagi';

  @override
  String get analyticsUnableToLoad => 'Tidak bisa memuat analitik.';

  @override
  String get analyticsSignInRequired => 'Masuk untuk melihat analitik kreator.';

  @override
  String get analyticsViewDataUnavailable =>
      'Data tontonan saat ini tidak tersedia dari relay untuk postingan ini. Metrik suka/komentar/repost masih akurat.';

  @override
  String get analyticsViewDataTitle => 'Data Tontonan';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return 'Diperbarui $time • Skor menggunakan suka, komentar, repost, dan tontonan/loop dari Funnelcake jika tersedia.';
  }

  @override
  String get analyticsVideos => 'Video';

  @override
  String get analyticsViews => 'Tontonan';

  @override
  String get analyticsInteractions => 'Interaksi';

  @override
  String get analyticsEngagement => 'Keterlibatan';

  @override
  String get analyticsFollowers => 'Pengikut';

  @override
  String get analyticsAvgPerPost => 'Rata-rata/Postingan';

  @override
  String get analyticsInteractionMix => 'Komposisi Interaksi';

  @override
  String get analyticsLikes => 'Suka';

  @override
  String get analyticsComments => 'Komentar';

  @override
  String get analyticsReposts => 'Repost';

  @override
  String get analyticsPerformanceHighlights => 'Sorotan Performa';

  @override
  String get analyticsMostViewed => 'Paling banyak ditonton';

  @override
  String get analyticsMostDiscussed => 'Paling banyak dibahas';

  @override
  String get analyticsMostReposted => 'Paling banyak di-repost';

  @override
  String get analyticsNoVideosYet => 'Belum ada video';

  @override
  String get analyticsViewDataUnavailableShort =>
      'Data tontonan tidak tersedia';

  @override
  String analyticsViewsCount(String count) {
    return '$count tontonan';
  }

  @override
  String analyticsCommentsCount(String count) {
    return '$count komentar';
  }

  @override
  String analyticsRepostsCount(String count) {
    return '$count repost';
  }

  @override
  String get analyticsTopContent => 'Konten Teratas';

  @override
  String get analyticsPublishPrompt =>
      'Publikasikan beberapa video untuk melihat peringkat.';

  @override
  String get analyticsEngagementRateExplainer =>
      'Sisi kanan % = Tingkat Keterlibatan (interaksi dibagi tontonan).';

  @override
  String get analyticsEngagementRateNoViews =>
      'Tingkat Keterlibatan butuh data tontonan; nilai tampil sebagai N/A sampai tontonan tersedia.';

  @override
  String get analyticsEngagementLabel => 'Keterlibatan';

  @override
  String get analyticsViewsUnavailable => 'tontonan tidak tersedia';

  @override
  String analyticsInteractionsCount(String count) {
    return '$count interaksi';
  }

  @override
  String get analyticsPostAnalytics => 'Analitik Postingan';

  @override
  String get analyticsOpenPost => 'Buka Postingan';

  @override
  String get analyticsRecentDailyInteractions => 'Interaksi Harian Terbaru';

  @override
  String get analyticsNoActivityYet => 'Belum ada aktivitas di rentang ini.';

  @override
  String get analyticsDailyInteractionsExplainer =>
      'Interaksi = suka + komentar + repost berdasarkan tanggal postingan.';

  @override
  String get analyticsDailyBarExplainer =>
      'Panjang batang relatif terhadap hari tertinggimu di jendela ini.';

  @override
  String get analyticsAudienceSnapshot => 'Snapshot Audiens';

  @override
  String analyticsFollowersCount(String count) {
    return 'Pengikut: $count';
  }

  @override
  String analyticsFollowingCount(String count) {
    return 'Mengikuti: $count';
  }

  @override
  String get analyticsAudiencePlaceholder =>
      'Rincian sumber/geo/waktu audiens akan terisi saat Funnelcake menambah endpoint analitik audiens.';

  @override
  String get analyticsRetention => 'Retensi';

  @override
  String get analyticsRetentionWithViews =>
      'Kurva retensi dan rincian waktu tonton akan muncul setelah retensi per detik/per bucket tiba dari Funnelcake.';

  @override
  String get analyticsRetentionWithoutViews =>
      'Data retensi tidak tersedia sampai analitik tontonan+waktu tonton dikembalikan oleh Funnelcake.';

  @override
  String get analyticsDiagnostics => 'Diagnostik';

  @override
  String analyticsDiagnosticsTotalVideos(int count) {
    return 'Total video: $count';
  }

  @override
  String analyticsDiagnosticsWithViews(int count) {
    return 'Dengan tontonan: $count';
  }

  @override
  String analyticsDiagnosticsMissingViews(int count) {
    return 'Tontonan hilang: $count';
  }

  @override
  String analyticsDiagnosticsHydratedBulk(int count) {
    return 'Dihidrasi (massal): $count';
  }

  @override
  String analyticsDiagnosticsHydratedViews(int count) {
    return 'Dihidrasi (/views): $count';
  }

  @override
  String analyticsDiagnosticsSources(String sources) {
    return 'Sumber: $sources';
  }

  @override
  String get analyticsDiagnosticsUseFixture => 'Pakai data fixture';

  @override
  String get analyticsNa => 'N/A';

  @override
  String get authCreateNewAccount => 'Buat akun Divine baru';

  @override
  String get authCreateNewAccountShort => 'Create new account';

  @override
  String get authSignInDifferentAccount => 'Masuk dengan akun yang berbeda';

  @override
  String get authUseAnotherAccount => 'Use another account';

  @override
  String authContinueAs(String displayName) {
    return 'Continue as $displayName';
  }

  @override
  String get authRecoveryDraftsOwner =>
      'Draf dan klip kamu tersimpan untuk akun ini';

  @override
  String get authRecoveryOtherAccountWarning =>
      'Masuk di sini akan menyembunyikan draf dan klip tersebut';

  @override
  String get authTermsPrefix =>
      'By selecting an option below, you confirm you are at least 16 years old (or have completed ';

  @override
  String get authTermsAgeAuthorizationCta => 'Divine age authorization';

  @override
  String get authTermsAfterAgeAuthorization => ') and agree to the ';

  @override
  String get authTermsOfService => 'Ketentuan Layanan';

  @override
  String get authPrivacyPolicy => 'Kebijakan Privasi';

  @override
  String get authTermsAnd => ', dan ';

  @override
  String get authSafetyStandards => 'Standar Keamanan';

  @override
  String get authAmberNotInstalled => 'Aplikasi Amber tidak terpasang';

  @override
  String get authAmberConnectionFailed => 'Gagal terhubung dengan Amber';

  @override
  String get authPasswordResetSent =>
      'Jika akun dengan email itu ada, tautan reset kata sandi telah dikirim.';

  @override
  String get authSignInTitle => 'Masuk';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authPasswordLabel => 'Kata Sandi';

  @override
  String get authConfirmPasswordLabel => 'Konfirmasi kata sandi';

  @override
  String get authEmailRequired => 'Email wajib diisi';

  @override
  String get authEmailInvalid => 'Masukkan email yang valid';

  @override
  String get authPasswordRequired => 'Kata sandi wajib diisi';

  @override
  String get authConfirmPasswordRequired => 'Konfirmasikan kata sandi Anda';

  @override
  String get authPasswordsDoNotMatch => 'Kata sandi tidak cocok';

  @override
  String get authForgotPassword => 'Lupa kata sandi?';

  @override
  String get authImportNostrKey => 'Impor kunci Nostr';

  @override
  String get authConnectSignerApp => 'Hubungkan dengan aplikasi signer';

  @override
  String get authSignInWithAmber => 'Masuk dengan Amber';

  @override
  String get authSignInWithBrowserExtension => 'Masuk dengan ekstensi peramban';

  @override
  String get authNip07ConnectionFailed =>
      'Tidak dapat terhubung ke ekstensi peramban Anda.';

  @override
  String get authNip07ExtensionNotFound =>
      'Tidak ditemukan ekstensi peramban. Pasang Alby, nos2x, atau ekstensi lain yang kompatibel dengan NIP-07.';

  @override
  String get authSignInOptionsTitle => 'Opsi masuk';

  @override
  String get authInfoEmailPasswordTitle => 'Email & Kata Sandi';

  @override
  String get authInfoEmailPasswordDescription =>
      'Masuk dengan akun Divine-mu. Kalau kamu mendaftar dengan email dan kata sandi, gunakan di sini.';

  @override
  String get authInfoImportNostrKeyDescription =>
      'Sudah punya identitas Nostr? Impor kunci pribadi nsec-mu dari klien lain.';

  @override
  String get authInfoSignerAppTitle => 'Aplikasi Signer';

  @override
  String get authInfoSignerAppDescription =>
      'Hubungkan menggunakan signer jarak jauh yang kompatibel dengan NIP-46 seperti nsecBunker untuk keamanan kunci yang lebih baik.';

  @override
  String get authInfoAmberTitle => 'Amber';

  @override
  String get authInfoAmberDescription =>
      'Gunakan aplikasi signer Amber di Android untuk mengelola kunci Nostr-mu dengan aman.';

  @override
  String get authInfoBrowserExtensionTitle => 'Ekstensi Peramban';

  @override
  String get authInfoBrowserExtensionDescription =>
      'Masuk dengan ekstensi peramban NIP-07 seperti Alby atau nos2x. Kunci Anda tetap di ekstensi — Divine tidak pernah melihatnya.';

  @override
  String get authCreateAccountTitle => 'Buat akun';

  @override
  String get authBackToInviteCode => 'Kembali ke kode undangan';

  @override
  String get authUseDivineNoBackup => 'Pakai Divine tanpa backup';

  @override
  String get authSkipConfirmTitle => 'Satu hal lagi...';

  @override
  String get authSkipConfirmKeyCreated =>
      'Kamu masuk! Kami akan membuat kunci aman yang menjalankan akun Divine-mu.';

  @override
  String get authSkipConfirmKeyOnly =>
      'Tanpa email, kuncimu adalah satu-satunya cara Divine mengetahui akun ini milikmu.';

  @override
  String get authSkipConfirmRecommendEmail =>
      'Kamu bisa mengakses kuncimu di aplikasi, tapi kalau kamu bukan orang teknis, kami menyarankan menambahkan email dan kata sandi sekarang. Ini memudahkan masuk dan memulihkan akunmu kalau kamu kehilangan atau mereset perangkat ini.';

  @override
  String get authAddEmailPassword => 'Tambah email & kata sandi';

  @override
  String get authUseThisDeviceOnly => 'Pakai perangkat ini saja';

  @override
  String get authCompleteRegistration => 'Lengkapi pendaftaranmu';

  @override
  String get authVerifying => 'Memverifikasi...';

  @override
  String get authVerificationLinkSent => 'Kami mengirim tautan verifikasi ke:';

  @override
  String get authClickVerificationLink =>
      'Silakan klik tautan di emailmu untuk\nmenyelesaikan pendaftaran.';

  @override
  String get authPleaseWaitVerifying =>
      'Mohon tunggu sementara kami memverifikasi emailmu...';

  @override
  String get authWaitingForVerification => 'Menunggu verifikasi';

  @override
  String get authOpenEmailApp => 'Buka aplikasi email';

  @override
  String get authWelcomeToDivine => 'Selamat datang di Divine!';

  @override
  String get authEmailVerified => 'Emailmu telah diverifikasi.';

  @override
  String get authSigningYouIn => 'Memasukkanmu';

  @override
  String get authErrorTitle => 'Waduh.';

  @override
  String get authVerificationFailed =>
      'Kami gagal memverifikasi emailmu.\nSilakan coba lagi.';

  @override
  String get authStartOver => 'Mulai ulang';

  @override
  String get authEmailVerifiedLogin =>
      'Email diverifikasi! Silakan login untuk melanjutkan.';

  @override
  String get authVerificationLinkExpired =>
      'Tautan verifikasi ini sudah tidak berlaku.';

  @override
  String get authVerificationConnectionError =>
      'Tidak bisa memverifikasi email. Silakan cek koneksimu dan coba lagi.';

  @override
  String get authWaitlistConfirmTitle => 'Kamu masuk!';

  @override
  String authWaitlistUpdatesAt(String email) {
    return 'Kami akan membagikan pembaruan di $email.\nSaat kode undangan lebih banyak tersedia, kami akan mengirimnya untukmu.';
  }

  @override
  String get authOk => 'OK';

  @override
  String get authInviteUnavailable =>
      'Akses undangan sementara tidak tersedia.';

  @override
  String get authInviteUnavailableBody =>
      'Coba lagi sebentar, atau hubungi dukungan kalau kamu butuh bantuan untuk masuk.';

  @override
  String get authTryAgain => 'Coba lagi';

  @override
  String get authContactSupport => 'Hubungi dukungan';

  @override
  String authCouldNotOpenEmail(String email) {
    return 'Tidak bisa membuka $email';
  }

  @override
  String get authAddInviteCode => 'Tambahkan kode undanganmu';

  @override
  String get authInviteCodeLabel => 'Kode undangan';

  @override
  String get authEnterYourCode => 'Masukkan kodemu';

  @override
  String get authNext => 'Lanjut';

  @override
  String get authJoinWaitlist => 'Gabung daftar tunggu';

  @override
  String get authJoinWaitlistTitle => 'Gabung daftar tunggu';

  @override
  String get authJoinWaitlistDescription =>
      'Bagikan emailmu dan kami akan mengirim pembaruan saat akses terbuka.';

  @override
  String get authJoinWaitlistNewsletterOptIn => 'Send me Divine inspiration';

  @override
  String get authInviteAccessHelp => 'Bantuan akses undangan';

  @override
  String get authGeneratingConnection => 'Membuat koneksi...';

  @override
  String get authConnectedAuthenticating => 'Terhubung! Mengautentikasi...';

  @override
  String get authConnectionTimedOut => 'Koneksi kedaluwarsa';

  @override
  String get authApproveConnection =>
      'Pastikan kamu menyetujui koneksi di aplikasi signer-mu.';

  @override
  String get authConnectionCancelled => 'Koneksi dibatalkan';

  @override
  String get authConnectionCancelledMessage => 'Koneksi dibatalkan.';

  @override
  String get authConnectionFailed => 'Koneksi gagal';

  @override
  String get authUnknownError => 'Terjadi kesalahan yang tidak diketahui.';

  @override
  String get authUrlCopied => 'URL disalin ke clipboard';

  @override
  String get authConnectToDivine => 'Hubungkan ke Divine';

  @override
  String get authPasteBunkerUrl => 'Tempel URL bunker://';

  @override
  String get authBunkerUrlHint => 'URL bunker://';

  @override
  String get authInvalidBunkerUrl =>
      'URL bunker tidak valid. Harus dimulai dengan bunker://';

  @override
  String get authScanSignerApp =>
      'Scan dengan aplikasi\nsigner-mu untuk terhubung.';

  @override
  String authWaitingForConnection(int seconds) {
    return 'Menunggu koneksi... ${seconds}d';
  }

  @override
  String get authCopyUrl => 'Salin URL';

  @override
  String get authShare => 'Bagikan';

  @override
  String get authAddBunker => 'Tambah bunker';

  @override
  String get authCompatibleSignerApps => 'Aplikasi Signer yang kompatibel';

  @override
  String get authFailedToConnect => 'Gagal terhubung';

  @override
  String get authResetPasswordTitle => 'Reset Kata Sandi';

  @override
  String get authResetPasswordSubtitle =>
      'Masukkan kata sandi barumu. Harus minimal 8 karakter.';

  @override
  String get authNewPasswordLabel => 'Kata Sandi Baru';

  @override
  String get authConfirmNewPasswordLabel => 'Konfirmasi kata sandi baru';

  @override
  String get authPasswordTooShort => 'Kata sandi harus minimal 8 karakter';

  @override
  String get authPasswordResetSuccess =>
      'Reset kata sandi berhasil. Silakan login.';

  @override
  String get authPasswordResetFailed => 'Reset kata sandi gagal';

  @override
  String get authUnexpectedError =>
      'Terjadi kesalahan tak terduga. Silakan coba lagi.';

  @override
  String get authUpdatePassword => 'Perbarui kata sandi';

  @override
  String get authSecureAccountTitle => 'Amankan akun';

  @override
  String get authUnableToAccessKeys =>
      'Tidak bisa mengakses kuncimu. Silakan coba lagi.';

  @override
  String get authRegistrationFailed => 'Pendaftaran gagal';

  @override
  String get authRegistrationComplete =>
      'Pendaftaran selesai. Silakan cek emailmu.';

  @override
  String get authVerificationFailedTitle => 'Verifikasi Gagal';

  @override
  String get authClose => 'Tutup';

  @override
  String get authAccountSecured => 'Akun Aman!';

  @override
  String get authAccountLinkedToEmail =>
      'Akunmu sekarang terhubung ke emailmu.';

  @override
  String get authVerifyYourEmail => 'Verifikasi Emailmu';

  @override
  String get authClickLinkContinue =>
      'Klik tautan di emailmu untuk menyelesaikan pendaftaran. Kamu bisa terus menggunakan aplikasi sementara itu.';

  @override
  String get authWaitingForVerificationEllipsis => 'Menunggu verifikasi...';

  @override
  String get authContinueToApp => 'Lanjut ke Aplikasi';

  @override
  String get authResetPassword => 'Reset kata sandi';

  @override
  String get authResetPasswordDescription =>
      'Masukkan alamat emailmu dan kami akan mengirim tautan untuk mereset kata sandimu.';

  @override
  String get authFailedToSendResetEmail => 'Gagal mengirim email reset.';

  @override
  String get authUnexpectedErrorShort => 'Terjadi kesalahan tak terduga.';

  @override
  String get authSending => 'Mengirim...';

  @override
  String get authSendResetLink => 'Kirim tautan reset';

  @override
  String get authEmailSent => 'Email terkirim!';

  @override
  String authResetLinkSentTo(String email) {
    return 'Kami mengirim tautan reset kata sandi ke $email. Silakan klik tautan di emailmu untuk memperbarui kata sandimu.';
  }

  @override
  String get authSignInButton => 'Masuk';

  @override
  String get authVerificationErrorTimeout =>
      'Verifikasi kedaluwarsa. Silakan coba daftar lagi.';

  @override
  String get authVerificationErrorMissingCode =>
      'Verifikasi gagal — kode otorisasi hilang.';

  @override
  String get authVerificationErrorPollFailed =>
      'Verifikasi gagal. Silakan coba lagi.';

  @override
  String get authVerificationErrorNetworkExchange =>
      'Kesalahan jaringan saat masuk. Silakan coba lagi.';

  @override
  String get authVerificationErrorOAuthExchange =>
      'Verifikasi gagal. Silakan coba daftar lagi.';

  @override
  String get authVerificationErrorSignInFailed =>
      'Masuk gagal. Silakan coba login manual.';

  @override
  String get authInviteErrorAlreadyUsed =>
      'Kode undangan itu sudah tidak tersedia. Kembali ke kode undanganmu, gabung daftar tunggu, atau hubungi dukungan.';

  @override
  String get authInviteErrorInvalid =>
      'Kode undangan itu tidak bisa digunakan sekarang. Kembali ke kode undanganmu, gabung daftar tunggu, atau hubungi dukungan.';

  @override
  String get authInviteErrorTemporary =>
      'Kami tidak bisa mengkonfirmasi undanganmu sekarang. Kembali ke kode undanganmu dan coba lagi, atau hubungi dukungan.';

  @override
  String get authInviteErrorUnknown =>
      'Kami tidak bisa mengaktifkan undanganmu. Kembali ke kode undanganmu, gabung daftar tunggu, atau hubungi dukungan.';

  @override
  String get shareSheetSave => 'Simpan';

  @override
  String get shareSheetSaveToGallery => 'Simpan ke Galeri';

  @override
  String get shareSheetSaveWithWatermark => 'Simpan dengan Watermark';

  @override
  String get shareSheetSaveVideo => 'Simpan Video';

  @override
  String get shareSheetAddToClips => 'Tambahkan ke klip';

  @override
  String get shareSheetNameClipTitle => 'Name this clip';

  @override
  String get shareSheetNameClipSubtitle =>
      'Pick a name you\'ll recognize in your library.';

  @override
  String get shareSheetClipTitleLabel => 'Clip title';

  @override
  String get shareSheetSaveClip => 'Save clip';

  @override
  String shareSheetSavedClipToClips(String title) {
    return 'Saved \"$title\" to clips';
  }

  @override
  String get shareSheetUntitledClip => 'Untitled clip';

  @override
  String get shareSheetAddToClipsFailed => 'Tidak dapat menambahkan ke klip';

  @override
  String get shareSheetAddToList => 'Tambah ke Daftar';

  @override
  String get shareSheetCopy => 'Salin';

  @override
  String get shareSheetShareVia => 'Bagikan via';

  @override
  String get shareSheetReport => 'Laporkan';

  @override
  String get shareSheetEventJson => 'Event JSON';

  @override
  String get shareSheetEventId => 'ID Event';

  @override
  String get shareSheetMoreActions => 'Aksi lainnya';

  @override
  String get watermarkDownloadSavedToCameraRoll => 'Disimpan ke Camera Roll';

  @override
  String get watermarkDownloadShare => 'Bagikan';

  @override
  String get watermarkDownloadDone => 'Selesai';

  @override
  String get watermarkDownloadPhotosAccessNeeded => 'Butuh Akses Foto';

  @override
  String get watermarkDownloadPhotosAccessDescription =>
      'Untuk menyimpan video, izinkan akses Foto di Pengaturan.';

  @override
  String get watermarkDownloadOpenSettings => 'Buka Pengaturan';

  @override
  String get watermarkDownloadNotNow => 'Nanti Saja';

  @override
  String get watermarkDownloadFailed => 'Unduhan Gagal';

  @override
  String get watermarkDownloadDismiss => 'Tutup';

  @override
  String get watermarkDownloadStageDownloading => 'Mengunduh Video';

  @override
  String get watermarkDownloadStageWatermarking => 'Menambahkan Watermark';

  @override
  String get watermarkDownloadStageSaving => 'Menyimpan ke Camera Roll';

  @override
  String get watermarkDownloadStageDownloadingDesc =>
      'Mengambil video dari jaringan...';

  @override
  String get watermarkDownloadStageWatermarkingDesc =>
      'Menerapkan watermark Divine...';

  @override
  String get watermarkDownloadStageSavingDesc =>
      'Menyimpan video ber-watermark ke camera roll-mu...';

  @override
  String get uploadProgressVideoUpload => 'Unggah Video';

  @override
  String get uploadProgressPause => 'Jeda';

  @override
  String get uploadProgressResume => 'Lanjutkan';

  @override
  String get uploadProgressGoBack => 'Kembali';

  @override
  String uploadProgressRetryWithCount(int count) {
    return 'Coba Lagi ($count tersisa)';
  }

  @override
  String get uploadProgressDelete => 'Hapus';

  @override
  String uploadProgressDaysAgo(int count) {
    return '${count}h lalu';
  }

  @override
  String uploadProgressHoursAgo(int count) {
    return '${count}j lalu';
  }

  @override
  String uploadProgressMinutesAgo(int count) {
    return '${count}m lalu';
  }

  @override
  String get uploadProgressJustNow => 'Baru saja';

  @override
  String uploadProgressUploadingPercent(int percent) {
    return 'Mengunggah $percent%';
  }

  @override
  String uploadProgressPausedPercent(int percent) {
    return 'Dijeda $percent%';
  }

  @override
  String get shareMenuTitle => 'Bagikan Video';

  @override
  String get shareMenuReportAiContent => 'Laporkan Konten AI';

  @override
  String get shareMenuReportAiContentSubtitle =>
      'Laporan cepat dugaan konten yang dihasilkan AI';

  @override
  String get shareMenuReportingAiContent => 'Melaporkan konten AI...';

  @override
  String shareMenuFailedToReportContent(String error) {
    return 'Gagal melaporkan konten: $error';
  }

  @override
  String shareMenuFailedToReportAiContent(String error) {
    return 'Gagal melaporkan konten AI: $error';
  }

  @override
  String get shareMenuVideoStatus => 'Status Video';

  @override
  String get shareMenuViewAllLists => 'Lihat semua daftar →';

  @override
  String get shareMenuShareWith => 'Bagikan Dengan';

  @override
  String get shareMenuShareViaOtherApps => 'Bagikan via aplikasi lain';

  @override
  String get shareMenuShareViaOtherAppsSubtitle =>
      'Bagikan via aplikasi lain atau salin tautan';

  @override
  String get shareMenuSaveToGallery => 'Simpan ke Galeri';

  @override
  String get shareMenuSaveOriginalSubtitle =>
      'Simpan video asli ke camera roll';

  @override
  String get shareMenuSaveWithWatermark => 'Simpan dengan Watermark';

  @override
  String get shareMenuSaveVideo => 'Simpan Video';

  @override
  String get shareMenuDownloadWithWatermark => 'Unduh dengan watermark Divine';

  @override
  String get shareMenuSaveVideoSubtitle => 'Simpan video ke camera roll';

  @override
  String get shareMenuLists => 'Daftar';

  @override
  String get shareMenuAddToList => 'Tambah ke Daftar';

  @override
  String get shareMenuAddToListSubtitle => 'Tambahkan ke daftar kurasi-mu';

  @override
  String get shareMenuCreateNewList => 'Buat Daftar Baru';

  @override
  String get shareMenuCreateNewListSubtitle => 'Mulai koleksi kurasi baru';

  @override
  String get shareMenuRemovedFromList => 'Dihapus dari daftar';

  @override
  String get shareMenuFailedToRemoveFromList => 'Gagal menghapus dari daftar';

  @override
  String get shareMenuBookmarks => 'Bookmark';

  @override
  String get shareMenuAddToBookmarks => 'Tambah ke Bookmark';

  @override
  String get shareMenuAddToBookmarksSubtitle => 'Simpan untuk ditonton nanti';

  @override
  String get shareMenuAddToBookmarkSet => 'Tambah ke Set Bookmark';

  @override
  String get shareMenuAddToBookmarkSetSubtitle => 'Susun dalam koleksi';

  @override
  String get shareMenuFollowSets => 'Set Ikuti';

  @override
  String get shareMenuCreateFollowSet => 'Buat Set Ikuti';

  @override
  String get shareMenuCreateFollowSetSubtitle =>
      'Mulai koleksi baru dengan kreator ini';

  @override
  String get shareMenuAddToFollowSet => 'Tambah ke Set Ikuti';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    return '$count set ikuti tersedia';
  }

  @override
  String get peopleListsAddToList => 'Tambahkan ke daftar';

  @override
  String get peopleListsAddToListSubtitle =>
      'Masukkan kreator ini ke salah satu daftarmu';

  @override
  String get peopleListsSheetTitle => 'Tambahkan ke daftar';

  @override
  String get peopleListsEmptyTitle => 'Belum ada daftar';

  @override
  String get peopleListsEmptySubtitle =>
      'Buat daftar untuk mulai mengelompokkan orang.';

  @override
  String get peopleListsCreateList => 'Buat daftar';

  @override
  String get peopleListsNewListTitle => 'Daftar baru';

  @override
  String get peopleListsRouteTitle => 'Daftar orang';

  @override
  String get peopleListsListNameLabel => 'Nama daftar';

  @override
  String get peopleListsListNameHint => 'Teman dekat';

  @override
  String get peopleListsCreateButton => 'Buat';

  @override
  String get peopleListsAddPeopleTitle => 'Tambahkan orang';

  @override
  String get peopleListsAddPeopleTooltip => 'Tambahkan orang';

  @override
  String get peopleListsAddPeopleSemanticLabel => 'Tambahkan orang ke daftar';

  @override
  String get peopleListsListNotFoundTitle => 'Daftar tidak ditemukan';

  @override
  String get peopleListsListNotFoundSubtitle =>
      'Daftar tidak ditemukan. Mungkin sudah dihapus.';

  @override
  String get peopleListsListDeletedSubtitle =>
      'Daftar ini mungkin sudah dihapus.';

  @override
  String get peopleListsNoPeopleTitle => 'Tidak ada orang dalam daftar ini';

  @override
  String get peopleListsNoPeopleSubtitle => 'Tambahkan orang untuk memulai';

  @override
  String get peopleListsNoVideosTitle => 'Belum ada video';

  @override
  String get peopleListsNoVideosSubtitle =>
      'Video dari anggota daftar akan muncul di sini';

  @override
  String get peopleListsNoVideosAvailable => 'Tidak ada video tersedia';

  @override
  String get peopleListsFailedToLoadVideos => 'Gagal memuat video';

  @override
  String get peopleListsVideoNotAvailable => 'Video tidak tersedia';

  @override
  String get peopleListsBackToGridTooltip => 'Kembali ke tampilan kisi';

  @override
  String get peopleListsErrorLoadingVideos => 'Kesalahan saat memuat video';

  @override
  String get peopleListsNoPeopleToAdd =>
      'Tidak ada orang yang tersedia untuk ditambahkan.';

  @override
  String peopleListsAddToListName(String name) {
    return 'Tambahkan ke $name';
  }

  @override
  String get peopleListsAddPeopleSearchHint => 'Cari orang';

  @override
  String get peopleListsAddPeopleError =>
      'Tidak dapat memuat orang. Silakan coba lagi.';

  @override
  String get peopleListsAddPeopleRetry => 'Coba lagi';

  @override
  String get peopleListsAddButton => 'Tambah';

  @override
  String peopleListsAddButtonWithCount(int count) {
    return 'Tambah $count';
  }

  @override
  String peopleListsInNLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Di $count daftar',
    );
    return '$_temp0';
  }

  @override
  String peopleListsRemoveConfirmTitle(String name) {
    return 'Hapus $name?';
  }

  @override
  String get peopleListsRemoveConfirmBody =>
      'Mereka akan dihapus dari daftar ini.';

  @override
  String get peopleListsRemove => 'Hapus';

  @override
  String peopleListsRemovedFromList(String name) {
    return '$name dihapus dari daftar';
  }

  @override
  String get peopleListsUndo => 'Batalkan';

  @override
  String peopleListsProfileLongPressHint(String name) {
    return 'Profil untuk $name. Tekan lama untuk menghapus.';
  }

  @override
  String peopleListsViewProfileHint(String name) {
    return 'Lihat profil untuk $name';
  }

  @override
  String get shareMenuAddedToBookmarks => 'Ditambahkan ke bookmark!';

  @override
  String get shareMenuFailedToAddBookmark => 'Gagal menambahkan bookmark';

  @override
  String shareMenuCreatedListAndAddedVideo(String name) {
    return 'Daftar \"$name\" dibuat dan video ditambahkan';
  }

  @override
  String get shareMenuManageContent => 'Kelola Konten';

  @override
  String get shareMenuEditVideo => 'Ubah Video';

  @override
  String get shareMenuEditVideoSubtitle =>
      'Perbarui judul, deskripsi, dan hashtag';

  @override
  String get shareMenuDeleteVideo => 'Hapus Video';

  @override
  String get shareMenuDeleteVideoSubtitle => 'Hapus konten ini secara permanen';

  @override
  String get shareMenuDeleteWarning =>
      'Ini akan mengirim permintaan hapus (NIP-09) ke semua relay. Beberapa relay mungkin masih menyimpan kontennya.';

  @override
  String get shareMenuVideoInTheseLists => 'Video ada di daftar ini:';

  @override
  String shareMenuVideoCount(int count) {
    return '$count video';
  }

  @override
  String get shareMenuClose => 'Tutup';

  @override
  String get shareMenuDeleteConfirmation => 'Yakin mau menghapus video ini?';

  @override
  String get shareMenuCancel => 'Batal';

  @override
  String get shareMenuDelete => 'Hapus';

  @override
  String get shareMenuDeletingContent => 'Menghapus konten...';

  @override
  String shareMenuFailedToDeleteContent(String error) {
    return 'Gagal menghapus konten: $error';
  }

  @override
  String get shareMenuDeleteRequestSent => 'Permintaan hapus berhasil dikirim';

  @override
  String get shareMenuDeleteFailedNotInitialized =>
      'Penghapusan belum siap. Coba lagi sebentar lagi.';

  @override
  String get shareMenuDeleteFailedNotOwner =>
      'Kamu cuma bisa menghapus video milikmu sendiri.';

  @override
  String get shareMenuDeleteFailedNotAuthenticated =>
      'Masuk lagi, lalu coba hapus.';

  @override
  String get shareMenuDeleteFailedCouldNotSign =>
      'Tidak bisa menandatangani permintaan hapus. Coba lagi.';

  @override
  String get shareMenuDeleteFailedRelayRejected =>
      'The relay wouldn\'t accept this delete request. Try again in a moment.';

  @override
  String get shareMenuDeleteFailedRelayNoResponse =>
      'Couldn\'t reach the relay. Check your connection and try again.';

  @override
  String get shareMenuDeleteFailedGeneric =>
      'Tidak bisa menghapus video ini. Coba lagi.';

  @override
  String get shareMenuFollowSetName => 'Nama Set Ikuti';

  @override
  String get shareMenuFollowSetNameHint =>
      'contoh: Kreator Konten, Musisi, dll.';

  @override
  String get shareMenuDescriptionOptional => 'Deskripsi (opsional)';

  @override
  String get shareMenuCreate => 'Buat';

  @override
  String shareMenuCreatedFollowSetAndAddedCreator(String name) {
    return 'Set ikuti \"$name\" dibuat dan kreator ditambahkan';
  }

  @override
  String get shareMenuDone => 'Selesai';

  @override
  String get shareMenuEditTitle => 'Judul';

  @override
  String get shareMenuEditTitleHint => 'Masukkan judul video';

  @override
  String get shareMenuEditDescription => 'Deskripsi';

  @override
  String get shareMenuEditDescriptionHint => 'Masukkan deskripsi video';

  @override
  String get shareMenuEditHashtags => 'Hashtag';

  @override
  String get shareMenuEditHashtagsHint => 'hashtag, dipisahkan, koma';

  @override
  String get shareMenuEditMetadataNote =>
      'Catatan: Hanya metadata yang bisa diubah. Konten video tidak bisa diubah.';

  @override
  String get shareMenuDeleting => 'Menghapus...';

  @override
  String get shareMenuUpdate => 'Perbarui';

  @override
  String get shareMenuChangeCover => 'Ubah Sampul';

  @override
  String get shareMenuCoverUploadingBackground =>
      'Thumbnail sedang diunggah di latar belakang';

  @override
  String get shareMenuVideoUpdated => 'Video berhasil diperbarui';

  @override
  String shareMenuVideoUpdatedWithInviteFailures(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count undangan kolaborator tidak terkirim.',
      one: '1 undangan kolaborator tidak terkirim.',
    );
    return 'Video diperbarui, tetapi $_temp0';
  }

  @override
  String shareMenuFailedToUpdateVideo(String error) {
    return 'Gagal memperbarui video: $error';
  }

  @override
  String shareMenuFailedToDeleteVideo(String error) {
    return 'Gagal menghapus video: $error';
  }

  @override
  String get shareMenuDeleteVideoQuestion => 'Hapus Video?';

  @override
  String get shareMenuDeleteRelayWarning =>
      'Ini akan mengirim permintaan hapus ke relay. Catatan: Beberapa relay mungkin masih punya salinan cache.';

  @override
  String get shareMenuVideoDeletionRequested => 'Penghapusan video diminta';

  @override
  String get shareMenuContentLabels => 'Label konten';

  @override
  String get shareMenuAddContentLabels => 'Tambah label konten';

  @override
  String get shareMenuClearAll => 'Bersihkan semua';

  @override
  String get shareMenuCollaborators => 'Kolaborator';

  @override
  String get shareMenuAddCollaborator => 'Tambah kolaborator';

  @override
  String shareMenuMutualFollowRequired(String name) {
    return 'Kamu perlu saling mengikuti $name untuk menambahkannya sebagai kolaborator.';
  }

  @override
  String get shareMenuLoading => 'Memuat...';

  @override
  String get shareMenuInspiredBy => 'Terinspirasi oleh';

  @override
  String get shareMenuAddInspirationCredit => 'Tambah kredit inspirasi';

  @override
  String get shareMenuCreatorCannotBeReferenced =>
      'Kreator ini tidak bisa dirujuk.';

  @override
  String get shareMenuUnknown => 'Tidak Dikenal';

  @override
  String get shareMenuCreateBookmarkSet => 'Buat Set Bookmark';

  @override
  String get shareMenuSetName => 'Nama Set';

  @override
  String get shareMenuSetNameHint => 'contoh: Favorit, Tonton Nanti, dll.';

  @override
  String get shareMenuCreateNewSet => 'Buat Set Baru';

  @override
  String get shareMenuStartNewBookmarkCollection =>
      'Mulai koleksi bookmark baru';

  @override
  String get shareMenuNoBookmarkSets =>
      'Belum ada set bookmark. Buat yang pertama!';

  @override
  String get shareMenuError => 'Kesalahan';

  @override
  String get shareMenuFailedToLoadBookmarkSets => 'Gagal memuat set bookmark';

  @override
  String shareMenuCreatedSetAndAddedVideo(String name) {
    return '\"$name\" dibuat dan video ditambahkan';
  }

  @override
  String get shareMenuUseThisSound => 'Pakai suara ini';

  @override
  String get shareMenuOriginalSound => 'Suara asli';

  @override
  String get authSessionExpired =>
      'Sesimu sudah kedaluwarsa. Silakan masuk lagi.';

  @override
  String get authSignInFailed => 'Gagal masuk. Silakan coba lagi.';

  @override
  String get localeAppLanguage => 'Bahasa Aplikasi';

  @override
  String get localeDeviceDefault => 'Bawaan perangkat';

  @override
  String get localeSelectLanguage => 'Pilih Bahasa';

  @override
  String get webAuthNotSupportedSecureMode =>
      'Autentikasi web tidak didukung dalam mode aman. Silakan pakai aplikasi seluler untuk manajemen kunci yang aman.';

  @override
  String webAuthIntegrationFailed(String error) {
    return 'Integrasi autentikasi gagal: $error';
  }

  @override
  String webAuthUnexpectedError(String error) {
    return 'Kesalahan tak terduga: $error';
  }

  @override
  String get webAuthEnterBunkerUri => 'Silakan masukkan URI bunker';

  @override
  String get webAuthConnectTitle => 'Hubungkan ke Divine';

  @override
  String get webAuthChooseMethod => 'Pilih metode autentikasi Nostr pilihanmu';

  @override
  String get webAuthBrowserExtension => 'Ekstensi Browser';

  @override
  String get webAuthRecommended => 'DIREKOMENDASIKAN';

  @override
  String get webAuthNsecBunker => 'nsec bunker';

  @override
  String get webAuthConnectRemoteSigner => 'Hubungkan ke signer jarak jauh';

  @override
  String get webAuthBunkerHint => 'bunker://pubkey?relay=wss://...';

  @override
  String get webAuthPasteFromClipboard => 'Tempel dari clipboard';

  @override
  String get webAuthConnectToBunker => 'Hubungkan ke Bunker';

  @override
  String get webAuthNewToNostr => 'Baru di Nostr?';

  @override
  String get webAuthNostrHelp =>
      'Pasang ekstensi browser seperti Alby atau nos2x untuk pengalaman termudah, atau pakai nsec bunker untuk penandatanganan jarak jauh yang aman.';

  @override
  String get soundsTitle => 'Suara';

  @override
  String get soundsSearchHint => 'Cari suara...';

  @override
  String get soundsPreviewUnavailable =>
      'Tidak bisa pratinjau suara - tidak ada audio tersedia';

  @override
  String soundsPreviewFailed(String error) {
    return 'Gagal memutar pratinjau: $error';
  }

  @override
  String get soundsFeaturedSounds => 'Suara Unggulan';

  @override
  String get soundsTrendingSounds => 'Suara Trending';

  @override
  String get soundsAllSounds => 'Semua Suara';

  @override
  String get soundsSearchResults => 'Hasil Pencarian';

  @override
  String get soundsNoSoundsAvailable => 'Tidak ada suara tersedia';

  @override
  String get soundsNoSoundsDescription =>
      'Suara akan muncul di sini saat kreator membagikan audio';

  @override
  String get soundsNoSoundsFound => 'Tidak ada suara ditemukan';

  @override
  String get soundsNoSoundsFoundDescription => 'Coba istilah pencarian lain';

  @override
  String get soundsSavedToLibrary => 'Disimpan ke Suara';

  @override
  String get soundsAlreadySavedToLibrary => 'Sudah ada di Suara';

  @override
  String get soundsSavedLibraryTitle => 'Suara Saya';

  @override
  String get soundsSavedEmptyTitle => 'Belum ada suara yang tersimpan';

  @override
  String get soundsSavedEmptyDescription =>
      'Ketuk Gunakan Suara pada video untuk menyimpannya di sini.';

  @override
  String get soundsAvailabilityPrivate => 'Pribadi';

  @override
  String get soundsAvailabilityCommunity => 'Komunitas';

  @override
  String get soundsRemoveSavedSound => 'Hapus suara';

  @override
  String get soundsRemovedFromLibrary => 'Dihapus dari Suara';

  @override
  String get soundsFailedToLoad => 'Gagal memuat suara';

  @override
  String get soundsRetry => 'Coba Lagi';

  @override
  String get soundsScreenLabel => 'Layar suara';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileRefresh => 'Segarkan';

  @override
  String get profileRefreshLabel => 'Segarkan profil';

  @override
  String get profileMoreOptions => 'Opsi lainnya';

  @override
  String profileBlockedUser(String name) {
    return 'Memblokir $name';
  }

  @override
  String profileUnblockedUser(String name) {
    return 'Membuka blokir $name';
  }

  @override
  String profileUnfollowedUser(String name) {
    return 'Berhenti mengikuti $name';
  }

  @override
  String profileError(String error) {
    return 'Kesalahan: $error';
  }

  @override
  String get profileFeedError => 'Couldn\'t load videos.';

  @override
  String get profileFeedLoadMoreError =>
      'Couldn\'t load more videos. Pull to refresh.';

  @override
  String get notificationsTabAll => 'Semua';

  @override
  String get notificationsTabLikes => 'Suka';

  @override
  String get notificationsTabComments => 'Komentar';

  @override
  String get notificationsTabFollows => 'Pengikut';

  @override
  String get notificationsTabReposts => 'Repost';

  @override
  String get notificationsFailedToLoad => 'Gagal memuat notifikasi';

  @override
  String get notificationsRetry => 'Coba Lagi';

  @override
  String get notificationsRefreshError =>
      'Gagal menyegarkan — menampilkan yang tersedia';

  @override
  String get notificationsCheckingNew => 'mengecek notifikasi baru';

  @override
  String get notificationsNoneYet => 'Belum ada notifikasi';

  @override
  String notificationsNoneForType(String type) {
    return 'Tidak ada notifikasi $type';
  }

  @override
  String get notificationsEmptyDescription =>
      'Saat orang berinteraksi dengan kontenmu, kamu akan melihatnya di sini';

  @override
  String get notificationsUnreadPrefix => 'Notifikasi belum dibaca';

  @override
  String notificationsBadgeUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread notifications',
      one: '1 unread notification',
    );
    return '$_temp0';
  }

  @override
  String notificationsViewProfileSemanticLabel(String displayName) {
    return 'Lihat profil $displayName';
  }

  @override
  String get notificationsViewProfilesSemanticLabel => 'Lihat profil';

  @override
  String notificationsVideoThumbnailFor(String title) {
    return 'Thumbnail video untuk $title';
  }

  @override
  String get notificationsVideoThumbnail => 'Thumbnail video';

  @override
  String notificationsLoadingType(String type) {
    return 'Memuat notifikasi $type...';
  }

  @override
  String get notificationsInviteSingular =>
      'Kamu punya 1 undangan untuk dibagikan ke teman!';

  @override
  String notificationsInvitePlural(int count) {
    return 'Kamu punya $count undangan untuk dibagikan ke teman!';
  }

  @override
  String get notificationsVideoNotFound => 'Video tidak ditemukan';

  @override
  String get notificationsVideoUnavailable => 'Video tidak tersedia';

  @override
  String get notificationsFromNotification => 'Dari Notifikasi';

  @override
  String get feedFailedToLoadVideos => 'Gagal memuat video';

  @override
  String get feedRetry => 'Coba Lagi';

  @override
  String get feedNoFollowedUsers =>
      'Tidak ada pengguna yang diikuti.\nIkuti seseorang untuk melihat video mereka di sini.';

  @override
  String get feedModeForYou => 'Untukmu';

  @override
  String get feedModeNew => 'Baru';

  @override
  String get feedModeFollowing => 'Mengikuti';

  @override
  String get feedModeClassics => 'Klasik';

  @override
  String feedModeSemanticLabel(String label) {
    return 'Mode feed: $label';
  }

  @override
  String videoAuthorSemanticLabel(String displayName) {
    return 'Pembuat video: $displayName';
  }

  @override
  String get videoAuthorAvatarSemanticLabel => 'Avatar pembuat';

  @override
  String get feedForYouEmpty =>
      'Feed Untuk Anda kamu kosong.\nJelajahi video dan ikuti kreator untuk membentuknya.';

  @override
  String get feedFollowingEmpty =>
      'Belum ada video dari orang yang kamu ikuti.\nTemukan kreator yang kamu suka dan ikuti mereka.';

  @override
  String get feedLatestEmpty =>
      'Belum ada video baru.\nCek lagi sebentar lagi.';

  @override
  String get feedClassicEmpty => 'Belum ada klasik.\nCek lagi sebentar lagi.';

  @override
  String get feedExploreVideos => 'Jelajahi Video';

  @override
  String get feedExternalVideoSlow => 'Video eksternal memuat lambat';

  @override
  String get feedSkip => 'Lewati';

  @override
  String get feedLoadingMore => 'Loading more videos…';

  @override
  String get uploadWaitingToUpload => 'Menunggu unggah';

  @override
  String get uploadUploadingVideo => 'Mengunggah video';

  @override
  String get uploadProcessingVideo => 'Memproses video';

  @override
  String get uploadProcessingComplete => 'Pemrosesan selesai';

  @override
  String get uploadPublishedSuccessfully => 'Berhasil dipublikasikan';

  @override
  String get uploadFailed => 'Unggah gagal';

  @override
  String get uploadRetrying => 'Mencoba unggah lagi';

  @override
  String get uploadPaused => 'Unggahan dijeda';

  @override
  String uploadPercentComplete(int percent) {
    return '$percent% selesai';
  }

  @override
  String get uploadQueuedMessage => 'Videomu dalam antrean unggah';

  @override
  String get uploadUploadingMessage => 'Mengunggah ke server...';

  @override
  String get uploadProcessingMessage =>
      'Memproses video - ini mungkin butuh beberapa menit';

  @override
  String get uploadReadyToPublishMessage =>
      'Video berhasil diproses dan siap dipublikasikan';

  @override
  String get uploadPublishedMessage => 'Video dipublikasikan ke profilmu';

  @override
  String get uploadFailedMessage => 'Unggah gagal - silakan coba lagi';

  @override
  String get uploadRetryingMessage => 'Mencoba unggah lagi...';

  @override
  String get uploadPausedMessage => 'Unggahan dijeda oleh pengguna';

  @override
  String get uploadRetryButton => 'COBA LAGI';

  @override
  String uploadRetryFailed(String error) {
    return 'Gagal mencoba unggah lagi: $error';
  }

  @override
  String get userSearchPrompt => 'Cari pengguna';

  @override
  String get userSearchNoResults => 'Tidak ada pengguna ditemukan';

  @override
  String get userSearchFailed => 'Pencarian gagal';

  @override
  String get userPickerSearchByName => 'Cari berdasarkan nama';

  @override
  String get userPickerFilterByNameHint => 'Filter berdasarkan nama...';

  @override
  String get userPickerSearchByNameHint => 'Cari berdasarkan nama...';

  @override
  String userPickerAlreadyAddedSemantics(String name) {
    return '$name sudah ditambahkan';
  }

  @override
  String userPickerSelectSemantics(String name) {
    return 'Pilih $name';
  }

  @override
  String userPickerRemoveSelectionSemantics(String name) {
    return 'Hapus $name';
  }

  @override
  String get userPickerEmptyFollowListTitle => 'Kru kamu ada di luar sana';

  @override
  String get userPickerEmptyFollowListBody =>
      'Ikuti orang yang cocok dengan vibe kamu. Saat mereka follow balik, kalian bisa kolaborasi.';

  @override
  String get userPickerGoBack => 'Kembali';

  @override
  String get userPickerTypeNameToSearch => 'Ketik nama untuk mencari';

  @override
  String get userPickerUnavailable =>
      'Pencarian pengguna tidak tersedia. Coba lagi nanti.';

  @override
  String get userPickerSearchFailedTryAgain => 'Pencarian gagal. Coba lagi.';

  @override
  String get forgotPasswordTitle => 'Reset Kata Sandi';

  @override
  String get forgotPasswordDescription =>
      'Masukkan alamat emailmu dan kami akan mengirim tautan untuk mereset kata sandimu.';

  @override
  String get forgotPasswordEmailLabel => 'Alamat Email';

  @override
  String get forgotPasswordCancel => 'Batal';

  @override
  String get forgotPasswordSendLink => 'Email Tautan Reset';

  @override
  String get ageVerificationContentWarning => 'Peringatan Konten';

  @override
  String get ageVerificationTitle => 'Verifikasi Usia';

  @override
  String get ageVerificationAdultDescription =>
      'Konten ini ditandai kemungkinan mengandung materi dewasa. Kamu harus berusia 18 tahun atau lebih untuk melihatnya.';

  @override
  String get ageVerificationCreationDescription =>
      'Untuk menggunakan kamera dan membuat konten, kamu harus berusia minimal 16 tahun.';

  @override
  String get ageVerificationAdultQuestion =>
      'Apakah kamu berusia 18 tahun atau lebih?';

  @override
  String get ageVerificationCreationQuestion =>
      'Apakah kamu berusia 16 tahun atau lebih?';

  @override
  String get ageVerificationNo => 'Tidak';

  @override
  String get ageVerificationYes => 'Ya';

  @override
  String get shareLinkCopied => 'Tautan disalin ke clipboard';

  @override
  String get shareFailedToCopy => 'Gagal menyalin tautan';

  @override
  String get shareVideoSubject => 'Lihat video ini di Divine';

  @override
  String get shareFailedToShare => 'Gagal membagikan';

  @override
  String get shareVideoTitle => 'Bagikan Video';

  @override
  String get shareToApps => 'Bagikan ke Aplikasi';

  @override
  String get shareToAppsSubtitle => 'Bagikan via pesan, aplikasi sosial';

  @override
  String get shareCopyWebLink => 'Salin Tautan Web';

  @override
  String get shareCopyWebLinkSubtitle => 'Salin tautan web yang bisa dibagikan';

  @override
  String get shareCopyNostrLink => 'Salin Tautan Nostr';

  @override
  String get shareCopyNostrLinkSubtitle =>
      'Salin tautan nevent untuk klien Nostr';

  @override
  String get navHome => 'Beranda';

  @override
  String get navExplore => 'Jelajahi';

  @override
  String get navInbox => 'Kotak Masuk';

  @override
  String get navProfile => 'Profil';

  @override
  String get navSearch => 'Cari';

  @override
  String get navSearchTooltip => 'Cari';

  @override
  String get navMyProfile => 'Profilku';

  @override
  String get navNotifications => 'Notifikasi';

  @override
  String get navOpenCamera => 'Buka kamera';

  @override
  String get navUnknown => 'Tidak Dikenal';

  @override
  String get navExploreClassics => 'Klasik';

  @override
  String get navExploreNewVideos => 'Video Baru';

  @override
  String get navExploreTrending => 'Trending';

  @override
  String get navExploreForYou => 'Untukmu';

  @override
  String get navExploreLists => 'Daftar';

  @override
  String get routeErrorTitle => 'Kesalahan';

  @override
  String get routeInvalidHashtag => 'Hashtag tidak valid';

  @override
  String get routeInvalidConversationId => 'ID percakapan tidak valid';

  @override
  String get routeInvalidRequestId => 'ID permintaan tidak valid';

  @override
  String get routeInvalidListId => 'ID daftar tidak valid';

  @override
  String get routeInvalidUserId => 'ID pengguna tidak valid';

  @override
  String get routeInvalidVideoId => 'ID video tidak valid';

  @override
  String get routeInvalidSoundId => 'ID suara tidak valid';

  @override
  String get routeInvalidCategory => 'Kategori tidak valid';

  @override
  String get routeNoVideosToDisplay => 'Tidak ada video untuk ditampilkan';

  @override
  String get routeInvalidProfileId => 'ID profil tidak valid';

  @override
  String get routeUnknownPath => 'Halaman itu tidak ada di aplikasi.';

  @override
  String get routeDefaultListName => 'Daftar';

  @override
  String get supportTitle => 'Pusat Bantuan';

  @override
  String get supportContactSupport => 'Hubungi Dukungan';

  @override
  String get supportContactSupportSubtitle =>
      'Mulai percakapan atau lihat pesan sebelumnya';

  @override
  String get supportReportBug => 'Laporkan Bug';

  @override
  String get supportReportBugSubtitle => 'Masalah teknis dengan aplikasi';

  @override
  String get supportRequestFeature => 'Minta Fitur';

  @override
  String get supportRequestFeatureSubtitle =>
      'Sarankan perbaikan atau fitur baru';

  @override
  String get supportSaveLogs => 'Simpan Log';

  @override
  String get supportSaveLogsSubtitle =>
      'Ekspor log ke file untuk pengiriman manual';

  @override
  String get supportFaq => 'FAQ';

  @override
  String get supportFaqSubtitle => 'Pertanyaan & jawaban umum';

  @override
  String get supportProofMode => 'ProofMode';

  @override
  String get supportProofModeSubtitle =>
      'Pelajari tentang verifikasi dan keaslian';

  @override
  String get supportLoginRequired => 'Login untuk menghubungi dukungan';

  @override
  String get supportExportingLogs => 'Mengekspor log...';

  @override
  String get supportExportLogsFailed => 'Gagal mengekspor log';

  @override
  String supportLogsSavedTo(String path) {
    return 'Log disimpan ke $path';
  }

  @override
  String get supportRevealLogsAction => 'Tampilkan di folder';

  @override
  String get supportChatNotAvailable => 'Chat dukungan tidak tersedia';

  @override
  String get supportCouldNotOpenMessages => 'Tidak bisa membuka pesan dukungan';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return 'Tidak bisa membuka $pageName';
  }

  @override
  String supportErrorOpeningPage(String pageName, Object error) {
    return 'Kesalahan membuka $pageName: $error';
  }

  @override
  String get reportTitle => 'Laporkan Konten';

  @override
  String get reportWhyReporting => 'Kenapa kamu melaporkan konten ini?';

  @override
  String get reportPolicyNotice =>
      'Divine akan menindak laporan konten dalam 24 jam dengan menghapus konten dan mengeluarkan pengguna yang memberikan konten yang melanggar.';

  @override
  String get reportAdditionalDetails => 'Detail tambahan (opsional)';

  @override
  String get reportBlockUser => 'Blokir pengguna ini';

  @override
  String get reportCancel => 'Batal';

  @override
  String get reportSubmit => 'Laporkan';

  @override
  String get reportSelectReason =>
      'Silakan pilih alasan untuk melaporkan konten ini';

  @override
  String get reportOtherRequiresDetails =>
      'Please describe the issue when selecting Other';

  @override
  String get reportDetailsRequired => 'Please describe the issue';

  @override
  String get reportReasonSpam => 'Spam atau Konten Tidak Diinginkan';

  @override
  String get reportReasonSpamSubtitle =>
      'Konten yang tidak diinginkan atau berulang';

  @override
  String get reportReasonHarassment => 'Pelecehan, Perundungan, atau Ancaman';

  @override
  String get reportReasonHarassmentSubtitle =>
      'Balasan atau sebutan berbahaya dan tidak diinginkan';

  @override
  String get reportReasonViolence => 'Konten Kekerasan atau Ekstremis';

  @override
  String get reportReasonViolenceSubtitle =>
      'Konten kekerasan, ekstremis, atau berbahaya';

  @override
  String get reportReasonSexualContent => 'Konten Seksual atau Dewasa';

  @override
  String get reportReasonSexualContentSubtitle =>
      'Ketelanjangan, porno, atau konten eksplisit';

  @override
  String get reportReasonCopyright => 'Pelanggaran Hak Cipta';

  @override
  String get reportReasonCopyrightSubtitle =>
      'Penggunaan kekayaan intelektual tanpa izin';

  @override
  String get reportReasonFalseInfo => 'Informasi Salah';

  @override
  String get reportReasonFalseInfoSubtitle => 'Klaim menyesatkan atau palsu';

  @override
  String get reportReasonChildSafety => 'Child Safety Violation';

  @override
  String get reportReasonChildSafetySubtitle =>
      'General concerns about minors\' safety';

  @override
  String get reportReasonCsam => 'Pelanggaran Keamanan Anak';

  @override
  String get reportReasonCsamSubtitle =>
      'Konten yang mengeksploitasi atau membahayakan anak di bawah umur';

  @override
  String get reportReasonUnderageUser => 'User Appears Under 16';

  @override
  String get reportReasonUnderageUserSubtitle =>
      'Account holder appears to be underage';

  @override
  String get reportReasonAiGenerated => 'Konten Dihasilkan AI';

  @override
  String get reportReasonAiGeneratedSubtitle =>
      'Konten yang diduga dibuat oleh AI';

  @override
  String get reportReasonOther => 'Pelanggaran Kebijakan Lainnya';

  @override
  String get reportReasonOtherSubtitle =>
      'Pelanggaran yang tidak tercantum di atas';

  @override
  String reportFailed(Object error) {
    return 'Gagal melaporkan konten: $error';
  }

  @override
  String get reportReceivedTitle => 'Laporan Diterima';

  @override
  String get reportReceivedThankYou =>
      'Terima kasih sudah membantu menjaga Divine tetap aman.';

  @override
  String get reportReceivedReviewNotice =>
      'Tim kami akan meninjau laporanmu dan mengambil tindakan yang sesuai. Kamu mungkin menerima pembaruan via pesan langsung.';

  @override
  String get reportModerationDmDelayed =>
      'We couldn\'t reach the moderation team directly just now, but your report was received and will be reviewed.';

  @override
  String get reportContactModeration => 'Message the moderation team';

  @override
  String get reportLearnMore => 'Pelajari Lebih Lanjut';

  @override
  String get reportLearnMoreAt => 'Pelajari lebih lanjut di';

  @override
  String get reportSafetyUrl => 'divine.video/safety';

  @override
  String get reportClose => 'Tutup';

  @override
  String get listAddToList => 'Tambah ke Daftar';

  @override
  String listVideoCount(int count) {
    return '$count video';
  }

  @override
  String listPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count orang',
      one: '1 orang',
    );
    return '$_temp0';
  }

  @override
  String get listByAuthorPrefix => 'Oleh ';

  @override
  String get listNewList => 'Daftar Baru';

  @override
  String get listDone => 'Selesai';

  @override
  String get listErrorLoading => 'Kesalahan memuat daftar';

  @override
  String listRemovedFrom(String name) {
    return 'Dihapus dari $name';
  }

  @override
  String listAddedTo(String name) {
    return 'Ditambahkan ke $name';
  }

  @override
  String get listCreateNewList => 'Buat Daftar Baru';

  @override
  String get listNewPeopleList => 'Daftar orang baru';

  @override
  String get listCollaboratorsNone => 'Tidak ada';

  @override
  String get listAddCollaboratorTitle => 'Tambah kolaborator';

  @override
  String get listCollaboratorSearchHint => 'Cari di diVine...';

  @override
  String get listNameLabel => 'Nama Daftar';

  @override
  String get listDescriptionLabel => 'Deskripsi (opsional)';

  @override
  String get listPublicList => 'Daftar Publik';

  @override
  String get listPublicListSubtitle =>
      'Orang lain bisa mengikuti dan melihat daftar ini';

  @override
  String get listCancel => 'Batal';

  @override
  String get listCreate => 'Buat';

  @override
  String get listCreateFailed => 'Gagal membuat daftar';

  @override
  String get keyManagementTitle => 'Kunci Nostr';

  @override
  String get keyManagementWhatAreKeys => 'Apa itu kunci Nostr?';

  @override
  String get keyManagementExplanation =>
      'Identitas Nostr-mu adalah pasangan kunci kriptografis:\n\n• Kunci publikmu (npub) seperti username-mu - bagikan dengan bebas\n• Kunci privatmu (nsec) seperti kata sandimu - jaga kerahasiaannya!\n\nnsec-mu memungkinkanmu mengakses akunmu di aplikasi Nostr mana pun.';

  @override
  String get keyManagementImportTitle => 'Impor Kunci yang Ada';

  @override
  String get keyManagementImportSubtitle =>
      'Sudah punya akun Nostr? Tempel kunci privatmu (nsec) untuk mengaksesnya di sini.';

  @override
  String get keyManagementImportButton => 'Impor Kunci';

  @override
  String get keyManagementImportWarning =>
      'Ini akan mengganti kuncimu saat ini!';

  @override
  String get keyManagementBackupTitle => 'Backup Kuncimu';

  @override
  String get keyManagementBackupSubtitle =>
      'Simpan kunci privatmu (nsec) untuk menggunakan akunmu di aplikasi Nostr lain.';

  @override
  String get keyManagementCopyNsec => 'Salin Kunci Privatku (nsec)';

  @override
  String get keyManagementNeverShare =>
      'Jangan pernah bagikan nsec-mu ke siapa pun!';

  @override
  String get keyManagementKeycastRemoteSigning =>
      'Akun ini menandatangani dengan Keycast. Tidak ada kunci privat yang disimpan di perangkat ini, jadi tidak ada nsec untuk disalin di sini.';

  @override
  String get keyManagementPasteKey => 'Silakan tempel kunci privatmu';

  @override
  String get keyManagementInvalidFormat =>
      'Format kunci tidak valid. Harus dimulai dengan \"nsec1\"';

  @override
  String get keyManagementConfirmImportTitle => 'Impor Kunci Ini?';

  @override
  String get keyManagementConfirmImportBody =>
      'Ini akan mengganti identitasmu saat ini dengan yang diimpor.\n\nKunci saat ini akan hilang kecuali kamu sudah mem-backup-nya.';

  @override
  String get keyManagementImportConfirm => 'Impor';

  @override
  String get keyManagementImportSuccess => 'Kunci berhasil diimpor!';

  @override
  String keyManagementImportFailed(Object error) {
    return 'Gagal mengimpor kunci: $error';
  }

  @override
  String get keyManagementExportSuccess =>
      'Kunci privat disalin ke clipboard!\n\nSimpan di tempat yang aman.';

  @override
  String keyManagementExportFailed(Object error) {
    return 'Gagal mengekspor kunci: $error';
  }

  @override
  String get keyManagementYourPublicKeyLabel => 'Kunci publikmu (npub)';

  @override
  String get keyManagementCopyPublicKeyTooltip => 'Salin kunci publik';

  @override
  String get keyManagementPublicKeyCopied => 'Kunci publik tersalin';

  @override
  String get profileEditPublicKeyLink => 'Lihat kunci publikmu';

  @override
  String get saveOriginalSavedToCameraRoll => 'Disimpan ke Camera Roll';

  @override
  String get saveOriginalShare => 'Bagikan';

  @override
  String get saveOriginalDone => 'Selesai';

  @override
  String get saveOriginalPhotosAccessNeeded => 'Butuh Akses Foto';

  @override
  String get saveOriginalPhotosAccessMessage =>
      'Untuk menyimpan video, izinkan akses Foto di Pengaturan.';

  @override
  String get saveOriginalOpenSettings => 'Buka Pengaturan';

  @override
  String get saveOriginalNotNow => 'Nanti Saja';

  @override
  String get saveOriginalDownloadFailed => 'Unduhan Gagal';

  @override
  String get saveOriginalDismiss => 'Tutup';

  @override
  String get saveOriginalDownloadingVideo => 'Mengunduh Video';

  @override
  String get saveOriginalSavingToCameraRoll => 'Menyimpan ke Camera Roll';

  @override
  String get saveOriginalFetchingVideo => 'Mengambil video dari jaringan...';

  @override
  String get saveOriginalSavingVideo =>
      'Menyimpan video asli ke camera roll-mu...';

  @override
  String get soundTitle => 'Suara';

  @override
  String get soundOriginalSound => 'Suara asli';

  @override
  String get soundVideosUsingThisSound => 'Video yang memakai suara ini';

  @override
  String get soundSourceVideo => 'Video sumber';

  @override
  String get soundNoVideosYet => 'Belum ada video';

  @override
  String get soundBeFirstToUse => 'Jadilah yang pertama memakai suara ini!';

  @override
  String get soundFailedToLoadVideos => 'Gagal memuat video';

  @override
  String get soundRetry => 'Coba Lagi';

  @override
  String get soundVideosUnavailable => 'Video tidak tersedia';

  @override
  String get soundCouldNotLoadDetails => 'Tidak bisa memuat detail video';

  @override
  String get soundPreview => 'Pratinjau';

  @override
  String get soundStop => 'Berhenti';

  @override
  String get soundUseSound => 'Pakai Suara';

  @override
  String get soundUntitled => 'Suara tanpa judul';

  @override
  String get soundStopPreview => 'Hentikan pratinjau';

  @override
  String soundPreviewSemanticLabel(String title) {
    return 'Pratinjau $title';
  }

  @override
  String soundViewDetailsSemanticLabel(String title) {
    return 'Lihat detail untuk $title';
  }

  @override
  String get soundNoVideoCount => 'Belum ada video';

  @override
  String get soundOneVideo => '1 video';

  @override
  String soundVideoCount(int count) {
    return '$count video';
  }

  @override
  String get soundUnableToPreview =>
      'Tidak bisa pratinjau suara - tidak ada audio tersedia';

  @override
  String soundPreviewFailed(Object error) {
    return 'Gagal memutar pratinjau: $error';
  }

  @override
  String get soundViewSource => 'Lihat sumber';

  @override
  String get soundCloseTooltip => 'Tutup';

  @override
  String get exploreNotExploreRoute => 'Bukan rute jelajah';

  @override
  String get legalTitle => 'Legal';

  @override
  String get legalTermsOfService => 'Ketentuan Layanan';

  @override
  String get legalTermsOfServiceSubtitle => 'Syarat dan ketentuan penggunaan';

  @override
  String get legalPrivacyPolicy => 'Kebijakan Privasi';

  @override
  String get legalPrivacyPolicySubtitle => 'Bagaimana kami menangani datamu';

  @override
  String get legalSafetyStandards => 'Standar Keamanan';

  @override
  String get legalSafetyStandardsSubtitle => 'Pedoman komunitas dan keamanan';

  @override
  String get legalDmca => 'DMCA';

  @override
  String get legalDmcaSubtitle => 'Kebijakan hak cipta dan takedown';

  @override
  String get legalOpenSourceLicenses => 'Lisensi Open Source';

  @override
  String get legalOpenSourceLicensesSubtitle => 'Atribusi paket pihak ketiga';

  @override
  String get legalAppName => 'Divine';

  @override
  String legalCouldNotOpenPage(String pageName) {
    return 'Tidak bisa membuka $pageName';
  }

  @override
  String legalErrorOpeningPage(String pageName, Object error) {
    return 'Kesalahan membuka $pageName: $error';
  }

  @override
  String get categoryAction => 'Aksi';

  @override
  String get categoryAdventure => 'Petualangan';

  @override
  String get categoryAnimals => 'Hewan';

  @override
  String get categoryAnimation => 'Animasi';

  @override
  String get categoryArchitecture => 'Arsitektur';

  @override
  String get categoryArt => 'Seni';

  @override
  String get categoryAutomotive => 'Otomotif';

  @override
  String get categoryAwardShow => 'Ajang Penghargaan';

  @override
  String get categoryAwards => 'Penghargaan';

  @override
  String get categoryBaseball => 'Bisbol';

  @override
  String get categoryBasketball => 'Basket';

  @override
  String get categoryBeauty => 'Kecantikan';

  @override
  String get categoryBeverage => 'Minuman';

  @override
  String get categoryCars => 'Mobil';

  @override
  String get categoryCelebration => 'Perayaan';

  @override
  String get categoryCelebrities => 'Selebriti';

  @override
  String get categoryCelebrity => 'Selebriti';

  @override
  String get categoryCityscape => 'Pemandangan Kota';

  @override
  String get categoryComedy => 'Komedi';

  @override
  String get categoryConcert => 'Konser';

  @override
  String get categoryCooking => 'Memasak';

  @override
  String get categoryCostume => 'Kostum';

  @override
  String get categoryCrafts => 'Kerajinan';

  @override
  String get categoryCrime => 'Kriminal';

  @override
  String get categoryCulture => 'Budaya';

  @override
  String get categoryDance => 'Tari';

  @override
  String get categoryDiy => 'DIY';

  @override
  String get categoryDrama => 'Drama';

  @override
  String get categoryEducation => 'Pendidikan';

  @override
  String get categoryEmotional => 'Emosional';

  @override
  String get categoryEmotions => 'Emosi';

  @override
  String get categoryEntertainment => 'Hiburan';

  @override
  String get categoryEvent => 'Acara';

  @override
  String get categoryFamily => 'Keluarga';

  @override
  String get categoryFans => 'Penggemar';

  @override
  String get categoryFantasy => 'Fantasi';

  @override
  String get categoryFashion => 'Mode';

  @override
  String get categoryFestival => 'Festival';

  @override
  String get categoryFilm => 'Film';

  @override
  String get categoryFitness => 'Kebugaran';

  @override
  String get categoryFood => 'Makanan';

  @override
  String get categoryFootball => 'Football';

  @override
  String get categoryFurniture => 'Furnitur';

  @override
  String get categoryGaming => 'Game';

  @override
  String get categoryGolf => 'Golf';

  @override
  String get categoryGrooming => 'Perawatan Diri';

  @override
  String get categoryGuitar => 'Gitar';

  @override
  String get categoryHalloween => 'Halloween';

  @override
  String get categoryHealth => 'Kesehatan';

  @override
  String get categoryHockey => 'Hoki';

  @override
  String get categoryHoliday => 'Liburan';

  @override
  String get categoryHome => 'Rumah';

  @override
  String get categoryHomeImprovement => 'Renovasi Rumah';

  @override
  String get categoryHorror => 'Horor';

  @override
  String get categoryHospital => 'Rumah Sakit';

  @override
  String get categoryHumor => 'Humor';

  @override
  String get categoryInteriorDesign => 'Desain Interior';

  @override
  String get categoryInterview => 'Wawancara';

  @override
  String get categoryKids => 'Anak-anak';

  @override
  String get categoryLifestyle => 'Gaya Hidup';

  @override
  String get categoryMagic => 'Sulap';

  @override
  String get categoryMakeup => 'Makeup';

  @override
  String get categoryMedical => 'Medis';

  @override
  String get categoryMusic => 'Musik';

  @override
  String get categoryMystery => 'Misteri';

  @override
  String get categoryNature => 'Alam';

  @override
  String get categoryNews => 'Berita';

  @override
  String get categoryOutdoor => 'Luar Ruang';

  @override
  String get categoryParty => 'Pesta';

  @override
  String get categoryPeople => 'Orang';

  @override
  String get categoryPerformance => 'Pertunjukan';

  @override
  String get categoryPets => 'Hewan Peliharaan';

  @override
  String get categoryPolitics => 'Politik';

  @override
  String get categoryPrank => 'Prank';

  @override
  String get categoryPranks => 'Prank';

  @override
  String get categoryRealityShow => 'Reality Show';

  @override
  String get categoryRelationship => 'Hubungan';

  @override
  String get categoryRelationships => 'Hubungan';

  @override
  String get categoryRomance => 'Romansa';

  @override
  String get categorySchool => 'Sekolah';

  @override
  String get categoryScienceFiction => 'Fiksi Ilmiah';

  @override
  String get categorySelfie => 'Selfie';

  @override
  String get categoryShopping => 'Belanja';

  @override
  String get categorySkateboarding => 'Skateboard';

  @override
  String get categorySkincare => 'Perawatan Kulit';

  @override
  String get categorySoccer => 'Sepak Bola';

  @override
  String get categorySocialGathering => 'Pertemuan Sosial';

  @override
  String get categorySocialMedia => 'Media Sosial';

  @override
  String get categorySports => 'Olahraga';

  @override
  String get categoryTalkShow => 'Talk Show';

  @override
  String get categoryTech => 'Tek';

  @override
  String get categoryTechnology => 'Teknologi';

  @override
  String get categoryTelevision => 'Televisi';

  @override
  String get categoryToys => 'Mainan';

  @override
  String get categoryTransportation => 'Transportasi';

  @override
  String get categoryTravel => 'Jalan-jalan';

  @override
  String get categoryUrban => 'Urban';

  @override
  String get categoryViolence => 'Kekerasan';

  @override
  String get categoryVlog => 'Vlog';

  @override
  String get categoryVlogging => 'Vlogging';

  @override
  String get categoryWrestling => 'Gulat';

  @override
  String get profileSetupUploadStaged =>
      'Diunggah — ketuk Simpan untuk menerapkan';

  @override
  String inboxReportedUser(String displayName) {
    return '$displayName dilaporkan';
  }

  @override
  String inboxBlockedUser(String displayName) {
    return '$displayName diblokir';
  }

  @override
  String inboxUnblockedUser(String displayName) {
    return '$displayName tidak diblokir lagi';
  }

  @override
  String get inboxRemovedConversation => 'Percakapan dihapus';

  @override
  String get inboxRestoringMessages => 'Memulihkan pesan Anda…';

  @override
  String get inboxEmptyTitle => 'Belum ada pesan';

  @override
  String get inboxEmptySubtitle => 'Tombol + tidak menggigit kok.';

  @override
  String get inboxActionMute => 'Bisukan percakapan';

  @override
  String inboxActionReport(String displayName) {
    return 'Laporkan $displayName';
  }

  @override
  String inboxActionBlock(String displayName) {
    return 'Blokir $displayName';
  }

  @override
  String inboxActionUnblock(String displayName) {
    return 'Buka blokir $displayName';
  }

  @override
  String get inboxActionRemove => 'Hapus percakapan';

  @override
  String get inboxRemoveConfirmTitle => 'Hapus percakapan?';

  @override
  String inboxRemoveConfirmBody(String displayName) {
    return 'Ini akan menghapus percakapanmu dengan $displayName. Tindakan ini tidak bisa dibatalkan.';
  }

  @override
  String get inboxRemoveConfirmConfirm => 'Hapus';

  @override
  String get inboxConversationMuted => 'Percakapan dibisukan';

  @override
  String get inboxConversationUnmuted => 'Bisu percakapan dibatalkan';

  @override
  String get inboxCollabInviteCardTitle => 'Undangan kolaborasi';

  @override
  String get inboxCollabInviteCardUntitledVideo => 'Video tanpa judul';

  @override
  String get clickableTextViewVideoLink => 'Lihat video';

  @override
  String get messageExternalLinkDialogTitle => 'Buka tautan eksternal?';

  @override
  String messageExternalLinkDialogBody(String url) {
    return 'Tautan ini menuju situs eksternal dan mungkin tidak aman:\n\n$url';
  }

  @override
  String get messageExternalLinkDialogOpen => 'Buka';

  @override
  String get inboxCollabInviteCoPostButton => 'Posting bersama';

  @override
  String get inboxCollabInviteNotMineButton => 'Bukan milik saya';

  @override
  String get inboxCollabInvitePreviewTitle => 'Undangan posting bersama';

  @override
  String inboxCollabInvitePreviewTitleFrom(String displayName) {
    return 'Undangan posting bersama dari $displayName';
  }

  @override
  String get inboxCollabInviteTimelineConsequence =>
      'Posting bersama menambahkan video ini ke timeline Anda sebagai kolaborasi.';

  @override
  String get inboxCollabInviteAcceptedStatus => 'Diterima';

  @override
  String get inboxCollabInviteIgnoredStatus => 'Diabaikan';

  @override
  String get inboxCollabInviteAcceptError => 'Tidak bisa menerima. Coba lagi.';

  @override
  String get inboxCollabInviteSentStatus => 'Undangan terkirim';

  @override
  String get inboxConversationCollabInvitePreview => 'Undangan kolaborasi';

  @override
  String collaboratorInviteDmBody(String title, String url) {
    return 'Kamu diundang untuk berkolaborasi di $title: $url\n\nOpen diVine to review and accept.';
  }

  @override
  String collaboratorInviteDmBodyUntitled(String url) {
    return 'Kamu diundang untuk berkolaborasi pada sebuah video: $url\n\nOpen diVine to review and accept.';
  }

  @override
  String videoPublishCollaboratorInviteWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count collaborator invites did not send.',
      one: '1 collaborator invite did not send.',
    );
    return 'Video posted, but $_temp0';
  }

  @override
  String get dmSendFailedMessage => 'Pesan gagal dikirim';

  @override
  String get dmSendFailedRetry => 'Coba Lagi';

  @override
  String get dmSendPartialMessage =>
      'Terkirim, tapi tidak tersinkron ke perangkat lainmu';

  @override
  String get dmConversationLoadError => 'Pesan tidak dapat dimuat';

  @override
  String get dmMessageInputHint => 'Say something…';

  @override
  String get dmMessageBubbleSentHint => 'Sent message';

  @override
  String get dmMessageBubbleReceivedHint => 'Received message';

  @override
  String get dmMessageBubbleLongPressHint => 'Message actions';

  @override
  String get dmMessageActionCopyText => 'Copy text';

  @override
  String get dmMessageActionCopyVideoUrl => 'Copy video URL';

  @override
  String get dmMessageActionDeleteForEveryone => 'Delete for everyone';

  @override
  String get dmMessageActionReport => 'Report';

  @override
  String get dmReactionAddCustomA11yLabel => 'Add custom emoji reaction';

  @override
  String dmReelReplyComposerHint(String name) {
    return 'Kirim pesan ke $name…';
  }

  @override
  String get dmReelReplyComposerHintSelf => 'Balas diri sendiri…';

  @override
  String get dmReelReplyComposerSemanticLabel => 'Balas reel ini';

  @override
  String get dmReelReplyViewChat => 'Lihat obrolan';

  @override
  String get dmReelReplyViewChatA11yLabel => 'Buka obrolan';

  @override
  String get dmReelReplySentAnnouncement => 'Balasan terkirim';

  @override
  String dmReelReactionSentAnnouncement(String emoji) {
    return 'Bereaksi $emoji';
  }

  @override
  String get dmReelReplyFailed => 'Tidak dapat mengirim';

  @override
  String dmReactionChipOwnA11yLabel(String emoji) {
    return 'Your reaction: $emoji';
  }

  @override
  String dmReactionChipOtherA11yLabel(String name, String emoji) {
    return '$name reacted with $emoji';
  }

  @override
  String dmReactionChipPendingA11yLabel(String emoji) {
    return 'Sending reaction: $emoji';
  }

  @override
  String get dmReactionChipFailedA11yLabel =>
      'Reaction failed, double tap to retry';

  @override
  String get dmReactionChipRetryAnnouncement => 'Retrying reaction';

  @override
  String get dmReactionsSheetTitle => 'Reaksi';

  @override
  String get dmReactionsViewA11yLabel => 'Lihat siapa yang bereaksi';

  @override
  String get dmReactionRemoveAction => 'Hapus';

  @override
  String get dmReactionRetryAction => 'Coba lagi';

  @override
  String get dmFormatBold => 'Tebal';

  @override
  String get dmFormatItalic => 'Miring';

  @override
  String get dmFormatStrikethrough => 'Coret';

  @override
  String get dmFormatCode => 'Kode';

  @override
  String get dmStatusPending => 'Mengirim';

  @override
  String get dmStatusFailed => 'Gagal mengirim';

  @override
  String get dmStatusDeliveredSelfFailed =>
      'Terkirim. Tidak akan tersinkron ke perangkat lainmu.';

  @override
  String get inboxConversationActionsSheetLabel => 'Conversation actions';

  @override
  String inboxConversationTileLabel(String displayName) {
    return '$displayName conversation';
  }

  @override
  String get inboxConversationTileLongPressHint => 'Show conversation actions';

  @override
  String get reportDialogCancel => 'Batal';

  @override
  String get reportDialogReport => 'Laporkan';

  @override
  String exploreVideoId(String id) {
    return 'ID: $id';
  }

  @override
  String exploreVideoTitle(String title) {
    return 'Judul: $title';
  }

  @override
  String exploreVideoCounter(int current, int total) {
    return 'Video $current/$total';
  }

  @override
  String get exploreSearchHint => 'Cari...';

  @override
  String categoryVideoCount(String count) {
    return '$count video';
  }

  @override
  String discoverListsFailedToUpdateSubscription(String error) {
    return 'Gagal memperbarui langganan: $error';
  }

  @override
  String get discoverListsTitle => 'Jelajahi Daftar';

  @override
  String get discoverListsFailedToLoad => 'Gagal memuat daftar';

  @override
  String discoverListsFailedToLoadWithError(String error) {
    return 'Gagal memuat daftar: $error';
  }

  @override
  String get discoverListsLoading => 'Mencari daftar publik...';

  @override
  String get discoverListsEmptyTitle => 'Tidak ada daftar publik';

  @override
  String get discoverListsEmptySubtitle => 'Cek lagi nanti untuk daftar baru';

  @override
  String get discoverListsByAuthorPrefix => 'oleh';

  @override
  String get curatedListEmptyTitle => 'Belum ada video di daftar ini';

  @override
  String get curatedListEmptySubtitle =>
      'Tambahkan beberapa video untuk memulai';

  @override
  String get curatedListLoadingVideos => 'Memuat video...';

  @override
  String get curatedListFailedToLoad => 'Gagal memuat daftar';

  @override
  String get curatedListNoVideosAvailable => 'Tidak ada video tersedia';

  @override
  String get curatedListVideoNotAvailable => 'Video tidak tersedia';

  @override
  String get curatedListActionsTooltip => 'List actions';

  @override
  String get curatedListUnfollowAction => 'Unfollow list';

  @override
  String get curatedListUnfollowedSnack => 'Unfollowed list';

  @override
  String get curatedListUnfollowFailed => 'Couldn\'t unfollow list';

  @override
  String get curatedListDeleteConfirmTitle => 'Delete list?';

  @override
  String get curatedListDeleteConfirmBody =>
      'This removes the list from relays. Videos in the list will not be deleted.';

  @override
  String get curatedListDeletedSnack => 'Deleted list';

  @override
  String get curatedListDeleteFailed => 'Couldn\'t delete list';

  @override
  String get peopleListsActionsTooltip => 'List actions';

  @override
  String get listDeleteAction => 'Delete list';

  @override
  String get peopleListsDeleteConfirmTitle => 'Delete list?';

  @override
  String get peopleListsDeleteConfirmBody =>
      'This removes the list for everyone. The people in it will not be unfollowed.';

  @override
  String get peopleListsDeleteFailed => 'Couldn\'t delete list';

  @override
  String get commonRetry => 'Coba lagi';

  @override
  String get commonSomethingWentWrong => 'Terjadi kesalahan';

  @override
  String get commonNext => 'Berikutnya';

  @override
  String get commonDelete => 'Hapus';

  @override
  String get commonCancel => 'Batal';

  @override
  String get commonBack => 'Kembali';

  @override
  String get commonClose => 'Tutup';

  @override
  String get videoMetadataEditCoverFailedSnackbar =>
      'Tidak dapat memperbarui sampul. Coba lagi.';

  @override
  String get videoMetadataEditCoverSuccessAnnouncement => 'Sampul diperbarui';

  @override
  String get videoMetadataTags => 'Tag';

  @override
  String get videoMetadataExpiration => 'Kedaluwarsa';

  @override
  String get videoMetadataExpirationNotExpire => 'Tidak kedaluwarsa';

  @override
  String get videoMetadataExpirationOneDay => '1 hari';

  @override
  String get videoMetadataExpirationOneWeek => '1 minggu';

  @override
  String get videoMetadataExpirationOneMonth => '1 bulan';

  @override
  String get videoMetadataExpirationOneYear => '1 tahun';

  @override
  String get videoMetadataExpirationOneDecade => '1 dekade';

  @override
  String get videoMetadataContentWarnings => 'Peringatan Konten';

  @override
  String get videoEditorStickers => 'Stiker';

  @override
  String get trendingTitle => 'Trending';

  @override
  String get libraryDeleteConfirm => 'Hapus';

  @override
  String get libraryWebUnavailableHeadline =>
      'Perpustakaan ada di aplikasi seluler';

  @override
  String get libraryWebUnavailableDescription =>
      'Draf dan klip disimpan di perangkatmu — buka Divine di ponsel untuk mengelolanya.';

  @override
  String get libraryTabDrafts => 'Draf';

  @override
  String get libraryTabClips => 'Klip';

  @override
  String get librarySaveToCameraRollTooltip => 'Simpan ke galeri kamera';

  @override
  String get libraryDeleteSelectedClipsTooltip => 'Hapus klip terpilih';

  @override
  String get librarySelect => 'Pilih';

  @override
  String get librarySortNewestCreation => 'Paling baru dibuat';

  @override
  String get librarySortOldestCreation => 'Paling lama dibuat';

  @override
  String get librarySortLongestClip => 'Klip terpanjang';

  @override
  String get librarySortShortestClip => 'Klip terpendek';

  @override
  String get librarySortSquareFirst => 'Persegi terlebih dahulu';

  @override
  String get librarySortVerticalFirst => 'Vertikal terlebih dahulu';

  @override
  String get libraryDeleteClipsTitle => 'Hapus klip';

  @override
  String libraryDeleteClipsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# klip terpilih',
      one: '# klip terpilih',
    );
    return 'Yakin ingin menghapus $_temp0?';
  }

  @override
  String get libraryDeleteClipsWarning =>
      'Tindakan ini tidak bisa dibatalkan. File video akan dihapus permanen dari perangkatmu.';

  @override
  String get libraryPreparingVideo => 'Menyiapkan video...';

  @override
  String get libraryCreateVideo => 'Buat video';

  @override
  String libraryClipsSavedToDestination(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klip',
      one: '1 klip',
    );
    return '$_temp0 disimpan ke $destination';
  }

  @override
  String libraryClipsSavePartialResult(int successCount, int failureCount) {
    return '$successCount tersimpan, $failureCount gagal';
  }

  @override
  String libraryGalleryPermissionDenied(String destination) {
    return 'Izin ditolak untuk $destination';
  }

  @override
  String libraryClipsDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klip dihapus',
      one: '1 klip dihapus',
    );
    return '$_temp0';
  }

  @override
  String get libraryClipsDeletedUndoLabel => 'Urungkan';

  @override
  String libraryTrashAutoDeletes(int daysLeft) {
    String _temp0 = intl.Intl.pluralLogic(
      daysLeft,
      locale: localeName,
      other: 'Akan dihapus otomatis dalam $daysLeft hari',
      one: 'Akan dihapus otomatis besok',
      zero: 'Akan dihapus otomatis hari ini',
    );
    return '$_temp0';
  }

  @override
  String get libraryCouldNotLoadDrafts => 'Tidak bisa memuat draf';

  @override
  String get libraryCouldNotLoadClips => 'Tidak bisa memuat klip';

  @override
  String get libraryOpenErrorDescription =>
      'Ada masalah saat membuka perpustakaan. Coba lagi.';

  @override
  String get libraryNoDraftsYetTitle => 'Belum ada draf';

  @override
  String get libraryNoDraftsYetSubtitle =>
      'Video yang kamu simpan sebagai draf akan muncul di sini';

  @override
  String get libraryNoClipsYetTitle => 'Belum ada klip';

  @override
  String get libraryNoClipsYetSubtitle =>
      'Klip video yang kamu rekam akan muncul di sini';

  @override
  String get libraryDraftDeletedSnackbar => 'Draf dihapus';

  @override
  String get libraryDraftDeleteFailedSnackbar => 'Gagal menghapus draf';

  @override
  String get libraryDraftActionPost => 'Posting';

  @override
  String get libraryDraftActionEdit => 'Edit';

  @override
  String get libraryDraftActionDelete => 'Hapus draf';

  @override
  String get libraryDeleteDraftTitle => 'Hapus draf';

  @override
  String libraryDeleteDraftMessage(String title) {
    return 'Yakin ingin menghapus \"$title\"?';
  }

  @override
  String get libraryDeleteClipTitle => 'Hapus klip';

  @override
  String get libraryDeleteClipMessage => 'Yakin ingin menghapus klip ini?';

  @override
  String get libraryClipSelectionTitle => 'Klip';

  @override
  String librarySecondsRemaining(String seconds) {
    return 'Tersisa $seconds dtk';
  }

  @override
  String get libraryAddClips => 'Tambah';

  @override
  String get libraryRecordVideo => 'Rekam video';

  @override
  String videoClipSemanticLabel(String duration) {
    return 'Klip video, $duration detik';
  }

  @override
  String get videoClipSemanticValueSelected => 'Dipilih';

  @override
  String get videoClipSemanticValueNotSelected => 'Tidak dipilih';

  @override
  String get videoClipSemanticHintDisabled => 'Dinonaktifkan';

  @override
  String get videoClipSemanticHintSelect =>
      'Ketuk untuk memilih, tekan lama untuk pratinjau';

  @override
  String get videoClipSemanticHintDeselect =>
      'Ketuk untuk membatalkan pilihan, tekan lama untuk pratinjau';

  @override
  String get routerInvalidCreator => 'Kreator tidak valid';

  @override
  String get routerInvalidHashtagRoute => 'Rute hashtag tidak valid';

  @override
  String get categoryGalleryCouldNotLoadVideos => 'Tidak dapat memuat video';

  @override
  String get categoryGalleryNoVideosInCategory =>
      'Tidak ada video di kategori ini';

  @override
  String get categoryGallerySortOptionsLabel => 'Opsi urutan kategori';

  @override
  String get categoryGallerySortHot => 'Populer';

  @override
  String get categoryGallerySortNew => 'Baru';

  @override
  String get categoryGallerySortClassic => 'Klasik';

  @override
  String get categoryGallerySortForYou => 'Untukmu';

  @override
  String get categoriesCouldNotLoadCategories => 'Tidak dapat memuat kategori';

  @override
  String get categoriesNoCategoriesAvailable => 'Tidak ada kategori tersedia';

  @override
  String get notificationsEmptyTitle => 'Belum ada aktivitas';

  @override
  String get notificationsEmptySubtitle =>
      'Saat orang berinteraksi dengan kontenmu, kamu akan melihatnya di sini';

  @override
  String get appsPermissionsTitle => 'Izin Integrasi';

  @override
  String get appsPermissionsRevoke => 'Cabut';

  @override
  String get appsPermissionsEmptyTitle => 'Tidak ada izin integrasi tersimpan';

  @override
  String get appsPermissionsEmptySubtitle =>
      'Integrasi yang disetujui akan muncul di sini setelah kamu mengingat persetujuan akses.';

  @override
  String nostrAppPermissionTitle(String appName) {
    return '$appName meminta persetujuanmu';
  }

  @override
  String get nostrAppPermissionDescription =>
      'Aplikasi ini meminta akses lewat sandbox tervalidasi Divine.';

  @override
  String get nostrAppPermissionOrigin => 'Asal';

  @override
  String get nostrAppPermissionMethod => 'Metode';

  @override
  String get nostrAppPermissionCapability => 'Kapabilitas';

  @override
  String get nostrAppPermissionEventKind => 'Jenis event';

  @override
  String get nostrAppPermissionAllow => 'Izinkan';

  @override
  String get appsDetailDefaultTitle => 'Integrated App';

  @override
  String get appsDetailNotFoundTitle => 'Integration not found';

  @override
  String get appsDetailNotFoundSubtitle =>
      'This approved integration is no longer available in Divine.';

  @override
  String get appsDetailHowItWorksTitle => 'How it works';

  @override
  String get appsDetailHowItWorksBody =>
      'This is an approved third-party app that runs inside Divine. Divine only grants reviewed capabilities for this integration, and blocks navigation outside its approved origins.';

  @override
  String get appsDetailAboutTitle => 'About';

  @override
  String get appsDetailPrimaryOriginTitle => 'Primary origin';

  @override
  String get appsDetailApprovedOriginsTitle => 'Approved origins';

  @override
  String get appsDetailCapabilitiesTitle => 'Available capabilities';

  @override
  String get appsDetailAskBeforeTitle => 'Ask before';

  @override
  String get appsDetailOpenButton => 'Open Integration';

  @override
  String get appsDetailNoneDeclared => 'None declared yet';

  @override
  String get appsDirectoryTitle => 'Integrated Apps';

  @override
  String get appsDirectoryIntroTitle => 'Approved third-party apps';

  @override
  String get appsDirectoryIntroBody =>
      'Approved third-party apps that run inside Divine';

  @override
  String get appsDirectoryErrorTitle => 'Could not load integrated apps';

  @override
  String get appsDirectoryErrorSubtitle =>
      'Pull to try the approved integrations again.';

  @override
  String get appsDirectoryEmptyTitle => 'No approved integrations yet';

  @override
  String get appsDirectoryEmptySubtitle =>
      'Approved third-party apps will appear here as Divine adds them.';

  @override
  String get appsDirectoryRefresh => 'Refresh';

  @override
  String get appsDirectoryUnsupportedTitle =>
      'Integrated Apps run in Divine mobile';

  @override
  String get appsDirectoryUnsupportedSubtitle =>
      'Approved integrations are only available on mobile for now.';

  @override
  String get appsSandboxUnavailableTitle => 'Integration unavailable';

  @override
  String get appsSandboxUnavailableBody =>
      'Open approved integrations from the Integrated Apps tab so Divine can apply the right access policy.';

  @override
  String get appsSandboxLoadingTitle => 'Loading integration';

  @override
  String get appsSandboxLoadingSubtitle =>
      'Checking the approved integration before launch.';

  @override
  String get appsSandboxBlockedTitle => 'Blocked for safety';

  @override
  String appsSandboxBlockedSubtitle(String uri) {
    return 'This integration tried to leave its approved origin.\n\n$uri';
  }

  @override
  String get shareCopiedPostLink => 'Link to post copied to clipboard';

  @override
  String get shareCopiedEventJson => 'Nostr event JSON copied to clipboard';

  @override
  String get shareCopiedEventId => 'Nostr event ID copied to clipboard';

  @override
  String get authHeroTaglineAuthentic => 'Authentic moments.';

  @override
  String get authHeroTaglineHuman => 'Human creativity.';

  @override
  String get keyImportFailedToImport =>
      'Failed to import key or connect bunker';

  @override
  String get keyImportInvalidBunkerUrl => 'Invalid bunker URL';

  @override
  String get keyImportInvalidFormat =>
      'Invalid format. Use nsec..., hex, ncryptsec1..., or bunker://...';

  @override
  String get keyImportInvalidNsecFormat =>
      'Invalid nsec format. Should be 63 characters';

  @override
  String get keyImportKeyFieldLabel => 'Private key or bunker URL';

  @override
  String get keyImportKeyRequired =>
      'Please enter your private key or bunker URL';

  @override
  String get keyImportPasswordRequired =>
      'Please enter the password for this encrypted key';

  @override
  String get keyImportSecurityWarningBody =>
      'Never share your private key with anyone. This key gives full access to your Nostr identity.';

  @override
  String get keyImportSecurityWarningTitle => 'Keep your private key secure!';

  @override
  String get keyImportSubtitle =>
      'Import your existing Nostr identity using your private key or a bunker URL.';

  @override
  String get keyImportTitle => 'Import your\nNostr identity';

  @override
  String get commentAuthorYouIndicator => 'You';

  @override
  String commentAuthorAvatarSemanticLabel(String name) {
    return 'Lihat profil $name';
  }

  @override
  String get commentOptionsDeleteSemanticLabel => 'Delete comment';

  @override
  String get commentOptionsEditSemanticLabel => 'Edit comment';

  @override
  String get commentOptionsFlagContentLabel => 'Flag Content';

  @override
  String get commentOptionsFlagContentSemanticLabel => 'Flag this content';

  @override
  String get commentOptionsFlagReasonPrompt =>
      'Select a reason for flagging this comment';

  @override
  String get commentOptionsFlagSubmit => 'Submit';

  @override
  String get commentOptionsTitle => 'Options';

  @override
  String get commentsEmptyClassicVineMessage =>
      'We\'re still working on importing old comments from the archive. They\'re not ready yet.';

  @override
  String get commentsEmptyClassicVineTitle => 'Classic Vine';

  @override
  String get commentsInputEditingLabel => 'Editing';

  @override
  String get commentsInputSemanticHint => 'Add a comment';

  @override
  String get commentsInputSemanticHintEdit => 'Edit comment';

  @override
  String get commentsInputSemanticHintReply => 'Add a reply';

  @override
  String get commentsInputSemanticLabel => 'Comment input';

  @override
  String get commentsInputSemanticLabelEdit => 'Edit input';

  @override
  String get commentsInputSemanticLabelReply => 'Reply input';

  @override
  String classicVinersViewProfileSemanticLabel(String displayName) {
    return 'View profile for $displayName';
  }

  @override
  String get classicsEmptyDescription => 'The Classics archive is being loaded';

  @override
  String get classicsEmptyTitle => 'No Classics Found';

  @override
  String get classicsErrorTitle => 'Failed to load Classics';

  @override
  String get classicsUnavailableDescription =>
      'Classics are only available when connected to Funnelcake relays.';

  @override
  String get classicsUnavailableSettingsHint =>
      'Switch to a Funnelcake-enabled relay in Settings to access the Classics archive.';

  @override
  String get classicsUnavailableTitle => 'Classics Unavailable';

  @override
  String get hashtagFeedEmptySubtitle =>
      'Be the first to post a video with this hashtag!';

  @override
  String hashtagFeedEmptyTitle(String hashtag) {
    return 'No videos found for #$hashtag';
  }

  @override
  String get hashtagFeedLoadingSubtitle => 'This may take a few moments';

  @override
  String hashtagFeedLoadingTitle(String hashtag) {
    return 'Loading videos about #$hashtag...';
  }

  @override
  String get hashtagInputHint => 'Add hashtags... #vine #nostr';

  @override
  String get newVideosTabEmptySubtitle => 'Check back later for new content';

  @override
  String get newVideosTabEmptyTitle => 'No videos in New Videos';

  @override
  String get popularVideosContextTitle => 'Popular Videos';

  @override
  String get popularVideosEmptySubtitle => 'Check back later for new content';

  @override
  String get popularVideosEmptyTitle => 'No videos in Popular Videos';

  @override
  String get popularVideosErrorTitle => 'Failed to load trending videos';

  @override
  String get popularVideosFeedSourceLabel => 'Popular feed source';

  @override
  String get trendingHashtagsLoading => 'Loading hashtags...';

  @override
  String trendingHashtagsViewVideosTagged(String hashtag) {
    return 'View videos tagged $hashtag';
  }

  @override
  String videoGridAuthorSemanticLabel(String name) {
    return 'Video author: $name';
  }

  @override
  String videoGridDescriptionSemanticLabel(String description) {
    return 'Video description: $description';
  }

  @override
  String get forYouAlgorithmChoiceBody =>
      'Divine\'s vision is to give you true algorithmic choice. Instead of being locked into a single black-box algorithm, you\'ll be able to choose from multiple recommendation approaches:';

  @override
  String get forYouAlgorithmChoiceChronological =>
      'Chronological timeline from creators you follow';

  @override
  String get forYouAlgorithmChoiceClosing =>
      'This puts you in control of your attention rather than leaving it up to the platform. You should know how your feed is curated and have the power to change it whenever you want.';

  @override
  String get forYouAlgorithmChoiceCustomFeeds =>
      'Community-created custom feeds for topics like music, comedy, or art';

  @override
  String get forYouAlgorithmChoicePersonalizedFeed =>
      'Personalized \"For You\" feed';

  @override
  String get forYouAlgorithmChoiceTitle => 'Your Algorithm, Your Choice';

  @override
  String get forYouAlgorithmChoiceTrending => 'Trending and popular content';

  @override
  String get forYouAlgorithmCommentsDescription =>
      'Strong signal — you were engaged enough to respond';

  @override
  String get forYouAlgorithmHowItWorksBody =>
      'Divine pays attention to how you interact with content to understand what you enjoy. Every time you watch a video, give it a reaction, leave a comment, or repost it, the system takes note.';

  @override
  String get forYouAlgorithmHowItWorksTitle => 'How It Works';

  @override
  String get forYouAlgorithmInteractionsIntro =>
      'Different actions signal different levels of interest:';

  @override
  String get forYouAlgorithmNewToDivineBody1 =>
      'If you haven\'t built up a viewing history yet, we show a mix of what\'s currently popular and trending alongside recent uploads. This gives you a great starting point to explore.';

  @override
  String get forYouAlgorithmNewToDivineBody2 =>
      'As you watch, like, and engage with content, recommendations gradually become more personalized. Over time, your For You feed surfaces videos from creators you might never have discovered on your own.';

  @override
  String get forYouAlgorithmNewToDivineTitle => 'New to Divine?';

  @override
  String get forYouAlgorithmOpenSourceBody =>
      'We\'re building an open system where developers can implement their own algorithms, and you can choose which ones to use — or opt out entirely.';

  @override
  String get forYouAlgorithmOpenSourceTitle => 'Open Source & Transparent';

  @override
  String get forYouAlgorithmReactionsDescription =>
      'Medium signal — a quick way to show appreciation';

  @override
  String get forYouAlgorithmReactionsTitle => 'Reactions';

  @override
  String get forYouAlgorithmRepostsDescription =>
      'Strongest signal — sharing with your followers is a powerful endorsement';

  @override
  String get forYouAlgorithmSubtitle =>
      'Powered by Gorse, an open-source recommendation engine';

  @override
  String get forYouAlgorithmTitle => 'The Divine Algorithm';

  @override
  String get forYouAlgorithmViewsDescription =>
      'Light signal — indicates basic interest';

  @override
  String get forYouEmptyDescription =>
      'Watch and like some videos to get personalized recommendations.';

  @override
  String get forYouEmptyTitle => 'No Recommendations Yet';

  @override
  String get forYouErrorTitle => 'Failed to load recommendations';

  @override
  String get forYouUnavailableDescription =>
      'Personalized recommendations require connection to Funnelcake.';

  @override
  String get forYouUnavailableTitle => 'For You Unavailable';

  @override
  String get inboxConversationOptionsLabel => 'Options';

  @override
  String get inboxConversationViewProfileButton => 'View profile';

  @override
  String get inboxMessageRequestsEmpty => 'No message requests';

  @override
  String inboxMessageRequestsSemanticLabel(int requestCount) {
    return 'Message requests, $requestCount pending';
  }

  @override
  String get inboxMessageRequestsTitle => 'Message requests';

  @override
  String get inboxMessagesTab => 'Messages';

  @override
  String inboxRequestTileLabel(String displayName) {
    return '$displayName message request';
  }

  @override
  String get inboxRequestTileSubtitle => 'Sent a message request';

  @override
  String get inboxRequestsMarkAllRead => 'Mark all requests as read';

  @override
  String get inboxRequestsRemoveAll => 'Remove all requests';

  @override
  String get messageRequestDeclineAndRemoveButton => 'Decline and remove';

  @override
  String messageRequestFollowersCount(String count) {
    return '$count Followers';
  }

  @override
  String messageRequestVideosCount(String count) {
    return '$count videos';
  }

  @override
  String messageRequestMessageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages',
      one: '1 message',
    );
    return '$_temp0';
  }

  @override
  String get messageRequestViewMessagesButton => 'View messages';

  @override
  String get messageRequestViewProfileButton => 'View profile';

  @override
  String messageRequestWantsToMessageYou(
    String displayName,
    String messageText,
  ) {
    return '$displayName wants to message you, they\'ve sent $messageText.';
  }

  @override
  String get deleteAccountConfirmationHint => 'Type DELETE';

  @override
  String get deleteAccountContentDeletionFailed =>
      'Failed to delete content from relays';

  @override
  String get deleteAccountDeleteAllContentButton => 'Delete All Content';

  @override
  String get deleteAccountFinalConfirmationBody =>
      'To confirm permanent deletion of ALL your content from Nostr relays, type:';

  @override
  String get deleteAccountFinalConfirmationTitle => '⚠️ Final Confirmation';

  @override
  String get deleteAccountKeyDeletionWarning =>
      'Account deleted, but your keys may not have been fully removed from this device. Go to Settings → Nostr Keys → Remove Keys to retry.';

  @override
  String get deleteAccountLocalDataDeletionFailed =>
      'Account deleted and signed out, but some local data could not be removed from this device.';

  @override
  String get deleteAccountPreparingDeletion => 'Preparing deletion...';

  @override
  String deleteAccountProgressEvents(int current, int total) {
    return '$current / $total events';
  }

  @override
  String get deleteAccountRemoveKeysBody =>
      'This removes the local login for this account from this device. It won\'t delete your Divine account or Nostr identity.\n\nYour drafts and clips stay saved on this device for this account. If this is your last local account, you\'ll return to the login screen.';

  @override
  String get deleteAccountRemoveKeysConfirm => 'Remove from device';

  @override
  String get deleteAccountRemoveKeysTitle =>
      'Remove this account from this device?';

  @override
  String get deleteAccountServerDeletionFailed =>
      'Could not delete your account from the server. Please check your connection and try again.';

  @override
  String get deleteAccountSuccess => 'Your account has been deleted';

  @override
  String get exportProgressStageApplyingTextOverlay => 'Adding text overlay...';

  @override
  String get exportProgressStageComplete => 'Export complete!';

  @override
  String get exportProgressStageConcatenating => 'Combining clips...';

  @override
  String get exportProgressStageError => 'Export failed';

  @override
  String get exportProgressStageGeneratingThumbnail =>
      'Generating thumbnail...';

  @override
  String get exportProgressStageMixingAudio => 'Adding sound...';

  @override
  String get findPeopleAnonymousUser => 'Anonymous';

  @override
  String get findPeopleNoContacts =>
      'No contacts found.\nStart following people to see them here.';

  @override
  String get geoBlockedCityLabel => 'City';

  @override
  String get geoBlockedCountryLabel => 'Country';

  @override
  String get geoBlockedDefaultReason =>
      'This service is not available in your region due to local regulations.';

  @override
  String get geoBlockedLegalNotice =>
      'We respect your local laws and regulations. This restriction is based on your IP address location.';

  @override
  String get geoBlockedRegionLabel => 'Region';

  @override
  String get geoBlockedTitle => 'Service Unavailable';

  @override
  String get likedVideosEmpty => 'No liked videos';

  @override
  String get likedVideosInvalidRoute => 'Invalid route';

  @override
  String get likedVideosTitle => 'Liked Videos';

  @override
  String get ogVinerBadgeSemanticLabel => 'OG Viner';

  @override
  String get uploadFailureSheetRetryingSnackbar => 'Retrying upload…';

  @override
  String get uploadFailureSheetSaveToDraftsButton => 'Save to Drafts';

  @override
  String get uploadFailureSheetSavedToDraftsSnackbar => 'Saved to drafts';

  @override
  String get uploadFailureSheetTitle => 'Upload Failed';

  @override
  String get uploadFailureSheetTryAgainButton => 'Try Again';

  @override
  String get videoEditorAudioImportAudio => 'Import audio';

  @override
  String get videoEditorAudioImportFailed => 'Audio import failed.';

  @override
  String get videoIconPlaceholderLabel => 'Video';

  @override
  String videoInspiredByAttributionSemanticLabel(String creatorName) {
    return 'Inspired by $creatorName. Tap to view their profile.';
  }

  @override
  String get proofmodeBadgeAiScanPending => 'AI scan pending';

  @override
  String get proofmodeBadgeHumanMade => 'Human Made';

  @override
  String get proofmodeBadgeNotDivineHosted => 'Not Divine Hosted';

  @override
  String get proofmodeBadgeOriginal => 'Original';

  @override
  String get proofmodeBadgePossiblyAiGenerated => 'Possibly AI-Generated';

  @override
  String get proofmodeBadgeUnverified => 'Unverified';

  @override
  String get proofmodeConfirmedByModerator => 'Confirmed by human moderator';

  @override
  String get proofmodeExternalContentTitle => 'External Content';

  @override
  String get proofmodeHostedOnLabel => 'This video is hosted on:';

  @override
  String get proofmodeLikelyHumanCreated => 'Likely human-created';

  @override
  String get proofmodeNoProofDataAttached => 'No ProofMode data attached';

  @override
  String get proofmodeNotDivineHostedDisclaimer =>
      'This content is not hosted on Divine servers. We cannot fully guarantee its authenticity.';

  @override
  String get proofmodePossiblyAiGenerated => 'Possibly AI-generated';

  @override
  String get proofmodePublishedByLabel => 'Published by:';

  @override
  String get publishErrorNotSignedIn =>
      'Silakan masuk untuk mempublikasikan video.';

  @override
  String get publishErrorNoRetry => 'Tidak ada unggahan untuk dicoba ulang.';

  @override
  String get publishErrorNoInternet =>
      'Tidak ada koneksi internet. Periksa Wi-Fi atau data selulermu dan coba lagi.';

  @override
  String get publishErrorServerUnreachable =>
      'Tidak dapat menjangkau server. Silakan coba lagi sebentar lagi.';

  @override
  String get publishErrorTimeout =>
      'Waktu unggah habis. Coba pakai koneksi yang lebih kuat atau video yang lebih kecil.';

  @override
  String get publishErrorTls =>
      'Koneksi aman gagal. Periksa jaringanmu—Wi-Fi publik bisa memblokir unggahan.';

  @override
  String publishErrorServerNotFound(String serverName) {
    return 'Server media ($serverName) tidak tersedia. Kamu bisa memilih yang lain di pengaturan.';
  }

  @override
  String get publishErrorFileTooLarge =>
      'File video terlalu besar untuk server. Coba pangkas videonya atau turunkan kualitasnya.';

  @override
  String publishErrorServerInternalError(String serverName) {
    return 'Server media ($serverName) mengalami kesalahan internal. Kamu bisa memilih yang lain di pengaturan.';
  }

  @override
  String publishErrorServerDown(String serverName) {
    return 'Server media ($serverName) sedang tidak aktif sementara. Coba lagi sebentar lagi atau pilih yang lain di pengaturan.';
  }

  @override
  String get publishErrorForbidden =>
      'Kamu tidak punya izin untuk mengunggah ke server ini.';

  @override
  String get publishErrorFileNotFound =>
      'File video tidak ditemukan. Mungkin sudah terhapus. Rekam ulang lalu coba lagi.';

  @override
  String get publishErrorLowStorage =>
      'Penyimpanan di perangkatmu tidak cukup. Kosongkan sedikit ruang lalu coba lagi.';

  @override
  String get publishErrorThumbnailFailed =>
      'Video berhasil diunggah, tapi thumbnail tidak bisa disiapkan. Silakan coba lagi.';

  @override
  String get publishErrorNostrPublishFailed =>
      'Video berhasil diunggah, tapi posting tidak bisa dipublikasikan. Periksa pengaturan relay-mu dan coba lagi.';

  @override
  String get publishErrorInterrupted =>
      'Unggahan ini terganggu. Mau coba lagi?';

  @override
  String get publishErrorGeneric => 'Terjadi kesalahan. Silakan coba lagi.';

  @override
  String get publishErrorRateLimited =>
      'Terlalu banyak unggahan saat ini. Tunggu sebentar lalu coba lagi.';

  @override
  String get publishErrorUploadSessionExpired =>
      'Sesi unggahanmu sudah berakhir. Silakan coba lagi.';

  @override
  String get publishErrorPermissionDenied =>
      'Divine tidak punya izin untuk mengunggah. Periksa izin aplikasi di pengaturanmu dan coba lagi.';

  @override
  String get publishErrorOutOfMemory =>
      'Memori perangkatmu menipis. Tutup beberapa aplikasi lalu coba lagi.';

  @override
  String get publishErrorUnknownServer => 'Server tidak dikenal';

  @override
  String searchFilterPillSemanticLabel(String filter) {
    return 'Filter: $filter';
  }

  @override
  String searchNoResultsFound(String query) {
    return 'No results found for \"$query\"';
  }

  @override
  String searchTagChipViewVideosTaggedLabel(String tag) {
    return 'View videos tagged $tag';
  }

  @override
  String audioAttributionRowSemanticLabel(
    String soundName,
    String creatorName,
  ) {
    return 'Sound: $soundName by $creatorName. Tap to view sound details.';
  }

  @override
  String metadataSoundsOriginalSoundSemantics(String creatorName) {
    return 'Original sound by $creatorName. Tap to use this sound.';
  }

  @override
  String metadataSoundsSharedSoundSemantics(
    String soundName,
    String creatorName,
  ) {
    return 'Sound: $soundName by $creatorName. Tap to view details.';
  }

  @override
  String soundDetailLoadError(String error) {
    return 'Failed to load sound: $error';
  }

  @override
  String get soundDetailNotFoundMessage => 'This sound could not be found';

  @override
  String get soundDetailNotFoundTitle => 'Sound Not Found';

  @override
  String get videoFeedDescriptionSemanticLabel => 'Video description';

  @override
  String videoFeedLoopCountLabel(int count) {
    return '🔁 $count loops';
  }

  @override
  String get videoFeedLoopCountSemanticLabel => 'Video loop count';

  @override
  String get originalSoundUnavailableBody =>
      'Audio from this video is not available separately.';

  @override
  String originalSoundByCreator(String creatorName) {
    return 'Original sound - $creatorName';
  }

  @override
  String globalUploadPendingCount(int count) {
    return 'Pending Uploads ($count)';
  }

  @override
  String get ogVinerBadgeLabel => 'OG Viner';

  @override
  String shareVideoInListsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'In $count lists',
      one: 'In 1 list',
    );
    return '$_temp0';
  }

  @override
  String get unfollowConfirmButton => 'Unfollow';

  @override
  String get videoClipSaveFailed => 'Failed to save clip';

  @override
  String videoClipSaveTo(String destination) {
    return 'Save to $destination';
  }

  @override
  String get videoClipDelete => 'Delete clip';

  @override
  String inspiredByAttributionSemanticLabel(String creatorName) {
    return 'Inspired by $creatorName. Tap to view their profile.';
  }

  @override
  String get bugReportSendReport => 'Kirim Laporan';

  @override
  String get supportSubjectRequiredLabel => 'Subjek *';

  @override
  String get supportRequiredHelper => 'Wajib';

  @override
  String get bugReportSubjectHint => 'Ringkasan singkat masalahnya';

  @override
  String get bugReportDescriptionRequiredLabel => 'Apa yang terjadi? *';

  @override
  String get bugReportDescriptionHint => 'Jelaskan masalah yang kamu temui';

  @override
  String get bugReportStepsLabel => 'Langkah Reproduksi';

  @override
  String get bugReportStepsHint => '1. Buka...\n2. Tap...\n3. Lihat error';

  @override
  String get bugReportExpectedBehaviorLabel => 'Perilaku yang Diharapkan';

  @override
  String get bugReportExpectedBehaviorHint => 'Apa yang seharusnya terjadi?';

  @override
  String get bugReportDiagnosticsNotice =>
      'Info perangkat dan log akan disertakan otomatis.';

  @override
  String get bugReportSuccessMessage =>
      'Terima kasih! Laporanmu sudah kami terima dan akan kami pakai untuk membuat Divine lebih baik.';

  @override
  String get bugReportAttachImages => 'Attach images';

  @override
  String bugReportImagesCount(int count, int max) {
    return '$count of $max images selected';
  }

  @override
  String get bugReportRemoveImage => 'Remove image';

  @override
  String get bugReportUploadFailed =>
      'We couldn\'t upload the selected image. Try again or send the report without it.';

  @override
  String get bugReportSendFailed =>
      'Gagal mengirim laporan bug. Coba lagi nanti.';

  @override
  String bugReportFailedWithError(String error) {
    return 'Laporan bug gagal terkirim: $error';
  }

  @override
  String get featureRequestSendRequest => 'Kirim Permintaan';

  @override
  String get featureRequestSubjectHint => 'Ringkasan singkat idemu';

  @override
  String get featureRequestDescriptionRequiredLabel =>
      'Apa yang kamu inginkan? *';

  @override
  String get featureRequestDescriptionHint => 'Jelaskan fitur yang kamu mau';

  @override
  String get featureRequestUsefulnessLabel => 'Bagaimana ini berguna?';

  @override
  String get featureRequestUsefulnessHint => 'Jelaskan manfaat dari fitur ini';

  @override
  String get featureRequestWhenLabel => 'Kapan kamu akan memakainya?';

  @override
  String get featureRequestWhenHint =>
      'Jelaskan situasi di mana ini akan membantu';

  @override
  String get featureRequestSuccessMessage =>
      'Terima kasih! Permintaan fiturmu sudah kami terima dan akan kami tinjau.';

  @override
  String get featureRequestSendFailed =>
      'Gagal mengirim permintaan fitur. Coba lagi nanti.';

  @override
  String featureRequestFailedWithError(String error) {
    return 'Permintaan fitur gagal terkirim: $error';
  }

  @override
  String get notificationFollowBack => 'Ikuti balik';

  @override
  String get followingTitle => 'Mengikuti';

  @override
  String followingTitleForName(String displayName) {
    return 'Yang Diikuti $displayName';
  }

  @override
  String get followingFailedToLoadList => 'Gagal memuat daftar mengikuti';

  @override
  String get followingEmptyTitle => 'Belum mengikuti siapa pun';

  @override
  String get followersTitle => 'Pengikut';

  @override
  String followersTitleForName(String displayName) {
    return 'Pengikut $displayName';
  }

  @override
  String get followersFailedToLoadList => 'Gagal memuat daftar pengikut';

  @override
  String get followersEmptyTitle => 'Belum ada pengikut';

  @override
  String get followersUpdateFollowFailed =>
      'Gagal memperbarui status follow. Coba lagi.';

  @override
  String get reportMessageTitle => 'Laporkan Pesan';

  @override
  String get reportMessageWhyReporting => 'Kenapa kamu melaporkan pesan ini?';

  @override
  String get reportMessageSelectReason =>
      'Silakan pilih alasan untuk melaporkan pesan ini';

  @override
  String get newMessageTitle => 'Pesan baru';

  @override
  String get newMessageFindPeople => 'Cari orang';

  @override
  String get newMessageNoContacts =>
      'Tidak ada kontak ditemukan.\nIkuti orang untuk melihat mereka di sini.';

  @override
  String get newMessageNoUsersFound => 'Pengguna tidak ditemukan';

  @override
  String get hashtagSearchTitle => 'Cari hashtag';

  @override
  String get hashtagSearchSubtitle => 'Temukan topik dan konten yang lagi tren';

  @override
  String hashtagSearchNoResults(String query) {
    return 'Tidak ada hashtag untuk \"$query\"';
  }

  @override
  String get hashtagSearchFailed => 'Pencarian gagal';

  @override
  String get userNotAvailableTitle => 'Akun tidak tersedia';

  @override
  String get userNotAvailableBody => 'Akun ini tidak tersedia saat ini.';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String blossomFailedToSaveSettings(String error) {
    return 'Gagal menyimpan pengaturan: $error';
  }

  @override
  String get blossomValidServerUrl =>
      'Masukkan URL server yang valid (contoh: https://blossom.band)';

  @override
  String get blossomSettingsSaved => 'Pengaturan Blossom tersimpan';

  @override
  String get blossomSaveTooltip => 'Simpan';

  @override
  String get blossomAboutTitle => 'Tentang Blossom';

  @override
  String get blossomAboutDescription =>
      'Blossom adalah protokol penyimpanan media terdesentralisasi yang memungkinkanmu mengunggah video ke server kompatibel mana pun. Secara default, video diunggah ke server Blossom Divine. Aktifkan opsi di bawah untuk memakai server kustom.';

  @override
  String get blossomUseCustomServer => 'Pakai Server Blossom Kustom';

  @override
  String get blossomCustomServerEnabledSubtitle =>
      'Video akan diunggah ke server Blossom kustommu';

  @override
  String get blossomCustomServerDisabledSubtitle =>
      'Video kamu saat ini diunggah ke server Blossom Divine';

  @override
  String get blossomCustomServerUrl => 'URL Server Blossom Kustom';

  @override
  String get blossomCustomServerHelper =>
      'Masukkan URL server Blossom kustommu';

  @override
  String get blossomPopularServers => 'Server Blossom Populer';

  @override
  String get blossomServerUrlMustUseHttps =>
      'URL server Blossom harus pakai https://';

  @override
  String get blueskyFailedToUpdateCrosspost =>
      'Gagal memperbarui pengaturan crosspost';

  @override
  String get blueskySignInRequired => 'Masuk untuk mengatur pengaturan Bluesky';

  @override
  String get blueskyPublishVideos => 'Publikasikan video ke Bluesky';

  @override
  String get blueskyEnabledSubtitle =>
      'Video kamu akan dipublikasikan ke Bluesky';

  @override
  String get blueskyDisabledSubtitle =>
      'Video kamu tidak akan dipublikasikan ke Bluesky';

  @override
  String get blueskyHandle => 'Handle Bluesky';

  @override
  String get blueskyStatus => 'Status';

  @override
  String get blueskyStatusReady => 'Akun sudah disiapkan dan siap';

  @override
  String get blueskyStatusPending => 'Penyiapan akun sedang berjalan...';

  @override
  String get blueskyStatusFailed => 'Penyiapan akun gagal';

  @override
  String get blueskyStatusDisabled => 'Akun dinonaktifkan';

  @override
  String get blueskyStatusNotLinked => 'Belum ada akun Bluesky terhubung';

  @override
  String get invitesTitle => 'Undang Teman';

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
  String get invitesNoneAvailable => 'Tidak ada undangan tersedia saat ini';

  @override
  String get invitesShareWithPeople =>
      'Bagikan diVine ke orang yang kamu kenal';

  @override
  String get invitesUsedInvites => 'Undangan terpakai';

  @override
  String invitesShareMessage(String code) {
    return 'Gabung dengan saya di diVine! Pakai kode undangan $code untuk mulai:\nhttps://divine.video/invite/$code';
  }

  @override
  String get invitesCopyInvite => 'Salin undangan';

  @override
  String get invitesCopied => 'Undangan tersalin!';

  @override
  String get invitesShareInvite => 'Bagikan undangan';

  @override
  String get invitesShareSubject => 'Gabung dengan saya di diVine';

  @override
  String get invitesClaimed => 'Sudah diklaim';

  @override
  String get invitesCouldNotLoad => 'Gagal memuat undangan';

  @override
  String get invitesRetry => 'Coba Lagi';

  @override
  String get searchSomethingWentWrong => 'Terjadi kesalahan';

  @override
  String get searchTryAgain => 'Coba lagi';

  @override
  String get searchForLists => 'Cari daftar';

  @override
  String get searchFindCuratedVideoLists => 'Temukan daftar video pilihan';

  @override
  String get searchEnterQuery => 'Masukkan kata pencarian';

  @override
  String get searchDiscoverSomethingInteresting =>
      'Temukan sesuatu yang menarik';

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
  String get searchVideosSortOptionsLabel => 'Sort video results';

  @override
  String get searchVideosSortTrending => 'Hot';

  @override
  String get searchVideosSortLoops => 'Most loops';

  @override
  String get searchVideosSortEngagement => 'Most engaged';

  @override
  String get searchVideosSortRecent => 'Recent';

  @override
  String get searchListsSectionHeader => 'Daftar';

  @override
  String get searchListsLoadingLabel => 'Memuat hasil daftar';

  @override
  String get cameraAgeRestriction =>
      'Kamu harus berusia 16 tahun atau lebih untuk membuat konten';

  @override
  String get featureRequestCancel => 'Batal';

  @override
  String keyImportError(String error) {
    return 'Error: $error';
  }

  @override
  String get keyImportInsecureBunkerRelay =>
      'Relay bunker harus pakai wss:// (ws:// hanya boleh untuk localhost)';

  @override
  String get timeNow => 'sekarang';

  @override
  String timeShortMinutes(int count) {
    return '${count}m';
  }

  @override
  String timeShortHours(int count) {
    return '${count}j';
  }

  @override
  String timeShortDays(int count) {
    return '${count}h';
  }

  @override
  String timeShortWeeks(int count) {
    return '${count}mg';
  }

  @override
  String timeShortMonths(int count) {
    return '${count}bl';
  }

  @override
  String timeShortYears(int count) {
    return '${count}th';
  }

  @override
  String get timeVerboseNow => 'Sekarang';

  @override
  String timeAgo(String time) {
    return '$time yang lalu';
  }

  @override
  String get timeToday => 'Hari ini';

  @override
  String get timeYesterday => 'Kemarin';

  @override
  String get timeJustNow => 'baru saja';

  @override
  String timeMinutesAgo(int count) {
    return '${count}m yang lalu';
  }

  @override
  String timeHoursAgo(int count) {
    return '${count}j yang lalu';
  }

  @override
  String timeDaysAgo(int count) {
    return '${count}h yang lalu';
  }

  @override
  String get draftTimeJustNow => 'Baru saja';

  @override
  String get contentLabelNudity => 'Ketelanjangan';

  @override
  String get contentLabelSexualContent => 'Konten Seksual';

  @override
  String get contentLabelPornography => 'Pornografi';

  @override
  String get contentLabelGraphicMedia => 'Media Grafis';

  @override
  String get contentLabelViolence => 'Kekerasan';

  @override
  String get contentLabelSelfHarm => 'Menyakiti Diri Sendiri/Bunuh Diri';

  @override
  String get contentLabelDrugUse => 'Penggunaan Narkoba';

  @override
  String get contentLabelAlcohol => 'Alkohol';

  @override
  String get contentLabelTobacco => 'Tembakau/Merokok';

  @override
  String get contentLabelGambling => 'Judi';

  @override
  String get contentLabelProfanity => 'Kata-kata Kasar';

  @override
  String get contentLabelHateSpeech => 'Ujaran Kebencian';

  @override
  String get contentLabelHarassment => 'Pelecehan';

  @override
  String get contentLabelFlashingLights => 'Cahaya Berkedip';

  @override
  String get contentLabelAiGenerated => 'Dibuat oleh AI';

  @override
  String get contentLabelDeepfake => 'Deepfake';

  @override
  String get contentLabelSpam => 'Spam';

  @override
  String get contentLabelScam => 'Penipuan';

  @override
  String get contentLabelSpoiler => 'Spoiler';

  @override
  String get contentLabelMisleading => 'Menyesatkan';

  @override
  String get contentLabelSensitiveContent => 'Konten Sensitif';

  @override
  String notificationLikedYourVideo(String actorName) {
    return '$actorName menyukai videomu';
  }

  @override
  String notificationLikedYourComment(String actorName) {
    return '$actorName menyukai komentarmu';
  }

  @override
  String notificationCommentedOnYourVideo(String actorName) {
    return '$actorName mengomentari videomu';
  }

  @override
  String notificationStartedFollowing(String actorName) {
    return '$actorName mulai mengikutimu';
  }

  @override
  String notificationMentionedYou(String actorName) {
    return '$actorName menyebutmu';
  }

  @override
  String notificationRepostedYourVideo(String actorName) {
    return '$actorName membagikan ulang videomu';
  }

  @override
  String notificationRepliedToYourComment(String actorName) {
    return '$actorName membalas komentar Anda';
  }

  @override
  String get notificationAndConnector => 'dan';

  @override
  String notificationOthersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lainnya',
    );
    return '$_temp0';
  }

  @override
  String get notificationSystemUpdate => 'Kamu punya pembaruan baru';

  @override
  String get notificationSomeoneLikedYourVideo => 'Seseorang menyukai videomu';

  @override
  String get commentReplyToPrefix => 'Bls:';

  @override
  String get commentHideKeyboard => 'Hide keyboard';

  @override
  String get commentsErrorLoadFailed => 'Failed to load comments';

  @override
  String get commentsErrorNotAuthenticatedComment =>
      'Please sign in to comment';

  @override
  String get commentsErrorPostCommentFailed => 'Failed to post comment';

  @override
  String get commentsErrorPostReplyFailed => 'Failed to post reply';

  @override
  String get commentsErrorEditFailed => 'Failed to edit comment';

  @override
  String get commentsErrorNotAuthenticatedInteract =>
      'Please sign in to interact';

  @override
  String get commentsErrorVoteFailed => 'Failed to vote on comment';

  @override
  String get commentsErrorReportFailed => 'Failed to report comment';

  @override
  String get commentsErrorBlockFailed => 'Failed to block user';

  @override
  String get commentsErrorDeleteFailed => 'Failed to delete comment';

  @override
  String commentsHeaderCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Comments',
      one: '$count Comment',
    );
    return '$_temp0';
  }

  @override
  String get commentsSortNew => 'New';

  @override
  String get commentsSortTop => 'Top';

  @override
  String get commentsSortOld => 'Old';

  @override
  String get commentsSortSemanticLabel => 'Comments sorting';

  @override
  String get commentReply => 'Reply';

  @override
  String get commentReplySemanticLabel => 'Reply to comment';

  @override
  String get commentUpvoteLabel => 'Upvote comment';

  @override
  String get commentRemoveUpvoteLabel => 'Remove upvote';

  @override
  String get commentDownvoteLabel => 'Downvote comment';

  @override
  String get commentRemoveDownvoteLabel => 'Remove downvote';

  @override
  String get commentsInputHint => 'Add comment...';

  @override
  String get commentsInputHintEdit => 'Edit comment...';

  @override
  String get commentsEmptyTitle => 'No comments yet';

  @override
  String get commentsEmptySubtitle => 'Get the party started!';

  @override
  String get commentsHeaderTitle => 'Comments';

  @override
  String get commentsHeaderCloseLabel => 'Close comments';

  @override
  String get draftUntitled => 'Tanpa judul';

  @override
  String get contentWarningNone => 'Tidak ada';

  @override
  String get textBackgroundNone => 'Tidak ada';

  @override
  String get textBackgroundSolid => 'Solid';

  @override
  String get textBackgroundHighlight => 'Sorotan';

  @override
  String get textBackgroundTransparent => 'Transparan';

  @override
  String get textAlignLeft => 'Kiri';

  @override
  String get textAlignRight => 'Kanan';

  @override
  String get textAlignCenter => 'Tengah';

  @override
  String get cameraPermissionWebUnsupportedTitle =>
      'Kamera belum didukung di web';

  @override
  String get cameraPermissionWebUnsupportedDescription =>
      'Pengambilan gambar dan perekaman kamera belum tersedia di versi web.';

  @override
  String get cameraPermissionBackToFeed => 'Kembali ke feed';

  @override
  String get cameraPermissionErrorTitle => 'Kesalahan izin';

  @override
  String get cameraPermissionErrorDescription =>
      'Terjadi kesalahan saat memeriksa izin.';

  @override
  String get cameraPermissionRetry => 'Coba lagi';

  @override
  String get cameraPermissionAllowAccessTitle =>
      'Izinkan akses kamera & mikrofon';

  @override
  String get cameraPermissionAllowAccessDescription =>
      'Ini memungkinkan Anda merekam dan mengedit video langsung di aplikasi, tidak lebih.';

  @override
  String get cameraPermissionContinue => 'Lanjutkan';

  @override
  String get cameraPermissionGoToSettings => 'Buka pengaturan';

  @override
  String get videoRecorderWhySixSecondsTitle => 'Mengapa enam detik?';

  @override
  String get videoRecorderWhySixSecondsSubtitle =>
      'Klip pendek memberi ruang untuk spontanitas. Format 6 detik membantu kamu menangkap momen autentik saat terjadi.';

  @override
  String get videoRecorderWhySixSecondsButton => 'Mengerti!';

  @override
  String get videoRecorderUploadTitle => 'Kenapa tidak ada unggahan?';

  @override
  String get videoRecorderUploadBody =>
      'Yang kamu lihat di Divine dibuat oleh manusia: mentah dan ditangkap pada momennya. Tidak seperti platform yang mengizinkan unggahan yang sangat diproduksi atau dihasilkan AI, kami memprioritaskan keaslian pengalaman kamera langsung.';

  @override
  String get videoRecorderUploadBodyDetail =>
      'Dengan menjaga kreasi tetap di dalam aplikasi, kami bisa lebih baik menjamin bahwa konten itu nyata dan tidak diedit. Kami tidak membuka unggahan dari galeri eksternal saat ini untuk melindungi keaslian itu dan menjaga komunitas kami bebas dari konten sintetis sebisa mungkin.';

  @override
  String get videoRecorderUploadBodyCta =>
      'Beralih ke Capture atau Classic untuk merekam sesuatu yang nyata.';

  @override
  String get videoRecorderUploadLearnMore => 'Pelajari cara kerja verifikasi';

  @override
  String get videoRecorderAutosaveFoundTitle =>
      'Kami menemukan pekerjaan yang belum selesai';

  @override
  String get videoRecorderAutosaveFoundSubtitle =>
      'Apakah kamu ingin melanjutkan dari tempat kamu berhenti?';

  @override
  String get videoRecorderAutosaveContinueButton => 'Ya, lanjutkan';

  @override
  String get videoRecorderAutosaveDiscardButton => 'Tidak, mulai video baru';

  @override
  String get videoRecorderAutosaveRestoreFailure =>
      'Tidak dapat memulihkan draf kamu';

  @override
  String get videoRecorderStopRecordingTooltip => 'Hentikan perekaman';

  @override
  String get videoRecorderStartRecordingTooltip => 'Mulai merekam';

  @override
  String get videoRecorderRecordingTapToStopLabel =>
      'Merekam. Ketuk di mana saja untuk berhenti';

  @override
  String get videoRecorderTapToStartLabel =>
      'Ketuk di mana saja untuk mulai merekam';

  @override
  String get videoRecorderDeleteLastClipLabel => 'Hapus klip terakhir';

  @override
  String get videoRecorderSwitchCameraLabel => 'Ganti kamera';

  @override
  String videoRecorderZoomLevelLabel(String zoom) {
    return 'Zoom ke $zoom×';
  }

  @override
  String get videoRecorderToggleGridLabel => 'Ganti grid';

  @override
  String get videoRecorderToggleGhostFrameLabel => 'Ganti frame hantu';

  @override
  String get videoRecorderGhostFrameEnabled => 'Frame hantu diaktifkan';

  @override
  String get videoRecorderGhostFrameDisabled => 'Frame hantu dinonaktifkan';

  @override
  String get videoRecorderClipDeletedMessage => 'Klip dipindahkan ke sampah';

  @override
  String get videoRecorderClipUndoLabel => 'Urungkan';

  @override
  String get libraryTrashTitle => 'Baru-baru ini dihapus';

  @override
  String get libraryTrashEmptyTitle => 'Sampah kosong';

  @override
  String get libraryTrashEmptySubtitle =>
      'Klip yang dihapus tetap di sini selama 30 hari sebelum dihapus secara permanen.';

  @override
  String get libraryTrashRestoreLabel => 'Pulihkan';

  @override
  String get libraryTrashDeleteNowLabel => 'Hapus sekarang';

  @override
  String get libraryTrashEmptyAllLabel => 'Kosongkan sampah';

  @override
  String get libraryTrashDeleteConfirmTitle => 'Hapus klip sekarang?';

  @override
  String get libraryTrashDeleteConfirmMessage =>
      'Ini langsung menghapus klip dari sampah.';

  @override
  String get libraryTrashEmptyConfirmTitle => 'Kosongkan sampah?';

  @override
  String libraryTrashEmptyConfirmMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klip',
      one: '1 klip',
    );
    return 'Ini langsung menghapus permanen $_temp0 dari sampah.';
  }

  @override
  String get libraryTrashEntryLabel => 'Baru-baru ini dihapus';

  @override
  String get videoRecorderCloseLabel => 'Tutup perekam video';

  @override
  String get videoRecorderContinueToEditorLabel => 'Lanjutkan ke editor video';

  @override
  String get videoRecorderCaptureCloseLabel => 'Tutup';

  @override
  String get videoRecorderCaptureNextLabel => 'Berikutnya';

  @override
  String get videoRecorderLipSyncAddAudioFirst =>
      'Tambahkan audio sebelum merekam';

  @override
  String get videoRecorderToggleFlashLabel => 'Ganti flash';

  @override
  String get videoRecorderCycleTimerLabel => 'Timer siklus';

  @override
  String get videoRecorderToggleAspectRatioLabel => 'Ganti rasio aspek';

  @override
  String get videoRecorderStabilizationLabel => 'Stabilisasi';

  @override
  String get videoRecorderStabilizationModeOff => 'Nonaktif';

  @override
  String get videoRecorderStabilizationModeStandard => 'Standar';

  @override
  String get videoRecorderStabilizationModeCinematic => 'Sinematik';

  @override
  String get videoRecorderStabilizationModeCinematicExtended =>
      'Sinematik Diperluas';

  @override
  String get videoRecorderStabilizationModePreviewOptimized =>
      'Dioptimalkan untuk pratinjau';

  @override
  String get videoRecorderStabilizationModeLowLatency => 'Latensi rendah';

  @override
  String get videoRecorderStabilizationModeAuto => 'Otomatis';

  @override
  String get videoRecorderLibraryEmptyLabel =>
      'Perpustakaan klip, tidak ada klip';

  @override
  String videoRecorderLibraryOpenLabel(int clipCount) {
    String _temp0 = intl.Intl.pluralLogic(
      clipCount,
      locale: localeName,
      other: 'Buka perpustakaan klip, $clipCount klip',
      one: 'Buka perpustakaan klip, 1 klip',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorCameraLabel => 'Kamera';

  @override
  String get videoEditorOpenCameraSemanticLabel => 'Buka kamera';

  @override
  String get videoEditorLibraryLabel => 'Perpustakaan';

  @override
  String get videoEditorTextLabel => 'Teks';

  @override
  String get videoEditorDrawLabel => 'Gambar';

  @override
  String get videoEditorFilterLabel => 'Filter';

  @override
  String get videoEditorAudioLabel => 'Audio';

  @override
  String get videoEditorAddTitle => 'Tambah';

  @override
  String get videoEditorOpenLibrarySemanticLabel => 'Buka perpustakaan';

  @override
  String get videoEditorOpenAudioSemanticLabel => 'Buka editor audio';

  @override
  String get videoEditorOpenTextSemanticLabel => 'Buka editor teks';

  @override
  String get videoEditorOpenDrawSemanticLabel => 'Buka editor gambar';

  @override
  String get videoEditorOpenFilterSemanticLabel => 'Buka editor filter';

  @override
  String get videoEditorOpenStickerSemanticLabel => 'Buka editor stiker';

  @override
  String get videoEditorSaveDraftTitle => 'Simpan draf?';

  @override
  String get videoEditorSaveDraftSubtitle =>
      'Simpan editan untuk nanti, atau buang dan keluar dari editor.';

  @override
  String get videoEditorSaveDraftButton => 'Simpan draf';

  @override
  String get videoEditorDiscardChangesButton => 'Buang perubahan';

  @override
  String get videoEditorKeepEditingButton => 'Lanjutkan mengedit';

  @override
  String get videoEditorDeleteLayerDropZone =>
      'Area lepas untuk menghapus lapisan';

  @override
  String get videoEditorReleaseToDeleteLayer => 'Lepas untuk menghapus lapisan';

  @override
  String get videoEditorDoneLabel => 'Selesai';

  @override
  String get videoEditorPlayPauseSemanticLabel => 'Putar atau jeda video';

  @override
  String get videoEditorCropSemanticLabel => 'Pangkas';

  @override
  String get videoEditorCannotSplitProcessing =>
      'Tidak dapat membagi klip saat sedang diproses. Harap tunggu.';

  @override
  String videoEditorSplitPositionInvalid(int minDurationMs) {
    return 'Posisi pembagian tidak valid. Setiap klip harus minimal ${minDurationMs}ms.';
  }

  @override
  String get videoEditorAddClipFromLibrary => 'Tambah klip dari Perpustakaan';

  @override
  String get videoEditorSaveSelectedClip => 'Simpan klip yang dipilih';

  @override
  String get videoEditorSplitClip => 'Bagi klip';

  @override
  String get videoEditorSaveClip => 'Simpan klip';

  @override
  String get videoEditorDeleteClip => 'Hapus klip';

  @override
  String get videoEditorClipSavedSuccess => 'Klip disimpan ke perpustakaan';

  @override
  String get videoEditorClipSaveFailed => 'Gagal menyimpan klip';

  @override
  String get videoEditorClipDeleted => 'Klip dihapus';

  @override
  String get videoEditorColorPickerSemanticLabel => 'Pemilih warna';

  @override
  String get videoEditorUndoSemanticLabel => 'Batalkan';

  @override
  String get videoEditorRedoSemanticLabel => 'Ulangi';

  @override
  String get videoEditorTextColorSemanticLabel => 'Warna teks';

  @override
  String get videoEditorTextAlignmentSemanticLabel => 'Perataan teks';

  @override
  String get videoEditorTextBackgroundSemanticLabel => 'Latar belakang teks';

  @override
  String get videoEditorFontSemanticLabel => 'Font';

  @override
  String get videoEditorNoStickersFound => 'Stiker tidak ditemukan';

  @override
  String get videoEditorNoStickersAvailable => 'Tidak ada stiker tersedia';

  @override
  String get videoEditorFailedLoadStickers => 'Gagal memuat stiker';

  @override
  String get videoEditorAdjustVolumeTitle => 'Atur volume';

  @override
  String get videoEditorRecordedAudioLabel => 'Audio yang direkam';

  @override
  String get videoEditorVoiceOverLabel => 'Sulih suara';

  @override
  String videoEditorVoiceOverTakeName(int number) {
    return 'Rekaman $number';
  }

  @override
  String get videoEditorOpenVoiceOverSemanticLabel => 'Rekam sulih suara';

  @override
  String get videoEditorVoiceOverRecordSemanticLabel => 'Mulai merekam';

  @override
  String get videoEditorVoiceOverStopSemanticLabel => 'Hentikan rekaman';

  @override
  String get videoEditorVoiceOverHint =>
      'Ketuk untuk merekam. Tambahkan sebanyak yang kamu mau.';

  @override
  String videoEditorVoiceOverRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rekaman',
      one: '1 rekaman',
      zero: 'Belum ada rekaman',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorVoiceOverDeleteLast => 'Hapus rekaman terakhir';

  @override
  String get videoEditorVoiceOverPermissionTitle => 'Perlu akses mikrofon';

  @override
  String get videoEditorVoiceOverPermissionBody =>
      'Izinkan akses mikrofon untuk merekam sulih suara.';

  @override
  String get videoEditorVoiceOverOpenSettings => 'Buka pengaturan';

  @override
  String get videoEditorVoiceOverRecordingStarted => 'Rekaman dimulai';

  @override
  String get videoEditorVoiceOverRecordingSaved => 'Rekaman disimpan';

  @override
  String get videoEditorVoiceOverTooLong =>
      'Rekaman lebih panjang dari video Anda';

  @override
  String get videoEditorPlaySemanticLabel => 'Putar';

  @override
  String get videoEditorPauseSemanticLabel => 'Jeda';

  @override
  String get videoEditorMuteAudioSemanticLabel => 'Matikan suara';

  @override
  String get videoEditorUnmuteAudioSemanticLabel => 'Aktifkan suara';

  @override
  String get videoEditorVolumeSemanticLabel => 'Sesuaikan volume';

  @override
  String videoEditorTimelineVolumePreview(int percent) {
    return 'Volume $percent%';
  }

  @override
  String get videoEditorTimelineSlideToAdjust => 'Geser untuk menyesuaikan';

  @override
  String get videoEditorOriginalAudioLabel => 'Audio asli';

  @override
  String videoEditorClipVolumeLabel(int index) {
    return 'Klip $index';
  }

  @override
  String get videoEditorDeleteLabel => 'Hapus';

  @override
  String get videoEditorDeleteSelectedItemSemanticLabel =>
      'Hapus item yang dipilih';

  @override
  String get videoEditorEditLabel => 'Edit';

  @override
  String get videoEditorEditSelectedItemSemanticLabel =>
      'Edit item yang dipilih';

  @override
  String get videoEditorDuplicateLabel => 'Duplikat';

  @override
  String get videoEditorDuplicateSelectedItemSemanticLabel =>
      'Duplikat item yang dipilih';

  @override
  String get videoEditorSplitLabel => 'Bagi';

  @override
  String get videoEditorSplitSelectedClipSemanticLabel =>
      'Bagi klip yang dipilih';

  @override
  String get videoEditorExtractAudioLabel => 'Ekstrak audio';

  @override
  String get videoEditorClipAudioTitle => 'Audio klip';

  @override
  String get videoEditorExtractAudioFromClipSemanticLabel =>
      'Ekstrak audio dari klip dan bisukan aslinya';

  @override
  String get videoEditorExtractAudioNoLocalFile =>
      'Tidak dapat mengekstrak audio: klip tidak tersedia secara lokal.';

  @override
  String get videoEditorExtractAudioFailed =>
      'Tidak dapat mengekstrak audio. Silakan coba lagi.';

  @override
  String get videoEditorSpeedLabel => 'Kecepatan';

  @override
  String get videoEditorSetClipSpeedSemanticLabel =>
      'Atur kecepatan putar untuk klip yang dipilih';

  @override
  String get videoEditorReverseLabel => 'Balik';

  @override
  String get videoEditorReverseClipSemanticLabel =>
      'Aktifkan atau nonaktifkan pemutaran terbalik untuk klip yang dipilih';

  @override
  String get videoEditorReverseProgressLabel =>
      'Tunggu sebentar, kami sedang membalik klip Anda';

  @override
  String get videoEditorTransformLabel => 'Transformasi';

  @override
  String get videoEditorTransformSelectedClipSemanticLabel =>
      'Pangkas, putar, atau balik klip yang dipilih';

  @override
  String get videoEditorTransformProgressLabel =>
      'Sebentar, kami sedang mentransformasi klip Anda';

  @override
  String get videoEditorTransformFailed =>
      'Tidak dapat mentransformasi klip. Silakan coba lagi.';

  @override
  String get videoEditorTransformNoLocalFile =>
      'Tidak dapat mentransformasi: klip tidak tersedia secara lokal.';

  @override
  String get videoEditorTransformRotateLabel => 'Putar';

  @override
  String get videoEditorTransformFlipLabel => 'Balik';

  @override
  String get videoEditorTransformRatioLabel => 'Rasio';

  @override
  String get videoEditorTransformResetLabel => 'Atur ulang';

  @override
  String get videoEditorTransformApplySemanticLabel => 'Terapkan transformasi';

  @override
  String get videoEditorTransformCancelSemanticLabel => 'Batalkan transformasi';

  @override
  String get videoEditorTransformPlayLabel => 'Putar';

  @override
  String get videoEditorTransformPauseLabel => 'Jeda';

  @override
  String get videoEditorReverseNoLocalFile =>
      'Tidak dapat membalik: klip tidak tersedia secara lokal.';

  @override
  String get videoEditorReverseFailed =>
      'Tidak dapat membalik klip. Silakan coba lagi.';

  @override
  String get videoEditorSpeedSheetTitle => 'Kecepatan Klip';

  @override
  String get videoEditorTransitionSheetTitle => 'Transisi';

  @override
  String get videoEditorTransitionNone => 'Tidak ada';

  @override
  String get videoEditorTransitionDissolve => 'Larut';

  @override
  String get videoEditorTransitionFadeToBlack => 'Pudar ke hitam';

  @override
  String get videoEditorTransitionFadeToWhite => 'Pudar ke putih';

  @override
  String get videoEditorTransitionSlide => 'Geser';

  @override
  String get videoEditorTransitionPush => 'Dorong';

  @override
  String get videoEditorTransitionWipe => 'Sapu';

  @override
  String get videoEditorTransitionButtonSemanticLabel => 'Edit transisi';

  @override
  String get videoEditorTransitionDuration => 'Durasi';

  @override
  String get videoEditorTransitionDurationLimitedHint =>
      'Dipendekkan agar tidak tumpang tindih dengan transisi di sebelahnya.';

  @override
  String get videoEditorTransitionCurve => 'Kurva';

  @override
  String get videoEditorTransitionDirection => 'Arah';

  @override
  String get videoEditorTransitionDirectionLeft => 'Kiri';

  @override
  String get videoEditorTransitionDirectionRight => 'Kanan';

  @override
  String get videoEditorTransitionDirectionUp => 'Atas';

  @override
  String get videoEditorTransitionDirectionDown => 'Bawah';

  @override
  String videoEditorTransitionCurveOptionSemanticLabel(int number) {
    return 'Kurva animasi $number';
  }

  @override
  String get videoEditorLayerAnimationLabel => 'Animasi';

  @override
  String get videoEditorLayerAnimationButtonSemanticLabel =>
      'Edit animasi lapisan';

  @override
  String get videoEditorLayerAnimationEnter => 'Masuk';

  @override
  String get videoEditorLayerAnimationLeave => 'Keluar';

  @override
  String get videoEditorLayerAnimationFade => 'Pudar';

  @override
  String get videoEditorLayerAnimationScale => 'Skala';

  @override
  String get videoEditorLayerAnimationScaleFrom => 'Skala dari';

  @override
  String get videoEditorFinishTimelineEditingSemanticLabel =>
      'Selesai mengedit timeline';

  @override
  String get videoEditorAudioPlayPreviewSemanticLabel => 'Putar pratinjau';

  @override
  String get videoEditorAudioPausePreviewSemanticLabel => 'Jeda pratinjau';

  @override
  String get videoEditorAudioUntitledSound => 'Suara tanpa judul';

  @override
  String get videoEditorAudioUntitled => 'Tanpa judul';

  @override
  String get videoEditorAudioAddAudio => 'Tambah audio';

  @override
  String get videoEditorAudioNoSoundsAvailableTitle =>
      'Tidak ada suara tersedia';

  @override
  String get videoEditorAudioNoSoundsAvailableSubtitle =>
      'Suara akan muncul di sini saat kreator berbagi audio';

  @override
  String get videoEditorAudioFailedToLoadTitle => 'Gagal memuat suara';

  @override
  String get videoEditorAudioSegmentInstruction =>
      'Pilih segmen audio untuk videomu';

  @override
  String get videoEditorAudioCategoryDivine => 'OG Sounds';

  @override
  String get videoEditorAudioCategoryCommunity => 'Komunitas';

  @override
  String get videoEditorAudioCategoryFeatured => 'Unggulan';

  @override
  String get videoEditorAudioCategoryMySounds => 'Suara Saya';

  @override
  String get videoEditorAudioFeaturedEmptyTitle =>
      'Suara unggulan segera hadir';

  @override
  String get videoEditorAudioFeaturedEmptySubtitle =>
      'Kami akan menambahkan suara unggulan di sini setelah siap.';

  @override
  String get videoEditorDrawToolArrowSemanticLabel => 'Alat panah';

  @override
  String get videoEditorDrawToolEraserSemanticLabel => 'Alat penghapus';

  @override
  String get videoEditorDrawToolMarkerSemanticLabel => 'Alat marker';

  @override
  String get videoEditorDrawToolPencilSemanticLabel => 'Alat pensil';

  @override
  String videoEditorLayerReorderLabel(int index) {
    return 'Urutkan ulang lapisan $index';
  }

  @override
  String get videoEditorLayerReorderHint => 'Tahan untuk mengurutkan ulang';

  @override
  String get videoEditorShowTimelineSemanticLabel => 'Tampilkan timeline';

  @override
  String get videoEditorHideTimelineSemanticLabel => 'Sembunyikan timeline';

  @override
  String get videoEditorFeedPreviewContent =>
      'Hindari menempatkan konten di belakang area ini.';

  @override
  String get videoEditorStickersDivineOriginals => 'Divine Orisinal';

  @override
  String get videoEditorStickerSearchHint => 'Cari stiker...';

  @override
  String get videoEditorSelectFontSemanticLabel => 'Pilih font';

  @override
  String get videoEditorFontUnknown => 'Tidak dikenal';

  @override
  String get videoEditorSplitPlayheadOutsideClip =>
      'Playhead harus berada di dalam klip yang dipilih untuk membagi.';

  @override
  String get videoEditorTimelineTrimStartSemanticLabel => 'Pangkas awal';

  @override
  String get videoEditorTimelineTrimEndSemanticLabel => 'Pangkas akhir';

  @override
  String get videoEditorTimelineTrimClipSemanticLabel => 'Pangkas klip';

  @override
  String get videoEditorTimelineTrimClipHint =>
      'Seret pegangan untuk mengatur durasi klip';

  @override
  String videoEditorTimelineDraggingClipSemanticLabel(int index) {
    return 'Menyeret klip $index';
  }

  @override
  String videoEditorTimelineClipSemanticLabel(
    int index,
    int total,
    String duration,
  ) {
    return 'Klip $index dari $total, $duration detik';
  }

  @override
  String get videoEditorTimelineClipReorderHint =>
      'Tekan lama untuk mengurutkan ulang';

  @override
  String get videoEditorClipGalleryInstruction =>
      'Ketuk untuk mengedit. Tekan lama dan seret untuk mengurutkan ulang.';

  @override
  String get videoEditorTimelineClipMoveLeft => 'Geser ke kiri';

  @override
  String get videoEditorTimelineClipMoveRight => 'Geser ke kanan';

  @override
  String videoEditorTimelineClipSelectedSemanticLabel(int index, int total) {
    return 'Klip $index dari $total, dipilih';
  }

  @override
  String videoEditorTimelineClipUnselectedSemanticLabel(int index, int total) {
    return 'Klip $index dari $total, tidak dipilih';
  }

  @override
  String get videoEditorMultiSelectLabel => 'Pilih';

  @override
  String get videoEditorMultiSelectSemanticLabel => 'Pilih beberapa klip';

  @override
  String get videoEditorMultiSelectDoneSemanticLabel => 'Selesai memilih';

  @override
  String videoEditorMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klip dipilih',
      one: '1 klip dipilih',
      zero: 'Tidak ada klip dipilih',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorMergeLabel => 'Gabungkan';

  @override
  String get videoEditorMergeSelectedClipsSemanticLabel =>
      'Gabungkan klip yang dipilih';

  @override
  String get videoEditorDeleteSelectedClipsSemanticLabel =>
      'Hapus klip yang dipilih';

  @override
  String get videoEditorMergeProgressLabel =>
      'Sebentar, kami sedang menggabungkan klipmu';

  @override
  String get videoEditorMergeFailed =>
      'Tidak dapat menggabungkan klip. Silakan coba lagi.';

  @override
  String get videoEditorTimelineLongPressToDragHint =>
      'Tekan lama untuk menyeret';

  @override
  String get videoEditorVideoTimelineSemanticLabel => 'Timeline video';

  @override
  String videoEditorTimelinePositionFormat(int minutes, String seconds) {
    return '${minutes}m ${seconds}d';
  }

  @override
  String videoEditorColorSelectedSemanticLabel(String colorName) {
    return '$colorName, dipilih';
  }

  @override
  String get videoEditorCloseColorPickerSemanticLabel => 'Tutup pemilih warna';

  @override
  String get videoEditorPickColorTitle => 'Pilih warna';

  @override
  String get videoEditorConfirmColorSemanticLabel => 'Konfirmasi warna';

  @override
  String get videoEditorSaturationBrightnessSemanticLabel =>
      'Saturasi dan kecerahan';

  @override
  String videoEditorSaturationBrightnessValue(int saturation, int brightness) {
    return 'Saturasi $saturation%, Kecerahan $brightness%';
  }

  @override
  String get videoEditorHueSemanticLabel => 'Rona';

  @override
  String get videoEditorAddElementSemanticLabel => 'Tambah elemen';

  @override
  String get videoEditorCloseSemanticLabel => 'Tutup';

  @override
  String get videoEditorDoneSemanticLabel => 'Selesai';

  @override
  String get videoEditorLevelSemanticLabel => 'Level';

  @override
  String get videoMetadataBackSemanticLabel => 'Kembali';

  @override
  String get videoMetadataDismissHelpDialogSemanticLabel =>
      'Tutup dialog bantuan';

  @override
  String get videoMetadataGotItButton => 'Mengerti!';

  @override
  String get videoMetadataLimitReachedWarning =>
      'Batas 64KB tercapai. Hapus beberapa konten untuk melanjutkan.';

  @override
  String get videoMetadataExpirationLabel => 'Kedaluwarsa';

  @override
  String get videoMetadataSelectExpirationSemanticLabel =>
      'Pilih waktu kedaluwarsa';

  @override
  String get videoMetadataTitleLabel => 'Judul';

  @override
  String get videoMetadataDescriptionLabel => 'Deskripsi';

  @override
  String get videoMetadataTagsLabel => 'Tag';

  @override
  String get videoMetadataDeleteTagSemanticLabel => 'Hapus';

  @override
  String videoMetadataDeleteTagHint(String tag) {
    return 'Hapus tag $tag';
  }

  @override
  String get videoMetadataContentWarningLabel => 'Peringatan Konten';

  @override
  String get videoMetadataSelectContentWarningsSemanticLabel =>
      'Pilih peringatan konten';

  @override
  String get videoMetadataContentWarningSelectAllThatApply =>
      'Pilih semua yang berlaku untuk kontenmu';

  @override
  String get videoMetadataContentWarningDoneButton => 'Selesai';

  @override
  String get videoMetadataAudioReuseTitle => 'Publikasikan suara ini';

  @override
  String get videoMetadataAudioReuseSubtitle =>
      'Izinkan orang lain menyimpan dan menggunakan kembali audio video ini.';

  @override
  String get videoMetadataCollaboratorsLabel => 'Kolaborator';

  @override
  String get videoMetadataAddCollaboratorSemanticLabel => 'Tambah kolaborator';

  @override
  String get videoMetadataCollaboratorsHelpTooltip => 'Cara kerja kolaborator';

  @override
  String videoMetadataCollaboratorsCount(int count, int max) {
    return '$count/$max Kolaborator';
  }

  @override
  String get videoMetadataRemoveCollaboratorSemanticLabel =>
      'Hapus kolaborator';

  @override
  String get videoMetadataCollaboratorsHelpMessage =>
      'Kolaborator ditandai sebagai co-creator pada postingan ini. Kamu hanya dapat menambahkan orang yang saling kamu ikuti, dan mereka muncul dalam metadata postingan saat dipublikasikan.';

  @override
  String get videoMetadataMutualFollowersSearchText =>
      'Pengikut saling mengikuti';

  @override
  String videoMetadataMustMutuallyFollowSnackbar(String name) {
    return 'Kamu perlu saling mengikuti $name untuk menambahkannya sebagai kolaborator.';
  }

  @override
  String get videoMetadataInspiredByLabel => 'Terinspirasi oleh';

  @override
  String get videoMetadataSetInspiredBySemanticLabel => 'Atur inspirasi';

  @override
  String get videoMetadataInspiredByHelpTooltip =>
      'Cara kerja kredit inspirasi';

  @override
  String get videoMetadataInspiredByNone => 'Tidak ada';

  @override
  String get videoMetadataInspiredByHelpMessage =>
      'Gunakan ini untuk memberikan atribusi. Kredit terinspirasi berbeda dari kolaborator: ini mengakui pengaruh, tetapi tidak menandai seseorang sebagai co-creator.';

  @override
  String get videoMetadataCreatorCannotBeReferencedSnackbar =>
      'Kreator ini tidak dapat direferensikan.';

  @override
  String get videoMetadataRemoveInspiredBySemanticLabel => 'Hapus inspirasi';

  @override
  String get videoMetadataPostDetailsTitle => 'Detail postingan';

  @override
  String get videoMetadataSavedToLibrarySnackbar => 'Disimpan ke perpustakaan';

  @override
  String get videoMetadataFailedToSaveSnackbar => 'Gagal menyimpan';

  @override
  String get videoMetadataGoToLibraryButton => 'Pergi ke Perpustakaan';

  @override
  String get videoMetadataSaveForLaterSemanticLabel =>
      'Tombol simpan untuk nanti';

  @override
  String get videoMetadataRenderingVideoHint => 'Merender video...';

  @override
  String get videoMetadataSavingVideoHint => 'Menyimpan video...';

  @override
  String videoMetadataSaveToDraftsHint(String destination) {
    return 'Simpan video ke draf dan $destination';
  }

  @override
  String get videoMetadataSaveForLaterButton => 'Simpan untuk Nanti';

  @override
  String get videoMetadataPostSemanticLabel => 'Tombol posting';

  @override
  String get videoMetadataPublishVideoHint => 'Publikasikan video ke feed';

  @override
  String get videoMetadataShareReplyToFeedTitle => 'Bagikan juga ke feed saya';

  @override
  String get videoMetadataShareReplyToFeedSubtitle =>
      'Jika dimatikan, video ini hanya tetap di utas komentar.';

  @override
  String get videoMetadataFormNotReadyHint => 'Isi formulir untuk mengaktifkan';

  @override
  String get videoMetadataPostButton => 'Posting';

  @override
  String get videoMetadataOpenPreviewSemanticLabel =>
      'Buka layar pratinjau postingan';

  @override
  String get videoMetadataShareTitle => 'Bagikan';

  @override
  String get videoMetadataVideoDetailsSubtitle => 'Detail video';

  @override
  String get videoMetadataClassicDoneButton => 'Selesai';

  @override
  String get videoMetadataPlayPreviewSemanticLabel => 'Putar pratinjau';

  @override
  String get videoMetadataPausePreviewSemanticLabel => 'Jeda pratinjau';

  @override
  String get videoMetadataClosePreviewSemanticLabel => 'Tutup pratinjau video';

  @override
  String get videoMetadataRemoveSemanticLabel => 'Hapus';

  @override
  String get fullscreenFeedRemovedMessage => 'Video dihapus';

  @override
  String get settingsBadgesTitle => 'Badge';

  @override
  String get settingsBadgesSubtitle =>
      'Terima penghargaan dan cek status badge yang diberikan.';

  @override
  String get badgesTitle => 'Badge';

  @override
  String get badgesIntroTitle => 'Pahami jejak badge-mu';

  @override
  String get badgesIntroBody =>
      'Lihat penghargaan badge yang dikirim ke kamu, pilih yang mau di-pin ke profil Nostr-mu, dan cek apakah orang menerima badge yang kamu berikan.';

  @override
  String get badgesOpenApp => 'Buka aplikasi badge';

  @override
  String get badgesLoadError => 'Gagal memuat badge';

  @override
  String get badgesUpdateError => 'Gagal memperbarui badge';

  @override
  String get badgesAwardedSectionTitle => 'Diberikan untukmu';

  @override
  String get badgesAwardedEmptyTitle => 'Belum ada badge yang diberikan';

  @override
  String get badgesAwardedEmptySubtitle =>
      'Saat seseorang memberimu badge Nostr, akan muncul di sini.';

  @override
  String get badgesStatusAccepted => 'Diterima';

  @override
  String get badgesStatusNotAccepted => 'Belum diterima';

  @override
  String get badgesActionRemove => 'Hapus';

  @override
  String get badgesActionAccept => 'Terima';

  @override
  String get badgesActionReject => 'Tolak';

  @override
  String get badgesIssuedSectionTitle => 'Diberikan olehmu';

  @override
  String get badgesIssuedEmptyTitle => 'Belum ada badge yang diberikan';

  @override
  String get badgesIssuedEmptySubtitle =>
      'Badge yang kamu berikan akan menampilkan status penerimaan di sini.';

  @override
  String get badgesIssuedNoRecipients =>
      'Tidak ada penerima untuk penghargaan ini.';

  @override
  String get badgesRecipientAcceptedStatus => 'Diterima oleh penerima';

  @override
  String get badgesRecipientWaitingStatus => 'Menunggu penerima';

  @override
  String get profileBadgeAwardedBy => 'Awarded by';

  @override
  String get profileBadgeRecipients => 'Recipients';

  @override
  String profileBadgeMoreRecipients(int count) {
    return '+$count more';
  }

  @override
  String profileBadgeSemanticLabel(String name) {
    return '$name badge';
  }

  @override
  String get profileBadgeFallbackSemanticLabel => 'Badge';

  @override
  String get minorAccountReviewWelcomePageTitle => 'Family guide';

  @override
  String get minorAccountReviewWelcomeCta =>
      'Not 16 yet? That\'s OK. Here\'s what you can do.';

  @override
  String get minorAccountReviewWelcomeTitle => 'Not 16 yet? That\'s OK.';

  @override
  String get minorAccountReviewWelcomeBody =>
      'Rules for people under 16 vary depending on where you live. At Divine, we want families to talk it through together and decide what healthy social media use looks like.';

  @override
  String get minorAccountReviewModerationTitle => 'We need one more step';

  @override
  String get minorAccountReviewModerationBody =>
      'We were asked to take a closer look at this account because it may belong to someone under 16. This flow keeps the next steps private and points you to the right path for your age.';

  @override
  String get minorAccountReviewRulesTitle =>
      'The rules are not the same everywhere';

  @override
  String get minorAccountReviewRulesBody =>
      'Different countries and regions treat teen social media use differently. That is why we ask families to slow down, check the facts, and choose the next step together.';

  @override
  String get minorAccountReviewApproachTitle => 'How Divine thinks about it';

  @override
  String get minorAccountReviewApproachBody =>
      'We think healthy tech habits come from pausing, reflecting, and redirecting attention toward better things, not from spying on kids or turning parents into hall monitors. Research backs that up too.';

  @override
  String get minorAccountReviewLearnMoreTitle => 'More for families';

  @override
  String get minorAccountReviewKidsPolicyCta => 'Read Divine\'s kids policy';

  @override
  String get minorAccountReviewChooseAgeBandTitle =>
      'Choose the path that fits';

  @override
  String get minorAccountReviewUnder13Cta => 'Under 13';

  @override
  String get minorAccountReviewTeenCta => 'Age 13-15';

  @override
  String get minorAccountReviewFamilyResourcesTitle => 'Helpful for families';

  @override
  String get minorAccountReviewFamilyResourcesBody =>
      'Visit the Divine family guide for practical tips, conversation tools, and resources for helping teens use social media more safely.';

  @override
  String get minorAccountReviewFamilyResourcesCta =>
      'Get family guides and tips';

  @override
  String get minorAccountReviewFooter =>
      'If you are 16 or older and got sent here by mistake, contact Divine support so a real person can review it.';

  @override
  String get minorAccountReviewTitle => 'Account Review';

  @override
  String get minorAccountReviewCheckingStatusTitle =>
      'Checking account status...';

  @override
  String get minorAccountReviewCheckingStatusBody =>
      'Please wait while we confirm this account\'s current review status.';

  @override
  String get minorAccountReviewDefaultTitle => 'Account review required';

  @override
  String get minorAccountReviewDefaultBody =>
      'We need to review this account before it can use Divine normally.';

  @override
  String minorAccountReviewCaseId(String caseId) {
    return 'Case ID: $caseId';
  }

  @override
  String get minorAccountReviewCaseIdShortLabel => 'Case ID';

  @override
  String get minorAccountReviewRestrictionsTitle =>
      'What is restricted right now';

  @override
  String get minorAccountReviewRestrictionPosting =>
      'Posting and publishing are paused';

  @override
  String get minorAccountReviewRestrictionEngagement =>
      'Comments, likes, reposts, and follows are paused';

  @override
  String get minorAccountReviewRestrictionMessaging =>
      'Starting or replying to regular messages is paused';

  @override
  String get minorAccountReviewRestrictionSupport =>
      'Support and your moderation message remain available';

  @override
  String get minorAccountReviewOpenSupportCenter => 'Open Support Center';

  @override
  String get minorAccountReviewOpenModerationMessage =>
      'Open Moderation Message';

  @override
  String get minorAccountReviewOpenReviewPage => 'Open review page';

  @override
  String get minorAccountReviewCheckAgain => 'Check Again';

  @override
  String get minorAccountReviewLogOut => 'Log out';

  @override
  String get minorAccountReviewNextStepTitle => 'Next step';

  @override
  String get minorAccountReviewNextStepBody =>
      'Open the support center or your moderation message if you need help with this review.';

  @override
  String get minorAccountReviewInProgressTitle => 'Review in progress';

  @override
  String get minorAccountReviewInProgressBody =>
      'We have what we need for now. Our team is reviewing this case before restoring normal account access.';

  @override
  String get minorAccountReviewUnder13Title => 'Under-13 accounts';

  @override
  String minorAccountReviewUnder13Body(String supportEmail) {
    return 'If this account belongs to someone under 13, a parent or guardian must email $supportEmail and include the case ID.';
  }

  @override
  String get minorAccountReviewUnder13PublicTitle =>
      'We can\'t give you an account yet';

  @override
  String get minorAccountReviewUnder13PublicBody =>
      'Divine isn\'t built for kids under 13 and the social media rules around the world tie our hands.\n\nA lot of things on the internet push you to lie to get what you want, and we hate that. It\'s the wrong lesson for life, and we\'re not going to teach it to you here.';

  @override
  String get minorAccountReviewUnder13FamilyTitle =>
      'What your family can do instead';

  @override
  String get minorAccountReviewUnder13FamilyBody =>
      'A parent or guardian can hold the account and do the posting, and you can absolutely be in the videos with them. We want families to enjoy Divine in whatever way is right for them.';

  @override
  String get minorAccountReviewUnder13ComeBackTitle => 'When you turn 13';

  @override
  String get minorAccountReviewUnder13ComeBackBody =>
      'Depending on the rules where you live, you may be able to come back and apply for your own account. In that case, if you’re between 13 and 15, you’ll need consent from a parent or guardian.';

  @override
  String get minorAccountReviewUnder13HonestyTitle =>
      'Why we won\'t tell you to just click back';

  @override
  String get minorAccountReviewUnder13HonestyBody =>
      'A lot of the internet is set up to reward people for saying whatever gets them through the gate. We don\'t think that\'s great. Yes, you could go back and say you\'re older than you are, but that wouldn\'t be honest, and we\'re not going to coach you into lying to get what you want.';

  @override
  String get minorAccountReviewUnder13LegalTitle =>
      'Why the answer is still no';

  @override
  String get minorAccountReviewUnder13LegalBody =>
      'We\'re trying to help young people use Divine in ways that are healthy and positive for them and the people around them. We also have to follow laws that are different in different places. So, if you\'re under 13, the answer is that you can\'t have your own account today.';

  @override
  String get minorAccountReviewTeenBody =>
      'If this account belongs to someone 13 to 15, use the moderation message or support path to follow the parental consent instructions.';

  @override
  String get minorAccountReviewParentConsentTitle =>
      'If the account will belong to someone 13 to 15';

  @override
  String get minorAccountReviewParentConsentBody =>
      'If parent or guardian contact is not possible or would put someone at risk, email Divine support and let us know.\n\nOtherwise, a parent or guardian should email Divine support with a short private video so our team can review the account and help with next steps.';

  @override
  String get minorAccountReviewParentConsentPauseNote =>
      'This is a pause, not a dead end. The account is not active until Divine support reviews the video.';

  @override
  String get minorAccountReviewParentConsentHonestyTitle =>
      'Why we ask a parent or guardian to be involved';

  @override
  String get minorAccountReviewParentConsentHonestyBody =>
      'Divine has to follow age-related laws around the world. We also know that most technical age gates are imperfect. Rather than pretending the rules don\'t exist or that it\'s cool to lie about your age, we want teens and families to make thoughtful decisions about how best to use Divine. That\'s why, for 13-15 year olds, we ask parents to be part of the account creation process.';

  @override
  String get minorAccountReviewParentConsentLegalBody =>
      'We also have to follow the law, and those rules are different depending on where someone lives. So instead of pretending the rules do not exist, we ask for a parent or guardian to be part of the process.';

  @override
  String get minorAccountReviewParentConsentChecklist =>
      'What the video should show';

  @override
  String get minorAccountReviewParentConsentChecklistKid =>
      'The teen in the video';

  @override
  String get minorAccountReviewParentConsentChecklistPermission =>
      'A parent or guardian speaking on camera';

  @override
  String get minorAccountReviewParentConsentChecklistAgeBand =>
      'A clear statement that the teen is 13 to 15 and has permission to use Divine';

  @override
  String get minorAccountReviewParentConsentChecklistSupervision =>
      'A clear statement that the parent or guardian knows about the account and will supervise its use';

  @override
  String get minorAccountReviewParentConsentPrivacy => 'How to send it';

  @override
  String get minorAccountReviewParentConsentNeverPost =>
      'Attach the video when you email Divine support';

  @override
  String get minorAccountReviewParentConsentDoNotSave =>
      'Keep the video private and do not post it in the app';

  @override
  String get minorAccountReviewParentConsentOneMove =>
      'Our team will review it and reply with next steps';

  @override
  String get minorAccountReviewParentConsentEmailCta => 'Email Divine support';

  @override
  String get minorAccountReviewParentConsentEmailSubject =>
      'Divine Greenlight review help (ages 13-15)';

  @override
  String get minorAccountReviewParentConsentEmailBody =>
      'Hi Divine support,\n\nI am contacting Divine about Divine Greenlight for a teen who is 13-15.\n\nI have attached a short private video that shows:\n- the teen\n- a parent or guardian speaking on camera\n- that the teen has permission to use Divine\n- that the parent or guardian knows about the account and will supervise its use\n\nCountry/ies of residence:\n\nHelpful context:\n\nThanks.';

  @override
  String get minorAccountReviewParentSupportInstructions =>
      'Parent Support Instructions';

  @override
  String get minorAccountReviewContinue => 'Continue';

  @override
  String get minorAccountReviewErrorTitle =>
      'We could not load your account review status.';

  @override
  String get minorAccountReviewErrorBody => 'Please try again in a moment.';

  @override
  String get minorAccountReviewTryAgain => 'Try Again';

  @override
  String get minorAccountReviewParentContactTitle => 'Parent Contact';

  @override
  String get minorAccountReviewParentContactHeading =>
      'Add a parent or guardian email';

  @override
  String minorAccountReviewParentContactBody(String caseId) {
    return 'We will use this address for the parental consent review on case $caseId.';
  }

  @override
  String get minorAccountReviewParentContactFieldLabel =>
      'Parent or guardian email';

  @override
  String get minorAccountReviewSubmitting => 'Submitting...';

  @override
  String get minorAccountReviewSubmitEmail => 'Submit Email';

  @override
  String get minorAccountReviewBackToReview => 'Back to Account Review';

  @override
  String get minorAccountReviewSubmissionReceivedTitle => 'Email submitted';

  @override
  String minorAccountReviewSubmissionReceivedBody(String email) {
    return 'We submitted $email for review. We\'ll email this address to confirm. Once your parent or guardian responds, your case will move forward. Use Check Again from the account review screen for updates.';
  }

  @override
  String get minorAccountReviewSubmissionReceivedLocalBody =>
      'We received the parent or guardian contact for this account. Our team will review it before restoring access.';

  @override
  String get minorAccountReviewMissingCase =>
      'We could not find an active review case for this account.';

  @override
  String get minorAccountReviewParentContactError =>
      'Could not submit the parent email. Please try again.';

  @override
  String get minorAccountReviewUnder13SupportTitle => 'Parent Support';

  @override
  String get minorAccountReviewUnder13Heading =>
      'A parent or guardian must contact Divine';

  @override
  String get minorAccountReviewUnder13SupportBody =>
      'For likely under-13 accounts, the next step is parent or guardian contact by email.';

  @override
  String get minorAccountReviewSupportEmailLabel => 'Support email';

  @override
  String get minorAccountReviewCopySupportEmail => 'Copy support email';

  @override
  String get minorAccountReviewSupportEmailCopied => 'Support email copied';

  @override
  String get minorAccountReviewCopyCaseId => 'Copy case ID';

  @override
  String get minorAccountReviewCaseIdCopied => 'Case ID copied';

  @override
  String get minorAccountReviewUnavailable => 'Unavailable';

  @override
  String get minorAccountReviewUnder13Instructions =>
      'Ask the parent or guardian to include the case ID and explain that they are contacting Divine about this account review.';

  @override
  String minorAccountReviewUnder13EmailSubject(String caseId) {
    return 'Under-13 account review for case $caseId';
  }

  @override
  String minorAccountReviewUnder13EmailBody(String caseId) {
    return 'Hi Divine support,\n\nI am the parent or guardian for a child under 13 and I am contacting Divine about account review case $caseId.\n\nThanks.';
  }

  @override
  String get devOptionsMinorReviewSimulationTitle =>
      'Minor Account Review Simulation';

  @override
  String get devOptionsMinorReviewCurrentStateLabel => 'Current state';

  @override
  String devOptionsMinorReviewStateRestricted(String state) {
    return 'Restricted ($state)';
  }

  @override
  String get devOptionsMinorReviewStateActive => 'Active';

  @override
  String get devOptionsMinorReviewStateLoading => 'Loading...';

  @override
  String get devOptionsMinorReviewStateError => 'Error loading state';

  @override
  String get devOptionsMinorReviewClearTitle => 'Clear simulation override';

  @override
  String get devOptionsMinorReviewClearSubtitle =>
      'Use backend or default active state again';

  @override
  String get devOptionsMinorReviewTeenTitle => 'Simulate 13-15 review case';

  @override
  String get devOptionsMinorReviewTeenSubtitle =>
      'Restricted account with parent contact path';

  @override
  String get devOptionsMinorReviewUnder13Title =>
      'Simulate under-13 support case';

  @override
  String get devOptionsMinorReviewUnder13Subtitle =>
      'Restricted account with parent-email-only instructions';

  @override
  String get devOptionsMinorReviewClearedToast =>
      'Minor account review simulation cleared';

  @override
  String get devOptionsMinorReviewTeenEnabledToast =>
      'Simulated 13-15 review case enabled';

  @override
  String get devOptionsMinorReviewUnder13EnabledToast =>
      'Simulated under-13 support case enabled';

  @override
  String get commentsRecordVideoButtonLabel => 'Rekam komentar video';

  @override
  String get commentsOpenVideoLabel => 'Buka komentar video';

  @override
  String get commentsMuteVideoReplyLabel => 'Bisukan balasan video';

  @override
  String get commentsUnmuteVideoReplyLabel => 'Aktifkan suara balasan video';

  @override
  String get commentsOpenReplyParentLabel => 'Buka video yang dibalas ini';

  @override
  String get commentsReplyParentSectionTitle => 'Menanggapi';

  @override
  String commentsReplyParentLabel(String target) {
    return 'Balas $target';
  }

  @override
  String get commentsReplyParentFallbackLabel => 'Balas video';

  @override
  String verifiedAccountChipSemanticLabel(String platform, String identity) {
    return 'Akun $platform terverifikasi: $identity';
  }

  @override
  String get profileEditVerifiedAccountsTitle => 'Akun terverifikasi';

  @override
  String get profileEditGetVerifiedCta => 'Verifikasi diri';

  @override
  String get profileEditGetVerifiedSubtitle =>
      'Hubungkan akun media sosialmu biar orang tahu ini memang kamu.';

  @override
  String profileWebsiteSemanticLabel(String url) {
    return 'Visit website: $url';
  }

  @override
  String get profileCouldNotOpenWebsite => 'Could not open website';

  @override
  String get videoMetadataEditCoverTitle => 'Edit sampul';

  @override
  String get videoMetadataEditCoverCloseSemanticLabel => 'Tutup editor sampul';

  @override
  String get videoMetadataEditCoverConfirmSemanticLabel =>
      'Konfirmasi pilihan sampul';

  @override
  String get videoMetadataEditCoverStripSemanticLabel =>
      'Gulir video untuk memilih bingkai sampul';

  @override
  String get videoMetadataTagsPickerSearchHint => 'Cari atau tambahkan tag';

  @override
  String get videoMetadataTagsPickerEmptyHint =>
      'Tambahkan tag agar orang menemukan videomu';

  @override
  String get videoMetadataTagsPickerNoResults => 'Tidak ada tag yang cocok';

  @override
  String videoMetadataTagsPickerAddTag(String tag) {
    return 'Tambahkan \"#$tag\"';
  }

  @override
  String get authMinAgeNotice => 'Divine Greenlight';

  @override
  String get authUnder16Prefix => 'Not 16 yet? That\'s OK. ';

  @override
  String get authUnder16ChoicesCta => 'Here are your choices.';

  @override
  String get minorAccountReviewUnder13WhyTitle => 'Here\'s why';

  @override
  String get generalSettingsHoldToRecord => 'Tahan untuk merekam';

  @override
  String get generalSettingsHoldToRecordSubtitle =>
      'Rekaman dimulai saat menahan dan berhenti saat dilepas';

  @override
  String get soundsPreviewFailedGeneric => 'Gagal memutar pratinjau';

  @override
  String uploadPublishedCountMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count video dipublikasikan ke profilmu',
      one: 'Video dipublikasikan ke profilmu',
    );
    return '$_temp0';
  }

  @override
  String get dmMessageSendLabel => 'Send message';

  @override
  String get emojiPickerSearchHint => 'Cari';

  @override
  String get emojiCategoryRecent => 'Terbaru';

  @override
  String get emojiCategorySmileys => 'Smiley & Orang';

  @override
  String get emojiCategoryAnimals => 'Hewan & Alam';

  @override
  String get emojiCategoryFood => 'Makanan & Minuman';

  @override
  String get emojiCategoryActivities => 'Aktivitas';

  @override
  String get emojiCategoryTravel => 'Perjalanan & Tempat';

  @override
  String get emojiCategoryObjects => 'Objek';

  @override
  String get emojiCategorySymbols => 'Simbol';

  @override
  String get emojiCategoryFlags => 'Bendera';

  @override
  String get videoEditorMarkerLabel => 'Penanda';

  @override
  String get videoEditorAddTimelineMarkerSemanticLabel =>
      'Tambahkan penanda timeline';

  @override
  String get videoEditorRemoveTimelineMarkerSemanticLabel =>
      'Hapus penanda timeline';

  @override
  String get videoEditorDeleteTimelineMarkerTitle => 'Hapus penanda?';

  @override
  String get videoEditorDeleteTimelineMarkerSubtitle =>
      'Ini menghapus penanda dari timeline. Editan Anda tetap utuh.';

  @override
  String get videoEditorVolumeLongPressHint =>
      'Bisukan atau aktifkan semua trek';

  @override
  String get videoEditorSplitFailed => 'Pembagian gagal. Silakan coba lagi.';

  @override
  String get videoEditEditSubtitles => 'Edit subtitles';

  @override
  String get subtitleEditorTitle => 'Edit subtitles';

  @override
  String get subtitleEditorSave => 'Save';

  @override
  String get subtitleEditorProcessing =>
      'Subtitles are still being generated. Check back in a moment.';

  @override
  String get subtitleEditorLoadError => 'Couldn\'t load subtitles. Try again.';

  @override
  String get subtitleEditorSaveSuccess => 'Subtitles updated';

  @override
  String get subtitleEditorSaveError => 'Couldn\'t save subtitles. Try again.';

  @override
  String get subtitleEditorRetry => 'Retry';

  @override
  String get subtitleEditorCueHint => 'Caption text';
}
