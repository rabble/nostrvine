// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get feedTuningMoreLabel => 'もっと見たい';

  @override
  String get feedTuningLessLabel => 'あまり見たくない';

  @override
  String get feedTuningUndo => '元に戻す';

  @override
  String get dmMessageBubbleVideoReplyHint => '参照先の動画を開く';

  @override
  String get appTitle => 'Divine';

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsSecureAccount => 'アカウントを守る';

  @override
  String get settingsSessionExpired => 'セッション切れちゃった';

  @override
  String get settingsSessionExpiredSubtitle => 'もう一回サインインして、フルアクセスを取り戻そう';

  @override
  String get settingsCreatorAnalytics => 'クリエイター分析';

  @override
  String get settingsSupportCenter => 'サポート';

  @override
  String get settingsNotifications => '通知';

  @override
  String get settingsContentPreferences => 'コンテンツ設定';

  @override
  String get settingsModerationControls => 'モデレーション設定';

  @override
  String get settingsBlueskyPublishing => 'Bluesky 公開';

  @override
  String get settingsBlueskyPublishingSubtitle => 'Bluesky へのクロス投稿を管理';

  @override
  String get settingsNostrSettings => 'Nostr 設定';

  @override
  String get settingsIntegratedApps => '連携アプリ';

  @override
  String get settingsIntegratedAppsSubtitle => 'Divine で使える承認済みサードパーティアプリ';

  @override
  String get settingsExperimentalFeatures => '実験的機能';

  @override
  String get settingsExperimentalFeaturesSubtitle => 'バグるかもしれないけど、気になったら試してみて。';

  @override
  String get settingsLegal => '法的情報';

  @override
  String get settingsIntegrationPermissions => '連携の権限';

  @override
  String get settingsIntegrationPermissionsSubtitle => '記憶された連携の承認を確認・取り消しできるよ';

  @override
  String settingsVersion(String version) {
    return 'バージョン $version';
  }

  @override
  String get settingsVersionEmpty => 'バージョン';

  @override
  String get settingsDeveloperModeAlreadyEnabled => '開発者モードはもう有効だよ';

  @override
  String get settingsDeveloperModeEnabled => '開発者モード、オン！';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    return 'あと$count回タップで開発者モードが開くよ';
  }

  @override
  String get settingsInvites => '招待';

  @override
  String get settingsSwitchAccount => 'アカウントを切り替え';

  @override
  String get settingsAddAnotherAccount => '別のアカウントを追加';

  @override
  String get settingsUnsavedDraftsTitle => '未保存の下書きがあるよ';

  @override
  String settingsUnsavedDraftsMessage(int count) {
    return '未保存の下書きが$count件あるよ。切り替えても下書きは残るけど、先に公開か確認しておくのがおすすめ。';
  }

  @override
  String get settingsCancel => 'キャンセル';

  @override
  String get settingsSwitchAnyway => 'それでも切り替える';

  @override
  String get settingsAppVersionLabel => 'アプリのバージョン';

  @override
  String get settingsAppLanguage => 'アプリの言語';

  @override
  String settingsAppLanguageDeviceDefault(String language) {
    return '$language (デバイスの既定)';
  }

  @override
  String get settingsAppLanguageTitle => 'アプリの言語';

  @override
  String get settingsAppLanguageDescription => 'インターフェースの言語を選んでね';

  @override
  String get settingsAppLanguageUseDeviceLanguage => 'デバイスの言語を使う';

  @override
  String get settingsGeneralTitle => '一般設定';

  @override
  String get settingsContentSafetyTitle => 'コンテンツと安全';

  @override
  String get generalSettingsSectionIntegrations => '連携';

  @override
  String get generalSettingsSectionViewing => '視聴';

  @override
  String get generalSettingsSectionCreating => '作成';

  @override
  String get generalSettingsSectionApp => 'アプリ';

  @override
  String get generalSettingsClosedCaptions => '字幕';

  @override
  String get generalSettingsClosedCaptionsSubtitle => '動画に字幕がある場合に表示するよ';

  @override
  String get generalSettingsVideoShape => '動画の形';

  @override
  String get generalSettingsVideoShapeSquareOnly => '正方形の動画のみ';

  @override
  String get generalSettingsVideoShapeSquareAndPortrait => '正方形と縦型';

  @override
  String get generalSettingsVideoShapeSquareAndPortraitSubtitle =>
      'Divine の動画をフルミックスで表示';

  @override
  String get generalSettingsVideoShapeSquareOnlySubtitle =>
      'クラシックな正方形フォーマットでフィードを保つ';

  @override
  String get contentPreferencesTitle => 'コンテンツ設定';

  @override
  String get contentPreferencesContentFilters => 'コンテンツフィルター';

  @override
  String get contentPreferencesContentFiltersSubtitle => 'コンテンツ警告フィルターを管理';

  @override
  String get contentPreferencesContentLanguage => 'コンテンツの言語';

  @override
  String contentPreferencesContentLanguageDeviceDefault(String language) {
    return '$language (デバイスの既定)';
  }

  @override
  String get contentPreferencesTagYourVideos =>
      '動画に言語タグを付けると、視聴者がコンテンツをフィルターできるよ。';

  @override
  String get contentPreferencesUseDeviceLanguage => 'デバイスの言語を使う (既定)';

  @override
  String get contentPreferencesAudioSharing => '自分の音声を再利用可能にする';

  @override
  String get contentPreferencesAudioSharingSubtitle =>
      'オンにすると、他の人があなたの動画の音声を使えるよ';

  @override
  String get contentPreferencesAccountLabels => 'アカウントラベル';

  @override
  String get contentPreferencesAccountLabelsEmpty => '自分のコンテンツにラベルを付けよう';

  @override
  String get contentPreferencesAccountContentLabels => 'アカウントのコンテンツラベル';

  @override
  String get contentPreferencesClearAll => 'すべてクリア';

  @override
  String get contentPreferencesSelectAllThatApply => 'あなたのアカウントに当てはまるものを全部選んでね';

  @override
  String get contentPreferencesDoneNoLabels => '完了 (ラベルなし)';

  @override
  String contentPreferencesDoneCount(int count) {
    return '完了 ($count件選択)';
  }

  @override
  String get contentPreferencesAudioInputDevice => '音声入力デバイス';

  @override
  String get contentPreferencesAutoRecommended => '自動 (おすすめ)';

  @override
  String get contentPreferencesAutoSelectsBest => '最適なマイクを自動で選ぶよ';

  @override
  String get contentPreferencesSelectAudioInput => '音声入力を選ぶ';

  @override
  String get contentPreferencesUnknownMicrophone => '不明なマイク';

  @override
  String get contentFiltersAdultContent => 'アダルトコンテンツ';

  @override
  String get contentFiltersViolenceGore => '暴力とグロテスク';

  @override
  String get contentFiltersSubstances => '薬物';

  @override
  String get contentFiltersOther => 'その他';

  @override
  String get contentFiltersAgeGateMessage =>
      'アダルトコンテンツのフィルターを使うには、[安全とプライバシー] 設定で年齢を確認してね';

  @override
  String get contentFiltersShow => '表示';

  @override
  String get contentFiltersWarn => '警告';

  @override
  String get contentFiltersFilterOut => 'フィルターで除外';

  @override
  String get profileBlockedAccountNotAvailable => 'このアカウントは見れないよ';

  @override
  String get profileInvalidId => '無効なプロフィール ID';

  @override
  String profileShareText(String displayName, String npub) {
    return 'Divine の $displayName をチェックしてみて!\n\nhttps://divine.video/profile/$npub';
  }

  @override
  String profileShareSubject(String displayName) {
    return 'Divine の $displayName';
  }

  @override
  String profileShareFailed(Object error) {
    return 'プロフィールの共有がうまくいかなかった: $error';
  }

  @override
  String get profileEditProfile => 'プロフィールを編集';

  @override
  String get profileCreatorAnalytics => 'クリエイター分析';

  @override
  String get profileShareProfile => 'プロフィールを共有';

  @override
  String get profileCopyPublicKey => '公開鍵 (npub) をコピー';

  @override
  String get profileGetEmbedCode => '埋め込みコードを取得';

  @override
  String get profilePublicKeyCopied => '公開鍵をコピーしたよ';

  @override
  String get profileEmbedCodeCopied => '埋め込みコードをコピーしたよ';

  @override
  String get profileRefreshTooltip => '更新';

  @override
  String get profileRefreshSemanticLabel => 'プロフィールを更新';

  @override
  String get profileMoreTooltip => 'その他';

  @override
  String get profileMoreSemanticLabel => 'その他のオプション';

  @override
  String get profileAvatarLightboxBarrierLabel => 'アバターを閉じる';

  @override
  String get profileAvatarLightboxCloseSemanticLabel => 'アバタープレビューを閉じる';

  @override
  String get profileFollowingLabel => 'フォロー中';

  @override
  String get profileFollowLabel => 'フォロー';

  @override
  String get profileBlockedLabel => 'ブロック済み';

  @override
  String get profileFollowersLabel => 'フォロワー';

  @override
  String get profileFollowingStatLabel => 'フォロー中';

  @override
  String get profileVideosLabel => '動画';

  @override
  String profileCollaboratorInvitePendingHeadline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'コラボの招待が$count件まだ送信されてないよ',
      one: 'コラボの招待が1件まだ送信されてないよ',
    );
    return '$_temp0';
  }

  @override
  String get profileCollaboratorInvitePendingDetail =>
      '招待はキューに入れておいたよ。ここから再送信してね。';

  @override
  String profileCollaboratorInvitePendingDetailWithTitle(String title) {
    return '「$title」への招待だよ。ここから再送信してね。';
  }

  @override
  String get profileCollaboratorInviteRetryAction => '再送信';

  @override
  String get profileCollaboratorInviteRetryingAction => '再送信中';

  @override
  String get profileCollaboratorInviteRetryUnavailable => '今はコラボ招待の再送信ができないよ。';

  @override
  String profileCollaboratorInviteRetryResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'コラボの招待が$count件まだ送信されてないよ。',
      one: 'コラボの招待が1件まだ送信されてないよ。',
      zero: 'コラボの招待を送信したよ。',
    );
    return '$_temp0';
  }

  @override
  String profileFollowerCountUsers(int count) {
    return '$count人';
  }

  @override
  String profileBlockTitle(String displayName) {
    return '$displayNameをブロックする?';
  }

  @override
  String get profileBlockExplanation => 'ブロックするとこうなるよ:';

  @override
  String get profileBlockBulletHidePosts => 'その人の投稿はフィードに出なくなる。';

  @override
  String get profileBlockBulletCantView =>
      'その人はあなたのプロフィール閲覧、フォロー、投稿の閲覧ができなくなる。';

  @override
  String get profileBlockBulletNoNotify => '相手には通知されないよ。';

  @override
  String get profileBlockBulletYouCanView => 'あなたはその人のプロフィールを引き続き見れるよ。';

  @override
  String profileBlockConfirmButton(String displayName) {
    return '$displayNameをブロック';
  }

  @override
  String get profileCancelButton => 'キャンセル';

  @override
  String get profileLearnMore => 'もっと詳しく';

  @override
  String profileUnblockTitle(String displayName) {
    return '$displayNameのブロックを解除する?';
  }

  @override
  String get profileUnblockExplanation => 'ブロックを解除するとこうなるよ:';

  @override
  String get profileUnblockBulletShowPosts => 'その人の投稿がフィードに表示されるようになる。';

  @override
  String get profileUnblockBulletCanView =>
      'その人はあなたのプロフィール閲覧、フォロー、投稿の閲覧ができるようになる。';

  @override
  String get profileUnblockBulletNoNotify => '相手には通知されないよ。';

  @override
  String get profileLearnMoreAt => '詳しくはこちら: ';

  @override
  String get profileUnblockButton => 'ブロック解除';

  @override
  String profileUnfollowDisplayName(String displayName) {
    return '$displayNameのフォローを解除';
  }

  @override
  String profileBlockDisplayName(String displayName) {
    return '$displayNameをブロック';
  }

  @override
  String profileUnblockDisplayName(String displayName) {
    return '$displayNameのブロックを解除';
  }

  @override
  String profileReportDisplayName(String displayName) {
    return '$displayNameを報告';
  }

  @override
  String profileAddToListDisplayName(String displayName) {
    return '$displayNameをリストに追加';
  }

  @override
  String get profileUserBlockedTitle => 'ブロックしたよ';

  @override
  String get profileUserBlockedContent => 'このユーザーのコンテンツはフィードに出なくなるよ。';

  @override
  String get profileUserBlockedUnblockHint =>
      'いつでもプロフィールか [設定] > [安全] からブロック解除できるよ。';

  @override
  String get profileCloseButton => '閉じる';

  @override
  String get profileNoCollabsTitle => 'コラボ動画はまだないよ';

  @override
  String get profileCollabsOwnEmpty => 'あなたがコラボした動画がここに表示されるよ';

  @override
  String get profileCollabsOtherEmpty => 'この人がコラボした動画がここに表示されるよ';

  @override
  String get profileErrorLoadingCollabs => 'コラボ動画の読み込みに失敗';

  @override
  String get profileNoSavedVideosTitle => '保存した動画はまだないよ';

  @override
  String get profileSavedOwnEmpty => 'シェアシートから動画をブックマークすると、ここに出るよ。';

  @override
  String get profileErrorLoadingSaved => '保存した動画の読み込みに失敗';

  @override
  String get profileNoCommentsOwnTitle => 'コメントはまだないよ';

  @override
  String get profileNoCommentsOtherTitle => 'コメントなし';

  @override
  String get profileCommentsOwnEmpty => 'あなたのコメントと返信がここに出るよ';

  @override
  String get profileCommentsOtherEmpty => 'この人のコメントと返信がここに出るよ';

  @override
  String get profileErrorLoadingComments => 'コメントの読み込みに失敗';

  @override
  String get profileVideoRepliesSection => '動画の返信';

  @override
  String get profileCommentsSection => 'コメント';

  @override
  String get profileEditLabel => '編集';

  @override
  String get profileLibraryLabel => 'ライブラリ';

  @override
  String get profileNoLikedVideosTitle => 'いいねした動画はまだないよ';

  @override
  String get profileLikedOwnEmpty => 'あなたがいいねした動画がここに出るよ';

  @override
  String get profileLikedOtherEmpty => 'この人がいいねした動画がここに出るよ';

  @override
  String get profileErrorLoadingLiked => 'いいね動画の読み込みに失敗';

  @override
  String get profileNoRepostsTitle => 'リポストはまだないよ';

  @override
  String get profileRepostsOwnEmpty => 'あなたがリポストした動画がここに出るよ';

  @override
  String get profileRepostsOtherEmpty => 'この人がリポストした動画がここに出るよ';

  @override
  String get profileErrorLoadingReposts => 'リポスト動画の読み込みに失敗';

  @override
  String get profileNoVideosTitle => '動画はまだないよ';

  @override
  String get profileNoVideosOwnSubtitle => '最初の動画を投稿してここに表示しよう';

  @override
  String get profileNoVideosOtherSubtitle => 'このユーザーはまだ動画を投稿してないよ';

  @override
  String profileVideoThumbnailLabel(int number) {
    return '動画サムネイル $number';
  }

  @override
  String get profileShowMore => 'もっと見る';

  @override
  String get profileShowLess => '閉じる';

  @override
  String get profileCompleteYourProfile => 'プロフィールを完成させよう';

  @override
  String get profileCompleteSubtitle => '名前、自己紹介、画像を追加して始めよう';

  @override
  String get profileSetUpButton => '設定する';

  @override
  String get profileVerifyingEmail => 'メールを確認中...';

  @override
  String profileCheckEmailVerification(String email) {
    return '$email に届いた認証リンクを確認してね';
  }

  @override
  String get profileWaitingForVerification => 'メール認証を待ってるよ';

  @override
  String get profileVerificationFailed => '認証がうまくいかなかった';

  @override
  String get profilePleaseTryAgain => 'もう一回試してみて';

  @override
  String get profileSecureYourAccount => 'アカウントを守ろう';

  @override
  String get profileSecureSubtitle => 'メールとパスワードを追加すれば、どのデバイスからでもアカウントを復元できるよ';

  @override
  String get profileRetryButton => 'もう一回';

  @override
  String get profileRegisterButton => '登録';

  @override
  String get profileSessionExpired => 'セッション切れちゃった';

  @override
  String get profileSignInToRestore => 'もう一回サインインして、フルアクセスを取り戻そう';

  @override
  String get profileSignInButton => 'サインイン';

  @override
  String get profileMaybeLaterLabel => 'あとで';

  @override
  String get profileSecurePrimaryButton => 'メールとパスワードを追加';

  @override
  String get profileCompletePrimaryButton => 'プロフィールを更新';

  @override
  String get profileLoopsLabel => 'ループ';

  @override
  String get profileLikesLabel => 'いいね';

  @override
  String get profileMyLibraryLabel => 'マイライブラリ';

  @override
  String get profileMessageLabel => 'メッセージ';

  @override
  String get profileUserFallback => 'ユーザー';

  @override
  String get profileDismissTooltip => '閉じる';

  @override
  String get profileLinkCopied => 'プロフィールのリンクをコピーしたよ';

  @override
  String get profileSetupEditProfileTitle => 'プロフィールを編集';

  @override
  String get profileSetupBackLabel => '戻る';

  @override
  String get profileSetupAboutNostr => 'Nostr について';

  @override
  String get profileSetupProfilePublished => 'プロフィールを公開したよ！';

  @override
  String get profileSetupCreateNewProfile => '新しいプロフィールを作る?';

  @override
  String get profileSetupNoExistingProfile =>
      'リレーに既存のプロフィールが見つからなかった。公開すると新しいプロフィールが作られるよ。続ける?';

  @override
  String get profileSetupPublishButton => '公開';

  @override
  String get profileSetupUsernameTaken => 'そのユーザー名はたった今取られちゃった。別の名前にしてみて。';

  @override
  String get profileSetupClaimFailed => 'ユーザー名の取得がうまくいかなかった。もう一回試してみて。';

  @override
  String get profileSetupPublishFailed => 'プロフィールの公開がうまくいかなかった。もう一回試してみて。';

  @override
  String get profileSetupNoRelaysConnected =>
      'ネットワークに接続できなかった。接続を確認してもう一回試してみて。';

  @override
  String get profileSetupRetryLabel => '再試行';

  @override
  String get profileSetupDisplayNameLabel => '表示名';

  @override
  String get profileSetupDisplayNameHint => 'みんなに何て呼ばれたい?';

  @override
  String get profileSetupDisplayNameHelper => '好きな名前やラベルを使ってOK。一意じゃなくて大丈夫。';

  @override
  String get profileSetupDisplayNameRequired => '表示名を入力してね';

  @override
  String get profileSetupBioLabel => '自己紹介 (任意)';

  @override
  String get profileSetupBioHint => 'あなたのことを書いてみて...';

  @override
  String get profileSetupWebsiteLabel => 'Website (Optional)';

  @override
  String get profileSetupWebsiteHint => 'https://yoursite.com';

  @override
  String get profileSetupPublicKeyLabel => '公開鍵 (npub)';

  @override
  String get profileSetupUsernameLabel => 'ユーザー名 (任意)';

  @override
  String get profileSetupUsernameHint => 'ユーザー名';

  @override
  String get profileSetupUsernameHelper => 'Divine での固有の ID だよ';

  @override
  String get profileSetupProfileColorLabel => 'プロフィールカラー (任意)';

  @override
  String get profileSetupSaveButton => '保存';

  @override
  String get profileSetupSavingButton => '保存中...';

  @override
  String get profileSetupImageUrlTitle => '画像 URL を追加';

  @override
  String get profileSetupPictureUploaded => 'プロフィール画像をアップロードしたよ！';

  @override
  String get profileSetupImageSelectionFailed =>
      '画像の選択がうまくいかなかった。代わりに下に画像 URL を貼り付けてね。';

  @override
  String get profileSetupImagesTypeGroup => '画像';

  @override
  String profileSetupCameraAccessFailed(Object error) {
    return 'カメラにアクセスできなかった: $error';
  }

  @override
  String get profileSetupGotItButton => '了解！';

  @override
  String get profileSetupUploadFailedGeneric => '画像をアップロードできなかった。あとでもう一度試してみて。';

  @override
  String get profileSetupUploadNetworkError =>
      'ネットワークエラー: ネット接続を確認してもう一回試してみて。';

  @override
  String get profileSetupUploadAuthError => '認証エラー: 一度ログアウトしてもう一回ログインしてみて。';

  @override
  String get profileSetupUploadFileTooLarge =>
      'ファイルが大きすぎる: もっと小さい画像を選んでね (最大 10MB)。';

  @override
  String get profileSetupUploadServerError =>
      '画像をアップロードできなかった。サーバーが一時的に利用できないよ。少し待ってからもう一度試してみて。';

  @override
  String get profileSetupUploadUnsupportedOnWeb =>
      'プロフィール画像のアップロードは、まだWebでは使えないよ。iOSかAndroidのアプリを使うか、画像URLを貼り付けてね。';

  @override
  String get profileSetupBannerSectionTitle => 'バナー';

  @override
  String get profileSetupBannerUploadButton => '写真をアップロード';

  @override
  String get profileSetupBannerClearButton => 'バナーをクリア';

  @override
  String get profileSetupBannerUploadSuccess => 'バナーを更新したよ';

  @override
  String get profileSetupUsernameChecking => '使えるか確認中...';

  @override
  String get profileSetupUsernameAvailable => 'このユーザー名、使えるよ！';

  @override
  String get profileSetupUsernameTakenIndicator => 'このユーザー名はもう使われてる';

  @override
  String get profileSetupUsernameReserved => 'このユーザー名は予約済み';

  @override
  String get profileSetupContactSupport => 'サポートに連絡';

  @override
  String get profileSetupCheckAgain => 'もう一回確認';

  @override
  String get profileSetupUsernameBurned => 'このユーザー名はもう使えないよ';

  @override
  String get profileSetupUsernameInvalidFormat => '使えるのは英数字とハイフンだけだよ';

  @override
  String get profileSetupUsernameInvalidLength => 'ユーザー名は3〜63文字にしてね';

  @override
  String get profileSetupUsernameNetworkError => '使えるか確認できなかった。もう一回試してみて。';

  @override
  String get profileSetupUsernameInvalidFormatGeneric => 'ユーザー名の形式が正しくないよ';

  @override
  String get profileSetupUsernameCheckFailed => '使えるか確認できなかった';

  @override
  String get profileSetupUsernameReservedTitle => '予約済みのユーザー名';

  @override
  String profileSetupUsernameReservedBody(String username) {
    return '$username は予約済みだよ。なぜあなたのものかを教えてね。';
  }

  @override
  String get profileSetupUsernameReservedHint => '例: ブランド名、アーティスト名など。';

  @override
  String get profileSetupUsernameReservedCheckHint =>
      'もうサポートに連絡した? [もう一度確認] をタップして、解放されたか見てみてね。';

  @override
  String get profileSetupSupportRequestSent => 'サポートリクエストを送ったよ！ すぐに連絡するね。';

  @override
  String get profileSetupCouldntOpenEmail =>
      'メールアプリが開けなかった。送信先: names@divine.video';

  @override
  String get profileSetupSendRequest => 'リクエストを送る';

  @override
  String get profileSetupPickColorTitle => '色を選ぼう';

  @override
  String get profileSetupSelectButton => '選択';

  @override
  String get profileSetupUseOwnNip05 => '自分の NIP-05 アドレスを使う';

  @override
  String get profileSetupNip05AddressLabel => 'NIP-05 アドレス';

  @override
  String get profileSetupExternalNip05InvalidFormat =>
      'NIP-05 の形式が正しくないよ (例: name@domain.com)';

  @override
  String get profileSetupExternalNip05DivineDomain =>
      'divine.video の場合は上のユーザー名欄を使ってね';

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
  String get profileSetupProfilePicturePreview => 'プロフィール画像のプレビュー';

  @override
  String get nostrInfoIntroBuiltOn => 'DiVine は Nostr の上に作られてるよ。';

  @override
  String get nostrInfoIntroDescription =>
      ' 検閲に強いオープンなプロトコルで、特定の企業やプラットフォームに縛られずにコミュニケーションできるんだ。 ';

  @override
  String get nostrInfoIntroIdentity => 'Divine にサインアップすると、新しい Nostr ID が作られるよ。';

  @override
  String get nostrInfoOwnership =>
      'Nostr なら自分のコンテンツ、ID、ソーシャルグラフを自分のものにできて、いろんなアプリで使い回せる。選択肢が増えてロックインが減って、もっと健全なソーシャルインターネットになるんだ。';

  @override
  String get nostrInfoLingo => 'Nostr 用語:';

  @override
  String get nostrInfoNpubLabel => 'npub:';

  @override
  String get nostrInfoNpubDescription =>
      ' あなたの公開 Nostr アドレス。共有しても安全で、他の Nostr アプリであなたを見つけたり、フォローしたり、メッセージを送れるようになるよ。';

  @override
  String get nostrInfoNsecLabel => 'nsec:';

  @override
  String get nostrInfoNsecDescription =>
      ' あなたの秘密鍵で、所有権の証明。これで Nostr ID を完全にコントロールできるから、';

  @override
  String get nostrInfoNsecWarning => '絶対に秘密にしておいて！';

  @override
  String get nostrInfoUsernameLabel => 'Nostr ユーザー名:';

  @override
  String get nostrInfoUsernameDescription =>
      ' 人間が読める名前 (例: @name.divine.video) で、npub にリンクしてる。メールアドレスみたいに、Nostr ID を認識・確認しやすくしてくれるよ。';

  @override
  String get nostrInfoLearnMoreAt => 'もっと詳しく: ';

  @override
  String get nostrInfoGotIt => '了解！';

  @override
  String get profileTabRefreshTooltip => '更新';

  @override
  String get videoGridRefreshLabel => 'さらに動画を探し中';

  @override
  String get videoGridOptionsTitle => '動画オプション';

  @override
  String get videoGridEditVideo => '動画を編集';

  @override
  String get videoGridEditVideoSubtitle => 'タイトル、説明、ハッシュタグを更新';

  @override
  String get videoGridDeleteVideo => '動画を削除';

  @override
  String get videoGridDeleteVideoSubtitle => 'このコンテンツを完全に削除する';

  @override
  String get videoGridDeleteConfirmTitle => '動画を削除';

  @override
  String get videoGridDeleteConfirmMessage => 'この動画を本当に削除する?';

  @override
  String get videoGridDeleteConfirmNote =>
      'すべてのリレーに削除リクエスト (NIP-09) を送るよ。一部のリレーではコンテンツが残ることもあるよ。';

  @override
  String get videoGridDeleteCancel => 'キャンセル';

  @override
  String get videoGridDeleteConfirm => '削除';

  @override
  String get videoGridDeletingContent => 'コンテンツを削除中...';

  @override
  String get videoGridDeleteSuccess => '削除リクエストを送ったよ';

  @override
  String videoGridDeleteFailure(Object error) {
    return 'コンテンツの削除がうまくいかなかった: $error';
  }

  @override
  String get exploreTabClassics => 'クラシック';

  @override
  String get exploreTabNew => '新着';

  @override
  String get exploreTabPopular => '人気';

  @override
  String get exploreTabCategories => 'カテゴリ';

  @override
  String get exploreTabForYou => 'おすすめ';

  @override
  String get exploreTabLists => 'リスト';

  @override
  String get exploreTabIntegratedApps => '連携アプリ';

  @override
  String get exploreNoVideosAvailable => '動画がないよ';

  @override
  String exploreErrorPrefix(Object error) {
    return 'エラー: $error';
  }

  @override
  String get exploreDiscoverLists => 'リストを見つけよう';

  @override
  String get exploreAboutLists => 'リストについて';

  @override
  String get exploreAboutListsDescription =>
      'リストを使うと、Divine のコンテンツを2つの方法で整理・キュレーションできるよ:';

  @override
  String get explorePeopleLists => 'ピープルリスト';

  @override
  String get explorePeopleListsDescription =>
      'クリエイターのグループをフォローして、最新の動画をチェックしよう';

  @override
  String get exploreVideoLists => 'ビデオリスト';

  @override
  String get exploreVideoListsDescription => 'お気に入りの動画をプレイリストにまとめて、あとで見よう';

  @override
  String get exploreMyLists => 'マイリスト';

  @override
  String get exploreSubscribedLists => '購読中のリスト';

  @override
  String exploreErrorLoadingLists(Object error) {
    return 'リストの読み込みに失敗: $error';
  }

  @override
  String exploreNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count本の新着動画',
    );
    return '$_temp0';
  }

  @override
  String exploreLoadNewVideosLabel(int count) {
    return '$count本の新着動画を読み込む';
  }

  @override
  String get videoPlayerLoadingVideo => '動画を読み込み中...';

  @override
  String get videoPlayerPlayVideo => '動画を再生';

  @override
  String get videoPlayerMute => '動画をミュート';

  @override
  String get videoPlayerUnmute => '動画のミュートを解除';

  @override
  String get videoPlayerEditVideo => '動画を編集';

  @override
  String get videoPlayerEditVideoTooltip => '動画を編集';

  @override
  String get videoPlayerTapHint => 'タップで再生・一時停止。ダブルタップでいいね。';

  @override
  String get videoSettingsMenuOpen => '再生設定を開く';

  @override
  String get videoSettingsMenuClose => '再生設定を閉じる';

  @override
  String get videoSettingsCaptionsEnable => '字幕を有効にする';

  @override
  String get videoSettingsCaptionsDisable => '字幕を無効にする';

  @override
  String get contentWarningLabel => 'コンテンツ警告';

  @override
  String get contentWarningNudity => 'ヌード';

  @override
  String get contentWarningSexualContent => '性的コンテンツ';

  @override
  String get contentWarningPornography => 'ポルノ';

  @override
  String get contentWarningGraphicMedia => '刺激的なメディア';

  @override
  String get contentWarningViolence => '暴力';

  @override
  String get contentWarningSelfHarm => '自傷行為';

  @override
  String get contentWarningDrugUse => '薬物使用';

  @override
  String get contentWarningAlcohol => 'アルコール';

  @override
  String get contentWarningTobacco => 'タバコ';

  @override
  String get contentWarningGambling => 'ギャンブル';

  @override
  String get contentWarningProfanity => '汚い言葉';

  @override
  String get contentWarningFlashingLights => '点滅する光';

  @override
  String get contentWarningAiGenerated => 'AI 生成';

  @override
  String get contentWarningSpoiler => 'ネタバレ';

  @override
  String get contentWarningSensitiveContent => 'センシティブなコンテンツ';

  @override
  String get contentWarningDescNudity => 'ヌードや部分的なヌードが含まれてるよ';

  @override
  String get contentWarningDescSexual => '性的なコンテンツが含まれてるよ';

  @override
  String get contentWarningDescPorn => '露骨なポルノコンテンツが含まれてるよ';

  @override
  String get contentWarningDescGraphicMedia => '刺激的・不快な映像が含まれてるよ';

  @override
  String get contentWarningDescViolence => '暴力的なコンテンツが含まれてるよ';

  @override
  String get contentWarningDescSelfHarm => '自傷行為への言及が含まれてるよ';

  @override
  String get contentWarningDescDrugs => '薬物関連のコンテンツが含まれてるよ';

  @override
  String get contentWarningDescAlcohol => 'アルコール関連のコンテンツが含まれてるよ';

  @override
  String get contentWarningDescTobacco => 'タバコ関連のコンテンツが含まれてるよ';

  @override
  String get contentWarningDescGambling => 'ギャンブル関連のコンテンツが含まれてるよ';

  @override
  String get contentWarningDescProfanity => '強い表現が含まれてるよ';

  @override
  String get contentWarningDescFlashingLights => '点滅する光が含まれてるよ (光過敏症注意)';

  @override
  String get contentWarningDescAiGenerated => 'このコンテンツは AI で作られたよ';

  @override
  String get contentWarningDescSpoiler => 'ネタバレが含まれてるよ';

  @override
  String get contentWarningDescContentWarning => 'クリエイターがセンシティブとしてマークしたよ';

  @override
  String get contentWarningDescDefault => 'クリエイターがこのコンテンツにフラグを付けたよ';

  @override
  String get contentWarningDetailsTitle => 'コンテンツ警告';

  @override
  String get contentWarningDetailsSubtitle => 'クリエイターが付けたラベル:';

  @override
  String get contentWarningManageFilters => 'コンテンツフィルターを管理';

  @override
  String get contentWarningViewAnyway => 'それでも見る';

  @override
  String get contentWarningReportContentTooltip => 'コンテンツを報告';

  @override
  String get contentWarningBlockUserTooltip => 'ユーザーをブロック';

  @override
  String get contentWarningBlockedTitle => 'ブロック済みのコンテンツ';

  @override
  String get contentWarningBlockedPolicy => 'このコンテンツはポリシー違反でブロックされたよ。';

  @override
  String get contentWarningNoticeTitle => 'コンテンツに関するお知らせ';

  @override
  String get contentWarningPotentiallyHarmfulTitle => '有害な可能性があるコンテンツ';

  @override
  String get contentWarningView => '表示';

  @override
  String get contentWarningReportAction => '報告';

  @override
  String get contentWarningHideAllLikeThis => 'こういうの全部隠す';

  @override
  String get contentWarningNoFilterYet => 'この警告のフィルターはまだ保存されてないよ。';

  @override
  String get contentWarningHiddenConfirmation => 'これからはこういう投稿を隠すね。';

  @override
  String get videoErrorNotFound => '動画が見つからない';

  @override
  String get videoErrorNetwork => 'ネットワークエラー';

  @override
  String get videoErrorTimeout => '読み込みがタイムアウトした';

  @override
  String get videoErrorFormat => '動画フォーマットエラー\n(もう一回試すか、別のブラウザを使ってみて)';

  @override
  String get videoErrorUnsupportedFormat => '対応してない動画フォーマット';

  @override
  String get videoErrorPlayback => '動画の再生エラー';

  @override
  String get videoErrorAgeRestricted => '年齢制限のあるコンテンツ';

  @override
  String get videoErrorVerifyAge => '年齢を確認';

  @override
  String get videoErrorRetry => 'もう一回';

  @override
  String get videoErrorContentRestricted => 'コンテンツが制限されてる';

  @override
  String get videoErrorContentRestrictedBody => 'この動画はリレーによって制限されたよ。';

  @override
  String get videoErrorVerifyAgeBody => 'この動画を見るには年齢確認が必要だよ。';

  @override
  String get videoErrorSkip => 'スキップ';

  @override
  String get videoErrorVerifyAgeButton => '年齢を確認';

  @override
  String get videoErrorVerifyAgeFailed => '年齢を確認できませんでした。もう一回試してみて';

  @override
  String get videoErrorVerifyAgeSignerUnreachable =>
      '確認がタイムアウトしました。接続を確認するか、少し時間をおいてもう一回試してみて';

  @override
  String get videoErrorAdultContentHidden =>
      'アダルトコンテンツはオフになってるよ。[設定]→[コンテンツフィルター]でオンにできるよ。';

  @override
  String get videoFollowButtonFollowing => 'フォロー中';

  @override
  String get videoFollowButtonFollow => 'フォロー';

  @override
  String get audioAttributionOriginalSound => 'オリジナルサウンド';

  @override
  String videoInspiredByAttribution(String creatorName) {
    return '@$creatorName にインスパイアされた';
  }

  @override
  String videoCollaboratorWithOne(String name) {
    return '@$name と';
  }

  @override
  String videoCollaboratorWithMore(String name, int count) {
    return '@$name 他 +$count人と';
  }

  @override
  String videoCollaboratorCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count人のコラボレーター',
    );
    return '$_temp0。タップしてプロフィールを見てね。';
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
    return '#$hashtag。タップするとこのハッシュタグの動画を見れるよ。';
  }

  @override
  String get listAttributionFallback => 'リスト';

  @override
  String get shareVideoLabel => '動画を共有';

  @override
  String sharePostSharedWith(String recipientName) {
    return '$recipientNameに投稿を共有したよ';
  }

  @override
  String sharePostSharedWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count人に投稿を共有したよ',
    );
    return '$_temp0';
  }

  @override
  String get shareFailedToSend => '動画の送信がうまくいかなかった';

  @override
  String get shareAddedToBookmarks => 'ブックマークに追加したよ';

  @override
  String get shareRemovedFromBookmarks => 'ブックマークから外したよ';

  @override
  String get shareFailedToAddBookmark => 'ブックマークの追加がうまくいかなかった';

  @override
  String get shareFailedToRemoveBookmark => 'ブックマークを外せなかった';

  @override
  String get shareActionFailed => '操作がうまくいかなかった';

  @override
  String get shareWithTitle => '共有先';

  @override
  String get shareFindPeople => 'ユーザーを検索';

  @override
  String get shareFindPeopleMultiline => 'ユーザーを\n検索';

  @override
  String get shareSent => '送信済み';

  @override
  String get shareContactFallback => '連絡先';

  @override
  String get shareUserFallback => 'ユーザー';

  @override
  String shareSelectedRecipientAnnouncement(String name) {
    return '$nameを選択しました';
  }

  @override
  String get shareMessageHint => 'メッセージを追加 (任意)...';

  @override
  String get videoActionUnlike => 'いいねを取り消す';

  @override
  String get videoActionLike => 'いいね';

  @override
  String get videoActionAutoLabel => '自動';

  @override
  String get videoActionLikeLabel => 'いいね';

  @override
  String get videoActionReplyLabel => '返信';

  @override
  String get videoActionRepostLabel => 'リポスト';

  @override
  String get videoActionShareLabel => 'シェア';

  @override
  String get videoActionReportLabel => '報告';

  @override
  String get videoActionReport => '動画を報告';

  @override
  String get videoActionEditLabel => '編集';

  @override
  String get videoActionEdit => '動画を編集';

  @override
  String get videoActionAboutLabel => '詳細';

  @override
  String get videoActionEnableAutoAdvance => '自動送りを有効にする';

  @override
  String get videoActionDisableAutoAdvance => '自動送りを無効にする';

  @override
  String get videoActionRemoveRepost => 'リポストを取り消す';

  @override
  String get videoActionRepost => 'リポスト';

  @override
  String get videoActionViewComments => 'コメントを見る';

  @override
  String get videoActionMoreOptions => 'その他のオプション';

  @override
  String get videoActionHideSubtitles => '字幕を隠す';

  @override
  String get videoActionShowSubtitles => '字幕を表示';

  @override
  String get videoEngagementLikersTitle => 'いいねしたユーザー';

  @override
  String get videoEngagementRepostersTitle => 'リポストしたユーザー';

  @override
  String get videoEngagementLikersEmpty => 'まだいいねがありません';

  @override
  String get videoEngagementRepostersEmpty => 'まだリポストがありません';

  @override
  String get videoEngagementLoadFailed => 'リストを読み込めませんでした';

  @override
  String get videoOverlayOpenMetadataFromTitle => '動画の詳細を開く';

  @override
  String get videoOverlayOpenMetadataFromDescription => '動画の詳細を開く';

  @override
  String get videoOverlayCommentBarHint => 'コメントを追加...';

  @override
  String get videoOverlayCommentBarSemanticLabel => 'コメントを追加';

  @override
  String get videoOverlayCommentBarSendLabel => 'コメントを送信';

  @override
  String get videoOverlayCommentPostedSnackbar => 'コメントを投稿したよ';

  @override
  String get videoOverlayCommentPostFailedSnackbar => 'コメントを投稿できなかったよ';

  @override
  String videoDescriptionLoops(String count) {
    return '$countループ';
  }

  @override
  String videoFeedLoopCountLine(String compactCount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ループ',
    );
    return '$compactCount$_temp0';
  }

  @override
  String get metadataBadgeNotDivine => 'Divine 以外';

  @override
  String get metadataBadgeHumanMade => '人間が制作';

  @override
  String get metadataSoundsLabel => 'サウンド';

  @override
  String get metadataOriginalSound => 'オリジナルサウンド';

  @override
  String get metadataVerificationLabel => '認証';

  @override
  String get metadataDeviceAttestation => 'デバイスの認証';

  @override
  String get metadataPgpSignature => 'PGP 署名';

  @override
  String get metadataC2paCredentials => 'C2PA コンテンツ認証情報';

  @override
  String get metadataProofManifest => '証明マニフェスト';

  @override
  String get metadataCreatorLabel => 'クリエイター';

  @override
  String get metadataCollaboratorsLabel => 'コラボレーター';

  @override
  String get metadataInspiredByLabel => 'インスパイア元';

  @override
  String get metadataRepostedByLabel => 'リポスト元';

  @override
  String metadataLoopsLabel(int count) {
    return 'ループ';
  }

  @override
  String get metadataLikesLabel => 'いいね';

  @override
  String get metadataCommentsLabel => 'コメント';

  @override
  String get metadataRepostsLabel => 'リポスト';

  @override
  String get metadataVineStatsLabel => 'Vineで';

  @override
  String metadataVineStatsLine(
    String loops,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$loopsループ · $likes件のいいね · $comments件のコメント · $reposts件のリポスト';
  }

  @override
  String get metadataDivineStatsLabel => 'Divineで';

  @override
  String metadataDivineStatsLine(
    String views,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$views回再生 · $likes件のいいね · $comments件のコメント · $reposts件のリポスト';
  }

  @override
  String metadataPostedDateSemantics(String date) {
    return '$dateに投稿';
  }

  @override
  String get devOptionsTitle => '開発者オプション';

  @override
  String get devOptionsPageLoadTimes => 'ページ読み込み時間';

  @override
  String get devOptionsNoPageLoads =>
      'まだページ読み込みの記録がないよ。\nアプリ内を移動するとタイミングデータが出るよ。';

  @override
  String devOptionsPageLoadVisible(String visibleMs, String dataMs) {
    return '表示: ${visibleMs}ms  |  データ: ${dataMs}ms';
  }

  @override
  String get devOptionsSlowestScreens => '最も遅い画面';

  @override
  String get devOptionsVideoPlaybackFormat => '動画再生フォーマット';

  @override
  String get devOptionsSwitchEnvironmentTitle => '環境を切り替える?';

  @override
  String devOptionsSwitchEnvironmentMessage(String envName) {
    return '$envNameに切り替える?\n\nキャッシュされた動画データがクリアされて、新しいリレーに再接続するよ。';
  }

  @override
  String get devOptionsCancel => 'キャンセル';

  @override
  String get devOptionsSwitch => '切り替え';

  @override
  String devOptionsSwitchedTo(String envName) {
    return '$envNameに切り替えたよ';
  }

  @override
  String devOptionsSwitchedFormat(String formatName) {
    return '$formatNameに切り替えた — キャッシュもクリアしたよ';
  }

  @override
  String get featureFlagTitle => '機能フラグ';

  @override
  String get featureFlagResetAllTooltip => 'すべてのフラグを既定値にリセット';

  @override
  String get featureFlagResetToDefault => '既定にリセット';

  @override
  String get featureFlagAppRecovery => 'アプリ復旧';

  @override
  String get featureFlagAppRecoveryDescription =>
      'アプリがクラッシュしたりおかしい時は、キャッシュのクリアを試してみて。';

  @override
  String get featureFlagClearAllCache => 'すべてのキャッシュをクリア';

  @override
  String get featureFlagCacheInfo => 'キャッシュ情報';

  @override
  String get featureFlagClearCacheTitle => 'すべてのキャッシュをクリアする?';

  @override
  String get featureFlagClearCacheMessage =>
      '次のキャッシュデータを全部クリアするよ:\n• 通知\n• ユーザープロフィール\n• ブックマーク\n• 一時ファイル\n\n再度ログインが必要になるけど、続ける?';

  @override
  String get featureFlagClearCache => 'キャッシュをクリア';

  @override
  String get featureFlagClearingCache => 'キャッシュをクリア中...';

  @override
  String get featureFlagSuccess => '成功！';

  @override
  String get featureFlagError => 'エラー';

  @override
  String get featureFlagClearCacheSuccess => 'キャッシュをクリアしたよ。アプリを再起動してね。';

  @override
  String get featureFlagClearCacheFailure =>
      '一部のキャッシュ項目のクリアがうまくいかなかった。ログを確認してみて。';

  @override
  String get featureFlagOk => 'OK';

  @override
  String get featureFlagCacheInformation => 'キャッシュ情報';

  @override
  String featureFlagTotalCacheSize(String size) {
    return 'キャッシュ合計: $size';
  }

  @override
  String get featureFlagCacheIncludes =>
      'キャッシュに含まれるもの:\n• 通知履歴\n• ユーザープロフィールデータ\n• 動画サムネイル\n• 一時ファイル\n• データベースインデックス';

  @override
  String get relaySettingsTitle => 'リレー';

  @override
  String get relaySettingsInfoTitle => 'Divine はオープンなシステム——接続はあなたがコントロールできるよ';

  @override
  String get relaySettingsInfoDescription =>
      'これらのリレーが、あなたのコンテンツを分散型の Nostr ネットワークに届けてくれる。リレーは自由に追加・削除できるよ。';

  @override
  String get relaySettingsLearnMoreNostr => 'Nostr についてもっと詳しく →';

  @override
  String get relaySettingsFindPublicRelays => 'nostr.co.uk でパブリックリレーを探す →';

  @override
  String get relaySettingsAppNotFunctional => 'アプリが動かないよ';

  @override
  String get relaySettingsRequiresRelay =>
      'Divine では、動画の読み込み、コンテンツの投稿、データの同期に少なくとも1つのリレーが必要だよ。';

  @override
  String get relaySettingsRestoreDefaultRelay => '既定のリレーを復元';

  @override
  String get relaySettingsAddCustomRelay => 'カスタムリレーを追加';

  @override
  String get relaySettingsAddRelay => 'リレーを追加';

  @override
  String get relaySettingsRetry => 'もう一回';

  @override
  String get relaySettingsNoStats => 'まだ統計情報がないよ';

  @override
  String get relaySettingsConnection => '接続';

  @override
  String get relaySettingsConnected => '接続済み';

  @override
  String get relaySettingsDisconnected => '切断';

  @override
  String get relaySettingsSessionDuration => 'セッション時間';

  @override
  String get relaySettingsLastConnected => '最終接続';

  @override
  String get relaySettingsDisconnectedLabel => '切断';

  @override
  String get relaySettingsReason => '理由';

  @override
  String get relaySettingsActiveSubscriptions => 'アクティブなサブスクリプション';

  @override
  String get relaySettingsTotalSubscriptions => 'サブスクリプション合計';

  @override
  String get relaySettingsEventsReceived => '受信したイベント';

  @override
  String get relaySettingsEventsSent => '送信したイベント';

  @override
  String get relaySettingsRequestsThisSession => 'このセッションのリクエスト';

  @override
  String get relaySettingsFailedRequests => '失敗したリクエスト';

  @override
  String relaySettingsLastError(String error) {
    return '最後のエラー: $error';
  }

  @override
  String get relaySettingsLoadingRelayInfo => 'リレー情報を読み込み中...';

  @override
  String get relaySettingsAboutRelay => 'リレーについて';

  @override
  String get relaySettingsSupportedNips => '対応 NIP';

  @override
  String get relaySettingsSoftware => 'ソフトウェア';

  @override
  String get relaySettingsViewWebsite => 'ウェブサイトを見る';

  @override
  String get relaySettingsRemoveRelayTitle => 'リレーを削除する?';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return 'このリレーを本当に削除する?\n\n$relayUrl';
  }

  @override
  String get relaySettingsCancel => 'キャンセル';

  @override
  String get relaySettingsRemove => '削除';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return 'リレーを削除したよ: $relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay => 'リレーの削除がうまくいかなかった';

  @override
  String get relaySettingsForcingReconnection => 'リレーに再接続中...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    return '$count個のリレーに接続したよ！';
  }

  @override
  String get relaySettingsFailedToConnectCheck => 'リレーに接続できなかった。ネット接続を確認してみて。';

  @override
  String get relaySettingsAddRelayTitle => 'リレーを追加';

  @override
  String get relaySettingsAddRelayPrompt => '追加したいリレーの WebSocket URL を入力してね:';

  @override
  String get relaySettingsBrowsePublicRelays => 'nostr.co.uk でパブリックリレーを見る';

  @override
  String get relaySettingsAdd => '追加';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return 'リレーを追加したよ: $relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay =>
      'リレーの追加がうまくいかなかった。URL を確認してもう一回試してみて。';

  @override
  String get relaySettingsInvalidUrl => 'リレー URL は wss:// か ws:// で始める必要があるよ';

  @override
  String get relaySettingsInsecureUrl =>
      'リレー URL は wss:// を使ってね (ws:// は localhost のみ可)';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return '既定のリレーを復元したよ: $defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault =>
      '既定リレーの復元がうまくいかなかった。ネット接続を確認してみて。';

  @override
  String get relaySettingsCouldNotOpenBrowser => 'ブラウザが開けなかった';

  @override
  String get relaySettingsFailedToOpenLink => 'リンクが開けなかった';

  @override
  String get relaySettingsExternalRelay => '外部リレー';

  @override
  String get relaySettingsNotConnected => '未接続';

  @override
  String relaySettingsDisconnectedAgo(String duration) {
    return '$duration前に切断';
  }

  @override
  String relaySettingsSubscriptionsSummary(int count) {
    return '$count件のサブスク';
  }

  @override
  String relaySettingsEventsSummary(String count) {
    return '$count件のイベント';
  }

  @override
  String relaySettingsTimeAgo(String duration) {
    return '$duration前';
  }

  @override
  String get nostrSettingsIntro =>
      'Divine は分散型パブリッシングに Nostr プロトコルを使ってるよ。コンテンツは選んだリレーに置かれて、鍵があなたの ID になる。';

  @override
  String get nostrSettingsSectionNetwork => 'ネットワーク';

  @override
  String get nostrSettingsSectionAccount => 'アカウント';

  @override
  String get nostrSettingsSectionDangerZone => '危険ゾーン';

  @override
  String get nostrSettingsRelays => 'リレー';

  @override
  String get nostrSettingsRelaysSubtitle => 'Nostr リレー接続を管理';

  @override
  String get nostrSettingsRelayDiagnostics => 'リレー診断';

  @override
  String get nostrSettingsRelayDiagnosticsSubtitle => 'リレー接続とネットワークの問題をデバッグ';

  @override
  String get nostrSettingsMediaServers => 'メディアサーバー';

  @override
  String get nostrSettingsMediaServersSubtitle => 'Blossom アップロードサーバーを設定';

  @override
  String get nostrSettingsDeveloperOptions => '開発者オプション';

  @override
  String get nostrSettingsDeveloperOptionsSubtitle => '環境スイッチャーとデバッグ設定';

  @override
  String get nostrSettingsExperimentalFeaturesSubtitle =>
      'バグるかもしれない機能フラグを切り替える。';

  @override
  String get nostrSettingsKeyManagement => '鍵の管理';

  @override
  String get nostrSettingsKeyManagementSubtitle => 'Nostr 鍵をエクスポート、バックアップ、復元';

  @override
  String get nostrSettingsClientAttribution => 'クライアント表記';

  @override
  String get nostrSettingsClientAttributionSubtitle =>
      '公開するイベントに Divine のクライアントタグを含めて、他の Nostr アプリが正しく出典を示せるようにするよ。';

  @override
  String get nostrSettingsRemoveKeys => 'このデバイスから鍵を削除';

  @override
  String get nostrSettingsRemoveKeysSubtitle =>
      'このデバイスから秘密鍵だけを消すよ。コンテンツはリレーに残るけど、もう一回アカウントを使うには nsec のバックアップが必要になるよ。';

  @override
  String get nostrSettingsCouldNotRemoveKeys => 'このデバイスから鍵を削除できなかった。もう一回試してみて。';

  @override
  String nostrSettingsFailedToRemoveKeys(String error) {
    return '鍵の削除に失敗: $error';
  }

  @override
  String get nostrSettingsDeleteAccount => 'アカウントとデータを削除';

  @override
  String get nostrSettingsDeleteAccountSubtitle =>
      'アカウントとすべてのコンテンツを Nostr リレーから完全に削除するよ。元には戻せないよ。';

  @override
  String get relayDiagnosticTitle => 'リレー診断';

  @override
  String get relayDiagnosticRefreshTooltip => '診断を更新';

  @override
  String relayDiagnosticLastRefresh(String time) {
    return '最終更新: $time';
  }

  @override
  String get relayDiagnosticRelayStatus => 'リレーの状態';

  @override
  String get relayDiagnosticInitialized => '初期化済み';

  @override
  String get relayDiagnosticReady => '準備OK';

  @override
  String get relayDiagnosticNotInitialized => '未初期化';

  @override
  String get relayDiagnosticDatabaseEvents => 'データベースイベント';

  @override
  String get relayDiagnosticActiveSubscriptions => 'アクティブなサブスクリプション';

  @override
  String get relayDiagnosticExternalRelays => '外部リレー';

  @override
  String get relayDiagnosticConfigured => '設定済み';

  @override
  String relayDiagnosticRelayCount(int count) {
    return '$count個のリレー';
  }

  @override
  String get relayDiagnosticConnectedLabel => '接続済み';

  @override
  String relayDiagnosticConnectedRatio(int connected, int total) {
    return '$connected/$total';
  }

  @override
  String get relayDiagnosticVideoEvents => '動画イベント';

  @override
  String get relayDiagnosticHomeFeed => 'ホームフィード';

  @override
  String relayDiagnosticVideosCount(int count) {
    return '$count本の動画';
  }

  @override
  String get relayDiagnosticDiscovery => '発見';

  @override
  String get relayDiagnosticLoading => '読み込み中';

  @override
  String get relayDiagnosticYes => 'はい';

  @override
  String get relayDiagnosticNo => 'いいえ';

  @override
  String get relayDiagnosticTestDirectQuery => 'ダイレクトクエリをテスト';

  @override
  String get relayDiagnosticNetworkConnectivity => 'ネットワーク接続';

  @override
  String get relayDiagnosticRunNetworkTest => 'ネットワークテストを実行';

  @override
  String get relayDiagnosticBlossomServer => 'Blossom サーバー';

  @override
  String get relayDiagnosticTestAllEndpoints => 'すべてのエンドポイントをテスト';

  @override
  String get relayDiagnosticStatus => 'ステータス';

  @override
  String get relayDiagnosticUrl => 'URL';

  @override
  String get relayDiagnosticError => 'エラー';

  @override
  String get relayDiagnosticFunnelCakeApi => 'FunnelCake API';

  @override
  String get relayDiagnosticBaseUrl => 'ベース URL';

  @override
  String get relayDiagnosticSummary => 'サマリー';

  @override
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  ) {
    return '$successCount/$totalCount OK (平均 ${avgMs}ms)';
  }

  @override
  String get relayDiagnosticRetestAll => 'すべて再テスト';

  @override
  String get relayDiagnosticRetrying => '再試行中...';

  @override
  String get relayDiagnosticRetryConnection => '接続を再試行';

  @override
  String get relayDiagnosticTroubleshooting => 'トラブルシューティング';

  @override
  String get relayDiagnosticTroubleshootingGuide =>
      '• 緑 = 接続済み・動いてるよ\n• 赤 = 接続に失敗\n• ネットワークテストが失敗するなら、ネット接続を確認してね\n• リレーが設定されてるのに繋がらないなら [接続を再試行] をタップしてみて\n• デバッグ用にこの画面をスクショしておくといいよ';

  @override
  String get relayDiagnosticAllEndpointsHealthy => 'すべての REST エンドポイントが正常だよ！';

  @override
  String get relayDiagnosticSomeEndpointsFailed =>
      '一部の REST エンドポイントが失敗してる - 上の詳細を見てね';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    return 'データベースで$count件の動画イベントが見つかったよ';
  }

  @override
  String relayDiagnosticQueryFailed(String error) {
    return 'クエリがうまくいかなかった: $error';
  }

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    return '$count個のリレーに接続したよ！';
  }

  @override
  String get relayDiagnosticFailedToConnect => 'どのリレーにも接続できなかった';

  @override
  String relayDiagnosticConnectionRetryFailed(String error) {
    return '接続の再試行がうまくいかなかった: $error';
  }

  @override
  String get relayDiagnosticConnectedAuthenticated => '接続・認証済み';

  @override
  String get relayDiagnosticConnectedOnly => '接続済み';

  @override
  String get relayDiagnosticNotConnected => '未接続';

  @override
  String get relayDiagnosticNoRelaysConfigured => 'リレーが設定されてないよ';

  @override
  String get relayDiagnosticFailed => '失敗';

  @override
  String get notificationSettingsTitle => '通知';

  @override
  String get notificationSettingsResetTooltip => '既定値にリセット';

  @override
  String get notificationSettingsTypes => '通知の種類';

  @override
  String get notificationSettingsLikes => 'いいね';

  @override
  String get notificationSettingsLikesSubtitle => '誰かがあなたの動画にいいねした時';

  @override
  String get notificationSettingsComments => 'コメント';

  @override
  String get notificationSettingsCommentsSubtitle => '誰かがあなたの動画にコメントした時';

  @override
  String get notificationSettingsFollows => 'フォロー';

  @override
  String get notificationSettingsFollowsSubtitle => '誰かがあなたをフォローした時';

  @override
  String get notificationSettingsMentions => 'メンション';

  @override
  String get notificationSettingsMentionsSubtitle => 'あなたがメンションされた時';

  @override
  String get notificationSettingsReposts => 'リポスト';

  @override
  String get notificationSettingsRepostsSubtitle => '誰かがあなたの動画をリポストした時';

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
  String get notificationSettingsActions => 'アクション';

  @override
  String get notificationSettingsMarkAllAsRead => 'すべて既読にする';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle => 'すべての通知を既読にするよ';

  @override
  String get notificationSettingsAllMarkedAsRead => 'すべての通知を既読にしたよ';

  @override
  String get notificationSettingsMarkAllAsReadFailed => 'すべて既読にできなかったよ';

  @override
  String get notificationSettingsResetToDefaults => '設定を既定値にリセットしたよ';

  @override
  String get notificationSettingsAbout => '通知について';

  @override
  String get notificationSettingsAboutDescription =>
      '通知は Nostr プロトコルで動いてるよ。リアルタイム更新は Nostr リレーへの接続に依存するから、遅れることもあるよ。';

  @override
  String get safetySettingsTitle => '安全とプライバシー';

  @override
  String get safetySettingsLabel => '設定';

  @override
  String get safetySettingsWhatYouSee => 'あなたが見るもの';

  @override
  String get safetySettingsWhatYouPublish => 'あなたが公開するもの';

  @override
  String get safetySettingsShowDivineHostedOnly => 'Divine ホスト動画だけ表示';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle => '他のメディアホストの動画を隠す';

  @override
  String get safetySettingsModeration => 'モデレーション';

  @override
  String get safetySettingsBlockedUsers => 'ブロック済みユーザー';

  @override
  String get safetySettingsAgeVerification => '年齢確認';

  @override
  String get safetySettingsAgeConfirmation => '18歳以上であることを確認する';

  @override
  String get safetySettingsAgeRequired => 'アダルトコンテンツの閲覧に必要だよ';

  @override
  String get safetySettingsAgeLockedForMinor => 'あなたのアカウントではロックされてるよ';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle => '公式モデレーションサービス (既定でオン)';

  @override
  String get safetySettingsPeopleIFollow => 'フォロー中のユーザー';

  @override
  String get safetySettingsPeopleIFollowSubtitle => 'フォローしてる人のラベルを購読';

  @override
  String get safetySettingsAddCustomLabeler => 'カスタムラベラーを追加';

  @override
  String get safetySettingsAddCustomLabelerHint => 'npub を入力...';

  @override
  String get safetySettingsAddCustomLabelerListTitle => 'カスタムラベラーを追加';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle => 'npub アドレスを入力してね';

  @override
  String get safetySettingsNoBlockedUsers => 'ブロック済みユーザーはいないよ';

  @override
  String get safetySettingsUnblock => 'ブロック解除';

  @override
  String get safetySettingsUserUnblocked => 'ブロックを解除したよ';

  @override
  String get safetySettingsCancel => 'キャンセル';

  @override
  String get safetySettingsAdd => '追加';

  @override
  String get analyticsTitle => 'クリエイター分析';

  @override
  String get analyticsDiagnosticsTooltip => '診断';

  @override
  String get analyticsDiagnosticsSemanticLabel => '診断を切り替え';

  @override
  String get analyticsRetry => 'もう一回';

  @override
  String get analyticsUnableToLoad => '分析データを読み込めなかった。';

  @override
  String get analyticsSignInRequired => 'クリエイター分析を見るにはサインインしてね。';

  @override
  String get analyticsViewDataUnavailable =>
      'これらの投稿の視聴データは今のところリレーから取得できないよ。いいね・コメント・リポストの数値は正確だよ。';

  @override
  String get analyticsViewDataTitle => '視聴データ';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return '更新 $time • スコアは Funnelcake で利用可能な場合、いいね、コメント、リポスト、視聴/ループを使ってるよ。';
  }

  @override
  String get analyticsVideos => '動画';

  @override
  String get analyticsViews => '視聴';

  @override
  String get analyticsInteractions => 'インタラクション';

  @override
  String get analyticsEngagement => 'エンゲージメント';

  @override
  String get analyticsFollowers => 'フォロワー';

  @override
  String get analyticsAvgPerPost => '投稿あたり平均';

  @override
  String get analyticsInteractionMix => 'インタラクション構成';

  @override
  String get analyticsLikes => 'いいね';

  @override
  String get analyticsComments => 'コメント';

  @override
  String get analyticsReposts => 'リポスト';

  @override
  String get analyticsPerformanceHighlights => 'パフォーマンスハイライト';

  @override
  String get analyticsMostViewed => '最も見られた';

  @override
  String get analyticsMostDiscussed => '最も話題になった';

  @override
  String get analyticsMostReposted => '最もリポストされた';

  @override
  String get analyticsNoVideosYet => '動画はまだないよ';

  @override
  String get analyticsViewDataUnavailableShort => '視聴データなし';

  @override
  String analyticsViewsCount(String count) {
    return '$count回視聴';
  }

  @override
  String analyticsCommentsCount(String count) {
    return '$count件のコメント';
  }

  @override
  String analyticsRepostsCount(String count) {
    return '$count件のリポスト';
  }

  @override
  String get analyticsTopContent => 'トップコンテンツ';

  @override
  String get analyticsPublishPrompt => 'ランキングを見るには動画をいくつか公開してみて。';

  @override
  String get analyticsEngagementRateExplainer =>
      '右の % = エンゲージメント率 (インタラクション数 ÷ 視聴数)。';

  @override
  String get analyticsEngagementRateNoViews =>
      'エンゲージメント率には視聴データが必要。視聴データが揃うまで N/A と出るよ。';

  @override
  String get analyticsEngagementLabel => 'エンゲージメント';

  @override
  String get analyticsViewsUnavailable => '視聴データなし';

  @override
  String analyticsInteractionsCount(String count) {
    return '$count件のインタラクション';
  }

  @override
  String get analyticsPostAnalytics => '投稿の分析';

  @override
  String get analyticsOpenPost => '投稿を開く';

  @override
  String get analyticsRecentDailyInteractions => '最近の日別インタラクション';

  @override
  String get analyticsNoActivityYet => 'この期間のアクティビティはまだないよ。';

  @override
  String get analyticsDailyInteractionsExplainer =>
      'インタラクション = 投稿日ごとの いいね + コメント + リポスト。';

  @override
  String get analyticsDailyBarExplainer => 'バーの長さはこの期間で最も多かった日を基準にした相対値だよ。';

  @override
  String get analyticsAudienceSnapshot => 'オーディエンスの概要';

  @override
  String analyticsFollowersCount(String count) {
    return 'フォロワー: $count';
  }

  @override
  String analyticsFollowingCount(String count) {
    return 'フォロー中: $count';
  }

  @override
  String get analyticsAudiencePlaceholder =>
      'Funnelcake がオーディエンス分析エンドポイントを追加したら、ソース/地域/時間帯の内訳がここに入るよ。';

  @override
  String get analyticsRetention => 'リテンション';

  @override
  String get analyticsRetentionWithViews =>
      'Funnelcake からリテンションデータが届いたら、リテンションカーブと視聴時間の内訳がここに出るよ。';

  @override
  String get analyticsRetentionWithoutViews =>
      'Funnelcake から視聴+視聴時間の分析が返されるまで、リテンションデータは使えないよ。';

  @override
  String get analyticsDiagnostics => '診断';

  @override
  String analyticsDiagnosticsTotalVideos(int count) {
    return '動画合計: $count';
  }

  @override
  String analyticsDiagnosticsWithViews(int count) {
    return '視聴ありの動画: $count';
  }

  @override
  String analyticsDiagnosticsMissingViews(int count) {
    return '視聴なしの動画: $count';
  }

  @override
  String analyticsDiagnosticsHydratedBulk(int count) {
    return '取得済み (bulk): $count';
  }

  @override
  String analyticsDiagnosticsHydratedViews(int count) {
    return '取得済み (/views): $count';
  }

  @override
  String analyticsDiagnosticsSources(String sources) {
    return 'ソース: $sources';
  }

  @override
  String get analyticsDiagnosticsUseFixture => 'フィクスチャデータを使う';

  @override
  String get analyticsNa => 'N/A';

  @override
  String get authCreateNewAccount => '新しい Divine アカウントを作ろう';

  @override
  String get authCreateNewAccountShort => 'Create new account';

  @override
  String get authSignInDifferentAccount => '別のアカウントでサインイン';

  @override
  String get authUseAnotherAccount => 'Use another account';

  @override
  String authContinueAs(String displayName) {
    return 'Continue as $displayName';
  }

  @override
  String get authRecoveryDraftsOwner => '下書きとクリップはこのアカウントに保存されています';

  @override
  String get authRecoveryOtherAccountWarning => 'ここでサインインするとそれらが非表示になります';

  @override
  String get authTermsPrefix =>
      'By selecting an option below, you confirm you are at least 16 years old (or have completed ';

  @override
  String get authTermsAgeAuthorizationCta => 'Divine age authorization';

  @override
  String get authTermsAfterAgeAuthorization => ') and agree to the ';

  @override
  String get authTermsOfService => '利用規約';

  @override
  String get authPrivacyPolicy => 'プライバシーポリシー';

  @override
  String get authTermsAnd => '、そして ';

  @override
  String get authSafetyStandards => '安全基準';

  @override
  String get authAmberNotInstalled => 'Amber アプリがインストールされてないよ';

  @override
  String get authAmberConnectionFailed => 'Amber との接続がうまくいかなかった';

  @override
  String get authPasswordResetSent => 'そのメールアドレスのアカウントがあれば、パスワードリセットリンクを送ったよ。';

  @override
  String get authSignInTitle => 'サインイン';

  @override
  String get authEmailLabel => 'メールアドレス';

  @override
  String get authPasswordLabel => 'パスワード';

  @override
  String get authConfirmPasswordLabel => 'パスワードの確認';

  @override
  String get authEmailRequired => 'メールは必須だよ';

  @override
  String get authEmailInvalid => '有効なメールアドレスを入力してね';

  @override
  String get authPasswordRequired => 'パスワードは必須だよ';

  @override
  String get authConfirmPasswordRequired => 'パスワードを確認してね';

  @override
  String get authPasswordsDoNotMatch => 'パスワードが一致しないよ';

  @override
  String get authForgotPassword => 'パスワードを忘れた?';

  @override
  String get authImportNostrKey => 'Nostr 鍵をインポート';

  @override
  String get authConnectSignerApp => '署名アプリで接続';

  @override
  String get authSignInWithAmber => 'Amber でサインイン';

  @override
  String get authSignInWithBrowserExtension => 'ブラウザ拡張機能でサインイン';

  @override
  String get authNip07ConnectionFailed => 'ブラウザ拡張機能に接続できませんでした。';

  @override
  String get authNip07ExtensionNotFound =>
      'ブラウザ拡張機能が見つかりません。Alby、nos2x、またはその他の NIP-07 対応拡張機能をインストールしてください。';

  @override
  String get authSignInOptionsTitle => 'サインインオプション';

  @override
  String get authInfoEmailPasswordTitle => 'メールとパスワード';

  @override
  String get authInfoEmailPasswordDescription =>
      'Divine アカウントでサインインするよ。メールとパスワードで登録した人はそれを使ってね。';

  @override
  String get authInfoImportNostrKeyDescription =>
      'もう Nostr ID を持ってる? 別のクライアントから nsec 秘密鍵をインポートしてね。';

  @override
  String get authInfoSignerAppTitle => '署名アプリ';

  @override
  String get authInfoSignerAppDescription =>
      'nsecBunker みたいな NIP-46 対応のリモート署名アプリで接続すれば、鍵のセキュリティを強化できるよ。';

  @override
  String get authInfoAmberTitle => 'Amber';

  @override
  String get authInfoAmberDescription =>
      'Android 向けの Amber 署名アプリで、Nostr 鍵を安全に管理できるよ。';

  @override
  String get authInfoBrowserExtensionTitle => 'ブラウザ拡張機能';

  @override
  String get authInfoBrowserExtensionDescription =>
      'Alby や nos2x のような NIP-07 ブラウザ拡張機能でサインインします。鍵は拡張機能内に保持され、Divine からは見えません。';

  @override
  String get authCreateAccountTitle => 'アカウントを作ろう';

  @override
  String get authBackToInviteCode => '招待コードに戻る';

  @override
  String get authUseDivineNoBackup => 'バックアップなしで Divine を使う';

  @override
  String get authSkipConfirmTitle => '最後にひとつだけ...';

  @override
  String get authSkipConfirmKeyCreated => 'やった！ Divine アカウントを動かす安全な鍵を作るよ。';

  @override
  String get authSkipConfirmKeyOnly => 'メールなしだと、この鍵がアカウントがあなたのものだと知る唯一の手段になるよ。';

  @override
  String get authSkipConfirmRecommendEmail =>
      'アプリ内で鍵にアクセスできるけど、技術に詳しくないなら今すぐメールとパスワードを追加するのがおすすめ。サインインが楽になるし、デバイスを失くしたりリセットした時にアカウントを復元しやすくなるよ。';

  @override
  String get authAddEmailPassword => 'メールとパスワードを追加';

  @override
  String get authUseThisDeviceOnly => 'このデバイスのみ使う';

  @override
  String get authCompleteRegistration => '登録を完了';

  @override
  String get authVerifying => '確認中...';

  @override
  String get authVerificationLinkSent => '認証リンクを送ったよ:';

  @override
  String get authClickVerificationLink => '登録を完了するには、メール内のリンクをクリックしてね。';

  @override
  String get authPleaseWaitVerifying => 'メールを確認中。ちょっと待ってね...';

  @override
  String get authWaitingForVerification => '認証を待ってるよ';

  @override
  String get authOpenEmailApp => 'メールアプリを開く';

  @override
  String get authWelcomeToDivine => 'やった！入れたよ！';

  @override
  String get authEmailVerified => 'メールアドレスを確認したよ。';

  @override
  String get authSigningYouIn => 'サインイン中';

  @override
  String get authErrorTitle => 'おっと。';

  @override
  String get authVerificationFailed => 'メールの確認がうまくいかなかった。\nもう一回試してみて。';

  @override
  String get authStartOver => '最初からやり直す';

  @override
  String get authEmailVerifiedLogin => 'メールを確認したよ！ ログインして続けてね。';

  @override
  String get authVerificationLinkExpired => 'この認証リンクはもう使えないよ。';

  @override
  String get authVerificationConnectionError =>
      'メールを確認できなかった。接続を確認してもう一回試してみて。';

  @override
  String get authWaitlistConfirmTitle => '登録完了！';

  @override
  String authWaitlistUpdatesAt(String email) {
    return 'アップデートは $email に送るね。\n招待コードが使えるようになったら、すぐお知らせするよ。';
  }

  @override
  String get authOk => 'OK';

  @override
  String get authInviteUnavailable => '招待アクセスが一時的に使えないよ。';

  @override
  String get authInviteUnavailableBody => '少し待ってからもう一回試してみて。参加で困ったらサポートに連絡してね。';

  @override
  String get authTryAgain => 'もう一回';

  @override
  String get authContactSupport => 'サポートに連絡';

  @override
  String authCouldNotOpenEmail(String email) {
    return '$email が開けなかった';
  }

  @override
  String get authAddInviteCode => '招待コードを入力';

  @override
  String get authInviteCodeLabel => '招待コード';

  @override
  String get authEnterYourCode => 'コードを入力';

  @override
  String get authNext => '次へ';

  @override
  String get authJoinWaitlist => 'ウェイトリストに参加';

  @override
  String get authJoinWaitlistTitle => 'ウェイトリストに参加';

  @override
  String get authJoinWaitlistDescription =>
      'メールアドレスを教えてね。アクセス開放に合わせてアップデートを送るよ。';

  @override
  String get authJoinWaitlistNewsletterOptIn => 'Send me Divine inspiration';

  @override
  String get authInviteAccessHelp => '招待アクセスのヘルプ';

  @override
  String get authGeneratingConnection => '接続を生成中...';

  @override
  String get authConnectedAuthenticating => '接続OK！認証中...';

  @override
  String get authConnectionTimedOut => '接続がタイムアウトした';

  @override
  String get authApproveConnection => '署名アプリで接続を承認したか確認してね。';

  @override
  String get authConnectionCancelled => '接続がキャンセルされた';

  @override
  String get authConnectionCancelledMessage => '接続はキャンセルされたよ。';

  @override
  String get authConnectionFailed => '接続がうまくいかなかった';

  @override
  String get authUnknownError => '不明なエラーが起きた。';

  @override
  String get authBunkerRejectedConnection => '署名アプリが接続を拒否したよ。';

  @override
  String get authNostrConnectStartFailed => '署名アプリにつながらなかった。接続を確認してもう一回試してみて。';

  @override
  String get authNostrConnectInvalidSession => 'この接続リンクはもう使えないよ。新しいリンクで始めてね。';

  @override
  String get authNostrConnectSetupFailed => 'あと少し——サインインを完了できなかったよ。もう一回試してみて。';

  @override
  String get authUrlCopied => 'URL をコピーしたよ';

  @override
  String get authConnectToDivine => 'Divine に接続';

  @override
  String get authPasteBunkerUrl => 'bunker:// URL を貼り付け';

  @override
  String get authBunkerUrlHint => 'bunker:// URL';

  @override
  String get authInvalidBunkerUrl => '無効な bunker URL だよ。bunker:// で始めてね';

  @override
  String get authScanSignerApp => '署名アプリで\nスキャンして接続してね。';

  @override
  String authWaitingForConnection(int seconds) {
    return '接続を待ってるよ... $seconds秒';
  }

  @override
  String get authCopyUrl => 'URL をコピー';

  @override
  String get authShare => '共有';

  @override
  String get authAddBunker => 'bunker を追加';

  @override
  String get authCompatibleSignerApps => '対応する署名アプリ';

  @override
  String get authFailedToConnect => '接続がうまくいかなかった';

  @override
  String get authResetPasswordTitle => 'パスワードをリセット';

  @override
  String get authResetPasswordSubtitle => '新しいパスワードを入れてね。8文字以上にしてね。';

  @override
  String get authNewPasswordLabel => '新しいパスワード';

  @override
  String get authConfirmNewPasswordLabel => '新しいパスワードの確認';

  @override
  String get authPasswordTooShort => 'パスワードは8文字以上にしてね';

  @override
  String get authPasswordResetSuccess => 'パスワードをリセットしたよ。ログインしてね。';

  @override
  String get authPasswordResetFailed => 'パスワードのリセットがうまくいかなかった';

  @override
  String get authUnexpectedError => '予期しないエラーが起きた。もう一回試してみて。';

  @override
  String get authUpdatePassword => 'パスワードを更新';

  @override
  String get authSecureAccountTitle => 'アカウントを守ろう';

  @override
  String get authUnableToAccessKeys => '鍵にアクセスできなかった。もう一回試してみて。';

  @override
  String get authRegistrationFailed => '登録がうまくいかなかった';

  @override
  String get authRegistrationComplete => '登録完了。メールを確認してね。';

  @override
  String get authVerificationFailedTitle => '認証がうまくいかなかった';

  @override
  String get authClose => '閉じる';

  @override
  String get authAccountSecured => 'アカウントを守ったよ！';

  @override
  String get authAccountLinkedToEmail => 'アカウントがメールアドレスに紐づいたよ。';

  @override
  String get authVerifyYourEmail => 'メールアドレスを確認してね';

  @override
  String get authClickLinkContinue => 'メール内のリンクをクリックして登録を完了してね。その間もアプリは使えるよ。';

  @override
  String get authWaitingForVerificationEllipsis => '認証を待ってるよ...';

  @override
  String get authContinueToApp => 'アプリに進む';

  @override
  String get authResetPassword => 'パスワードをリセット';

  @override
  String get authResetPasswordDescription =>
      'メールアドレスを入れてね。パスワードをリセットするリンクを送るよ。';

  @override
  String get authFailedToSendResetEmail => 'リセットメールの送信がうまくいかなかった。';

  @override
  String get authUnexpectedErrorShort => '予期しないエラーが起きた。';

  @override
  String get authSending => '送信中...';

  @override
  String get authSendResetLink => 'リセットリンクを送る';

  @override
  String get authEmailSent => 'メールを送ったよ！';

  @override
  String authResetLinkSentTo(String email) {
    return '$email にパスワードリセットリンクを送ったよ。メール内のリンクをクリックしてパスワードを更新してね。';
  }

  @override
  String get authSignInButton => 'サインイン';

  @override
  String get authVerificationErrorTimeout => '認証がタイムアウトした。もう一回登録を試してみて。';

  @override
  String get authVerificationErrorMissingCode => '認証がうまくいかなかった — 認可コードがないよ。';

  @override
  String get authVerificationErrorPollFailed => '認証がうまくいかなかった。もう一回試してみて。';

  @override
  String get authVerificationErrorNetworkExchange =>
      'サインイン中にネットワークエラーが起きた。もう一回試してみて。';

  @override
  String get authVerificationErrorOAuthExchange => '認証がうまくいかなかった。もう一回登録を試してみて。';

  @override
  String get authVerificationErrorSignInFailed =>
      'サインインがうまくいかなかった。手動でログインしてみて。';

  @override
  String get authVerificationEmailAlreadyRegistered =>
      'このメールアドレスはすでに登録されているよ。代わりにログインしてね。';

  @override
  String get authInviteErrorAlreadyUsed =>
      'その招待コードはもう使えないよ。招待コードに戻るか、ウェイトリストに参加するか、サポートに連絡してね。';

  @override
  String get authInviteErrorInvalid =>
      'その招待コードは今は使えないよ。招待コードに戻るか、ウェイトリストに参加するか、サポートに連絡してね。';

  @override
  String get authInviteErrorTemporary =>
      '今は招待を確認できなかった。招待コードに戻ってもう一回試すか、サポートに連絡してね。';

  @override
  String get authInviteErrorUnknown =>
      '招待を有効にできなかった。招待コードに戻るか、ウェイトリストに参加するか、サポートに連絡してね。';

  @override
  String get shareSheetSave => '保存';

  @override
  String get shareSheetSaveToGallery => 'ギャラリーに保存';

  @override
  String get shareSheetSaveWithWatermark => 'ウォーターマーク付きで保存';

  @override
  String get shareSheetSaveVideo => '動画を保存';

  @override
  String get shareSheetAddToClips => 'クリップに追加';

  @override
  String get shareSheetNameClipTitle => 'このクリップに名前を付ける';

  @override
  String get shareSheetNameClipSubtitle => 'ライブラリで見つけやすい名前を付けてね。';

  @override
  String get shareSheetClipTitleLabel => 'クリップのタイトル';

  @override
  String get shareSheetSaveClip => 'クリップを保存';

  @override
  String shareSheetSavedClipToClips(String title) {
    return '「$title」をクリップに保存したよ';
  }

  @override
  String get shareSheetUntitledClip => '無題のクリップ';

  @override
  String get shareSheetAddToClipsFailed => 'クリップに追加できませんでした';

  @override
  String get shareSheetAddToList => 'リストに追加';

  @override
  String get shareSheetCopy => 'コピー';

  @override
  String get shareSheetShareVia => '他のアプリで共有';

  @override
  String get shareSheetReport => '報告';

  @override
  String get shareSheetEventJson => 'イベント JSON';

  @override
  String get shareSheetEventId => 'イベント ID';

  @override
  String get shareSheetMoreActions => 'その他のアクション';

  @override
  String get watermarkDownloadSavedToCameraRoll => 'カメラロールに保存したよ';

  @override
  String get watermarkDownloadShare => '共有';

  @override
  String get watermarkDownloadDone => '完了';

  @override
  String get watermarkDownloadPhotosAccessNeeded => '写真へのアクセスが必要';

  @override
  String get watermarkDownloadPhotosAccessDescription =>
      '動画を保存するには、設定で写真へのアクセスを許可してね。';

  @override
  String get watermarkDownloadOpenSettings => '設定を開く';

  @override
  String get watermarkDownloadNotNow => '今はいい';

  @override
  String get watermarkDownloadFailed => 'ダウンロードがうまくいかなかった';

  @override
  String get watermarkDownloadDismiss => '閉じる';

  @override
  String get watermarkDownloadStageDownloading => '動画をダウンロード中';

  @override
  String get watermarkDownloadStageWatermarking => 'ウォーターマークを追加中';

  @override
  String get watermarkDownloadStageSaving => 'カメラロールに保存中';

  @override
  String get watermarkDownloadStageDownloadingDesc => 'ネットワークから動画を取ってるよ...';

  @override
  String get watermarkDownloadStageWatermarkingDesc =>
      'Divine ウォーターマークを追加してるよ...';

  @override
  String get watermarkDownloadStageSavingDesc =>
      'ウォーターマーク付き動画をカメラロールに保存してるよ...';

  @override
  String get uploadProgressVideoUpload => '動画アップロード';

  @override
  String get uploadProgressPause => '一時停止';

  @override
  String get uploadProgressResume => '再開';

  @override
  String get uploadProgressGoBack => '戻る';

  @override
  String uploadProgressRetryWithCount(int count) {
    return 'もう一回 (残り$count回)';
  }

  @override
  String get uploadProgressDelete => '削除';

  @override
  String uploadProgressDaysAgo(int count) {
    return '$count日前';
  }

  @override
  String uploadProgressHoursAgo(int count) {
    return '$count時間前';
  }

  @override
  String uploadProgressMinutesAgo(int count) {
    return '$count分前';
  }

  @override
  String get uploadProgressJustNow => 'たった今';

  @override
  String uploadProgressUploadingPercent(int percent) {
    return 'アップロード中 $percent%';
  }

  @override
  String uploadProgressPausedPercent(int percent) {
    return '一時停止 $percent%';
  }

  @override
  String get shareMenuTitle => '動画を共有';

  @override
  String get shareMenuReportAiContent => 'AI コンテンツを報告';

  @override
  String get shareMenuReportAiContentSubtitle => 'AI 生成の疑いがあるコンテンツをサクッと報告';

  @override
  String get shareMenuReportingAiContent => 'AI コンテンツを報告中...';

  @override
  String shareMenuFailedToReportContent(String error) {
    return 'コンテンツの報告がうまくいかなかった: $error';
  }

  @override
  String shareMenuFailedToReportAiContent(String error) {
    return 'AI コンテンツの報告がうまくいかなかった: $error';
  }

  @override
  String get shareMenuVideoStatus => '動画のステータス';

  @override
  String get shareMenuViewAllLists => 'すべてのリストを見る →';

  @override
  String get shareMenuShareWith => '共有相手';

  @override
  String get shareMenuShareViaOtherApps => '他のアプリで共有';

  @override
  String get shareMenuShareViaOtherAppsSubtitle => '他のアプリで共有するかリンクをコピー';

  @override
  String get shareMenuSaveToGallery => 'ギャラリーに保存';

  @override
  String get shareMenuSaveOriginalSubtitle => 'オリジナル動画をカメラロールに保存';

  @override
  String get shareMenuSaveWithWatermark => 'ウォーターマーク付きで保存';

  @override
  String get shareMenuSaveVideo => '動画を保存';

  @override
  String get shareMenuDownloadWithWatermark => 'Divine ウォーターマーク付きでダウンロード';

  @override
  String get shareMenuSaveVideoSubtitle => '動画をカメラロールに保存';

  @override
  String get shareMenuLists => 'リスト';

  @override
  String get shareMenuAddToList => 'リストに追加';

  @override
  String get shareMenuAddToListSubtitle => 'キュレートしたリストに追加';

  @override
  String get shareMenuCreateNewList => '新しいリストを作る';

  @override
  String get shareMenuCreateNewListSubtitle => '新しいキュレーションコレクションを始めよう';

  @override
  String get shareMenuRemovedFromList => 'リストから削除したよ';

  @override
  String get shareMenuFailedToRemoveFromList => 'リストからの削除がうまくいかなかった';

  @override
  String get shareMenuBookmarks => 'ブックマーク';

  @override
  String get shareMenuAddToBookmarks => 'ブックマークに追加';

  @override
  String get shareMenuAddToBookmarksSubtitle => 'あとで見るために保存';

  @override
  String get shareMenuAddToBookmarkSet => 'ブックマークセットに追加';

  @override
  String get shareMenuAddToBookmarkSetSubtitle => 'コレクションに整理';

  @override
  String get shareMenuFollowSets => 'フォローセット';

  @override
  String get shareMenuCreateFollowSet => 'フォローセットを作る';

  @override
  String get shareMenuCreateFollowSetSubtitle => 'このクリエイターで新しいコレクションを始めよう';

  @override
  String get shareMenuAddToFollowSet => 'フォローセットに追加';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    return 'フォローセット$count個あるよ';
  }

  @override
  String get peopleListsAddToList => 'リストに追加';

  @override
  String get peopleListsAddToListSubtitle => 'このクリエイターをリストに追加する';

  @override
  String get peopleListsSheetTitle => 'リストに追加';

  @override
  String get peopleListsEmptyTitle => 'リストがありません';

  @override
  String get peopleListsEmptySubtitle => 'リストを作成して人々をグループ化しましょう。';

  @override
  String get peopleListsCreateList => 'リストを作成';

  @override
  String get peopleListsNewListTitle => '新しいリスト';

  @override
  String get peopleListsRouteTitle => 'ピープルリスト';

  @override
  String get peopleListsListNameLabel => 'リスト名';

  @override
  String get peopleListsListNameHint => '仲の良い友達';

  @override
  String get peopleListsCreateButton => '作成';

  @override
  String get peopleListsAddPeopleTitle => 'ユーザーを追加';

  @override
  String get peopleListsAddPeopleTooltip => 'ユーザーを追加';

  @override
  String get peopleListsAddPeopleSemanticLabel => 'リストにユーザーを追加';

  @override
  String get peopleListsListNotFoundTitle => 'リストが見つかりません';

  @override
  String get peopleListsListNotFoundSubtitle => 'リストが見つかりません。削除された可能性があります。';

  @override
  String get peopleListsListDeletedSubtitle => 'このリストは削除された可能性があります。';

  @override
  String get peopleListsNoPeopleTitle => 'このリストにユーザーはいません';

  @override
  String get peopleListsNoPeopleSubtitle => '始めるにはユーザーを追加してください';

  @override
  String get peopleListsNoVideosTitle => 'まだ動画がありません';

  @override
  String get peopleListsNoVideosSubtitle => 'リストメンバーの動画がここに表示されます';

  @override
  String get peopleListsNoVideosAvailable => '利用可能な動画がありません';

  @override
  String get peopleListsFailedToLoadVideos => '動画の読み込みに失敗しました';

  @override
  String get peopleListsVideoNotAvailable => '動画は利用できません';

  @override
  String get peopleListsBackToGridTooltip => 'グリッドに戻る';

  @override
  String get peopleListsErrorLoadingVideos => '動画の読み込みエラー';

  @override
  String get peopleListsNoPeopleToAdd => '追加できるユーザーがいません。';

  @override
  String peopleListsAddToListName(String name) {
    return '$nameに追加';
  }

  @override
  String get peopleListsAddPeopleSearchHint => 'ユーザーを検索';

  @override
  String get peopleListsAddPeopleError => 'ユーザーを読み込めませんでした。もう一度お試しください。';

  @override
  String get peopleListsAddPeopleRetry => '再試行';

  @override
  String get peopleListsAddButton => '追加';

  @override
  String peopleListsAddButtonWithCount(int count) {
    return '$count人追加';
  }

  @override
  String peopleListsInNLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件のリストに含まれています',
    );
    return '$_temp0';
  }

  @override
  String peopleListsRemoveConfirmTitle(String name) {
    return '$nameを削除しますか？';
  }

  @override
  String get peopleListsRemoveConfirmBody => 'このリストから削除されます。';

  @override
  String get peopleListsRemove => '削除';

  @override
  String peopleListsRemovedFromList(String name) {
    return '$nameをリストから削除しました';
  }

  @override
  String get peopleListsUndo => '元に戻す';

  @override
  String peopleListsProfileLongPressHint(String name) {
    return '$nameのプロフィール。長押しで削除。';
  }

  @override
  String peopleListsViewProfileHint(String name) {
    return '$nameのプロフィールを表示';
  }

  @override
  String get shareMenuAddedToBookmarks => 'ブックマークに追加したよ！';

  @override
  String get shareMenuFailedToAddBookmark => 'ブックマークの追加がうまくいかなかった';

  @override
  String shareMenuCreatedListAndAddedVideo(String name) {
    return 'リスト「$name」を作って動画を追加したよ';
  }

  @override
  String get shareMenuManageContent => 'コンテンツを管理';

  @override
  String get shareMenuEditVideo => '動画を編集';

  @override
  String get shareMenuEditVideoSubtitle => 'タイトル、説明、ハッシュタグを更新';

  @override
  String get shareMenuDeleteVideo => '動画を削除';

  @override
  String get shareMenuDeleteVideoSubtitle => 'このコンテンツを完全に削除';

  @override
  String get shareMenuDeleteWarning =>
      'すべてのリレーに削除リクエスト (NIP-09) を送るよ。一部のリレーではキャッシュが残ることもあるよ。';

  @override
  String get shareMenuVideoInTheseLists => 'この動画が入ってるリスト:';

  @override
  String shareMenuVideoCount(int count) {
    return '$count本の動画';
  }

  @override
  String get shareMenuClose => '閉じる';

  @override
  String get shareMenuDeleteConfirmation => 'この動画を本当に削除する?';

  @override
  String get shareMenuCancel => 'キャンセル';

  @override
  String get shareMenuDelete => '削除';

  @override
  String get shareMenuDeletingContent => 'コンテンツを削除中...';

  @override
  String shareMenuFailedToDeleteContent(String error) {
    return 'コンテンツの削除がうまくいかなかった: $error';
  }

  @override
  String get shareMenuDeleteRequestSent => '削除リクエストを送ったよ';

  @override
  String get shareMenuDeleteFailedNotInitialized =>
      '削除の準備がまだだよ。少し待ってからもう一度試してね。';

  @override
  String get shareMenuDeleteFailedNotOwner => '自分の動画だけ削除できるよ。';

  @override
  String get shareMenuDeleteFailedNotAuthenticated => 'もう一度ログインしてから削除してね。';

  @override
  String get shareMenuDeleteFailedCouldNotSign => '削除リクエストに署名できなかったよ。もう一度試してね。';

  @override
  String get shareMenuDeleteFailedRelayRejected =>
      'The relay wouldn\'t accept this delete request. Try again in a moment.';

  @override
  String get shareMenuDeleteFailedRelayNoResponse =>
      'Couldn\'t reach the relay. Check your connection and try again.';

  @override
  String get shareMenuDeleteFailedGeneric => 'この動画を削除できなかったよ。もう一度試してね。';

  @override
  String get shareMenuFollowSetName => 'フォローセット名';

  @override
  String get shareMenuFollowSetNameHint => '例: クリエイター、ミュージシャンなど';

  @override
  String get shareMenuDescriptionOptional => '説明 (任意)';

  @override
  String get shareMenuCreate => '作成';

  @override
  String shareMenuCreatedFollowSetAndAddedCreator(String name) {
    return 'フォローセット「$name」を作ってクリエイターを追加したよ';
  }

  @override
  String get shareMenuDone => '完了';

  @override
  String get shareMenuEditTitle => 'タイトル';

  @override
  String get shareMenuEditTitleHint => '動画のタイトルを入れてね';

  @override
  String get shareMenuEditDescription => '説明';

  @override
  String get shareMenuEditDescriptionHint => '動画の説明を入れてね';

  @override
  String get shareMenuEditHashtags => 'ハッシュタグ';

  @override
  String get shareMenuEditHashtagsHint => 'カンマ, 区切り, ハッシュタグ';

  @override
  String get shareMenuEditMetadataNote => '注意: 編集できるのはメタデータだけだよ。動画の中身は変えられないよ。';

  @override
  String get shareMenuDeleting => '削除中...';

  @override
  String get shareMenuUpdate => '更新';

  @override
  String get shareMenuChangeCover => 'カバーを変更';

  @override
  String get shareMenuCoverUploadingBackground => 'サムネイルをバックグラウンドでアップロード中';

  @override
  String get shareMenuVideoUpdated => '動画を更新したよ';

  @override
  String shareMenuVideoUpdatedWithInviteFailures(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件のコラボレーター招待が送信されませんでした。',
      one: '1件のコラボレーター招待が送信されませんでした。',
    );
    return '動画を更新しましたが、$_temp0';
  }

  @override
  String shareMenuFailedToUpdateVideo(String error) {
    return '動画の更新がうまくいかなかった: $error';
  }

  @override
  String shareMenuFailedToDeleteVideo(String error) {
    return '動画の削除がうまくいかなかった: $error';
  }

  @override
  String get shareMenuDeleteVideoQuestion => '動画を削除する?';

  @override
  String get shareMenuDeleteRelayWarning =>
      'リレーに削除リクエストを送るよ。注意: 一部のリレーにはキャッシュが残ることもあるよ。';

  @override
  String get shareMenuVideoDeletionRequested => '動画の削除をリクエストしたよ';

  @override
  String get shareMenuContentLabels => 'コンテンツラベル';

  @override
  String get shareMenuAddContentLabels => 'コンテンツラベルを追加';

  @override
  String get shareMenuClearAll => 'すべてクリア';

  @override
  String get shareMenuCollaborators => 'コラボレーター';

  @override
  String get shareMenuAddCollaborator => 'コラボレーターを追加';

  @override
  String shareMenuMutualFollowRequired(String name) {
    return 'コラボレーターとして追加するには、$nameと相互フォローになってる必要があるよ。';
  }

  @override
  String get shareMenuLoading => '読み込み中...';

  @override
  String get shareMenuInspiredBy => 'インスパイア元';

  @override
  String get shareMenuAddInspirationCredit => 'インスピレーションクレジットを追加';

  @override
  String get shareMenuCreatorCannotBeReferenced => 'このクリエイターは参照できないよ。';

  @override
  String get shareMenuUnknown => '不明';

  @override
  String get shareMenuCreateBookmarkSet => 'ブックマークセットを作る';

  @override
  String get shareMenuSetName => 'セット名';

  @override
  String get shareMenuSetNameHint => '例: お気に入り、あとで見るなど';

  @override
  String get shareMenuCreateNewSet => '新しいセットを作る';

  @override
  String get shareMenuStartNewBookmarkCollection => '新しいブックマークコレクションを始めよう';

  @override
  String get shareMenuNoBookmarkSets => 'ブックマークセットはまだないよ。最初のセットを作ろう！';

  @override
  String get shareMenuError => 'エラー';

  @override
  String get shareMenuFailedToLoadBookmarkSets => 'ブックマークセットの読み込みがうまくいかなかった';

  @override
  String shareMenuCreatedSetAndAddedVideo(String name) {
    return '「$name」を作って動画を追加したよ';
  }

  @override
  String get shareMenuUseThisSound => 'このサウンドを使う';

  @override
  String get shareMenuOriginalSound => 'オリジナルサウンド';

  @override
  String get authSessionExpired => 'セッションが切れちゃった。もう一回サインインしてね。';

  @override
  String get authSignInFailed => 'サインインがうまくいかなかった。もう一回試してみて。';

  @override
  String get localeAppLanguage => 'アプリの言語';

  @override
  String get localeDeviceDefault => 'デバイスの既定';

  @override
  String get localeSelectLanguage => '言語を選ぶ';

  @override
  String get webAuthNotSupportedSecureMode =>
      'セキュアモードではウェブ認証は対応してないよ。安全な鍵管理にはモバイルアプリを使ってね。';

  @override
  String webAuthIntegrationFailed(String error) {
    return '認証連携がうまくいかなかった: $error';
  }

  @override
  String webAuthUnexpectedError(String error) {
    return '予期しないエラー: $error';
  }

  @override
  String get webAuthEnterBunkerUri => 'bunker URI を入れてね';

  @override
  String get webAuthConnectTitle => 'Divine に接続';

  @override
  String get webAuthChooseMethod => 'Nostr 認証方法を選んでね';

  @override
  String get webAuthBrowserExtension => 'ブラウザ拡張機能';

  @override
  String get webAuthRecommended => 'おすすめ';

  @override
  String get webAuthNsecBunker => 'nsec bunker';

  @override
  String get webAuthConnectRemoteSigner => 'リモート署名に接続';

  @override
  String get webAuthBunkerHint => 'bunker://pubkey?relay=wss://...';

  @override
  String get webAuthPasteFromClipboard => 'クリップボードから貼り付け';

  @override
  String get webAuthConnectToBunker => 'Bunker に接続';

  @override
  String get webAuthNewToNostr => 'Nostr は初めて?';

  @override
  String get webAuthNostrHelp =>
      '一番簡単なのは Alby や nos2x みたいなブラウザ拡張をインストールする方法だよ。安全なリモート署名なら nsec bunker を使ってね。';

  @override
  String get soundsTitle => 'サウンド';

  @override
  String get soundsSearchHint => 'サウンドを検索...';

  @override
  String get soundsPreviewUnavailable => 'サウンドをプレビューできない - 音声がないよ';

  @override
  String soundsPreviewFailed(String error) {
    return 'プレビューの再生がうまくいかなかった: $error';
  }

  @override
  String get soundsFeaturedSounds => '注目のサウンド';

  @override
  String get soundsTrendingSounds => 'トレンドのサウンド';

  @override
  String get soundsAllSounds => 'すべてのサウンド';

  @override
  String get soundsSearchResults => '検索結果';

  @override
  String get soundsNoSoundsAvailable => '使えるサウンドがないよ';

  @override
  String get soundsNoSoundsDescription => 'クリエイターが音声を共有するとここに出るよ';

  @override
  String get soundsNoSoundsFound => 'サウンドが見つからない';

  @override
  String get soundsNoSoundsFoundDescription => '別のキーワードで検索してみて';

  @override
  String get soundsSavedToLibrary => 'サウンドに保存しました';

  @override
  String get soundsAlreadySavedToLibrary => 'すでにサウンドにあります';

  @override
  String get soundsSavedLibraryTitle => 'マイサウンド';

  @override
  String get soundsSavedEmptyTitle => '保存されたサウンドはまだありません';

  @override
  String get soundsSavedEmptyDescription => '動画でサウンドを使用をタップして、ここに保存します。';

  @override
  String get soundsAvailabilityPrivate => 'プライベート';

  @override
  String get soundsAvailabilityCommunity => 'コミュニティ';

  @override
  String get soundsRemoveSavedSound => 'サウンドを削除';

  @override
  String get soundsRemovedFromLibrary => 'サウンドから削除しました';

  @override
  String get soundsFailedToLoad => 'サウンドの読み込みがうまくいかなかった';

  @override
  String get soundsRetry => 'もう一回';

  @override
  String get soundsScreenLabel => 'サウンド画面';

  @override
  String get profileTitle => 'プロフィール';

  @override
  String get profileRefresh => '更新';

  @override
  String get profileRefreshLabel => 'プロフィールを更新';

  @override
  String get profileMoreOptions => 'その他のオプション';

  @override
  String profileBlockedUser(String name) {
    return '$nameをブロックしたよ';
  }

  @override
  String profileUnblockedUser(String name) {
    return '$nameのブロックを解除したよ';
  }

  @override
  String profileUnfollowedUser(String name) {
    return '$nameのフォローを解除したよ';
  }

  @override
  String profileError(String error) {
    return 'エラー: $error';
  }

  @override
  String get profileFeedError => 'Couldn\'t load videos.';

  @override
  String get profileFeedLoadMoreError =>
      'Couldn\'t load more videos. Pull to refresh.';

  @override
  String get notificationsTabAll => 'すべて';

  @override
  String get notificationsTabLikes => 'いいね';

  @override
  String get notificationsTabComments => 'コメント';

  @override
  String get notificationsTabFollows => 'フォロー';

  @override
  String get notificationsTabReposts => 'リポスト';

  @override
  String get notificationsFailedToLoad => '通知の読み込みがうまくいかなかった';

  @override
  String get notificationsRetry => 'もう一回';

  @override
  String get notificationsRefreshError => '更新できませんでした — 既存の通知を表示しています';

  @override
  String get notificationsCheckingNew => '新しい通知をチェック中';

  @override
  String get notificationsNoneYet => '通知はまだないよ';

  @override
  String notificationsNoneForType(String type) {
    return '$typeの通知はないよ';
  }

  @override
  String get notificationsEmptyDescription => '誰かがあなたのコンテンツに反応したらここに出るよ';

  @override
  String get notificationsUnreadPrefix => '未読の通知';

  @override
  String notificationsBadgeUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '未読の通知が$count件',
      one: '未読の通知が1件',
    );
    return '$_temp0';
  }

  @override
  String notificationsViewProfileSemanticLabel(String displayName) {
    return '$displayNameさんのプロフィールを開く';
  }

  @override
  String get notificationsViewProfilesSemanticLabel => 'プロフィールを開く';

  @override
  String notificationsVideoThumbnailFor(String title) {
    return '$titleの動画サムネイル';
  }

  @override
  String get notificationsVideoThumbnail => '動画のサムネイル';

  @override
  String notificationsLoadingType(String type) {
    return '$typeの通知を読み込み中...';
  }

  @override
  String get notificationsInviteSingular => '友達に送れる招待が1つあるよ！';

  @override
  String notificationsInvitePlural(int count) {
    return '友達に送れる招待が$count個あるよ！';
  }

  @override
  String get notificationsVideoNotFound => '動画が見つからない';

  @override
  String get notificationsVideoUnavailable => '動画を見れないよ';

  @override
  String get notificationsFromNotification => '通知から';

  @override
  String get feedFailedToLoadVideos => '動画の読み込みがうまくいかなかった';

  @override
  String get feedRetry => 'もう一回';

  @override
  String get feedNoFollowedUsers => 'まだ誰もフォローしてないよ。\n誰かをフォローすると、ここに動画が出るよ。';

  @override
  String get feedModeForYou => 'おすすめ';

  @override
  String get feedModeNew => '新着';

  @override
  String get feedModeFollowing => 'フォロー中';

  @override
  String get feedModeClassics => 'クラシック';

  @override
  String feedModeSemanticLabel(String label) {
    return 'フィードモード: $label';
  }

  @override
  String videoAuthorSemanticLabel(String displayName) {
    return '動画の作者: $displayName';
  }

  @override
  String get videoAuthorAvatarSemanticLabel => '作者のアバター';

  @override
  String get feedForYouEmpty =>
      'おすすめフィードはまだ空です。\n動画を見つけてクリエイターをフォローし、あなた向けに育てましょう。';

  @override
  String get feedFollowingEmpty =>
      'フォロー中の人の動画はまだありません。\n気に入ったクリエイターを見つけてフォローしましょう。';

  @override
  String get feedLatestEmpty => '新しい動画はまだありません。\nしばらくしてからもう一度確認してください。';

  @override
  String get feedClassicEmpty => 'クラシック動画はまだありません。\nしばらくしてからもう一度確認してください。';

  @override
  String get feedExploreVideos => '動画を探しに行こう';

  @override
  String get feedExternalVideoSlow => '外部動画の読み込みに時間がかかってる';

  @override
  String get feedSkip => 'スキップ';

  @override
  String get feedLoadingMore => '動画をもっと読み込んでるよ…';

  @override
  String get uploadWaitingToUpload => 'アップロード待ち';

  @override
  String get uploadUploadingVideo => '動画をアップロード中';

  @override
  String get uploadProcessingVideo => '動画を処理中';

  @override
  String get uploadProcessingComplete => '処理完了';

  @override
  String get uploadPublishedSuccessfully => '公開したよ';

  @override
  String get uploadFailed => 'アップロードがうまくいかなかった';

  @override
  String get uploadRetrying => 'アップロードを再試行中';

  @override
  String get uploadPaused => 'アップロード一時停止';

  @override
  String uploadPercentComplete(int percent) {
    return '$percent% 完了';
  }

  @override
  String get uploadQueuedMessage => '動画はアップロード待ちだよ';

  @override
  String get uploadUploadingMessage => 'サーバーにアップロード中...';

  @override
  String get uploadProcessingMessage => '動画を処理中 - 数分かかるかも';

  @override
  String get uploadReadyToPublishMessage => '動画の処理が完了、公開の準備OKだよ';

  @override
  String get uploadPublishedMessage => '動画をプロフィールに公開したよ';

  @override
  String get uploadFailedMessage => 'アップロードがうまくいかなかった - もう一回試してみて';

  @override
  String get uploadRetryingMessage => 'アップロードを再試行中...';

  @override
  String get uploadPausedMessage => 'アップロードを一時停止したよ';

  @override
  String get uploadRetryButton => 'もう一回';

  @override
  String uploadRetryFailed(String error) {
    return 'アップロードの再試行がうまくいかなかった: $error';
  }

  @override
  String get userSearchPrompt => 'ユーザーを検索';

  @override
  String get userSearchNoResults => 'ユーザーが見つからない';

  @override
  String get userSearchFailed => '検索がうまくいかなかった';

  @override
  String get userPickerSearchByName => '名前で検索';

  @override
  String get userPickerFilterByNameHint => '名前で絞り込み...';

  @override
  String get userPickerSearchByNameHint => '名前で検索...';

  @override
  String userPickerAlreadyAddedSemantics(String name) {
    return '$name はすでに追加済みです';
  }

  @override
  String userPickerSelectSemantics(String name) {
    return '$name を選択';
  }

  @override
  String userPickerRemoveSelectionSemantics(String name) {
    return '$nameを削除';
  }

  @override
  String get userPickerEmptyFollowListTitle => 'あなたの仲間は外にいる';

  @override
  String get userPickerEmptyFollowListBody =>
      '気の合う人をフォローしよう。相互フォローになればコラボできます。';

  @override
  String get userPickerGoBack => '戻る';

  @override
  String get userPickerTypeNameToSearch => '検索する名前を入力';

  @override
  String get userPickerUnavailable => 'ユーザー検索は現在利用できません。後でもう一度お試しください。';

  @override
  String get userPickerSearchFailedTryAgain => '検索に失敗しました。もう一度お試しください。';

  @override
  String get forgotPasswordTitle => 'パスワードをリセット';

  @override
  String get forgotPasswordDescription => 'メールアドレスを入れてね。パスワードをリセットするリンクを送るよ。';

  @override
  String get forgotPasswordEmailLabel => 'メールアドレス';

  @override
  String get forgotPasswordCancel => 'キャンセル';

  @override
  String get forgotPasswordSendLink => 'リセットリンクを送る';

  @override
  String get ageVerificationContentWarning => 'コンテンツ警告';

  @override
  String get ageVerificationTitle => '年齢確認';

  @override
  String get ageVerificationAdultDescription =>
      'このコンテンツは成人向け素材が含まれる可能性があるよ。閲覧には18歳以上である必要があるよ。';

  @override
  String get ageVerificationCreationDescription =>
      'カメラでコンテンツを作るには、16歳以上である必要があるよ。';

  @override
  String get ageVerificationAdultQuestion => '18歳以上?';

  @override
  String get ageVerificationCreationQuestion => '16歳以上?';

  @override
  String get ageVerificationNo => 'いいえ';

  @override
  String get ageVerificationYes => 'はい';

  @override
  String get shareLinkCopied => 'リンクをコピーしたよ';

  @override
  String get shareFailedToCopy => 'リンクのコピーがうまくいかなかった';

  @override
  String get shareVideoSubject => 'Divine でこの動画見てみて';

  @override
  String get shareFailedToShare => '共有がうまくいかなかった';

  @override
  String get shareVideoTitle => '動画を共有';

  @override
  String get shareToApps => 'アプリで共有';

  @override
  String get shareToAppsSubtitle => 'メッセージアプリや SNS で共有';

  @override
  String get shareCopyWebLink => 'ウェブリンクをコピー';

  @override
  String get shareCopyWebLinkSubtitle => '共有できるウェブリンクをコピー';

  @override
  String get shareCopyNostrLink => 'Nostr リンクをコピー';

  @override
  String get shareCopyNostrLinkSubtitle => 'Nostr クライアント用の nevent リンクをコピー';

  @override
  String get navHome => 'ホーム';

  @override
  String get navExplore => '探索';

  @override
  String get navInbox => '受信箱';

  @override
  String get navProfile => 'プロフィール';

  @override
  String get navSearch => '検索';

  @override
  String get navSearchTooltip => '検索';

  @override
  String get navMyProfile => 'マイプロフィール';

  @override
  String get navNotifications => '通知';

  @override
  String get navOpenCamera => 'カメラを開く';

  @override
  String get navUnknown => '不明';

  @override
  String get navExploreClassics => 'クラシック';

  @override
  String get navExploreNewVideos => '新着動画';

  @override
  String get navExploreTrending => 'トレンド';

  @override
  String get navExploreForYou => 'おすすめ';

  @override
  String get navExploreLists => 'リスト';

  @override
  String get routeErrorTitle => 'エラー';

  @override
  String get routeInvalidHashtag => '無効なハッシュタグ';

  @override
  String get routeInvalidConversationId => '無効な会話 ID';

  @override
  String get routeInvalidRequestId => '無効なリクエスト ID';

  @override
  String get routeInvalidListId => '無効なリスト ID';

  @override
  String get routeInvalidUserId => '無効なユーザー ID';

  @override
  String get routeInvalidVideoId => '無効な動画 ID';

  @override
  String get routeInvalidSoundId => '無効なサウンド ID';

  @override
  String get routeInvalidCategory => '無効なカテゴリ';

  @override
  String get routeNoVideosToDisplay => '表示する動画がないよ';

  @override
  String get routeInvalidProfileId => '無効なプロフィール ID';

  @override
  String get routeUnknownPath => 'このページはアプリ内にありません。';

  @override
  String get routeDefaultListName => 'リスト';

  @override
  String get supportTitle => 'サポート';

  @override
  String get supportContactSupport => 'サポートに連絡';

  @override
  String get supportContactSupportSubtitle => '会話を始めたり、過去のメッセージを確認するよ';

  @override
  String get supportReportBug => 'バグを報告';

  @override
  String get supportReportBugSubtitle => 'アプリの技術的な問題';

  @override
  String get supportRequestFeature => '機能リクエスト';

  @override
  String get supportRequestFeatureSubtitle => '改善や新機能の提案';

  @override
  String get supportSaveLogs => 'ログを保存';

  @override
  String get supportSaveLogsSubtitle => '手動送信用にログをファイルにエクスポート';

  @override
  String get supportFaq => 'よくある質問';

  @override
  String get supportFaqSubtitle => 'よくある質問と回答';

  @override
  String get supportProofMode => 'ProofMode';

  @override
  String get supportProofModeSubtitle => '検証と真正性について学ぼう';

  @override
  String get supportLoginRequired => 'サポートに連絡するにはログインしてね';

  @override
  String get supportExportingLogs => 'ログをエクスポート中...';

  @override
  String get supportExportLogsFailed => 'ログのエクスポートがうまくいかなかった';

  @override
  String supportLogsSavedTo(String path) {
    return 'ログを$pathに保存しました';
  }

  @override
  String get supportRevealLogsAction => 'フォルダで表示';

  @override
  String get supportChatNotAvailable => 'サポートチャットは今使えないよ';

  @override
  String get supportCouldNotOpenMessages => 'サポートメッセージが開けなかった';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return '$pageNameが開けなかった';
  }

  @override
  String supportErrorOpeningPage(String pageName, Object error) {
    return '$pageNameを開く時にエラー: $error';
  }

  @override
  String get reportTitle => 'コンテンツを報告';

  @override
  String get reportWhyReporting => 'このコンテンツを報告する理由は?';

  @override
  String get reportPolicyNotice =>
      'Divine はコンテンツの報告に24時間以内に対応して、問題のあるコンテンツを削除し、違反ユーザーを排除するよ。';

  @override
  String get reportAdditionalDetails => '追加の詳細 (任意)';

  @override
  String get reportBlockUser => 'このユーザーをブロック';

  @override
  String get reportCancel => 'キャンセル';

  @override
  String get reportSubmit => '報告';

  @override
  String get reportSelectReason => '報告する理由を選んでね';

  @override
  String get reportOtherRequiresDetails =>
      'Please describe the issue when selecting Other';

  @override
  String get reportDetailsRequired => 'Please describe the issue';

  @override
  String get reportReasonSpam => 'スパムや迷惑なコンテンツ';

  @override
  String get reportReasonSpamSubtitle => '迷惑または繰り返しのコンテンツ';

  @override
  String get reportReasonHarassment => '嫌がらせ、いじめ、脅迫';

  @override
  String get reportReasonHarassmentSubtitle => '有害で望まない返信やメンション';

  @override
  String get reportReasonViolence => '暴力的・過激なコンテンツ';

  @override
  String get reportReasonViolenceSubtitle => '暴力的、過激、または有害なコンテンツ';

  @override
  String get reportReasonSexualContent => '性的・成人向けコンテンツ';

  @override
  String get reportReasonSexualContentSubtitle => 'ヌード、ポルノ、または露骨なコンテンツ';

  @override
  String get reportReasonCopyright => '著作権侵害';

  @override
  String get reportReasonCopyrightSubtitle => '知的財産の無許可使用';

  @override
  String get reportReasonFalseInfo => '虚偽の情報';

  @override
  String get reportReasonFalseInfoSubtitle => '誤解を招くまたは虚偽の主張';

  @override
  String get reportReasonChildSafety => '子どもの安全に関する違反';

  @override
  String get reportReasonChildSafetySubtitle => '未成年の安全に関する一般的な懸念';

  @override
  String get reportReasonCsam => '児童性的虐待';

  @override
  String get reportReasonCsamSubtitle => '未成年者への性的虐待を描写したコンテンツ';

  @override
  String get reportReasonUnderageUser => 'ユーザーが16歳未満に見える';

  @override
  String get reportReasonUnderageUserSubtitle => 'アカウント所有者が未成年に見える';

  @override
  String get reportReasonAiGenerated => 'AI 生成コンテンツ';

  @override
  String get reportReasonAiGeneratedSubtitle => 'AI生成と疑われるコンテンツ';

  @override
  String get reportReasonOther => 'その他のポリシー違反';

  @override
  String get reportReasonOtherSubtitle => '上記に記載されていない違反';

  @override
  String reportFailed(Object error) {
    return 'コンテンツの報告がうまくいかなかった: $error';
  }

  @override
  String get reportReceivedTitle => '報告を受け付けたよ';

  @override
  String get reportReceivedThankYou => 'Divine を安全に保つために協力してくれてありがとう。';

  @override
  String get reportReceivedReviewNotice =>
      'チームが報告を確認して、適切に対応するね。ダイレクトメッセージでアップデートが届くかも。';

  @override
  String get reportModerationDmDelayed =>
      '今はモデレーションチームに直接連絡できなかったけど、あなたの報告は受け取ったから、あとで確認するね。';

  @override
  String get reportContactModeration => 'モデレーションチームにメッセージを送る';

  @override
  String get reportLearnMore => 'もっと詳しく';

  @override
  String get reportLearnMoreAt => '詳しくはこちら';

  @override
  String get reportSafetyUrl => 'divine.video/safety';

  @override
  String get reportClose => '閉じる';

  @override
  String get listAddToList => 'リストに追加';

  @override
  String listVideoCount(int count) {
    return '$count本の動画';
  }

  @override
  String listPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count人',
      one: '1人',
    );
    return '$_temp0';
  }

  @override
  String get listByAuthorPrefix => '作成者: ';

  @override
  String get listNewList => '新しいリスト';

  @override
  String get listDone => '完了';

  @override
  String get listErrorLoading => 'リストの読み込みに失敗';

  @override
  String listRemovedFrom(String name) {
    return '$nameから削除したよ';
  }

  @override
  String listAddedTo(String name) {
    return '$nameに追加したよ';
  }

  @override
  String get listCreateNewList => '新しいリストを作る';

  @override
  String get listNewPeopleList => '新しい人リスト';

  @override
  String get listCollaboratorsNone => 'なし';

  @override
  String get listAddCollaboratorTitle => 'コラボレーターを追加';

  @override
  String get listCollaboratorSearchHint => 'diVineを検索...';

  @override
  String get listNameLabel => 'リスト名';

  @override
  String get listDescriptionLabel => '説明 (任意)';

  @override
  String get listPublicList => '公開リスト';

  @override
  String get listPublicListSubtitle => 'みんながフォロー・閲覧できるよ';

  @override
  String get listCancel => 'キャンセル';

  @override
  String get listCreate => '作成';

  @override
  String get listCreateFailed => 'リストの作成がうまくいかなかった';

  @override
  String get keyManagementTitle => 'Nostr 鍵';

  @override
  String get keyManagementWhatAreKeys => 'Nostr 鍵って何?';

  @override
  String get keyManagementExplanation =>
      'あなたの Nostr ID は暗号鍵のペアだよ:\n\n• 公開鍵 (npub) はユーザー名みたいなもの - 自由に共有してOK\n• 秘密鍵 (nsec) はパスワードみたいなもの - 秘密にしておいて！\n\nnsec があれば、どの Nostr アプリでもあなたのアカウントにアクセスできるよ。';

  @override
  String get keyManagementImportTitle => '既存の鍵をインポート';

  @override
  String get keyManagementImportSubtitle =>
      'もう Nostr アカウントを持ってる? 秘密鍵 (nsec) を貼り付けてここからアクセスしてね。';

  @override
  String get keyManagementImportButton => '鍵をインポート';

  @override
  String get keyManagementImportWarning => '現在の鍵が置き換えられるよ！';

  @override
  String get keyManagementBackupTitle => '鍵をバックアップ';

  @override
  String get keyManagementBackupSubtitle =>
      '秘密鍵 (nsec) を保存して、他の Nostr アプリでもこのアカウントを使えるようにしよう。';

  @override
  String get keyManagementCopyNsec => '秘密鍵 (nsec) をコピー';

  @override
  String get keyManagementNeverShare => 'nsec は誰にも共有しないで！';

  @override
  String get keyManagementKeycastRemoteSigning =>
      'このアカウントはKeycastで署名します。このデバイスには秘密鍵が保存されていないため、ここでコピーできるnsecはありません。';

  @override
  String get keyManagementPasteKey => '秘密鍵を貼り付けてね';

  @override
  String get keyManagementInvalidFormat => '鍵の形式が正しくないよ。「nsec1」で始める必要があるよ';

  @override
  String get keyManagementConfirmImportTitle => 'この鍵をインポートする?';

  @override
  String get keyManagementConfirmImportBody =>
      '現在のアイデンティティがインポートした鍵に置き換わるよ。\n\n先にバックアップしておかないと、現在の鍵がなくなっちゃうよ。';

  @override
  String get keyManagementImportConfirm => 'インポート';

  @override
  String get keyManagementImportSuccess => '鍵をインポートしたよ！';

  @override
  String keyManagementImportFailed(Object error) {
    return '鍵のインポートがうまくいかなかった: $error';
  }

  @override
  String get keyManagementExportSuccess => '秘密鍵をコピーしたよ！\n\n安全な場所に保管してね。';

  @override
  String keyManagementExportFailed(Object error) {
    return '鍵のエクスポートがうまくいかなかった: $error';
  }

  @override
  String get keyManagementYourPublicKeyLabel => 'あなたの公開鍵 (npub)';

  @override
  String get keyManagementCopyPublicKeyTooltip => '公開鍵をコピー';

  @override
  String get keyManagementPublicKeyCopied => '公開鍵をコピーしたよ';

  @override
  String get profileEditPublicKeyLink => '公開鍵を表示';

  @override
  String get saveOriginalSavedToCameraRoll => 'カメラロールに保存したよ';

  @override
  String get saveOriginalShare => '共有';

  @override
  String get saveOriginalDone => '完了';

  @override
  String get saveOriginalPhotosAccessNeeded => '写真へのアクセスが必要';

  @override
  String get saveOriginalPhotosAccessMessage => '動画を保存するには、設定で写真へのアクセスを許可してね。';

  @override
  String get saveOriginalOpenSettings => '設定を開く';

  @override
  String get saveOriginalNotNow => '今はいい';

  @override
  String get saveOriginalDownloadFailed => 'ダウンロードがうまくいかなかった';

  @override
  String get saveOriginalDismiss => '閉じる';

  @override
  String get saveOriginalDownloadingVideo => '動画をダウンロード中';

  @override
  String get saveOriginalSavingToCameraRoll => 'カメラロールに保存中';

  @override
  String get saveOriginalFetchingVideo => 'ネットワークから動画を取ってるよ...';

  @override
  String get saveOriginalSavingVideo => 'オリジナル動画をカメラロールに保存してるよ...';

  @override
  String get soundTitle => 'サウンド';

  @override
  String get soundOriginalSound => 'オリジナルサウンド';

  @override
  String get soundVideosUsingThisSound => 'このサウンドを使ってる動画';

  @override
  String get soundSourceVideo => '元動画';

  @override
  String get soundNoVideosYet => '動画はまだないよ';

  @override
  String get soundBeFirstToUse => 'このサウンドを最初に使おう！';

  @override
  String get soundFailedToLoadVideos => '動画の読み込みがうまくいかなかった';

  @override
  String get soundRetry => 'もう一回';

  @override
  String get soundVideosUnavailable => '動画を見れないよ';

  @override
  String get soundCouldNotLoadDetails => '動画の詳細を読み込めなかった';

  @override
  String get soundPreview => 'プレビュー';

  @override
  String get soundStop => '停止';

  @override
  String get soundUseSound => 'サウンドを使う';

  @override
  String get soundUntitled => '無題のサウンド';

  @override
  String get soundStopPreview => 'プレビューを停止';

  @override
  String soundPreviewSemanticLabel(String title) {
    return '$titleをプレビュー';
  }

  @override
  String soundViewDetailsSemanticLabel(String title) {
    return '$titleの詳細を表示';
  }

  @override
  String get soundNoVideoCount => '動画はまだないよ';

  @override
  String get soundOneVideo => '1本の動画';

  @override
  String soundVideoCount(int count) {
    return '$count本の動画';
  }

  @override
  String get soundUnableToPreview => 'サウンドをプレビューできない - 音声がないよ';

  @override
  String soundPreviewFailed(Object error) {
    return 'プレビューの再生がうまくいかなかった: $error';
  }

  @override
  String get soundViewSource => '元動画を見る';

  @override
  String get soundCloseTooltip => '閉じる';

  @override
  String get exploreNotExploreRoute => '探索ルートじゃないよ';

  @override
  String get legalTitle => '法的情報';

  @override
  String get legalTermsOfService => '利用規約';

  @override
  String get legalTermsOfServiceSubtitle => 'ご利用条件';

  @override
  String get legalPrivacyPolicy => 'プライバシーポリシー';

  @override
  String get legalPrivacyPolicySubtitle => 'データの取り扱いについて';

  @override
  String get legalSafetyStandards => '安全基準';

  @override
  String get legalSafetyStandardsSubtitle => 'コミュニティガイドラインと安全について';

  @override
  String get legalDmca => 'DMCA';

  @override
  String get legalDmcaSubtitle => '著作権とテイクダウンポリシー';

  @override
  String get legalOpenSourceLicenses => 'オープンソースライセンス';

  @override
  String get legalOpenSourceLicensesSubtitle => 'サードパーティパッケージのクレジット';

  @override
  String get legalAppName => 'Divine';

  @override
  String legalCouldNotOpenPage(String pageName) {
    return '$pageNameが開けなかった';
  }

  @override
  String legalErrorOpeningPage(String pageName, Object error) {
    return '$pageNameを開く時にエラー: $error';
  }

  @override
  String get categoryAction => 'アクション';

  @override
  String get categoryAdventure => 'アドベンチャー';

  @override
  String get categoryAnimals => '動物';

  @override
  String get categoryAnimation => 'アニメ';

  @override
  String get categoryArchitecture => '建築';

  @override
  String get categoryArt => 'アート';

  @override
  String get categoryAutomotive => '自動車';

  @override
  String get categoryAwardShow => '授賞式';

  @override
  String get categoryAwards => 'アワード';

  @override
  String get categoryBaseball => '野球';

  @override
  String get categoryBasketball => 'バスケ';

  @override
  String get categoryBeauty => '美容';

  @override
  String get categoryBeverage => '飲み物';

  @override
  String get categoryCars => '車';

  @override
  String get categoryCelebration => 'お祝い';

  @override
  String get categoryCelebrities => 'セレブ';

  @override
  String get categoryCelebrity => 'セレブ';

  @override
  String get categoryCityscape => '街並み';

  @override
  String get categoryComedy => 'コメディ';

  @override
  String get categoryConcert => 'コンサート';

  @override
  String get categoryCooking => '料理';

  @override
  String get categoryCostume => 'コスチューム';

  @override
  String get categoryCrafts => 'クラフト';

  @override
  String get categoryCrime => '犯罪';

  @override
  String get categoryCulture => '文化';

  @override
  String get categoryDance => 'ダンス';

  @override
  String get categoryDiy => 'DIY';

  @override
  String get categoryDrama => 'ドラマ';

  @override
  String get categoryEducation => '教育';

  @override
  String get categoryEmotional => '感動';

  @override
  String get categoryEmotions => '感情';

  @override
  String get categoryEntertainment => 'エンタメ';

  @override
  String get categoryEvent => 'イベント';

  @override
  String get categoryFamily => '家族';

  @override
  String get categoryFans => 'ファン';

  @override
  String get categoryFantasy => 'ファンタジー';

  @override
  String get categoryFashion => 'ファッション';

  @override
  String get categoryFestival => 'フェス';

  @override
  String get categoryFilm => '映画';

  @override
  String get categoryFitness => 'フィットネス';

  @override
  String get categoryFood => '料理';

  @override
  String get categoryFootball => 'フットボール';

  @override
  String get categoryFurniture => '家具';

  @override
  String get categoryGaming => 'ゲーム';

  @override
  String get categoryGolf => 'ゴルフ';

  @override
  String get categoryGrooming => '身だしなみ';

  @override
  String get categoryGuitar => 'ギター';

  @override
  String get categoryHalloween => 'ハロウィン';

  @override
  String get categoryHealth => '健康';

  @override
  String get categoryHockey => 'ホッケー';

  @override
  String get categoryHoliday => '休日';

  @override
  String get categoryHome => 'ホーム';

  @override
  String get categoryHomeImprovement => 'DIYリフォーム';

  @override
  String get categoryHorror => 'ホラー';

  @override
  String get categoryHospital => '病院';

  @override
  String get categoryHumor => 'ユーモア';

  @override
  String get categoryInteriorDesign => 'インテリア';

  @override
  String get categoryInterview => 'インタビュー';

  @override
  String get categoryKids => 'キッズ';

  @override
  String get categoryLifestyle => 'ライフスタイル';

  @override
  String get categoryMagic => 'マジック';

  @override
  String get categoryMakeup => 'メイク';

  @override
  String get categoryMedical => '医療';

  @override
  String get categoryMusic => '音楽';

  @override
  String get categoryMystery => 'ミステリー';

  @override
  String get categoryNature => '自然';

  @override
  String get categoryNews => 'ニュース';

  @override
  String get categoryOutdoor => 'アウトドア';

  @override
  String get categoryParty => 'パーティー';

  @override
  String get categoryPeople => '人物';

  @override
  String get categoryPerformance => 'パフォーマンス';

  @override
  String get categoryPets => 'ペット';

  @override
  String get categoryPolitics => '政治';

  @override
  String get categoryPrank => 'ドッキリ';

  @override
  String get categoryPranks => 'ドッキリ';

  @override
  String get categoryRealityShow => 'リアリティ番組';

  @override
  String get categoryRelationship => '関係';

  @override
  String get categoryRelationships => '人間関係';

  @override
  String get categoryRomance => 'ロマンス';

  @override
  String get categorySchool => '学校';

  @override
  String get categoryScienceFiction => 'SF';

  @override
  String get categorySelfie => '自撮り';

  @override
  String get categoryShopping => 'ショッピング';

  @override
  String get categorySkateboarding => 'スケボー';

  @override
  String get categorySkincare => 'スキンケア';

  @override
  String get categorySoccer => 'サッカー';

  @override
  String get categorySocialGathering => '集まり';

  @override
  String get categorySocialMedia => 'SNS';

  @override
  String get categorySports => 'スポーツ';

  @override
  String get categoryTalkShow => 'トークショー';

  @override
  String get categoryTech => 'テック';

  @override
  String get categoryTechnology => 'テクノロジー';

  @override
  String get categoryTelevision => 'テレビ';

  @override
  String get categoryToys => 'おもちゃ';

  @override
  String get categoryTransportation => '交通';

  @override
  String get categoryTravel => '旅行';

  @override
  String get categoryUrban => '都市';

  @override
  String get categoryViolence => '暴力';

  @override
  String get categoryVlog => 'ブイログ';

  @override
  String get categoryVlogging => 'ブイログ';

  @override
  String get categoryWrestling => 'プロレス';

  @override
  String get profileSetupUploadStaged => 'アップロードしたよ — 適用するには「保存」をタップしてね';

  @override
  String inboxReportedUser(String displayName) {
    return '$displayNameを報告したよ';
  }

  @override
  String inboxBlockedUser(String displayName) {
    return '$displayNameをブロックしたよ';
  }

  @override
  String inboxUnblockedUser(String displayName) {
    return '$displayNameのブロックを解除したよ';
  }

  @override
  String get inboxRemovedConversation => '会話を削除したよ';

  @override
  String get inboxRestoringMessages => 'メッセージを復元中…';

  @override
  String get inboxEmptyTitle => 'まだメッセージはないよ';

  @override
  String get inboxEmptySubtitle => 'この+ボタン、噛まないよ。';

  @override
  String get inboxActionMute => '会話をミュート';

  @override
  String inboxActionReport(String displayName) {
    return '$displayNameを報告';
  }

  @override
  String inboxActionBlock(String displayName) {
    return '$displayNameをブロック';
  }

  @override
  String inboxActionUnblock(String displayName) {
    return '$displayNameのブロックを解除';
  }

  @override
  String get inboxActionRemove => '会話を削除';

  @override
  String get inboxRemoveConfirmTitle => '会話を削除する？';

  @override
  String inboxRemoveConfirmBody(String displayName) {
    return '$displayNameとの会話が削除されます。この操作は取り消せません。';
  }

  @override
  String get inboxRemoveConfirmConfirm => '削除';

  @override
  String get inboxConversationMuted => '会話をミュートしたよ';

  @override
  String get inboxConversationUnmuted => '会話のミュートを解除したよ';

  @override
  String get inboxCollabInviteCardTitle => 'コラボ招待';

  @override
  String get inboxCollabInviteCardUntitledVideo => '無題の動画';

  @override
  String get clickableTextViewVideoLink => '動画を見る';

  @override
  String get messageExternalLinkDialogTitle => '外部リンクを開きますか？';

  @override
  String messageExternalLinkDialogBody(String url) {
    return 'このリンクは外部サイトに移動します。安全ではない可能性があります:\n\n$url';
  }

  @override
  String get messageExternalLinkDialogOpen => '開く';

  @override
  String get inboxCollabInviteCoPostButton => '共同投稿';

  @override
  String get inboxCollabInviteNotMineButton => '自分のものではない';

  @override
  String get inboxCollabInvitePreviewTitle => '共同投稿の招待';

  @override
  String inboxCollabInvitePreviewTitleFrom(String displayName) {
    return '$displayNameからの共同投稿の招待';
  }

  @override
  String get inboxCollabInviteTimelineConsequence =>
      '共同投稿すると、この動画がコラボレーションとしてあなたのタイムラインに追加されます。';

  @override
  String get inboxCollabInviteAcceptedStatus => '承認済み';

  @override
  String get inboxCollabInviteIgnoredStatus => '無視済み';

  @override
  String get inboxCollabInviteAcceptError => '承認できなかったよ。もう一度試してね。';

  @override
  String get inboxCollabInviteSentStatus => '招待を送ったよ';

  @override
  String get inboxConversationCollabInvitePreview => 'コラボ招待';

  @override
  String collaboratorInviteDmBody(String title, String url) {
    return '$titleのコラボに招待されたよ：$url\n\nOpen diVine to review and accept.';
  }

  @override
  String collaboratorInviteDmBodyUntitled(String url) {
    return '動画のコラボに招待されたよ：$url\n\nOpen diVine to review and accept.';
  }

  @override
  String videoPublishCollaboratorInviteWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'コラボの招待が$count件送信されなかったよ。',
      one: 'コラボの招待が1件送信されなかったよ。',
    );
    return '動画を投稿したよ。でも$_temp0';
  }

  @override
  String get dmSendFailedMessage => 'メッセージを送信できなかった';

  @override
  String get dmSendFailedRetry => 'もう一回';

  @override
  String get dmSendPartialMessage => '送信したけど、ほかのデバイスには同期できなかった';

  @override
  String get dmConversationLoadError => 'メッセージを読み込めなかった';

  @override
  String get dmMessageInputHint => 'Say something…';

  @override
  String get dmMessageBubbleSentHint => '送信したメッセージ';

  @override
  String get dmMessageBubbleReceivedHint => '受信したメッセージ';

  @override
  String get dmMessageBubbleLongPressHint => 'メッセージの操作';

  @override
  String get dmMessageActionCopyText => 'テキストをコピー';

  @override
  String get dmMessageActionCopyVideoUrl => '動画のURLをコピー';

  @override
  String get dmMessageActionDeleteForEveryone => '全員から削除';

  @override
  String get dmMessageActionReport => '報告';

  @override
  String get dmReactionAddCustomA11yLabel => 'Add custom emoji reaction';

  @override
  String dmReelReplyComposerHint(String name) {
    return '$nameさんにメッセージ…';
  }

  @override
  String get dmReelReplyComposerHintSelf => '自分に返信…';

  @override
  String get dmReelReplyComposerSemanticLabel => 'このリールに返信';

  @override
  String get dmReelReplyViewChat => 'チャットを見る';

  @override
  String get dmReelReplyViewChatA11yLabel => 'チャットを開く';

  @override
  String get dmReelReplySentAnnouncement => '返信を送信しました';

  @override
  String dmReelReactionSentAnnouncement(String emoji) {
    return '$emojiでリアクションしました';
  }

  @override
  String get dmReelReplyFailed => '送信できませんでした';

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
  String get dmReactionsSheetTitle => 'リアクション';

  @override
  String get dmReactionsViewA11yLabel => 'リアクションした人を見る';

  @override
  String get dmReactionRemoveAction => '削除';

  @override
  String get dmReactionRetryAction => '再試行';

  @override
  String get dmFormatBold => '太字';

  @override
  String get dmFormatItalic => '斜体';

  @override
  String get dmFormatStrikethrough => '取り消し線';

  @override
  String get dmFormatCode => 'コード';

  @override
  String get dmStatusPending => '送信中';

  @override
  String get dmStatusFailed => '送信できなかった';

  @override
  String get dmStatusDeliveredSelfFailed => '配信済み。ほかのデバイスには同期されない。';

  @override
  String get inboxConversationActionsSheetLabel => '会話の操作';

  @override
  String inboxConversationTileLabel(String displayName) {
    return '$displayNameとの会話';
  }

  @override
  String get inboxConversationTileLongPressHint => '会話の操作を表示';

  @override
  String get reportDialogCancel => 'キャンセル';

  @override
  String get reportDialogReport => '報告';

  @override
  String exploreVideoId(String id) {
    return 'ID: $id';
  }

  @override
  String exploreVideoTitle(String title) {
    return 'タイトル: $title';
  }

  @override
  String exploreVideoCounter(int current, int total) {
    return '動画 $current/$total';
  }

  @override
  String get exploreSearchHint => '検索...';

  @override
  String categoryVideoCount(String count) {
    return '$count本の動画';
  }

  @override
  String discoverListsFailedToUpdateSubscription(String error) {
    return 'サブスクリプションの更新がうまくいかなかった: $error';
  }

  @override
  String get discoverListsTitle => 'リストを見つける';

  @override
  String get discoverListsFailedToLoad => 'リストの読み込みに失敗';

  @override
  String discoverListsFailedToLoadWithError(String error) {
    return 'リストの読み込みに失敗: $error';
  }

  @override
  String get discoverListsLoading => '公開リストを探してるよ...';

  @override
  String get discoverListsEmptyTitle => '公開リストが見つからなかった';

  @override
  String get discoverListsEmptySubtitle => 'あとでまたチェックしてみてね';

  @override
  String get discoverListsByAuthorPrefix => '作成者:';

  @override
  String get curatedListEmptyTitle => 'このリストには動画がないよ';

  @override
  String get curatedListEmptySubtitle => '動画を追加してみよう';

  @override
  String get curatedListLoadingVideos => '動画を読み込み中...';

  @override
  String get curatedListFailedToLoad => 'リストの読み込みに失敗';

  @override
  String get curatedListNoVideosAvailable => '動画がないよ';

  @override
  String get curatedListVideoNotAvailable => '動画は利用できないよ';

  @override
  String get curatedListActionsTooltip => 'リストの操作';

  @override
  String get curatedListUnfollowAction => 'リストのフォローを解除';

  @override
  String get curatedListUnfollowedSnack => 'リストのフォローを解除したよ';

  @override
  String get curatedListUnfollowFailed => 'リストのフォローを解除できなかったよ';

  @override
  String get curatedListDeleteConfirmTitle => 'リストを削除する?';

  @override
  String get curatedListDeleteConfirmBody => 'リストをリレーから削除するよ。リスト内の動画は削除されないよ。';

  @override
  String get curatedListDeletedSnack => 'リストを削除したよ';

  @override
  String get curatedListDeleteFailed => 'リストを削除できなかったよ';

  @override
  String get peopleListsActionsTooltip => 'リストの操作';

  @override
  String get listDeleteAction => 'リストを削除';

  @override
  String get peopleListsDeleteConfirmTitle => 'リストを削除する?';

  @override
  String get peopleListsDeleteConfirmBody =>
      'リストを全員から削除するよ。リストの人たちのフォローは解除されないよ。';

  @override
  String get peopleListsDeleteFailed => 'リストを削除できなかったよ';

  @override
  String get commonRetry => 'もう一回';

  @override
  String get commonSomethingWentWrong => '問題が発生しました';

  @override
  String get commonNext => '次へ';

  @override
  String get commonDelete => '削除';

  @override
  String get commonCancel => 'キャンセル';

  @override
  String get commonBack => '戻る';

  @override
  String get commonClose => '閉じる';

  @override
  String get videoMetadataEditCoverFailedSnackbar =>
      'カバーを更新できませんでした。もう一度お試しください。';

  @override
  String get videoMetadataEditCoverSuccessAnnouncement => 'カバーを更新しました';

  @override
  String get videoMetadataTags => 'タグ';

  @override
  String get videoMetadataExpiration => '有効期限';

  @override
  String get videoMetadataExpirationNotExpire => '期限なし';

  @override
  String get videoMetadataExpirationOneDay => '1日';

  @override
  String get videoMetadataExpirationOneWeek => '1週間';

  @override
  String get videoMetadataExpirationOneMonth => '1か月';

  @override
  String get videoMetadataExpirationOneYear => '1年';

  @override
  String get videoMetadataExpirationOneDecade => '10年';

  @override
  String get videoMetadataContentWarnings => 'コンテンツ警告';

  @override
  String get videoEditorStickers => 'ステッカー';

  @override
  String get trendingTitle => 'トレンド';

  @override
  String get libraryDeleteConfirm => '削除';

  @override
  String get libraryWebUnavailableHeadline => 'ライブラリはモバイルアプリで利用できます';

  @override
  String get libraryWebUnavailableDescription =>
      '下書きとクリップは端末に保存されます。管理するにはスマートフォンでDivineを開いてください。';

  @override
  String get libraryTabDrafts => '下書き';

  @override
  String get libraryTabClips => 'クリップ';

  @override
  String get librarySaveToCameraRollTooltip => 'カメラロールに保存';

  @override
  String get libraryDeleteSelectedClipsTooltip => '選択したクリップを削除';

  @override
  String get librarySelect => '選択';

  @override
  String get librarySortNewestCreation => '作成日が新しい順';

  @override
  String get librarySortOldestCreation => '作成日が古い順';

  @override
  String get librarySortLongestClip => '長いクリップ順';

  @override
  String get librarySortShortestClip => '短いクリップ順';

  @override
  String get librarySortSquareFirst => '正方形を先に';

  @override
  String get librarySortVerticalFirst => '縦長を先に';

  @override
  String get libraryDeleteClipsTitle => 'クリップを削除';

  @override
  String libraryDeleteClipsMessage(int count) {
    return '選択した$count件のクリップを削除しますか？';
  }

  @override
  String get libraryDeleteClipsWarning => 'この操作は取り消せません。動画ファイルは端末から完全に削除されます。';

  @override
  String get libraryPreparingVideo => '動画を準備しています…';

  @override
  String get libraryCreateVideo => '動画を作成';

  @override
  String libraryClipsSavedToDestination(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$destinationに$count件のクリップを保存しました',
      one: '$destinationに1件のクリップを保存しました',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsSavePartialResult(int successCount, int failureCount) {
    return '保存 $successCount、失敗 $failureCount';
  }

  @override
  String libraryGalleryPermissionDenied(String destination) {
    return '$destinationの権限が拒否されました';
  }

  @override
  String libraryClipsDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件のクリップを削除しました',
    );
    return '$_temp0';
  }

  @override
  String get libraryClipsDeletedUndoLabel => '元に戻す';

  @override
  String libraryTrashAutoDeletes(int daysLeft) {
    String _temp0 = intl.Intl.pluralLogic(
      daysLeft,
      locale: localeName,
      other: '$daysLeft日後に自動削除',
      one: '明日自動削除',
      zero: '今日自動削除',
    );
    return '$_temp0';
  }

  @override
  String get libraryCouldNotLoadDrafts => '下書きを読み込めませんでした';

  @override
  String get libraryCouldNotLoadClips => 'クリップを読み込めませんでした';

  @override
  String get libraryOpenErrorDescription => 'ライブラリを開くときに問題が発生しました。もう一度お試しください。';

  @override
  String get libraryNoDraftsYetTitle => 'まだ下書きがありません';

  @override
  String get libraryNoDraftsYetSubtitle => '下書きとして保存した動画がここに表示されます';

  @override
  String get libraryNoClipsYetTitle => 'まだクリップがありません';

  @override
  String get libraryNoClipsYetSubtitle => '録画したクリップがここに表示されます';

  @override
  String get libraryDraftDeletedSnackbar => '下書きを削除しました';

  @override
  String get libraryDraftDeleteFailedSnackbar => '下書きを削除できませんでした';

  @override
  String get libraryDraftActionPost => '投稿';

  @override
  String get libraryDraftActionEdit => '編集';

  @override
  String get libraryDraftActionDelete => '下書きを削除';

  @override
  String get libraryDeleteDraftTitle => '下書きを削除';

  @override
  String libraryDeleteDraftMessage(String title) {
    return '「$title」を削除しますか？';
  }

  @override
  String get libraryDeleteClipTitle => 'クリップを削除';

  @override
  String get libraryDeleteClipMessage => 'このクリップを削除しますか？';

  @override
  String get libraryClipSelectionTitle => 'クリップ';

  @override
  String librarySecondsRemaining(String seconds) {
    return '残り$seconds秒';
  }

  @override
  String get libraryAddClips => '追加';

  @override
  String get libraryRecordVideo => '動画を録画';

  @override
  String videoClipSemanticLabel(String duration) {
    return '動画クリップ、$duration秒';
  }

  @override
  String get videoClipSemanticValueSelected => '選択済み';

  @override
  String get videoClipSemanticValueNotSelected => '未選択';

  @override
  String get videoClipSemanticHintDisabled => '無効';

  @override
  String get videoClipSemanticHintSelect => 'タップして選択、長押しでプレビュー';

  @override
  String get videoClipSemanticHintDeselect => 'タップして選択解除、長押しでプレビュー';

  @override
  String get routerInvalidCreator => '無効なクリエイター';

  @override
  String get routerInvalidHashtagRoute => '無効なハッシュタグルート';

  @override
  String get categoryGalleryCouldNotLoadVideos => '動画を読み込めなかった';

  @override
  String get categoryGalleryNoVideosInCategory => 'このカテゴリーには動画がないよ';

  @override
  String get categoryGallerySortOptionsLabel => 'カテゴリーの並び替えオプション';

  @override
  String get categoryGallerySortHot => '人気';

  @override
  String get categoryGallerySortNew => '新着';

  @override
  String get categoryGallerySortClassic => 'クラシック';

  @override
  String get categoryGallerySortForYou => 'おすすめ';

  @override
  String get categoriesCouldNotLoadCategories => 'カテゴリを読み込めなかった';

  @override
  String get categoriesNoCategoriesAvailable => 'カテゴリーがないよ';

  @override
  String get notificationsEmptyTitle => 'アクティビティはまだないよ';

  @override
  String get notificationsEmptySubtitle => 'あなたのコンテンツに反応があると、ここに出るよ';

  @override
  String get appsPermissionsTitle => '連携の権限';

  @override
  String get appsPermissionsRevoke => '取り消す';

  @override
  String get appsPermissionsEmptyTitle => '保存された連携の権限はないよ';

  @override
  String get appsPermissionsEmptySubtitle => 'アクセス承認を記憶した連携アプリは、ここに表示されるよ。';

  @override
  String nostrAppPermissionTitle(String appName) {
    return '$appNameが承認をリクエストしてるよ';
  }

  @override
  String get nostrAppPermissionDescription =>
      'このアプリは Divine の審査済みサンドボックス経由でアクセスをリクエストしてるよ。';

  @override
  String get nostrAppPermissionOrigin => 'オリジン';

  @override
  String get nostrAppPermissionMethod => 'メソッド';

  @override
  String get nostrAppPermissionCapability => '機能';

  @override
  String get nostrAppPermissionEventKind => 'イベントの種類';

  @override
  String get nostrAppPermissionAllow => '許可';

  @override
  String get appsDetailDefaultTitle => '連携アプリ';

  @override
  String get appsDetailNotFoundTitle => '連携が見つからないよ';

  @override
  String get appsDetailNotFoundSubtitle => 'この承認済みの連携は、もう Divine で利用できないよ。';

  @override
  String get appsDetailHowItWorksTitle => '仕組み';

  @override
  String get appsDetailHowItWorksBody =>
      'これは Divine の中で動く承認済みのサードパーティアプリだよ。Divine はこの連携に対して審査済みの機能だけを許可して、承認済みのオリジン以外への移動はブロックするよ。';

  @override
  String get appsDetailAboutTitle => '詳細';

  @override
  String get appsDetailPrimaryOriginTitle => 'メインのオリジン';

  @override
  String get appsDetailApprovedOriginsTitle => '承認済みのオリジン';

  @override
  String get appsDetailCapabilitiesTitle => '使える機能';

  @override
  String get appsDetailAskBeforeTitle => '確認するもの';

  @override
  String get appsDetailOpenButton => '連携を開く';

  @override
  String get appsDetailNoneDeclared => 'まだ宣言されてないよ';

  @override
  String get appsDirectoryTitle => '連携アプリ';

  @override
  String get appsDirectoryIntroTitle => '承認済みのサードパーティアプリ';

  @override
  String get appsDirectoryIntroBody => 'Divine の中で動く承認済みのサードパーティアプリ';

  @override
  String get appsDirectoryErrorTitle => '連携アプリを読み込めなかったよ';

  @override
  String get appsDirectoryErrorSubtitle => '引っ張って承認済みの連携をもう一回試してね。';

  @override
  String get appsDirectoryEmptyTitle => '承認済みの連携はまだないよ';

  @override
  String get appsDirectoryEmptySubtitle =>
      'Divine が追加していくと、承認済みのサードパーティアプリがここに表示されるよ。';

  @override
  String get appsDirectoryRefresh => '更新';

  @override
  String get appsDirectoryUnsupportedTitle => '連携アプリは Divine モバイルで動くよ';

  @override
  String get appsDirectoryUnsupportedSubtitle => '承認済みの連携は今のところモバイルだけで使えるよ。';

  @override
  String get appsSandboxUnavailableTitle => '連携が利用できないよ';

  @override
  String get appsSandboxUnavailableBody =>
      '[連携アプリ]タブから承認済みの連携を開いてね。そうすると Divine が正しいアクセスポリシーを適用できるよ。';

  @override
  String get appsSandboxLoadingTitle => '連携を読み込み中';

  @override
  String get appsSandboxLoadingSubtitle => '起動前に承認済みの連携を確認してるよ。';

  @override
  String get appsSandboxBlockedTitle => '安全のためにブロックしたよ';

  @override
  String appsSandboxBlockedSubtitle(String uri) {
    return 'この連携が承認済みのオリジンから出ようとしたよ。\n\n$uri';
  }

  @override
  String get shareCopiedPostLink => '投稿へのリンクをクリップボードにコピーしたよ';

  @override
  String get shareCopiedEventJson => 'Nostr イベントの JSON をクリップボードにコピーしたよ';

  @override
  String get shareCopiedEventId => 'Nostr イベント ID をクリップボードにコピーしたよ';

  @override
  String get authHeroTaglineAuthentic => 'ありのままの瞬間。';

  @override
  String get authHeroTaglineHuman => '人間の創造性。';

  @override
  String get keyImportFailedToImport => '鍵のインポートまたはバンカーへの接続に失敗したよ';

  @override
  String get keyImportInvalidBunkerUrl => '無効なバンカー URL だよ';

  @override
  String get keyImportInvalidFormat =>
      '無効な形式だよ。nsec...、hex、ncryptsec1...、または bunker://... を使ってね';

  @override
  String get keyImportInvalidNsecFormat => '無効な nsec 形式だよ。63文字である必要があるよ';

  @override
  String get keyImportKeyFieldLabel => '秘密鍵またはバンカー URL';

  @override
  String get keyImportKeyRequired => '秘密鍵またはバンカー URL を入力してね';

  @override
  String get keyImportPasswordRequired => 'この暗号化された鍵のパスワードを入力してね';

  @override
  String get keyImportSecurityWarningBody =>
      '秘密鍵は絶対に誰にも教えないでね。この鍵があるとあなたの Nostr アイデンティティにフルアクセスできちゃうよ。';

  @override
  String get keyImportSecurityWarningTitle => '秘密鍵は大切に守ってね！';

  @override
  String get keyImportSubtitle =>
      '秘密鍵かバンカー URL を使って、あなたの既存の Nostr アイデンティティをインポートしよう。';

  @override
  String get keyImportTitle => 'Nostr アイデンティティを\nインポート';

  @override
  String get commentAuthorYouIndicator => 'あなた';

  @override
  String commentAuthorAvatarSemanticLabel(String name) {
    return '$nameのプロフィールを表示';
  }

  @override
  String get commentOptionsDeleteSemanticLabel => 'コメントを削除';

  @override
  String get commentOptionsEditSemanticLabel => 'コメントを編集';

  @override
  String get commentOptionsFlagContentLabel => 'コンテンツにフラグを付ける';

  @override
  String get commentOptionsFlagContentSemanticLabel => 'このコンテンツにフラグを付ける';

  @override
  String get commentOptionsFlagReasonPrompt => 'このコメントにフラグを付ける理由を選んでね';

  @override
  String get commentOptionsFlagSubmit => '送信';

  @override
  String get commentOptionsTitle => 'オプション';

  @override
  String get commentsEmptyClassicVineMessage =>
      'アーカイブから昔のコメントをインポートする作業をまだ進めてるよ。まだ準備できてないんだ。';

  @override
  String get commentsEmptyClassicVineTitle => 'クラシック Vine';

  @override
  String get commentsInputEditingLabel => '編集中';

  @override
  String get commentsInputSemanticHint => 'コメントを追加';

  @override
  String get commentsInputSemanticHintEdit => 'コメントを編集';

  @override
  String get commentsInputSemanticHintReply => '返信を追加';

  @override
  String get commentsInputSemanticLabel => 'コメント入力';

  @override
  String get commentsInputSemanticLabelEdit => '編集入力';

  @override
  String get commentsInputSemanticLabelReply => '返信入力';

  @override
  String classicVinersViewProfileSemanticLabel(String displayName) {
    return '$displayNameのプロフィールを表示';
  }

  @override
  String get classicsEmptyDescription => 'クラシックのアーカイブを読み込んでるよ';

  @override
  String get classicsEmptyTitle => 'クラシックが見つからないよ';

  @override
  String get classicsErrorTitle => 'クラシックの読み込みに失敗したよ';

  @override
  String get classicsUnavailableDescription =>
      'クラシックは Funnelcake リレーに接続してるときだけ利用できるよ。';

  @override
  String get classicsUnavailableSettingsHint =>
      '設定で Funnelcake 対応のリレーに切り替えると、クラシックのアーカイブにアクセスできるよ。';

  @override
  String get classicsUnavailableTitle => 'クラシックは利用できないよ';

  @override
  String get hashtagFeedEmptySubtitle => 'このハッシュタグで最初の動画を投稿しよう！';

  @override
  String hashtagFeedEmptyTitle(String hashtag) {
    return '#$hashtag の動画は見つからなかったよ';
  }

  @override
  String get hashtagFeedLoadingSubtitle => '少し時間がかかるかも';

  @override
  String hashtagFeedLoadingTitle(String hashtag) {
    return '#$hashtag の動画を読み込み中...';
  }

  @override
  String get hashtagInputHint => 'ハッシュタグを追加... #vine #nostr';

  @override
  String get newVideosTabEmptySubtitle => '新しいコンテンツはまたあとでチェックしてね';

  @override
  String get newVideosTabEmptyTitle => '新着動画に動画はないよ';

  @override
  String get popularVideosContextTitle => '人気の動画';

  @override
  String get popularVideosEmptySubtitle => '新しいコンテンツはまたあとでチェックしてね';

  @override
  String get popularVideosEmptyTitle => '人気の動画に動画はないよ';

  @override
  String get popularVideosErrorTitle => 'トレンド動画の読み込みに失敗したよ';

  @override
  String get popularVideosFeedSourceLabel => '人気フィードのソース';

  @override
  String get trendingHashtagsLoading => 'ハッシュタグを読み込み中...';

  @override
  String trendingHashtagsViewVideosTagged(String hashtag) {
    return '$hashtag が付いた動画を見る';
  }

  @override
  String videoGridAuthorSemanticLabel(String name) {
    return '動画の作者: $name';
  }

  @override
  String videoGridDescriptionSemanticLabel(String description) {
    return '動画の説明: $description';
  }

  @override
  String get forYouAlgorithmChoiceBody =>
      'Divine が目指すのは、本当の意味でアルゴリズムを選べるようにすること。ひとつのブラックボックスなアルゴリズムに縛られるんじゃなくて、いくつかのおすすめの方法から選べるようになるよ:';

  @override
  String get forYouAlgorithmChoiceChronological => 'フォロー中のクリエイターの時系列タイムライン';

  @override
  String get forYouAlgorithmChoiceClosing =>
      'これで、注目のコントロールをプラットフォームに任せるんじゃなくて、あなた自身が握れるようになるよ。フィードがどう組み立てられてるかを知って、いつでも好きに変えられる力を持つべきなんだ。';

  @override
  String get forYouAlgorithmChoiceCustomFeeds =>
      '音楽、コメディ、アートみたいなテーマ別の、コミュニティが作ったカスタムフィード';

  @override
  String get forYouAlgorithmChoicePersonalizedFeed => 'あなた専用の「おすすめ」フィード';

  @override
  String get forYouAlgorithmChoiceTitle => 'アルゴリズムはあなたが選ぶ';

  @override
  String get forYouAlgorithmChoiceTrending => 'トレンドや人気のコンテンツ';

  @override
  String get forYouAlgorithmCommentsDescription =>
      '強いシグナル — 反応したくなるくらい引き込まれたってこと';

  @override
  String get forYouAlgorithmHowItWorksBody =>
      'Divine は、あなたがコンテンツとどうやりとりするかに注目して、何が好きかを理解するよ。動画を見たり、リアクションしたり、コメントを残したり、リポストするたびに、システムはそれを覚えていくんだ。';

  @override
  String get forYouAlgorithmHowItWorksTitle => '仕組み';

  @override
  String get forYouAlgorithmInteractionsIntro => 'アクションによって、興味の強さのシグナルが違うよ:';

  @override
  String get forYouAlgorithmNewToDivineBody1 =>
      'まだ視聴履歴がたまってないときは、今人気やトレンドのものと最近のアップロードをミックスして見せるよ。探索を始めるのにぴったりのスタート地点になるよ。';

  @override
  String get forYouAlgorithmNewToDivineBody2 =>
      '動画を見たり、いいねしたり、コンテンツに関わっていくうちに、おすすめはだんだんあなた好みになっていくよ。そのうち、おすすめフィードには自分だけじゃ見つけられなかったクリエイターの動画が出てくるようになるよ。';

  @override
  String get forYouAlgorithmNewToDivineTitle => 'Divine は初めて?';

  @override
  String get forYouAlgorithmOpenSourceBody =>
      '私たちは、開発者が自分のアルゴリズムを実装できて、あなたがどれを使うか選べる（または完全にオプトアウトできる）オープンなシステムを作ってるよ。';

  @override
  String get forYouAlgorithmOpenSourceTitle => 'オープンソースで透明';

  @override
  String get forYouAlgorithmReactionsDescription => '中くらいのシグナル — サクッと好意を示す方法';

  @override
  String get forYouAlgorithmReactionsTitle => 'リアクション';

  @override
  String get forYouAlgorithmRepostsDescription =>
      '最も強いシグナル — フォロワーにシェアするのは強力な推薦だよ';

  @override
  String get forYouAlgorithmSubtitle => 'オープンソースのおすすめエンジン Gorse を使ってるよ';

  @override
  String get forYouAlgorithmTitle => 'Divine のアルゴリズム';

  @override
  String get forYouAlgorithmViewsDescription => '軽いシグナル — 基本的な興味を示すよ';

  @override
  String get forYouEmptyDescription => '動画を見たりいいねしたりすると、あなた好みのおすすめが表示されるよ。';

  @override
  String get forYouEmptyTitle => 'おすすめはまだないよ';

  @override
  String get forYouErrorTitle => 'おすすめの読み込みに失敗したよ';

  @override
  String get forYouUnavailableDescription =>
      'あなた好みのおすすめには Funnelcake への接続が必要だよ。';

  @override
  String get forYouUnavailableTitle => 'おすすめは利用できないよ';

  @override
  String get inboxConversationOptionsLabel => 'オプション';

  @override
  String get inboxConversationViewProfileButton => 'プロフィールを表示';

  @override
  String get inboxMessageRequestsEmpty => 'メッセージリクエストはないよ';

  @override
  String inboxMessageRequestsSemanticLabel(int requestCount) {
    return 'メッセージリクエスト、$requestCount件保留中';
  }

  @override
  String get inboxMessageRequestsTitle => 'メッセージリクエスト';

  @override
  String get inboxMessagesTab => 'メッセージ';

  @override
  String inboxRequestTileLabel(String displayName) {
    return '$displayNameからのメッセージリクエスト';
  }

  @override
  String get inboxRequestTileSubtitle => 'メッセージリクエストを送信したよ';

  @override
  String get inboxRequestsMarkAllRead => 'すべてのリクエストを既読にする';

  @override
  String get inboxRequestsRemoveAll => 'すべてのリクエストを削除';

  @override
  String get messageRequestDeclineAndRemoveButton => '拒否して削除';

  @override
  String messageRequestFollowersCount(String count) {
    return '$count人のフォロワー';
  }

  @override
  String messageRequestVideosCount(String count) {
    return '$count本の動画';
  }

  @override
  String messageRequestMessageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件のメッセージ',
      one: '1件のメッセージ',
    );
    return '$_temp0';
  }

  @override
  String get messageRequestViewMessagesButton => 'メッセージを表示';

  @override
  String get messageRequestViewProfileButton => 'プロフィールを表示';

  @override
  String messageRequestWantsToMessageYou(
    String displayName,
    String messageText,
  ) {
    return '$displayNameがあなたにメッセージを送りたがってるよ。$messageTextを送信済みだよ。';
  }

  @override
  String get deleteAccountConfirmationHint => 'DELETE と入力してね';

  @override
  String get deleteAccountContentDeletionFailed => 'リレーからのコンテンツ削除に失敗したよ';

  @override
  String get deleteAccountDeleteAllContentButton => 'すべてのコンテンツを削除';

  @override
  String get deleteAccountFinalConfirmationBody =>
      'Nostr リレーからすべてのコンテンツを完全に削除することを確認するには、次を入力してね:';

  @override
  String get deleteAccountFinalConfirmationTitle => '⚠️ 最終確認';

  @override
  String get deleteAccountKeyDeletionWarning =>
      'アカウントは削除したけど、鍵がこのデバイスから完全には消えてないかもしれないよ。[設定]→[Nostr 鍵]→[鍵を削除]でもう一回試してね。';

  @override
  String get deleteAccountLocalDataDeletionFailed =>
      'Account deleted and signed out, but some local data could not be removed from this device.';

  @override
  String get deleteAccountPreparingDeletion => '削除の準備中...';

  @override
  String deleteAccountProgressEvents(int current, int total) {
    return '$current / $total 件のイベント';
  }

  @override
  String get deleteAccountRemoveKeysBody =>
      'このアカウントのローカルログインをこのデバイスから削除するよ。Divine アカウントや Nostr アイデンティティは削除されないよ。\n\nこのアカウントの下書きとクリップは、このデバイスに保存されたまま残るよ。これが最後のローカルアカウントなら、ログイン画面に戻るよ。';

  @override
  String get deleteAccountRemoveKeysConfirm => 'デバイスから削除';

  @override
  String get deleteAccountRemoveKeysTitle => 'このアカウントをこのデバイスから削除する?';

  @override
  String get deleteAccountServerDeletionFailed =>
      'サーバーからアカウントを削除できなかったよ。接続を確認してもう一回試してね。';

  @override
  String get deleteAccountSuccess => 'アカウントを削除したよ';

  @override
  String get exportProgressStageApplyingTextOverlay => 'テキストオーバーレイを追加中...';

  @override
  String get exportProgressStageComplete => '書き出し完了！';

  @override
  String get exportProgressStageConcatenating => 'クリップを結合中...';

  @override
  String get exportProgressStageError => '書き出しに失敗したよ';

  @override
  String get exportProgressStageGeneratingThumbnail => 'サムネイルを生成中...';

  @override
  String get exportProgressStageMixingAudio => 'サウンドを追加中...';

  @override
  String get findPeopleAnonymousUser => '匿名';

  @override
  String get findPeopleNoContacts => '連絡先が見つからないよ。\n誰かをフォローすると、ここに表示されるよ。';

  @override
  String get geoBlockedCityLabel => '市区町村';

  @override
  String get geoBlockedCountryLabel => '国';

  @override
  String get geoBlockedDefaultReason => '現地の規制により、このサービスはお住まいの地域では利用できないよ。';

  @override
  String get geoBlockedLegalNotice =>
      '私たちはあなたの地域の法律や規制を尊重してるよ。この制限は、あなたの IP アドレスの位置情報に基づいてるよ。';

  @override
  String get geoBlockedRegionLabel => '地域';

  @override
  String get geoBlockedTitle => 'サービスは利用できないよ';

  @override
  String get likedVideosEmpty => 'いいねした動画はないよ';

  @override
  String get likedVideosInvalidRoute => '無効なルート';

  @override
  String get likedVideosTitle => 'いいねした動画';

  @override
  String get ogVinerBadgeSemanticLabel => 'OG Viner';

  @override
  String get uploadFailureSheetRetryingSnackbar => 'アップロードを再試行中…';

  @override
  String get uploadFailureSheetSaveToDraftsButton => '下書きに保存';

  @override
  String get uploadFailureSheetSavedToDraftsSnackbar => '下書きに保存したよ';

  @override
  String get uploadFailureSheetTitle => 'アップロードに失敗したよ';

  @override
  String get uploadFailureSheetTryAgainButton => 'もう一回試す';

  @override
  String get videoEditorAudioImportAudio => '音声をインポート';

  @override
  String get videoEditorAudioImportFailed => '音声のインポートに失敗したよ。';

  @override
  String get videoIconPlaceholderLabel => '動画';

  @override
  String videoInspiredByAttributionSemanticLabel(String creatorName) {
    return '$creatorNameにインスパイアされたよ。タップするとプロフィールを見れるよ。';
  }

  @override
  String get proofmodeBadgeAiScanPending => 'AI スキャン待ち';

  @override
  String get proofmodeBadgeHumanMade => '人間が作成';

  @override
  String get proofmodeBadgeNotDivineHosted => 'Divine 非ホスト';

  @override
  String get proofmodeBadgeOriginal => 'オリジナル';

  @override
  String get proofmodeBadgePossiblyAiGenerated => 'AI 生成の可能性あり';

  @override
  String get proofmodeBadgeUnverified => '未検証';

  @override
  String get proofmodeConfirmedByModerator => '人間のモデレーターが確認済み';

  @override
  String get proofmodeExternalContentTitle => '外部コンテンツ';

  @override
  String get proofmodeHostedOnLabel => 'この動画のホスト先:';

  @override
  String get proofmodeLikelyHumanCreated => '人間が作成した可能性が高い';

  @override
  String get proofmodeNoProofDataAttached => 'ProofMode データが添付されてないよ';

  @override
  String get proofmodeNotDivineHostedDisclaimer =>
      'このコンテンツは Divine のサーバーにはホストされてないよ。真正性を完全には保証できないよ。';

  @override
  String get proofmodePossiblyAiGenerated => 'AI 生成の可能性あり';

  @override
  String get proofmodePublishedByLabel => '投稿者:';

  @override
  String get publishErrorNotSignedIn => '動画を投稿するにはサインインしてね。';

  @override
  String get publishErrorNoRetry => 'やり直せるアップロードがないよ。';

  @override
  String get publishErrorNoInternet =>
      'ネットに接続できないよ。Wi-Fi かモバイルデータを確認して、もう一回試してみて。';

  @override
  String get publishErrorServerUnreachable =>
      'サーバーに接続できなかったよ。少し待ってからもう一回試してみて。';

  @override
  String get publishErrorTimeout =>
      'アップロードがタイムアウトしたよ。接続のいい場所に移るか、もっと小さい動画で試してみて。';

  @override
  String get publishErrorTls =>
      'セキュア接続に失敗したよ。ネットワークを確認してみて。公共の Wi-Fi だとアップロードがブロックされることがあるよ。';

  @override
  String publishErrorServerNotFound(String serverName) {
    return 'メディアサーバー（$serverName）が利用できないよ。設定で別のサーバーを選べるよ。';
  }

  @override
  String get publishErrorFileTooLarge =>
      '動画ファイルがサーバーには大きすぎるよ。トリミングするか、画質を下げて試してみて。';

  @override
  String publishErrorServerInternalError(String serverName) {
    return 'メディアサーバー（$serverName）で内部エラーが起きたよ。設定で別のサーバーを選べるよ。';
  }

  @override
  String publishErrorServerDown(String serverName) {
    return 'メディアサーバー（$serverName）が一時的にダウンしてるよ。少し待ってからもう一回試すか、設定で別のサーバーを選んでみて。';
  }

  @override
  String get publishErrorForbidden => 'このサーバーにアップロードする権限がないよ。';

  @override
  String get publishErrorFileNotFound =>
      '動画ファイルが見つからなかったよ。削除されたのかもしれない。もう一回撮影して試してみて。';

  @override
  String get publishErrorLowStorage => '端末の空き容量が足りないよ。容量を空けてもう一回試してみて。';

  @override
  String get publishErrorThumbnailFailed =>
      '動画はアップロードできたけど、サムネイルを準備できなかったよ。もう一回試してみて。';

  @override
  String get publishErrorNostrPublishFailed =>
      '動画はアップロードできたけど、投稿を公開できなかったよ。リレー設定を確認して、もう一回試してみて。';

  @override
  String get publishErrorInterrupted => 'アップロードが中断されたよ。もう一回試す？';

  @override
  String get publishErrorGeneric => '問題が発生したよ。もう一回試してみて。';

  @override
  String get publishErrorRateLimited => '今はアップロードが多すぎるよ。少し待ってからもう一回試してみて。';

  @override
  String get publishErrorUploadSessionExpired =>
      'アップロードのセッションが切れちゃったよ。もう一回試してみて。';

  @override
  String get publishErrorPermissionDenied =>
      'Divine にアップロードの権限がないよ。設定でアプリの権限を確認して、もう一回試してみて。';

  @override
  String get publishErrorOutOfMemory => '端末のメモリが足りないよ。アプリをいくつか閉じて、もう一回試してみて。';

  @override
  String get publishErrorUnknownServer => '不明なサーバー';

  @override
  String searchFilterPillSemanticLabel(String filter) {
    return 'フィルター: $filter';
  }

  @override
  String searchNoResultsFound(String query) {
    return '「$query」の結果は見つからなかったよ';
  }

  @override
  String searchTagChipViewVideosTaggedLabel(String tag) {
    return '$tag が付いた動画を見る';
  }

  @override
  String audioAttributionRowSemanticLabel(
    String soundName,
    String creatorName,
  ) {
    return 'サウンド: $creatorNameの$soundName。タップするとサウンドの詳細を見れるよ。';
  }

  @override
  String metadataSoundsOriginalSoundSemantics(String creatorName) {
    return '$creatorNameのオリジナルサウンド。タップするとこのサウンドを使えるよ。';
  }

  @override
  String metadataSoundsSharedSoundSemantics(
    String soundName,
    String creatorName,
  ) {
    return 'サウンド: $creatorNameの$soundName。タップすると詳細を見れるよ。';
  }

  @override
  String soundDetailLoadError(String error) {
    return 'サウンドの読み込みに失敗したよ: $error';
  }

  @override
  String get soundDetailNotFoundMessage => 'このサウンドは見つからなかったよ';

  @override
  String get soundDetailNotFoundTitle => 'サウンドが見つからないよ';

  @override
  String get videoFeedDescriptionSemanticLabel => '動画の説明';

  @override
  String videoFeedLoopCountLabel(int count) {
    return '🔁 $countループ';
  }

  @override
  String get videoFeedLoopCountSemanticLabel => '動画のループ数';

  @override
  String get originalSoundUnavailableBody => 'この動画の音声は個別には利用できないよ。';

  @override
  String originalSoundByCreator(String creatorName) {
    return 'オリジナルサウンド - $creatorName';
  }

  @override
  String globalUploadPendingCount(int count) {
    return '保留中のアップロード ($count)';
  }

  @override
  String get ogVinerBadgeLabel => 'OG Viner';

  @override
  String shareVideoInListsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件のリストに含まれてるよ',
      one: '1件のリストに含まれてるよ',
    );
    return '$_temp0';
  }

  @override
  String get unfollowConfirmButton => 'フォロー解除';

  @override
  String get videoClipSaveFailed => 'クリップの保存に失敗したよ';

  @override
  String videoClipSaveTo(String destination) {
    return '$destinationに保存';
  }

  @override
  String get videoClipDelete => 'クリップを削除';

  @override
  String inspiredByAttributionSemanticLabel(String creatorName) {
    return '$creatorNameにインスパイアされたよ。タップするとプロフィールを見れるよ。';
  }

  @override
  String get bugReportSendReport => 'レポートを送信';

  @override
  String get supportSubjectRequiredLabel => '件名 *';

  @override
  String get supportRequiredHelper => '必須';

  @override
  String get bugReportSubjectHint => '問題の概要';

  @override
  String get bugReportDescriptionRequiredLabel => '何が起きた? *';

  @override
  String get bugReportDescriptionHint => '起きた問題を教えてね';

  @override
  String get bugReportStepsLabel => '再現手順';

  @override
  String get bugReportStepsHint => '1. ...に移動\n2. ...をタップ\n3. エラーが出る';

  @override
  String get bugReportExpectedBehaviorLabel => '期待していた動作';

  @override
  String get bugReportExpectedBehaviorHint => '本来どうなるはずだった?';

  @override
  String get bugReportDiagnosticsNotice => 'デバイス情報とログは自動で添付されるよ。';

  @override
  String get bugReportSuccessMessage => 'ありがとう！レポートを受け取ったよ。Divine をよくするのに使うね。';

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
  String get bugReportSendFailed => 'バグレポートの送信に失敗。あとでもう一回試してみて。';

  @override
  String bugReportFailedWithError(String error) {
    return 'バグレポートの送信に失敗: $error';
  }

  @override
  String get featureRequestSendRequest => 'リクエストを送信';

  @override
  String get featureRequestSubjectHint => 'アイデアの概要';

  @override
  String get featureRequestDescriptionRequiredLabel => 'どんな機能がほしい? *';

  @override
  String get featureRequestDescriptionHint => 'ほしい機能を教えてね';

  @override
  String get featureRequestUsefulnessLabel => 'どう役に立つ?';

  @override
  String get featureRequestUsefulnessHint => 'この機能のメリットを教えてね';

  @override
  String get featureRequestWhenLabel => 'どんなときに使う?';

  @override
  String get featureRequestWhenHint => 'この機能が役立つシーンを教えてね';

  @override
  String get featureRequestSuccessMessage => 'ありがとう！機能リクエストを受け取ったよ。チェックするね。';

  @override
  String get featureRequestSendFailed => '機能リクエストの送信に失敗。あとでもう一回試してみて。';

  @override
  String featureRequestFailedWithError(String error) {
    return '機能リクエストの送信に失敗: $error';
  }

  @override
  String get notificationFollowBack => 'フォローバック';

  @override
  String get followingTitle => 'フォロー中';

  @override
  String followingTitleForName(String displayName) {
    return '$displayNameのフォロー中';
  }

  @override
  String get followingFailedToLoadList => 'フォロー中リストの読み込みがうまくいかなかった';

  @override
  String get followingEmptyTitle => 'まだ誰もフォローしてないよ';

  @override
  String get followersTitle => 'フォロワー';

  @override
  String followersTitleForName(String displayName) {
    return '$displayNameのフォロワー';
  }

  @override
  String get followersFailedToLoadList => 'フォロワーリストの読み込みがうまくいかなかった';

  @override
  String get followersEmptyTitle => 'フォロワーはまだいないよ';

  @override
  String get followersUpdateFollowFailed => 'フォロー状態の更新に失敗。もう一回試してみて。';

  @override
  String get reportMessageTitle => 'メッセージを報告';

  @override
  String get reportMessageWhyReporting => 'このメッセージを報告する理由は?';

  @override
  String get reportMessageSelectReason => 'このメッセージを報告する理由を選んでね';

  @override
  String get newMessageTitle => '新しいメッセージ';

  @override
  String get newMessageFindPeople => '人を探す';

  @override
  String get newMessageNoContacts => '連絡先が見つからなかった。\n人をフォローするとここに出るよ。';

  @override
  String get newMessageNoUsersFound => 'ユーザーが見つからなかった';

  @override
  String get hashtagSearchTitle => 'ハッシュタグを検索';

  @override
  String get hashtagSearchSubtitle => 'トレンドのトピックとコンテンツを見つけよう';

  @override
  String hashtagSearchNoResults(String query) {
    return '「$query」のハッシュタグは見つからなかった';
  }

  @override
  String get hashtagSearchFailed => '検索に失敗';

  @override
  String get userNotAvailableTitle => 'アカウントは利用できないよ';

  @override
  String get userNotAvailableBody => 'このアカウントは今は利用できないよ。';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String blossomFailedToSaveSettings(String error) {
    return '設定の保存がうまくいかなかった: $error';
  }

  @override
  String get blossomValidServerUrl =>
      '有効なサーバー URL を入力してね (例: https://blossom.band)';

  @override
  String get blossomSettingsSaved => 'Blossom の設定を保存したよ';

  @override
  String get blossomSaveTooltip => '保存';

  @override
  String get blossomAboutTitle => 'Blossom について';

  @override
  String get blossomAboutDescription =>
      'Blossom は分散型のメディアストレージプロトコルで、対応する任意のサーバーに動画をアップロードできるよ。デフォルトでは Divine の Blossom サーバーにアップロードされる。下のオプションを有効にすると、カスタムサーバーが使えるよ。';

  @override
  String get blossomUseCustomServer => 'カスタム Blossom サーバーを使う';

  @override
  String get blossomCustomServerEnabledSubtitle =>
      '動画はカスタム Blossom サーバーにアップロードされるよ';

  @override
  String get blossomCustomServerDisabledSubtitle =>
      '現在、動画は Divine の Blossom サーバーにアップロードされてるよ';

  @override
  String get blossomCustomServerUrl => 'カスタム Blossom サーバー URL';

  @override
  String get blossomCustomServerHelper => 'カスタム Blossom サーバーの URL を入力してね';

  @override
  String get blossomPopularServers => '人気の Blossom サーバー';

  @override
  String get blossomServerUrlMustUseHttps =>
      'Blossom サーバー URL は https:// を使ってね';

  @override
  String get blueskyFailedToUpdateCrosspost => 'クロスポスト設定の更新がうまくいかなかった';

  @override
  String get blueskySignInRequired => 'Bluesky 設定を管理するにはサインインしてね';

  @override
  String get blueskyPublishVideos => '動画を Bluesky に公開';

  @override
  String get blueskyEnabledSubtitle => '動画は Bluesky に公開されるよ';

  @override
  String get blueskyDisabledSubtitle => '動画は Bluesky には公開されないよ';

  @override
  String get blueskyHandle => 'Bluesky ハンドル';

  @override
  String get blueskyStatus => 'ステータス';

  @override
  String get blueskyStatusReady => 'アカウント準備完了';

  @override
  String get blueskyStatusPending => 'アカウントを準備中...';

  @override
  String get blueskyStatusFailed => 'アカウントの準備に失敗';

  @override
  String get blueskyStatusDisabled => 'アカウントは無効';

  @override
  String get blueskyStatusNotLinked => 'Bluesky アカウントが連携されてないよ';

  @override
  String get invitesTitle => '友達を招待しよう';

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
  String get invitesNoneAvailable => '今は使える招待がないよ';

  @override
  String get invitesShareWithPeople => 'diVine を周りの人にシェアしよう';

  @override
  String get invitesUsedInvites => '使用済みの招待';

  @override
  String invitesShareMessage(String code) {
    return 'diVine に参加しよう！招待コード $code で始められるよ:\nhttps://divine.video/invite/$code';
  }

  @override
  String get invitesCopyInvite => '招待をコピー';

  @override
  String get invitesCopied => '招待をコピーしたよ！';

  @override
  String get invitesShareInvite => '招待をシェア';

  @override
  String get invitesShareSubject => 'diVine に参加しよう';

  @override
  String get invitesClaimed => '受け取り済み';

  @override
  String get invitesCouldNotLoad => '招待の読み込みに失敗';

  @override
  String get invitesRetry => 'もう一回';

  @override
  String get searchSomethingWentWrong => 'なんかうまくいかなかった';

  @override
  String get searchTryAgain => 'もう一回';

  @override
  String get searchForLists => 'リストを検索';

  @override
  String get searchFindCuratedVideoLists => 'キュレーションされた動画リストを探そう';

  @override
  String get searchEnterQuery => '検索キーワードを入力';

  @override
  String get searchDiscoverSomethingInteresting => '面白いものを見つけよう';

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
  String get searchVideosSortOptionsLabel => '動画の検索結果を並び替え';

  @override
  String get searchVideosSortTrending => '話題';

  @override
  String get searchVideosSortLoops => 'ループが多い順';

  @override
  String get searchVideosSortEngagement => '反応が多い順';

  @override
  String get searchVideosSortRecent => '新着';

  @override
  String get searchListsSectionHeader => 'リスト';

  @override
  String get searchListsLoadingLabel => 'リスト結果を読み込み中';

  @override
  String get cameraAgeRestriction => 'コンテンツを作るには16歳以上である必要があるよ';

  @override
  String get featureRequestCancel => 'キャンセル';

  @override
  String keyImportError(String error) {
    return 'エラー: $error';
  }

  @override
  String get keyImportInsecureBunkerRelay =>
      'Bunker リレーは wss:// を使ってね (ws:// は localhost のみ可)';

  @override
  String get timeNow => '今';

  @override
  String timeShortMinutes(int count) {
    return '$count分';
  }

  @override
  String timeShortHours(int count) {
    return '$count時間';
  }

  @override
  String timeShortDays(int count) {
    return '$count日';
  }

  @override
  String timeShortWeeks(int count) {
    return '$count週';
  }

  @override
  String timeShortMonths(int count) {
    return '$countヶ月';
  }

  @override
  String timeShortYears(int count) {
    return '$count年';
  }

  @override
  String get timeVerboseNow => '今';

  @override
  String timeAgo(String time) {
    return '$time前';
  }

  @override
  String get timeToday => '今日';

  @override
  String get timeYesterday => '昨日';

  @override
  String get timeJustNow => 'たった今';

  @override
  String timeMinutesAgo(int count) {
    return '$count分前';
  }

  @override
  String timeHoursAgo(int count) {
    return '$count時間前';
  }

  @override
  String timeDaysAgo(int count) {
    return '$count日前';
  }

  @override
  String get draftTimeJustNow => 'たった今';

  @override
  String get contentLabelNudity => 'ヌード';

  @override
  String get contentLabelSexualContent => '性的な内容';

  @override
  String get contentLabelPornography => 'ポルノ';

  @override
  String get contentLabelGraphicMedia => '過激なメディア';

  @override
  String get contentLabelViolence => '暴力';

  @override
  String get contentLabelSelfHarm => '自傷行為/自殺';

  @override
  String get contentLabelDrugUse => '薬物使用';

  @override
  String get contentLabelAlcohol => 'アルコール';

  @override
  String get contentLabelTobacco => 'タバコ/喫煙';

  @override
  String get contentLabelGambling => 'ギャンブル';

  @override
  String get contentLabelProfanity => '不適切な言葉';

  @override
  String get contentLabelHateSpeech => 'ヘイトスピーチ';

  @override
  String get contentLabelHarassment => 'ハラスメント';

  @override
  String get contentLabelFlashingLights => '点滅する光';

  @override
  String get contentLabelAiGenerated => 'AI生成';

  @override
  String get contentLabelDeepfake => 'ディープフェイク';

  @override
  String get contentLabelSpam => 'スパム';

  @override
  String get contentLabelScam => '詐欺';

  @override
  String get contentLabelSpoiler => 'ネタバレ';

  @override
  String get contentLabelMisleading => '誤解を招く内容';

  @override
  String get contentLabelSensitiveContent => 'センシティブな内容';

  @override
  String notificationLikedYourVideo(String actorName) {
    return '$actorNameさんがあなたの動画にいいねしました';
  }

  @override
  String notificationLikedYourComment(String actorName) {
    return '$actorNameさんがあなたのコメントにいいねしました';
  }

  @override
  String notificationCommentedOnYourVideo(String actorName) {
    return '$actorNameさんがあなたの動画にコメントしました';
  }

  @override
  String notificationStartedFollowing(String actorName) {
    return '$actorNameさんがあなたをフォローしました';
  }

  @override
  String notificationMentionedYou(String actorName) {
    return '$actorNameさんがあなたをメンションしました';
  }

  @override
  String notificationRepostedYourVideo(String actorName) {
    return '$actorNameさんがあなたの動画をリポストしました';
  }

  @override
  String notificationRepliedToYourComment(String actorName) {
    return '$actorNameさんがあなたのコメントに返信しました';
  }

  @override
  String get notificationAndConnector => 'と';

  @override
  String notificationOthersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '他$count人',
    );
    return '$_temp0';
  }

  @override
  String get notificationSystemUpdate => '新しいお知らせがあります';

  @override
  String get notificationSomeoneLikedYourVideo => '誰かがあなたの動画にいいねしました';

  @override
  String get commentReplyToPrefix => 'Re:';

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
  String get draftUntitled => '無題';

  @override
  String get contentWarningNone => 'なし';

  @override
  String get textBackgroundNone => 'なし';

  @override
  String get textBackgroundSolid => '塗りつぶし';

  @override
  String get textBackgroundHighlight => 'ハイライト';

  @override
  String get textBackgroundTransparent => '透明';

  @override
  String get textAlignLeft => '左';

  @override
  String get textAlignRight => '右';

  @override
  String get textAlignCenter => '中央';

  @override
  String get cameraPermissionWebUnsupportedTitle => 'カメラはまだWebでサポートされていません';

  @override
  String get cameraPermissionWebUnsupportedDescription =>
      'カメラでの撮影と録画は、Web版ではまだ利用できません。';

  @override
  String get cameraPermissionBackToFeed => 'フィードに戻る';

  @override
  String get cameraPermissionErrorTitle => '権限エラー';

  @override
  String get cameraPermissionErrorDescription => '権限の確認中に問題が発生しました。';

  @override
  String get cameraPermissionRetry => '再試行';

  @override
  String get cameraPermissionAllowAccessTitle => 'カメラとマイクへのアクセスを許可';

  @override
  String get cameraPermissionAllowAccessDescription =>
      'これにより、アプリ内で動画の撮影と編集ができるようになります。それ以外の用途はありません。';

  @override
  String get cameraPermissionGoToSettings => '設定に移動';

  @override
  String get videoRecorderWhySixSecondsTitle => 'なぜ6秒なの？';

  @override
  String get videoRecorderWhySixSecondsSubtitle =>
      '短いクリップは自発性のための空間を作ります。6秒フォーマットは起きた瞬間の本物の瞬間を捉えるのに役立ちます。';

  @override
  String get videoRecorderWhySixSecondsButton => 'わかりました！';

  @override
  String get videoRecorderUploadTitle => 'なぜアップロードできないの?';

  @override
  String get videoRecorderUploadBody =>
      'Divineで見るものは人間が作ったもの。生のまま、その瞬間に撮影されたものです。高度に加工された動画やAI生成のアップロードを許可するプラットフォームとは違い、私たちはカメラ直撮りの体験の本物らしさを優先します。';

  @override
  String get videoRecorderUploadBodyDetail =>
      '作成をアプリ内に留めることで、コンテンツが本物で未編集であることをより確実に保証できます。今のところ外部ギャラリーからのアップロードは開放していません。その本物らしさを守り、コミュニティを合成コンテンツからできる限り守るためです。';

  @override
  String get videoRecorderUploadBodyCta => '本物を撮るならCaptureかClassicに切り替えてね。';

  @override
  String get videoRecorderUploadLearnMore => '認証の仕組みを見る';

  @override
  String get videoRecorderAutosaveFoundTitle => '作業中のものが見つかりました';

  @override
  String get videoRecorderAutosaveFoundSubtitle => '続きから再開しますか？';

  @override
  String get videoRecorderAutosaveContinueButton => 'はい、続ける';

  @override
  String get videoRecorderAutosaveDiscardButton => 'いいえ、新しい動画を開始';

  @override
  String get videoRecorderAutosaveRestoreFailure => '下書きを復元できませんでした';

  @override
  String get videoRecorderStopRecordingTooltip => '録画を停止';

  @override
  String get videoRecorderStartRecordingTooltip => '録画を開始';

  @override
  String get videoRecorderRecordingTapToStopLabel => '録画中。どこかタップして停止';

  @override
  String get videoRecorderTapToStartLabel => 'どこかタップして録画を開始';

  @override
  String get videoRecorderDeleteLastClipLabel => '最後のクリップを削除';

  @override
  String get videoRecorderSwitchCameraLabel => 'カメラを切り替え';

  @override
  String videoRecorderZoomLevelLabel(String zoom) {
    return '$zoom× にズーム';
  }

  @override
  String get videoRecorderToggleGridLabel => 'グリッドを切り替え';

  @override
  String get videoRecorderToggleGhostFrameLabel => 'ゴーストフレームを切り替え';

  @override
  String get videoRecorderGhostFrameEnabled => 'ゴーストフレームを有効化';

  @override
  String get videoRecorderGhostFrameDisabled => 'ゴーストフレームを無効化';

  @override
  String get videoRecorderClipDeletedMessage => 'クリップをゴミ箱に移動しました';

  @override
  String get videoRecorderClipUndoLabel => '元に戻す';

  @override
  String get libraryTrashTitle => '最近削除した項目';

  @override
  String get libraryTrashEmptyTitle => 'ゴミ箱は空です';

  @override
  String get libraryTrashEmptySubtitle => '削除されたクリップは30日間ここに保管され、その後完全に削除されます。';

  @override
  String get libraryTrashRestoreLabel => '復元';

  @override
  String get libraryTrashDeleteNowLabel => '今すぐ削除';

  @override
  String get libraryTrashEmptyAllLabel => 'ゴミ箱を空にする';

  @override
  String get libraryTrashDeleteConfirmTitle => '今すぐクリップを削除しますか？';

  @override
  String get libraryTrashDeleteConfirmMessage => 'これでクリップはゴミ箱からすぐに削除されます。';

  @override
  String get libraryTrashEmptyConfirmTitle => 'ゴミ箱を空にしますか？';

  @override
  String libraryTrashEmptyConfirmMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件のクリップ',
      one: '1件のクリップ',
    );
    return 'これでゴミ箱から$_temp0がすぐに完全に削除されます。';
  }

  @override
  String get libraryTrashEntryLabel => '最近削除した項目';

  @override
  String get videoRecorderCloseLabel => '動画レコーダーを閉じる';

  @override
  String get videoRecorderContinueToEditorLabel => '動画エディタへ進む';

  @override
  String get videoRecorderCaptureCloseLabel => '閉じる';

  @override
  String get videoRecorderCaptureNextLabel => '次へ';

  @override
  String get videoRecorderLipSyncAddAudioFirst => '録画する前にオーディオを追加してください';

  @override
  String get videoRecorderToggleFlashLabel => 'フラッシュを切り替え';

  @override
  String get videoRecorderCycleTimerLabel => 'タイマーを切り替え';

  @override
  String get videoRecorderToggleAspectRatioLabel => 'アスペクト比を切り替え';

  @override
  String get videoRecorderStabilizationLabel => '手ぶれ補正';

  @override
  String get videoRecorderStabilizationModeOff => 'オフ';

  @override
  String get videoRecorderStabilizationModeStandard => '標準';

  @override
  String get videoRecorderStabilizationModeCinematic => 'シネマティック';

  @override
  String get videoRecorderStabilizationModeCinematicExtended => 'シネマティック拡張';

  @override
  String get videoRecorderStabilizationModePreviewOptimized => 'プレビュー最適化';

  @override
  String get videoRecorderStabilizationModeLowLatency => '低遅延';

  @override
  String get videoRecorderStabilizationModeAuto => '自動';

  @override
  String get videoRecorderLibraryEmptyLabel => 'クリップライブラリ、クリップなし';

  @override
  String videoRecorderLibraryOpenLabel(int clipCount) {
    String _temp0 = intl.Intl.pluralLogic(
      clipCount,
      locale: localeName,
      other: 'クリップライブラリを開く、$clipCountクリップ',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorCameraLabel => 'カメラ';

  @override
  String get videoEditorOpenCameraSemanticLabel => 'カメラを開く';

  @override
  String get videoEditorLibraryLabel => 'ライブラリ';

  @override
  String get videoEditorTextLabel => 'テキスト';

  @override
  String get videoEditorDrawLabel => '描画';

  @override
  String get videoEditorFilterLabel => 'フィルター';

  @override
  String get videoEditorTuneLabel => '調整';

  @override
  String get videoEditorOpenTuneSemanticLabel => '調整エディターを開く';

  @override
  String get videoEditorTuneBrightness => '明るさ';

  @override
  String get videoEditorTuneContrast => 'コントラスト';

  @override
  String get videoEditorTuneSaturation => '彩度';

  @override
  String get videoEditorTuneExposure => '露出';

  @override
  String get videoEditorTuneHue => '色相';

  @override
  String get videoEditorTuneTemperature => '色温度';

  @override
  String get videoEditorTuneTint => '色かぶり';

  @override
  String get videoEditorTuneFade => 'フェード';

  @override
  String get videoEditorAudioLabel => 'オーディオ';

  @override
  String get videoEditorAddTitle => '追加';

  @override
  String get videoEditorOpenLibrarySemanticLabel => 'ライブラリを開く';

  @override
  String get videoEditorOpenAudioSemanticLabel => 'オーディオエディタを開く';

  @override
  String get videoEditorOpenTextSemanticLabel => 'テキストエディタを開く';

  @override
  String get videoEditorOpenDrawSemanticLabel => '描画エディタを開く';

  @override
  String get videoEditorOpenFilterSemanticLabel => 'フィルターエディタを開く';

  @override
  String get videoEditorOpenStickerSemanticLabel => 'スタンプエディタを開く';

  @override
  String get videoEditorSaveDraftTitle => '下書きを保存しますか？';

  @override
  String get videoEditorSaveDraftSubtitle => '編集内容を後で保存するか、破棄してエディタを終了します。';

  @override
  String get videoEditorSaveDraftButton => '下書きを保存';

  @override
  String get videoEditorDiscardChangesButton => '変更を破棄';

  @override
  String get videoEditorKeepEditingButton => '編集を続ける';

  @override
  String get videoEditorDeleteLayerDropZone => 'レイヤー削除のドロップゾーン';

  @override
  String get videoEditorReleaseToDeleteLayer => '離してレイヤーを削除';

  @override
  String get videoEditorDoneLabel => '完了';

  @override
  String get videoEditorPlayPauseSemanticLabel => '動画を再生または一時停止';

  @override
  String get videoEditorCropSemanticLabel => 'トリミング';

  @override
  String get videoEditorCannotSplitProcessing =>
      '処理中はクリップを分割できません。しばらくお待ちください。';

  @override
  String videoEditorSplitPositionInvalid(int minDurationMs) {
    return '分割位置が無効です。各クリップは最低${minDurationMs}ms必要です。';
  }

  @override
  String get videoEditorAddClipFromLibrary => 'ライブラリからクリップを追加';

  @override
  String get videoEditorSaveSelectedClip => '選択したクリップを保存';

  @override
  String get videoEditorSplitClip => 'クリップを分割';

  @override
  String get videoEditorSaveClip => 'クリップを保存';

  @override
  String get videoEditorDeleteClip => 'クリップを削除';

  @override
  String get videoEditorClipSavedSuccess => 'クリップをライブラリに保存しました';

  @override
  String get videoEditorClipSaveFailed => 'クリップの保存に失敗しました';

  @override
  String get videoEditorClipDeleted => 'クリップを削除しました';

  @override
  String get videoEditorColorPickerSemanticLabel => 'カラーピッカー';

  @override
  String get videoEditorUndoSemanticLabel => '元に戻す';

  @override
  String get videoEditorRedoSemanticLabel => 'やり直し';

  @override
  String get videoEditorTextColorSemanticLabel => 'テキストの色';

  @override
  String get videoEditorTextAlignmentSemanticLabel => 'テキストの配置';

  @override
  String get videoEditorTextBackgroundSemanticLabel => 'テキストの背景';

  @override
  String get videoEditorFontSemanticLabel => 'フォント';

  @override
  String get videoEditorNoStickersFound => 'ステッカーが見つかりません';

  @override
  String get videoEditorNoStickersAvailable => 'ステッカーがありません';

  @override
  String get videoEditorFailedLoadStickers => 'ステッカーの読み込みに失敗しました';

  @override
  String get videoEditorAdjustVolumeTitle => '音量を調整';

  @override
  String get videoEditorRecordedAudioLabel => '録音済みオーディオ';

  @override
  String get videoEditorVoiceOverLabel => 'ナレーション';

  @override
  String videoEditorVoiceOverTakeName(int number) {
    return '録音 $number';
  }

  @override
  String get videoEditorOpenVoiceOverSemanticLabel => 'ナレーションを録音';

  @override
  String get videoEditorVoiceOverRecordSemanticLabel => '録音を開始';

  @override
  String get videoEditorVoiceOverStopSemanticLabel => '録音を停止';

  @override
  String get videoEditorVoiceOverHint => 'タップして録音。好きなだけテイクを追加できます。';

  @override
  String videoEditorVoiceOverRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '録音$count件',
      one: '録音1件',
      zero: 'まだ録音はありません',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorVoiceOverDeleteLast => '最後の録音を削除';

  @override
  String get videoEditorVoiceOverPermissionTitle => 'マイクへのアクセスが必要です';

  @override
  String get videoEditorVoiceOverPermissionBody =>
      'ナレーションを録音するにはマイクへのアクセスを許可してください。';

  @override
  String get videoEditorVoiceOverOpenSettings => '設定を開く';

  @override
  String get videoEditorVoiceOverRecordingStarted => '録音を開始しました';

  @override
  String get videoEditorVoiceOverRecordingSaved => '録音を保存しました';

  @override
  String get videoEditorVoiceOverTooLong => '録音が動画より長くなっています';

  @override
  String get videoEditorPlaySemanticLabel => '再生';

  @override
  String get videoEditorPauseSemanticLabel => '一時停止';

  @override
  String get videoEditorMuteAudioSemanticLabel => '音声をミュート';

  @override
  String get videoEditorUnmuteAudioSemanticLabel => '音声のミュートを解除';

  @override
  String get videoEditorVolumeSemanticLabel => '音量を調整';

  @override
  String videoEditorTimelineVolumePreview(int percent) {
    return '音量 $percent%';
  }

  @override
  String get videoEditorTimelineSlideToAdjust => 'スライドして調整';

  @override
  String get videoEditorOriginalAudioLabel => '元の音声';

  @override
  String videoEditorClipVolumeLabel(int index) {
    return 'クリップ $index';
  }

  @override
  String get videoEditorDeleteLabel => '削除';

  @override
  String get videoEditorDeleteSelectedItemSemanticLabel => '選択したアイテムを削除';

  @override
  String get videoEditorEditLabel => '編集';

  @override
  String get videoEditorEditSelectedItemSemanticLabel => '選択したアイテムを編集';

  @override
  String get videoEditorDuplicateLabel => '複製';

  @override
  String get videoEditorDuplicateSelectedItemSemanticLabel => '選択したアイテムを複製';

  @override
  String get videoEditorSplitLabel => '分割';

  @override
  String get videoEditorSplitSelectedClipSemanticLabel => '選択したクリップを分割';

  @override
  String get videoEditorExtractAudioLabel => '音声を抽出';

  @override
  String get videoEditorClipAudioTitle => 'クリップ音声';

  @override
  String get videoEditorExtractAudioFromClipSemanticLabel =>
      'クリップから音声を抽出してオリジナルをミュート';

  @override
  String get videoEditorExtractAudioNoLocalFile =>
      '音声を抽出できません：クリップがローカルで利用できません。';

  @override
  String get videoEditorExtractAudioFailed => '音声を抽出できませんでした。もう一度お試しください。';

  @override
  String get videoEditorSpeedLabel => '速度';

  @override
  String get videoEditorSetClipSpeedSemanticLabel => '選択したクリップの再生速度を設定';

  @override
  String get videoEditorReverseLabel => '逆再生';

  @override
  String get videoEditorReverseClipSemanticLabel => '選択したクリップの逆再生を切り替え';

  @override
  String get videoEditorReverseProgressLabel => '少々お待ちください。クリップを逆再生用に処理しています';

  @override
  String get videoEditorTransformLabel => '変形';

  @override
  String get videoEditorTransformSelectedClipSemanticLabel =>
      '選択したクリップをトリミング、回転、または反転';

  @override
  String get videoEditorTransformProgressLabel => 'クリップを変形しています。少々お待ちください';

  @override
  String get videoEditorTransformFailed => 'クリップを変形できませんでした。もう一度お試しください。';

  @override
  String get videoEditorTransformNoLocalFile => '変形できません：クリップがローカルに利用できません。';

  @override
  String get videoEditorTransformRotateLabel => '回転';

  @override
  String get videoEditorTransformFlipLabel => '反転';

  @override
  String get videoEditorTransformRatioLabel => '比率';

  @override
  String get videoEditorTransformResetLabel => 'リセット';

  @override
  String get videoEditorTransformApplySemanticLabel => '変形を適用';

  @override
  String get videoEditorTransformCancelSemanticLabel => '変形をキャンセル';

  @override
  String get videoEditorTransformPlayLabel => '再生';

  @override
  String get videoEditorTransformPauseLabel => '一時停止';

  @override
  String get videoEditorReverseNoLocalFile => '逆再生できません：クリップがローカルで利用できません。';

  @override
  String get videoEditorReverseFailed => 'クリップを逆再生できませんでした。もう一度お試しください。';

  @override
  String get videoEditorSpeedSheetTitle => 'クリップの速度';

  @override
  String get videoEditorTransitionSheetTitle => 'トランジション';

  @override
  String get videoEditorTransitionNone => 'なし';

  @override
  String get videoEditorTransitionDissolve => 'ディゾルブ';

  @override
  String get videoEditorTransitionFadeToBlack => '黒にフェード';

  @override
  String get videoEditorTransitionFadeToWhite => '白にフェード';

  @override
  String get videoEditorTransitionSlide => 'スライド';

  @override
  String get videoEditorTransitionPush => 'プッシュ';

  @override
  String get videoEditorTransitionWipe => 'ワイプ';

  @override
  String get videoEditorTransitionButtonSemanticLabel => 'トランジションを編集';

  @override
  String get videoEditorTransitionDuration => '長さ';

  @override
  String get videoEditorTransitionDurationLimitedHint =>
      '隣接するトランジションと重ならないように短縮されました。';

  @override
  String get videoEditorTransitionCurve => 'カーブ';

  @override
  String get videoEditorTransitionDirection => '方向';

  @override
  String get videoEditorTransitionDirectionLeft => '左';

  @override
  String get videoEditorTransitionDirectionRight => '右';

  @override
  String get videoEditorTransitionDirectionUp => '上';

  @override
  String get videoEditorTransitionDirectionDown => '下';

  @override
  String videoEditorTransitionCurveOptionSemanticLabel(int number) {
    return 'アニメーションカーブ $number';
  }

  @override
  String get videoEditorLayerAnimationLabel => 'アニメーション';

  @override
  String get videoEditorLayerAnimationButtonSemanticLabel => 'レイヤーアニメーションを編集';

  @override
  String get videoEditorLayerAnimationEnter => 'イン';

  @override
  String get videoEditorLayerAnimationLeave => 'アウト';

  @override
  String get videoEditorLayerAnimationFade => 'フェード';

  @override
  String get videoEditorLayerAnimationScale => 'スケール';

  @override
  String get videoEditorLayerAnimationScaleFrom => '開始スケール';

  @override
  String get videoEditorFinishTimelineEditingSemanticLabel => 'タイムライン編集を終了';

  @override
  String get videoEditorAudioPlayPreviewSemanticLabel => 'プレビューを再生';

  @override
  String get videoEditorAudioPausePreviewSemanticLabel => 'プレビューを一時停止';

  @override
  String get videoEditorAudioUntitledSound => 'タイトルなしのサウンド';

  @override
  String get videoEditorAudioUntitled => 'タイトルなし';

  @override
  String get videoEditorAudioAddAudio => 'オーディオを追加';

  @override
  String get videoEditorAudioNoSoundsAvailableTitle => '利用可能なサウンドなし';

  @override
  String get videoEditorAudioNoSoundsAvailableSubtitle =>
      'クリエイターがオーディオを共有するとここに表示されます';

  @override
  String get videoEditorAudioFailedToLoadTitle => 'サウンドの読み込みに失敗';

  @override
  String get videoEditorAudioSegmentInstruction => '動画に使うオーディオ範囲を選択';

  @override
  String get videoEditorAudioCategoryDivine => 'OG Sounds';

  @override
  String get videoEditorAudioCategoryCommunity => 'コミュニティ';

  @override
  String get videoEditorAudioCategoryFeatured => 'おすすめ';

  @override
  String get videoEditorAudioCategoryMySounds => 'マイサウンド';

  @override
  String get videoEditorAudioFeaturedEmptyTitle => 'おすすめサウンドは近日公開';

  @override
  String get videoEditorAudioFeaturedEmptySubtitle =>
      '準備ができ次第、おすすめサウンドをここに掲載します。';

  @override
  String get videoEditorDrawToolArrowSemanticLabel => '矢印ツール';

  @override
  String get videoEditorDrawToolEraserSemanticLabel => '消しゴムツール';

  @override
  String get videoEditorDrawToolMarkerSemanticLabel => 'マーカーツール';

  @override
  String get videoEditorDrawToolPencilSemanticLabel => '鉛筆ツール';

  @override
  String videoEditorLayerReorderLabel(int index) {
    return 'レイヤー$indexを並べ替え';
  }

  @override
  String get videoEditorLayerReorderHint => '長押しして並べ替え';

  @override
  String get videoEditorShowTimelineSemanticLabel => 'タイムラインを表示';

  @override
  String get videoEditorHideTimelineSemanticLabel => 'タイムラインを非表示';

  @override
  String get videoEditorFeedPreviewContent => 'これらのエリアの後ろにコンテンツを配置しないでください。';

  @override
  String get videoEditorStickersDivineOriginals => 'Divine オリジナル';

  @override
  String get videoEditorStickerSearchHint => 'ステッカーを検索...';

  @override
  String get videoEditorSelectFontSemanticLabel => 'フォントを選択';

  @override
  String get videoEditorFontUnknown => '不明';

  @override
  String get videoEditorSplitPlayheadOutsideClip =>
      '分割するには再生ヘッドを選択したクリップ内に置いてください。';

  @override
  String get videoEditorTimelineTrimStartSemanticLabel => '始端をトリム';

  @override
  String get videoEditorTimelineTrimEndSemanticLabel => '終端をトリム';

  @override
  String get videoEditorTimelineTrimClipSemanticLabel => 'クリップをトリム';

  @override
  String get videoEditorTimelineTrimClipHint => 'ハンドルをドラッグしてクリップの長さを調整';

  @override
  String videoEditorTimelineDraggingClipSemanticLabel(int index) {
    return 'クリップ$indexをドラッグ中';
  }

  @override
  String videoEditorTimelineClipSemanticLabel(
    int index,
    int total,
    String duration,
  ) {
    return '$total個中$index番目のクリップ、$duration秒';
  }

  @override
  String get videoEditorTimelineClipReorderHint => '長押しして並べ替え';

  @override
  String get videoEditorClipGalleryInstruction => 'タップして編集。長押ししてドラッグで並べ替え。';

  @override
  String get videoEditorTimelineClipMoveLeft => '左に移動';

  @override
  String get videoEditorTimelineClipMoveRight => '右に移動';

  @override
  String videoEditorTimelineClipSelectedSemanticLabel(int index, int total) {
    return 'クリップ $index/$total、選択中';
  }

  @override
  String videoEditorTimelineClipUnselectedSemanticLabel(int index, int total) {
    return 'クリップ $index/$total、未選択';
  }

  @override
  String get videoEditorMultiSelectLabel => '選択';

  @override
  String get videoEditorMultiSelectSemanticLabel => '複数のクリップを選択';

  @override
  String get videoEditorMultiSelectDoneSemanticLabel => '選択を完了';

  @override
  String videoEditorMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件のクリップを選択中',
      one: '1 件のクリップを選択中',
      zero: 'クリップが選択されていません',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorMergeLabel => '結合';

  @override
  String get videoEditorMergeSelectedClipsSemanticLabel => '選択したクリップを結合';

  @override
  String get videoEditorDeleteSelectedClipsSemanticLabel => '選択したクリップを削除';

  @override
  String get videoEditorMergeProgressLabel => '少々お待ちください。クリップを結合しています';

  @override
  String get videoEditorMergeFailed => 'クリップを結合できませんでした。もう一度お試しください。';

  @override
  String get videoEditorTimelineLongPressToDragHint => '長押しでドラッグ';

  @override
  String get videoEditorVideoTimelineSemanticLabel => '動画タイムライン';

  @override
  String videoEditorTimelinePositionFormat(int minutes, String seconds) {
    return '$minutes分$seconds秒';
  }

  @override
  String videoEditorColorSelectedSemanticLabel(String colorName) {
    return '$colorName、選択済み';
  }

  @override
  String get videoEditorCloseColorPickerSemanticLabel => 'カラーピッカーを閉じる';

  @override
  String get videoEditorPickColorTitle => '色を選択';

  @override
  String get videoEditorConfirmColorSemanticLabel => '色を確定';

  @override
  String get videoEditorSaturationBrightnessSemanticLabel => '彩度と明度';

  @override
  String videoEditorSaturationBrightnessValue(int saturation, int brightness) {
    return '彩度 $saturation%、明度 $brightness%';
  }

  @override
  String get videoEditorHueSemanticLabel => '色相';

  @override
  String get videoEditorAddElementSemanticLabel => '要素を追加';

  @override
  String get videoEditorCloseSemanticLabel => '閉じる';

  @override
  String get videoEditorDoneSemanticLabel => '完了';

  @override
  String get videoEditorLevelSemanticLabel => 'レベル';

  @override
  String get videoMetadataBackSemanticLabel => '戻る';

  @override
  String get videoMetadataDismissHelpDialogSemanticLabel => 'ヘルプダイアログを閉じる';

  @override
  String get videoMetadataGotItButton => 'わかりました！';

  @override
  String get videoMetadataLimitReachedWarning =>
      '64KBの上限に達しました。続けるにはコンテンツを削除してください。';

  @override
  String get videoMetadataExpirationLabel => '有効期限';

  @override
  String get videoMetadataSelectExpirationSemanticLabel => '有効期限を選択';

  @override
  String get videoMetadataTitleLabel => 'タイトル';

  @override
  String get videoMetadataDescriptionLabel => '説明';

  @override
  String get videoMetadataTagsLabel => 'タグ';

  @override
  String get videoMetadataDeleteTagSemanticLabel => '削除';

  @override
  String videoMetadataDeleteTagHint(String tag) {
    return 'タグ$tagを削除';
  }

  @override
  String get videoMetadataContentWarningLabel => 'コンテンツ警告';

  @override
  String get videoMetadataSelectContentWarningsSemanticLabel => 'コンテンツ警告を選択';

  @override
  String get videoMetadataContentWarningSelectAllThatApply =>
      'コンテンツに該当するものをすべて選択';

  @override
  String get videoMetadataContentWarningDoneButton => '完了';

  @override
  String get videoMetadataAudioReuseTitle => 'このサウンドを公開';

  @override
  String get videoMetadataAudioReuseSubtitle =>
      '他のユーザーがこの動画の音声を保存して再利用できるようにします。';

  @override
  String get videoMetadataCollaboratorsLabel => 'コラボレーター';

  @override
  String get videoMetadataAddCollaboratorSemanticLabel => 'コラボレーターを追加';

  @override
  String get videoMetadataCollaboratorsHelpTooltip => 'コラボレーターの仕組み';

  @override
  String videoMetadataCollaboratorsCount(int count, int max) {
    return '$count/$max人のコラボレーター';
  }

  @override
  String get videoMetadataRemoveCollaboratorSemanticLabel => 'コラボレーターを削除';

  @override
  String get videoMetadataCollaboratorsHelpMessage =>
      'コラボレーターはこの投稿の共同クリエイターとしてタグ付けされます。相互フォローしている人のみ追加でき、公開時に投稿メタデータに表示されます。';

  @override
  String get videoMetadataMutualFollowersSearchText => '相互フォロワー';

  @override
  String videoMetadataMustMutuallyFollowSnackbar(String name) {
    return '$nameをコラボレーターとして追加するには、相互フォローが必要です。';
  }

  @override
  String get videoMetadataInspiredByLabel => 'インスパイア元';

  @override
  String get videoMetadataSetInspiredBySemanticLabel => 'インスパイア元を設定';

  @override
  String get videoMetadataInspiredByHelpTooltip => 'インスピレーションクレジットの仕組み';

  @override
  String get videoMetadataInspiredByNone => 'なし';

  @override
  String get videoMetadataInspiredByHelpMessage =>
      '帰属のために使用します。インスパイアクレジットはコラボレーターとは異なります。影響を認めますが、共同クリエイターとしてタグ付けはしません。';

  @override
  String get videoMetadataCreatorCannotBeReferencedSnackbar =>
      'このクリエイターは参照できません。';

  @override
  String get videoMetadataRemoveInspiredBySemanticLabel => 'インスパイア元を削除';

  @override
  String get videoMetadataPostDetailsTitle => '投稿の詳細';

  @override
  String get videoMetadataSavedToLibrarySnackbar => 'ライブラリに保存しました';

  @override
  String get videoMetadataFailedToSaveSnackbar => '保存に失敗しました';

  @override
  String get videoMetadataGoToLibraryButton => 'ライブラリへ';

  @override
  String get videoMetadataSaveForLaterSemanticLabel => '後で保存ボタン';

  @override
  String get videoMetadataRenderingVideoHint => '動画をレンダリング中...';

  @override
  String get videoMetadataSavingVideoHint => '動画を保存中...';

  @override
  String videoMetadataSaveToDraftsHint(String destination) {
    return '動画を下書きと$destinationに保存';
  }

  @override
  String get videoMetadataSaveForLaterButton => '後で保存';

  @override
  String get videoMetadataPostSemanticLabel => '投稿ボタン';

  @override
  String get videoMetadataPublishVideoHint => 'フィードに動画を公開';

  @override
  String get videoMetadataShareReplyToFeedTitle => '自分のフィードにも共有';

  @override
  String get videoMetadataShareReplyToFeedSubtitle =>
      'オフにすると、この動画はコメントスレッド内にのみ表示されます。';

  @override
  String get videoMetadataFormNotReadyHint => '有効にするにはフォームを入力してください';

  @override
  String get videoMetadataPostButton => '投稿';

  @override
  String get videoMetadataOpenPreviewSemanticLabel => '投稿プレビュー画面を開く';

  @override
  String get videoMetadataShareTitle => 'シェア';

  @override
  String get videoMetadataVideoDetailsSubtitle => '動画の詳細';

  @override
  String get videoMetadataClassicDoneButton => '完了';

  @override
  String get videoMetadataPlayPreviewSemanticLabel => 'プレビューを再生';

  @override
  String get videoMetadataPausePreviewSemanticLabel => 'プレビューを一時停止';

  @override
  String get videoMetadataClosePreviewSemanticLabel => '動画プレビューを閉じる';

  @override
  String get videoMetadataRemoveSemanticLabel => '削除';

  @override
  String get fullscreenFeedRemovedMessage => '動画を削除しました';

  @override
  String get settingsBadgesTitle => 'バッジ';

  @override
  String get settingsBadgesSubtitle => '受賞を承認したり、発行したバッジの状態を確認できるよ。';

  @override
  String get badgesTitle => 'バッジ';

  @override
  String get badgesIntroTitle => 'あなたのバッジ履歴をチェック';

  @override
  String get badgesIntroBody =>
      'あなたに送られたバッジを見て、Nostr プロフィールにピンするものを選んだり、自分が発行したバッジが受け取られたか確認できるよ。';

  @override
  String get badgesOpenApp => 'バッジアプリを開く';

  @override
  String get badgesLoadError => 'バッジの読み込みに失敗';

  @override
  String get badgesUpdateError => 'バッジの更新に失敗';

  @override
  String get badgesAwardedSectionTitle => 'あなたへの受賞';

  @override
  String get badgesAwardedEmptyTitle => 'バッジの受賞はまだないよ';

  @override
  String get badgesAwardedEmptySubtitle => '誰かが Nostr バッジを贈ってくれたら、ここに届くよ。';

  @override
  String get badgesStatusAccepted => '承認済み';

  @override
  String get badgesStatusNotAccepted => '未承認';

  @override
  String get badgesActionRemove => '削除';

  @override
  String get badgesActionAccept => '承認';

  @override
  String get badgesActionReject => '拒否';

  @override
  String get badgesIssuedSectionTitle => 'あなたが発行したバッジ';

  @override
  String get badgesIssuedEmptyTitle => '発行したバッジはまだないよ';

  @override
  String get badgesIssuedEmptySubtitle => 'あなたが発行したバッジの承認状況がここに出るよ。';

  @override
  String get badgesIssuedNoRecipients => 'この受賞には受信者が見つからないよ。';

  @override
  String get badgesRecipientAcceptedStatus => '受信者が承認';

  @override
  String get badgesRecipientWaitingStatus => '受信者の承認待ち';

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
  String get minorAccountReviewUnder13HonestyTitle => '「とりあえず戻って」って言わない理由';

  @override
  String get minorAccountReviewUnder13HonestyBody =>
      'ネットの多くは、ゲートを通るためなら何とでも言えるように仕向けられてるよね。それって良くないと思うんだ。確かに、戻って本当の年齢よりも上だって言うこともできるけど、それは正直じゃないし、欲しいものを手に入れるために嘘をつくよう仕向けるつもりはないよ。';

  @override
  String get minorAccountReviewUnder13LegalTitle => 'それでも答えが「ノー」な理由';

  @override
  String get minorAccountReviewUnder13LegalBody =>
      '私たちは、若い人たちが自分自身や周りの人にとって健康的でポジティブな形で Divine を使えるよう手助けしたいと思ってるよ。それに、場所によって違う法律も守らなきゃいけないんだ。だから、もし13歳未満なら、今は自分のアカウントを持つことはできないよ。';

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
      '保護者に関わってもらうようお願いする理由';

  @override
  String get minorAccountReviewParentConsentHonestyBody =>
      'Divine は世界中の年齢に関する法律を守らなきゃいけないよ。それに、技術的な年齢確認のほとんどが完璧じゃないこともわかってる。ルールなんてないふりをしたり、年齢について嘘をつくのがカッコいいみたいにするんじゃなくて、10代の人や家族に Divine の一番いい使い方を一緒に考えてほしいんだ。だから13〜15歳の人には、アカウント作成に保護者が参加するようお願いしてるよ。';

  @override
  String get minorAccountReviewParentConsentLegalBody =>
      '私たちは法律も守らなきゃいけなくて、そのルールは住んでる場所によって違うんだ。だから、ルールなんてないふりをするんじゃなくて、保護者にこのプロセスに参加してもらうようお願いしてるよ。';

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
  String get commentsRecordVideoButtonLabel => '動画コメントを録画';

  @override
  String get commentsOpenVideoLabel => '動画コメントを開く';

  @override
  String get commentsMuteVideoReplyLabel => '動画返信をミュート';

  @override
  String get commentsUnmuteVideoReplyLabel => '動画返信のミュートを解除';

  @override
  String get commentsOpenReplyParentLabel => '返信先の動画を開く';

  @override
  String get commentsReplyParentSectionTitle => '返信先';

  @override
  String commentsReplyParentLabel(String target) {
    return '$target への返信';
  }

  @override
  String get commentsReplyParentFallbackLabel => '動画への返信';

  @override
  String verifiedAccountChipSemanticLabel(String platform, String identity) {
    return '認証済み$platformアカウント: $identity';
  }

  @override
  String get profileEditVerifiedAccountsTitle => '認証済みアカウント';

  @override
  String get profileEditGetVerifiedCta => '認証を受ける';

  @override
  String get profileEditGetVerifiedSubtitle =>
      'ソーシャルメディアのアカウントをつないで、本物のあなただと伝えよう。';

  @override
  String profileWebsiteSemanticLabel(String url) {
    return 'Visit website: $url';
  }

  @override
  String get profileCouldNotOpenWebsite => 'Could not open website';

  @override
  String get videoMetadataEditCoverTitle => 'カバーを編集';

  @override
  String get videoMetadataEditCoverCloseSemanticLabel => 'カバーエディターを閉じる';

  @override
  String get videoMetadataEditCoverConfirmSemanticLabel => 'カバー選択を確認';

  @override
  String get videoMetadataEditCoverStripSemanticLabel =>
      'カバーフレームを選択するために動画をシーク';

  @override
  String get videoMetadataTagsPickerSearchHint => 'タグを検索または追加';

  @override
  String get videoMetadataTagsPickerEmptyHint => 'タグを追加して動画を見つけてもらおう';

  @override
  String get videoMetadataTagsPickerNoResults => '一致するタグがありません';

  @override
  String videoMetadataTagsPickerAddTag(String tag) {
    return '「#$tag」を追加';
  }

  @override
  String get authMinAgeNotice => 'Divine Greenlight';

  @override
  String get authUnder16Prefix => 'まだ16歳じゃない? 大丈夫だよ。 ';

  @override
  String get authUnder16ChoicesCta => 'あなたの選択肢はこちら。';

  @override
  String get minorAccountReviewUnder13WhyTitle => 'Here\'s why';

  @override
  String get generalSettingsHoldToRecord => '長押しで録画';

  @override
  String get generalSettingsHoldToRecordSubtitle => '長押しすると録画が始まり、離すと止まります';

  @override
  String get soundsPreviewFailedGeneric => 'プレビューの再生がうまくいかなかった';

  @override
  String uploadPublishedCountMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count本の動画をプロフィールに公開したよ',
      one: '動画をプロフィールに公開したよ',
    );
    return '$_temp0';
  }

  @override
  String get dmMessageSendLabel => 'Send message';

  @override
  String get emojiPickerSearchHint => '検索';

  @override
  String get emojiCategoryRecent => '最近使った絵文字';

  @override
  String get emojiCategorySmileys => 'スマイリーと人々';

  @override
  String get emojiCategoryAnimals => '動物と自然';

  @override
  String get emojiCategoryFood => '食べ物と飲み物';

  @override
  String get emojiCategoryActivities => 'アクティビティ';

  @override
  String get emojiCategoryTravel => '旅行と場所';

  @override
  String get emojiCategoryObjects => '物';

  @override
  String get emojiCategorySymbols => '記号';

  @override
  String get emojiCategoryFlags => '旗';

  @override
  String get videoEditorMarkerLabel => 'マーカー';

  @override
  String get videoEditorAddTimelineMarkerSemanticLabel => 'タイムラインマーカーを追加';

  @override
  String get videoEditorRemoveTimelineMarkerSemanticLabel => 'タイムラインマーカーを削除';

  @override
  String get videoEditorRemoveTimelineMarkerAtPlayheadSemanticLabel =>
      '再生ヘッド位置のマーカーを削除';

  @override
  String get videoEditorDeleteTimelineMarkerTitle => 'マーカーを削除しますか？';

  @override
  String get videoEditorDeleteTimelineMarkerSubtitle =>
      'タイムラインからマーカーを削除します。編集内容はそのまま残ります。';

  @override
  String get videoEditorVolumeLongPressHint => 'すべてのトラックをミュートまたはミュート解除';

  @override
  String get videoEditorSplitFailed => '分割に失敗しました。もう一度お試しください。';

  @override
  String get videoEditEditSubtitles => '字幕を編集';

  @override
  String get subtitleEditorTitle => '字幕を編集';

  @override
  String get subtitleEditorSave => '保存';

  @override
  String get subtitleEditorProcessing => '字幕はまだ生成中だよ。少し待ってからもう一回見てね。';

  @override
  String get subtitleEditorLoadError => '字幕を読み込めなかったよ。もう一回試してね。';

  @override
  String get subtitleEditorSaveSuccess => '字幕を更新したよ';

  @override
  String get subtitleEditorSaveError => '字幕を保存できなかったよ。もう一回試してね。';

  @override
  String get subtitleEditorRetry => '再試行';

  @override
  String get subtitleEditorCueHint => 'キャプションのテキスト';

  @override
  String get imageCropEditorRotateLabel => '回転';

  @override
  String get imageCropEditorFlipLabel => '反転';

  @override
  String get imageCropEditorResetLabel => 'リセット';

  @override
  String get imageCropEditorCloseSemanticLabel => '切り抜きをキャンセル';

  @override
  String get imageCropEditorDoneSemanticLabel => '切り抜きを適用';

  @override
  String get imageCropEditorProcessing => '切り抜きを適用中…';

  @override
  String get backgroundUploadNotificationTitle => '動画をアップロード中';

  @override
  String get monetizationSettingsTitle => 'Creator Support';

  @override
  String get monetizationSettingsSubtitle => 'Add tip and subscription links';

  @override
  String get monetizationSettingsIntroTitle => 'Outbound links only';

  @override
  String get monetizationSettingsIntroBody =>
      'Add creator-controlled destinations. Divine never handles the payment or unlocks in-app content from these links.';

  @override
  String monetizationSettingsConfiguredCount(int count) {
    return '$count active link(s) on your profile';
  }

  @override
  String get monetizationSettingsTipSection => 'Send a tip';

  @override
  String get monetizationSettingsSubscriptionSection => 'Subscribe / support';

  @override
  String get monetizationSettingsSave => 'Save support links';

  @override
  String get monetizationSettingsSaving => 'Saving...';

  @override
  String get monetizationSettingsSaved => 'Support links updated';

  @override
  String get monetizationSettingsSaveFailed =>
      'Could not save support links. Check your connection and try again.';

  @override
  String get monetizationSettingsErrorEmpty => 'Add a handle or URL.';

  @override
  String get monetizationSettingsErrorInvalid =>
      'That link does not look right.';

  @override
  String get monetizationSettingsErrorWrongProvider =>
      'Use a link for this provider.';

  @override
  String get monetizationSettingsHintCashApp => '\$cashtag or cash.app link';

  @override
  String get monetizationSettingsHintPayPal => 'PayPal.me handle or link';

  @override
  String get monetizationSettingsHintVenmo => 'Venmo handle or link';

  @override
  String get monetizationSettingsHintPatreon => 'Patreon handle or link';

  @override
  String get monetizationSettingsHintSubstack => 'Substack domain or link';

  @override
  String get monetizationSettingsHintMedium => 'Medium handle or link';

  @override
  String get monetizationSettingsHintOpenCollective =>
      'Open Collective slug or link';

  @override
  String get profileSupportSheetTitle => 'Support this creator';

  @override
  String get profileSupportSheetBody =>
      'These links open outside Divine. Nothing here unlocks content in the app.';

  @override
  String get profileSupportTipSection => 'Send a tip';

  @override
  String get profileSupportSubscriptionSection => 'Subscribe / support';

  @override
  String get profileSupportButtonLabel => 'Support';

  @override
  String get monetizationTipsSettingsTitle => 'Tips';

  @override
  String get monetizationTipsSettingsSubtitle => 'Add optional tip links';

  @override
  String get monetizationTipsSettingsIntroTitle => 'Optional tips only';

  @override
  String get monetizationTipsSettingsIntroBody =>
      'Tips are optional user-to-user gifts. They do not unlock content, subscriptions, features, ranking, visibility, or access in Divine.';

  @override
  String monetizationTipsSettingsConfiguredCount(int count) {
    return '$count active tip link(s) on your profile';
  }

  @override
  String get monetizationTipsSettingsSave => 'Save tip links';

  @override
  String get monetizationTipsSettingsSaved => 'Tip links updated';

  @override
  String get profileTipButtonLabel => 'Tip';

  @override
  String get profileTipSheetTitle => 'Tip this creator';

  @override
  String get profileTipSheetBody =>
      'Tips open outside Divine. They are optional and do not unlock content, subscriptions, features, or access in Divine.';
}
