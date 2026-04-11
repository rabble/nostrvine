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
  String get videoGridDeleteVideoSubtitle => 'إزالة هذا المحتوى نهائيًا';

  @override
  String get videoGridDeleteConfirmTitle => 'حذف الفيديو';

  @override
  String get videoGridDeleteConfirmMessage =>
      'هل أنت متأكد من رغبتك في حذف هذا الفيديو؟';

  @override
  String get videoGridDeleteConfirmNote =>
      'سيرسل هذا طلب حذف (NIP-09) إلى جميع المحولات. قد تحتفظ بعض المحولات بالمحتوى.';

  @override
  String get videoGridDeleteCancel => 'إلغاء';

  @override
  String get videoGridDeleteConfirm => 'حذف';

  @override
  String get videoGridDeletingContent => 'جاري حذف المحتوى...';

  @override
  String get videoGridDeleteSuccess => 'تم إرسال طلب الحذف بنجاح';

  @override
  String videoGridDeleteFailure(Object error) {
    return 'فشل حذف المحتوى: $error';
  }

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
  String get metadataLoopsLabel => 'التكرارات';

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
  String get relaySettingsTitle => 'Relays';

  @override
  String get relaySettingsInfoTitle =>
      'Divine is an open system - you control your connections';

  @override
  String get relaySettingsInfoDescription =>
      'These relays distribute your content across the decentralized Nostr network. You can add or remove relays as you wish.';

  @override
  String get relaySettingsLearnMoreNostr => 'Learn more about Nostr →';

  @override
  String get relaySettingsFindPublicRelays =>
      'Find public relays at nostr.co.uk →';

  @override
  String get relaySettingsAppNotFunctional => 'App Not Functional';

  @override
  String get relaySettingsRequiresRelay =>
      'Divine requires at least one relay to load videos, post content, and sync data.';

  @override
  String get relaySettingsRestoreDefaultRelay => 'Restore Default Relay';

  @override
  String get relaySettingsAddCustomRelay => 'Add Custom Relay';

  @override
  String get relaySettingsAddRelay => 'Add Relay';

  @override
  String get relaySettingsRetry => 'Retry';

  @override
  String get relaySettingsNoStats => 'No statistics available yet';

  @override
  String get relaySettingsConnection => 'Connection';

  @override
  String get relaySettingsConnected => 'Connected';

  @override
  String get relaySettingsDisconnected => 'Disconnected';

  @override
  String get relaySettingsSessionDuration => 'Session Duration';

  @override
  String get relaySettingsLastConnected => 'Last Connected';

  @override
  String get relaySettingsDisconnectedLabel => 'Disconnected';

  @override
  String get relaySettingsReason => 'Reason';

  @override
  String get relaySettingsActiveSubscriptions => 'Active Subscriptions';

  @override
  String get relaySettingsTotalSubscriptions => 'Total Subscriptions';

  @override
  String get relaySettingsEventsReceived => 'Events Received';

  @override
  String get relaySettingsEventsSent => 'Events Sent';

  @override
  String get relaySettingsRequestsThisSession => 'Requests This Session';

  @override
  String get relaySettingsFailedRequests => 'Failed Requests';

  @override
  String relaySettingsLastError(String error) {
    return 'Last Error: $error';
  }

  @override
  String get relaySettingsLoadingRelayInfo => 'Loading relay info...';

  @override
  String get relaySettingsAboutRelay => 'About Relay';

  @override
  String get relaySettingsSupportedNips => 'Supported NIPs';

  @override
  String get relaySettingsSoftware => 'Software';

  @override
  String get relaySettingsViewWebsite => 'View Website';

  @override
  String get relaySettingsRemoveRelayTitle => 'Remove Relay?';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return 'Are you sure you want to remove this relay?\n\n$relayUrl';
  }

  @override
  String get relaySettingsCancel => 'Cancel';

  @override
  String get relaySettingsRemove => 'Remove';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return 'Removed relay: $relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay => 'Failed to remove relay';

  @override
  String get relaySettingsForcingReconnection =>
      'Forcing relay reconnection...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    return 'Connected to $count relay(s)!';
  }

  @override
  String get relaySettingsFailedToConnectCheck =>
      'Failed to connect to relays. Please check your network connection.';

  @override
  String get relaySettingsAddRelayTitle => 'Add Relay';

  @override
  String get relaySettingsAddRelayPrompt =>
      'Enter the WebSocket URL of the relay you want to add:';

  @override
  String get relaySettingsBrowsePublicRelays =>
      'Browse public relays at nostr.co.uk';

  @override
  String get relaySettingsAdd => 'Add';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return 'Added relay: $relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay =>
      'Failed to add relay. Please check the URL and try again.';

  @override
  String get relaySettingsInvalidUrl =>
      'Relay URL must start with wss:// or ws://';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return 'Restored default relay: $defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault =>
      'Failed to restore default relay. Please check your network connection.';

  @override
  String get relaySettingsCouldNotOpenBrowser => 'Could not open browser';

  @override
  String get relaySettingsFailedToOpenLink => 'Failed to open link';

  @override
  String get relayDiagnosticTitle => 'Relay Diagnostics';

  @override
  String get relayDiagnosticRefreshTooltip => 'Refresh diagnostics';

  @override
  String relayDiagnosticLastRefresh(String time) {
    return 'Last refresh: $time';
  }

  @override
  String get relayDiagnosticRelayStatus => 'Relay Status';

  @override
  String get relayDiagnosticInitialized => 'Initialized';

  @override
  String get relayDiagnosticReady => 'Ready';

  @override
  String get relayDiagnosticNotInitialized => 'Not initialized';

  @override
  String get relayDiagnosticDatabaseEvents => 'Database Events';

  @override
  String get relayDiagnosticActiveSubscriptions => 'Active Subscriptions';

  @override
  String get relayDiagnosticExternalRelays => 'External Relays';

  @override
  String get relayDiagnosticConfigured => 'Configured';

  @override
  String relayDiagnosticRelayCount(int count) {
    return '$count relay(s)';
  }

  @override
  String get relayDiagnosticConnectedLabel => 'Connected';

  @override
  String relayDiagnosticConnectedRatio(int connected, int total) {
    return '$connected/$total';
  }

  @override
  String get relayDiagnosticVideoEvents => 'Video Events';

  @override
  String get relayDiagnosticHomeFeed => 'Home Feed';

  @override
  String relayDiagnosticVideosCount(int count) {
    return '$count videos';
  }

  @override
  String get relayDiagnosticDiscovery => 'Discovery';

  @override
  String get relayDiagnosticLoading => 'Loading';

  @override
  String get relayDiagnosticYes => 'Yes';

  @override
  String get relayDiagnosticNo => 'No';

  @override
  String get relayDiagnosticTestDirectQuery => 'Test Direct Query';

  @override
  String get relayDiagnosticNetworkConnectivity => 'Network Connectivity';

  @override
  String get relayDiagnosticRunNetworkTest => 'Run Network Test';

  @override
  String get relayDiagnosticBlossomServer => 'Blossom Server';

  @override
  String get relayDiagnosticTestAllEndpoints => 'Test All Endpoints';

  @override
  String get relayDiagnosticStatus => 'Status';

  @override
  String get relayDiagnosticUrl => 'URL';

  @override
  String get relayDiagnosticError => 'Error';

  @override
  String get relayDiagnosticFunnelCakeApi => 'FunnelCake API';

  @override
  String get relayDiagnosticBaseUrl => 'Base URL';

  @override
  String get relayDiagnosticSummary => 'Summary';

  @override
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  ) {
    return '$successCount/$totalCount OK (avg ${avgMs}ms)';
  }

  @override
  String get relayDiagnosticRetestAll => 'Retest All';

  @override
  String get relayDiagnosticRetrying => 'Retrying...';

  @override
  String get relayDiagnosticRetryConnection => 'Retry Connection';

  @override
  String get relayDiagnosticTroubleshooting => 'Troubleshooting';

  @override
  String get relayDiagnosticTroubleshootingGuide =>
      '• Green status = Connected and working\n• Red status = Connection failed\n• If network test fails, check internet connection\n• If relays are configured but not connected, tap \"Retry Connection\"\n• Screenshot this screen for debugging';

  @override
  String get relayDiagnosticAllEndpointsHealthy =>
      'All REST endpoints healthy!';

  @override
  String get relayDiagnosticSomeEndpointsFailed =>
      'Some REST endpoints failed - see details above';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    return 'Found $count video events in database';
  }

  @override
  String relayDiagnosticQueryFailed(String error) {
    return 'Query failed: $error';
  }

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    return 'Connected to $count relay(s)!';
  }

  @override
  String get relayDiagnosticFailedToConnect =>
      'Failed to connect to any relays';

  @override
  String relayDiagnosticConnectionRetryFailed(String error) {
    return 'Connection retry failed: $error';
  }

  @override
  String get relayDiagnosticConnectedAuthenticated =>
      'Connected & Authenticated';

  @override
  String get relayDiagnosticConnectedOnly => 'Connected';

  @override
  String get relayDiagnosticNotConnected => 'Not connected';

  @override
  String get relayDiagnosticNoRelaysConfigured => 'No relays configured';

  @override
  String get relayDiagnosticFailed => 'Failed';

  @override
  String get notificationSettingsTitle => 'Notifications';

  @override
  String get notificationSettingsResetTooltip => 'Reset to defaults';

  @override
  String get notificationSettingsTypes => 'Notification Types';

  @override
  String get notificationSettingsLikes => 'Likes';

  @override
  String get notificationSettingsLikesSubtitle =>
      'When someone likes your videos';

  @override
  String get notificationSettingsComments => 'Comments';

  @override
  String get notificationSettingsCommentsSubtitle =>
      'When someone comments on your videos';

  @override
  String get notificationSettingsFollows => 'Follows';

  @override
  String get notificationSettingsFollowsSubtitle => 'When someone follows you';

  @override
  String get notificationSettingsMentions => 'Mentions';

  @override
  String get notificationSettingsMentionsSubtitle => 'When you are mentioned';

  @override
  String get notificationSettingsReposts => 'Reposts';

  @override
  String get notificationSettingsRepostsSubtitle =>
      'When someone reposts your videos';

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
  String get notificationSettingsActions => 'Actions';

  @override
  String get notificationSettingsMarkAllAsRead => 'Mark All as Read';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle =>
      'Mark all notifications as read';

  @override
  String get notificationSettingsAllMarkedAsRead =>
      'All notifications marked as read';

  @override
  String get notificationSettingsResetToDefaults =>
      'Settings reset to defaults';

  @override
  String get notificationSettingsAbout => 'About Notifications';

  @override
  String get notificationSettingsAboutDescription =>
      'Notifications are powered by the Nostr protocol. Real-time updates depend on your connection to Nostr relays. Some notifications may have delays.';

  @override
  String get safetySettingsTitle => 'Safety & Privacy';

  @override
  String get safetySettingsLabel => 'SETTINGS';

  @override
  String get safetySettingsShowDivineHostedOnly =>
      'Only show Divine-hosted videos';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle =>
      'Hide videos served from other media hosts';

  @override
  String get safetySettingsModeration => 'MODERATION';

  @override
  String get safetySettingsBlockedUsers => 'BLOCKED USERS';

  @override
  String get safetySettingsAgeVerification => 'AGE VERIFICATION';

  @override
  String get safetySettingsAgeConfirmation =>
      'I confirm I am 18 years or older';

  @override
  String get safetySettingsAgeRequired => 'Required to view adult content';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle =>
      'Official moderation service (on by default)';

  @override
  String get safetySettingsPeopleIFollow => 'People I follow';

  @override
  String get safetySettingsPeopleIFollowSubtitle =>
      'Subscribe to labels from people you follow';

  @override
  String get safetySettingsAddCustomLabeler => 'Add Custom Labeler';

  @override
  String get safetySettingsAddCustomLabelerHint => 'Enter npub...';

  @override
  String get safetySettingsAddCustomLabelerListTitle => 'Add custom labeler';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle => 'Enter npub address';

  @override
  String get safetySettingsNoBlockedUsers => 'No blocked users';

  @override
  String get safetySettingsUnblock => 'Unblock';

  @override
  String get safetySettingsUserUnblocked => 'User unblocked';

  @override
  String get safetySettingsCancel => 'Cancel';

  @override
  String get safetySettingsAdd => 'Add';

  @override
  String get analyticsTitle => 'Creator Analytics';

  @override
  String get analyticsDiagnosticsTooltip => 'Diagnostics';

  @override
  String get analyticsDiagnosticsSemanticLabel => 'Toggle diagnostics';

  @override
  String get analyticsRetry => 'Retry';

  @override
  String get analyticsUnableToLoad => 'Unable to load analytics.';

  @override
  String get analyticsSignInRequired => 'Sign in to view creator analytics.';

  @override
  String get analyticsViewDataUnavailable =>
      'Views are currently unavailable from the relay for these posts. Like/comment/repost metrics are still accurate.';

  @override
  String get analyticsViewDataTitle => 'View Data';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return 'Updated $time • Scores use likes, comments, reposts, and views/loops from Funnelcake when available.';
  }

  @override
  String get analyticsVideos => 'Videos';

  @override
  String get analyticsViews => 'Views';

  @override
  String get analyticsInteractions => 'Interactions';

  @override
  String get analyticsEngagement => 'Engagement';

  @override
  String get analyticsFollowers => 'Followers';

  @override
  String get analyticsAvgPerPost => 'Avg/Post';

  @override
  String get analyticsInteractionMix => 'Interaction Mix';

  @override
  String get analyticsLikes => 'Likes';

  @override
  String get analyticsComments => 'Comments';

  @override
  String get analyticsReposts => 'Reposts';

  @override
  String get analyticsPerformanceHighlights => 'Performance Highlights';

  @override
  String get analyticsMostViewed => 'Most viewed';

  @override
  String get analyticsMostDiscussed => 'Most discussed';

  @override
  String get analyticsMostReposted => 'Most reposted';

  @override
  String get analyticsNoVideosYet => 'No videos yet';

  @override
  String get analyticsViewDataUnavailableShort => 'View data unavailable';

  @override
  String analyticsViewsCount(String count) {
    return '$count views';
  }

  @override
  String analyticsCommentsCount(String count) {
    return '$count comments';
  }

  @override
  String analyticsRepostsCount(String count) {
    return '$count reposts';
  }

  @override
  String get analyticsTopContent => 'Top Content';

  @override
  String get analyticsPublishPrompt => 'Publish a few videos to see rankings.';

  @override
  String get analyticsEngagementRateExplainer =>
      'Right-side % = Engagement Rate (interactions divided by views).';

  @override
  String get analyticsEngagementRateNoViews =>
      'Engagement Rate needs view data; values show as N/A until views are available.';

  @override
  String get analyticsEngagementLabel => 'Engagement';

  @override
  String get analyticsViewsUnavailable => 'views unavailable';

  @override
  String analyticsInteractionsCount(String count) {
    return '$count interactions';
  }

  @override
  String get analyticsPostAnalytics => 'Post Analytics';

  @override
  String get analyticsOpenPost => 'Open Post';

  @override
  String get analyticsRecentDailyInteractions => 'Recent Daily Interactions';

  @override
  String get analyticsNoActivityYet => 'No activity in this range yet.';

  @override
  String get analyticsDailyInteractionsExplainer =>
      'Interactions = likes + comments + reposts by post date.';

  @override
  String get analyticsDailyBarExplainer =>
      'Bar length is relative to your highest day in this window.';

  @override
  String get analyticsAudienceSnapshot => 'Audience Snapshot';

  @override
  String analyticsFollowersCount(String count) {
    return 'Followers: $count';
  }

  @override
  String analyticsFollowingCount(String count) {
    return 'Following: $count';
  }

  @override
  String get analyticsAudiencePlaceholder =>
      'Audience source/geo/time breakdowns will populate as Funnelcake adds audience analytics endpoints.';

  @override
  String get analyticsRetention => 'Retention';

  @override
  String get analyticsRetentionWithViews =>
      'Retention curve and watch-time breakdown will appear once per-second/per-bucket retention arrives from Funnelcake.';

  @override
  String get analyticsRetentionWithoutViews =>
      'Retention data unavailable until view+watch-time analytics are returned by Funnelcake.';

  @override
  String get analyticsDiagnostics => 'Diagnostics';

  @override
  String analyticsDiagnosticsTotalVideos(int count) {
    return 'Total videos: $count';
  }

  @override
  String analyticsDiagnosticsWithViews(int count) {
    return 'With views: $count';
  }

  @override
  String analyticsDiagnosticsMissingViews(int count) {
    return 'Missing views: $count';
  }

  @override
  String analyticsDiagnosticsHydratedBulk(int count) {
    return 'Hydrated (bulk): $count';
  }

  @override
  String analyticsDiagnosticsHydratedViews(int count) {
    return 'Hydrated (/views): $count';
  }

  @override
  String analyticsDiagnosticsSources(String sources) {
    return 'Sources: $sources';
  }

  @override
  String get analyticsDiagnosticsUseFixture => 'Use fixture data';

  @override
  String get analyticsNa => 'N/A';

  @override
  String get authCreateNewAccount => 'Create a new Divine account';

  @override
  String get authSignInDifferentAccount => 'Sign in with a different account';

  @override
  String get authSignBackIn => 'Sign back in';

  @override
  String get authTermsPrefix =>
      'By selecting an option above, you confirm you are at least 16 years old and agree to the ';

  @override
  String get authTermsOfService => 'Terms of Service';

  @override
  String get authPrivacyPolicy => 'Privacy Policy';

  @override
  String get authTermsAnd => ', and ';

  @override
  String get authSafetyStandards => 'Safety Standards';

  @override
  String get authAmberNotInstalled => 'Amber app is not installed';

  @override
  String get authAmberConnectionFailed => 'Failed to connect with Amber';

  @override
  String get authPasswordResetSent =>
      'If an account exists with that email, a password reset link has been sent.';

  @override
  String get authSignInTitle => 'Sign in';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authImportNostrKey => 'Import Nostr key';

  @override
  String get authConnectSignerApp => 'Connect with a signer app';

  @override
  String get authSignInWithAmber => 'Sign in with Amber';

  @override
  String get authSignInOptionsTitle => 'Sign-in options';

  @override
  String get authInfoEmailPasswordTitle => 'Email & Password';

  @override
  String get authInfoEmailPasswordDescription =>
      'Sign in with your Divine account. If you registered with an email and password, use them here.';

  @override
  String get authInfoImportNostrKeyDescription =>
      'Already have a Nostr identity? Import your nsec private key from another client.';

  @override
  String get authInfoSignerAppTitle => 'Signer App';

  @override
  String get authInfoSignerAppDescription =>
      'Connect using a NIP-46 compatible remote signer like nsecBunker for enhanced key security.';

  @override
  String get authInfoAmberTitle => 'Amber';

  @override
  String get authInfoAmberDescription =>
      'Use the Amber signer app on Android to manage your Nostr keys securely.';

  @override
  String get authCreateAccountTitle => 'Create account';

  @override
  String get authBackToInviteCode => 'Back to invite code';

  @override
  String get authUseDivineNoBackup => 'Use Divine with no backup';

  @override
  String get authSkipConfirmTitle => 'One last thing...';

  @override
  String get authSkipConfirmKeyCreated =>
      'You\'re in! We\'ll create a secure key that powers your Divine account.';

  @override
  String get authSkipConfirmKeyOnly =>
      'Without an email, your key is the only way Divine knows this account is yours.';

  @override
  String get authSkipConfirmRecommendEmail =>
      'You can access your key in the app, but, if you\'re not technical we recommend adding an email and password now. It makes it easier to sign in and restore your account if you lose or reset this device.';

  @override
  String get authAddEmailPassword => 'Add email & password';

  @override
  String get authUseThisDeviceOnly => 'Use this device only';

  @override
  String get authCompleteRegistration => 'Complete your registration';

  @override
  String get authVerifying => 'Verifying...';

  @override
  String get authVerificationLinkSent => 'We sent a verification link to:';

  @override
  String get authClickVerificationLink =>
      'Please click the link in your email to\ncomplete your registration.';

  @override
  String get authPleaseWaitVerifying =>
      'Please wait while we verify your email...';

  @override
  String get authWaitingForVerification => 'Waiting for verification';

  @override
  String get authOpenEmailApp => 'Open email app';

  @override
  String get authWelcomeToDivine => 'Welcome to Divine!';

  @override
  String get authEmailVerified => 'Your email has been verified.';

  @override
  String get authSigningYouIn => 'Signing you in';

  @override
  String get authErrorTitle => 'Uh oh.';

  @override
  String get authVerificationFailed =>
      'We failed to verify your email.\nPlease try again.';

  @override
  String get authStartOver => 'Start over';

  @override
  String get authEmailVerifiedLogin =>
      'Email verified! Please log in to continue.';

  @override
  String get authVerificationLinkExpired =>
      'This verification link is no longer valid.';

  @override
  String get authVerificationConnectionError =>
      'Unable to verify email. Please check your connection and try again.';

  @override
  String get authWaitlistConfirmTitle => 'You\'re in!';

  @override
  String authWaitlistUpdatesAt(String email) {
    return 'We\'ll share updates at $email.\nWhen more invite codes are available, we\'ll send them your way.';
  }

  @override
  String get authOk => 'OK';

  @override
  String get authInviteUnavailable =>
      'Invite access is temporarily unavailable.';

  @override
  String get authInviteUnavailableBody =>
      'Try again in a moment, or contact support if you need help getting in.';

  @override
  String get authTryAgain => 'Try again';

  @override
  String get authContactSupport => 'Contact support';

  @override
  String authCouldNotOpenEmail(String email) {
    return 'Could not open $email';
  }

  @override
  String get authAddInviteCode => 'Add your invite code';

  @override
  String get authInviteCodeLabel => 'Invite code';

  @override
  String get authEnterYourCode => 'Enter your code';

  @override
  String get authNext => 'Next';

  @override
  String get authJoinWaitlist => 'Join waitlist';

  @override
  String get authJoinWaitlistTitle => 'Join the waitlist';

  @override
  String get authJoinWaitlistDescription =>
      'Share your email and we\'ll send updates as access opens up.';

  @override
  String get authInviteAccessHelp => 'Invite access help';

  @override
  String get authGeneratingConnection => 'Generating connection...';

  @override
  String get authConnectedAuthenticating => 'Connected! Authenticating...';

  @override
  String get authConnectionTimedOut => 'Connection timed out';

  @override
  String get authApproveConnection =>
      'Make sure you approved the connection in your signer app.';

  @override
  String get authConnectionCancelled => 'Connection cancelled';

  @override
  String get authConnectionCancelledMessage => 'The connection was cancelled.';

  @override
  String get authConnectionFailed => 'Connection failed';

  @override
  String get authUnknownError => 'An unknown error occurred.';

  @override
  String get authUrlCopied => 'URL copied to clipboard';

  @override
  String get authConnectToDivine => 'Connect to Divine';

  @override
  String get authPasteBunkerUrl => 'Paste bunker:// URL';

  @override
  String get authBunkerUrlHint => 'bunker:// URL';

  @override
  String get authInvalidBunkerUrl =>
      'Invalid bunker URL. It should start with bunker://';

  @override
  String get authScanSignerApp => 'Scan with your\nsigner app to connect.';

  @override
  String authWaitingForConnection(int seconds) {
    return 'Waiting for connection... ${seconds}s';
  }

  @override
  String get authCopyUrl => 'Copy URL';

  @override
  String get authShare => 'Share';

  @override
  String get authAddBunker => 'Add bunker';

  @override
  String get authCompatibleSignerApps => 'Compatible Signer apps';

  @override
  String get authFailedToConnect => 'Failed to connect';

  @override
  String get authResetPasswordTitle => 'Reset Password';

  @override
  String get authResetPasswordSubtitle =>
      'Please enter your new password. It must be at least 8 characters in length.';

  @override
  String get authNewPasswordLabel => 'New Password';

  @override
  String get authPasswordTooShort => 'Password must be at least 8 characters';

  @override
  String get authPasswordResetSuccess =>
      'Password reset successful. Please log in.';

  @override
  String get authPasswordResetFailed => 'Password reset failed';

  @override
  String get authUnexpectedError =>
      'An unexpected error occurred. Please try again.';

  @override
  String get authUpdatePassword => 'Update password';

  @override
  String get authSecureAccountTitle => 'Secure account';

  @override
  String get authUnableToAccessKeys =>
      'Unable to access your keys. Please try again.';

  @override
  String get authRegistrationFailed => 'Registration failed';

  @override
  String get authRegistrationComplete =>
      'Registration complete. Please check your email.';

  @override
  String get authVerificationFailedTitle => 'Verification Failed';

  @override
  String get authClose => 'Close';

  @override
  String get authAccountSecured => 'Account Secured!';

  @override
  String get authAccountLinkedToEmail =>
      'Your account is now linked to your email.';

  @override
  String get authVerifyYourEmail => 'Verify Your Email';

  @override
  String get authClickLinkContinue =>
      'Click the link in your email to complete registration. You can continue using the app in the meantime.';

  @override
  String get authWaitingForVerificationEllipsis =>
      'Waiting for verification...';

  @override
  String get authContinueToApp => 'Continue to App';

  @override
  String get authResetPassword => 'Reset password';

  @override
  String get authResetPasswordDescription =>
      'Enter your email address and we\'ll send you a link to reset your password.';

  @override
  String get authFailedToSendResetEmail => 'Failed to send reset email.';

  @override
  String get authUnexpectedErrorShort => 'An unexpected error occurred.';

  @override
  String get authSending => 'Sending...';

  @override
  String get authSendResetLink => 'Send reset link';

  @override
  String get authEmailSent => 'Email sent!';

  @override
  String authResetLinkSentTo(String email) {
    return 'We sent a password reset link to $email. Please click the link in your email to update your password.';
  }

  @override
  String get authSignInButton => 'Sign in';

  @override
  String get authVerificationErrorTimeout =>
      'Verification timed out. Please try registering again.';

  @override
  String get authVerificationErrorMissingCode =>
      'Verification failed — missing authorization code.';

  @override
  String get authVerificationErrorPollFailed =>
      'Verification failed. Please try again.';

  @override
  String get authVerificationErrorNetworkExchange =>
      'Network error during sign-in. Please try again.';

  @override
  String get authVerificationErrorOAuthExchange =>
      'Verification failed. Please try registering again.';

  @override
  String get authVerificationErrorSignInFailed =>
      'Sign-in failed. Please try logging in manually.';

  @override
  String get authInviteErrorAlreadyUsed =>
      'That invite code is no longer available. Go back to your invite code, join the waitlist, or contact support.';

  @override
  String get authInviteErrorInvalid =>
      'That invite code cannot be used right now. Go back to your invite code, join the waitlist, or contact support.';

  @override
  String get authInviteErrorTemporary =>
      'We couldn\'t confirm your invite right now. Go back to your invite code and try again, or contact support.';

  @override
  String get authInviteErrorUnknown =>
      'We couldn\'t activate your invite. Go back to your invite code, join the waitlist, or contact support.';

  @override
  String get shareSheetSave => 'Save';

  @override
  String get shareSheetSaveToGallery => 'Save to Gallery';

  @override
  String get shareSheetSaveWithWatermark => 'Save with Watermark';

  @override
  String get shareSheetSaveVideo => 'Save Video';

  @override
  String get shareSheetAddToList => 'Add to List';

  @override
  String get shareSheetCopy => 'Copy';

  @override
  String get shareSheetShareVia => 'Share via';

  @override
  String get shareSheetReport => 'Report';

  @override
  String get shareSheetEventJson => 'Event JSON';

  @override
  String get shareSheetEventId => 'Event ID';

  @override
  String get shareSheetMoreActions => 'More actions';

  @override
  String get watermarkDownloadSavedToCameraRoll => 'Saved to Camera Roll';

  @override
  String get watermarkDownloadShare => 'Share';

  @override
  String get watermarkDownloadDone => 'Done';

  @override
  String get watermarkDownloadPhotosAccessNeeded => 'Photos Access Needed';

  @override
  String get watermarkDownloadPhotosAccessDescription =>
      'To save videos, allow Photos access in Settings.';

  @override
  String get watermarkDownloadOpenSettings => 'Open Settings';

  @override
  String get watermarkDownloadNotNow => 'Not Now';

  @override
  String get watermarkDownloadFailed => 'Download Failed';

  @override
  String get watermarkDownloadDismiss => 'Dismiss';

  @override
  String get watermarkDownloadStageDownloading => 'Downloading Video';

  @override
  String get watermarkDownloadStageWatermarking => 'Adding Watermark';

  @override
  String get watermarkDownloadStageSaving => 'Saving to Camera Roll';

  @override
  String get watermarkDownloadStageDownloadingDesc =>
      'Fetching the video from the network...';

  @override
  String get watermarkDownloadStageWatermarkingDesc =>
      'Applying the Divine watermark...';

  @override
  String get watermarkDownloadStageSavingDesc =>
      'Saving the watermarked video to your camera roll...';

  @override
  String get uploadProgressVideoUpload => 'Video Upload';

  @override
  String get uploadProgressPause => 'Pause';

  @override
  String get uploadProgressResume => 'Resume';

  @override
  String get uploadProgressGoBack => 'Go Back';

  @override
  String uploadProgressRetryWithCount(int count) {
    return 'Retry ($count left)';
  }

  @override
  String get uploadProgressDelete => 'Delete';

  @override
  String uploadProgressDaysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String uploadProgressHoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String uploadProgressMinutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String get uploadProgressJustNow => 'Just now';

  @override
  String uploadProgressUploadingPercent(int percent) {
    return 'Uploading $percent%';
  }

  @override
  String uploadProgressPausedPercent(int percent) {
    return 'Paused $percent%';
  }

  @override
  String get badgeExplanationClose => 'Close';

  @override
  String get badgeExplanationOriginalVineArchive => 'Original Vine Archive';

  @override
  String get badgeExplanationCameraProof => 'Camera Proof';

  @override
  String get badgeExplanationAuthenticitySignals => 'Authenticity Signals';

  @override
  String get badgeExplanationVineArchiveIntro =>
      'This video is an original Vine recovered from the Internet Archive.';

  @override
  String get badgeExplanationVineArchiveHistory =>
      'Before Vine shut down in 2017, ArchiveTeam and the Internet Archive worked to preserve millions of Vines for posterity. This content is part of that historic preservation effort.';

  @override
  String badgeExplanationOriginalStats(int loops) {
    return 'Original stats: $loops loops';
  }

  @override
  String get badgeExplanationLearnVineArchive =>
      'Learn more about the Vine archive preservation';

  @override
  String get badgeExplanationLearnProofmode =>
      'Learn more about Proofmode verification';

  @override
  String get badgeExplanationLearnAuthenticity =>
      'Learn more about Divine authenticity signals';

  @override
  String get badgeExplanationInspectProofCheck =>
      'Inspect with ProofCheck Tool';

  @override
  String get badgeExplanationInspectMedia => 'Inspect media details';

  @override
  String get badgeExplanationProofmodeVerified =>
      'This video\'s authenticity is verified using Proofmode technology.';

  @override
  String get badgeExplanationDivineHostedHumanMade =>
      'This video is hosted on Divine and AI detection indicates it is likely human-made, but it does not include cryptographic camera-verification data.';

  @override
  String get badgeExplanationHumanMadeNoCrypto =>
      'AI detection indicates this video is likely human-made, though it does not include cryptographic camera-verification data.';

  @override
  String get badgeExplanationDivineHostedNoCrypto =>
      'This video is hosted on Divine, but it does not include cryptographic camera-verification data yet.';

  @override
  String get badgeExplanationExternalNoCrypto =>
      'This video is hosted outside Divine and does not include cryptographic camera-verification data.';

  @override
  String get badgeExplanationDeviceAttestation => 'Device attestation';

  @override
  String get badgeExplanationPgpSignature => 'PGP signature';

  @override
  String get badgeExplanationC2paCredentials => 'C2PA Content Credentials';

  @override
  String get badgeExplanationProofManifest => 'Proof manifest';

  @override
  String get badgeExplanationAiDetection => 'AI Detection';

  @override
  String get badgeExplanationAiNotScanned => 'AI scan: Not yet scanned';

  @override
  String get badgeExplanationNoScanResults => 'No scan results available yet.';

  @override
  String get badgeExplanationCheckAiGenerated => 'Check if AI-generated';

  @override
  String badgeExplanationAiLikelihood(int percentage) {
    return '$percentage% likelihood of being AI-generated';
  }

  @override
  String badgeExplanationScannedBy(String source) {
    return 'Scanned by: $source';
  }

  @override
  String get badgeExplanationVerifiedByModerator =>
      'Verified by human moderator';

  @override
  String get badgeExplanationVerificationPlatinum =>
      'Platinum: Device hardware attestation, cryptographic signatures, Content Credentials (C2PA), and AI scan confirms human origin.';

  @override
  String get badgeExplanationVerificationGold =>
      'Gold: Captured on a real device with hardware attestation, cryptographic signatures, and Content Credentials (C2PA).';

  @override
  String get badgeExplanationVerificationSilver =>
      'Silver: Cryptographic signatures prove this video hasn\'t been altered since recording.';

  @override
  String get badgeExplanationVerificationBronze =>
      'Bronze: Basic metadata signatures are present.';

  @override
  String get badgeExplanationVerificationSilverAiScan =>
      'Silver: AI scan confirms this video is likely human-created.';

  @override
  String get badgeExplanationNoVerification =>
      'No verification data available for this video.';

  @override
  String get shareMenuTitle => 'Share Video';

  @override
  String get shareMenuReportAiContent => 'Report AI Content';

  @override
  String get shareMenuReportAiContentSubtitle =>
      'Quick report suspected AI-generated content';

  @override
  String get shareMenuReportingAiContent => 'Reporting AI content...';

  @override
  String shareMenuFailedToReportContent(String error) {
    return 'Failed to report content: $error';
  }

  @override
  String shareMenuFailedToReportAiContent(String error) {
    return 'Failed to report AI content: $error';
  }

  @override
  String get shareMenuVideoStatus => 'Video Status';

  @override
  String get shareMenuViewAllLists => 'View all lists →';

  @override
  String get shareMenuShareWith => 'Share With';

  @override
  String get shareMenuShareViaOtherApps => 'Share via other apps';

  @override
  String get shareMenuShareViaOtherAppsSubtitle =>
      'Share via other apps or copy link';

  @override
  String get shareMenuSaveToGallery => 'Save to Gallery';

  @override
  String get shareMenuSaveOriginalSubtitle =>
      'Save original video to camera roll';

  @override
  String get shareMenuSaveWithWatermark => 'Save with Watermark';

  @override
  String get shareMenuSaveVideo => 'Save Video';

  @override
  String get shareMenuDownloadWithWatermark => 'Download with Divine watermark';

  @override
  String get shareMenuSaveVideoSubtitle => 'Save video to camera roll';

  @override
  String get shareMenuLists => 'Lists';

  @override
  String get shareMenuAddToList => 'Add to List';

  @override
  String get shareMenuAddToListSubtitle => 'Add to your curated lists';

  @override
  String get shareMenuCreateNewList => 'Create New List';

  @override
  String get shareMenuCreateNewListSubtitle => 'Start a new curated collection';

  @override
  String get shareMenuRemovedFromList => 'Removed from list';

  @override
  String get shareMenuFailedToRemoveFromList => 'Failed to remove from list';

  @override
  String get shareMenuBookmarks => 'Bookmarks';

  @override
  String get shareMenuAddToBookmarks => 'Add to Bookmarks';

  @override
  String get shareMenuAddToBookmarksSubtitle => 'Save for later viewing';

  @override
  String get shareMenuAddToBookmarkSet => 'Add to Bookmark Set';

  @override
  String get shareMenuAddToBookmarkSetSubtitle => 'Organize in collections';

  @override
  String get shareMenuFollowSets => 'Follow Sets';

  @override
  String get shareMenuCreateFollowSet => 'Create Follow Set';

  @override
  String get shareMenuCreateFollowSetSubtitle =>
      'Start new collection with this creator';

  @override
  String get shareMenuAddToFollowSet => 'Add to Follow Set';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    return '$count follow sets available';
  }

  @override
  String get shareMenuAddedToBookmarks => 'Added to bookmarks!';

  @override
  String get shareMenuFailedToAddBookmark => 'Failed to add bookmark';

  @override
  String shareMenuCreatedListAndAddedVideo(String name) {
    return 'Created list \"$name\" and added video';
  }

  @override
  String get shareMenuManageContent => 'Manage Content';

  @override
  String get shareMenuEditVideo => 'Edit Video';

  @override
  String get shareMenuEditVideoSubtitle =>
      'Update title, description, and hashtags';

  @override
  String get shareMenuDeleteVideo => 'Delete Video';

  @override
  String get shareMenuDeleteVideoSubtitle => 'Permanently remove this content';

  @override
  String get shareMenuVideoInTheseLists => 'Video is in these lists:';

  @override
  String shareMenuVideoCount(int count) {
    return '$count videos';
  }

  @override
  String get shareMenuClose => 'Close';

  @override
  String get shareMenuDeleteConfirmation =>
      'Are you sure you want to delete this video?';

  @override
  String get shareMenuDeleteWarning =>
      'This will send a delete request (NIP-09) to all relays. Some relays may still retain the content.';

  @override
  String get shareMenuCancel => 'Cancel';

  @override
  String get shareMenuDelete => 'Delete';

  @override
  String get shareMenuDeletingContent => 'Deleting content...';

  @override
  String get shareMenuDeleteRequestSent => 'Delete request sent successfully';

  @override
  String shareMenuFailedToDeleteContent(String error) {
    return 'Failed to delete content: $error';
  }

  @override
  String get shareMenuFollowSetName => 'Follow Set Name';

  @override
  String get shareMenuFollowSetNameHint =>
      'e.g., Content Creators, Musicians, etc.';

  @override
  String get shareMenuDescriptionOptional => 'Description (optional)';

  @override
  String get shareMenuCreate => 'Create';

  @override
  String shareMenuCreatedFollowSetAndAddedCreator(String name) {
    return 'Created follow set \"$name\" and added creator';
  }

  @override
  String get shareMenuDone => 'Done';

  @override
  String get shareMenuEditTitle => 'Title';

  @override
  String get shareMenuEditTitleHint => 'Enter video title';

  @override
  String get shareMenuEditDescription => 'Description';

  @override
  String get shareMenuEditDescriptionHint => 'Enter video description';

  @override
  String get shareMenuEditHashtags => 'Hashtags';

  @override
  String get shareMenuEditHashtagsHint => 'comma, separated, hashtags';

  @override
  String get shareMenuEditMetadataNote =>
      'Note: Only metadata can be edited. Video content cannot be changed.';

  @override
  String get shareMenuDeleting => 'Deleting...';

  @override
  String get shareMenuUpdate => 'Update';

  @override
  String get shareMenuVideoUpdated => 'Video updated successfully';

  @override
  String shareMenuFailedToUpdateVideo(String error) {
    return 'Failed to update video: $error';
  }

  @override
  String get shareMenuDeleteVideoQuestion => 'Delete Video?';

  @override
  String get shareMenuDeleteRelayWarning =>
      'This will send a deletion request to relays. Note: Some relays may still have cached copies.';

  @override
  String get shareMenuVideoDeletionRequested => 'Video deletion requested';

  @override
  String shareMenuFailedToDeleteVideo(String error) {
    return 'Failed to delete video: $error';
  }

  @override
  String get shareMenuContentLabels => 'Content labels';

  @override
  String get shareMenuAddContentLabels => 'Add content labels';

  @override
  String get shareMenuClearAll => 'Clear all';

  @override
  String get shareMenuCollaborators => 'Collaborators';

  @override
  String get shareMenuAddCollaborator => 'Add collaborator';

  @override
  String shareMenuMutualFollowRequired(String name) {
    return 'You need to mutually follow $name to add them as a collaborator.';
  }

  @override
  String get shareMenuLoading => 'Loading...';

  @override
  String get shareMenuInspiredBy => 'Inspired by';

  @override
  String get shareMenuAddInspirationCredit => 'Add inspiration credit';

  @override
  String get shareMenuCreatorCannotBeReferenced =>
      'This creator cannot be referenced.';

  @override
  String get shareMenuUnknown => 'Unknown';

  @override
  String get shareMenuCreateBookmarkSet => 'Create Bookmark Set';

  @override
  String get shareMenuSetName => 'Set Name';

  @override
  String get shareMenuSetNameHint => 'e.g., Favorites, Watch Later, etc.';

  @override
  String get shareMenuCreateNewSet => 'Create New Set';

  @override
  String get shareMenuStartNewBookmarkCollection =>
      'Start a new bookmark collection';

  @override
  String get shareMenuNoBookmarkSets =>
      'No bookmark sets yet. Create your first one!';

  @override
  String get shareMenuError => 'Error';

  @override
  String get shareMenuFailedToLoadBookmarkSets =>
      'Failed to load bookmark sets';

  @override
  String shareMenuCreatedSetAndAddedVideo(String name) {
    return 'Created \"$name\" and added video';
  }

  @override
  String get shareMenuUseThisSound => 'Use this sound';

  @override
  String get shareMenuOriginalSound => 'Original sound';

  @override
  String get authSessionExpired =>
      'Your session has expired. Please sign in again.';

  @override
  String get authSignInFailed => 'Failed to sign in. Please try again.';

  @override
  String get localeAppLanguage => 'App Language';

  @override
  String get localeDeviceDefault => 'Device default';

  @override
  String get localeSelectLanguage => 'Select Language';

  @override
  String get webAuthNotSupportedSecureMode =>
      'Web authentication not supported in secure mode. Please use mobile app for secure key management.';

  @override
  String webAuthIntegrationFailed(String error) {
    return 'Authentication integration failed: $error';
  }

  @override
  String webAuthUnexpectedError(String error) {
    return 'Unexpected error: $error';
  }

  @override
  String get webAuthEnterBunkerUri => 'Please enter a bunker URI';

  @override
  String get webAuthConnectTitle => 'Connect to Divine';

  @override
  String get webAuthChooseMethod =>
      'Choose your preferred Nostr authentication method';

  @override
  String get webAuthBrowserExtension => 'Browser Extension';

  @override
  String get webAuthRecommended => 'RECOMMENDED';

  @override
  String get webAuthNsecBunker => 'nsec bunker';

  @override
  String get webAuthConnectRemoteSigner => 'Connect to a remote signer';

  @override
  String get webAuthBunkerHint => 'bunker://pubkey?relay=wss://...';

  @override
  String get webAuthPasteFromClipboard => 'Paste from clipboard';

  @override
  String get webAuthConnectToBunker => 'Connect to Bunker';

  @override
  String get webAuthNewToNostr => 'New to Nostr?';

  @override
  String get webAuthNostrHelp =>
      'Install a browser extension like Alby or nos2x for the easiest experience, or use nsec bunker for secure remote signing.';

  @override
  String get soundsTitle => 'Sounds';

  @override
  String get soundsSearchHint => 'Search sounds...';

  @override
  String get soundsPreviewUnavailable =>
      'Unable to preview sound - no audio available';

  @override
  String soundsPreviewFailed(String error) {
    return 'Failed to play preview: $error';
  }

  @override
  String get soundsFeaturedSounds => 'Featured Sounds';

  @override
  String get soundsTrendingSounds => 'Trending Sounds';

  @override
  String get soundsAllSounds => 'All Sounds';

  @override
  String get soundsSearchResults => 'Search Results';

  @override
  String get soundsNoSoundsAvailable => 'No sounds available';

  @override
  String get soundsNoSoundsDescription =>
      'Sounds will appear here when creators share audio';

  @override
  String get soundsNoSoundsFound => 'No sounds found';

  @override
  String get soundsNoSoundsFoundDescription => 'Try a different search term';

  @override
  String get soundsFailedToLoad => 'Failed to load sounds';

  @override
  String get soundsRetry => 'Retry';

  @override
  String get soundsScreenLabel => 'Sounds screen';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileRefresh => 'Refresh';

  @override
  String get profileRefreshLabel => 'Refresh profile';

  @override
  String get profileMoreOptions => 'More options';

  @override
  String profileBlockedUser(String name) {
    return 'Blocked $name';
  }

  @override
  String profileUnblockedUser(String name) {
    return 'Unblocked $name';
  }

  @override
  String profileUnfollowedUser(String name) {
    return 'Unfollowed $name';
  }

  @override
  String profileError(String error) {
    return 'Error: $error';
  }

  @override
  String get notificationsTabAll => 'All';

  @override
  String get notificationsTabLikes => 'Likes';

  @override
  String get notificationsTabComments => 'Comments';

  @override
  String get notificationsTabFollows => 'Follows';

  @override
  String get notificationsTabReposts => 'Reposts';

  @override
  String get notificationsFailedToLoad => 'Failed to load notifications';

  @override
  String get notificationsRetry => 'Retry';

  @override
  String get notificationsCheckingNew => 'checking for new notifications';

  @override
  String get notificationsNoneYet => 'No notifications yet';

  @override
  String notificationsNoneForType(String type) {
    return 'No $type notifications';
  }

  @override
  String get notificationsEmptyDescription =>
      'When people interact with your content, you\'ll see it here';

  @override
  String notificationsLoadingType(String type) {
    return 'Loading $type notifications...';
  }

  @override
  String get notificationsInviteSingular =>
      'You have 1 invite to share with a friend!';

  @override
  String notificationsInvitePlural(int count) {
    return 'You have $count invites to share with friends!';
  }

  @override
  String get notificationsVideoNotFound => 'Video not found';

  @override
  String get notificationsVideoUnavailable => 'Video unavailable';

  @override
  String get notificationsFromNotification => 'From Notification';

  @override
  String get feedFailedToLoadVideos => 'Failed to load videos';

  @override
  String get feedRetry => 'Retry';

  @override
  String get feedNoFollowedUsers =>
      'No followed users.\nFollow someone to see their videos here.';

  @override
  String feedNoVideosForMode(String mode) {
    return 'No videos found for $mode feed.';
  }

  @override
  String get feedExploreVideos => 'Explore Videos';

  @override
  String get feedExternalVideoSlow => 'External video loading slowly';

  @override
  String get feedSkip => 'Skip';

  @override
  String get uploadWaitingToUpload => 'Waiting to upload';

  @override
  String get uploadUploadingVideo => 'Uploading video';

  @override
  String get uploadProcessingVideo => 'Processing video';

  @override
  String get uploadProcessingComplete => 'Processing complete';

  @override
  String get uploadPublishedSuccessfully => 'Published successfully';

  @override
  String get uploadFailed => 'Upload failed';

  @override
  String get uploadRetrying => 'Retrying upload';

  @override
  String get uploadPaused => 'Upload paused';

  @override
  String uploadPercentComplete(int percent) {
    return '$percent% complete';
  }

  @override
  String get uploadQueuedMessage => 'Your video is queued for upload';

  @override
  String get uploadUploadingMessage => 'Uploading to server...';

  @override
  String get uploadProcessingMessage =>
      'Processing video - this may take a few minutes';

  @override
  String get uploadReadyToPublishMessage =>
      'Video processed successfully and ready to publish';

  @override
  String get uploadPublishedMessage => 'Video published to your profile';

  @override
  String get uploadFailedMessage => 'Upload failed - please try again';

  @override
  String get uploadRetryingMessage => 'Retrying upload...';

  @override
  String get uploadPausedMessage => 'Upload paused by user';

  @override
  String get uploadRetryButton => 'RETRY';

  @override
  String uploadRetryFailed(String error) {
    return 'Failed to retry upload: $error';
  }

  @override
  String get userSearchPrompt => 'Search for users';

  @override
  String get userSearchNoResults => 'No users found';

  @override
  String get userSearchFailed => 'Search failed';

  @override
  String get forgotPasswordTitle => 'Reset Password';

  @override
  String get forgotPasswordDescription =>
      'Enter your email address and we\'ll send you a link to reset your password.';

  @override
  String get forgotPasswordEmailLabel => 'Email Address';

  @override
  String get forgotPasswordCancel => 'Cancel';

  @override
  String get forgotPasswordSendLink => 'Email Reset Link';

  @override
  String get ageVerificationContentWarning => 'Content Warning';

  @override
  String get ageVerificationTitle => 'Age Verification';

  @override
  String get ageVerificationAdultDescription =>
      'This content has been flagged as potentially containing adult material. You must be 18 or older to view it.';

  @override
  String get ageVerificationCreationDescription =>
      'To use the camera and create content, you must be at least 16 years old.';

  @override
  String get ageVerificationAdultQuestion =>
      'Are you 18 years of age or older?';

  @override
  String get ageVerificationCreationQuestion =>
      'Are you 16 years of age or older?';

  @override
  String get ageVerificationNo => 'No';

  @override
  String get ageVerificationYes => 'Yes';

  @override
  String get shareLinkCopied => 'Link copied to clipboard';

  @override
  String get shareFailedToCopy => 'Failed to copy link';

  @override
  String get shareVideoSubject => 'Check out this video on Divine';

  @override
  String get shareFailedToShare => 'Failed to share';

  @override
  String get shareVideoTitle => 'Share Video';

  @override
  String get shareToApps => 'Share to Apps';

  @override
  String get shareToAppsSubtitle => 'Share via messaging, social apps';

  @override
  String get shareCopyWebLink => 'Copy Web Link';

  @override
  String get shareCopyWebLinkSubtitle => 'Copy shareable web link';

  @override
  String get shareCopyNostrLink => 'Copy Nostr Link';

  @override
  String get shareCopyNostrLinkSubtitle => 'Copy nevent link for Nostr clients';

  @override
  String get navHome => 'Home';

  @override
  String get navExplore => 'Explore';

  @override
  String get navInbox => 'Inbox';

  @override
  String get navProfile => 'Profile';

  @override
  String get navMyProfile => 'My Profile';

  @override
  String get navSearch => 'Search';

  @override
  String get navNotifications => 'Notifications';

  @override
  String get navSearchTooltip => 'Search';

  @override
  String get navOpenCamera => 'Open camera';

  @override
  String get navUnknown => 'Unknown';

  @override
  String get navExploreClassics => 'Classics';

  @override
  String get navExploreNewVideos => 'New Videos';

  @override
  String get navExploreTrending => 'Trending';

  @override
  String get navExploreForYou => 'For You';

  @override
  String get navExploreLists => 'Lists';

  @override
  String get routeErrorTitle => 'Error';

  @override
  String get routeInvalidHashtag => 'Invalid hashtag';

  @override
  String get routeInvalidConversationId => 'Invalid conversation ID';

  @override
  String get routeInvalidRequestId => 'Invalid request ID';

  @override
  String get routeInvalidListId => 'Invalid list ID';

  @override
  String get routeInvalidUserId => 'Invalid user ID';

  @override
  String get routeInvalidVideoId => 'Invalid video ID';

  @override
  String get routeInvalidSoundId => 'Invalid sound ID';

  @override
  String get routeInvalidCategory => 'Invalid category';

  @override
  String get routeNoVideosToDisplay => 'No videos to display';

  @override
  String get routeInvalidProfileId => 'Invalid profile ID';

  @override
  String get routeDefaultListName => 'List';

  @override
  String get supportTitle => 'Support Center';

  @override
  String get supportContactSupport => 'Contact Support';

  @override
  String get supportContactSupportSubtitle =>
      'Start a conversation or view past messages';

  @override
  String get supportReportBug => 'Report a Bug';

  @override
  String get supportReportBugSubtitle => 'Technical issues with the app';

  @override
  String get supportRequestFeature => 'Request a Feature';

  @override
  String get supportRequestFeatureSubtitle =>
      'Suggest an improvement or new feature';

  @override
  String get supportSaveLogs => 'Save Logs';

  @override
  String get supportSaveLogsSubtitle =>
      'Export logs to file for manual sending';

  @override
  String get supportFaq => 'FAQ';

  @override
  String get supportFaqSubtitle => 'Common questions & answers';

  @override
  String get supportProofMode => 'ProofMode';

  @override
  String get supportProofModeSubtitle =>
      'Learn about verification and authenticity';

  @override
  String get supportLoginRequired => 'Log in to contact support';

  @override
  String get supportExportingLogs => 'Exporting logs...';

  @override
  String get supportExportLogsFailed => 'Failed to export logs';

  @override
  String get supportChatNotAvailable => 'Support chat not available';

  @override
  String get supportCouldNotOpenMessages => 'Could not open support messages';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return 'Could not open $pageName';
  }

  @override
  String supportErrorOpeningPage(String pageName, Object error) {
    return 'Error opening $pageName: $error';
  }

  @override
  String get reportTitle => 'Report Content';

  @override
  String get reportWhyReporting => 'Why are you reporting this content?';

  @override
  String get reportPolicyNotice =>
      'Divine will act on content reports within 24 hours by removing the content and ejecting the user who provided the offending content.';

  @override
  String get reportAdditionalDetails => 'Additional details (optional)';

  @override
  String get reportBlockUser => 'Block this user';

  @override
  String get reportCancel => 'Cancel';

  @override
  String get reportSubmit => 'Report';

  @override
  String get reportSelectReason =>
      'Please select a reason for reporting this content';

  @override
  String get reportReasonSpam => 'Spam or Unwanted Content';

  @override
  String get reportReasonHarassment => 'Harassment, Bullying, or Threats';

  @override
  String get reportReasonViolence => 'Violent or Extremist Content';

  @override
  String get reportReasonSexualContent => 'Sexual or Adult Content';

  @override
  String get reportReasonCopyright => 'Copyright Violation';

  @override
  String get reportReasonFalseInfo => 'False Information';

  @override
  String get reportReasonCsam => 'Child Safety Violation';

  @override
  String get reportReasonAiGenerated => 'AI-Generated Content';

  @override
  String get reportReasonOther => 'Other Policy Violation';

  @override
  String reportFailed(Object error) {
    return 'Failed to report content: $error';
  }

  @override
  String get reportReceivedTitle => 'Report Received';

  @override
  String get reportReceivedThankYou =>
      'Thank you for helping keep Divine safe.';

  @override
  String get reportReceivedReviewNotice =>
      'Our team will review your report and take appropriate action. You may receive updates via direct message.';

  @override
  String get reportLearnMore => 'Learn More';

  @override
  String get reportSafetyUrl => 'divine.video/safety';

  @override
  String get reportClose => 'Close';

  @override
  String get listAddToList => 'Add to List';

  @override
  String listVideoCount(int count) {
    return '$count videos';
  }

  @override
  String get listNewList => 'New List';

  @override
  String get listDone => 'Done';

  @override
  String get listErrorLoading => 'Error loading lists';

  @override
  String listRemovedFrom(String name) {
    return 'Removed from $name';
  }

  @override
  String listAddedTo(String name) {
    return 'Added to $name';
  }

  @override
  String get listCreateNewList => 'Create New List';

  @override
  String get listNameLabel => 'List Name';

  @override
  String get listDescriptionLabel => 'Description (optional)';

  @override
  String get listPublicList => 'Public List';

  @override
  String get listPublicListSubtitle => 'Others can follow and see this list';

  @override
  String get listCancel => 'Cancel';

  @override
  String get listCreate => 'Create';

  @override
  String get listCreateFailed => 'Failed to create list';

  @override
  String get keyManagementTitle => 'Nostr Keys';

  @override
  String get keyManagementWhatAreKeys => 'What are Nostr keys?';

  @override
  String get keyManagementExplanation =>
      'Your Nostr identity is a cryptographic key pair:\n\n• Your public key (npub) is like your username - share it freely\n• Your private key (nsec) is like your password - keep it secret!\n\nYour nsec lets you access your account on any Nostr app.';

  @override
  String get keyManagementImportTitle => 'Import Existing Key';

  @override
  String get keyManagementImportSubtitle =>
      'Already have a Nostr account? Paste your private key (nsec) to access it here.';

  @override
  String get keyManagementImportButton => 'Import Key';

  @override
  String get keyManagementImportWarning =>
      'This will replace your current key!';

  @override
  String get keyManagementBackupTitle => 'Backup Your Key';

  @override
  String get keyManagementBackupSubtitle =>
      'Save your private key (nsec) to use your account in other Nostr apps.';

  @override
  String get keyManagementCopyNsec => 'Copy My Private Key (nsec)';

  @override
  String get keyManagementNeverShare => 'Never share your nsec with anyone!';

  @override
  String get keyManagementPasteKey => 'Please paste your private key';

  @override
  String get keyManagementInvalidFormat =>
      'Invalid key format. Must start with \"nsec1\"';

  @override
  String get keyManagementConfirmImportTitle => 'Import This Key?';

  @override
  String get keyManagementConfirmImportBody =>
      'This will replace your current identity with the imported one.\n\nYour current key will be lost unless you backed it up first.';

  @override
  String get keyManagementImportConfirm => 'Import';

  @override
  String get keyManagementImportSuccess => 'Key imported successfully!';

  @override
  String keyManagementImportFailed(Object error) {
    return 'Failed to import key: $error';
  }

  @override
  String get keyManagementExportSuccess =>
      'Private key copied to clipboard!\n\nStore it somewhere safe.';

  @override
  String keyManagementExportFailed(Object error) {
    return 'Failed to export key: $error';
  }

  @override
  String get saveOriginalSavedToCameraRoll => 'Saved to Camera Roll';

  @override
  String get saveOriginalShare => 'Share';

  @override
  String get saveOriginalDone => 'Done';

  @override
  String get saveOriginalPhotosAccessNeeded => 'Photos Access Needed';

  @override
  String get saveOriginalPhotosAccessMessage =>
      'To save videos, allow Photos access in Settings.';

  @override
  String get saveOriginalOpenSettings => 'Open Settings';

  @override
  String get saveOriginalNotNow => 'Not Now';

  @override
  String get saveOriginalDownloadFailed => 'Download Failed';

  @override
  String get saveOriginalDismiss => 'Dismiss';

  @override
  String get saveOriginalDownloadingVideo => 'Downloading Video';

  @override
  String get saveOriginalSavingToCameraRoll => 'Saving to Camera Roll';

  @override
  String get saveOriginalFetchingVideo =>
      'Fetching the video from the network...';

  @override
  String get saveOriginalSavingVideo =>
      'Saving the original video to your camera roll...';

  @override
  String get soundTitle => 'Sound';

  @override
  String get soundOriginalSound => 'Original sound';

  @override
  String get soundVideosUsingThisSound => 'Videos using this sound';

  @override
  String get soundSourceVideo => 'Source video';

  @override
  String get soundNoVideosYet => 'No videos yet';

  @override
  String get soundBeFirstToUse => 'Be the first to use this sound!';

  @override
  String get soundFailedToLoadVideos => 'Failed to load videos';

  @override
  String get soundRetry => 'Retry';

  @override
  String get soundVideosUnavailable => 'Videos unavailable';

  @override
  String get soundCouldNotLoadDetails => 'Could not load video details';

  @override
  String get soundPreview => 'Preview';

  @override
  String get soundStop => 'Stop';

  @override
  String get soundUseSound => 'Use Sound';

  @override
  String get soundNoVideoCount => 'No videos yet';

  @override
  String get soundOneVideo => '1 video';

  @override
  String soundVideoCount(int count) {
    return '$count videos';
  }

  @override
  String get soundUnableToPreview =>
      'Unable to preview sound - no audio available';

  @override
  String soundPreviewFailed(Object error) {
    return 'Failed to play preview: $error';
  }

  @override
  String get soundViewSource => 'View source';

  @override
  String get soundCloseTooltip => 'Close';

  @override
  String get exploreNotExploreRoute => 'Not an explore route';

  @override
  String get legalTitle => 'Legal';

  @override
  String get legalTermsOfService => 'Terms of Service';

  @override
  String get legalTermsOfServiceSubtitle => 'Usage terms and conditions';

  @override
  String get legalPrivacyPolicy => 'Privacy Policy';

  @override
  String get legalPrivacyPolicySubtitle => 'How we handle your data';

  @override
  String get legalSafetyStandards => 'Safety Standards';

  @override
  String get legalSafetyStandardsSubtitle => 'Community guidelines and safety';

  @override
  String get legalDmca => 'DMCA';

  @override
  String get legalDmcaSubtitle => 'Copyright and takedown policy';

  @override
  String get legalOpenSourceLicenses => 'Open Source Licenses';

  @override
  String get legalOpenSourceLicensesSubtitle =>
      'Third-party package attributions';

  @override
  String get legalAppName => 'Divine';

  @override
  String legalCouldNotOpenPage(String pageName) {
    return 'Could not open $pageName';
  }

  @override
  String legalErrorOpeningPage(String pageName, Object error) {
    return 'Error opening $pageName: $error';
  }
}
