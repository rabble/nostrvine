// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'Divine';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get settingsSecureAccount => 'أمّن حسابك';

  @override
  String get settingsSessionExpired => 'انتهت الجلسة';

  @override
  String get settingsSessionExpiredSubtitle =>
      'سجّل الدخول مرّة أخرى لاستعادة الوصول الكامل';

  @override
  String get settingsCreatorAnalytics => 'تحليلات الصانع';

  @override
  String get settingsSupportCenter => 'مركز الدعم';

  @override
  String get settingsNotifications => 'الإشعارات';

  @override
  String get settingsContentPreferences => 'تفضيلات المحتوى';

  @override
  String get settingsModerationControls => 'ضوابط الإشراف';

  @override
  String get settingsBlueskyPublishing => 'النشر على Bluesky';

  @override
  String get settingsBlueskyPublishingSubtitle =>
      'أدر النشر المتزامن إلى Bluesky';

  @override
  String get settingsNostrSettings => 'إعدادات Nostr';

  @override
  String get settingsIntegratedApps => 'التطبيقات المدمجة';

  @override
  String get settingsIntegratedAppsSubtitle =>
      'تطبيقات خارجية موثوقة تعمل داخل Divine';

  @override
  String get settingsExperimentalFeatures => 'ميزات تجريبية';

  @override
  String get settingsExperimentalFeaturesSubtitle =>
      'تعديلات قد تتعثّر—جرّبها إن كنت فضوليًا.';

  @override
  String get settingsLegal => 'الأمور القانونية';

  @override
  String get settingsIntegrationPermissions => 'صلاحيات التطبيقات المدمجة';

  @override
  String get settingsIntegrationPermissionsSubtitle =>
      'راجع وألغِ موافقات التطبيقات المخزّنة';

  @override
  String settingsVersion(String version) {
    return 'الإصدار $version';
  }

  @override
  String get settingsVersionEmpty => 'الإصدار';

  @override
  String get settingsDeveloperModeAlreadyEnabled => 'وضع المطوّر مُفعّل مسبقًا';

  @override
  String get settingsDeveloperModeEnabled => 'تم تفعيل وضع المطوّر!';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    return '$count نقرة إضافية لتفعيل وضع المطوّر';
  }

  @override
  String get settingsInvites => 'الدعوات';

  @override
  String get settingsSwitchAccount => 'تبديل الحساب';

  @override
  String get settingsAddAnotherAccount => 'إضافة حساب آخر';

  @override
  String get settingsUnsavedDraftsTitle => 'مسودات غير محفوظة';

  @override
  String settingsUnsavedDraftsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مسودة غير محفوظة',
      many: '$count مسودة غير محفوظة',
      few: '$count مسودات غير محفوظة',
      two: 'مسودتان غير محفوظتين',
      one: 'مسودة واحدة غير محفوظة',
      zero: 'مسودات غير محفوظة',
    );
    return 'لديك $_temp0. تبديل الحسابات سيحتفظ بها، لكن قد ترغب في نشرها أو مراجعتها أولاً.';
  }

  @override
  String get settingsCancel => 'إلغاء';

  @override
  String get settingsSwitchAnyway => 'تبديل على أي حال';

  @override
  String get settingsAppVersionLabel => 'إصدار التطبيق';

  @override
  String get settingsAppLanguage => 'لغة التطبيق';

  @override
  String settingsAppLanguageDeviceDefault(String language) {
    return '$language (افتراضي الجهاز)';
  }

  @override
  String get settingsAppLanguageTitle => 'لغة التطبيق';

  @override
  String get settingsAppLanguageDescription => 'اختر لغة واجهة التطبيق';

  @override
  String get settingsAppLanguageUseDeviceLanguage => 'استخدام لغة الجهاز';

  @override
  String get contentPreferencesTitle => 'تفضيلات المحتوى';

  @override
  String get contentPreferencesContentFilters => 'مرشّحات المحتوى';

  @override
  String get contentPreferencesContentFiltersSubtitle =>
      'أدر مرشّحات تحذيرات المحتوى';

  @override
  String get contentPreferencesContentLanguage => 'لغة المحتوى';

  @override
  String contentPreferencesContentLanguageDeviceDefault(String language) {
    return '$language (افتراضي الجهاز)';
  }

  @override
  String get contentPreferencesTagYourVideos =>
      'وسِم فيديوهاتك بلغة حتى يتمكّن المشاهدون من تصفية المحتوى.';

  @override
  String get contentPreferencesUseDeviceLanguage =>
      'استخدام لغة الجهاز (افتراضي)';

  @override
  String get contentPreferencesAudioSharing => 'إتاحة صوتي للاستخدام';

  @override
  String get contentPreferencesAudioSharingSubtitle =>
      'عند التفعيل، يمكن للآخرين استخدام الصوت من فيديوهاتك';

  @override
  String get contentPreferencesAccountLabels => 'وسوم الحساب';

  @override
  String get contentPreferencesAccountLabelsEmpty => 'ضع وسومًا لمحتواك';

  @override
  String get contentPreferencesAccountContentLabels => 'وسوم محتوى الحساب';

  @override
  String get contentPreferencesClearAll => 'مسح الكل';

  @override
  String get contentPreferencesSelectAllThatApply =>
      'اختر كل ما ينطبق على حسابك';

  @override
  String get contentPreferencesDoneNoLabels => 'تم (بدون وسوم)';

  @override
  String contentPreferencesDoneCount(int count) {
    return 'تم ($count محدد)';
  }

  @override
  String get contentPreferencesAudioInputDevice => 'جهاز إدخال الصوت';

  @override
  String get contentPreferencesAutoRecommended => 'تلقائي (موصى به)';

  @override
  String get contentPreferencesAutoSelectsBest =>
      'يختار تلقائيًا أفضل ميكروفون';

  @override
  String get contentPreferencesSelectAudioInput => 'حدد إدخال الصوت';

  @override
  String get contentPreferencesUnknownMicrophone => 'ميكروفون غير معروف';

  @override
  String get profileBlockedAccountNotAvailable => 'هذا الحساب غير متاح';

  @override
  String profileErrorPrefix(Object error) {
    return 'خطأ: $error';
  }

  @override
  String get profileInvalidId => 'معرّف الملف الشخصي غير صالح';

  @override
  String profileShareText(String displayName, String npub) {
    return 'شاهد $displayName على Divine!\n\nhttps://divine.video/profile/$npub';
  }

  @override
  String profileShareSubject(String displayName) {
    return '$displayName على Divine';
  }

  @override
  String profileShareFailed(Object error) {
    return 'تعذّرت مشاركة الملف الشخصي: $error';
  }

  @override
  String get profileEditProfile => 'تعديل الملف الشخصي';

  @override
  String get profileCreatorAnalytics => 'تحليلات الصانع';

  @override
  String get profileShareProfile => 'مشاركة الملف الشخصي';

  @override
  String get profileCopyPublicKey => 'نسخ المفتاح العام (npub)';

  @override
  String get profileGetEmbedCode => 'الحصول على كود التضمين';

  @override
  String get profilePublicKeyCopied => 'تم نسخ المفتاح العام إلى الحافظة';

  @override
  String get profileEmbedCodeCopied => 'تم نسخ كود التضمين إلى الحافظة';

  @override
  String get profileRefreshTooltip => 'تحديث';

  @override
  String get profileRefreshSemanticLabel => 'تحديث الملف الشخصي';

  @override
  String get profileMoreTooltip => 'المزيد';

  @override
  String get profileMoreSemanticLabel => 'خيارات إضافية';

  @override
  String get profileFollowingLabel => 'متابع';

  @override
  String get profileFollowLabel => 'متابعة';

  @override
  String get profileBlockedLabel => 'محظور';

  @override
  String get profileFollowersLabel => 'المتابِعون';

  @override
  String get profileFollowingStatLabel => 'يتابِع';

  @override
  String get profileVideosLabel => 'الفيديوهات';

  @override
  String profileFollowerCountUsers(int count) {
    return '$count مستخدم';
  }

  @override
  String profileBlockTitle(String displayName) {
    return 'حظر $displayName؟';
  }

  @override
  String get profileBlockExplanation => 'عند حظر مستخدم:';

  @override
  String get profileBlockBulletHidePosts => 'لن تظهر منشوراته في تغذياتك.';

  @override
  String get profileBlockBulletCantView =>
      'لن يتمكن من رؤية ملفك الشخصي أو متابعتك أو مشاهدة منشوراتك.';

  @override
  String get profileBlockBulletNoNotify => 'لن يتم إبلاغه بهذا التغيير.';

  @override
  String get profileBlockBulletYouCanView =>
      'لا يزال بإمكانك رؤية ملفه الشخصي.';

  @override
  String profileBlockConfirmButton(String displayName) {
    return 'حظر $displayName';
  }

  @override
  String get profileCancelButton => 'إلغاء';

  @override
  String get profileLearnMore => 'اعرف المزيد';

  @override
  String profileUnblockTitle(String displayName) {
    return 'إلغاء حظر $displayName؟';
  }

  @override
  String get profileUnblockExplanation => 'عند إلغاء حظر هذا المستخدم:';

  @override
  String get profileUnblockBulletShowPosts => 'ستظهر منشوراته في تغذياتك.';

  @override
  String get profileUnblockBulletCanView =>
      'سيتمكّن من رؤية ملفك الشخصي ومتابعتك ومشاهدة منشوراتك.';

  @override
  String get profileUnblockBulletNoNotify => 'لن يتم إبلاغه بهذا التغيير.';

  @override
  String get profileLearnMoreAt => 'اعرف المزيد على ';

  @override
  String get profileUnblockButton => 'إلغاء الحظر';

  @override
  String profileUnfollowDisplayName(String displayName) {
    return 'إلغاء متابعة $displayName';
  }

  @override
  String profileBlockDisplayName(String displayName) {
    return 'حظر $displayName';
  }

  @override
  String profileUnblockDisplayName(String displayName) {
    return 'إلغاء حظر $displayName';
  }

  @override
  String get profileUserBlockedTitle => 'تم حظر المستخدم';

  @override
  String get profileUserBlockedContent =>
      'لن ترى محتوى من هذا المستخدم في تغذياتك.';

  @override
  String get profileUserBlockedUnblockHint =>
      'يمكنك إلغاء حظره في أي وقت من ملفه الشخصي أو من الإعدادات > الأمان.';

  @override
  String get profileCloseButton => 'إغلاق';

  @override
  String get profileNoCollabsTitle => 'لا توجد تعاونات بعد';

  @override
  String get profileCollabsOwnEmpty => 'ستظهر هنا الفيديوهات التي تتعاون عليها';

  @override
  String get profileCollabsOtherEmpty =>
      'ستظهر هنا الفيديوهات التي يتعاون عليها';

  @override
  String get profileErrorLoadingCollabs => 'خطأ في تحميل فيديوهات التعاون';

  @override
  String get profileNoCommentsOwnTitle => 'لا توجد تعليقات بعد';

  @override
  String get profileNoCommentsOtherTitle => 'لا توجد تعليقات';

  @override
  String get profileCommentsOwnEmpty => 'ستظهر هنا تعليقاتك وردودك';

  @override
  String get profileCommentsOtherEmpty => 'ستظهر هنا تعليقاته وردوده';

  @override
  String get profileErrorLoadingComments => 'خطأ في تحميل التعليقات';

  @override
  String get profileVideoRepliesSection => 'ردود الفيديو';

  @override
  String get profileCommentsSection => 'التعليقات';

  @override
  String get profileEditLabel => 'تعديل';

  @override
  String get profileLibraryLabel => 'المكتبة';

  @override
  String get profileNoLikedVideosTitle => 'لا توجد فيديوهات معجب بها بعد';

  @override
  String get profileLikedOwnEmpty => 'ستظهر هنا الفيديوهات التي تعجبك';

  @override
  String get profileLikedOtherEmpty => 'ستظهر هنا الفيديوهات التي تعجبه';

  @override
  String get profileErrorLoadingLiked => 'خطأ في تحميل الفيديوهات المعجب بها';

  @override
  String get profileNoRepostsTitle => 'لا توجد إعادات نشر بعد';

  @override
  String get profileRepostsOwnEmpty => 'ستظهر هنا الفيديوهات التي تعيد نشرها';

  @override
  String get profileRepostsOtherEmpty => 'ستظهر هنا الفيديوهات التي يعيد نشرها';

  @override
  String get profileErrorLoadingReposts =>
      'خطأ في تحميل الفيديوهات المعاد نشرها';

  @override
  String get profileLoadingTitle => 'جاري تحميل الملف الشخصي...';

  @override
  String get profileLoadingSubtitle => 'قد يستغرق هذا بضع لحظات';

  @override
  String get profileLoadingVideos => 'جاري تحميل الفيديوهات...';

  @override
  String get profileNoVideosTitle => 'لا توجد فيديوهات بعد';

  @override
  String get profileNoVideosOwnSubtitle => 'شارك أول فيديو لك ليظهر هنا';

  @override
  String get profileNoVideosOtherSubtitle =>
      'لم يشارك هذا المستخدم أي فيديو بعد';

  @override
  String profileVideoThumbnailLabel(int number) {
    return 'صورة مصغّرة للفيديو $number';
  }

  @override
  String get profileShowMore => 'عرض المزيد';

  @override
  String get profileShowLess => 'عرض أقل';

  @override
  String get profileCompleteYourProfile => 'أكمل ملفك الشخصي';

  @override
  String get profileCompleteSubtitle => 'أضف اسمك ونبذة عنك وصورة للبدء';

  @override
  String get profileSetUpButton => 'الإعداد';

  @override
  String get profileVerifyingEmail => 'جاري التحقق من البريد...';

  @override
  String profileCheckEmailVerification(String email) {
    return 'تحقّق من $email للحصول على رابط التحقق';
  }

  @override
  String get profileWaitingForVerification => 'في انتظار التحقق من البريد';

  @override
  String get profileVerificationFailed => 'فشل التحقق';

  @override
  String get profilePleaseTryAgain => 'يرجى المحاولة مرّة أخرى';

  @override
  String get profileSecureYourAccount => 'أمّن حسابك';

  @override
  String get profileSecureSubtitle =>
      'أضف بريدًا وكلمة مرور لاستعادة حسابك من أي جهاز';

  @override
  String get profileRetryButton => 'إعادة المحاولة';

  @override
  String get profileRegisterButton => 'تسجيل';

  @override
  String get profileSessionExpired => 'انتهت الجلسة';

  @override
  String get profileSignInToRestore =>
      'سجّل الدخول مرّة أخرى لاستعادة الوصول الكامل';

  @override
  String get profileSignInButton => 'تسجيل الدخول';

  @override
  String get profileDismissTooltip => 'تجاهل';

  @override
  String get profileLinkCopied => 'تم نسخ رابط الملف الشخصي';

  @override
  String get profileSetupEditProfileTitle => 'تعديل الملف الشخصي';

  @override
  String get profileSetupBackLabel => 'رجوع';

  @override
  String get profileSetupAboutNostr => 'عن Nostr';

  @override
  String get profileSetupProfilePublished => 'تم نشر الملف الشخصي بنجاح!';

  @override
  String get profileSetupCreateNewProfile => 'إنشاء ملف شخصي جديد؟';

  @override
  String get profileSetupNoExistingProfile =>
      'لم نجد ملفًا موجودًا على المحولات الخاصة بك. النشر سينشئ ملفًا جديدًا. هل تريد المتابعة؟';

  @override
  String get profileSetupPublishButton => 'نشر';

  @override
  String get profileSetupUsernameTaken =>
      'تم أخذ اسم المستخدم للتو. يرجى اختيار اسم آخر.';

  @override
  String get profileSetupClaimFailed =>
      'تعذّرت المطالبة باسم المستخدم. حاول مرّة أخرى.';

  @override
  String get profileSetupPublishFailed =>
      'تعذّر نشر الملف الشخصي. حاول مرّة أخرى.';

  @override
  String get profileSetupDisplayNameLabel => 'الاسم المعروض';

  @override
  String get profileSetupDisplayNameHint => 'كيف يجب أن يعرفك الناس؟';

  @override
  String get profileSetupDisplayNameHelper =>
      'أي اسم أو لقب تريد. لا يلزم أن يكون فريدًا.';

  @override
  String get profileSetupDisplayNameRequired => 'يرجى إدخال اسم معروض';

  @override
  String get profileSetupBioLabel => 'نبذة (اختيارية)';

  @override
  String get profileSetupBioHint => 'أخبر الناس عن نفسك...';

  @override
  String get profileSetupPublicKeyLabel => 'المفتاح العام (npub)';

  @override
  String get profileSetupUsernameLabel => 'اسم المستخدم (اختياري)';

  @override
  String get profileSetupUsernameHint => 'username';

  @override
  String get profileSetupUsernameHelper => 'هويتك الفريدة على Divine';

  @override
  String get profileSetupProfileColorLabel => 'لون الملف الشخصي (اختياري)';

  @override
  String get profileSetupSaveButton => 'حفظ';

  @override
  String get profileSetupSavingButton => 'جاري الحفظ...';

  @override
  String get profileSetupImageUrlTitle => 'إضافة رابط صورة';

  @override
  String get profileSetupPictureUploaded => 'تم رفع صورة الملف الشخصي بنجاح!';

  @override
  String get profileSetupImageSelectionFailed =>
      'فشل اختيار الصورة. يرجى لصق رابط الصورة أدناه بدلاً من ذلك.';

  @override
  String profileSetupCameraAccessFailed(Object error) {
    return 'فشل الوصول إلى الكاميرا: $error';
  }

  @override
  String get profileSetupGotItButton => 'فهمت';

  @override
  String profileSetupUploadFailedGeneric(Object error) {
    return 'فشل رفع الصورة: $error';
  }

  @override
  String get profileSetupUploadNetworkError =>
      'خطأ في الشبكة: يرجى التحقق من اتصالك والمحاولة مرّة أخرى.';

  @override
  String get profileSetupUploadAuthError =>
      'خطأ في المصادقة: حاول تسجيل الخروج ثم الدخول مجددًا.';

  @override
  String get profileSetupUploadFileTooLarge =>
      'الملف كبير جدًا: يرجى اختيار صورة أصغر (10 ميغابايت كحد أقصى).';

  @override
  String get profileSetupUsernameChecking => 'جاري التحقق من التوفر...';

  @override
  String get profileSetupUsernameAvailable => 'اسم المستخدم متاح!';

  @override
  String get profileSetupUsernameTakenIndicator => 'اسم المستخدم مأخوذ مسبقًا';

  @override
  String get profileSetupUsernameReserved => 'اسم المستخدم محجوز';

  @override
  String get profileSetupContactSupport => 'اتصل بالدعم';

  @override
  String get profileSetupCheckAgain => 'تحقّق مجددًا';

  @override
  String get profileSetupUsernameBurned => 'اسم المستخدم هذا لم يعد متاحًا';

  @override
  String get profileSetupUsernameInvalidFormat =>
      'يُسمح بالأحرف والأرقام والواصلات فقط';

  @override
  String get profileSetupUsernameInvalidLength =>
      'يجب أن يتراوح طول اسم المستخدم بين 3 و 20 حرفًا';

  @override
  String get profileSetupUsernameNetworkError =>
      'تعذّر التحقق من التوفر. حاول مرّة أخرى.';

  @override
  String get profileSetupUsernameInvalidFormatGeneric =>
      'تنسيق اسم المستخدم غير صالح';

  @override
  String get profileSetupUsernameCheckFailed => 'تعذّر التحقق من التوفر';

  @override
  String get profileSetupUsernameReservedTitle => 'اسم المستخدم محجوز';

  @override
  String profileSetupUsernameReservedBody(String username) {
    return 'الاسم $username محجوز. أخبرنا لماذا يجب أن يكون لك.';
  }

  @override
  String get profileSetupUsernameReservedHint =>
      'مثل: هو اسم علامتي التجارية، اسم الشهرة، إلخ.';

  @override
  String get profileSetupUsernameReservedCheckHint =>
      'هل تواصلت مع الدعم بالفعل؟ انقر على \"تحقّق مجددًا\" لترى إن كان قد أُفرج عنه لك.';

  @override
  String get profileSetupSupportRequestSent =>
      'تم إرسال طلب الدعم! سنرد عليك قريبًا.';

  @override
  String get profileSetupCouldntOpenEmail =>
      'تعذّر فتح البريد. أرسل إلى: names@divine.video';

  @override
  String get profileSetupSendRequest => 'إرسال الطلب';

  @override
  String get profileSetupPickColorTitle => 'اختر لونًا';

  @override
  String get profileSetupSelectButton => 'اختيار';

  @override
  String get profileSetupUseOwnNip05 => 'استخدم عنوان NIP-05 الخاص بك';

  @override
  String get profileSetupNip05AddressLabel => 'عنوان NIP-05';

  @override
  String get profileSetupProfilePicturePreview => 'معاينة صورة الملف الشخصي';

  @override
  String get nostrInfoIntroBuiltOn => 'DiVine مبني على Nostr،';

  @override
  String get nostrInfoIntroDescription =>
      ' بروتوكول مفتوح مقاوم للرقابة يسمح للناس بالتواصل عبر الإنترنت دون الاعتماد على شركة أو منصّة واحدة. ';

  @override
  String get nostrInfoIntroIdentity =>
      'عند التسجيل في Divine، تحصل على هوية Nostr جديدة.';

  @override
  String get nostrInfoOwnership =>
      'Nostr يسمح لك بامتلاك محتواك وهويتك وشبكتك الاجتماعية، والتي يمكنك استخدامها في تطبيقات عديدة. النتيجة خيارات أكثر، واحتكار أقل، وإنترنت اجتماعي أكثر صحة ومرونة.';

  @override
  String get nostrInfoLingo => 'مصطلحات Nostr:';

  @override
  String get nostrInfoNpubLabel => 'npub:';

  @override
  String get nostrInfoNpubDescription =>
      ' عنوان Nostr العام الخاص بك. يمكن مشاركته بأمان ويسمح للآخرين بالعثور عليك أو متابعتك أو مراسلتك عبر تطبيقات Nostr.';

  @override
  String get nostrInfoNsecLabel => 'nsec:';

  @override
  String get nostrInfoNsecDescription =>
      ' مفتاحك الخاص ودليل ملكيتك. يمنحك التحكم الكامل بهويتك في Nostr، لذلك ';

  @override
  String get nostrInfoNsecWarning => 'احتفظ به سريًا دومًا!';

  @override
  String get nostrInfoUsernameLabel => 'اسم مستخدم Nostr:';

  @override
  String get nostrInfoUsernameDescription =>
      ' اسم قابل للقراءة (مثل @name.divine.video) يرتبط بـ npub الخاص بك. يجعل هويتك في Nostr أسهل للتعرّف والتحقق، مثل عنوان البريد الإلكتروني.';

  @override
  String get nostrInfoLearnMoreAt => 'اعرف المزيد على ';

  @override
  String get nostrInfoGotIt => 'فهمت!';

  @override
  String get profileTabRefreshTooltip => 'تحديث';

  @override
  String get videoGridRefreshLabel => 'البحث عن المزيد من الفيديوهات';

  @override
  String get videoGridOptionsTitle => 'خيارات الفيديو';

  @override
  String get videoGridEditVideo => 'تعديل الفيديو';

  @override
  String get videoGridEditVideoSubtitle => 'تحديث العنوان والوصف والوسوم';

  @override
  String get videoGridDeleteVideo => 'حذف الفيديو';

  @override
  String get videoGridDeleteVideoSubtitle =>
      'أزِل هذا الفيديو من Divine. قد يظل ظاهرًا في عملاء Nostr آخرين.';

  @override
  String get videoGridDeleteConfirmTitle => 'حذف الفيديو';

  @override
  String get videoGridDeleteConfirmMessage =>
      'سيتم حذف هذا الفيديو نهائيًا من Divine. قد يظل ظاهرًا في عملاء Nostr الآخرين الذين يستخدمون محولات مختلفة.';

  @override
  String get videoGridDeleteConfirmNote =>
      'سيرسل هذا طلب حذف إلى المحولات. ملاحظة: قد تحتفظ بعض المحولات بنسخ مخزّنة.';

  @override
  String get videoGridDeleteCancel => 'إلغاء';

  @override
  String get videoGridDeleteConfirm => 'حذف';

  @override
  String get videoGridDeletingContent => 'جاري حذف المحتوى...';

  @override
  String get videoGridDeleteSuccess => 'تم إرسال طلب الحذف بنجاح';

  @override
  String get exploreTabClassics => 'الكلاسيكيات';

  @override
  String get exploreTabNew => 'جديد';

  @override
  String get exploreTabPopular => 'الرائج';

  @override
  String get exploreTabCategories => 'الفئات';

  @override
  String get exploreTabForYou => 'لأجلك';

  @override
  String get exploreTabLists => 'القوائم';

  @override
  String get exploreTabIntegratedApps => 'التطبيقات المدمجة';

  @override
  String get exploreNoVideosAvailable => 'لا توجد فيديوهات متاحة';

  @override
  String exploreErrorPrefix(Object error) {
    return 'خطأ: $error';
  }

  @override
  String get exploreDiscoverLists => 'اكتشف القوائم';

  @override
  String get exploreAboutLists => 'عن القوائم';

  @override
  String get exploreAboutListsDescription =>
      'القوائم تساعدك في تنظيم محتوى Divine بطريقتين:';

  @override
  String get explorePeopleLists => 'قوائم الأشخاص';

  @override
  String get explorePeopleListsDescription =>
      'تابع مجموعات من الصناع وشاهد أحدث فيديوهاتهم';

  @override
  String get exploreVideoLists => 'قوائم الفيديو';

  @override
  String get exploreVideoListsDescription =>
      'أنشئ قوائم تشغيل لفيديوهاتك المفضلة لمشاهدتها لاحقًا';

  @override
  String get exploreMyLists => 'قوائمي';

  @override
  String get exploreSubscribedLists => 'القوائم المشترك بها';

  @override
  String exploreErrorLoadingLists(Object error) {
    return 'خطأ في تحميل القوائم: $error';
  }

  @override
  String exploreNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فيديو جديد',
      many: '$count فيديو جديد',
      few: '$count فيديوهات جديدة',
      two: 'فيديوان جديدان',
      one: 'فيديو جديد واحد',
      zero: 'لا توجد فيديوهات جديدة',
    );
    return '$_temp0';
  }

  @override
  String exploreLoadNewVideosLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فيديو جديد',
      many: '$count فيديو جديد',
      few: '$count فيديوهات جديدة',
      two: 'فيديوين جديدين',
      one: 'فيديو جديد واحد',
      zero: 'لا شيء',
    );
    return 'تحميل $_temp0';
  }

  @override
  String get videoPlayerLoadingVideo => 'جاري تحميل الفيديو...';

  @override
  String get videoPlayerPlayVideo => 'تشغيل الفيديو';

  @override
  String get videoPlayerMute => 'كتم الفيديو';

  @override
  String get videoPlayerUnmute => 'إلغاء كتم الفيديو';

  @override
  String get videoPlayerEditVideo => 'تعديل الفيديو';

  @override
  String get videoPlayerEditVideoTooltip => 'تعديل الفيديو';

  @override
  String get contentWarningLabel => 'تحذير محتوى';

  @override
  String get contentWarningNudity => 'عري';

  @override
  String get contentWarningSexualContent => 'محتوى جنسي';

  @override
  String get contentWarningPornography => 'إباحية';

  @override
  String get contentWarningGraphicMedia => 'محتوى مصور صادم';

  @override
  String get contentWarningViolence => 'عنف';

  @override
  String get contentWarningSelfHarm => 'إيذاء النفس';

  @override
  String get contentWarningDrugUse => 'تعاطي المخدرات';

  @override
  String get contentWarningAlcohol => 'كحول';

  @override
  String get contentWarningTobacco => 'تبغ';

  @override
  String get contentWarningGambling => 'قمار';

  @override
  String get contentWarningProfanity => 'ألفاظ نابية';

  @override
  String get contentWarningFlashingLights => 'أضواء وامضة';

  @override
  String get contentWarningAiGenerated => 'مُنشأ بالذكاء الاصطناعي';

  @override
  String get contentWarningSpoiler => 'حرق أحداث';

  @override
  String get contentWarningSensitiveContent => 'محتوى حساس';

  @override
  String get contentWarningDescNudity => 'يحتوي على عري كلي أو جزئي';

  @override
  String get contentWarningDescSexual => 'يحتوي على محتوى جنسي';

  @override
  String get contentWarningDescPorn => 'يحتوي على محتوى إباحي صريح';

  @override
  String get contentWarningDescGraphicMedia => 'يحتوي على صور صادمة أو مزعجة';

  @override
  String get contentWarningDescViolence => 'يحتوي على محتوى عنيف';

  @override
  String get contentWarningDescSelfHarm => 'يحتوي على إشارات لإيذاء النفس';

  @override
  String get contentWarningDescDrugs => 'يحتوي على محتوى متعلق بالمخدرات';

  @override
  String get contentWarningDescAlcohol => 'يحتوي على محتوى متعلق بالكحول';

  @override
  String get contentWarningDescTobacco => 'يحتوي على محتوى متعلق بالتبغ';

  @override
  String get contentWarningDescGambling => 'يحتوي على محتوى متعلق بالقمار';

  @override
  String get contentWarningDescProfanity => 'يحتوي على لغة قوية';

  @override
  String get contentWarningDescFlashingLights =>
      'يحتوي على أضواء وامضة (تحذير للحساسية الضوئية)';

  @override
  String get contentWarningDescAiGenerated =>
      'تم إنشاء هذا المحتوى بواسطة الذكاء الاصطناعي';

  @override
  String get contentWarningDescSpoiler => 'يحتوي على حرق أحداث';

  @override
  String get contentWarningDescContentWarning =>
      'صنّف الصانع هذا المحتوى بوصفه حساسًا';

  @override
  String get contentWarningDescDefault => 'وضع الصانع علامة على هذا المحتوى';

  @override
  String get contentWarningDetailsTitle => 'تحذيرات المحتوى';

  @override
  String get contentWarningDetailsSubtitle => 'طبّق الصانع هذه الوسوم:';

  @override
  String get contentWarningManageFilters => 'إدارة مرشّحات المحتوى';

  @override
  String get contentWarningViewAnyway => 'العرض على أي حال';

  @override
  String get contentWarningHideAllLikeThis => 'إخفاء كل المحتوى المشابه';

  @override
  String get contentWarningNoFilterYet =>
      'لا يوجد مرشّح محفوظ لهذا التحذير بعد.';

  @override
  String get contentWarningHiddenConfirmation =>
      'سنخفي المنشورات المشابهة من الآن فصاعدًا.';

  @override
  String get videoErrorNotFound => 'لم يُعثر على الفيديو';

  @override
  String get videoErrorNetwork => 'خطأ في الشبكة';

  @override
  String get videoErrorTimeout => 'انتهت مهلة التحميل';

  @override
  String get videoErrorFormat =>
      'خطأ في تنسيق الفيديو\n(حاول مرّة أخرى أو استخدم متصفحًا آخر)';

  @override
  String get videoErrorUnsupportedFormat => 'تنسيق الفيديو غير مدعوم';

  @override
  String get videoErrorPlayback => 'خطأ في تشغيل الفيديو';

  @override
  String get videoErrorAgeRestricted => 'محتوى مقيّد بالعمر';

  @override
  String get videoErrorVerifyAge => 'تحقق من العمر';

  @override
  String get videoErrorRetry => 'إعادة المحاولة';

  @override
  String get videoErrorContentRestricted => 'المحتوى مقيّد';

  @override
  String get videoErrorContentRestrictedBody =>
      'تم تقييد هذا الفيديو من طرف المحول.';

  @override
  String get videoErrorVerifyAgeBody => 'تحقّق من عمرك لعرض هذا الفيديو.';

  @override
  String get videoErrorSkip => 'تخطّي';

  @override
  String get videoErrorVerifyAgeButton => 'تحقّق من العمر';

  @override
  String get videoFollowButtonFollowing => 'متابع';

  @override
  String get videoFollowButtonFollow => 'متابعة';

  @override
  String get audioAttributionOriginalSound => 'صوت أصلي';

  @override
  String videoInspiredByAttribution(String creatorName) {
    return 'مستوحى من @$creatorName';
  }

  @override
  String videoCollaboratorWithOne(String name) {
    return 'مع @$name';
  }

  @override
  String videoCollaboratorWithMore(String name, int count) {
    return 'مع @$name +$count';
  }

  @override
  String videoCollaboratorCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count متعاون',
      many: '$count متعاونًا',
      few: '$count متعاونين',
      two: 'متعاونان',
      one: 'متعاون واحد',
      zero: 'لا يوجد متعاونون',
    );
    return '$_temp0. انقر لعرض الملف الشخصي.';
  }

  @override
  String get listAttributionFallback => 'قائمة';

  @override
  String get shareVideoLabel => 'مشاركة الفيديو';

  @override
  String sharePostSharedWith(String recipientName) {
    return 'تمت مشاركة المنشور مع $recipientName';
  }

  @override
  String get shareFailedToSend => 'فشل إرسال الفيديو';

  @override
  String get shareAddedToBookmarks => 'تمت الإضافة إلى الإشارات المرجعية';

  @override
  String get shareFailedToAddBookmark => 'فشل إضافة الإشارة المرجعية';

  @override
  String get shareActionFailed => 'فشل الإجراء';

  @override
  String get shareWithTitle => 'المشاركة مع';

  @override
  String get shareFindPeople => 'ابحث عن أشخاص';

  @override
  String get shareFindPeopleMultiline => 'ابحثعن أشخاص';

  @override
  String get shareSent => 'تم الإرسال';

  @override
  String get shareContactFallback => 'جهة اتصال';

  @override
  String get shareUserFallback => 'مستخدم';

  @override
  String shareSendingTo(String name) {
    return 'جاري الإرسال إلى $name';
  }

  @override
  String get shareMessageHint => 'أضف رسالة اختيارية...';

  @override
  String get videoActionUnlike => 'إلغاء الإعجاب بالفيديو';

  @override
  String get videoActionLike => 'الإعجاب بالفيديو';

  @override
  String get videoActionAutoLabel => 'تلقائي';

  @override
  String get videoActionEnableAutoAdvance => 'تفعيل التقدّم التلقائي';

  @override
  String get videoActionDisableAutoAdvance => 'إيقاف التقدّم التلقائي';

  @override
  String get videoActionRemoveRepost => 'إزالة إعادة النشر';

  @override
  String get videoActionRepost => 'إعادة نشر الفيديو';

  @override
  String get videoActionViewComments => 'عرض التعليقات';

  @override
  String get videoActionMoreOptions => 'خيارات إضافية';

  @override
  String get videoActionHideSubtitles => 'إخفاء الترجمات';

  @override
  String get videoActionShowSubtitles => 'عرض الترجمات';

  @override
  String videoDescriptionLoops(String count) {
    return '$count تكرار';
  }

  @override
  String videoFeedLoopCountLine(String compactCount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تكرارات',
      one: 'تكرار',
    );
    return '$compactCount $_temp0';
  }

  @override
  String get metadataBadgeNotDivine => 'ليس Divine';

  @override
  String get metadataBadgeHumanMade => 'من صنع البشر';

  @override
  String get metadataSoundsLabel => 'أصوات';

  @override
  String get metadataOriginalSound => 'صوت أصلي';

  @override
  String get metadataVerificationLabel => 'التحقق';

  @override
  String get metadataDeviceAttestation => 'تصديق الجهاز';

  @override
  String get metadataProofManifest => 'بيان الإثبات';

  @override
  String get metadataCreatorLabel => 'الصانع';

  @override
  String get metadataCollaboratorsLabel => 'المتعاونون';

  @override
  String get metadataInspiredByLabel => 'مستوحى من';

  @override
  String get metadataRepostedByLabel => 'أعاد نشره';

  @override
  String metadataLoopsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'التكرارات',
      one: 'تكرار',
    );
    return '$_temp0';
  }

  @override
  String get metadataLikesLabel => 'الإعجابات';

  @override
  String get metadataCommentsLabel => 'التعليقات';

  @override
  String get metadataRepostsLabel => 'إعادات النشر';

  @override
  String get devOptionsTitle => 'خيارات المطور';

  @override
  String get devOptionsPageLoadTimes => 'أوقات تحميل الصفحات';

  @override
  String get devOptionsNoPageLoads =>
      'لم يتم تسجيل أي تحميل صفحة بعد.\nتنقّل في التطبيق لرؤية بيانات التوقيت.';

  @override
  String devOptionsPageLoadVisible(String visibleMs, String dataMs) {
    return 'مرئي: $visibleMs ملليثانية  |  البيانات: $dataMs ملليثانية';
  }

  @override
  String get devOptionsSlowestScreens => 'أبطأ الشاشات';

  @override
  String get devOptionsVideoPlaybackFormat => 'تنسيق تشغيل الفيديو';

  @override
  String get devOptionsSwitchEnvironmentTitle => 'تبديل البيئة؟';

  @override
  String devOptionsSwitchEnvironmentMessage(String envName) {
    return 'التبديل إلى $envName؟\n\nسيؤدي هذا إلى مسح بيانات الفيديو المخزّنة وإعادة الاتصال بالمحول الجديد.';
  }

  @override
  String get devOptionsCancel => 'إلغاء';

  @override
  String get devOptionsSwitch => 'تبديل';

  @override
  String devOptionsSwitchedTo(String envName) {
    return 'تم التبديل إلى $envName';
  }

  @override
  String devOptionsSwitchedFormat(String formatName) {
    return 'تم التبديل إلى $formatName — تم مسح الذاكرة المؤقتة';
  }

  @override
  String get featureFlagTitle => 'أعلام الميزات';

  @override
  String get featureFlagResetAllTooltip => 'إعادة جميع الأعلام إلى الافتراضي';

  @override
  String get featureFlagResetToDefault => 'إعادة إلى الافتراضي';

  @override
  String get featureFlagAppRecovery => 'استرداد التطبيق';

  @override
  String get featureFlagAppRecoveryDescription =>
      'إذا كان التطبيق يتعطّل أو يتصرف بغرابة، جرّب مسح الذاكرة المؤقتة.';

  @override
  String get featureFlagClearAllCache => 'مسح كل الذاكرة المؤقتة';

  @override
  String get featureFlagCacheInfo => 'معلومات الذاكرة المؤقتة';

  @override
  String get featureFlagClearCacheTitle => 'مسح كل الذاكرة المؤقتة؟';

  @override
  String get featureFlagClearCacheMessage =>
      'سيؤدي هذا إلى مسح جميع البيانات المخزّنة بما في ذلك:\n• الإشعارات\n• ملفات المستخدمين\n• الإشارات المرجعية\n• الملفات المؤقتة\n\nستحتاج إلى تسجيل الدخول مجددًا. هل تريد المتابعة؟';

  @override
  String get featureFlagClearCache => 'مسح الذاكرة المؤقتة';

  @override
  String get featureFlagClearingCache => 'جاري مسح الذاكرة المؤقتة...';

  @override
  String get featureFlagSuccess => 'نجح';

  @override
  String get featureFlagError => 'خطأ';

  @override
  String get featureFlagClearCacheSuccess =>
      'تم مسح الذاكرة المؤقتة بنجاح. يرجى إعادة تشغيل التطبيق.';

  @override
  String get featureFlagClearCacheFailure =>
      'فشل مسح بعض عناصر الذاكرة المؤقتة. راجع السجلات للتفاصيل.';

  @override
  String get featureFlagOk => 'حسنًا';

  @override
  String get featureFlagCacheInformation => 'معلومات الذاكرة المؤقتة';

  @override
  String featureFlagTotalCacheSize(String size) {
    return 'إجمالي حجم الذاكرة المؤقتة: $size';
  }

  @override
  String get featureFlagCacheIncludes =>
      'الذاكرة المؤقتة تشمل:\n• سجل الإشعارات\n• بيانات ملفات المستخدمين\n• صور الفيديو المصغّرة\n• الملفات المؤقتة\n• فهارس قاعدة البيانات';

  @override
  String get relaySettingsTitle => 'المحولات';

  @override
  String get relaySettingsInfoTitle =>
      'Divine نظام مفتوح - أنت تتحكم في اتصالاتك';

  @override
  String get relaySettingsInfoDescription =>
      'هذه المحولات توزّع محتواك عبر شبكة Nostr اللامركزية. يمكنك إضافة أو إزالة المحولات كما ترغب.';

  @override
  String get relaySettingsLearnMoreNostr => 'اعرف المزيد عن Nostr →';

  @override
  String get relaySettingsFindPublicRelays =>
      'اعثر على محولات عامة في nostr.co.uk →';

  @override
  String get relaySettingsAppNotFunctional => 'التطبيق غير فعّال';

  @override
  String get relaySettingsRequiresRelay =>
      'يتطلب Divine محولًا واحدًا على الأقل لتحميل الفيديوهات ونشر المحتوى ومزامنة البيانات.';

  @override
  String get relaySettingsRestoreDefaultRelay => 'استعادة المحول الافتراضي';

  @override
  String get relaySettingsAddCustomRelay => 'إضافة محول مخصّص';

  @override
  String get relaySettingsAddRelay => 'إضافة محول';

  @override
  String get relaySettingsRetry => 'إعادة المحاولة';

  @override
  String get relaySettingsNoStats => 'لا توجد إحصائيات متاحة بعد';

  @override
  String get relaySettingsConnection => 'الاتصال';

  @override
  String get relaySettingsConnected => 'متصل';

  @override
  String get relaySettingsDisconnected => 'غير متصل';

  @override
  String get relaySettingsSessionDuration => 'مدة الجلسة';

  @override
  String get relaySettingsLastConnected => 'آخر اتصال';

  @override
  String get relaySettingsDisconnectedLabel => 'غير متصل';

  @override
  String get relaySettingsReason => 'السبب';

  @override
  String get relaySettingsActiveSubscriptions => 'الاشتراكات النشطة';

  @override
  String get relaySettingsTotalSubscriptions => 'إجمالي الاشتراكات';

  @override
  String get relaySettingsEventsReceived => 'الأحداث الواردة';

  @override
  String get relaySettingsEventsSent => 'الأحداث المرسلة';

  @override
  String get relaySettingsRequestsThisSession => 'الطلبات في هذه الجلسة';

  @override
  String get relaySettingsFailedRequests => 'الطلبات الفاشلة';

  @override
  String relaySettingsLastError(String error) {
    return 'آخر خطأ: $error';
  }

  @override
  String get relaySettingsLoadingRelayInfo => 'جاري تحميل معلومات المحول...';

  @override
  String get relaySettingsAboutRelay => 'عن المحول';

  @override
  String get relaySettingsSupportedNips => 'NIPs المدعومة';

  @override
  String get relaySettingsSoftware => 'البرنامج';

  @override
  String get relaySettingsViewWebsite => 'عرض الموقع';

  @override
  String get relaySettingsRemoveRelayTitle => 'إزالة المحول؟';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return 'هل أنت متأكد من رغبتك في إزالة هذا المحول؟\n\n$relayUrl';
  }

  @override
  String get relaySettingsCancel => 'إلغاء';

  @override
  String get relaySettingsRemove => 'إزالة';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return 'تم إزالة المحول: $relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay => 'فشل إزالة المحول';

  @override
  String get relaySettingsForcingReconnection =>
      'جاري فرض إعادة اتصال المحول...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    return 'تم الاتصال بـ $count محول!';
  }

  @override
  String get relaySettingsFailedToConnectCheck =>
      'فشل الاتصال بالمحولات. يرجى التحقق من اتصال الشبكة.';

  @override
  String get relaySettingsAddRelayTitle => 'إضافة محول';

  @override
  String get relaySettingsAddRelayPrompt =>
      'أدخل رابط WebSocket للمحول الذي تريد إضافته:';

  @override
  String get relaySettingsBrowsePublicRelays =>
      'تصفّح المحولات العامة في nostr.co.uk';

  @override
  String get relaySettingsAdd => 'إضافة';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return 'تمت إضافة المحول: $relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay =>
      'فشلت إضافة المحول. تحقّق من الرابط وحاول مرّة أخرى.';

  @override
  String get relaySettingsInvalidUrl =>
      'يجب أن يبدأ رابط المحول بـ wss:// أو ws://';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return 'تمت استعادة المحول الافتراضي: $defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault =>
      'فشلت استعادة المحول الافتراضي. تحقّق من اتصال الشبكة.';

  @override
  String get relaySettingsCouldNotOpenBrowser => 'تعذّر فتح المتصفح';

  @override
  String get relaySettingsFailedToOpenLink => 'تعذّر فتح الرابط';

  @override
  String get relayDiagnosticTitle => 'تشخيص المحول';

  @override
  String get relayDiagnosticRefreshTooltip => 'تحديث التشخيص';

  @override
  String relayDiagnosticLastRefresh(String time) {
    return 'آخر تحديث: $time';
  }

  @override
  String get relayDiagnosticRelayStatus => 'حالة المحول';

  @override
  String get relayDiagnosticInitialized => 'تمت التهيئة';

  @override
  String get relayDiagnosticReady => 'جاهز';

  @override
  String get relayDiagnosticNotInitialized => 'غير مهيأ';

  @override
  String get relayDiagnosticDatabaseEvents => 'أحداث قاعدة البيانات';

  @override
  String get relayDiagnosticActiveSubscriptions => 'الاشتراكات النشطة';

  @override
  String get relayDiagnosticExternalRelays => 'المحولات الخارجية';

  @override
  String get relayDiagnosticConfigured => 'مُعدّات';

  @override
  String relayDiagnosticRelayCount(int count) {
    return '$count محول';
  }

  @override
  String get relayDiagnosticConnectedLabel => 'متصل';

  @override
  String relayDiagnosticConnectedRatio(int connected, int total) {
    return '$connected/$total';
  }

  @override
  String get relayDiagnosticVideoEvents => 'أحداث الفيديو';

  @override
  String get relayDiagnosticHomeFeed => 'التغذية الرئيسية';

  @override
  String relayDiagnosticVideosCount(int count) {
    return '$count فيديو';
  }

  @override
  String get relayDiagnosticDiscovery => 'اكتشاف';

  @override
  String get relayDiagnosticLoading => 'جاري التحميل';

  @override
  String get relayDiagnosticYes => 'نعم';

  @override
  String get relayDiagnosticNo => 'لا';

  @override
  String get relayDiagnosticTestDirectQuery => 'اختبار استعلام مباشر';

  @override
  String get relayDiagnosticNetworkConnectivity => 'اتصال الشبكة';

  @override
  String get relayDiagnosticRunNetworkTest => 'تشغيل اختبار الشبكة';

  @override
  String get relayDiagnosticBlossomServer => 'خادم Blossom';

  @override
  String get relayDiagnosticTestAllEndpoints => 'اختبار جميع نقاط النهاية';

  @override
  String get relayDiagnosticStatus => 'الحالة';

  @override
  String get relayDiagnosticUrl => 'الرابط';

  @override
  String get relayDiagnosticError => 'خطأ';

  @override
  String get relayDiagnosticFunnelCakeApi => 'FunnelCake API';

  @override
  String get relayDiagnosticBaseUrl => 'الرابط الأساسي';

  @override
  String get relayDiagnosticSummary => 'الملخص';

  @override
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  ) {
    return '$successCount/$totalCount على ما يرام (المتوسط $avgMs ملليثانية)';
  }

  @override
  String get relayDiagnosticRetestAll => 'إعادة اختبار الكل';

  @override
  String get relayDiagnosticRetrying => 'جاري إعادة المحاولة...';

  @override
  String get relayDiagnosticRetryConnection => 'إعادة محاولة الاتصال';

  @override
  String get relayDiagnosticTroubleshooting => 'استكشاف الأخطاء';

  @override
  String get relayDiagnosticTroubleshootingGuide =>
      '• حالة خضراء = متصل ويعمل\n• حالة حمراء = فشل الاتصال\n• إذا فشل اختبار الشبكة، تحقّق من اتصال الإنترنت\n• إذا كانت المحولات مُعدّة وليست متصلة، انقر على \"إعادة محاولة الاتصال\"\n• التقط صورة لهذه الشاشة للتصحيح';

  @override
  String get relayDiagnosticAllEndpointsHealthy =>
      'جميع نقاط نهاية REST سليمة!';

  @override
  String get relayDiagnosticSomeEndpointsFailed =>
      'فشلت بعض نقاط نهاية REST - انظر التفاصيل أعلاه';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    return 'تم العثور على $count حدث فيديو في قاعدة البيانات';
  }

  @override
  String relayDiagnosticQueryFailed(String error) {
    return 'فشل الاستعلام: $error';
  }

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    return 'تم الاتصال بـ $count محول!';
  }

  @override
  String get relayDiagnosticFailedToConnect => 'فشل الاتصال بأي محول';

  @override
  String relayDiagnosticConnectionRetryFailed(String error) {
    return 'فشلت إعادة محاولة الاتصال: $error';
  }

  @override
  String get relayDiagnosticConnectedAuthenticated => 'متصل ومُصادَق عليه';

  @override
  String get relayDiagnosticConnectedOnly => 'متصل';

  @override
  String get relayDiagnosticNotConnected => 'غير متصل';

  @override
  String get relayDiagnosticNoRelaysConfigured => 'لا توجد محولات مُعدّة';

  @override
  String get relayDiagnosticFailed => 'فشل';

  @override
  String get notificationSettingsTitle => 'الإشعارات';

  @override
  String get notificationSettingsResetTooltip => 'إعادة الضبط الافتراضي';

  @override
  String get notificationSettingsTypes => 'أنواع الإشعارات';

  @override
  String get notificationSettingsLikes => 'الإعجابات';

  @override
  String get notificationSettingsLikesSubtitle => 'عندما يعجب أحدهم بفيديوهاتك';

  @override
  String get notificationSettingsComments => 'التعليقات';

  @override
  String get notificationSettingsCommentsSubtitle =>
      'عندما يعلّق أحدهم على فيديوهاتك';

  @override
  String get notificationSettingsFollows => 'المتابعون';

  @override
  String get notificationSettingsFollowsSubtitle => 'عندما يتابعك أحدهم';

  @override
  String get notificationSettingsMentions => 'الإشارات';

  @override
  String get notificationSettingsMentionsSubtitle => 'عندما تتم الإشارة إليك';

  @override
  String get notificationSettingsReposts => 'إعادات النشر';

  @override
  String get notificationSettingsRepostsSubtitle =>
      'عندما يعيد أحدهم نشر فيديوهاتك';

  @override
  String get notificationSettingsSystem => 'النظام';

  @override
  String get notificationSettingsSystemSubtitle =>
      'تحديثات التطبيق ورسائل النظام';

  @override
  String get notificationSettingsPushNotificationsSection =>
      'الإشعارات الفورية';

  @override
  String get notificationSettingsPushNotifications => 'الإشعارات الفورية';

  @override
  String get notificationSettingsPushNotificationsSubtitle =>
      'تلقّ الإشعارات حتى عند إغلاق التطبيق';

  @override
  String get notificationSettingsSound => 'الصوت';

  @override
  String get notificationSettingsSoundSubtitle => 'تشغيل صوت للإشعارات';

  @override
  String get notificationSettingsVibration => 'الاهتزاز';

  @override
  String get notificationSettingsVibrationSubtitle => 'اهتزاز للإشعارات';

  @override
  String get notificationSettingsActions => 'الإجراءات';

  @override
  String get notificationSettingsMarkAllAsRead => 'وسم الكل كمقروء';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle =>
      'وسم جميع الإشعارات كمقروءة';

  @override
  String get notificationSettingsAllMarkedAsRead =>
      'تم وسم جميع الإشعارات كمقروءة';

  @override
  String get notificationSettingsResetToDefaults =>
      'تمت إعادة الإعدادات إلى الافتراضي';

  @override
  String get notificationSettingsAbout => 'عن الإشعارات';

  @override
  String get notificationSettingsAboutDescription =>
      'الإشعارات مدعومة ببروتوكول Nostr. التحديثات الفورية تعتمد على اتصالك بمحولات Nostr. قد تواجه بعض الإشعارات تأخيرًا.';

  @override
  String get safetySettingsTitle => 'الأمان والخصوصية';

  @override
  String get safetySettingsLabel => 'الإعدادات';

  @override
  String get safetySettingsShowDivineHostedOnly =>
      'عرض الفيديوهات المستضافة على Divine فقط';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle =>
      'إخفاء الفيديوهات المقدّمة من مصادر أخرى';

  @override
  String get safetySettingsModeration => 'الإشراف';

  @override
  String get safetySettingsBlockedUsers => 'المستخدمون المحظورون';

  @override
  String get safetySettingsAgeVerification => 'التحقق من العمر';

  @override
  String get safetySettingsAgeConfirmation =>
      'أؤكّد أنّي في الثامنة عشرة من عمري أو أكبر';

  @override
  String get safetySettingsAgeRequired => 'مطلوب لعرض المحتوى للبالغين';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle =>
      'خدمة الإشراف الرسمية (مُفعّلة افتراضيًا)';

  @override
  String get safetySettingsPeopleIFollow => 'الأشخاص الذين أتابعهم';

  @override
  String get safetySettingsPeopleIFollowSubtitle =>
      'اشترك في الوسوم من الأشخاص الذين تتابعهم';

  @override
  String get safetySettingsAddCustomLabeler => 'إضافة واسم مخصّص';

  @override
  String get safetySettingsAddCustomLabelerHint => 'أدخل npub...';

  @override
  String get safetySettingsAddCustomLabelerListTitle => 'إضافة واسم مخصّص';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle => 'أدخل عنوان npub';

  @override
  String get safetySettingsNoBlockedUsers => 'لا يوجد مستخدمون محظورون';

  @override
  String get safetySettingsUnblock => 'إلغاء الحظر';

  @override
  String get safetySettingsUserUnblocked => 'تم إلغاء حظر المستخدم';

  @override
  String get safetySettingsCancel => 'إلغاء';

  @override
  String get safetySettingsAdd => 'إضافة';

  @override
  String get analyticsTitle => 'تحليلات الصانع';

  @override
  String get analyticsDiagnosticsTooltip => 'التشخيص';

  @override
  String get analyticsDiagnosticsSemanticLabel => 'تبديل التشخيص';

  @override
  String get analyticsRetry => 'إعادة المحاولة';

  @override
  String get analyticsUnableToLoad => 'تعذّر تحميل التحليلات.';

  @override
  String get analyticsSignInRequired => 'سجل الدخول لعرض تحليلات الصانع.';

  @override
  String get analyticsViewDataUnavailable =>
      'المشاهدات غير متاحة حاليًا من المحول لهذه المنشورات. مقاييس الإعجاب والتعليق وإعادة النشر لا تزال دقيقة.';

  @override
  String get analyticsViewDataTitle => 'بيانات المشاهدة';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return 'آخر تحديث $time • تستخدم الدرجات الإعجابات والتعليقات وإعادات النشر والمشاهدات/التكرارات من Funnelcake عند التوفر.';
  }

  @override
  String get analyticsVideos => 'الفيديوهات';

  @override
  String get analyticsViews => 'المشاهدات';

  @override
  String get analyticsInteractions => 'التفاعلات';

  @override
  String get analyticsEngagement => 'التفاعل';

  @override
  String get analyticsFollowers => 'المتابِعون';

  @override
  String get analyticsAvgPerPost => 'المتوسط/منشور';

  @override
  String get analyticsInteractionMix => 'مزيج التفاعلات';

  @override
  String get analyticsLikes => 'الإعجابات';

  @override
  String get analyticsComments => 'التعليقات';

  @override
  String get analyticsReposts => 'إعادات النشر';

  @override
  String get analyticsPerformanceHighlights => 'أبرز لحظات الأداء';

  @override
  String get analyticsMostViewed => 'الأكثر مشاهدة';

  @override
  String get analyticsMostDiscussed => 'الأكثر نقاشًا';

  @override
  String get analyticsMostReposted => 'الأكثر إعادة نشر';

  @override
  String get analyticsNoVideosYet => 'لا توجد فيديوهات بعد';

  @override
  String get analyticsViewDataUnavailableShort => 'بيانات المشاهدة غير متاحة';

  @override
  String analyticsViewsCount(String count) {
    return '$count مشاهدة';
  }

  @override
  String analyticsCommentsCount(String count) {
    return '$count تعليق';
  }

  @override
  String analyticsRepostsCount(String count) {
    return '$count إعادة نشر';
  }

  @override
  String get analyticsTopContent => 'أفضل المحتوى';

  @override
  String get analyticsPublishPrompt => 'انشر بعض الفيديوهات لرؤية الترتيبات.';

  @override
  String get analyticsEngagementRateExplainer =>
      'النسبة المئوية على الجانب الأيمن = معدل التفاعل (التفاعلات مقسومة على المشاهدات).';

  @override
  String get analyticsEngagementRateNoViews =>
      'معدل التفاعل يتطلب بيانات المشاهدة؛ ستظهر القيم باسم غير متوفر حتى تتوفر المشاهدات.';

  @override
  String get analyticsEngagementLabel => 'التفاعل';

  @override
  String get analyticsViewsUnavailable => 'المشاهدات غير متاحة';

  @override
  String analyticsInteractionsCount(String count) {
    return '$count تفاعل';
  }

  @override
  String get analyticsPostAnalytics => 'تحليلات المنشور';

  @override
  String get analyticsOpenPost => 'فتح المنشور';

  @override
  String get analyticsRecentDailyInteractions => 'التفاعلات اليومية الأخيرة';

  @override
  String get analyticsNoActivityYet => 'لا يوجد نشاط في هذه الفترة بعد.';

  @override
  String get analyticsDailyInteractionsExplainer =>
      'التفاعلات = الإعجابات + التعليقات + إعادات النشر حسب تاريخ المنشور.';

  @override
  String get analyticsDailyBarExplainer =>
      'طول الشريط نسبي لأعلى يوم في هذه النافذة.';

  @override
  String get analyticsAudienceSnapshot => 'لمحة عن الجمهور';

  @override
  String analyticsFollowersCount(String count) {
    return 'المتابِعون: $count';
  }

  @override
  String analyticsFollowingCount(String count) {
    return 'يتابِع: $count';
  }

  @override
  String get analyticsAudiencePlaceholder =>
      'ستظهر تفاصيل مصدر الجمهور والموقع الجغرافي والوقت عندما يضيف Funnelcake نقاط نهاية تحليلات الجمهور.';

  @override
  String get analyticsRetention => 'الاحتفاظ';

  @override
  String get analyticsRetentionWithViews =>
      'ستظهر منحنى الاحتفاظ وتفاصيل وقت المشاهدة عندما تصل بيانات الاحتفاظ التفصيلية من Funnelcake.';

  @override
  String get analyticsRetentionWithoutViews =>
      'بيانات الاحتفاظ غير متاحة حتى تعود تحليلات المشاهدات ووقت المشاهدة من Funnelcake.';

  @override
  String get analyticsDiagnostics => 'التشخيص';

  @override
  String analyticsDiagnosticsTotalVideos(int count) {
    return 'إجمالي الفيديوهات: $count';
  }

  @override
  String analyticsDiagnosticsWithViews(int count) {
    return 'بمشاهدات: $count';
  }

  @override
  String analyticsDiagnosticsMissingViews(int count) {
    return 'بدون مشاهدات: $count';
  }

  @override
  String analyticsDiagnosticsHydratedBulk(int count) {
    return 'مجلوب (دفعة): $count';
  }

  @override
  String analyticsDiagnosticsHydratedViews(int count) {
    return 'مجلوب (/مشاهدات): $count';
  }

  @override
  String analyticsDiagnosticsSources(String sources) {
    return 'المصادر: $sources';
  }

  @override
  String get analyticsDiagnosticsUseFixture => 'استخدام بيانات وهمية';

  @override
  String get analyticsNa => 'غير متوفر';

  @override
  String get authCreateNewAccount => 'إنشاء حساب Divine جديد';

  @override
  String get authSignInDifferentAccount => 'تسجيل الدخول بحساب آخر';

  @override
  String get authSignBackIn => 'عد إلى تسجيل الدخول';

  @override
  String get authTermsPrefix =>
      'باختيار خيار أعلاه، أنت تؤكّد أنّ عمرك 16 عامًا على الأقل وتوافق على ';

  @override
  String get authTermsOfService => 'شروط الخدمة';

  @override
  String get authPrivacyPolicy => 'سياسة الخصوصية';

  @override
  String get authTermsAnd => '، و';

  @override
  String get authSafetyStandards => 'معايير الأمان';

  @override
  String get authAmberNotInstalled => 'تطبيق Amber غير مثبّت';

  @override
  String get authAmberConnectionFailed => 'فشل الاتصال بـ Amber';

  @override
  String get authPasswordResetSent =>
      'إذا كان هناك حساب بهذا البريد، فسيتم إرسال رابط إعادة تعيين كلمة المرور.';

  @override
  String get authSignInTitle => 'تسجيل الدخول';

  @override
  String get authEmailLabel => 'البريد الإلكتروني';

  @override
  String get authPasswordLabel => 'كلمة المرور';

  @override
  String get authForgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get authImportNostrKey => 'استيراد مفتاح Nostr';

  @override
  String get authConnectSignerApp => 'الاتصال بتطبيق توقيع';

  @override
  String get authSignInWithAmber => 'تسجيل الدخول بـ Amber';

  @override
  String get authSignInOptionsTitle => 'خيارات تسجيل الدخول';

  @override
  String get authInfoEmailPasswordTitle => 'بريد إلكتروني وكلمة مرور';

  @override
  String get authInfoEmailPasswordDescription =>
      'سجّل الدخول بحساب Divine الخاص بك. إذا سجّلت ببريد وكلمة مرور، استخدمهما هنا.';

  @override
  String get authInfoImportNostrKeyDescription =>
      'لديك هوية Nostr بالفعل؟ استورد مفتاح nsec الخاص بك من تطبيق آخر.';

  @override
  String get authInfoSignerAppTitle => 'تطبيق توقيع';

  @override
  String get authInfoSignerAppDescription =>
      'اتصل باستخدام موقّع خارجي متوافق مع NIP-46 مثل nsecBunker لأمان مفاتيح أفضل.';

  @override
  String get authInfoAmberTitle => 'Amber';

  @override
  String get authInfoAmberDescription =>
      'استخدم تطبيق توقيع Amber على أندرويد لإدارة مفاتيح Nostr الخاصة بك بأمان.';

  @override
  String get authCreateAccountTitle => 'إنشاء حساب';

  @override
  String get authBackToInviteCode => 'العودة إلى رمز الدعوة';

  @override
  String get authUseDivineNoBackup => 'استخدم Divine بدون نسخة احتياطية';

  @override
  String get authSkipConfirmTitle => 'أمر أخير...';

  @override
  String get authSkipConfirmKeyCreated =>
      'أنت في الداخل! سننشئ مفتاحًا آمنًا يشغّل حسابك في Divine.';

  @override
  String get authSkipConfirmKeyOnly =>
      'بدون بريد إلكتروني، مفتاحك هو الطريقة الوحيدة ليعرف Divine أن هذا الحساب لك.';

  @override
  String get authSkipConfirmRecommendEmail =>
      'يمكنك الوصول إلى مفتاحك في التطبيق، لكن إذا لم تكن ملمًا بالتقنية، نوصي بإضافة بريد وكلمة مرور الآن. سيجعل ذلك تسجيل الدخول واستعادة حسابك أسهل إذا فقدت هذا الجهاز أو أعدت ضبطه.';

  @override
  String get authAddEmailPassword => 'إضافة بريد وكلمة مرور';

  @override
  String get authUseThisDeviceOnly => 'استخدم هذا الجهاز فقط';

  @override
  String get authCompleteRegistration => 'أكمل تسجيلك';

  @override
  String get authVerifying => 'جاري التحقق...';

  @override
  String get authVerificationLinkSent => 'أرسلنا رابط تحقق إلى:';

  @override
  String get authClickVerificationLink =>
      'يرجى النقر على الرابط في بريدك الإلكتروني\nلإكمال التسجيل.';

  @override
  String get authPleaseWaitVerifying =>
      'يرجى الانتظار بينما نتحقّق من بريدك...';

  @override
  String get authWaitingForVerification => 'في انتظار التحقق';

  @override
  String get authOpenEmailApp => 'فتح تطبيق البريد';

  @override
  String get authWelcomeToDivine => 'أهلاً بك في Divine!';

  @override
  String get authEmailVerified => 'تم التحقق من بريدك الإلكتروني.';

  @override
  String get authSigningYouIn => 'جاري تسجيل دخولك';

  @override
  String get authErrorTitle => 'عفوًا.';

  @override
  String get authVerificationFailed =>
      'فشلنا في التحقق من بريدك.\nحاول مرّة أخرى.';

  @override
  String get authStartOver => 'البدء من جديد';

  @override
  String get authEmailVerifiedLogin =>
      'تم التحقق من البريد! يرجى تسجيل الدخول للمتابعة.';

  @override
  String get authVerificationLinkExpired => 'رابط التحقق هذا لم يعد صالحًا.';

  @override
  String get authVerificationConnectionError =>
      'تعذّر التحقق من البريد. تحقّق من اتصالك وحاول مرّة أخرى.';

  @override
  String get authWaitlistConfirmTitle => 'أنت في الداخل!';

  @override
  String authWaitlistUpdatesAt(String email) {
    return 'سنشارك التحديثات على $email.\nعندما تتوفر رموز دعوة إضافية، سنرسلها إليك.';
  }

  @override
  String get authOk => 'حسنًا';

  @override
  String get authInviteUnavailable => 'وصول الدعوة غير متاح مؤقتًا.';

  @override
  String get authInviteUnavailableBody =>
      'حاول بعد لحظات، أو تواصل مع الدعم إذا احتجت مساعدة.';

  @override
  String get authTryAgain => 'حاول مرّة أخرى';

  @override
  String get authContactSupport => 'اتصل بالدعم';

  @override
  String authCouldNotOpenEmail(String email) {
    return 'تعذّر فتح $email';
  }

  @override
  String get authAddInviteCode => 'أضف رمز الدعوة الخاص بك';

  @override
  String get authInviteCodeLabel => 'رمز الدعوة';

  @override
  String get authEnterYourCode => 'أدخل رمزك';

  @override
  String get authNext => 'التالي';

  @override
  String get authJoinWaitlist => 'انضم لقائمة الانتظار';

  @override
  String get authJoinWaitlistTitle => 'انضم إلى قائمة الانتظار';

  @override
  String get authJoinWaitlistDescription =>
      'شاركنا بريدك وسنرسل لك التحديثات عند فتح الوصول.';

  @override
  String get authInviteAccessHelp => 'مساعدة وصول الدعوة';

  @override
  String get authGeneratingConnection => 'جاري إنشاء الاتصال...';

  @override
  String get authConnectedAuthenticating => 'تم الاتصال! جاري المصادقة...';

  @override
  String get authConnectionTimedOut => 'انتهت مهلة الاتصال';

  @override
  String get authApproveConnection =>
      'تأكد أنّك وافقت على الاتصال في تطبيق التوقيع الخاص بك.';

  @override
  String get authConnectionCancelled => 'تم إلغاء الاتصال';

  @override
  String get authConnectionCancelledMessage => 'تم إلغاء الاتصال.';

  @override
  String get authConnectionFailed => 'فشل الاتصال';

  @override
  String get authUnknownError => 'حدث خطأ غير معروف.';

  @override
  String get authUrlCopied => 'تم نسخ الرابط إلى الحافظة';

  @override
  String get authConnectToDivine => 'الاتصال بـ Divine';

  @override
  String get authPasteBunkerUrl => 'الصق رابط bunker://';

  @override
  String get authBunkerUrlHint => 'رابط bunker://';

  @override
  String get authInvalidBunkerUrl =>
      'رابط bunker غير صالح. يجب أن يبدأ بـ bunker://';

  @override
  String get authScanSignerApp => 'امسح بتطبيق التوقيع الخاص بك\nللاتصال.';

  @override
  String authWaitingForConnection(int seconds) {
    return 'في انتظار الاتصال... $seconds ث';
  }

  @override
  String get authCopyUrl => 'نسخ الرابط';

  @override
  String get authShare => 'مشاركة';

  @override
  String get authAddBunker => 'إضافة bunker';

  @override
  String get authCompatibleSignerApps => 'تطبيقات توقيع متوافقة';

  @override
  String get authFailedToConnect => 'فشل الاتصال';

  @override
  String get authResetPasswordTitle => 'إعادة تعيين كلمة المرور';

  @override
  String get authResetPasswordSubtitle =>
      'يرجى إدخال كلمة المرور الجديدة. يجب ألّا تقل عن 8 أحرف.';

  @override
  String get authNewPasswordLabel => 'كلمة المرور الجديدة';

  @override
  String get authPasswordTooShort => 'يجب ألّا تقل كلمة المرور عن 8 أحرف';

  @override
  String get authPasswordResetSuccess =>
      'تمت إعادة تعيين كلمة المرور بنجاح. يرجى تسجيل الدخول.';

  @override
  String get authPasswordResetFailed => 'فشل إعادة تعيين كلمة المرور';

  @override
  String get authUnexpectedError => 'حدث خطأ غير متوقّع. حاول مرّة أخرى.';

  @override
  String get authUpdatePassword => 'تحديث كلمة المرور';

  @override
  String get authSecureAccountTitle => 'حساب آمن';

  @override
  String get authUnableToAccessKeys =>
      'تعذّر الوصول إلى مفاتيحك. حاول مرّة أخرى.';

  @override
  String get authRegistrationFailed => 'فشل التسجيل';

  @override
  String get authRegistrationComplete =>
      'تم التسجيل. يرجى تفقّد بريدك الإلكتروني.';

  @override
  String get authVerificationFailedTitle => 'فشل التحقق';

  @override
  String get authClose => 'إغلاق';

  @override
  String get authAccountSecured => 'تم تأمين الحساب!';

  @override
  String get authAccountLinkedToEmail => 'حسابك مرتبط الآن ببريدك الإلكتروني.';

  @override
  String get authVerifyYourEmail => 'تحقّق من بريدك';

  @override
  String get authClickLinkContinue =>
      'انقر على الرابط في بريدك لإكمال التسجيل. يمكنك الاستمرار في استخدام التطبيق في الأثناء.';

  @override
  String get authWaitingForVerificationEllipsis => 'في انتظار التحقق...';

  @override
  String get authContinueToApp => 'المتابعة إلى التطبيق';

  @override
  String get authResetPassword => 'إعادة تعيين كلمة المرور';

  @override
  String get authResetPasswordDescription =>
      'أدخل عنوان بريدك الإلكتروني وسنرسل لك رابطًا لإعادة تعيين كلمة المرور.';

  @override
  String get authFailedToSendResetEmail => 'فشل إرسال بريد إعادة التعيين.';

  @override
  String get authUnexpectedErrorShort => 'حدث خطأ غير متوقّع.';

  @override
  String get authSending => 'جاري الإرسال...';

  @override
  String get authSendResetLink => 'إرسال رابط التعيين';

  @override
  String get authEmailSent => 'تم إرسال البريد!';

  @override
  String authResetLinkSentTo(String email) {
    return 'أرسلنا رابط إعادة تعيين كلمة المرور إلى $email. يرجى النقر على الرابط في بريدك لتحديث كلمة المرور.';
  }

  @override
  String get authSignInButton => 'تسجيل الدخول';

  @override
  String get authVerificationErrorTimeout =>
      'انتهت مهلة التحقق. حاول التسجيل مرّة أخرى.';

  @override
  String get authVerificationErrorMissingCode =>
      'فشل التحقق — رمز التفويض مفقود.';

  @override
  String get authVerificationErrorPollFailed => 'فشل التحقق. حاول مرّة أخرى.';

  @override
  String get authVerificationErrorNetworkExchange =>
      'خطأ في الشبكة أثناء تسجيل الدخول. حاول مرّة أخرى.';

  @override
  String get authVerificationErrorOAuthExchange =>
      'فشل التحقق. حاول التسجيل مرّة أخرى.';

  @override
  String get authVerificationErrorSignInFailed =>
      'فشل تسجيل الدخول. حاول تسجيل الدخول يدويًا.';

  @override
  String get authInviteErrorAlreadyUsed =>
      'رمز الدعوة هذا لم يعد متاحًا. عد إلى رمز دعوتك، انضم لقائمة الانتظار، أو تواصل مع الدعم.';

  @override
  String get authInviteErrorInvalid =>
      'رمز الدعوة هذا لا يمكن استخدامه الآن. عد إلى رمز دعوتك، انضم لقائمة الانتظار، أو تواصل مع الدعم.';

  @override
  String get authInviteErrorTemporary =>
      'لم نتمكّن من تأكيد دعوتك الآن. عد إلى رمز دعوتك وحاول مرّة أخرى، أو تواصل مع الدعم.';

  @override
  String get authInviteErrorUnknown =>
      'لم نتمكّن من تفعيل دعوتك. عد إلى رمز دعوتك، انضم لقائمة الانتظار، أو تواصل مع الدعم.';

  @override
  String get shareSheetSave => 'حفظ';

  @override
  String get shareSheetSaveToGallery => 'حفظ في المعرض';

  @override
  String get shareSheetSaveWithWatermark => 'حفظ مع العلامة المائية';

  @override
  String get shareSheetSaveVideo => 'حفظ الفيديو';

  @override
  String get shareSheetAddToList => 'إضافة إلى قائمة';

  @override
  String get shareSheetCopy => 'نسخ';

  @override
  String get shareSheetShareVia => 'مشاركة عبر';

  @override
  String get shareSheetReport => 'إبلاغ';

  @override
  String get shareSheetEventJson => 'JSON الحدث';

  @override
  String get shareSheetEventId => 'معرّف الحدث';

  @override
  String get shareSheetMoreActions => 'إجراءات إضافية';

  @override
  String get watermarkDownloadSavedToCameraRoll => 'تم الحفظ في ألبوم الكاميرا';

  @override
  String get watermarkDownloadShare => 'مشاركة';

  @override
  String get watermarkDownloadDone => 'تم';

  @override
  String get watermarkDownloadPhotosAccessNeeded => 'مطلوب الوصول إلى الصور';

  @override
  String get watermarkDownloadPhotosAccessDescription =>
      'لحفظ الفيديوهات، اسمح بالوصول إلى الصور في الإعدادات.';

  @override
  String get watermarkDownloadOpenSettings => 'فتح الإعدادات';

  @override
  String get watermarkDownloadNotNow => 'ليس الآن';

  @override
  String get watermarkDownloadFailed => 'فشل التنزيل';

  @override
  String get watermarkDownloadDismiss => 'تجاهل';

  @override
  String get watermarkDownloadStageDownloading => 'جاري تنزيل الفيديو';

  @override
  String get watermarkDownloadStageWatermarking => 'إضافة العلامة المائية';

  @override
  String get watermarkDownloadStageSaving => 'جاري الحفظ في ألبوم الكاميرا';

  @override
  String get watermarkDownloadStageDownloadingDesc =>
      'جاري جلب الفيديو من الشبكة...';

  @override
  String get watermarkDownloadStageWatermarkingDesc =>
      'جاري تطبيق علامة Divine المائية...';

  @override
  String get watermarkDownloadStageSavingDesc =>
      'جاري حفظ الفيديو في ألبوم الكاميرا...';

  @override
  String get uploadProgressVideoUpload => 'رفع الفيديو';

  @override
  String get uploadProgressPause => 'إيقاف مؤقت';

  @override
  String get uploadProgressResume => 'استئناف';

  @override
  String get uploadProgressGoBack => 'العودة';

  @override
  String uploadProgressRetryWithCount(int count) {
    return 'إعادة المحاولة ($count متبقية)';
  }

  @override
  String get uploadProgressDelete => 'حذف';

  @override
  String uploadProgressDaysAgo(int count) {
    return 'منذ $count يوم';
  }

  @override
  String uploadProgressHoursAgo(int count) {
    return 'منذ $count ساعة';
  }

  @override
  String uploadProgressMinutesAgo(int count) {
    return 'منذ $count دقيقة';
  }

  @override
  String get uploadProgressJustNow => 'الآن';

  @override
  String uploadProgressUploadingPercent(int percent) {
    return 'جاري الرفع $percent%';
  }

  @override
  String uploadProgressPausedPercent(int percent) {
    return 'موقوف مؤقتًا $percent%';
  }

  @override
  String get badgeExplanationClose => 'إغلاق';

  @override
  String get badgeExplanationOriginalVineArchive => 'أرشيف Vine الأصلي';

  @override
  String get badgeExplanationCameraProof => 'إثبات الكاميرا';

  @override
  String get badgeExplanationAuthenticitySignals => 'إشارات الأصالة';

  @override
  String get badgeExplanationVineArchiveIntro =>
      'هذا الفيديو من Vine أصلي تمت استعادته من Internet Archive.';

  @override
  String get badgeExplanationVineArchiveHistory =>
      'قبل إغلاق Vine عام 2017، عمل ArchiveTeam و Internet Archive على حفظ ملايين مقاطع Vine للأجيال القادمة. هذا المحتوى جزء من ذلك الجهد التاريخي للحفظ.';

  @override
  String badgeExplanationOriginalStats(int loops) {
    return 'الإحصائيات الأصلية: $loops تكرار';
  }

  @override
  String get badgeExplanationLearnVineArchive =>
      'اعرف المزيد عن حفظ أرشيف Vine';

  @override
  String get badgeExplanationLearnProofmode =>
      'اعرف المزيد عن التحقق بـ Proofmode';

  @override
  String get badgeExplanationLearnAuthenticity =>
      'اعرف المزيد عن إشارات أصالة Divine';

  @override
  String get badgeExplanationInspectProofCheck => 'الفحص بأداة ProofCheck';

  @override
  String get badgeExplanationInspectMedia => 'فحص تفاصيل الوسائط';

  @override
  String get badgeExplanationProofmodeVerified =>
      'تم التحقق من أصالة هذا الفيديو باستخدام تقنية Proofmode.';

  @override
  String get badgeExplanationDivineHostedHumanMade =>
      'هذا الفيديو مستضاف على Divine، وتشير أدوات كشف الذكاء الاصطناعي إلى أنّه من صنع البشر على الأغلب، لكنّه لا يتضمّن بيانات تحقق تشفيري من الكاميرا.';

  @override
  String get badgeExplanationHumanMadeNoCrypto =>
      'تشير أدوات كشف الذكاء الاصطناعي إلى أنّ هذا الفيديو من صنع البشر على الأغلب، رغم أنّه لا يتضمّن بيانات تحقق تشفيري من الكاميرا.';

  @override
  String get badgeExplanationDivineHostedNoCrypto =>
      'هذا الفيديو مستضاف على Divine، لكنّه لا يتضمّن بيانات تحقق تشفيري من الكاميرا بعد.';

  @override
  String get badgeExplanationExternalNoCrypto =>
      'هذا الفيديو مستضاف خارج Divine ولا يتضمّن بيانات تحقق تشفيري من الكاميرا.';

  @override
  String get badgeExplanationDeviceAttestation => 'تصديق الجهاز';

  @override
  String get badgeExplanationPgpSignature => 'توقيع PGP';

  @override
  String get badgeExplanationC2paCredentials => 'بيانات اعتماد المحتوى C2PA';

  @override
  String get badgeExplanationProofManifest => 'بيان الإثبات';

  @override
  String get badgeExplanationAiDetection => 'كشف الذكاء الاصطناعي';

  @override
  String get badgeExplanationAiNotScanned =>
      'فحص الذكاء الاصطناعي: لم يتم الفحص بعد';

  @override
  String get badgeExplanationNoScanResults => 'لا توجد نتائج فحص متاحة بعد.';

  @override
  String get badgeExplanationCheckAiGenerated =>
      'تحقّق إن كان مُنشأ بالذكاء الاصطناعي';

  @override
  String badgeExplanationAiLikelihood(int percentage) {
    return '$percentage% احتمال أنّه مُنشأ بالذكاء الاصطناعي';
  }

  @override
  String badgeExplanationScannedBy(String source) {
    return 'تم الفحص بواسطة: $source';
  }

  @override
  String get badgeExplanationVerifiedByModerator =>
      'تم التحقق بواسطة مشرف بشري';

  @override
  String get badgeExplanationVerificationPlatinum =>
      'بلاتيني: تصديق عتاد الجهاز، توقيعات تشفيرية، بيانات اعتماد المحتوى (C2PA)، وفحص الذكاء الاصطناعي يؤكّد الأصل البشري.';

  @override
  String get badgeExplanationVerificationGold =>
      'ذهبي: تم التصوير على جهاز حقيقي مع تصديق العتاد، وتوقيعات تشفيرية، وبيانات اعتماد المحتوى (C2PA).';

  @override
  String get badgeExplanationVerificationSilver =>
      'فضي: التوقيعات التشفيرية تثبت أنّ هذا الفيديو لم يعدل منذ التسجيل.';

  @override
  String get badgeExplanationVerificationBronze =>
      'برونزي: توقيعات بيانات أساسية موجودة.';

  @override
  String get badgeExplanationVerificationSilverAiScan =>
      'فضي: فحص الذكاء الاصطناعي يؤكّد أنّ هذا الفيديو من صنع البشر على الأغلب.';

  @override
  String get badgeExplanationNoVerification =>
      'لا توجد بيانات تحقق متاحة لهذا الفيديو.';

  @override
  String get shareMenuTitle => 'مشاركة الفيديو';

  @override
  String get shareMenuReportAiContent => 'الإبلاغ عن محتوى بالذكاء الاصطناعي';

  @override
  String get shareMenuReportAiContentSubtitle =>
      'إبلاغ سريع عن محتوى يُشتبه بأنّه مُنشأ بالذكاء الاصطناعي';

  @override
  String get shareMenuReportingAiContent =>
      'جاري الإبلاغ عن محتوى الذكاء الاصطناعي...';

  @override
  String shareMenuFailedToReportContent(String error) {
    return 'فشل الإبلاغ عن المحتوى: $error';
  }

  @override
  String shareMenuFailedToReportAiContent(String error) {
    return 'فشل الإبلاغ عن محتوى الذكاء الاصطناعي: $error';
  }

  @override
  String get shareMenuVideoStatus => 'حالة الفيديو';

  @override
  String get shareMenuViewAllLists => 'عرض جميع القوائم →';

  @override
  String get shareMenuShareWith => 'مشاركة مع';

  @override
  String get shareMenuShareViaOtherApps => 'مشاركة عبر تطبيقات أخرى';

  @override
  String get shareMenuShareViaOtherAppsSubtitle =>
      'شارك عبر تطبيقات أخرى أو انسخ الرابط';

  @override
  String get shareMenuSaveToGallery => 'حفظ في المعرض';

  @override
  String get shareMenuSaveOriginalSubtitle =>
      'حفظ الفيديو الأصلي في ألبوم الكاميرا';

  @override
  String get shareMenuSaveWithWatermark => 'حفظ مع العلامة المائية';

  @override
  String get shareMenuSaveVideo => 'حفظ الفيديو';

  @override
  String get shareMenuDownloadWithWatermark => 'تنزيل مع علامة Divine المائية';

  @override
  String get shareMenuSaveVideoSubtitle => 'حفظ الفيديو في ألبوم الكاميرا';

  @override
  String get shareMenuLists => 'القوائم';

  @override
  String get shareMenuAddToList => 'إضافة إلى قائمة';

  @override
  String get shareMenuAddToListSubtitle => 'أضف إلى قوائمك المختارة';

  @override
  String get shareMenuCreateNewList => 'إنشاء قائمة جديدة';

  @override
  String get shareMenuCreateNewListSubtitle => 'ابدأ مجموعة مختارة جديدة';

  @override
  String get shareMenuRemovedFromList => 'تمت الإزالة من القائمة';

  @override
  String get shareMenuFailedToRemoveFromList => 'فشلت الإزالة من القائمة';

  @override
  String get shareMenuBookmarks => 'الإشارات المرجعية';

  @override
  String get shareMenuAddToBookmarks => 'إضافة إلى الإشارات المرجعية';

  @override
  String get shareMenuAddToBookmarksSubtitle => 'حفظ للمشاهدة لاحقًا';

  @override
  String get shareMenuAddToBookmarkSet => 'إضافة إلى مجموعة إشارات';

  @override
  String get shareMenuAddToBookmarkSetSubtitle => 'نظّم في مجموعات';

  @override
  String get shareMenuFollowSets => 'مجموعات المتابعة';

  @override
  String get shareMenuCreateFollowSet => 'إنشاء مجموعة متابعة';

  @override
  String get shareMenuCreateFollowSetSubtitle =>
      'ابدأ مجموعة جديدة بهذا الصانع';

  @override
  String get shareMenuAddToFollowSet => 'إضافة إلى مجموعة متابعة';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    return '$count مجموعة متابعة متاحة';
  }

  @override
  String get shareMenuAddedToBookmarks => 'تمت الإضافة إلى الإشارات المرجعية!';

  @override
  String get shareMenuFailedToAddBookmark => 'فشل إضافة الإشارة المرجعية';

  @override
  String shareMenuCreatedListAndAddedVideo(String name) {
    return 'تم إنشاء القائمة \"$name\" وإضافة الفيديو';
  }

  @override
  String get shareMenuManageContent => 'إدارة المحتوى';

  @override
  String get shareMenuEditVideo => 'تعديل الفيديو';

  @override
  String get shareMenuEditVideoSubtitle => 'تحديث العنوان والوصف والوسوم';

  @override
  String get shareMenuDeleteVideo => 'حذف الفيديو';

  @override
  String get shareMenuDeleteVideoSubtitle =>
      'أزِل هذا الفيديو من Divine. قد يظل ظاهرًا في عملاء Nostr آخرين.';

  @override
  String get shareMenuVideoInTheseLists => 'الفيديو في هذه القوائم:';

  @override
  String shareMenuVideoCount(int count) {
    return '$count فيديو';
  }

  @override
  String get shareMenuClose => 'إغلاق';

  @override
  String get shareMenuDeleteConfirmation =>
      'سيتم حذف هذا الفيديو نهائيًا من Divine. قد يظل ظاهرًا في عملاء Nostr الآخرين الذين يستخدمون محولات مختلفة.';

  @override
  String get shareMenuCancel => 'إلغاء';

  @override
  String get shareMenuDelete => 'حذف';

  @override
  String get shareMenuDeletingContent => 'جاري حذف المحتوى...';

  @override
  String get shareMenuDeleteRequestSent => 'تم حذف الفيديو';

  @override
  String get shareMenuDeleteFailedNotInitialized =>
      'الحذف غير جاهز بعد. حاول مرة أخرى بعد لحظة.';

  @override
  String get shareMenuDeleteFailedNotOwner =>
      'يمكنك حذف مقاطع الفيديو الخاصة بك فقط.';

  @override
  String get shareMenuDeleteFailedNotAuthenticated =>
      'سجّل الدخول مرة أخرى، ثم حاول الحذف.';

  @override
  String get shareMenuDeleteFailedCouldNotSign =>
      'لم نتمكن من توقيع طلب الحذف. حاول مرة أخرى.';

  @override
  String get shareMenuDeleteFailedRelayRejected =>
      'Couldn\'t reach the relay. Check your connection and try again.';

  @override
  String get shareMenuDeleteFailedGeneric =>
      'تعذّر حذف هذا الفيديو. حاول مرة أخرى.';

  @override
  String get shareMenuFollowSetName => 'اسم مجموعة المتابعة';

  @override
  String get shareMenuFollowSetNameHint => 'مثل: صناع المحتوى، موسيقيون، إلخ.';

  @override
  String get shareMenuDescriptionOptional => 'الوصف (اختياري)';

  @override
  String get shareMenuCreate => 'إنشاء';

  @override
  String shareMenuCreatedFollowSetAndAddedCreator(String name) {
    return 'تم إنشاء مجموعة المتابعة \"$name\" وإضافة الصانع';
  }

  @override
  String get shareMenuDone => 'تم';

  @override
  String get shareMenuEditTitle => 'العنوان';

  @override
  String get shareMenuEditTitleHint => 'أدخل عنوان الفيديو';

  @override
  String get shareMenuEditDescription => 'الوصف';

  @override
  String get shareMenuEditDescriptionHint => 'أدخل وصف الفيديو';

  @override
  String get shareMenuEditHashtags => 'الوسوم';

  @override
  String get shareMenuEditHashtagsHint => 'وسوم، مفصولة، بفواصل';

  @override
  String get shareMenuEditMetadataNote =>
      'ملحوظة: يمكن تعديل البيانات الوصفية فقط. لا يمكن تغيير محتوى الفيديو.';

  @override
  String get shareMenuDeleting => 'جاري الحذف...';

  @override
  String get shareMenuUpdate => 'تحديث';

  @override
  String get shareMenuVideoUpdated => 'تم تحديث الفيديو بنجاح';

  @override
  String shareMenuFailedToUpdateVideo(String error) {
    return 'فشل تحديث الفيديو: $error';
  }

  @override
  String get shareMenuDeleteVideoQuestion => 'حذف الفيديو؟';

  @override
  String get shareMenuDeleteRelayWarning =>
      'سيرسل هذا طلب حذف إلى المحولات. ملاحظة: قد تحتفظ بعض المحولات بنسخ مخزّنة.';

  @override
  String get shareMenuVideoDeletionRequested => 'تم حذف الفيديو';

  @override
  String get shareMenuContentLabels => 'وسوم المحتوى';

  @override
  String get shareMenuAddContentLabels => 'إضافة وسوم محتوى';

  @override
  String get shareMenuClearAll => 'مسح الكل';

  @override
  String get shareMenuCollaborators => 'المتعاونون';

  @override
  String get shareMenuAddCollaborator => 'إضافة متعاون';

  @override
  String shareMenuMutualFollowRequired(String name) {
    return 'تحتاج إلى متابعة متبادلة مع $name لإضافته كمتعاون.';
  }

  @override
  String get shareMenuLoading => 'جاري التحميل...';

  @override
  String get shareMenuInspiredBy => 'مستوحى من';

  @override
  String get shareMenuAddInspirationCredit => 'إضافة تنويه الإلهام';

  @override
  String get shareMenuCreatorCannotBeReferenced =>
      'لا يمكن الإشارة إلى هذا الصانع.';

  @override
  String get shareMenuUnknown => 'غير معروف';

  @override
  String get shareMenuCreateBookmarkSet => 'إنشاء مجموعة إشارات';

  @override
  String get shareMenuSetName => 'اسم المجموعة';

  @override
  String get shareMenuSetNameHint => 'مثل: المفضلة، مشاهدة لاحقًا، إلخ.';

  @override
  String get shareMenuCreateNewSet => 'إنشاء مجموعة جديدة';

  @override
  String get shareMenuStartNewBookmarkCollection => 'ابدأ مجموعة إشارات جديدة';

  @override
  String get shareMenuNoBookmarkSets =>
      'لا توجد مجموعات إشارات بعد. أنشئ أول واحدة!';

  @override
  String get shareMenuError => 'خطأ';

  @override
  String get shareMenuFailedToLoadBookmarkSets => 'فشل تحميل مجموعات الإشارات';

  @override
  String shareMenuCreatedSetAndAddedVideo(String name) {
    return 'تم إنشاء \"$name\" وإضافة الفيديو';
  }

  @override
  String get shareMenuUseThisSound => 'استخدم هذا الصوت';

  @override
  String get shareMenuOriginalSound => 'صوت أصلي';

  @override
  String get authSessionExpired => 'انتهت جلستك. يرجى تسجيل الدخول مرّة أخرى.';

  @override
  String get authSignInFailed => 'فشل تسجيل الدخول. حاول مرّة أخرى.';

  @override
  String get localeAppLanguage => 'لغة التطبيق';

  @override
  String get localeDeviceDefault => 'افتراضي الجهاز';

  @override
  String get localeSelectLanguage => 'اختر اللغة';

  @override
  String get webAuthNotSupportedSecureMode =>
      'مصادقة الويب غير مدعومة في الوضع الآمن. يرجى استخدام تطبيق الجوال لإدارة المفاتيح بأمان.';

  @override
  String webAuthIntegrationFailed(String error) {
    return 'فشل تكامل المصادقة: $error';
  }

  @override
  String webAuthUnexpectedError(String error) {
    return 'خطأ غير متوقّع: $error';
  }

  @override
  String get webAuthEnterBunkerUri => 'يرجى إدخال رابط bunker';

  @override
  String get webAuthConnectTitle => 'الاتصال بـ Divine';

  @override
  String get webAuthChooseMethod => 'اختر طريقة مصادقة Nostr المفضّلة لديك';

  @override
  String get webAuthBrowserExtension => 'إضافة المتصفح';

  @override
  String get webAuthRecommended => 'موصى به';

  @override
  String get webAuthNsecBunker => 'nsec bunker';

  @override
  String get webAuthConnectRemoteSigner => 'الاتصال بموقّع خارجي';

  @override
  String get webAuthBunkerHint => 'bunker://pubkey?relay=wss://...';

  @override
  String get webAuthPasteFromClipboard => 'لصق من الحافظة';

  @override
  String get webAuthConnectToBunker => 'الاتصال بـ Bunker';

  @override
  String get webAuthNewToNostr => 'جديد على Nostr؟';

  @override
  String get webAuthNostrHelp =>
      'ثبّت إضافة متصفح مثل Alby أو nos2x لتجربة أسهل، أو استخدم nsec bunker للتوقيع الخارجي الآمن.';

  @override
  String get soundsTitle => 'الأصوات';

  @override
  String get soundsSearchHint => 'البحث عن أصوات...';

  @override
  String get soundsPreviewUnavailable => 'تعذر معاينة الصوت - لا يوجد صوت متاح';

  @override
  String soundsPreviewFailed(String error) {
    return 'تعذر تشغيل المعاينة: $error';
  }

  @override
  String get soundsFeaturedSounds => 'أصوات مميزة';

  @override
  String get soundsTrendingSounds => 'أصوات رائجة';

  @override
  String get soundsAllSounds => 'كل الأصوات';

  @override
  String get soundsSearchResults => 'نتائج البحث';

  @override
  String get soundsNoSoundsAvailable => 'لا توجد أصوات متاحة';

  @override
  String get soundsNoSoundsDescription =>
      'ستظهر الأصوات هنا عندما يشارك المنشئون مقاطع صوتية';

  @override
  String get soundsNoSoundsFound => 'لم يُعثر على أصوات';

  @override
  String get soundsNoSoundsFoundDescription => 'جرِّب كلمة بحث مختلفة';

  @override
  String get soundsFailedToLoad => 'تعذر تحميل الأصوات';

  @override
  String get soundsRetry => 'إعادة المحاولة';

  @override
  String get soundsScreenLabel => 'شاشة الأصوات';

  @override
  String get profileTitle => 'الملف الشخصي';

  @override
  String get profileRefresh => 'تحديث';

  @override
  String get profileRefreshLabel => 'تحديث الملف الشخصي';

  @override
  String get profileMoreOptions => 'خيارات أخرى';

  @override
  String profileBlockedUser(String name) {
    return 'تم حظر $name';
  }

  @override
  String profileUnblockedUser(String name) {
    return 'تم إلغاء حظر $name';
  }

  @override
  String profileUnfollowedUser(String name) {
    return 'تم إلغاء متابعة $name';
  }

  @override
  String profileError(String error) {
    return 'خطأ: $error';
  }

  @override
  String get notificationsTabAll => 'الكل';

  @override
  String get notificationsTabLikes => 'الإعجابات';

  @override
  String get notificationsTabComments => 'التعليقات';

  @override
  String get notificationsTabFollows => 'المتابعات';

  @override
  String get notificationsTabReposts => 'إعادة النشر';

  @override
  String get notificationsFailedToLoad => 'تعذر تحميل الإشعارات';

  @override
  String get notificationsRetry => 'إعادة المحاولة';

  @override
  String get notificationsCheckingNew => 'جارٍ التحقق من الإشعارات الجديدة';

  @override
  String get notificationsNoneYet => 'لا توجد إشعارات بعد';

  @override
  String notificationsNoneForType(String type) {
    return 'لا توجد إشعارات $type';
  }

  @override
  String get notificationsEmptyDescription =>
      'عندما يتفاعل الأشخاص مع محتواك، سيظهر هنا';

  @override
  String notificationsLoadingType(String type) {
    return 'جارٍ تحميل إشعارات $type...';
  }

  @override
  String get notificationsInviteSingular =>
      'لديك دعوة واحدة لمشاركتها مع صديق!';

  @override
  String notificationsInvitePlural(int count) {
    return 'لديك $count دعوات لمشاركتها مع الأصدقاء!';
  }

  @override
  String get notificationsVideoNotFound => 'لم يُعثر على الفيديو';

  @override
  String get notificationsVideoUnavailable => 'الفيديو غير متاح';

  @override
  String get notificationsFromNotification => 'من إشعار';

  @override
  String get feedFailedToLoadVideos => 'تعذر تحميل مقاطع الفيديو';

  @override
  String get feedRetry => 'إعادة المحاولة';

  @override
  String get feedNoFollowedUsers =>
      'لا يوجد مستخدمون متابَعون.\nتابِع شخصًا ما لترى مقاطع الفيديو هنا.';

  @override
  String get feedForYouEmpty =>
      'خلاصة \"لك\" فارغة.\nاستكشف مقاطع الفيديو وتابع المبدعين لتشكيلها.';

  @override
  String get feedFollowingEmpty =>
      'لا توجد مقاطع فيديو من الأشخاص الذين تتابعهم بعد.\nاعثر على مبدعين تحبهم وتابعهم.';

  @override
  String get feedLatestEmpty =>
      'لا توجد مقاطع فيديو جديدة بعد.\nعد قريبًا للاطلاع.';

  @override
  String get feedExploreVideos => 'استكشاف مقاطع الفيديو';

  @override
  String get feedExternalVideoSlow => 'الفيديو الخارجي يُحمَّل ببطء';

  @override
  String get feedSkip => 'تخطي';

  @override
  String get uploadWaitingToUpload => 'في انتظار الرفع';

  @override
  String get uploadUploadingVideo => 'جارٍ رفع الفيديو';

  @override
  String get uploadProcessingVideo => 'جارٍ معالجة الفيديو';

  @override
  String get uploadProcessingComplete => 'اكتملت المعالجة';

  @override
  String get uploadPublishedSuccessfully => 'تم النشر بنجاح';

  @override
  String get uploadFailed => 'فشل الرفع';

  @override
  String get uploadRetrying => 'جارٍ إعادة محاولة الرفع';

  @override
  String get uploadPaused => 'الرفع متوقف مؤقتًا';

  @override
  String uploadPercentComplete(int percent) {
    return '$percent% مكتمل';
  }

  @override
  String get uploadQueuedMessage => 'فيديوك في قائمة انتظار الرفع';

  @override
  String get uploadUploadingMessage => 'جارٍ الرفع إلى الخادم...';

  @override
  String get uploadProcessingMessage =>
      'جارٍ معالجة الفيديو - قد يستغرق هذا بضع دقائق';

  @override
  String get uploadReadyToPublishMessage =>
      'تمت معالجة الفيديو بنجاح وهو جاهز للنشر';

  @override
  String get uploadPublishedMessage => 'تم نشر الفيديو في ملفك الشخصي';

  @override
  String get uploadFailedMessage => 'فشل الرفع - يُرجى المحاولة مرة أخرى';

  @override
  String get uploadRetryingMessage => 'جارٍ إعادة محاولة الرفع...';

  @override
  String get uploadPausedMessage => 'أوقف المستخدم الرفع مؤقتًا';

  @override
  String get uploadRetryButton => 'إعادة المحاولة';

  @override
  String uploadRetryFailed(String error) {
    return 'تعذرت إعادة محاولة الرفع: $error';
  }

  @override
  String get userSearchPrompt => 'البحث عن مستخدمين';

  @override
  String get userSearchNoResults => 'لم يُعثر على مستخدمين';

  @override
  String get userSearchFailed => 'فشل البحث';

  @override
  String get forgotPasswordTitle => 'إعادة تعيين كلمة المرور';

  @override
  String get forgotPasswordDescription =>
      'أدخل بريدك الإلكتروني وسنُرسل إليك رابطًا لإعادة تعيين كلمة المرور.';

  @override
  String get forgotPasswordEmailLabel => 'البريد الإلكتروني';

  @override
  String get forgotPasswordCancel => 'إلغاء';

  @override
  String get forgotPasswordSendLink => 'إرسال رابط إعادة التعيين';

  @override
  String get ageVerificationContentWarning => 'تحذير محتوى';

  @override
  String get ageVerificationTitle => 'التحقق من العمر';

  @override
  String get ageVerificationAdultDescription =>
      'تم وسم هذا المحتوى باعتباره قد يحتوي على مواد للبالغين. يجب أن يكون عمرك 18 عامًا أو أكثر لمشاهدته.';

  @override
  String get ageVerificationCreationDescription =>
      'لاستخدام الكاميرا وإنشاء محتوى، يجب أن يكون عمرك 16 عامًا على الأقل.';

  @override
  String get ageVerificationAdultQuestion => 'هل عمرك 18 عامًا أو أكثر؟';

  @override
  String get ageVerificationCreationQuestion => 'هل عمرك 16 عامًا أو أكثر؟';

  @override
  String get ageVerificationNo => 'لا';

  @override
  String get ageVerificationYes => 'نعم';

  @override
  String get shareLinkCopied => 'تم نسخ الرابط إلى الحافظة';

  @override
  String get shareFailedToCopy => 'تعذر نسخ الرابط';

  @override
  String get shareVideoSubject => 'شاهد هذا الفيديو على Divine';

  @override
  String get shareFailedToShare => 'تعذرت المشاركة';

  @override
  String get shareVideoTitle => 'مشاركة الفيديو';

  @override
  String get shareToApps => 'مشاركة إلى التطبيقات';

  @override
  String get shareToAppsSubtitle => 'شارك عبر تطبيقات المراسلة ووسائل التواصل';

  @override
  String get shareCopyWebLink => 'نسخ رابط الويب';

  @override
  String get shareCopyWebLinkSubtitle => 'انسخ رابط ويب قابلًا للمشاركة';

  @override
  String get shareCopyNostrLink => 'نسخ رابط Nostr';

  @override
  String get shareCopyNostrLinkSubtitle => 'انسخ رابط nevent لعملاء Nostr';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navExplore => 'استكشاف';

  @override
  String get navInbox => 'الوارد';

  @override
  String get navProfile => 'الملف الشخصي';

  @override
  String get navMyProfile => 'ملفي الشخصي';

  @override
  String get navNotifications => 'الإشعارات';

  @override
  String get navOpenCamera => 'فتح الكاميرا';

  @override
  String get navUnknown => 'غير معروف';

  @override
  String get navExploreClassics => 'الكلاسيكيات';

  @override
  String get navExploreNewVideos => 'فيديوهات جديدة';

  @override
  String get navExploreTrending => 'الرائجة';

  @override
  String get navExploreForYou => 'مُقترَح لك';

  @override
  String get navExploreLists => 'القوائم';

  @override
  String get routeErrorTitle => 'خطأ';

  @override
  String get routeInvalidHashtag => 'وسم غير صالح';

  @override
  String get routeInvalidConversationId => 'مُعرِّف محادثة غير صالح';

  @override
  String get routeInvalidRequestId => 'مُعرِّف طلب غير صالح';

  @override
  String get routeInvalidListId => 'مُعرِّف قائمة غير صالح';

  @override
  String get routeInvalidUserId => 'مُعرِّف مستخدم غير صالح';

  @override
  String get routeInvalidVideoId => 'مُعرِّف فيديو غير صالح';

  @override
  String get routeInvalidSoundId => 'مُعرِّف صوت غير صالح';

  @override
  String get routeInvalidCategory => 'فئة غير صالحة';

  @override
  String get routeNoVideosToDisplay => 'لا توجد مقاطع فيديو لعرضها';

  @override
  String get routeInvalidProfileId => 'مُعرِّف ملف شخصي غير صالح';

  @override
  String get routeDefaultListName => 'قائمة';

  @override
  String get supportTitle => 'مركز الدعم';

  @override
  String get supportContactSupport => 'التواصل مع الدعم';

  @override
  String get supportContactSupportSubtitle =>
      'ابدأ محادثة أو اطّلع على الرسائل السابقة';

  @override
  String get supportReportBug => 'الإبلاغ عن خطأ';

  @override
  String get supportReportBugSubtitle => 'مشاكل تقنية في التطبيق';

  @override
  String get supportRequestFeature => 'طلب ميزة';

  @override
  String get supportRequestFeatureSubtitle => 'اقتراح تحسين أو ميزة جديدة';

  @override
  String get supportSaveLogs => 'حفظ السجلات';

  @override
  String get supportSaveLogsSubtitle => 'تصدير السجلات إلى ملف للإرسال يدويًا';

  @override
  String get supportFaq => 'الأسئلة الشائعة';

  @override
  String get supportFaqSubtitle => 'الأسئلة والأجوبة الشائعة';

  @override
  String get supportProofMode => 'Proofmode';

  @override
  String get supportProofModeSubtitle => 'تعرَّف على التحقق والأصالة';

  @override
  String get supportLoginRequired => 'سجِّل الدخول للتواصل مع الدعم';

  @override
  String get supportExportingLogs => 'جارٍ تصدير السجلات...';

  @override
  String get supportExportLogsFailed => 'تعذر تصدير السجلات';

  @override
  String get supportChatNotAvailable => 'محادثة الدعم غير متاحة';

  @override
  String get supportCouldNotOpenMessages => 'تعذر فتح رسائل الدعم';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return 'تعذر فتح $pageName';
  }

  @override
  String supportErrorOpeningPage(String pageName, Object error) {
    return 'خطأ في فتح $pageName: $error';
  }

  @override
  String get reportTitle => 'الإبلاغ عن محتوى';

  @override
  String get reportWhyReporting => 'لماذا تُبلِّغ عن هذا المحتوى؟';

  @override
  String get reportPolicyNotice =>
      'ستتصرف Divine بشأن بلاغات المحتوى خلال 24 ساعة بإزالة المحتوى وإخراج المستخدم الذي قدَّم المحتوى المخالف.';

  @override
  String get reportAdditionalDetails => 'تفاصيل إضافية (اختياري)';

  @override
  String get reportBlockUser => 'حظر هذا المستخدم';

  @override
  String get reportCancel => 'إلغاء';

  @override
  String get reportSubmit => 'إبلاغ';

  @override
  String get reportSelectReason => 'يُرجى اختيار سبب للإبلاغ عن هذا المحتوى';

  @override
  String get reportReasonSpam => 'محتوى غير مرغوب فيه أو مزعج';

  @override
  String get reportReasonHarassment => 'تحرُّش أو تنمُّر أو تهديدات';

  @override
  String get reportReasonViolence => 'محتوى عنيف أو متطرف';

  @override
  String get reportReasonSexualContent => 'محتوى جنسي أو للبالغين';

  @override
  String get reportReasonCopyright => 'انتهاك حقوق الملكية';

  @override
  String get reportReasonFalseInfo => 'معلومات كاذبة';

  @override
  String get reportReasonCsam => 'انتهاك سلامة الأطفال';

  @override
  String get reportReasonAiGenerated => 'محتوى مُولَّد بالذكاء الاصطناعي';

  @override
  String get reportReasonOther => 'انتهاك آخر للسياسة';

  @override
  String reportFailed(Object error) {
    return 'تعذر الإبلاغ عن المحتوى: $error';
  }

  @override
  String get reportReceivedTitle => 'تم استلام البلاغ';

  @override
  String get reportReceivedThankYou =>
      'شكرًا لمساعدتك في الحفاظ على سلامة Divine.';

  @override
  String get reportReceivedReviewNotice =>
      'سيُراجع فريقنا بلاغك ويتخذ الإجراء المناسب. قد تتلقى تحديثات عبر رسالة مباشرة.';

  @override
  String get reportLearnMore => 'اعرف المزيد';

  @override
  String get reportSafetyUrl => 'divine.video/safety';

  @override
  String get reportClose => 'إغلاق';

  @override
  String get listAddToList => 'إضافة إلى قائمة';

  @override
  String listVideoCount(int count) {
    return '$count مقاطع فيديو';
  }

  @override
  String get listNewList => 'قائمة جديدة';

  @override
  String get listDone => 'تم';

  @override
  String get listErrorLoading => 'تعذر تحميل القوائم';

  @override
  String listRemovedFrom(String name) {
    return 'تمت الإزالة من $name';
  }

  @override
  String listAddedTo(String name) {
    return 'تمت الإضافة إلى $name';
  }

  @override
  String get listCreateNewList => 'إنشاء قائمة جديدة';

  @override
  String get listNameLabel => 'اسم القائمة';

  @override
  String get listDescriptionLabel => 'الوصف (اختياري)';

  @override
  String get listPublicList => 'قائمة عامة';

  @override
  String get listPublicListSubtitle =>
      'يمكن للآخرين متابعة هذه القائمة ورؤيتها';

  @override
  String get listCancel => 'إلغاء';

  @override
  String get listCreate => 'إنشاء';

  @override
  String get listCreateFailed => 'تعذر إنشاء القائمة';

  @override
  String get keyManagementTitle => 'مفاتيح Nostr';

  @override
  String get keyManagementWhatAreKeys => 'ما هي مفاتيح Nostr؟';

  @override
  String get keyManagementExplanation =>
      'هويتك في Nostr عبارة عن زوج مفاتيح مُشفَّرة:\n\n• مفتاحك العام (npub) بمثابة اسم المستخدم - شاركه بحرية\n• مفتاحك الخاص (nsec) بمثابة كلمة المرور - احتفظ به سريًا!\n\nيُتيح لك nsec الوصول إلى حسابك على أي تطبيق Nostr.';

  @override
  String get keyManagementImportTitle => 'استيراد مفتاح موجود';

  @override
  String get keyManagementImportSubtitle =>
      'هل لديك حساب Nostr بالفعل؟ الصق مفتاحك الخاص (nsec) للوصول إليه هنا.';

  @override
  String get keyManagementImportButton => 'استيراد المفتاح';

  @override
  String get keyManagementImportWarning => 'سيحل هذا محل مفتاحك الحالي!';

  @override
  String get keyManagementBackupTitle => 'النسخ الاحتياطي لمفتاحك';

  @override
  String get keyManagementBackupSubtitle =>
      'احفظ مفتاحك الخاص (nsec) لاستخدام حسابك في تطبيقات Nostr أخرى.';

  @override
  String get keyManagementCopyNsec => 'نسخ مفتاحي الخاص (nsec)';

  @override
  String get keyManagementNeverShare => 'لا تُشارك nsec مع أي شخص أبدًا!';

  @override
  String get keyManagementPasteKey => 'يُرجى لصق مفتاحك الخاص';

  @override
  String get keyManagementInvalidFormat =>
      'تنسيق مفتاح غير صالح. يجب أن يبدأ بـ \"nsec1\"';

  @override
  String get keyManagementConfirmImportTitle => 'استيراد هذا المفتاح؟';

  @override
  String get keyManagementConfirmImportBody =>
      'سيحل هذا محل هويتك الحالية بالهوية المستوردة.\n\nسيُفقد مفتاحك الحالي ما لم تقم بعمل نسخة احتياطية منه أولًا.';

  @override
  String get keyManagementImportConfirm => 'استيراد';

  @override
  String get keyManagementImportSuccess => 'تم استيراد المفتاح بنجاح!';

  @override
  String keyManagementImportFailed(Object error) {
    return 'تعذر استيراد المفتاح: $error';
  }

  @override
  String get keyManagementExportSuccess =>
      'تم نسخ المفتاح الخاص إلى الحافظة!\n\nاحفظه في مكان آمن.';

  @override
  String keyManagementExportFailed(Object error) {
    return 'تعذر تصدير المفتاح: $error';
  }

  @override
  String get saveOriginalSavedToCameraRoll => 'تم الحفظ في ألبوم الكاميرا';

  @override
  String get saveOriginalShare => 'مشاركة';

  @override
  String get saveOriginalDone => 'تم';

  @override
  String get saveOriginalPhotosAccessNeeded => 'مطلوب الوصول إلى الصور';

  @override
  String get saveOriginalPhotosAccessMessage =>
      'لحفظ مقاطع الفيديو، اسمح بالوصول إلى الصور في الإعدادات.';

  @override
  String get saveOriginalOpenSettings => 'فتح الإعدادات';

  @override
  String get saveOriginalNotNow => 'ليس الآن';

  @override
  String get cameraPermissionNotNow => 'ليس الآن';

  @override
  String get saveOriginalDownloadFailed => 'فشل التنزيل';

  @override
  String get saveOriginalDismiss => 'إخفاء';

  @override
  String get saveOriginalDownloadingVideo => 'جارٍ تنزيل الفيديو';

  @override
  String get saveOriginalSavingToCameraRoll => 'جارٍ الحفظ في ألبوم الكاميرا';

  @override
  String get saveOriginalFetchingVideo => 'جارٍ جلب الفيديو من الشبكة...';

  @override
  String get saveOriginalSavingVideo =>
      'جارٍ حفظ الفيديو الأصلي في ألبوم الكاميرا...';

  @override
  String get soundTitle => 'الصوت';

  @override
  String get soundOriginalSound => 'الصوت الأصلي';

  @override
  String get soundVideosUsingThisSound => 'مقاطع الفيديو التي تستخدم هذا الصوت';

  @override
  String get soundSourceVideo => 'فيديو المصدر';

  @override
  String get soundNoVideosYet => 'لا توجد مقاطع فيديو بعد';

  @override
  String get soundBeFirstToUse => 'كُن أول من يستخدم هذا الصوت!';

  @override
  String get soundFailedToLoadVideos => 'تعذر تحميل مقاطع الفيديو';

  @override
  String get soundRetry => 'إعادة المحاولة';

  @override
  String get soundVideosUnavailable => 'مقاطع الفيديو غير متاحة';

  @override
  String get soundCouldNotLoadDetails => 'تعذر تحميل تفاصيل الفيديو';

  @override
  String get soundPreview => 'معاينة';

  @override
  String get soundStop => 'إيقاف';

  @override
  String get soundUseSound => 'استخدام الصوت';

  @override
  String get soundNoVideoCount => 'لا توجد مقاطع فيديو بعد';

  @override
  String get soundOneVideo => 'فيديو واحد';

  @override
  String soundVideoCount(int count) {
    return '$count مقاطع فيديو';
  }

  @override
  String get soundUnableToPreview => 'تعذر معاينة الصوت - لا يوجد صوت متاح';

  @override
  String soundPreviewFailed(Object error) {
    return 'تعذر تشغيل المعاينة: $error';
  }

  @override
  String get soundViewSource => 'عرض المصدر';

  @override
  String get soundCloseTooltip => 'إغلاق';

  @override
  String get exploreNotExploreRoute => 'ليس مسار استكشاف';

  @override
  String get legalTitle => 'قانوني';

  @override
  String get legalTermsOfService => 'شروط الخدمة';

  @override
  String get legalTermsOfServiceSubtitle => 'شروط وأحكام الاستخدام';

  @override
  String get legalPrivacyPolicy => 'سياسة الخصوصية';

  @override
  String get legalPrivacyPolicySubtitle => 'كيف نتعامل مع بياناتك';

  @override
  String get legalSafetyStandards => 'معايير السلامة';

  @override
  String get legalSafetyStandardsSubtitle => 'إرشادات المجتمع والسلامة';

  @override
  String get legalDmca => 'DMCA';

  @override
  String get legalDmcaSubtitle => 'سياسة حقوق النشر والإزالة';

  @override
  String get legalOpenSourceLicenses => 'تراخيص المصدر المفتوح';

  @override
  String get legalOpenSourceLicensesSubtitle => 'نسب حقوق حزم الطرف الثالث';

  @override
  String get legalAppName => 'Divine';

  @override
  String legalCouldNotOpenPage(String pageName) {
    return 'تعذر فتح $pageName';
  }

  @override
  String legalErrorOpeningPage(String pageName, Object error) {
    return 'خطأ في فتح $pageName: $error';
  }

  @override
  String get categoryAction => 'أكشن';

  @override
  String get categoryAdventure => 'مغامرة';

  @override
  String get categoryAnimals => 'حيوانات';

  @override
  String get categoryAnimation => 'رسوم متحركة';

  @override
  String get categoryArchitecture => 'هندسة معمارية';

  @override
  String get categoryArt => 'فن';

  @override
  String get categoryAutomotive => 'سيارات';

  @override
  String get categoryAwardShow => 'حفل جوائز';

  @override
  String get categoryAwards => 'جوائز';

  @override
  String get categoryBaseball => 'بيسبول';

  @override
  String get categoryBasketball => 'كرة السلة';

  @override
  String get categoryBeauty => 'جمال';

  @override
  String get categoryBeverage => 'مشروبات';

  @override
  String get categoryCars => 'سيارات';

  @override
  String get categoryCelebration => 'احتفال';

  @override
  String get categoryCelebrities => 'مشاهير';

  @override
  String get categoryCelebrity => 'مشهور';

  @override
  String get categoryCityscape => 'مناظر المدينة';

  @override
  String get categoryComedy => 'كوميديا';

  @override
  String get categoryConcert => 'حفلة موسيقية';

  @override
  String get categoryCooking => 'طبخ';

  @override
  String get categoryCostume => 'أزياء';

  @override
  String get categoryCrafts => 'حرف يدوية';

  @override
  String get categoryCrime => 'جريمة';

  @override
  String get categoryCulture => 'ثقافة';

  @override
  String get categoryDance => 'رقص';

  @override
  String get categoryDiy => 'اصنعها بنفسك';

  @override
  String get categoryDrama => 'دراما';

  @override
  String get categoryEducation => 'تعليم';

  @override
  String get categoryEmotional => 'عاطفي';

  @override
  String get categoryEmotions => 'مشاعر';

  @override
  String get categoryEntertainment => 'ترفيه';

  @override
  String get categoryEvent => 'حدث';

  @override
  String get categoryFamily => 'عائلة';

  @override
  String get categoryFans => 'معجبون';

  @override
  String get categoryFantasy => 'خيال';

  @override
  String get categoryFashion => 'أزياء';

  @override
  String get categoryFestival => 'مهرجان';

  @override
  String get categoryFilm => 'فيلم';

  @override
  String get categoryFitness => 'لياقة';

  @override
  String get categoryFood => 'طعام';

  @override
  String get categoryFootball => 'كرة قدم';

  @override
  String get categoryFurniture => 'أثاث';

  @override
  String get categoryGaming => 'ألعاب';

  @override
  String get categoryGolf => 'غولف';

  @override
  String get categoryGrooming => 'العناية الشخصية';

  @override
  String get categoryGuitar => 'غيتار';

  @override
  String get categoryHalloween => 'هالوين';

  @override
  String get categoryHealth => 'صحة';

  @override
  String get categoryHockey => 'هوكي';

  @override
  String get categoryHoliday => 'عطلة';

  @override
  String get categoryHome => 'منزل';

  @override
  String get categoryHomeImprovement => 'تحسين المنزل';

  @override
  String get categoryHorror => 'رعب';

  @override
  String get categoryHospital => 'مستشفى';

  @override
  String get categoryHumor => 'فكاهة';

  @override
  String get categoryInteriorDesign => 'تصميم داخلي';

  @override
  String get categoryInterview => 'مقابلة';

  @override
  String get categoryKids => 'أطفال';

  @override
  String get categoryLifestyle => 'أسلوب حياة';

  @override
  String get categoryMagic => 'سحر';

  @override
  String get categoryMakeup => 'مكياج';

  @override
  String get categoryMedical => 'طبي';

  @override
  String get categoryMusic => 'موسيقى';

  @override
  String get categoryMystery => 'غموض';

  @override
  String get categoryNature => 'طبيعة';

  @override
  String get categoryNews => 'أخبار';

  @override
  String get categoryOutdoor => 'أنشطة خارجية';

  @override
  String get categoryParty => 'حفلة';

  @override
  String get categoryPeople => 'أشخاص';

  @override
  String get categoryPerformance => 'أداء';

  @override
  String get categoryPets => 'حيوانات أليفة';

  @override
  String get categoryPolitics => 'سياسة';

  @override
  String get categoryPrank => 'مقلب';

  @override
  String get categoryPranks => 'مقالب';

  @override
  String get categoryRealityShow => 'برنامج واقعي';

  @override
  String get categoryRelationship => 'علاقة';

  @override
  String get categoryRelationships => 'علاقات';

  @override
  String get categoryRomance => 'رومانسية';

  @override
  String get categorySchool => 'مدرسة';

  @override
  String get categoryScienceFiction => 'خيال علمي';

  @override
  String get categorySelfie => 'سيلفي';

  @override
  String get categoryShopping => 'تسوق';

  @override
  String get categorySkateboarding => 'تزلج على اللوح';

  @override
  String get categorySkincare => 'العناية بالبشرة';

  @override
  String get categorySoccer => 'كرة قدم';

  @override
  String get categorySocialGathering => 'تجمع اجتماعي';

  @override
  String get categorySocialMedia => 'وسائل التواصل';

  @override
  String get categorySports => 'رياضة';

  @override
  String get categoryTalkShow => 'برنامج حواري';

  @override
  String get categoryTech => 'تقنية';

  @override
  String get categoryTechnology => 'تكنولوجيا';

  @override
  String get categoryTelevision => 'تلفزيون';

  @override
  String get categoryToys => 'ألعاب';

  @override
  String get categoryTransportation => 'نقل';

  @override
  String get categoryTravel => 'سفر';

  @override
  String get categoryUrban => 'حضري';

  @override
  String get categoryViolence => 'عنف';

  @override
  String get categoryVlog => 'مدونة فيديو';

  @override
  String get categoryVlogging => 'تدوين فيديو';

  @override
  String get categoryWrestling => 'مصارعة';

  @override
  String get profileSetupUploadSuccess => 'تم رفع صورة الملف الشخصي بنجاح!';

  @override
  String inboxReportedUser(String displayName) {
    return 'تم الإبلاغ عن $displayName';
  }

  @override
  String inboxBlockedUser(String displayName) {
    return 'تم حظر $displayName';
  }

  @override
  String inboxUnblockedUser(String displayName) {
    return 'تم إلغاء حظر $displayName';
  }

  @override
  String get inboxRemovedConversation => 'تمت إزالة المحادثة';

  @override
  String get inboxEmptyTitle => 'No messages yet';

  @override
  String get inboxEmptySubtitle => 'That + button won\'t bite.';

  @override
  String get inboxActionMute => 'Mute conversation';

  @override
  String inboxActionReport(String displayName) {
    return 'Report $displayName';
  }

  @override
  String inboxActionBlock(String displayName) {
    return 'Block $displayName';
  }

  @override
  String inboxActionUnblock(String displayName) {
    return 'Unblock $displayName';
  }

  @override
  String get inboxActionRemove => 'Remove conversation';

  @override
  String get inboxRemoveConfirmTitle => 'Remove conversation?';

  @override
  String inboxRemoveConfirmBody(String displayName) {
    return 'This will delete your conversation with $displayName. This action cannot be undone.';
  }

  @override
  String get inboxRemoveConfirmConfirm => 'Remove';

  @override
  String get inboxConversationMuted => 'Conversation muted';

  @override
  String get inboxConversationUnmuted => 'Conversation unmuted';

  @override
  String get reportDialogCancel => 'إلغاء';

  @override
  String get reportDialogReport => 'إبلاغ';

  @override
  String exploreVideoId(String id) {
    return 'المعرّف: $id';
  }

  @override
  String exploreVideoTitle(String title) {
    return 'العنوان: $title';
  }

  @override
  String exploreVideoCounter(int current, int total) {
    return 'فيديو $current/$total';
  }

  @override
  String discoverListsFailedToUpdateSubscription(String error) {
    return 'فشل تحديث الاشتراك: $error';
  }

  @override
  String get commonRetry => 'إعادة المحاولة';

  @override
  String get commonDelete => 'حذف';

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get videoMetadataTags => 'الوسوم';

  @override
  String get videoMetadataExpiration => 'انتهاء الصلاحية';

  @override
  String get videoMetadataContentWarnings => 'تحذيرات المحتوى';

  @override
  String get videoEditorLayers => 'الطبقات';

  @override
  String get videoEditorStickers => 'الملصقات';

  @override
  String get trendingTitle => 'الرائج';

  @override
  String get proofmodeCheckAiGenerated =>
      'التحقق إذا كان مُنشأً بالذكاء الاصطناعي';

  @override
  String get libraryDeleteConfirm => 'حذف';

  @override
  String get libraryWebUnavailableHeadline =>
      'المكتبة متوفّرة في التطبيق على الجوال';

  @override
  String get libraryWebUnavailableDescription =>
      'تُحفظ المسودات والمقاطع على جهازك. افتح Divine على هاتفك لإدارتها.';

  @override
  String get libraryTabDrafts => 'مسودات';

  @override
  String get libraryTabClips => 'مقاطع';

  @override
  String get librarySaveToCameraRollTooltip => 'حفظ في ألبوم الكاميرا';

  @override
  String get libraryDeleteSelectedClipsTooltip => 'حذف المقاطع المحددة';

  @override
  String get libraryDeleteClipsTitle => 'حذف المقاطع';

  @override
  String libraryDeleteClipsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# مقاطع محددة',
      one: 'مقطع واحد محدد',
    );
    return 'هل تريد حذف $_temp0؟';
  }

  @override
  String get libraryDeleteClipsWarning =>
      'لا يمكن التراجع. ستُزال ملفات الفيديو نهائيًا من جهازك.';

  @override
  String get libraryPreparingVideo => 'جاري تجهيز الفيديو...';

  @override
  String get libraryCreateVideo => 'إنشاء فيديو';

  @override
  String libraryClipsSavedToDestination(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مقاطع',
      one: 'مقطع واحد',
    );
    return '$_temp0 تم حفظه في $destination';
  }

  @override
  String libraryClipsSavePartialResult(int successCount, int failureCount) {
    return 'تم حفظ $successCount، فشل $failureCount';
  }

  @override
  String libraryGalleryPermissionDenied(String destination) {
    return 'تم رفض إذن $destination';
  }

  @override
  String libraryClipsDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم حذف $count مقاطع',
      one: 'تم حذف مقطع واحد',
    );
    return '$_temp0';
  }

  @override
  String get libraryCouldNotLoadDrafts => 'تعذّر تحميل المسودات';

  @override
  String get libraryCouldNotLoadClips => 'تعذّر تحميل المقاطع';

  @override
  String get libraryOpenErrorDescription =>
      'حدث خطأ أثناء فتح المكتبة. يمكنك المحاولة مرة أخرى.';

  @override
  String get libraryNoDraftsYetTitle => 'لا توجد مسودات بعد';

  @override
  String get libraryNoDraftsYetSubtitle =>
      'ستُظهر الفيديو الذي تحفظه كمسودة هنا';

  @override
  String get libraryNoClipsYetTitle => 'لا توجد مقاطع بعد';

  @override
  String get libraryNoClipsYetSubtitle => 'ستُظهر مقاطع الفيديو المسجّلة هنا';

  @override
  String get libraryDraftDeletedSnackbar => 'تم حذف المسودة';

  @override
  String get libraryDraftDeleteFailedSnackbar => 'تعذّر حذف المسودة';

  @override
  String get libraryDraftActionPost => 'نشر';

  @override
  String get libraryDraftActionEdit => 'تعديل';

  @override
  String get libraryDraftActionDelete => 'حذف المسودة';

  @override
  String get libraryDeleteDraftTitle => 'حذف المسودة';

  @override
  String libraryDeleteDraftMessage(String title) {
    return 'هل تريد حذُ “$title”؟';
  }

  @override
  String get libraryDeleteClipTitle => 'حذف المقطع';

  @override
  String get libraryDeleteClipMessage => 'هل تريد حذف هذا المقطع؟';

  @override
  String get libraryClipSelectionTitle => 'مقاطع';

  @override
  String librarySecondsRemaining(String seconds) {
    return 'متبقى $seconds ث';
  }

  @override
  String get libraryAddClips => 'إضافة';

  @override
  String get libraryRecordVideo => 'تسجيل فيديو';

  @override
  String get routerInvalidCreator => 'منشئ غير صالح';

  @override
  String get routerInvalidHashtagRoute => 'مسار هاشتاغ غير صالح';

  @override
  String get categoryGalleryCouldNotLoadVideos => 'تعذّر تحميل الفيديوهات';

  @override
  String get categoriesCouldNotLoadCategories => 'تعذّر تحميل الفئات';

  @override
  String get notificationFollowBack => 'متابعة بالمقابل';

  @override
  String get followingFailedToLoadList => 'فشل تحميل قائمة المتابَعين';

  @override
  String get followersFailedToLoadList => 'فشل تحميل قائمة المتابعين';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String blossomFailedToSaveSettings(String error) {
    return 'فشل حفظ الإعدادات: $error';
  }

  @override
  String get blueskyFailedToUpdateCrosspost => 'فشل تحديث إعداد النشر المتقاطع';

  @override
  String get invitesTitle => 'دعوة الأصدقاء';

  @override
  String get searchSomethingWentWrong => 'حدث خطأ ما';

  @override
  String get searchTryAgain => 'حاول مجددًا';

  @override
  String get searchForLists => 'البحث عن قوائم';

  @override
  String get searchFindCuratedVideoLists => 'ابحث عن قوائم فيديو مختارة';

  @override
  String get cameraAgeRestriction =>
      'يجب أن يكون عمرك 16 عامًا أو أكثر لإنشاء محتوى';

  @override
  String get featureRequestCancel => 'إلغاء';

  @override
  String keyImportError(String error) {
    return 'خطأ: $error';
  }

  @override
  String get timeNow => 'الآن';

  @override
  String timeShortMinutes(int count) {
    return '$count د';
  }

  @override
  String timeShortHours(int count) {
    return '$count س';
  }

  @override
  String timeShortDays(int count) {
    return '$count ي';
  }

  @override
  String timeShortWeeks(int count) {
    return '$count أ';
  }

  @override
  String timeShortMonths(int count) {
    return '$count ش';
  }

  @override
  String timeShortYears(int count) {
    return '$count سن';
  }

  @override
  String get timeVerboseNow => 'الآن';

  @override
  String timeAgo(String time) {
    return 'منذ $time';
  }

  @override
  String get timeToday => 'اليوم';

  @override
  String get timeYesterday => 'أمس';

  @override
  String get timeJustNow => 'الآن';

  @override
  String timeMinutesAgo(int count) {
    return 'منذ $count د';
  }

  @override
  String timeHoursAgo(int count) {
    return 'منذ $count س';
  }

  @override
  String timeDaysAgo(int count) {
    return 'منذ $count ي';
  }

  @override
  String get draftTimeJustNow => 'الآن';

  @override
  String get contentLabelNudity => 'عُري';

  @override
  String get contentLabelSexualContent => 'محتوى جنسي';

  @override
  String get contentLabelPornography => 'إباحية';

  @override
  String get contentLabelGraphicMedia => 'محتوى صادم';

  @override
  String get contentLabelViolence => 'عنف';

  @override
  String get contentLabelSelfHarm => 'إيذاء النفس/انتحار';

  @override
  String get contentLabelDrugUse => 'تعاطي المخدرات';

  @override
  String get contentLabelAlcohol => 'كحول';

  @override
  String get contentLabelTobacco => 'تبغ/تدخين';

  @override
  String get contentLabelGambling => 'قمار';

  @override
  String get contentLabelProfanity => 'ألفاظ بذيئة';

  @override
  String get contentLabelHateSpeech => 'خطاب كراهية';

  @override
  String get contentLabelHarassment => 'تحرّش';

  @override
  String get contentLabelFlashingLights => 'أضواء وامضة';

  @override
  String get contentLabelAiGenerated => 'محتوى مُولّد بالذكاء الاصطناعي';

  @override
  String get contentLabelDeepfake => 'Deepfake';

  @override
  String get contentLabelSpam => 'بريد مزعج';

  @override
  String get contentLabelScam => 'احتيال';

  @override
  String get contentLabelSpoiler => 'حرق أحداث';

  @override
  String get contentLabelMisleading => 'مُضلِّل';

  @override
  String get contentLabelSensitiveContent => 'محتوى حسّاس';

  @override
  String notificationLikedYourVideo(String actorName) {
    return '$actorName أعجب بفيديوك';
  }

  @override
  String notificationCommentedOnYourVideo(String actorName) {
    return '$actorName علّق على فيديوك';
  }

  @override
  String notificationStartedFollowing(String actorName) {
    return '$actorName بدأ بمتابعتك';
  }

  @override
  String notificationMentionedYou(String actorName) {
    return '$actorName أشار إليك';
  }

  @override
  String notificationRepostedYourVideo(String actorName) {
    return '$actorName أعاد نشر فيديوك';
  }

  @override
  String get draftUntitled => 'بدون عنوان';

  @override
  String get contentWarningNone => 'بلا';

  @override
  String get textBackgroundNone => 'بلا';

  @override
  String get textBackgroundSolid => 'مُصمَت';

  @override
  String get textBackgroundHighlight => 'تمييز';

  @override
  String get textBackgroundTransparent => 'شفاف';

  @override
  String get textAlignLeft => 'يسار';

  @override
  String get textAlignRight => 'يمين';

  @override
  String get textAlignCenter => 'وسط';

  @override
  String get cameraPermissionWebUnsupportedTitle =>
      'الكاميرا غير مدعومة على الويب بعد';

  @override
  String get cameraPermissionWebUnsupportedDescription =>
      'التقاط الكاميرا وتسجيلها غير متاحين في إصدار الويب بعد.';

  @override
  String get cameraPermissionBackToFeed => 'العودة إلى الخلاصة';

  @override
  String get cameraPermissionErrorTitle => 'خطأ في الأذونات';

  @override
  String get cameraPermissionErrorDescription =>
      'حدث خطأ أثناء التحقق من الأذونات.';

  @override
  String get cameraPermissionRetry => 'إعادة المحاولة';

  @override
  String get cameraPermissionAllowAccessTitle =>
      'السماح بالوصول إلى الكاميرا والميكروفون';

  @override
  String get cameraPermissionAllowAccessDescription =>
      'يتيح لك هذا التقاط الفيديوهات وتعديلها مباشرة داخل التطبيق، ولا شيء أكثر.';

  @override
  String get cameraPermissionContinue => 'متابعة';

  @override
  String get cameraPermissionGoToSettings => 'الذهاب إلى الإعدادات';

  @override
  String get metadataCaptionsLabel => 'Captions';

  @override
  String get metadataCaptionsEnabledSemantics =>
      'Captions enabled for all videos';

  @override
  String get metadataCaptionsDisabledSemantics =>
      'Captions disabled for all videos';
}
