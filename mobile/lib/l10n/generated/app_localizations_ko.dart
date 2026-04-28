// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'Divine';

  @override
  String get settingsTitle => '설정';

  @override
  String get settingsSecureAccount => '계정 보호하기';

  @override
  String get settingsSessionExpired => '세션이 만료됐어요';

  @override
  String get settingsSessionExpiredSubtitle => '다시 로그인해서 전체 접근 권한을 복구해보세요';

  @override
  String get settingsCreatorAnalytics => '크리에이터 분석';

  @override
  String get settingsSupportCenter => '고객센터';

  @override
  String get settingsNotifications => '알림';

  @override
  String get settingsContentPreferences => '콘텐츠 환경설정';

  @override
  String get settingsModerationControls => '조절 설정';

  @override
  String get settingsBlueskyPublishing => 'Bluesky 게시';

  @override
  String get settingsBlueskyPublishingSubtitle => 'Bluesky로의 크로스 포스팅을 관리해요';

  @override
  String get settingsNostrSettings => 'Nostr 설정';

  @override
  String get settingsIntegratedApps => '연동된 앱';

  @override
  String get settingsIntegratedAppsSubtitle => 'Divine 안에서 돌아가는 승인된 서드파티 앱';

  @override
  String get settingsExperimentalFeatures => '실험적 기능';

  @override
  String get settingsExperimentalFeaturesSubtitle =>
      '종종 딱굱1거리는 조정들—궁금하면 한번 써보세요.';

  @override
  String get settingsLegal => '법적 고지';

  @override
  String get settingsIntegrationPermissions => '연동 권한';

  @override
  String get settingsIntegrationPermissionsSubtitle => '저장된 연동 승인을 검토하고 취소해보세요';

  @override
  String settingsVersion(String version) {
    return '버전 $version';
  }

  @override
  String get settingsVersionEmpty => '버전';

  @override
  String get settingsDeveloperModeAlreadyEnabled => '개발자 모드가 이미 켜져 있어요';

  @override
  String get settingsDeveloperModeEnabled => '개발자 모드가 켜졌어요!';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    return '개발자 모드를 켜려면 $count번 더 탭해주세요';
  }

  @override
  String get settingsInvites => '초대장';

  @override
  String get settingsSwitchAccount => '계정 전환';

  @override
  String get settingsAddAnotherAccount => '다른 계정 추가';

  @override
  String get settingsUnsavedDraftsTitle => '저장되지 않은 초안';

  @override
  String settingsUnsavedDraftsMessage(int count) {
    return '저장되지 않은 초안이 $count개 있어요. 계정을 바꿔도 초안은 유지되지만, 먼저 게시하거나 검토하는 게 좋아요.';
  }

  @override
  String get settingsCancel => '취소';

  @override
  String get settingsSwitchAnyway => '그래도 전환';

  @override
  String get settingsAppVersionLabel => '앱 버전';

  @override
  String get settingsAppLanguage => '앱 언어';

  @override
  String settingsAppLanguageDeviceDefault(String language) {
    return '$language (기기 기본값)';
  }

  @override
  String get settingsAppLanguageTitle => '앱 언어';

  @override
  String get settingsAppLanguageDescription => '앱 인터페이스에서 사용할 언어를 고르세요';

  @override
  String get settingsAppLanguageUseDeviceLanguage => '기기 언어 사용';

  @override
  String get contentPreferencesTitle => '콘텐츠 환경설정';

  @override
  String get contentPreferencesContentFilters => '콘텐츠 필터';

  @override
  String get contentPreferencesContentFiltersSubtitle => '콘텐츠 경고 필터를 관리해요';

  @override
  String get contentPreferencesContentLanguage => '콘텐츠 언어';

  @override
  String contentPreferencesContentLanguageDeviceDefault(String language) {
    return '$language (기기 기본값)';
  }

  @override
  String get contentPreferencesTagYourVideos =>
      '시청자가 콘텐츠를 필터링할 수 있도록 영상에 언어를 태그해주세요.';

  @override
  String get contentPreferencesUseDeviceLanguage => '기기 언어 사용 (기본값)';

  @override
  String get contentPreferencesAudioSharing => '내 오디오 재사용 허용';

  @override
  String get contentPreferencesAudioSharingSubtitle =>
      '켜면 다른 사람들이 내 영상의 오디오를 쓸 수 있어요';

  @override
  String get contentPreferencesAccountLabels => '계정 라벨';

  @override
  String get contentPreferencesAccountLabelsEmpty => '내 콘텐츠에 스스로 라벨 달기';

  @override
  String get contentPreferencesAccountContentLabels => '계정 콘텐츠 라벨';

  @override
  String get contentPreferencesClearAll => '모두 지우기';

  @override
  String get contentPreferencesSelectAllThatApply => '내 계정에 해당하는 항목을 모두 선택해주세요';

  @override
  String get contentPreferencesDoneNoLabels => '완료 (라벨 없음)';

  @override
  String contentPreferencesDoneCount(int count) {
    return '완료 ($count개 선택)';
  }

  @override
  String get contentPreferencesAudioInputDevice => '오디오 입력 장치';

  @override
  String get contentPreferencesAutoRecommended => '자동 (추천)';

  @override
  String get contentPreferencesAutoSelectsBest => '가장 좋은 마이크를 자동으로 고르주세요';

  @override
  String get contentPreferencesSelectAudioInput => '오디오 입력 선택';

  @override
  String get contentPreferencesUnknownMicrophone => '알 수 없는 마이크';

  @override
  String get profileBlockedAccountNotAvailable => '이 계정은 이용할 수 없어요';

  @override
  String profileErrorPrefix(Object error) {
    return '오류: $error';
  }

  @override
  String get profileInvalidId => '잘못된 프로필 ID';

  @override
  String profileShareText(String displayName, String npub) {
    return 'Divine에서 $displayName님을 확인해보세요!\n\nhttps://divine.video/profile/$npub';
  }

  @override
  String profileShareSubject(String displayName) {
    return 'Divine의 $displayName';
  }

  @override
  String profileShareFailed(Object error) {
    return '프로필을 공유하지 못했어요: $error';
  }

  @override
  String get profileEditProfile => '프로필 편집';

  @override
  String get profileCreatorAnalytics => '크리에이터 분석';

  @override
  String get profileShareProfile => '프로필 공유';

  @override
  String get profileCopyPublicKey => '공개 키 복사 (npub)';

  @override
  String get profileGetEmbedCode => '임베드 코드 가져오기';

  @override
  String get profilePublicKeyCopied => '공개 키를 클립보드에 복사했어요';

  @override
  String get profileEmbedCodeCopied => '임베드 코드를 클립보드에 복사했어요';

  @override
  String get profileRefreshTooltip => '새로고침';

  @override
  String get profileRefreshSemanticLabel => '프로필 새로고침';

  @override
  String get profileMoreTooltip => '더보기';

  @override
  String get profileMoreSemanticLabel => '더 많은 옵션';

  @override
  String get profileFollowingLabel => '팔로잉';

  @override
  String get profileFollowLabel => '팔로우';

  @override
  String get profileBlockedLabel => '차단됨';

  @override
  String get profileFollowersLabel => '팔로워';

  @override
  String get profileFollowingStatLabel => '팔로잉';

  @override
  String get profileVideosLabel => '영상';

  @override
  String profileFollowerCountUsers(int count) {
    return '사용자 $count명';
  }

  @override
  String profileBlockTitle(String displayName) {
    return '$displayName님을 차단할까요?';
  }

  @override
  String get profileBlockExplanation => '사용자를 차단하면:';

  @override
  String get profileBlockBulletHidePosts => '이 사람의 게시물이 내 피드에 나타나지 않아요.';

  @override
  String get profileBlockBulletCantView =>
      '이 사람은 내 프로필을 보거나 팔로우하거나 게시물을 볼 수 없어요.';

  @override
  String get profileBlockBulletNoNotify => '차단은 상대에게 알림으로 전달되지 않아요.';

  @override
  String get profileBlockBulletYouCanView => '당신은 여전히 상대의 프로필을 볼 수 있어요.';

  @override
  String profileBlockConfirmButton(String displayName) {
    return '$displayName님 차단';
  }

  @override
  String get profileCancelButton => '취소';

  @override
  String get profileLearnMore => '자세히 알아보기';

  @override
  String profileUnblockTitle(String displayName) {
    return '$displayName님을 차단 해제할까요?';
  }

  @override
  String get profileUnblockExplanation => '이 사용자를 차단 해제하면:';

  @override
  String get profileUnblockBulletShowPosts => '이 사람의 게시물이 다시 내 피드에 나타나요.';

  @override
  String get profileUnblockBulletCanView =>
      '이 사람이 내 프로필을 보거나 팔로우하거나 게시물을 볼 수 있게 돼요.';

  @override
  String get profileUnblockBulletNoNotify => '차단 해제는 상대에게 알림으로 전달되지 않아요.';

  @override
  String get profileLearnMoreAt => '자세히 보기: ';

  @override
  String get profileUnblockButton => '차단 해제';

  @override
  String profileUnfollowDisplayName(String displayName) {
    return '$displayName님 언팔로우';
  }

  @override
  String profileBlockDisplayName(String displayName) {
    return '$displayName님 차단';
  }

  @override
  String profileUnblockDisplayName(String displayName) {
    return '$displayName님 차단 해제';
  }

  @override
  String get profileUserBlockedTitle => '사용자를 차단했어요';

  @override
  String get profileUserBlockedContent => '이 사용자의 콘텐츠는 피드에서 보이지 않아요.';

  @override
  String get profileUserBlockedUnblockHint =>
      '언제든 프로필이나 설정 > 안전에서 차단을 해제할 수 있어요.';

  @override
  String get profileCloseButton => '닫기';

  @override
  String get profileNoCollabsTitle => '아직 콜라보 없음';

  @override
  String get profileCollabsOwnEmpty => '콜라보한 영상이 여기에 나타나요';

  @override
  String get profileCollabsOtherEmpty => '이 사람이 콜라보한 영상이 여기에 나타나요';

  @override
  String get profileErrorLoadingCollabs => '콜라보 영상을 불러오지 못했어요';

  @override
  String get profileNoSavedVideosTitle => 'Nothing saved yet';

  @override
  String get profileSavedOwnEmpty =>
      'Bookmark videos from the share sheet and they\'ll show up here.';

  @override
  String get profileErrorLoadingSaved => 'Error loading saved videos';

  @override
  String get profileNoCommentsOwnTitle => '아직 댓글 없음';

  @override
  String get profileNoCommentsOtherTitle => '댓글 없음';

  @override
  String get profileCommentsOwnEmpty => '내가 쓴 댓글과 답글이 여기에 나타나요';

  @override
  String get profileCommentsOtherEmpty => '이 사람의 댓글과 답글이 여기에 나타나요';

  @override
  String get profileErrorLoadingComments => '댓글을 불러오지 못했어요';

  @override
  String get profileVideoRepliesSection => '영상 답글';

  @override
  String get profileCommentsSection => '댓글';

  @override
  String get profileEditLabel => '편집';

  @override
  String get profileLibraryLabel => '라이브러리';

  @override
  String get profileNoLikedVideosTitle => '아직 좋아요한 영상 없음';

  @override
  String get profileLikedOwnEmpty => '좋아요한 영상이 여기에 나타나요';

  @override
  String get profileLikedOtherEmpty => '이 사람이 좋아요한 영상이 여기에 나타나요';

  @override
  String get profileErrorLoadingLiked => '좋아요한 영상을 불러오지 못했어요';

  @override
  String get profileNoRepostsTitle => '아직 리포스트 없음';

  @override
  String get profileRepostsOwnEmpty => '리포스트한 영상이 여기에 나타나요';

  @override
  String get profileRepostsOtherEmpty => '이 사람이 리포스트한 영상이 여기에 나타나요';

  @override
  String get profileErrorLoadingReposts => '리포스트 영상을 불러오지 못했어요';

  @override
  String get profileLoadingTitle => '프로필을 불러오는 중...';

  @override
  String get profileLoadingSubtitle => '잠시 걸릴 수 있어요';

  @override
  String get profileLoadingVideos => '영상을 불러오는 중...';

  @override
  String get profileNoVideosTitle => '아직 영상 없음';

  @override
  String get profileNoVideosOwnSubtitle => '첫 영상을 공유하고 여기에서 확인해보세요';

  @override
  String get profileNoVideosOtherSubtitle => '이 사용자는 아직 영상을 공유하지 않았어요';

  @override
  String profileVideoThumbnailLabel(int number) {
    return '영상 썸네일 $number';
  }

  @override
  String get profileShowMore => '더보기';

  @override
  String get profileShowLess => '접기';

  @override
  String get profileCompleteYourProfile => '프로필 완성하기';

  @override
  String get profileCompleteSubtitle => '이름, 소개, 사진을 추가해서 시작해보세요';

  @override
  String get profileSetUpButton => '설정';

  @override
  String get profileVerifyingEmail => '이메일 인증 중...';

  @override
  String profileCheckEmailVerification(String email) {
    return '인증 링크가 $email로 갔어요';
  }

  @override
  String get profileWaitingForVerification => '이메일 인증 대기 중';

  @override
  String get profileVerificationFailed => '인증 실패';

  @override
  String get profilePleaseTryAgain => '다시 시도해보세요';

  @override
  String get profileSecureYourAccount => '계정 보호하기';

  @override
  String get profileSecureSubtitle => '이메일과 비밀번호를 추가해서 어느 기기에서든 계정을 복구해보세요';

  @override
  String get profileRetryButton => '다시 시도';

  @override
  String get profileRegisterButton => '가입하기';

  @override
  String get profileSessionExpired => '세션이 만료됐어요';

  @override
  String get profileSignInToRestore => '다시 로그인해서 전체 접근 권한을 복구해보세요';

  @override
  String get profileSignInButton => '로그인';

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
  String get profileDismissTooltip => '닫기';

  @override
  String get profileLinkCopied => '프로필 링크를 복사했어요';

  @override
  String get profileSetupEditProfileTitle => '프로필 편집';

  @override
  String get profileSetupBackLabel => '뒤로';

  @override
  String get profileSetupAboutNostr => 'Nostr란?';

  @override
  String get profileSetupProfilePublished => '프로필을 게시했어요!';

  @override
  String get profileSetupCreateNewProfile => '새 프로필을 만들까요?';

  @override
  String get profileSetupNoExistingProfile =>
      '릴레이에서 기존 프로필을 찾지 못했어요. 지금 게시하면 새 프로필이 만들어져요. 계속할까요?';

  @override
  String get profileSetupPublishButton => '게시';

  @override
  String get profileSetupUsernameTaken => '이 사용자명은 방금 선점됐어요. 다른 이름을 고르세요.';

  @override
  String get profileSetupClaimFailed => '사용자명을 가져오지 못했어요. 다시 시도해보세요.';

  @override
  String get profileSetupPublishFailed => '프로필을 게시하지 못했어요. 다시 시도해보세요.';

  @override
  String get profileSetupDisplayNameLabel => '표시 이름';

  @override
  String get profileSetupDisplayNameHint => '사람들에게 어떻게 불리고 싶으세요?';

  @override
  String get profileSetupDisplayNameHelper => '원하는 아무 이름이나 라벨이요. 고유하지 않아도 돼요.';

  @override
  String get profileSetupDisplayNameRequired => '표시 이름을 입력해주세요';

  @override
  String get profileSetupBioLabel => '소개 (선택)';

  @override
  String get profileSetupBioHint => '자신을 소개해보세요...';

  @override
  String get profileSetupPublicKeyLabel => '공개 키 (npub)';

  @override
  String get profileSetupUsernameLabel => '사용자명 (선택)';

  @override
  String get profileSetupUsernameHint => '사용자명';

  @override
  String get profileSetupUsernameHelper => 'Divine에서의 고유한 당신의 이름';

  @override
  String get profileSetupProfileColorLabel => '프로필 색상 (선택)';

  @override
  String get profileSetupSaveButton => '저장';

  @override
  String get profileSetupSavingButton => '저장 중...';

  @override
  String get profileSetupImageUrlTitle => '이미지 URL 추가';

  @override
  String get profileSetupPictureUploaded => '프로필 사진을 올렸어요!';

  @override
  String get profileSetupImageSelectionFailed =>
      '이미지 선택에 실패했어요. 아래에 이미지 URL을 붙여넣어보세요.';

  @override
  String profileSetupCameraAccessFailed(Object error) {
    return '카메라 접근 실패: $error';
  }

  @override
  String get profileSetupGotItButton => '알겠어요';

  @override
  String profileSetupUploadFailedGeneric(Object error) {
    return '이미지를 올리지 못했어요: $error';
  }

  @override
  String get profileSetupUploadNetworkError =>
      '네트워크 오류: 인터넷 연결을 확인하고 다시 시도해주세요.';

  @override
  String get profileSetupUploadAuthError => '인증 오류: 로그아웃 후 다시 로그인해보세요.';

  @override
  String get profileSetupUploadFileTooLarge =>
      '파일이 너무 커요: 더 작은 이미지를 고르세요 (최대 10MB).';

  @override
  String get profileSetupUsernameChecking => '사용 가능 여부 확인 중...';

  @override
  String get profileSetupUsernameAvailable => '사용 가능한 이름이에요!';

  @override
  String get profileSetupUsernameTakenIndicator => '이미 사용 중인 이름이에요';

  @override
  String get profileSetupUsernameReserved => '예약된 이름이에요';

  @override
  String get profileSetupContactSupport => '고객센터 문의';

  @override
  String get profileSetupCheckAgain => '다시 확인';

  @override
  String get profileSetupUsernameBurned => '이 사용자명은 더 이상 사용할 수 없어요';

  @override
  String get profileSetupUsernameInvalidFormat => '문자, 숫자, 하이픈만 쓸 수 있어요';

  @override
  String get profileSetupUsernameInvalidLength => '사용자명은 3~20자 사이여야 해요';

  @override
  String get profileSetupUsernameNetworkError =>
      '사용 가능 여부를 확인하지 못했어요. 다시 시도해보세요.';

  @override
  String get profileSetupUsernameInvalidFormatGeneric => '잘못된 사용자명 형식';

  @override
  String get profileSetupUsernameCheckFailed => '사용 가능 여부 확인에 실패했어요';

  @override
  String get profileSetupUsernameReservedTitle => '예약된 이름';

  @override
  String profileSetupUsernameReservedBody(String username) {
    return '$username은(는) 예약된 이름이에요. 왜 당신의 것이어야 하는지 알려주세요.';
  }

  @override
  String get profileSetupUsernameReservedHint => '예: 내 브랜드명, 활동명 등';

  @override
  String get profileSetupUsernameReservedCheckHint =>
      '이미 고객센터에 문의하셨나요? \"다시 확인\"을 눌러 해제되었는지 확인해보세요.';

  @override
  String get profileSetupSupportRequestSent => '요청을 보냈어요! 곷 답변드릴게요.';

  @override
  String get profileSetupCouldntOpenEmail =>
      '이메일을 열지 못했어요. names@divine.video로 보내주세요';

  @override
  String get profileSetupSendRequest => '요청 보내기';

  @override
  String get profileSetupPickColorTitle => '색상을 고르세요';

  @override
  String get profileSetupSelectButton => '선택';

  @override
  String get profileSetupUseOwnNip05 => '내 NIP-05 주소 쓰기';

  @override
  String get profileSetupNip05AddressLabel => 'NIP-05 주소';

  @override
  String get profileSetupProfilePicturePreview => '프로필 사진 미리보기';

  @override
  String get nostrInfoIntroBuiltOn => 'DiVine은 Nostr를 기반으로 만들어졌어요,';

  @override
  String get nostrInfoIntroDescription =>
      ' 하나의 회사나 플랫폼에 의존하지 않고 온라인으로 소통할 수 있게 해주는 검열 저항 개방형 프로토콜이에요. ';

  @override
  String get nostrInfoIntroIdentity => 'Divine에 가입하면 새 Nostr 아이덴티티를 받게 돼요.';

  @override
  String get nostrInfoOwnership =>
      'Nostr를 쓰면 내 콘텐츠, 아이덴티티, 소셜 그래프를 소유하고 여러 앱에서 쓸 수 있어요. 더 많은 선택, 적은 종속, 더 건강하고 탄력적인 소셜 인터넷을 만들 수 있죠.';

  @override
  String get nostrInfoLingo => 'Nostr 용어:';

  @override
  String get nostrInfoNpubLabel => 'npub:';

  @override
  String get nostrInfoNpubDescription =>
      ' 당신의 공개 Nostr 주소예요. 안전하게 공유할 수 있고, 다른 사람들이 Nostr 앱에서 당신을 찾거나 팔로우하거나 메시지를 보낼 수 있어요.';

  @override
  String get nostrInfoNsecLabel => 'nsec:';

  @override
  String get nostrInfoNsecDescription =>
      ' 당신의 개인 키이자 소유권 증명이에요. Nostr 아이덴티티를 완전히 통제할 수 있으니까, ';

  @override
  String get nostrInfoNsecWarning => '절대 비밀로 간직하세요!';

  @override
  String get nostrInfoUsernameLabel => 'Nostr 사용자명:';

  @override
  String get nostrInfoUsernameDescription =>
      ' npub에 연결되는 사람이 읽을 수 있는 이름(예: @name.divine.video)이에요. 이메일 주소처럼 Nostr 아이덴티티를 알아보고 인증하기 쉬워져요.';

  @override
  String get nostrInfoLearnMoreAt => '자세히 보기: ';

  @override
  String get nostrInfoGotIt => '알겠어요!';

  @override
  String get profileTabRefreshTooltip => '새로고침';

  @override
  String get videoGridRefreshLabel => '더 많은 영상을 찾는 중';

  @override
  String get videoGridOptionsTitle => '영상 옵션';

  @override
  String get videoGridEditVideo => '영상 편집';

  @override
  String get videoGridEditVideoSubtitle => '제목, 설명, 해시태그 수정';

  @override
  String get videoGridDeleteVideo => '영상 삭제';

  @override
  String get videoGridDeleteVideoSubtitle => '이 콘텐츠를 완전히 지워요';

  @override
  String get videoGridDeleteConfirmTitle => '영상 삭제';

  @override
  String get videoGridDeleteConfirmMessage => '이 영상을 정말 삭제할까요?';

  @override
  String get videoGridDeleteConfirmNote =>
      '모든 릴레이에 삭제 요청(NIP-09)을 보내요. 일부 릴레이에는 콘텐츠가 남아 있을 수 있어요.';

  @override
  String get videoGridDeleteCancel => '취소';

  @override
  String get videoGridDeleteConfirm => '삭제';

  @override
  String get videoGridDeletingContent => '콘텐츠 삭제 중...';

  @override
  String get videoGridDeleteSuccess => '삭제 요청을 보냈어요';

  @override
  String videoGridDeleteFailure(Object error) {
    return '콘텐츠를 삭제하지 못했어요: $error';
  }

  @override
  String get exploreTabClassics => '클래식';

  @override
  String get exploreTabNew => '신규';

  @override
  String get exploreTabPopular => '인기';

  @override
  String get exploreTabCategories => '카테고리';

  @override
  String get exploreTabForYou => '추천';

  @override
  String get exploreTabLists => '리스트';

  @override
  String get exploreTabIntegratedApps => '연동된 앱';

  @override
  String get exploreNoVideosAvailable => '이용 가능한 영상이 없어요';

  @override
  String exploreErrorPrefix(Object error) {
    return '오류: $error';
  }

  @override
  String get exploreDiscoverLists => '리스트 둘러보기';

  @override
  String get exploreAboutLists => '리스트란?';

  @override
  String get exploreAboutListsDescription =>
      '리스트는 Divine 콘텐츠를 두 가지 방식으로 정리하고 큐레이션할 수 있게 해줘요:';

  @override
  String get explorePeopleLists => '사람 리스트';

  @override
  String get explorePeopleListsDescription =>
      '크리에이터 그룹을 팔로우하고 그들의 최신 영상을 확인해보세요';

  @override
  String get exploreVideoLists => '영상 리스트';

  @override
  String get exploreVideoListsDescription => '좋아하는 영상의 플레이리스트를 만들어서 나중에 다시 보세요';

  @override
  String get exploreMyLists => '내 리스트';

  @override
  String get exploreSubscribedLists => '구독 리스트';

  @override
  String exploreErrorLoadingLists(Object error) {
    return '리스트를 불러오지 못했어요: $error';
  }

  @override
  String exploreNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '새 영상 $count개',
    );
    return '$_temp0';
  }

  @override
  String exploreLoadNewVideosLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '새 영상 $count개 불러오기',
    );
    return '$_temp0';
  }

  @override
  String get videoPlayerLoadingVideo => '영상 불러오는 중...';

  @override
  String get videoPlayerPlayVideo => '영상 재생';

  @override
  String get videoPlayerMute => '영상 음소거';

  @override
  String get videoPlayerUnmute => '영상 음소거 해제';

  @override
  String get videoPlayerEditVideo => '영상 편집';

  @override
  String get videoPlayerEditVideoTooltip => '영상 편집';

  @override
  String get contentWarningLabel => '콘텐츠 경고';

  @override
  String get contentWarningNudity => '노출';

  @override
  String get contentWarningSexualContent => '성적 콘텐츠';

  @override
  String get contentWarningPornography => '음란물';

  @override
  String get contentWarningGraphicMedia => '자극적 매체';

  @override
  String get contentWarningViolence => '폭력';

  @override
  String get contentWarningSelfHarm => '자해';

  @override
  String get contentWarningDrugUse => '약물 사용';

  @override
  String get contentWarningAlcohol => '알코올';

  @override
  String get contentWarningTobacco => '담배';

  @override
  String get contentWarningGambling => '도박';

  @override
  String get contentWarningProfanity => '욕설';

  @override
  String get contentWarningFlashingLights => '번짝이는 불빛';

  @override
  String get contentWarningAiGenerated => 'AI 생성';

  @override
  String get contentWarningSpoiler => '스포일러';

  @override
  String get contentWarningSensitiveContent => '민감한 콘텐츠';

  @override
  String get contentWarningDescNudity => '노출 또는 부분 노출을 포함해요';

  @override
  String get contentWarningDescSexual => '성적 콘텐츠를 포함해요';

  @override
  String get contentWarningDescPorn => '노골적인 음란물을 포함해요';

  @override
  String get contentWarningDescGraphicMedia => '자극적이거나 불편한 이미지를 포함해요';

  @override
  String get contentWarningDescViolence => '폭력적인 콘텐츠를 포함해요';

  @override
  String get contentWarningDescSelfHarm => '자해 관련 내용을 포함해요';

  @override
  String get contentWarningDescDrugs => '약물 관련 콘텐츠를 포함해요';

  @override
  String get contentWarningDescAlcohol => '알코올 관련 콘텐츠를 포함해요';

  @override
  String get contentWarningDescTobacco => '담배 관련 콘텐츠를 포함해요';

  @override
  String get contentWarningDescGambling => '도박 관련 콘텐츠를 포함해요';

  @override
  String get contentWarningDescProfanity => '강한 언어를 포함해요';

  @override
  String get contentWarningDescFlashingLights => '번짝이는 불빛을 포함해요 (광과민 주의)';

  @override
  String get contentWarningDescAiGenerated => '이 콘텐츠는 AI로 생성됐어요';

  @override
  String get contentWarningDescSpoiler => '스포일러를 포함해요';

  @override
  String get contentWarningDescContentWarning => '크리에이터가 민감한 콘텐츠로 표시했어요';

  @override
  String get contentWarningDescDefault => '크리에이터가 이 콘텐츠를 표시했어요';

  @override
  String get contentWarningDetailsTitle => '콘텐츠 경고';

  @override
  String get contentWarningDetailsSubtitle => '크리에이터가 적용한 라벨:';

  @override
  String get contentWarningManageFilters => '콘텐츠 필터 관리';

  @override
  String get contentWarningViewAnyway => '그래도 보기';

  @override
  String get contentWarningHideAllLikeThis => '이런 종류의 콘텐츠 모두 숨기기';

  @override
  String get contentWarningNoFilterYet => '이 경고에 대한 저장된 필터가 아직 없어요.';

  @override
  String get contentWarningHiddenConfirmation => '앞으로 이런 게시물은 숨길게요.';

  @override
  String get videoErrorNotFound => '영상을 찾을 수 없어요';

  @override
  String get videoErrorNetwork => '네트워크 오류';

  @override
  String get videoErrorTimeout => '로딩 시간 초과';

  @override
  String get videoErrorFormat => '영상 형식 오류\n(다시 시도하거나 다른 브라우저를 써보세요)';

  @override
  String get videoErrorUnsupportedFormat => '지원하지 않는 영상 형식';

  @override
  String get videoErrorPlayback => '영상 재생 오류';

  @override
  String get videoErrorAgeRestricted => '연령 제한 콘텐츠';

  @override
  String get videoErrorVerifyAge => '나이 인증';

  @override
  String get videoErrorRetry => '다시 시도';

  @override
  String get videoErrorContentRestricted => '콘텐츠 제한됨';

  @override
  String get videoErrorContentRestrictedBody => '이 영상은 릴레이에 의해 제한됐어요.';

  @override
  String get videoErrorVerifyAgeBody => '이 영상을 보려면 나이를 인증해주세요.';

  @override
  String get videoErrorSkip => '건너뛰기';

  @override
  String get videoErrorVerifyAgeButton => '나이 인증';

  @override
  String get videoFollowButtonFollowing => '팔로잉';

  @override
  String get videoFollowButtonFollow => '팔로우';

  @override
  String get audioAttributionOriginalSound => '오리지널 사운드';

  @override
  String videoInspiredByAttribution(String creatorName) {
    return '@$creatorName님에게 영감받아';
  }

  @override
  String videoCollaboratorWithOne(String name) {
    return '@$name님과 함께';
  }

  @override
  String videoCollaboratorWithMore(String name, int count) {
    return '@$name님 외 +$count명과 함께';
  }

  @override
  String videoCollaboratorCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '콜라보레이터 $count명',
    );
    return '$_temp0. 탭해서 프로필을 보세요.';
  }

  @override
  String get listAttributionFallback => '리스트';

  @override
  String get shareVideoLabel => '영상 공유';

  @override
  String sharePostSharedWith(String recipientName) {
    return '$recipientName님과 게시물을 공유했어요';
  }

  @override
  String get shareFailedToSend => '영상을 보내지 못했어요';

  @override
  String get shareAddedToBookmarks => '북마크에 추가했어요';

  @override
  String get shareFailedToAddBookmark => '북마크 추가에 실패했어요';

  @override
  String get shareActionFailed => '작업에 실패했어요';

  @override
  String get shareWithTitle => '공유 대상';

  @override
  String get shareFindPeople => '사람 찾기';

  @override
  String get shareFindPeopleMultiline => '사람\n찾기';

  @override
  String get shareSent => '보냄';

  @override
  String get shareContactFallback => '연락처';

  @override
  String get shareUserFallback => '사용자';

  @override
  String shareSendingTo(String name) {
    return '$name님에게 보내는 중';
  }

  @override
  String get shareMessageHint => '메시지 추가 (선택)...';

  @override
  String get videoActionUnlike => '좋아요 취소';

  @override
  String get videoActionLike => '좋아요';

  @override
  String get videoActionAutoLabel => '자동';

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
  String get videoActionEnableAutoAdvance => '자동 넘기기 활성화';

  @override
  String get videoActionDisableAutoAdvance => '자동 넘기기 비활성화';

  @override
  String get videoActionRemoveRepost => '리포스트 취소';

  @override
  String get videoActionRepost => '영상 리포스트';

  @override
  String get videoActionViewComments => '댓글 보기';

  @override
  String get videoActionMoreOptions => '더 많은 옵션';

  @override
  String get videoActionHideSubtitles => '자막 숨기기';

  @override
  String get videoActionShowSubtitles => '자막 표시';

  @override
  String get videoOverlayOpenMetadataFromTitle => 'Open video details';

  @override
  String get videoOverlayOpenMetadataFromDescription => 'Open video details';

  @override
  String videoDescriptionLoops(String count) {
    return '루프 $count회';
  }

  @override
  String videoFeedLoopCountLine(String compactCount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '루프',
    );
    return '$compactCount $_temp0';
  }

  @override
  String get metadataBadgeNotDivine => 'Divine 아님';

  @override
  String get metadataBadgeHumanMade => '사람 제작';

  @override
  String get metadataSoundsLabel => '사운드';

  @override
  String get metadataOriginalSound => '오리지널 사운드';

  @override
  String get metadataVerificationLabel => '인증';

  @override
  String get metadataDeviceAttestation => '기기 증명';

  @override
  String get metadataProofManifest => '증명 매니페스트';

  @override
  String get metadataCreatorLabel => '크리에이터';

  @override
  String get metadataCollaboratorsLabel => '콜라보레이터';

  @override
  String get metadataInspiredByLabel => '영감';

  @override
  String get metadataRepostedByLabel => '리포스트';

  @override
  String metadataLoopsLabel(int count) {
    return '루프';
  }

  @override
  String get metadataLikesLabel => '좋아요';

  @override
  String get metadataCommentsLabel => '댓글';

  @override
  String get metadataRepostsLabel => '리포스트';

  @override
  String get devOptionsTitle => '개발자 옵션';

  @override
  String get devOptionsPageLoadTimes => '페이지 로딩 시간';

  @override
  String get devOptionsNoPageLoads =>
      '아직 기록된 페이지 로드가 없어요.\n앱을 둘러보며 타이밍 데이터를 쌓아보세요.';

  @override
  String devOptionsPageLoadVisible(String visibleMs, String dataMs) {
    return '표시: ${visibleMs}ms  |  데이터: ${dataMs}ms';
  }

  @override
  String get devOptionsSlowestScreens => '가장 느린 화면';

  @override
  String get devOptionsVideoPlaybackFormat => '영상 재생 형식';

  @override
  String get devOptionsSwitchEnvironmentTitle => '환경을 전환할까요?';

  @override
  String devOptionsSwitchEnvironmentMessage(String envName) {
    return '$envName으로 전환할까요?\n\n캐시된 영상 데이터가 지워지고 새 릴레이에 다시 연결돼요.';
  }

  @override
  String get devOptionsCancel => '취소';

  @override
  String get devOptionsSwitch => '전환';

  @override
  String devOptionsSwitchedTo(String envName) {
    return '$envName으로 전환했어요';
  }

  @override
  String devOptionsSwitchedFormat(String formatName) {
    return '$formatName으로 전환했어요 — 캐시 삭제됨';
  }

  @override
  String get featureFlagTitle => '기능 플래그';

  @override
  String get featureFlagResetAllTooltip => '모든 플래그를 기본값으로 재설정';

  @override
  String get featureFlagResetToDefault => '기본값으로 재설정';

  @override
  String get featureFlagAppRecovery => '앱 복구';

  @override
  String get featureFlagAppRecoveryDescription =>
      '앱이 멈추거나 이상한 동작을 하면 캐시를 지워보세요.';

  @override
  String get featureFlagClearAllCache => '모든 캐시 삭제';

  @override
  String get featureFlagCacheInfo => '캐시 정보';

  @override
  String get featureFlagClearCacheTitle => '모든 캐시를 지울까요?';

  @override
  String get featureFlagClearCacheMessage =>
      '다음을 포함한 모든 캐시 데이터가 지워져요:\n• 알림\n• 사용자 프로필\n• 북마크\n• 임시 파일\n\n다시 로그인해야 해요. 계속할까요?';

  @override
  String get featureFlagClearCache => '캐시 삭제';

  @override
  String get featureFlagClearingCache => '캐시 삭제 중...';

  @override
  String get featureFlagSuccess => '성공';

  @override
  String get featureFlagError => '오류';

  @override
  String get featureFlagClearCacheSuccess => '캐시를 지웠어요. 앱을 다시 시작해주세요.';

  @override
  String get featureFlagClearCacheFailure =>
      '일부 캐시 항목을 지우지 못했어요. 자세한 내용은 로그를 확인해주세요.';

  @override
  String get featureFlagOk => '확인';

  @override
  String get featureFlagCacheInformation => '캐시 정보';

  @override
  String featureFlagTotalCacheSize(String size) {
    return '전체 캐시 크기: $size';
  }

  @override
  String get featureFlagCacheIncludes =>
      '캐시 포함 항목:\n• 알림 기록\n• 사용자 프로필 데이터\n• 영상 썸네일\n• 임시 파일\n• 데이터베이스 인덱스';

  @override
  String get relaySettingsTitle => '릴레이';

  @override
  String get relaySettingsInfoTitle => 'Divine은 개방형 시스템이에요 - 연결은 당신이 조절해요';

  @override
  String get relaySettingsInfoDescription =>
      '이 릴레이들이 분산형 Nostr 네트워크 전체에 콘텐츠를 전달해요. 원하는 대로 릴레이를 추가하거나 제거할 수 있어요.';

  @override
  String get relaySettingsLearnMoreNostr => 'Nostr에 대해 자세히 보기 →';

  @override
  String get relaySettingsFindPublicRelays => 'nostr.co.uk에서 공개 릴레이 찾기 →';

  @override
  String get relaySettingsAppNotFunctional => '앱이 작동하지 않아요';

  @override
  String get relaySettingsRequiresRelay =>
      'Divine은 영상을 불러오고 콘텐츠를 게시하고 데이터를 동기화하려면 최소 하나의 릴레이가 필요해요.';

  @override
  String get relaySettingsRestoreDefaultRelay => '기본 릴레이 복원';

  @override
  String get relaySettingsAddCustomRelay => '커스텀 릴레이 추가';

  @override
  String get relaySettingsAddRelay => '릴레이 추가';

  @override
  String get relaySettingsRetry => '다시 시도';

  @override
  String get relaySettingsNoStats => '아직 사용 가능한 통계가 없어요';

  @override
  String get relaySettingsConnection => '연결';

  @override
  String get relaySettingsConnected => '연결됨';

  @override
  String get relaySettingsDisconnected => '연결 끊김';

  @override
  String get relaySettingsSessionDuration => '세션 길이';

  @override
  String get relaySettingsLastConnected => '마지막 연결';

  @override
  String get relaySettingsDisconnectedLabel => '연결 끊김';

  @override
  String get relaySettingsReason => '이유';

  @override
  String get relaySettingsActiveSubscriptions => '활성 구독';

  @override
  String get relaySettingsTotalSubscriptions => '전체 구독';

  @override
  String get relaySettingsEventsReceived => '받은 이벤트';

  @override
  String get relaySettingsEventsSent => '보낸 이벤트';

  @override
  String get relaySettingsRequestsThisSession => '이번 세션 요청';

  @override
  String get relaySettingsFailedRequests => '실패한 요청';

  @override
  String relaySettingsLastError(String error) {
    return '마지막 오류: $error';
  }

  @override
  String get relaySettingsLoadingRelayInfo => '릴레이 정보 불러오는 중...';

  @override
  String get relaySettingsAboutRelay => '릴레이 정보';

  @override
  String get relaySettingsSupportedNips => '지원 NIP';

  @override
  String get relaySettingsSoftware => '소프트웨어';

  @override
  String get relaySettingsViewWebsite => '웹사이트 보기';

  @override
  String get relaySettingsRemoveRelayTitle => '릴레이를 제거할까요?';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return '이 릴레이를 정말 제거할까요?\n\n$relayUrl';
  }

  @override
  String get relaySettingsCancel => '취소';

  @override
  String get relaySettingsRemove => '제거';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return '릴레이를 제거했어요: $relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay => '릴레이 제거에 실패했어요';

  @override
  String get relaySettingsForcingReconnection => '릴레이 재연결 중...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    return '릴레이 $count개에 연결됐어요!';
  }

  @override
  String get relaySettingsFailedToConnectCheck =>
      '릴레이 연결에 실패했어요. 네트워크 연결을 확인해주세요.';

  @override
  String get relaySettingsAddRelayTitle => '릴레이 추가';

  @override
  String get relaySettingsAddRelayPrompt => '추가할 릴레이의 WebSocket URL을 입력해주세요:';

  @override
  String get relaySettingsBrowsePublicRelays => 'nostr.co.uk에서 공개 릴레이 둘러보기';

  @override
  String get relaySettingsAdd => '추가';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return '릴레이를 추가했어요: $relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay =>
      '릴레이 추가에 실패했어요. URL을 확인하고 다시 시도해보세요.';

  @override
  String get relaySettingsInvalidUrl => '릴레이 URL은 wss:// 또는 ws://로 시작해야 해요';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return '기본 릴레이를 복원했어요: $defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault =>
      '기본 릴레이 복원에 실패했어요. 네트워크 연결을 확인해주세요.';

  @override
  String get relaySettingsCouldNotOpenBrowser => '브라우저를 열 수 없어요';

  @override
  String get relaySettingsFailedToOpenLink => '링크를 열 수 없어요';

  @override
  String get relayDiagnosticTitle => '릴레이 진단';

  @override
  String get relayDiagnosticRefreshTooltip => '진단 새로고침';

  @override
  String relayDiagnosticLastRefresh(String time) {
    return '마지막 새로고침: $time';
  }

  @override
  String get relayDiagnosticRelayStatus => '릴레이 상태';

  @override
  String get relayDiagnosticInitialized => '초기화됨';

  @override
  String get relayDiagnosticReady => '준비 완료';

  @override
  String get relayDiagnosticNotInitialized => '초기화되지 않음';

  @override
  String get relayDiagnosticDatabaseEvents => '데이터베이스 이벤트';

  @override
  String get relayDiagnosticActiveSubscriptions => '활성 구독';

  @override
  String get relayDiagnosticExternalRelays => '외부 릴레이';

  @override
  String get relayDiagnosticConfigured => '구성됨';

  @override
  String relayDiagnosticRelayCount(int count) {
    return '릴레이 $count개';
  }

  @override
  String get relayDiagnosticConnectedLabel => '연결됨';

  @override
  String relayDiagnosticConnectedRatio(int connected, int total) {
    return '$connected/$total';
  }

  @override
  String get relayDiagnosticVideoEvents => '영상 이벤트';

  @override
  String get relayDiagnosticHomeFeed => '홈 피드';

  @override
  String relayDiagnosticVideosCount(int count) {
    return '영상 $count개';
  }

  @override
  String get relayDiagnosticDiscovery => '둘러보기';

  @override
  String get relayDiagnosticLoading => '불러오는 중';

  @override
  String get relayDiagnosticYes => '예';

  @override
  String get relayDiagnosticNo => '아니요';

  @override
  String get relayDiagnosticTestDirectQuery => '직접 쿼리 테스트';

  @override
  String get relayDiagnosticNetworkConnectivity => '네트워크 연결';

  @override
  String get relayDiagnosticRunNetworkTest => '네트워크 테스트 실행';

  @override
  String get relayDiagnosticBlossomServer => 'Blossom 서버';

  @override
  String get relayDiagnosticTestAllEndpoints => '모든 엔드포인트 테스트';

  @override
  String get relayDiagnosticStatus => '상태';

  @override
  String get relayDiagnosticUrl => 'URL';

  @override
  String get relayDiagnosticError => '오류';

  @override
  String get relayDiagnosticFunnelCakeApi => 'FunnelCake API';

  @override
  String get relayDiagnosticBaseUrl => '기본 URL';

  @override
  String get relayDiagnosticSummary => '요약';

  @override
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  ) {
    return '$successCount/$totalCount 정상 (평균 ${avgMs}ms)';
  }

  @override
  String get relayDiagnosticRetestAll => '모두 재테스트';

  @override
  String get relayDiagnosticRetrying => '다시 시도 중...';

  @override
  String get relayDiagnosticRetryConnection => '연결 다시 시도';

  @override
  String get relayDiagnosticTroubleshooting => '문제 해결';

  @override
  String get relayDiagnosticTroubleshootingGuide =>
      '• 초록 상태 = 연결되어 정상 작동 중\n• 적색 상태 = 연결 실패\n• 네트워크 테스트가 실패하면 인터넷 연결을 확인하세요\n• 릴레이가 구성되었는데 연결 안 되면 \"연결 다시 시도\"를 탭해주세요\n• 디버깅을 위해 이 화면을 캡처해두세요';

  @override
  String get relayDiagnosticAllEndpointsHealthy => '모든 REST 엔드포인트가 정상이에요!';

  @override
  String get relayDiagnosticSomeEndpointsFailed =>
      '일부 REST 엔드포인트가 실패했어요 - 위 세부 정보를 확인해주세요';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    return '데이터베이스에서 영상 이벤트 $count개를 찾았어요';
  }

  @override
  String relayDiagnosticQueryFailed(String error) {
    return '쿼리 실패: $error';
  }

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    return '릴레이 $count개에 연결됐어요!';
  }

  @override
  String get relayDiagnosticFailedToConnect => '릴레이 연결에 실패했어요';

  @override
  String relayDiagnosticConnectionRetryFailed(String error) {
    return '연결 재시도 실패: $error';
  }

  @override
  String get relayDiagnosticConnectedAuthenticated => '연결 및 인증됨';

  @override
  String get relayDiagnosticConnectedOnly => '연결됨';

  @override
  String get relayDiagnosticNotConnected => '연결되지 않음';

  @override
  String get relayDiagnosticNoRelaysConfigured => '구성된 릴레이가 없어요';

  @override
  String get relayDiagnosticFailed => '실패';

  @override
  String get notificationSettingsTitle => '알림';

  @override
  String get notificationSettingsResetTooltip => '기본값으로 재설정';

  @override
  String get notificationSettingsTypes => '알림 종류';

  @override
  String get notificationSettingsLikes => '좋아요';

  @override
  String get notificationSettingsLikesSubtitle => '누군가 내 영상을 좋아할 때';

  @override
  String get notificationSettingsComments => '댓글';

  @override
  String get notificationSettingsCommentsSubtitle => '누군가 내 영상에 댓글을 달 때';

  @override
  String get notificationSettingsFollows => '팔로우';

  @override
  String get notificationSettingsFollowsSubtitle => '누군가 나를 팔로우할 때';

  @override
  String get notificationSettingsMentions => '멘션';

  @override
  String get notificationSettingsMentionsSubtitle => '멘션될 때';

  @override
  String get notificationSettingsReposts => '리포스트';

  @override
  String get notificationSettingsRepostsSubtitle => '누군가 내 영상을 리포스트할 때';

  @override
  String get notificationSettingsSystem => '시스템';

  @override
  String get notificationSettingsSystemSubtitle => '앱 업데이트와 시스템 메시지';

  @override
  String get notificationSettingsPushNotificationsSection => '푸시 알림';

  @override
  String get notificationSettingsPushNotifications => '푸시 알림';

  @override
  String get notificationSettingsPushNotificationsSubtitle =>
      '앱이 꺼져 있을 때도 알림 받기';

  @override
  String get notificationSettingsSound => '소리';

  @override
  String get notificationSettingsSoundSubtitle => '알림 소리 재생';

  @override
  String get notificationSettingsVibration => '진동';

  @override
  String get notificationSettingsVibrationSubtitle => '알림 시 진동';

  @override
  String get notificationSettingsActions => '작업';

  @override
  String get notificationSettingsMarkAllAsRead => '모두 읽음으로 표시';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle => '모든 알림을 읽음으로 표시';

  @override
  String get notificationSettingsAllMarkedAsRead => '모든 알림을 읽음으로 표시했어요';

  @override
  String get notificationSettingsResetToDefaults => '설정이 기본값으로 되돌아갔어요';

  @override
  String get notificationSettingsAbout => '알림 안내';

  @override
  String get notificationSettingsAboutDescription =>
      '알림은 Nostr 프로토콜로 구동돼요. 실시간 업데이트는 Nostr 릴레이에의 연결에 따라 달라져요. 일부 알림은 지연될 수 있어요.';

  @override
  String get safetySettingsTitle => '안전 및 개인정보';

  @override
  String get safetySettingsLabel => '설정';

  @override
  String get safetySettingsShowDivineHostedOnly => 'Divine이 호스팅하는 영상만 보이기';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle =>
      '다른 매체 호스트에서 제공되는 영상은 숨겨요';

  @override
  String get safetySettingsModeration => '조절';

  @override
  String get safetySettingsBlockedUsers => '차단된 사용자';

  @override
  String get safetySettingsAgeVerification => '나이 인증';

  @override
  String get safetySettingsAgeConfirmation => '나는 18세 이상임을 확인해요';

  @override
  String get safetySettingsAgeRequired => '성인 콘텐츠를 보려면 필요해요';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle => '공식 조절 서비스 (기본 켜짐)';

  @override
  String get safetySettingsPeopleIFollow => '내가 팔로우하는 사람';

  @override
  String get safetySettingsPeopleIFollowSubtitle => '팔로우하는 사람들의 라벨을 구독해요';

  @override
  String get safetySettingsAddCustomLabeler => '커스텀 라벨러 추가';

  @override
  String get safetySettingsAddCustomLabelerHint => 'npub 입력...';

  @override
  String get safetySettingsAddCustomLabelerListTitle => '커스텀 라벨러 추가';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle => 'npub 주소를 입력해주세요';

  @override
  String get safetySettingsNoBlockedUsers => '차단한 사용자가 없어요';

  @override
  String get safetySettingsUnblock => '차단 해제';

  @override
  String get safetySettingsUserUnblocked => '사용자 차단을 해제했어요';

  @override
  String get safetySettingsCancel => '취소';

  @override
  String get safetySettingsAdd => '추가';

  @override
  String get analyticsTitle => '크리에이터 분석';

  @override
  String get analyticsDiagnosticsTooltip => '진단';

  @override
  String get analyticsDiagnosticsSemanticLabel => '진단 토글';

  @override
  String get analyticsRetry => '다시 시도';

  @override
  String get analyticsUnableToLoad => '분석을 불러올 수 없어요.';

  @override
  String get analyticsSignInRequired => '크리에이터 분석을 보려면 로그인해주세요.';

  @override
  String get analyticsViewDataUnavailable =>
      '이 게시물에 대한 조회수는 현재 릴레이에서 제공되지 않아요. 좋아요/댓글/리포스트 지표는 정확해요.';

  @override
  String get analyticsViewDataTitle => '조회 데이터';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return '업데이트 $time • 점수는 Funnelcake에서 사용 가능한 경우 좋아요, 댓글, 리포스트, 조회/루프를 사용해요.';
  }

  @override
  String get analyticsVideos => '영상';

  @override
  String get analyticsViews => '조회수';

  @override
  String get analyticsInteractions => '상호작용';

  @override
  String get analyticsEngagement => '참여도';

  @override
  String get analyticsFollowers => '팔로워';

  @override
  String get analyticsAvgPerPost => '게시물당 평균';

  @override
  String get analyticsInteractionMix => '상호작용 구성';

  @override
  String get analyticsLikes => '좋아요';

  @override
  String get analyticsComments => '댓글';

  @override
  String get analyticsReposts => '리포스트';

  @override
  String get analyticsPerformanceHighlights => '주요 성과';

  @override
  String get analyticsMostViewed => '가장 많이 본 영상';

  @override
  String get analyticsMostDiscussed => '가장 많이 이야기된 영상';

  @override
  String get analyticsMostReposted => '가장 많이 리포스트된 영상';

  @override
  String get analyticsNoVideosYet => '아직 영상이 없어요';

  @override
  String get analyticsViewDataUnavailableShort => '조회 데이터 없음';

  @override
  String analyticsViewsCount(String count) {
    return '조회수 $count';
  }

  @override
  String analyticsCommentsCount(String count) {
    return '댓글 $count';
  }

  @override
  String analyticsRepostsCount(String count) {
    return '리포스트 $count';
  }

  @override
  String get analyticsTopContent => '인기 콘텐츠';

  @override
  String get analyticsPublishPrompt => '순위를 보려면 영상을 몇 개 게시해보세요.';

  @override
  String get analyticsEngagementRateExplainer => '오른쪽 % = 참여율 (상호작용 ÷ 조회수).';

  @override
  String get analyticsEngagementRateNoViews =>
      '참여율은 조회 데이터가 필요해요; 조회수가 제공될 때까지 N/A로 표시돼요.';

  @override
  String get analyticsEngagementLabel => '참여도';

  @override
  String get analyticsViewsUnavailable => '조회수 없음';

  @override
  String analyticsInteractionsCount(String count) {
    return '상호작용 $count';
  }

  @override
  String get analyticsPostAnalytics => '게시물 분석';

  @override
  String get analyticsOpenPost => '게시물 열기';

  @override
  String get analyticsRecentDailyInteractions => '최근 일별 상호작용';

  @override
  String get analyticsNoActivityYet => '이 기간에는 아직 활동이 없어요.';

  @override
  String get analyticsDailyInteractionsExplainer =>
      '상호작용 = 게시일 기준 좋아요 + 댓글 + 리포스트.';

  @override
  String get analyticsDailyBarExplainer => '막대 길이는 이 기간의 최고치에 대한 상대적 값이에요.';

  @override
  String get analyticsAudienceSnapshot => '시청자 스냅샷';

  @override
  String analyticsFollowersCount(String count) {
    return '팔로워: $count';
  }

  @override
  String analyticsFollowingCount(String count) {
    return '팔로잉: $count';
  }

  @override
  String get analyticsAudiencePlaceholder =>
      'Funnelcake가 시청자 분석 엔드포인트를 추가하면 시청자 소스/지역/시간 분석이 채워져요.';

  @override
  String get analyticsRetention => '재시청률';

  @override
  String get analyticsRetentionWithViews =>
      'Funnelcake에서 초/버킷별 재시청 데이터가 도착하면 재시청 곡선과 시청 시간 분석이 나타나요.';

  @override
  String get analyticsRetentionWithoutViews =>
      'Funnelcake에서 조회+시청 시간 분석이 반환될 때까지 재시청 데이터는 이용할 수 없어요.';

  @override
  String get analyticsDiagnostics => '진단';

  @override
  String analyticsDiagnosticsTotalVideos(int count) {
    return '전체 영상: $count';
  }

  @override
  String analyticsDiagnosticsWithViews(int count) {
    return '조회 데이터 있음: $count';
  }

  @override
  String analyticsDiagnosticsMissingViews(int count) {
    return '조회 데이터 없음: $count';
  }

  @override
  String analyticsDiagnosticsHydratedBulk(int count) {
    return '체워짐 (배치): $count';
  }

  @override
  String analyticsDiagnosticsHydratedViews(int count) {
    return '체워짐 (/views): $count';
  }

  @override
  String analyticsDiagnosticsSources(String sources) {
    return '소스: $sources';
  }

  @override
  String get analyticsDiagnosticsUseFixture => '고정 데이터 사용';

  @override
  String get analyticsNa => 'N/A';

  @override
  String get authCreateNewAccount => '새 Divine 계정 만들기';

  @override
  String get authSignInDifferentAccount => '다른 계정으로 로그인';

  @override
  String get authSignBackIn => '다시 로그인';

  @override
  String get authTermsPrefix =>
      '위에서 옵션을 선택하면 만 16세 이상임을 확인하고 다음 내용에 동의하는 것이에요: ';

  @override
  String get authTermsOfService => '이용약관';

  @override
  String get authPrivacyPolicy => '개인정보 처리방침';

  @override
  String get authTermsAnd => ', 그리고 ';

  @override
  String get authSafetyStandards => '안전 기준';

  @override
  String get authAmberNotInstalled => 'Amber 앱이 설치되지 않았어요';

  @override
  String get authAmberConnectionFailed => 'Amber와 연결하지 못했어요';

  @override
  String get authPasswordResetSent => '해당 이메일로 가입된 계정이 있으면 비밀번호 재설정 링크를 보냈어요.';

  @override
  String get authSignInTitle => '로그인';

  @override
  String get authEmailLabel => '이메일';

  @override
  String get authPasswordLabel => '비밀번호';

  @override
  String get authForgotPassword => '비밀번호를 잊으셨나요?';

  @override
  String get authImportNostrKey => 'Nostr 키 가져오기';

  @override
  String get authConnectSignerApp => '서명 앱으로 연결';

  @override
  String get authSignInWithAmber => 'Amber로 로그인';

  @override
  String get authSignInOptionsTitle => '로그인 옵션';

  @override
  String get authInfoEmailPasswordTitle => '이메일 및 비밀번호';

  @override
  String get authInfoEmailPasswordDescription =>
      'Divine 계정으로 로그인하세요. 이메일과 비밀번호로 가입했다면 여기서 쓰면 돼요.';

  @override
  String get authInfoImportNostrKeyDescription =>
      '이미 Nostr 아이덴티티가 있나요? 다른 클라이언트에서 nsec 개인 키를 가져오세요.';

  @override
  String get authInfoSignerAppTitle => '서명 앱';

  @override
  String get authInfoSignerAppDescription =>
      '키 보안 강화를 위해 nsecBunker같은 NIP-46 호환 원격 서명 앱을 쓰세요.';

  @override
  String get authInfoAmberTitle => 'Amber';

  @override
  String get authInfoAmberDescription =>
      '안드로이드에서 Amber 서명 앱으로 Nostr 키를 안전하게 관리해보세요.';

  @override
  String get authCreateAccountTitle => '계정 만들기';

  @override
  String get authBackToInviteCode => '초대 코드로 돌아가기';

  @override
  String get authUseDivineNoBackup => '백업 없이 Divine 쓰기';

  @override
  String get authSkipConfirmTitle => '마지막으로...';

  @override
  String get authSkipConfirmKeyCreated =>
      '들어오셨어요! Divine 계정을 구동할 안전한 키를 만들어드릴게요.';

  @override
  String get authSkipConfirmKeyOnly =>
      '이메일이 없으면 Divine이 이 계정을 당신의 것이라고 알 수 있는 유일한 방법은 키뿐이에요.';

  @override
  String get authSkipConfirmRecommendEmail =>
      '앱에서 키를 확인할 수는 있지만, 기술적 지식이 없다면 지금 이메일과 비밀번호를 추가하시는 걸 추천드려요. 이 기기를 잃거나 초기화해도 쉽게 로그인하고 계정을 복구할 수 있어요.';

  @override
  String get authAddEmailPassword => '이메일과 비밀번호 추가';

  @override
  String get authUseThisDeviceOnly => '이 기기에서만 쓰기';

  @override
  String get authCompleteRegistration => '가입 완료하기';

  @override
  String get authVerifying => '인증 중...';

  @override
  String get authVerificationLinkSent => '다음 주소로 인증 링크를 보냈어요:';

  @override
  String get authClickVerificationLink => '이메일의 링크를 클릭해서\n가입을 완료해주세요.';

  @override
  String get authPleaseWaitVerifying => '이메일을 인증하는 동안 기다려주세요...';

  @override
  String get authWaitingForVerification => '인증 대기 중';

  @override
  String get authOpenEmailApp => '이메일 앱 열기';

  @override
  String get authWelcomeToDivine => 'Divine에 오신 걸 환영해요!';

  @override
  String get authEmailVerified => '이메일이 인증됐어요.';

  @override
  String get authSigningYouIn => '로그인 중';

  @override
  String get authErrorTitle => '이런.';

  @override
  String get authVerificationFailed => '이메일 인증에 실패했어요.\n다시 시도해보세요.';

  @override
  String get authStartOver => '처음부터 다시';

  @override
  String get authEmailVerifiedLogin => '이메일 인증 완료! 계속하려면 로그인해주세요.';

  @override
  String get authVerificationLinkExpired => '이 인증 링크는 더 이상 유효하지 않아요.';

  @override
  String get authVerificationConnectionError =>
      '이메일을 인증할 수 없어요. 연결을 확인하고 다시 시도해주세요.';

  @override
  String get authWaitlistConfirmTitle => '들어오셨어요!';

  @override
  String authWaitlistUpdatesAt(String email) {
    return '$email로 업데이트를 공유할게요.\n초대 코드가 재고가 생기면 보내드릴게요.';
  }

  @override
  String get authOk => '확인';

  @override
  String get authInviteUnavailable => '초대 접근이 일시적으로 이용 불가능해요.';

  @override
  String get authInviteUnavailableBody =>
      '잠시 후에 다시 시도하거나 도움이 필요하면 고객센터에 문의해주세요.';

  @override
  String get authTryAgain => '다시 시도';

  @override
  String get authContactSupport => '고객센터 문의';

  @override
  String authCouldNotOpenEmail(String email) {
    return '$email을(를) 열 수 없어요';
  }

  @override
  String get authAddInviteCode => '초대 코드를 입력해주세요';

  @override
  String get authInviteCodeLabel => '초대 코드';

  @override
  String get authEnterYourCode => '코드 입력';

  @override
  String get authNext => '다음';

  @override
  String get authJoinWaitlist => '대기자 명단 등록';

  @override
  String get authJoinWaitlistTitle => '대기자 명단에 등록하기';

  @override
  String get authJoinWaitlistDescription => '이메일을 알려주시면 접근이 열릴 때 업데이트를 보내드릴게요.';

  @override
  String get authInviteAccessHelp => '초대 접근 도움말';

  @override
  String get authGeneratingConnection => '연결 생성 중...';

  @override
  String get authConnectedAuthenticating => '연결됨! 인증 중...';

  @override
  String get authConnectionTimedOut => '연결 시간 초과';

  @override
  String get authApproveConnection => '서명 앱에서 연결을 승인했는지 확인해주세요.';

  @override
  String get authConnectionCancelled => '연결이 취소됐어요';

  @override
  String get authConnectionCancelledMessage => '연결이 취소됐어요.';

  @override
  String get authConnectionFailed => '연결 실패';

  @override
  String get authUnknownError => '알 수 없는 오류가 발생했어요.';

  @override
  String get authUrlCopied => 'URL을 클립보드에 복사했어요';

  @override
  String get authConnectToDivine => 'Divine에 연결';

  @override
  String get authPasteBunkerUrl => 'bunker:// URL 붙여넣기';

  @override
  String get authBunkerUrlHint => 'bunker:// URL';

  @override
  String get authInvalidBunkerUrl => '잘못된 bunker URL이에요. bunker://로 시작해야 해요';

  @override
  String get authScanSignerApp => '서명 앱으로 스캔해서\n연결해주세요.';

  @override
  String authWaitingForConnection(int seconds) {
    return '연결 대기 중... $seconds초';
  }

  @override
  String get authCopyUrl => 'URL 복사';

  @override
  String get authShare => '공유';

  @override
  String get authAddBunker => 'Bunker 추가';

  @override
  String get authCompatibleSignerApps => '호환 서명 앱';

  @override
  String get authFailedToConnect => '연결에 실패했어요';

  @override
  String get authResetPasswordTitle => '비밀번호 재설정';

  @override
  String get authResetPasswordSubtitle => '새 비밀번호를 입력해주세요. 최소 8자 이상이어야 해요.';

  @override
  String get authNewPasswordLabel => '새 비밀번호';

  @override
  String get authPasswordTooShort => '비밀번호는 최소 8자 이상이어야 해요';

  @override
  String get authPasswordResetSuccess => '비밀번호를 재설정했어요. 다시 로그인해주세요.';

  @override
  String get authPasswordResetFailed => '비밀번호 재설정에 실패했어요';

  @override
  String get authUnexpectedError => '예상치 못한 오류가 발생했어요. 다시 시도해주세요.';

  @override
  String get authUpdatePassword => '비밀번호 변경';

  @override
  String get authSecureAccountTitle => '계정 보호';

  @override
  String get authUnableToAccessKeys => '키에 접근할 수 없어요. 다시 시도해보세요.';

  @override
  String get authRegistrationFailed => '가입에 실패했어요';

  @override
  String get authRegistrationComplete => '가입이 완료됐어요. 이메일을 확인해주세요.';

  @override
  String get authVerificationFailedTitle => '인증 실패';

  @override
  String get authClose => '닫기';

  @override
  String get authAccountSecured => '계정이 보호됐어요!';

  @override
  String get authAccountLinkedToEmail => '계정이 이메일에 연결됐어요.';

  @override
  String get authVerifyYourEmail => '이메일을 인증해주세요';

  @override
  String get authClickLinkContinue =>
      '가입을 마치려면 이메일의 링크를 클릭해주세요. 그 동안 앱을 계속 쓸 수 있어요.';

  @override
  String get authWaitingForVerificationEllipsis => '인증 대기 중...';

  @override
  String get authContinueToApp => '앱으로 계속';

  @override
  String get authResetPassword => '비밀번호 재설정';

  @override
  String get authResetPasswordDescription =>
      '이메일 주소를 입력하면 비밀번호 재설정 링크를 보내드릴게요.';

  @override
  String get authFailedToSendResetEmail => '재설정 이메일을 보내지 못했어요.';

  @override
  String get authUnexpectedErrorShort => '예상치 못한 오류가 발생했어요.';

  @override
  String get authSending => '보내는 중...';

  @override
  String get authSendResetLink => '재설정 링크 보내기';

  @override
  String get authEmailSent => '이메일을 보냈어요!';

  @override
  String authResetLinkSentTo(String email) {
    return '$email로 비밀번호 재설정 링크를 보냈어요. 이메일의 링크를 클릭해서 비밀번호를 변경해주세요.';
  }

  @override
  String get authSignInButton => '로그인';

  @override
  String get authVerificationErrorTimeout => '인증 시간이 초과됐어요. 다시 가입해보세요.';

  @override
  String get authVerificationErrorMissingCode => '인증 실패 — 인증 코드가 없어요.';

  @override
  String get authVerificationErrorPollFailed => '인증에 실패했어요. 다시 시도해주세요.';

  @override
  String get authVerificationErrorNetworkExchange =>
      '로그인 중 네트워크 오류가 발생했어요. 다시 시도해주세요.';

  @override
  String get authVerificationErrorOAuthExchange => '인증에 실패했어요. 다시 가입해보세요.';

  @override
  String get authVerificationErrorSignInFailed =>
      '로그인에 실패했어요. 수동으로 로그인을 시도해보세요.';

  @override
  String get authInviteErrorAlreadyUsed =>
      '그 초대 코드는 더 이상 쓸 수 없어요. 초대 코드로 돌아가거나, 대기자 명단에 등록하거나, 고객센터에 문의해주세요.';

  @override
  String get authInviteErrorInvalid =>
      '그 초대 코드는 지금 쓸 수 없어요. 초대 코드로 돌아가거나, 대기자 명단에 등록하거나, 고객센터에 문의해주세요.';

  @override
  String get authInviteErrorTemporary =>
      '지금은 초대 코드를 확인할 수 없어요. 초대 코드로 돌아가서 다시 시도하거나 고객센터에 문의해주세요.';

  @override
  String get authInviteErrorUnknown =>
      '초대를 활성화할 수 없어요. 초대 코드로 돌아가거나, 대기자 명단에 등록하거나, 고객센터에 문의해주세요.';

  @override
  String get shareSheetSave => '저장';

  @override
  String get shareSheetSaveToGallery => '갤러리에 저장';

  @override
  String get shareSheetSaveWithWatermark => '워터마크와 함께 저장';

  @override
  String get shareSheetSaveVideo => '영상 저장';

  @override
  String get shareSheetAddToList => '리스트에 추가';

  @override
  String get shareSheetCopy => '복사';

  @override
  String get shareSheetShareVia => '다른 곳으로 공유';

  @override
  String get shareSheetReport => '신고';

  @override
  String get shareSheetEventJson => '이벤트 JSON';

  @override
  String get shareSheetEventId => '이벤트 ID';

  @override
  String get shareSheetMoreActions => '더 많은 작업';

  @override
  String get watermarkDownloadSavedToCameraRoll => '카메라 롤에 저장했어요';

  @override
  String get watermarkDownloadShare => '공유';

  @override
  String get watermarkDownloadDone => '완료';

  @override
  String get watermarkDownloadPhotosAccessNeeded => '사진 접근 권한이 필요해요';

  @override
  String get watermarkDownloadPhotosAccessDescription =>
      '영상을 저장하려면 설정에서 사진 접근을 허용해주세요.';

  @override
  String get watermarkDownloadOpenSettings => '설정 열기';

  @override
  String get watermarkDownloadNotNow => '다음에';

  @override
  String get watermarkDownloadFailed => '다운로드에 실패했어요';

  @override
  String get watermarkDownloadDismiss => '닫기';

  @override
  String get watermarkDownloadStageDownloading => '영상 다운로드 중';

  @override
  String get watermarkDownloadStageWatermarking => '워터마크 추가 중';

  @override
  String get watermarkDownloadStageSaving => '카메라 롤에 저장 중';

  @override
  String get watermarkDownloadStageDownloadingDesc => '네트워크에서 영상을 가져오는 중...';

  @override
  String get watermarkDownloadStageWatermarkingDesc => 'Divine 워터마크를 적용하는 중...';

  @override
  String get watermarkDownloadStageSavingDesc =>
      '워터마크가 적용된 영상을 카메라 롤에 저장하는 중...';

  @override
  String get uploadProgressVideoUpload => '영상 업로드';

  @override
  String get uploadProgressPause => '일시 정지';

  @override
  String get uploadProgressResume => '재개';

  @override
  String get uploadProgressGoBack => '뒤로';

  @override
  String uploadProgressRetryWithCount(int count) {
    return '다시 시도 ($count회 남음)';
  }

  @override
  String get uploadProgressDelete => '삭제';

  @override
  String uploadProgressDaysAgo(int count) {
    return '$count일 전';
  }

  @override
  String uploadProgressHoursAgo(int count) {
    return '$count시간 전';
  }

  @override
  String uploadProgressMinutesAgo(int count) {
    return '$count분 전';
  }

  @override
  String get uploadProgressJustNow => '방금';

  @override
  String uploadProgressUploadingPercent(int percent) {
    return '업로드 중 $percent%';
  }

  @override
  String uploadProgressPausedPercent(int percent) {
    return '일시 정지 $percent%';
  }

  @override
  String get badgeExplanationClose => '닫기';

  @override
  String get badgeExplanationOriginalVineArchive => '오리지널 Vine 아카이브';

  @override
  String get badgeExplanationCameraProof => '카메라 증명';

  @override
  String get badgeExplanationAuthenticitySignals => '진본 신호';

  @override
  String get badgeExplanationVineArchiveIntro =>
      '이 영상은 Internet Archive에서 복구한 오리지널 Vine이에요.';

  @override
  String get badgeExplanationVineArchiveHistory =>
      '2017년 Vine이 문을 닫기 전에 ArchiveTeam과 Internet Archive는 수백만 개의 Vine을 보존하기 위해 노력했어요. 이 콘텐츠는 그 역사적 보존 노력의 일부예요.';

  @override
  String badgeExplanationOriginalStats(int loops) {
    return '오리지널 통계: 루프 $loops회';
  }

  @override
  String get badgeExplanationLearnVineArchive => 'Vine 아카이브 보존에 대해 더 알아보기';

  @override
  String get badgeExplanationLearnProofmode => 'Proofmode 인증에 대해 더 알아보기';

  @override
  String get badgeExplanationLearnAuthenticity => 'Divine 진본 신호에 대해 더 알아보기';

  @override
  String get badgeExplanationInspectProofCheck => 'ProofCheck 도구로 검사';

  @override
  String get badgeExplanationInspectMedia => '미디어 세부 정보 검사';

  @override
  String get badgeExplanationProofmodeVerified =>
      '이 영상의 진본 여부는 Proofmode 기술로 인증됐어요.';

  @override
  String get badgeExplanationDivineHostedHumanMade =>
      '이 영상은 Divine에 호스팅되어 있으며 AI 감지 결과 사람이 만들었을 가능성이 높아요. 단, 암호학적 카메라 인증 데이터는 포함되어 있지 않아요.';

  @override
  String get badgeExplanationHumanMadeNoCrypto =>
      'AI 감지 결과 이 영상은 사람이 만들었을 가능성이 높은데, 암호학적 카메라 인증 데이터는 포함되어 있지 않아요.';

  @override
  String get badgeExplanationDivineHostedNoCrypto =>
      '이 영상은 Divine에 호스팅되어 있지만 아직 암호학적 카메라 인증 데이터가 포함되어 있지 않아요.';

  @override
  String get badgeExplanationExternalNoCrypto =>
      '이 영상은 Divine 외부에 호스팅되어 있으며 암호학적 카메라 인증 데이터가 포함되어 있지 않아요.';

  @override
  String get badgeExplanationDeviceAttestation => '기기 증명';

  @override
  String get badgeExplanationPgpSignature => 'PGP 서명';

  @override
  String get badgeExplanationC2paCredentials => 'C2PA 콘텐츠 자격 증명';

  @override
  String get badgeExplanationProofManifest => '증명 매니페스트';

  @override
  String get badgeExplanationAiDetection => 'AI 감지';

  @override
  String get badgeExplanationAiNotScanned => 'AI 검사: 아직 검사되지 않음';

  @override
  String get badgeExplanationNoScanResults => '아직 검사 결과가 없어요.';

  @override
  String get badgeExplanationCheckAiGenerated => 'AI 생성 여부 확인';

  @override
  String badgeExplanationAiLikelihood(int percentage) {
    return 'AI 생성 가능성 $percentage%';
  }

  @override
  String badgeExplanationScannedBy(String source) {
    return '검사 주체: $source';
  }

  @override
  String get badgeExplanationVerifiedByModerator => '사람 관리자가 검증했어요';

  @override
  String get badgeExplanationVerificationPlatinum =>
      '플래티널: 기기 하드웨어 증명, 암호학적 서명, 콘텐츠 자격 증명(C2PA), AI 검사가 사람 출처임을 확인했어요.';

  @override
  String get badgeExplanationVerificationGold =>
      '골드: 하드웨어 증명이 있는 실제 기기로 캡처되었고, 암호학적 서명과 콘텐츠 자격 증명(C2PA)이 있어요.';

  @override
  String get badgeExplanationVerificationSilver =>
      '실버: 암호학적 서명이 녹화 이후 이 영상이 변경되지 않았음을 증명해요.';

  @override
  String get badgeExplanationVerificationBronze => '브론즈: 기본 메타데이터 서명이 있어요.';

  @override
  String get badgeExplanationVerificationSilverAiScan =>
      '실버: AI 검사가 이 영상은 사람이 만들었을 가능성이 높다고 확인했어요.';

  @override
  String get badgeExplanationNoVerification => '이 영상에 대한 인증 데이터가 없어요.';

  @override
  String get shareMenuTitle => '영상 공유';

  @override
  String get shareMenuReportAiContent => 'AI 콘텐츠 신고';

  @override
  String get shareMenuReportAiContentSubtitle =>
      'AI로 생성된 것으로 의심되는 콘텐츠를 빠르게 신고해요';

  @override
  String get shareMenuReportingAiContent => 'AI 콘텐츠 신고 중...';

  @override
  String shareMenuFailedToReportContent(String error) {
    return '콘텐츠 신고에 실패했어요: $error';
  }

  @override
  String shareMenuFailedToReportAiContent(String error) {
    return 'AI 콘텐츠 신고에 실패했어요: $error';
  }

  @override
  String get shareMenuVideoStatus => '영상 상태';

  @override
  String get shareMenuViewAllLists => '모든 리스트 보기 →';

  @override
  String get shareMenuShareWith => '공유 대상';

  @override
  String get shareMenuShareViaOtherApps => '다른 앱으로 공유';

  @override
  String get shareMenuShareViaOtherAppsSubtitle => '다른 앱으로 공유하거나 링크 복사';

  @override
  String get shareMenuSaveToGallery => '갤러리에 저장';

  @override
  String get shareMenuSaveOriginalSubtitle => '원본 영상을 카메라 롤에 저장';

  @override
  String get shareMenuSaveWithWatermark => '워터마크와 함께 저장';

  @override
  String get shareMenuSaveVideo => '영상 저장';

  @override
  String get shareMenuDownloadWithWatermark => 'Divine 워터마크로 다운로드';

  @override
  String get shareMenuSaveVideoSubtitle => '영상을 카메라 롤에 저장';

  @override
  String get shareMenuLists => '리스트';

  @override
  String get shareMenuAddToList => '리스트에 추가';

  @override
  String get shareMenuAddToListSubtitle => '내가 정리한 리스트에 추가';

  @override
  String get shareMenuCreateNewList => '새 리스트 만들기';

  @override
  String get shareMenuCreateNewListSubtitle => '새 정리 컴렉션 시작';

  @override
  String get shareMenuRemovedFromList => '리스트에서 제거했어요';

  @override
  String get shareMenuFailedToRemoveFromList => '리스트에서 제거하지 못했어요';

  @override
  String get shareMenuBookmarks => '북마크';

  @override
  String get shareMenuAddToBookmarks => '북마크에 추가';

  @override
  String get shareMenuAddToBookmarksSubtitle => '나중에 보려고 저장';

  @override
  String get shareMenuAddToBookmarkSet => '북마크 세트에 추가';

  @override
  String get shareMenuAddToBookmarkSetSubtitle => '컴렉션으로 정리';

  @override
  String get shareMenuFollowSets => '팔로우 세트';

  @override
  String get shareMenuCreateFollowSet => '팔로우 세트 만들기';

  @override
  String get shareMenuCreateFollowSetSubtitle => '이 크리에이터로 새 컴렉션 시작';

  @override
  String get shareMenuAddToFollowSet => '팔로우 세트에 추가';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    return '팔로우 세트 $count개 사용 가능';
  }

  @override
  String get shareMenuAddedToBookmarks => '북마크에 추가했어요!';

  @override
  String get shareMenuFailedToAddBookmark => '북마크 추가에 실패했어요';

  @override
  String shareMenuCreatedListAndAddedVideo(String name) {
    return '\"$name\" 리스트를 만들고 영상을 추가했어요';
  }

  @override
  String get shareMenuManageContent => '콘텐츠 관리';

  @override
  String get shareMenuEditVideo => '영상 편집';

  @override
  String get shareMenuEditVideoSubtitle => '제목, 설명, 해시태그 수정';

  @override
  String get shareMenuDeleteVideo => '영상 삭제';

  @override
  String get shareMenuDeleteVideoSubtitle => '이 콘텐츠를 완전히 지워요';

  @override
  String get shareMenuDeleteWarning =>
      '모든 릴레이에 삭제 요청(NIP-09)을 보내요. 일부 릴레이에는 콘텐츠가 남아 있을 수 있어요.';

  @override
  String get shareMenuVideoInTheseLists => '영상이 다음 리스트에 있어요:';

  @override
  String shareMenuVideoCount(int count) {
    return '영상 $count개';
  }

  @override
  String get shareMenuClose => '닫기';

  @override
  String get shareMenuDeleteConfirmation => '이 영상을 정말 삭제할까요?';

  @override
  String get shareMenuCancel => '취소';

  @override
  String get shareMenuDelete => '삭제';

  @override
  String get shareMenuDeletingContent => '콘텐츠 삭제 중...';

  @override
  String shareMenuFailedToDeleteContent(String error) {
    return '콘텐츠 삭제에 실패했어요: $error';
  }

  @override
  String get shareMenuDeleteRequestSent => '삭제 요청을 보냈어요';

  @override
  String get shareMenuDeleteFailedNotInitialized =>
      '삭제 준비가 아직 안 됐어요. 잠시 뒤에 다시 시도해요.';

  @override
  String get shareMenuDeleteFailedNotOwner => '내가 올린 영상만 삭제할 수 있어요.';

  @override
  String get shareMenuDeleteFailedNotAuthenticated => '다시 로그인한 뒤 삭제를 시도해요.';

  @override
  String get shareMenuDeleteFailedCouldNotSign => '삭제 요청에 서명하지 못했어요. 다시 시도해요.';

  @override
  String get shareMenuDeleteFailedRelayRejected =>
      'Couldn\'t reach the relay. Check your connection and try again.';

  @override
  String get shareMenuDeleteFailedGeneric => '이 영상을 삭제하지 못했어요. 다시 시도해요.';

  @override
  String get shareMenuFollowSetName => '팔로우 세트 이름';

  @override
  String get shareMenuFollowSetNameHint => '예: 크리에이터, 뮤지션 등';

  @override
  String get shareMenuDescriptionOptional => '설명 (선택)';

  @override
  String get shareMenuCreate => '만들기';

  @override
  String shareMenuCreatedFollowSetAndAddedCreator(String name) {
    return '\"$name\" 팔로우 세트를 만들고 크리에이터를 추가했어요';
  }

  @override
  String get shareMenuDone => '완료';

  @override
  String get shareMenuEditTitle => '제목';

  @override
  String get shareMenuEditTitleHint => '영상 제목 입력';

  @override
  String get shareMenuEditDescription => '설명';

  @override
  String get shareMenuEditDescriptionHint => '영상 설명 입력';

  @override
  String get shareMenuEditHashtags => '해시태그';

  @override
  String get shareMenuEditHashtagsHint => '쉼표로, 구분된, 해시태그';

  @override
  String get shareMenuEditMetadataNote =>
      '참고: 메타데이터만 수정할 수 있어요. 영상 콘텐츠는 변경할 수 없어요.';

  @override
  String get shareMenuDeleting => '삭제 중...';

  @override
  String get shareMenuUpdate => '업데이트';

  @override
  String get shareMenuVideoUpdated => '영상을 업데이트했어요';

  @override
  String shareMenuFailedToUpdateVideo(String error) {
    return '영상 업데이트에 실패했어요: $error';
  }

  @override
  String shareMenuFailedToDeleteVideo(String error) {
    return '영상 삭제에 실패했어요: $error';
  }

  @override
  String get shareMenuDeleteVideoQuestion => '영상을 삭제할까요?';

  @override
  String get shareMenuDeleteRelayWarning =>
      '릴레이에 삭제 요청을 보내요. 참고: 일부 릴레이에는 캐시된 사본이 남아 있을 수 있어요.';

  @override
  String get shareMenuVideoDeletionRequested => '영상 삭제를 요청했어요';

  @override
  String get shareMenuContentLabels => '콘텐츠 라벨';

  @override
  String get shareMenuAddContentLabels => '콘텐츠 라벨 추가';

  @override
  String get shareMenuClearAll => '모두 지우기';

  @override
  String get shareMenuCollaborators => '콜라보레이터';

  @override
  String get shareMenuAddCollaborator => '콜라보레이터 추가';

  @override
  String shareMenuMutualFollowRequired(String name) {
    return '$name님을 콜라보레이터로 추가하려면 서로 팔로우해야 해요.';
  }

  @override
  String get shareMenuLoading => '불러오는 중...';

  @override
  String get shareMenuInspiredBy => '영감';

  @override
  String get shareMenuAddInspirationCredit => '영감 크레딧 추가';

  @override
  String get shareMenuCreatorCannotBeReferenced => '이 크리에이터는 참조할 수 없어요.';

  @override
  String get shareMenuUnknown => '알 수 없음';

  @override
  String get shareMenuCreateBookmarkSet => '북마크 세트 만들기';

  @override
  String get shareMenuSetName => '세트 이름';

  @override
  String get shareMenuSetNameHint => '예: 즐겨찾기, 나중에 보기 등';

  @override
  String get shareMenuCreateNewSet => '새 세트 만들기';

  @override
  String get shareMenuStartNewBookmarkCollection => '새 북마크 컴렉션 시작';

  @override
  String get shareMenuNoBookmarkSets => '아직 북마크 세트가 없어요. 첫 세트를 만들어보세요!';

  @override
  String get shareMenuError => '오류';

  @override
  String get shareMenuFailedToLoadBookmarkSets => '북마크 세트를 불러오지 못했어요';

  @override
  String shareMenuCreatedSetAndAddedVideo(String name) {
    return '\"$name\"을(를) 만들고 영상을 추가했어요';
  }

  @override
  String get shareMenuUseThisSound => '이 사운드 쓰기';

  @override
  String get shareMenuOriginalSound => '오리지널 사운드';

  @override
  String get authSessionExpired => '세션이 만료됐어요. 다시 로그인해주세요.';

  @override
  String get authSignInFailed => '로그인에 실패했어요. 다시 시도해주세요.';

  @override
  String get localeAppLanguage => '앱 언어';

  @override
  String get localeDeviceDefault => '기기 기본값';

  @override
  String get localeSelectLanguage => '언어 선택';

  @override
  String get webAuthNotSupportedSecureMode =>
      '보안 모드에서는 웹 인증을 지원하지 않아요. 안전한 키 관리를 위해 모바일 앱을 이용해주세요.';

  @override
  String webAuthIntegrationFailed(String error) {
    return '인증 연동에 실패했어요: $error';
  }

  @override
  String webAuthUnexpectedError(String error) {
    return '예상치 못한 오류가 발생했어요: $error';
  }

  @override
  String get webAuthEnterBunkerUri => 'Bunker URI를 입력해주세요';

  @override
  String get webAuthConnectTitle => 'Divine에 연결';

  @override
  String get webAuthChooseMethod => '원하는 Nostr 인증 방법을 고르세요';

  @override
  String get webAuthBrowserExtension => '브라우저 확장';

  @override
  String get webAuthRecommended => '추천';

  @override
  String get webAuthNsecBunker => 'nsec bunker';

  @override
  String get webAuthConnectRemoteSigner => '원격 서명자에 연결';

  @override
  String get webAuthBunkerHint => 'bunker://pubkey?relay=wss://...';

  @override
  String get webAuthPasteFromClipboard => '클립보드에서 붙여넣기';

  @override
  String get webAuthConnectToBunker => 'Bunker에 연결';

  @override
  String get webAuthNewToNostr => 'Nostr가 처음이세요?';

  @override
  String get webAuthNostrHelp =>
      '가장 쉽게 쓰는 방법은 Alby나 nos2x 같은 브라우저 확장을 설치하거나, 안전한 원격 서명을 위해 nsec bunker를 쓰는 거예요.';

  @override
  String get soundsTitle => '사운드';

  @override
  String get soundsSearchHint => '사운드 검색...';

  @override
  String get soundsPreviewUnavailable => '사운드를 미리 들을 수 없어요 - 오디오가 없어요';

  @override
  String soundsPreviewFailed(String error) {
    return '미리 듣기를 재생하지 못했어요: $error';
  }

  @override
  String get soundsFeaturedSounds => '추천 사운드';

  @override
  String get soundsTrendingSounds => '인기 사운드';

  @override
  String get soundsAllSounds => '모든 사운드';

  @override
  String get soundsSearchResults => '검색 결과';

  @override
  String get soundsNoSoundsAvailable => '사용할 수 있는 사운드가 없어요';

  @override
  String get soundsNoSoundsDescription => '크리에이터가 오디오를 공유하면 여기에 사운드가 표시돼요';

  @override
  String get soundsNoSoundsFound => '사운드를 찾을 수 없어요';

  @override
  String get soundsNoSoundsFoundDescription => '다른 검색어로 시도해 보세요';

  @override
  String get soundsFailedToLoad => '사운드를 불러오지 못했어요';

  @override
  String get soundsRetry => '다시 시도';

  @override
  String get soundsScreenLabel => '사운드 화면';

  @override
  String get profileTitle => '프로필';

  @override
  String get profileRefresh => '새로고침';

  @override
  String get profileRefreshLabel => '프로필 새로고침';

  @override
  String get profileMoreOptions => '더 보기';

  @override
  String profileBlockedUser(String name) {
    return '$name님을 차단했어요';
  }

  @override
  String profileUnblockedUser(String name) {
    return '$name님 차단을 해제했어요';
  }

  @override
  String profileUnfollowedUser(String name) {
    return '$name님 팔로우를 해제했어요';
  }

  @override
  String profileError(String error) {
    return '오류: $error';
  }

  @override
  String get notificationsTabAll => '전체';

  @override
  String get notificationsTabLikes => '좋아요';

  @override
  String get notificationsTabComments => '댓글';

  @override
  String get notificationsTabFollows => '팔로우';

  @override
  String get notificationsTabReposts => '리포스트';

  @override
  String get notificationsFailedToLoad => '알림을 불러오지 못했어요';

  @override
  String get notificationsRetry => '다시 시도';

  @override
  String get notificationsCheckingNew => '새 알림을 확인하는 중';

  @override
  String get notificationsNoneYet => '아직 알림이 없어요';

  @override
  String notificationsNoneForType(String type) {
    return '$type 알림이 없어요';
  }

  @override
  String get notificationsEmptyDescription => '다른 사람들이 내 콘텐츠에 반응하면 여기에 표시돼요';

  @override
  String notificationsLoadingType(String type) {
    return '$type 알림을 불러오는 중...';
  }

  @override
  String get notificationsInviteSingular => '친구와 공유할 수 있는 초대장이 1개 있어요!';

  @override
  String notificationsInvitePlural(int count) {
    return '친구들과 공유할 수 있는 초대장이 $count개 있어요!';
  }

  @override
  String get notificationsVideoNotFound => '영상을 찾을 수 없어요';

  @override
  String get notificationsVideoUnavailable => '영상을 사용할 수 없어요';

  @override
  String get notificationsFromNotification => '알림에서';

  @override
  String get feedFailedToLoadVideos => '영상을 불러오지 못했어요';

  @override
  String get feedRetry => '다시 시도';

  @override
  String get feedNoFollowedUsers => '팔로우한 사용자가 없어요.\n누군가를 팔로우하면 여기에 영상이 표시돼요.';

  @override
  String get feedForYouEmpty =>
      '추천 피드가 비어 있어요.\n동영상을 탐색하고 크리에이터를 팔로우해 피드를 만들어보세요.';

  @override
  String get feedFollowingEmpty =>
      '아직 팔로우한 사람들의 동영상이 없어요.\n마음에 드는 크리에이터를 찾아 팔로우해 보세요.';

  @override
  String get feedLatestEmpty => '아직 새로운 동영상이 없어요.\n잠시 후 다시 확인해 주세요.';

  @override
  String get feedExploreVideos => '영상 둘러보기';

  @override
  String get feedExternalVideoSlow => '외부 영상 로딩이 느려요';

  @override
  String get feedSkip => '건너뛰기';

  @override
  String get uploadWaitingToUpload => '업로드 대기 중';

  @override
  String get uploadUploadingVideo => '영상 업로드 중';

  @override
  String get uploadProcessingVideo => '영상 처리 중';

  @override
  String get uploadProcessingComplete => '처리 완료';

  @override
  String get uploadPublishedSuccessfully => '성공적으로 게시했어요';

  @override
  String get uploadFailed => '업로드 실패';

  @override
  String get uploadRetrying => '업로드 재시도 중';

  @override
  String get uploadPaused => '업로드 일시 중지';

  @override
  String uploadPercentComplete(int percent) {
    return '$percent% 완료';
  }

  @override
  String get uploadQueuedMessage => '영상이 업로드 대기열에 있어요';

  @override
  String get uploadUploadingMessage => '서버에 업로드 중...';

  @override
  String get uploadProcessingMessage => '영상을 처리하는 중 - 몇 분이 걸릴 수 있어요';

  @override
  String get uploadReadyToPublishMessage => '영상을 성공적으로 처리했고 게시할 준비가 됐어요';

  @override
  String get uploadPublishedMessage => '프로필에 영상을 게시했어요';

  @override
  String get uploadFailedMessage => '업로드에 실패했어요 - 다시 시도해 주세요';

  @override
  String get uploadRetryingMessage => '업로드를 다시 시도하는 중...';

  @override
  String get uploadPausedMessage => '사용자가 업로드를 일시 중지했어요';

  @override
  String get uploadRetryButton => '다시 시도';

  @override
  String uploadRetryFailed(String error) {
    return '업로드 재시도에 실패했어요: $error';
  }

  @override
  String get userSearchPrompt => '사용자 검색';

  @override
  String get userSearchNoResults => '사용자를 찾을 수 없어요';

  @override
  String get userSearchFailed => '검색에 실패했어요';

  @override
  String get userPickerSearchByName => '이름으로 검색';

  @override
  String get userPickerFilterByNameHint => '이름으로 필터링...';

  @override
  String get userPickerSearchByNameHint => '이름으로 검색...';

  @override
  String userPickerAlreadyAddedSemantics(String name) {
    return '$name 이미 추가됨';
  }

  @override
  String userPickerSelectSemantics(String name) {
    return '$name 선택';
  }

  @override
  String get userPickerEmptyFollowListTitle => '네 크루는 밖에 있어';

  @override
  String get userPickerEmptyFollowListBody =>
      '잘 맞는 사람들을 팔로우해 보세요. 서로 팔로우하면 함께 협업할 수 있어요.';

  @override
  String get userPickerGoBack => '뒤로 가기';

  @override
  String get userPickerTypeNameToSearch => '검색할 이름을 입력하세요';

  @override
  String get userPickerUnavailable => '사용자 검색을 사용할 수 없습니다. 나중에 다시 시도해 주세요.';

  @override
  String get userPickerSearchFailedTryAgain => '검색에 실패했어요. 다시 시도해 주세요.';

  @override
  String get forgotPasswordTitle => '비밀번호 재설정';

  @override
  String get forgotPasswordDescription => '이메일 주소를 입력하면 비밀번호 재설정 링크를 보내드려요.';

  @override
  String get forgotPasswordEmailLabel => '이메일 주소';

  @override
  String get forgotPasswordCancel => '취소';

  @override
  String get forgotPasswordSendLink => '재설정 링크 이메일 보내기';

  @override
  String get ageVerificationContentWarning => '콘텐츠 경고';

  @override
  String get ageVerificationTitle => '연령 확인';

  @override
  String get ageVerificationAdultDescription =>
      '이 콘텐츠는 성인용 자료를 포함할 가능성이 있어 플래그가 지정됐어요. 시청하려면 만 18세 이상이어야 해요.';

  @override
  String get ageVerificationCreationDescription =>
      '카메라를 사용하고 콘텐츠를 만들려면 만 16세 이상이어야 해요.';

  @override
  String get ageVerificationAdultQuestion => '만 18세 이상이신가요?';

  @override
  String get ageVerificationCreationQuestion => '만 16세 이상이신가요?';

  @override
  String get ageVerificationNo => '아니요';

  @override
  String get ageVerificationYes => '네';

  @override
  String get shareLinkCopied => '링크를 클립보드에 복사했어요';

  @override
  String get shareFailedToCopy => '링크 복사에 실패했어요';

  @override
  String get shareVideoSubject => 'Divine에서 이 영상을 확인해 보세요';

  @override
  String get shareFailedToShare => '공유에 실패했어요';

  @override
  String get shareVideoTitle => '영상 공유';

  @override
  String get shareToApps => '앱으로 공유';

  @override
  String get shareToAppsSubtitle => '메시지, 소셜 앱으로 공유해요';

  @override
  String get shareCopyWebLink => '웹 링크 복사';

  @override
  String get shareCopyWebLinkSubtitle => '공유 가능한 웹 링크를 복사해요';

  @override
  String get shareCopyNostrLink => 'Nostr 링크 복사';

  @override
  String get shareCopyNostrLinkSubtitle => 'Nostr 클라이언트용 nevent 링크를 복사해요';

  @override
  String get navHome => '홈';

  @override
  String get navExplore => '둘러보기';

  @override
  String get navInbox => '받은편지함';

  @override
  String get navProfile => '프로필';

  @override
  String get navSearch => '검색';

  @override
  String get navSearchTooltip => '검색';

  @override
  String get navMyProfile => '내 프로필';

  @override
  String get navNotifications => '알림';

  @override
  String get navOpenCamera => '카메라 열기';

  @override
  String get navUnknown => '알 수 없음';

  @override
  String get navExploreClassics => '클래식';

  @override
  String get navExploreNewVideos => '새 영상';

  @override
  String get navExploreTrending => '인기';

  @override
  String get navExploreForYou => '추천';

  @override
  String get navExploreLists => '목록';

  @override
  String get routeErrorTitle => '오류';

  @override
  String get routeInvalidHashtag => '잘못된 해시태그예요';

  @override
  String get routeInvalidConversationId => '잘못된 대화 ID예요';

  @override
  String get routeInvalidRequestId => '잘못된 요청 ID예요';

  @override
  String get routeInvalidListId => '잘못된 목록 ID예요';

  @override
  String get routeInvalidUserId => '잘못된 사용자 ID예요';

  @override
  String get routeInvalidVideoId => '잘못된 영상 ID예요';

  @override
  String get routeInvalidSoundId => '잘못된 사운드 ID예요';

  @override
  String get routeInvalidCategory => '잘못된 카테고리예요';

  @override
  String get routeNoVideosToDisplay => '표시할 영상이 없어요';

  @override
  String get routeInvalidProfileId => '잘못된 프로필 ID예요';

  @override
  String get routeDefaultListName => '목록';

  @override
  String get supportTitle => '지원 센터';

  @override
  String get supportContactSupport => '지원팀 문의';

  @override
  String get supportContactSupportSubtitle => '대화를 시작하거나 이전 메시지를 확인해요';

  @override
  String get supportReportBug => '버그 신고';

  @override
  String get supportReportBugSubtitle => '앱의 기술적 문제';

  @override
  String get supportRequestFeature => '기능 요청';

  @override
  String get supportRequestFeatureSubtitle => '개선이나 새로운 기능을 제안해요';

  @override
  String get supportSaveLogs => '로그 저장';

  @override
  String get supportSaveLogsSubtitle => '수동 전송을 위해 로그를 파일로 내보내요';

  @override
  String get supportFaq => '자주 묻는 질문';

  @override
  String get supportFaqSubtitle => '일반적인 질문과 답변';

  @override
  String get supportProofMode => 'Proofmode';

  @override
  String get supportProofModeSubtitle => '검증과 진위 확인에 대해 알아보세요';

  @override
  String get supportLoginRequired => '지원팀에 문의하려면 로그인해 주세요';

  @override
  String get supportExportingLogs => '로그 내보내는 중...';

  @override
  String get supportExportLogsFailed => '로그 내보내기에 실패했어요';

  @override
  String get supportChatNotAvailable => '지원 채팅을 사용할 수 없어요';

  @override
  String get supportCouldNotOpenMessages => '지원 메시지를 열 수 없어요';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return '$pageName을(를) 열 수 없어요';
  }

  @override
  String supportErrorOpeningPage(String pageName, Object error) {
    return '$pageName을(를) 여는 중 오류 발생: $error';
  }

  @override
  String get reportTitle => '콘텐츠 신고';

  @override
  String get reportWhyReporting => '이 콘텐츠를 왜 신고하시나요?';

  @override
  String get reportPolicyNotice =>
      'Divine은 24시간 이내에 신고된 콘텐츠를 조치하여 콘텐츠를 삭제하고 문제가 된 콘텐츠를 제공한 사용자를 퇴출해요.';

  @override
  String get reportAdditionalDetails => '추가 세부 정보 (선택)';

  @override
  String get reportBlockUser => '이 사용자 차단';

  @override
  String get reportCancel => '취소';

  @override
  String get reportSubmit => '신고';

  @override
  String get reportSelectReason => '이 콘텐츠를 신고하는 이유를 선택해 주세요';

  @override
  String get reportReasonSpam => '스팸 또는 원치 않는 콘텐츠';

  @override
  String get reportReasonHarassment => '괴롭힘, 따돌림, 협박';

  @override
  String get reportReasonViolence => '폭력적이거나 극단적인 콘텐츠';

  @override
  String get reportReasonSexualContent => '성적이거나 성인용 콘텐츠';

  @override
  String get reportReasonCopyright => '저작권 침해';

  @override
  String get reportReasonFalseInfo => '허위 정보';

  @override
  String get reportReasonCsam => '아동 안전 위반';

  @override
  String get reportReasonAiGenerated => 'AI 생성 콘텐츠';

  @override
  String get reportReasonOther => '기타 정책 위반';

  @override
  String reportFailed(Object error) {
    return '콘텐츠 신고에 실패했어요: $error';
  }

  @override
  String get reportReceivedTitle => '신고 접수 완료';

  @override
  String get reportReceivedThankYou => 'Divine을 안전하게 지키는 데 도움을 주셔서 감사해요.';

  @override
  String get reportReceivedReviewNotice =>
      '저희 팀이 신고를 검토하고 적절한 조치를 취할 거예요. 다이렉트 메시지로 업데이트를 받을 수 있어요.';

  @override
  String get reportLearnMore => '더 알아보기';

  @override
  String get reportSafetyUrl => 'divine.video/safety';

  @override
  String get reportClose => '닫기';

  @override
  String get listAddToList => '목록에 추가';

  @override
  String listVideoCount(int count) {
    return '영상 $count개';
  }

  @override
  String get listNewList => '새 목록';

  @override
  String get listDone => '완료';

  @override
  String get listErrorLoading => '목록을 불러오는 중 오류 발생';

  @override
  String listRemovedFrom(String name) {
    return '$name에서 삭제했어요';
  }

  @override
  String listAddedTo(String name) {
    return '$name에 추가했어요';
  }

  @override
  String get listCreateNewList => '새 목록 만들기';

  @override
  String get listNameLabel => '목록 이름';

  @override
  String get listDescriptionLabel => '설명 (선택)';

  @override
  String get listPublicList => '공개 목록';

  @override
  String get listPublicListSubtitle => '다른 사람들이 이 목록을 팔로우하고 볼 수 있어요';

  @override
  String get listCancel => '취소';

  @override
  String get listCreate => '만들기';

  @override
  String get listCreateFailed => '목록 만들기에 실패했어요';

  @override
  String get keyManagementTitle => 'Nostr 키';

  @override
  String get keyManagementWhatAreKeys => 'Nostr 키란 무엇인가요?';

  @override
  String get keyManagementExplanation =>
      'Nostr 신원은 암호학적 키 쌍이에요:\n\n• 공개 키(npub)는 사용자 이름 같아요 - 자유롭게 공유하세요\n• 개인 키(nsec)는 비밀번호 같아요 - 비밀로 유지하세요!\n\nnsec으로 어떤 Nostr 앱에서든 계정에 접근할 수 있어요.';

  @override
  String get keyManagementImportTitle => '기존 키 가져오기';

  @override
  String get keyManagementImportSubtitle =>
      '이미 Nostr 계정이 있으신가요? 여기에서 접근하려면 개인 키(nsec)를 붙여넣으세요.';

  @override
  String get keyManagementImportButton => '키 가져오기';

  @override
  String get keyManagementImportWarning => '현재 키가 대체돼요!';

  @override
  String get keyManagementBackupTitle => '키 백업';

  @override
  String get keyManagementBackupSubtitle =>
      '다른 Nostr 앱에서 계정을 사용하려면 개인 키(nsec)를 저장해요.';

  @override
  String get keyManagementCopyNsec => '내 개인 키(nsec) 복사';

  @override
  String get keyManagementNeverShare => 'nsec을 절대 다른 사람과 공유하지 마세요!';

  @override
  String get keyManagementPasteKey => '개인 키를 붙여넣어 주세요';

  @override
  String get keyManagementInvalidFormat => '잘못된 키 형식이에요. \"nsec1\"로 시작해야 해요';

  @override
  String get keyManagementConfirmImportTitle => '이 키를 가져올까요?';

  @override
  String get keyManagementConfirmImportBody =>
      '현재 신원이 가져온 신원으로 대체돼요.\n\n먼저 백업하지 않으면 현재 키를 잃을 수 있어요.';

  @override
  String get keyManagementImportConfirm => '가져오기';

  @override
  String get keyManagementImportSuccess => '키를 성공적으로 가져왔어요!';

  @override
  String keyManagementImportFailed(Object error) {
    return '키 가져오기에 실패했어요: $error';
  }

  @override
  String get keyManagementExportSuccess =>
      '개인 키를 클립보드에 복사했어요!\n\n안전한 곳에 보관하세요.';

  @override
  String keyManagementExportFailed(Object error) {
    return '키 내보내기에 실패했어요: $error';
  }

  @override
  String get saveOriginalSavedToCameraRoll => '카메라 롤에 저장했어요';

  @override
  String get saveOriginalShare => '공유';

  @override
  String get saveOriginalDone => '완료';

  @override
  String get saveOriginalPhotosAccessNeeded => '사진 접근 권한이 필요해요';

  @override
  String get saveOriginalPhotosAccessMessage =>
      '영상을 저장하려면 설정에서 사진 접근을 허용해 주세요.';

  @override
  String get saveOriginalOpenSettings => '설정 열기';

  @override
  String get saveOriginalNotNow => '나중에';

  @override
  String get cameraPermissionNotNow => '나중에';

  @override
  String get saveOriginalDownloadFailed => '다운로드 실패';

  @override
  String get saveOriginalDismiss => '닫기';

  @override
  String get saveOriginalDownloadingVideo => '영상 다운로드 중';

  @override
  String get saveOriginalSavingToCameraRoll => '카메라 롤에 저장 중';

  @override
  String get saveOriginalFetchingVideo => '네트워크에서 영상을 가져오는 중...';

  @override
  String get saveOriginalSavingVideo => '원본 영상을 카메라 롤에 저장하는 중...';

  @override
  String get soundTitle => '사운드';

  @override
  String get soundOriginalSound => '원본 사운드';

  @override
  String get soundVideosUsingThisSound => '이 사운드를 사용하는 영상';

  @override
  String get soundSourceVideo => '원본 영상';

  @override
  String get soundNoVideosYet => '아직 영상이 없어요';

  @override
  String get soundBeFirstToUse => '이 사운드를 처음으로 사용해 보세요!';

  @override
  String get soundFailedToLoadVideos => '영상을 불러오지 못했어요';

  @override
  String get soundRetry => '다시 시도';

  @override
  String get soundVideosUnavailable => '영상을 사용할 수 없어요';

  @override
  String get soundCouldNotLoadDetails => '영상 세부 정보를 불러올 수 없어요';

  @override
  String get soundPreview => '미리 듣기';

  @override
  String get soundStop => '정지';

  @override
  String get soundUseSound => '사운드 사용';

  @override
  String get soundNoVideoCount => '아직 영상이 없어요';

  @override
  String get soundOneVideo => '영상 1개';

  @override
  String soundVideoCount(int count) {
    return '영상 $count개';
  }

  @override
  String get soundUnableToPreview => '사운드를 미리 들을 수 없어요 - 오디오가 없어요';

  @override
  String soundPreviewFailed(Object error) {
    return '미리 듣기를 재생하지 못했어요: $error';
  }

  @override
  String get soundViewSource => '원본 보기';

  @override
  String get soundCloseTooltip => '닫기';

  @override
  String get exploreNotExploreRoute => '둘러보기 경로가 아니에요';

  @override
  String get legalTitle => '법적 고지';

  @override
  String get legalTermsOfService => '서비스 약관';

  @override
  String get legalTermsOfServiceSubtitle => '사용 약관과 조건';

  @override
  String get legalPrivacyPolicy => '개인정보 처리방침';

  @override
  String get legalPrivacyPolicySubtitle => '데이터 처리 방식';

  @override
  String get legalSafetyStandards => '안전 기준';

  @override
  String get legalSafetyStandardsSubtitle => '커뮤니티 가이드라인과 안전';

  @override
  String get legalDmca => 'DMCA';

  @override
  String get legalDmcaSubtitle => '저작권 및 삭제 정책';

  @override
  String get legalOpenSourceLicenses => '오픈 소스 라이선스';

  @override
  String get legalOpenSourceLicensesSubtitle => '서드파티 패키지 저작자 표시';

  @override
  String get legalAppName => 'Divine';

  @override
  String legalCouldNotOpenPage(String pageName) {
    return '$pageName을(를) 열 수 없어요';
  }

  @override
  String legalErrorOpeningPage(String pageName, Object error) {
    return '$pageName을(를) 여는 중 오류 발생: $error';
  }

  @override
  String get categoryAction => '액션';

  @override
  String get categoryAdventure => '모험';

  @override
  String get categoryAnimals => '동물';

  @override
  String get categoryAnimation => '애니메이션';

  @override
  String get categoryArchitecture => '건축';

  @override
  String get categoryArt => '예술';

  @override
  String get categoryAutomotive => '자동차';

  @override
  String get categoryAwardShow => '시상식';

  @override
  String get categoryAwards => '수상';

  @override
  String get categoryBaseball => '야구';

  @override
  String get categoryBasketball => '농구';

  @override
  String get categoryBeauty => '뷰티';

  @override
  String get categoryBeverage => '음료';

  @override
  String get categoryCars => '자동차';

  @override
  String get categoryCelebration => '축하';

  @override
  String get categoryCelebrities => '연예인';

  @override
  String get categoryCelebrity => '셀럽';

  @override
  String get categoryCityscape => '도시 풍경';

  @override
  String get categoryComedy => '코미디';

  @override
  String get categoryConcert => '콘서트';

  @override
  String get categoryCooking => '요리';

  @override
  String get categoryCostume => '코스튬';

  @override
  String get categoryCrafts => '공예';

  @override
  String get categoryCrime => '범죄';

  @override
  String get categoryCulture => '문화';

  @override
  String get categoryDance => '댄스';

  @override
  String get categoryDiy => 'DIY';

  @override
  String get categoryDrama => '드라마';

  @override
  String get categoryEducation => '교육';

  @override
  String get categoryEmotional => '감동';

  @override
  String get categoryEmotions => '감정';

  @override
  String get categoryEntertainment => '엔터테인먼트';

  @override
  String get categoryEvent => '이벤트';

  @override
  String get categoryFamily => '가족';

  @override
  String get categoryFans => '팬';

  @override
  String get categoryFantasy => '판타지';

  @override
  String get categoryFashion => '패션';

  @override
  String get categoryFestival => '축제';

  @override
  String get categoryFilm => '영화';

  @override
  String get categoryFitness => '피트니스';

  @override
  String get categoryFood => '음식';

  @override
  String get categoryFootball => '미식축구';

  @override
  String get categoryFurniture => '가구';

  @override
  String get categoryGaming => '게임';

  @override
  String get categoryGolf => '골프';

  @override
  String get categoryGrooming => '그루밍';

  @override
  String get categoryGuitar => '기타';

  @override
  String get categoryHalloween => '할로윈';

  @override
  String get categoryHealth => '건강';

  @override
  String get categoryHockey => '하키';

  @override
  String get categoryHoliday => '휴일';

  @override
  String get categoryHome => '홈';

  @override
  String get categoryHomeImprovement => '홈 리모델링';

  @override
  String get categoryHorror => '호러';

  @override
  String get categoryHospital => '병원';

  @override
  String get categoryHumor => '유머';

  @override
  String get categoryInteriorDesign => '인테리어';

  @override
  String get categoryInterview => '인터뷰';

  @override
  String get categoryKids => '키즈';

  @override
  String get categoryLifestyle => '라이프스타일';

  @override
  String get categoryMagic => '마술';

  @override
  String get categoryMakeup => '메이크업';

  @override
  String get categoryMedical => '의료';

  @override
  String get categoryMusic => '음악';

  @override
  String get categoryMystery => '미스터리';

  @override
  String get categoryNature => '자연';

  @override
  String get categoryNews => '뉴스';

  @override
  String get categoryOutdoor => '아웃도어';

  @override
  String get categoryParty => '파티';

  @override
  String get categoryPeople => '사람';

  @override
  String get categoryPerformance => '공연';

  @override
  String get categoryPets => '반려동물';

  @override
  String get categoryPolitics => '정치';

  @override
  String get categoryPrank => '장난';

  @override
  String get categoryPranks => '몰카';

  @override
  String get categoryRealityShow => '리얼리티 쇼';

  @override
  String get categoryRelationship => '관계';

  @override
  String get categoryRelationships => '인간관계';

  @override
  String get categoryRomance => '로맨스';

  @override
  String get categorySchool => '학교';

  @override
  String get categoryScienceFiction => 'SF';

  @override
  String get categorySelfie => '셀카';

  @override
  String get categoryShopping => '쇼핑';

  @override
  String get categorySkateboarding => '스케이트보드';

  @override
  String get categorySkincare => '스킨케어';

  @override
  String get categorySoccer => '축구';

  @override
  String get categorySocialGathering => '모임';

  @override
  String get categorySocialMedia => '소셜 미디어';

  @override
  String get categorySports => '스포츠';

  @override
  String get categoryTalkShow => '토크쇼';

  @override
  String get categoryTech => '테크';

  @override
  String get categoryTechnology => '기술';

  @override
  String get categoryTelevision => 'TV';

  @override
  String get categoryToys => '장난감';

  @override
  String get categoryTransportation => '교통';

  @override
  String get categoryTravel => '여행';

  @override
  String get categoryUrban => '도시';

  @override
  String get categoryViolence => '폭력';

  @override
  String get categoryVlog => '브이로그';

  @override
  String get categoryVlogging => '브이로깅';

  @override
  String get categoryWrestling => '레슬링';

  @override
  String get profileSetupUploadSuccess => '프로필 사진이 성공적으로 업로드되었어요!';

  @override
  String inboxReportedUser(String displayName) {
    return '$displayName을(를) 신고했어요';
  }

  @override
  String inboxBlockedUser(String displayName) {
    return '$displayName을(를) 차단했어요';
  }

  @override
  String inboxUnblockedUser(String displayName) {
    return '$displayName의 차단을 해제했어요';
  }

  @override
  String get inboxRemovedConversation => '대화를 삭제했어요';

  @override
  String get inboxEmptyTitle => '아직 메시지가 없어요';

  @override
  String get inboxEmptySubtitle => '+ 버튼, 물지 않아요.';

  @override
  String get inboxActionMute => '대화 알림 끄기';

  @override
  String inboxActionReport(String displayName) {
    return '$displayName 신고';
  }

  @override
  String inboxActionBlock(String displayName) {
    return '$displayName 차단';
  }

  @override
  String inboxActionUnblock(String displayName) {
    return '$displayName 차단 해제';
  }

  @override
  String get inboxActionRemove => '대화 삭제';

  @override
  String get inboxRemoveConfirmTitle => '대화를 삭제할까요?';

  @override
  String inboxRemoveConfirmBody(String displayName) {
    return '$displayName와의 대화가 삭제돼요. 이 작업은 되돌릴 수 없어요.';
  }

  @override
  String get inboxRemoveConfirmConfirm => '삭제';

  @override
  String get inboxConversationMuted => '대화 알림을 껐어요';

  @override
  String get inboxConversationUnmuted => '대화 알림을 다시 켰어요';

  @override
  String get reportDialogCancel => '취소';

  @override
  String get reportDialogReport => '신고';

  @override
  String exploreVideoId(String id) {
    return 'ID: $id';
  }

  @override
  String exploreVideoTitle(String title) {
    return '제목: $title';
  }

  @override
  String exploreVideoCounter(int current, int total) {
    return '동영상 $current/$total';
  }

  @override
  String discoverListsFailedToUpdateSubscription(String error) {
    return '구독 업데이트에 실패했어요: $error';
  }

  @override
  String get commonRetry => '다시 시도';

  @override
  String get commonNext => '다음';

  @override
  String get commonDelete => '삭제';

  @override
  String get commonCancel => '취소';

  @override
  String get videoMetadataTags => '태그';

  @override
  String get videoMetadataExpiration => '만료';

  @override
  String get videoMetadataExpirationNotExpire => '만료되지 않음';

  @override
  String get videoMetadataExpirationOneDay => '1일';

  @override
  String get videoMetadataExpirationOneWeek => '1주';

  @override
  String get videoMetadataExpirationOneMonth => '1개월';

  @override
  String get videoMetadataExpirationOneYear => '1년';

  @override
  String get videoMetadataExpirationOneDecade => '10년';

  @override
  String get videoMetadataContentWarnings => '콘텐츠 경고';

  @override
  String get videoEditorStickers => '스티커';

  @override
  String get trendingTitle => '트렌딩';

  @override
  String get proofmodeCheckAiGenerated => 'AI 생성 여부 확인';

  @override
  String get libraryDeleteConfirm => '삭제';

  @override
  String get libraryWebUnavailableHeadline => '라이브러리는 모바일 앱에서 이용할 수 있어요';

  @override
  String get libraryWebUnavailableDescription =>
      '임시 저장과 클립은 기기에 저장됩니다. 관리하려면 휴대폰에서 Divine을 열어 주세요.';

  @override
  String get libraryTabDrafts => '임시 저장';

  @override
  String get libraryTabClips => '클립';

  @override
  String get librarySaveToCameraRollTooltip => '카메라 롤에 저장';

  @override
  String get libraryDeleteSelectedClipsTooltip => '선택한 클립 삭제';

  @override
  String get libraryDeleteClipsTitle => '클립 삭제';

  @override
  String libraryDeleteClipsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개',
      one: '1개',
    );
    return '선택한 클립 $_temp0를 삭제할까요?';
  }

  @override
  String get libraryDeleteClipsWarning => '되돌릴 수 없어요. 동영상 파일이 기기에서 삭제됩니다.';

  @override
  String get libraryPreparingVideo => '동영상 준비 중...';

  @override
  String get libraryCreateVideo => '동영상 만들기';

  @override
  String libraryClipsSavedToDestination(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$destination에 클립 $count개 저장됨',
      one: '$destination에 클립 1개 저장됨',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsSavePartialResult(int successCount, int failureCount) {
    return '$successCount개 저장, $failureCount개 실패';
  }

  @override
  String libraryGalleryPermissionDenied(String destination) {
    return '$destination 권한이 거부되었어요';
  }

  @override
  String libraryClipsDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '클립 $count개 삭제됨',
      one: '클립 1개 삭제됨',
    );
    return '$_temp0';
  }

  @override
  String get libraryCouldNotLoadDrafts => '임시 저장 영상을 불러올 수 없어요';

  @override
  String get libraryCouldNotLoadClips => '클립을 불러올 수 없어요';

  @override
  String get libraryOpenErrorDescription => '라이브러리를 열 때 문제가 생겼어요. 다시 시도해 주세요.';

  @override
  String get libraryNoDraftsYetTitle => '아직 임시 저장이 없어요';

  @override
  String get libraryNoDraftsYetSubtitle => '임시 저장으로 저장한 동영상이 여기에 표시됩니다';

  @override
  String get libraryNoClipsYetTitle => '아직 클립이 없어요';

  @override
  String get libraryNoClipsYetSubtitle => '녹화한 클립이 여기에 표시됩니다';

  @override
  String get libraryDraftDeletedSnackbar => '임시 저장을 삭제했어요';

  @override
  String get libraryDraftDeleteFailedSnackbar => '임시 저장을 삭제하지 못했어요';

  @override
  String get libraryDraftActionPost => '게시';

  @override
  String get libraryDraftActionEdit => '편집';

  @override
  String get libraryDraftActionDelete => '임시 저장 삭제';

  @override
  String get libraryDeleteDraftTitle => '임시 저장 삭제';

  @override
  String libraryDeleteDraftMessage(String title) {
    return '“$title”을(를) 삭제할까요?';
  }

  @override
  String get libraryDeleteClipTitle => '클립 삭제';

  @override
  String get libraryDeleteClipMessage => '이 클립을 삭제할까요?';

  @override
  String get libraryClipSelectionTitle => '클립';

  @override
  String librarySecondsRemaining(String seconds) {
    return '$seconds초 남음';
  }

  @override
  String get libraryAddClips => '추가';

  @override
  String get libraryRecordVideo => '동영상 녹화';

  @override
  String get routerInvalidCreator => '유효하지 않은 크리에이터';

  @override
  String get routerInvalidHashtagRoute => '유효하지 않은 해시태그 경로';

  @override
  String get categoryGalleryCouldNotLoadVideos => '동영상을 불러올 수 없었어요';

  @override
  String get categoriesCouldNotLoadCategories => '카테고리를 불러올 수 없었어요';

  @override
  String get notificationFollowBack => '맞팔로우';

  @override
  String get followingFailedToLoadList => '팔로잉 목록을 불러오지 못했어요';

  @override
  String get followersFailedToLoadList => '팔로워 목록을 불러오지 못했어요';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String blossomFailedToSaveSettings(String error) {
    return '설정 저장에 실패했어요: $error';
  }

  @override
  String get blueskyFailedToUpdateCrosspost => '크로스포스트 설정 업데이트에 실패했어요';

  @override
  String get invitesTitle => '친구 초대';

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
  String get searchSomethingWentWrong => '문제가 발생했어요';

  @override
  String get searchTryAgain => '다시 시도';

  @override
  String get searchForLists => '목록 검색';

  @override
  String get searchFindCuratedVideoLists => '큐레이션된 동영상 목록 찾기';

  @override
  String get searchEnterQuery => '검색어를 입력하세요';

  @override
  String get searchDiscoverSomethingInteresting => '흥미로운 것을 발견해보세요';

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
  String get searchListsSectionHeader => '목록';

  @override
  String get searchListsLoadingLabel => '목록 결과 불러오는 중';

  @override
  String get cameraAgeRestriction => '콘텐츠를 만들려면 16세 이상이어야 해요';

  @override
  String get featureRequestCancel => '취소';

  @override
  String keyImportError(String error) {
    return '오류: $error';
  }

  @override
  String get timeNow => '지금';

  @override
  String timeShortMinutes(int count) {
    return '$count분';
  }

  @override
  String timeShortHours(int count) {
    return '$count시간';
  }

  @override
  String timeShortDays(int count) {
    return '$count일';
  }

  @override
  String timeShortWeeks(int count) {
    return '$count주';
  }

  @override
  String timeShortMonths(int count) {
    return '$count개월';
  }

  @override
  String timeShortYears(int count) {
    return '$count년';
  }

  @override
  String get timeVerboseNow => '지금';

  @override
  String timeAgo(String time) {
    return '$time 전';
  }

  @override
  String get timeToday => '오늘';

  @override
  String get timeYesterday => '어제';

  @override
  String get timeJustNow => '방금';

  @override
  String timeMinutesAgo(int count) {
    return '$count분 전';
  }

  @override
  String timeHoursAgo(int count) {
    return '$count시간 전';
  }

  @override
  String timeDaysAgo(int count) {
    return '$count일 전';
  }

  @override
  String get draftTimeJustNow => '방금';

  @override
  String get contentLabelNudity => '노출';

  @override
  String get contentLabelSexualContent => '성적 콘텐츠';

  @override
  String get contentLabelPornography => '포르노';

  @override
  String get contentLabelGraphicMedia => '자극적인 미디어';

  @override
  String get contentLabelViolence => '폭력';

  @override
  String get contentLabelSelfHarm => '자해/자살';

  @override
  String get contentLabelDrugUse => '약물 사용';

  @override
  String get contentLabelAlcohol => '음주';

  @override
  String get contentLabelTobacco => '담배/흡연';

  @override
  String get contentLabelGambling => '도박';

  @override
  String get contentLabelProfanity => '욕설';

  @override
  String get contentLabelHateSpeech => '혐오 발언';

  @override
  String get contentLabelHarassment => '괴롭힘';

  @override
  String get contentLabelFlashingLights => '번쩍이는 빛';

  @override
  String get contentLabelAiGenerated => 'AI 생성';

  @override
  String get contentLabelDeepfake => '딥페이크';

  @override
  String get contentLabelSpam => '스팸';

  @override
  String get contentLabelScam => '사기/사기';

  @override
  String get contentLabelSpoiler => '스포일러';

  @override
  String get contentLabelMisleading => '오해의 소지';

  @override
  String get contentLabelSensitiveContent => '민감한 콘텐츠';

  @override
  String notificationLikedYourVideo(String actorName) {
    return '$actorName님이 회원님의 동영상을 좋아해요';
  }

  @override
  String notificationCommentedOnYourVideo(String actorName) {
    return '$actorName님이 회원님의 동영상에 댓글을 남겼어요';
  }

  @override
  String notificationStartedFollowing(String actorName) {
    return '$actorName님이 회원님을 팔로우하기 시작했어요';
  }

  @override
  String notificationMentionedYou(String actorName) {
    return '$actorName님이 회원님을 언급했어요';
  }

  @override
  String notificationRepostedYourVideo(String actorName) {
    return '$actorName님이 회원님의 동영상을 리포스트했어요';
  }

  @override
  String get draftUntitled => '제목 없음';

  @override
  String get contentWarningNone => '없음';

  @override
  String get textBackgroundNone => '없음';

  @override
  String get textBackgroundSolid => '불투명';

  @override
  String get textBackgroundHighlight => '하이라이트';

  @override
  String get textBackgroundTransparent => '투명';

  @override
  String get textAlignLeft => '왼쪽';

  @override
  String get textAlignRight => '오른쪽';

  @override
  String get textAlignCenter => '가운데';

  @override
  String get cameraPermissionWebUnsupportedTitle => '카메라는 아직 웹에서 지원되지 않습니다';

  @override
  String get cameraPermissionWebUnsupportedDescription =>
      '카메라 촬영 및 녹화는 웹 버전에서 아직 사용할 수 없습니다.';

  @override
  String get cameraPermissionBackToFeed => '피드로 돌아가기';

  @override
  String get cameraPermissionErrorTitle => '권한 오류';

  @override
  String get cameraPermissionErrorDescription => '권한을 확인하는 중 문제가 발생했습니다.';

  @override
  String get cameraPermissionRetry => '다시 시도';

  @override
  String get cameraPermissionAllowAccessTitle => '카메라 및 마이크 접근 허용';

  @override
  String get cameraPermissionAllowAccessDescription =>
      '이렇게 하면 앱에서 바로 동영상을 촬영하고 편집할 수 있으며, 그 외 용도는 없습니다.';

  @override
  String get cameraPermissionContinue => '계속';

  @override
  String get cameraPermissionGoToSettings => '설정으로 이동';

  @override
  String get videoRecorderWhySixSecondsTitle => '왜 6초인가요?';

  @override
  String get videoRecorderWhySixSecondsSubtitle =>
      '짧은 클립은 자발성을 위한 공간을 만듭니다. 6초 형식은 순간이 일어나는 그대로 진정성 있는 순간을 포착하는 데 도움이 됩니다.';

  @override
  String get videoRecorderWhySixSecondsButton => '알겠어요!';

  @override
  String get videoRecorderAutosaveFoundTitle => '작업 중인 항목을 찾았습니다';

  @override
  String get videoRecorderAutosaveFoundSubtitle => '중단한 부분에서 계속하시겠어요?';

  @override
  String get videoRecorderAutosaveContinueButton => '네, 계속하기';

  @override
  String get videoRecorderAutosaveDiscardButton => '아니요, 새 동영상 시작';

  @override
  String get videoRecorderAutosaveRestoreFailure => '임시저장을 복원할 수 없습니다';

  @override
  String get videoRecorderStopRecordingTooltip => '녹화 중지';

  @override
  String get videoRecorderStartRecordingTooltip => '녹화 시작';

  @override
  String get videoRecorderRecordingTapToStopLabel => '녹화 중. 아무 곳이나 탭하여 중지';

  @override
  String get videoRecorderTapToStartLabel => '아무 곳이나 탭하여 녹화 시작';

  @override
  String get videoRecorderDeleteLastClipLabel => '마지막 클립 삭제';

  @override
  String get videoRecorderSwitchCameraLabel => '카메라 전환';

  @override
  String get videoRecorderToggleGridLabel => '그리드 전환';

  @override
  String get videoRecorderToggleGhostFrameLabel => '고스트 프레임 전환';

  @override
  String get videoRecorderGhostFrameEnabled => '고스트 프레임 활성화됨';

  @override
  String get videoRecorderGhostFrameDisabled => '고스트 프레임 비활성화됨';

  @override
  String get videoRecorderClipDeletedMessage => '클립이 삭제되었습니다';

  @override
  String get videoRecorderCloseLabel => '동영상 녹화기 닫기';

  @override
  String get videoRecorderContinueToEditorLabel => '동영상 편집기로 계속';

  @override
  String get videoRecorderCaptureCloseLabel => '닫기';

  @override
  String get videoRecorderCaptureNextLabel => '다음';

  @override
  String get videoRecorderToggleFlashLabel => '플래시 전환';

  @override
  String get videoRecorderCycleTimerLabel => '타이머 전환';

  @override
  String get videoRecorderToggleAspectRatioLabel => '화면 비율 전환';

  @override
  String get videoRecorderLibraryEmptyLabel => '클립 보관함, 클립 없음';

  @override
  String videoRecorderLibraryOpenLabel(int clipCount) {
    String _temp0 = intl.Intl.pluralLogic(
      clipCount,
      locale: localeName,
      other: '클립 보관함 열기, $clipCount개 클립',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorCameraLabel => '카메라';

  @override
  String get videoEditorOpenCameraSemanticLabel => '카메라 열기';

  @override
  String get videoEditorLibraryLabel => '라이브러리';

  @override
  String get videoEditorTextLabel => '텍스트';

  @override
  String get videoEditorDrawLabel => '그리기';

  @override
  String get videoEditorFilterLabel => '필터';

  @override
  String get videoEditorAudioLabel => '오디오';

  @override
  String get videoEditorVolumeLabel => '볼륨';

  @override
  String get videoEditorAddTitle => '추가';

  @override
  String get videoEditorOpenLibrarySemanticLabel => '라이브러리 열기';

  @override
  String get videoEditorOpenAudioSemanticLabel => '오디오 편집기 열기';

  @override
  String get videoEditorOpenTextSemanticLabel => '텍스트 편집기 열기';

  @override
  String get videoEditorOpenDrawSemanticLabel => '그리기 편집기 열기';

  @override
  String get videoEditorOpenFilterSemanticLabel => '필터 편집기 열기';

  @override
  String get videoEditorSaveDraftTitle => '임시저장 하시겠어요?';

  @override
  String get videoEditorSaveDraftSubtitle => '편집 내용을 나중에 저장하거나, 버리고 편집기를 나갑니다.';

  @override
  String get videoEditorSaveDraftButton => '임시저장';

  @override
  String get videoEditorDiscardChangesButton => '변경사항 버리기';

  @override
  String get videoEditorKeepEditingButton => '계속 편집';

  @override
  String get videoEditorDeleteLayerDropZone => '레이어 삭제 드롭 영역';

  @override
  String get videoEditorReleaseToDeleteLayer => '놓아서 레이어 삭제';

  @override
  String get videoEditorDoneLabel => '완료';

  @override
  String get videoEditorPlayPauseSemanticLabel => '동영상 재생 또는 일시 정지';

  @override
  String get videoEditorCropSemanticLabel => '자르기';

  @override
  String get videoEditorCannotSplitProcessing =>
      '처리 중에는 클립을 분할할 수 없습니다. 잠시 기다려 주세요.';

  @override
  String videoEditorSplitPositionInvalid(int minDurationMs) {
    return '분할 위치가 유효하지 않습니다. 각 클립은 최소 ${minDurationMs}ms 이상이어야 합니다.';
  }

  @override
  String get videoEditorAddClipFromLibrary => '보관함에서 클립 추가';

  @override
  String get videoEditorSaveSelectedClip => '선택한 클립 저장';

  @override
  String get videoEditorSplitClip => '클립 분할';

  @override
  String get videoEditorSaveClip => '클립 저장';

  @override
  String get videoEditorDeleteClip => '클립 삭제';

  @override
  String get videoEditorClipSavedSuccess => '클립이 보관함에 저장되었습니다';

  @override
  String get videoEditorClipSaveFailed => '클립 저장 실패';

  @override
  String get videoEditorClipDeleted => '클립이 삭제되었습니다';

  @override
  String get videoEditorColorPickerSemanticLabel => '색상 선택기';

  @override
  String get videoEditorUndoSemanticLabel => '실행 취소';

  @override
  String get videoEditorRedoSemanticLabel => '다시 실행';

  @override
  String get videoEditorTextColorSemanticLabel => '텍스트 색상';

  @override
  String get videoEditorTextAlignmentSemanticLabel => '텍스트 정렬';

  @override
  String get videoEditorTextBackgroundSemanticLabel => '텍스트 배경';

  @override
  String get videoEditorFontSemanticLabel => '폰트';

  @override
  String get videoEditorNoStickersFound => '스티커를 찾을 수 없음';

  @override
  String get videoEditorNoStickersAvailable => '사용 가능한 스티커 없음';

  @override
  String get videoEditorFailedLoadStickers => '스티커 로드 실패';

  @override
  String get videoEditorAdjustVolumeTitle => '볼륨 조정';

  @override
  String get videoEditorRecordedAudioLabel => '녹음된 오디오';

  @override
  String get videoEditorCustomAudioLabel => '커스텀 오디오';

  @override
  String get videoEditorPlaySemanticLabel => '재생';

  @override
  String get videoEditorPauseSemanticLabel => '일시 정지';

  @override
  String get videoEditorMuteAudioSemanticLabel => '오디오 음소거';

  @override
  String get videoEditorUnmuteAudioSemanticLabel => '오디오 음소거 해제';

  @override
  String get videoEditorDeleteLabel => '삭제';

  @override
  String get videoEditorDeleteSelectedItemSemanticLabel => '선택한 항목 삭제';

  @override
  String get videoEditorEditLabel => '편집';

  @override
  String get videoEditorEditSelectedItemSemanticLabel => '선택한 항목 편집';

  @override
  String get videoEditorDuplicateLabel => '복제';

  @override
  String get videoEditorDuplicateSelectedItemSemanticLabel => '선택한 항목 복제';

  @override
  String get videoEditorSplitLabel => '분할';

  @override
  String get videoEditorSplitSelectedClipSemanticLabel => '선택한 클립 분할';

  @override
  String get videoEditorFinishTimelineEditingSemanticLabel => '타임라인 편집 완료';

  @override
  String get videoEditorAudioPlayPreviewSemanticLabel => '미리보기 재생';

  @override
  String get videoEditorAudioPausePreviewSemanticLabel => '미리보기 일시 정지';

  @override
  String get videoEditorAudioUntitledSound => '제목 없는 사운드';

  @override
  String get videoEditorAudioUntitled => '제목 없음';

  @override
  String get videoEditorAudioAddAudio => '오디오 추가';

  @override
  String get videoEditorAudioNoSoundsAvailableTitle => '사용 가능한 사운드 없음';

  @override
  String get videoEditorAudioNoSoundsAvailableSubtitle =>
      '크리에이터가 오디오를 공유하면 여기에 표시됩니다';

  @override
  String get videoEditorAudioFailedToLoadTitle => '사운드 로드 실패';

  @override
  String get videoEditorAudioSegmentInstruction => '동영상에 사용할 오디오 구간을 선택하세요';

  @override
  String get videoEditorAudioCategoryDivine => 'diVine';

  @override
  String get videoEditorAudioCategoryCommunity => '커뮤니티';

  @override
  String get videoEditorDrawToolArrowSemanticLabel => '화살표 도구';

  @override
  String get videoEditorDrawToolEraserSemanticLabel => '지우개 도구';

  @override
  String get videoEditorDrawToolMarkerSemanticLabel => '마커 도구';

  @override
  String get videoEditorDrawToolPencilSemanticLabel => '연필 도구';

  @override
  String videoEditorLayerReorderLabel(int index) {
    return '레이어 $index 순서 변경';
  }

  @override
  String get videoEditorLayerReorderHint => '길게 눌러 순서 변경';

  @override
  String get videoEditorShowTimelineSemanticLabel => '타임라인 표시';

  @override
  String get videoEditorHideTimelineSemanticLabel => '타임라인 숨기기';

  @override
  String get videoEditorFeedPreviewContent => '이 영역 뒤에 콘텐츠를 배치하지 마세요.';

  @override
  String get videoEditorStickerSearchHint => '스티커 검색...';

  @override
  String get videoEditorSelectFontSemanticLabel => '폰트 선택';

  @override
  String get videoEditorFontUnknown => '알 수 없음';

  @override
  String get videoEditorSplitPlayheadOutsideClip =>
      '분할하려면 재생 헤드가 선택한 클립 안에 있어야 합니다.';

  @override
  String get videoEditorTimelineTrimStartSemanticLabel => '시작 트림';

  @override
  String get videoEditorTimelineTrimEndSemanticLabel => '끝 트림';

  @override
  String get videoEditorTimelineTrimClipSemanticLabel => '클립 트림';

  @override
  String get videoEditorTimelineTrimClipHint => '핸들을 드래그하여 클립 길이 조정';

  @override
  String videoEditorTimelineDraggingClipSemanticLabel(int index) {
    return '클립 $index 드래그 중';
  }

  @override
  String videoEditorTimelineClipSemanticLabel(
    int index,
    int total,
    String duration,
  ) {
    return '클립 $total개 중 $index번째, $duration초';
  }

  @override
  String get videoEditorTimelineClipReorderHint => '길게 눌러 순서 변경';

  @override
  String get videoEditorClipGalleryInstruction =>
      '탭해서 편집하세요. 길게 누르고 드래그해 순서를 바꾸세요.';

  @override
  String get videoEditorTimelineClipMoveLeft => '왼쪽으로 이동';

  @override
  String get videoEditorTimelineClipMoveRight => '오른쪽으로 이동';

  @override
  String get videoEditorTimelineLongPressToDragHint => '길게 눌러 드래그';

  @override
  String get videoEditorVideoTimelineSemanticLabel => '동영상 타임라인';

  @override
  String videoEditorTimelinePositionFormat(int minutes, String seconds) {
    return '$minutes분 $seconds초';
  }

  @override
  String videoEditorColorSelectedSemanticLabel(String colorName) {
    return '$colorName, 선택됨';
  }

  @override
  String get videoEditorCloseColorPickerSemanticLabel => '색상 선택기 닫기';

  @override
  String get videoEditorPickColorTitle => '색상 선택';

  @override
  String get videoEditorConfirmColorSemanticLabel => '색상 확인';

  @override
  String get videoEditorSaturationBrightnessSemanticLabel => '채도 및 밝기';

  @override
  String videoEditorSaturationBrightnessValue(int saturation, int brightness) {
    return '채도 $saturation%, 밝기 $brightness%';
  }

  @override
  String get videoEditorHueSemanticLabel => '색조';

  @override
  String get videoEditorAddElementSemanticLabel => '요소 추가';

  @override
  String get videoEditorCloseSemanticLabel => '닫기';

  @override
  String get videoEditorDoneSemanticLabel => '완료';

  @override
  String get videoEditorLevelSemanticLabel => '레벨';

  @override
  String get videoMetadataBackSemanticLabel => '뒤로';

  @override
  String get videoMetadataDismissHelpDialogSemanticLabel => '도움말 대화상자 닫기';

  @override
  String get videoMetadataGotItButton => '알겠어요!';

  @override
  String get videoMetadataLimitReachedWarning =>
      '64KB 제한에 도달했습니다. 계속하려면 일부 콘텐츠를 삭제하세요.';

  @override
  String get videoMetadataExpirationLabel => '만료';

  @override
  String get videoMetadataSelectExpirationSemanticLabel => '만료 시간 선택';

  @override
  String get videoMetadataTitleLabel => '제목';

  @override
  String get videoMetadataDescriptionLabel => '설명';

  @override
  String get videoMetadataTagsLabel => '태그';

  @override
  String get videoMetadataDeleteTagSemanticLabel => '삭제';

  @override
  String videoMetadataDeleteTagHint(String tag) {
    return '태그 $tag 삭제';
  }

  @override
  String get videoMetadataContentWarningLabel => '콘텐츠 경고';

  @override
  String get videoMetadataSelectContentWarningsSemanticLabel => '콘텐츠 경고 선택';

  @override
  String get videoMetadataContentWarningSelectAllThatApply =>
      '콘텐츠에 해당하는 것을 모두 선택';

  @override
  String get videoMetadataContentWarningDoneButton => '완료';

  @override
  String get videoMetadataCollaboratorsLabel => '협업자';

  @override
  String get videoMetadataAddCollaboratorSemanticLabel => '협업자 추가';

  @override
  String get videoMetadataCollaboratorsHelpTooltip => '협업자 작동 방식';

  @override
  String videoMetadataCollaboratorsCount(int count, int max) {
    return '$count/$max명의 협업자';
  }

  @override
  String get videoMetadataRemoveCollaboratorSemanticLabel => '협업자 삭제';

  @override
  String get videoMetadataCollaboratorsHelpMessage =>
      '협업자는 이 게시물의 공동 크리에이터로 태그됩니다. 서로 팔로우하는 사람만 추가할 수 있으며, 게시 시 게시물 메타데이터에 표시됩니다.';

  @override
  String get videoMetadataMutualFollowersSearchText => '맞팔 팔로워';

  @override
  String videoMetadataMustMutuallyFollowSnackbar(String name) {
    return '$name을(를) 협업자로 추가하려면 서로 팔로우해야 합니다.';
  }

  @override
  String get videoMetadataInspiredByLabel => '영감 출처';

  @override
  String get videoMetadataSetInspiredBySemanticLabel => '영감 출처 설정';

  @override
  String get videoMetadataInspiredByHelpTooltip => '영감 크레딧 작동 방식';

  @override
  String get videoMetadataInspiredByNone => '없음';

  @override
  String get videoMetadataInspiredByHelpMessage =>
      '출처 표시를 위해 사용하세요. 영감 크레딧은 협업자와 다릅니다. 영향을 인정하지만 공동 크리에이터로 태그하지는 않습니다.';

  @override
  String get videoMetadataCreatorCannotBeReferencedSnackbar =>
      '이 크리에이터는 참조할 수 없습니다.';

  @override
  String get videoMetadataRemoveInspiredBySemanticLabel => '영감 출처 삭제';

  @override
  String get videoMetadataPostDetailsTitle => '게시물 세부 정보';

  @override
  String get videoMetadataSavedToLibrarySnackbar => '보관함에 저장되었습니다';

  @override
  String get videoMetadataFailedToSaveSnackbar => '저장 실패';

  @override
  String get videoMetadataGoToLibraryButton => '보관함으로 이동';

  @override
  String get videoMetadataSaveForLaterSemanticLabel => '나중에 저장 버튼';

  @override
  String get videoMetadataRenderingVideoHint => '동영상 렌더링 중...';

  @override
  String get videoMetadataSavingVideoHint => '동영상 저장 중...';

  @override
  String videoMetadataSaveToDraftsHint(String destination) {
    return '동영상을 임시저장 및 $destination에 저장';
  }

  @override
  String get videoMetadataSaveForLaterButton => '나중에 저장';

  @override
  String get videoMetadataPostSemanticLabel => '게시 버튼';

  @override
  String get videoMetadataPublishVideoHint => '피드에 동영상 게시';

  @override
  String get videoMetadataFormNotReadyHint => '활성화하려면 양식을 작성하세요';

  @override
  String get videoMetadataPostButton => '게시';

  @override
  String get videoMetadataOpenPreviewSemanticLabel => '게시물 미리보기 화면 열기';

  @override
  String get videoMetadataShareTitle => '공유';

  @override
  String get videoMetadataVideoDetailsSubtitle => '동영상 세부 정보';

  @override
  String get videoMetadataClassicDoneButton => '완료';

  @override
  String get videoMetadataPlayPreviewSemanticLabel => '미리보기 재생';

  @override
  String get videoMetadataPausePreviewSemanticLabel => '미리보기 일시 정지';

  @override
  String get videoMetadataClosePreviewSemanticLabel => '동영상 미리보기 닫기';

  @override
  String get videoMetadataRemoveSemanticLabel => '삭제';

  @override
  String get metadataCaptionsLabel => '자막';

  @override
  String get metadataCaptionsEnabledSemantics => '모든 동영상에서 자막이 활성화되었습니다';

  @override
  String get metadataCaptionsDisabledSemantics => '모든 동영상에서 자막이 비활성화되었습니다';

  @override
  String get fullscreenFeedRemovedMessage => '동영상이 삭제됐어요';
}
