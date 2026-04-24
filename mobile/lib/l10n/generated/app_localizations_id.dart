// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

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
  String get profileBlockedAccountNotAvailable => 'Akun ini tidak tersedia';

  @override
  String profileErrorPrefix(Object error) {
    return 'Kesalahan: $error';
  }

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
  String get profileNoSavedVideosTitle => 'Nothing saved yet';

  @override
  String get profileSavedOwnEmpty =>
      'Bookmark videos from the share sheet and they\'ll show up here.';

  @override
  String get profileErrorLoadingSaved => 'Error loading saved videos';

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
  String get profileLoadingTitle => 'Memuat profil...';

  @override
  String get profileLoadingSubtitle => 'Ini mungkin butuh beberapa saat';

  @override
  String get profileLoadingVideos => 'Memuat video...';

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
  String profileSetupCameraAccessFailed(Object error) {
    return 'Akses kamera gagal: $error';
  }

  @override
  String get profileSetupGotItButton => 'Mengerti';

  @override
  String profileSetupUploadFailedGeneric(Object error) {
    return 'Gagal mengunggah gambar: $error';
  }

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
      'Username harus 3-20 karakter';

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
  String get shareFailedToAddBookmark => 'Gagal menambahkan bookmark';

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
  String get videoOverlayOpenMetadataFromTitle => 'Open video details';

  @override
  String get videoOverlayOpenMetadataFromDescription => 'Open video details';

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
  String get notificationSettingsSystem => 'Sistem';

  @override
  String get notificationSettingsSystemSubtitle =>
      'Pembaruan aplikasi dan pesan sistem';

  @override
  String get notificationSettingsPushNotificationsSection => 'Notifikasi Push';

  @override
  String get notificationSettingsPushNotifications => 'Notifikasi Push';

  @override
  String get notificationSettingsPushNotificationsSubtitle =>
      'Terima notifikasi saat aplikasi tertutup';

  @override
  String get notificationSettingsSound => 'Suara';

  @override
  String get notificationSettingsSoundSubtitle =>
      'Mainkan suara untuk notifikasi';

  @override
  String get notificationSettingsVibration => 'Getaran';

  @override
  String get notificationSettingsVibrationSubtitle => 'Getar untuk notifikasi';

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
  String get authSignInDifferentAccount => 'Masuk dengan akun yang berbeda';

  @override
  String get authSignBackIn => 'Masuk kembali';

  @override
  String get authTermsPrefix =>
      'Dengan memilih opsi di atas, kamu mengonfirmasi bahwa kamu berusia minimal 16 tahun dan setuju dengan ';

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
  String get authForgotPassword => 'Lupa kata sandi?';

  @override
  String get authImportNostrKey => 'Impor kunci Nostr';

  @override
  String get authConnectSignerApp => 'Hubungkan dengan aplikasi signer';

  @override
  String get authSignInWithAmber => 'Masuk dengan Amber';

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
  String get badgeExplanationClose => 'Tutup';

  @override
  String get badgeExplanationOriginalVineArchive => 'Arsip Vine Asli';

  @override
  String get badgeExplanationCameraProof => 'Bukti Kamera';

  @override
  String get badgeExplanationAuthenticitySignals => 'Sinyal Keaslian';

  @override
  String get badgeExplanationVineArchiveIntro =>
      'Video ini adalah Vine asli yang dipulihkan dari Internet Archive.';

  @override
  String get badgeExplanationVineArchiveHistory =>
      'Sebelum Vine ditutup pada 2017, ArchiveTeam dan Internet Archive bekerja untuk melestarikan jutaan Vine untuk anak cucu. Konten ini adalah bagian dari upaya pelestarian bersejarah itu.';

  @override
  String badgeExplanationOriginalStats(int loops) {
    return 'Statistik asli: $loops loop';
  }

  @override
  String get badgeExplanationLearnVineArchive =>
      'Pelajari lebih lanjut tentang pelestarian arsip Vine';

  @override
  String get badgeExplanationLearnProofmode =>
      'Pelajari lebih lanjut tentang verifikasi Proofmode';

  @override
  String get badgeExplanationLearnAuthenticity =>
      'Pelajari lebih lanjut tentang sinyal keaslian Divine';

  @override
  String get badgeExplanationInspectProofCheck =>
      'Periksa dengan Alat ProofCheck';

  @override
  String get badgeExplanationInspectMedia => 'Periksa detail media';

  @override
  String get badgeExplanationProofmodeVerified =>
      'Keaslian video ini diverifikasi menggunakan teknologi Proofmode.';

  @override
  String get badgeExplanationDivineHostedHumanMade =>
      'Video ini di-host di Divine dan deteksi AI menunjukkan kemungkinan buatan manusia, tapi tidak mencakup data verifikasi kamera kriptografis.';

  @override
  String get badgeExplanationHumanMadeNoCrypto =>
      'Deteksi AI menunjukkan video ini kemungkinan buatan manusia, meskipun tidak mencakup data verifikasi kamera kriptografis.';

  @override
  String get badgeExplanationDivineHostedNoCrypto =>
      'Video ini di-host di Divine, tapi belum mencakup data verifikasi kamera kriptografis.';

  @override
  String get badgeExplanationExternalNoCrypto =>
      'Video ini di-host di luar Divine dan tidak mencakup data verifikasi kamera kriptografis.';

  @override
  String get badgeExplanationDeviceAttestation => 'Atestasi perangkat';

  @override
  String get badgeExplanationPgpSignature => 'Tanda tangan PGP';

  @override
  String get badgeExplanationC2paCredentials => 'Kredensial Konten C2PA';

  @override
  String get badgeExplanationProofManifest => 'Manifes bukti';

  @override
  String get badgeExplanationAiDetection => 'Deteksi AI';

  @override
  String get badgeExplanationAiNotScanned => 'Scan AI: Belum dipindai';

  @override
  String get badgeExplanationNoScanResults =>
      'Belum ada hasil pindai yang tersedia.';

  @override
  String get badgeExplanationCheckAiGenerated => 'Cek apakah dihasilkan AI';

  @override
  String badgeExplanationAiLikelihood(int percentage) {
    return '$percentage% kemungkinan dihasilkan AI';
  }

  @override
  String badgeExplanationScannedBy(String source) {
    return 'Dipindai oleh: $source';
  }

  @override
  String get badgeExplanationVerifiedByModerator =>
      'Diverifikasi oleh moderator manusia';

  @override
  String get badgeExplanationVerificationPlatinum =>
      'Platinum: Atestasi hardware perangkat, tanda tangan kriptografis, Kredensial Konten (C2PA), dan scan AI mengonfirmasi asal manusia.';

  @override
  String get badgeExplanationVerificationGold =>
      'Emas: Diambil dengan perangkat asli yang memiliki atestasi hardware, tanda tangan kriptografis, dan Kredensial Konten (C2PA).';

  @override
  String get badgeExplanationVerificationSilver =>
      'Perak: Tanda tangan kriptografis membuktikan video ini tidak diubah sejak direkam.';

  @override
  String get badgeExplanationVerificationBronze =>
      'Perunggu: Tanda tangan metadata dasar tersedia.';

  @override
  String get badgeExplanationVerificationSilverAiScan =>
      'Perak: Scan AI mengonfirmasi video ini kemungkinan dibuat manusia.';

  @override
  String get badgeExplanationNoVerification =>
      'Tidak ada data verifikasi untuk video ini.';

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
  String get shareMenuVideoUpdated => 'Video berhasil diperbarui';

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
  String get feedForYouEmpty =>
      'Feed Untuk Anda kamu kosong.\nJelajahi video dan ikuti kreator untuk membentuknya.';

  @override
  String get feedFollowingEmpty =>
      'Belum ada video dari orang yang kamu ikuti.\nTemukan kreator yang kamu suka dan ikuti mereka.';

  @override
  String get feedLatestEmpty =>
      'Belum ada video baru.\nCek lagi sebentar lagi.';

  @override
  String get feedExploreVideos => 'Jelajahi Video';

  @override
  String get feedExternalVideoSlow => 'Video eksternal memuat lambat';

  @override
  String get feedSkip => 'Lewati';

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
  String get reportReasonSpam => 'Spam atau Konten Tidak Diinginkan';

  @override
  String get reportReasonHarassment => 'Pelecehan, Perundungan, atau Ancaman';

  @override
  String get reportReasonViolence => 'Konten Kekerasan atau Ekstremis';

  @override
  String get reportReasonSexualContent => 'Konten Seksual atau Dewasa';

  @override
  String get reportReasonCopyright => 'Pelanggaran Hak Cipta';

  @override
  String get reportReasonFalseInfo => 'Informasi Salah';

  @override
  String get reportReasonCsam => 'Pelanggaran Keamanan Anak';

  @override
  String get reportReasonAiGenerated => 'Konten Dihasilkan AI';

  @override
  String get reportReasonOther => 'Pelanggaran Kebijakan Lainnya';

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
  String get reportLearnMore => 'Pelajari Lebih Lanjut';

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
  String get cameraPermissionNotNow => 'Nanti Saja';

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
  String get profileSetupUploadSuccess => 'Foto profil berhasil diunggah!';

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
  String discoverListsFailedToUpdateSubscription(String error) {
    return 'Gagal memperbarui langganan: $error';
  }

  @override
  String get commonRetry => 'Coba lagi';

  @override
  String get commonNext => 'Berikutnya';

  @override
  String get commonDelete => 'Hapus';

  @override
  String get commonCancel => 'Batal';

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
  String get proofmodeCheckAiGenerated => 'Periksa apakah dibuat oleh AI';

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
  String get routerInvalidCreator => 'Kreator tidak valid';

  @override
  String get routerInvalidHashtagRoute => 'Rute hashtag tidak valid';

  @override
  String get categoryGalleryCouldNotLoadVideos => 'Tidak dapat memuat video';

  @override
  String get categoriesCouldNotLoadCategories => 'Tidak dapat memuat kategori';

  @override
  String get notificationFollowBack => 'Ikuti balik';

  @override
  String get followingFailedToLoadList => 'Gagal memuat daftar mengikuti';

  @override
  String get followersFailedToLoadList => 'Gagal memuat daftar pengikut';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String blossomFailedToSaveSettings(String error) {
    return 'Gagal menyimpan pengaturan: $error';
  }

  @override
  String get blueskyFailedToUpdateCrosspost =>
      'Gagal memperbarui pengaturan crosspost';

  @override
  String get invitesTitle => 'Undang Teman';

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
  String get videoRecorderToggleGridLabel => 'Ganti grid';

  @override
  String get videoRecorderToggleGhostFrameLabel => 'Ganti frame hantu';

  @override
  String get videoRecorderGhostFrameEnabled => 'Frame hantu diaktifkan';

  @override
  String get videoRecorderGhostFrameDisabled => 'Frame hantu dinonaktifkan';

  @override
  String get videoRecorderClipDeletedMessage => 'Klip dihapus';

  @override
  String get videoRecorderCloseLabel => 'Tutup perekam video';

  @override
  String get videoRecorderContinueToEditorLabel => 'Lanjutkan ke editor video';

  @override
  String get videoRecorderCaptureCloseLabel => 'Tutup';

  @override
  String get videoRecorderCaptureNextLabel => 'Berikutnya';

  @override
  String get videoRecorderToggleFlashLabel => 'Ganti flash';

  @override
  String get videoRecorderCycleTimerLabel => 'Timer siklus';

  @override
  String get videoRecorderToggleAspectRatioLabel => 'Ganti rasio aspek';

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
  String get videoEditorVolumeLabel => 'Volume';

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
  String get videoEditorCustomAudioLabel => 'Audio kustom';

  @override
  String get videoEditorPlaySemanticLabel => 'Putar';

  @override
  String get videoEditorPauseSemanticLabel => 'Jeda';

  @override
  String get videoEditorMuteAudioSemanticLabel => 'Matikan suara';

  @override
  String get videoEditorUnmuteAudioSemanticLabel => 'Aktifkan suara';

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
  String get videoEditorFinishTimelineEditingSemanticLabel =>
      'Selesai mengedit timeline';

  @override
  String get videoEditorSortNewest => 'Terbaru';

  @override
  String get videoEditorSortLongest => 'Terpanjang';

  @override
  String get videoEditorSortShortest => 'Terpendek';

  @override
  String videoEditorSortBySemanticLabel(String option) {
    return 'Urutkan berdasarkan $option. Ketuk untuk mengubah urutan';
  }

  @override
  String get videoEditorAudioPlayPreviewSemanticLabel => 'Putar pratinjau';

  @override
  String get videoEditorAudioPausePreviewSemanticLabel => 'Jeda pratinjau';

  @override
  String get videoEditorAudioUntitledSound => 'Suara tanpa judul';

  @override
  String get videoEditorAudioSelectSoundSemanticLabel => 'Pilih suara';

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
  String get videoEditorAudioNoSoundsFoundTitle => 'Suara tidak ditemukan';

  @override
  String get videoEditorAudioNoSoundsFoundSubtitle =>
      'Coba kata kunci pencarian lain';

  @override
  String get videoEditorAudioFailedToLoadTitle => 'Gagal memuat suara';

  @override
  String get videoEditorAudioSegmentInstruction =>
      'Pilih segmen audio untuk videomu';

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
  String get metadataCaptionsLabel => 'Teks';

  @override
  String get metadataCaptionsEnabledSemantics =>
      'Teks diaktifkan untuk semua video';

  @override
  String get metadataCaptionsDisabledSemantics =>
      'Teks dinonaktifkan untuk semua video';
}
