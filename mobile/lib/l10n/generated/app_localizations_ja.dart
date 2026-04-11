// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Divine';

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsSecureAccount => 'アカウントを保護';

  @override
  String get settingsSessionExpired => 'セッションの有効期限切れ';

  @override
  String get settingsSessionExpiredSubtitle => '再度サインインして完全なアクセスを復元してください';

  @override
  String get settingsCreatorAnalytics => 'クリエイター分析';

  @override
  String get settingsSupportCenter => 'サポートセンター';

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
  String get settingsIntegratedAppsSubtitle => 'Divine 内で動作する承認済みサードパーティアプリ';

  @override
  String get settingsExperimentalFeatures => '実験的機能';

  @override
  String get settingsExperimentalFeaturesSubtitle =>
      '不具合が出るかもしれない設定——興味があれば試してみてください。';

  @override
  String get settingsLegal => '法的情報';

  @override
  String get settingsIntegrationPermissions => '連携の権限';

  @override
  String get settingsIntegrationPermissionsSubtitle => '記憶された連携の承認を確認・取り消しします';

  @override
  String settingsVersion(String version) {
    return 'バージョン $version';
  }

  @override
  String get settingsVersionEmpty => 'バージョン';

  @override
  String get settingsDeveloperModeAlreadyEnabled => '開発者モードはすでに有効です';

  @override
  String get settingsDeveloperModeEnabled => '開発者モードを有効にしました!';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    return '開発者モードを有効にするにはあと$count回タップ';
  }

  @override
  String get settingsInvites => '招待';

  @override
  String get settingsSwitchAccount => 'アカウントを切り替え';

  @override
  String get settingsAddAnotherAccount => '別のアカウントを追加';

  @override
  String get settingsUnsavedDraftsTitle => '未保存の下書き';

  @override
  String settingsUnsavedDraftsMessage(int count) {
    return '未保存の下書きが$count件あります。アカウントを切り替えても下書きは保持されますが、先に公開または確認しておくことをおすすめします。';
  }

  @override
  String get settingsCancel => 'キャンセル';

  @override
  String get settingsSwitchAnyway => 'それでも切り替え';

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
  String get settingsAppLanguageDescription => 'アプリのインターフェースの言語を選択してください';

  @override
  String get settingsAppLanguageUseDeviceLanguage => 'デバイスの言語を使用';

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
      '動画に言語タグを付けると、視聴者がコンテンツをフィルターできます。';

  @override
  String get contentPreferencesUseDeviceLanguage => 'デバイスの言語を使用 (既定)';

  @override
  String get contentPreferencesAudioSharing => '自分の音声を再利用可能にする';

  @override
  String get contentPreferencesAudioSharingSubtitle =>
      '有効にすると、他の人があなたの動画の音声を使えます';

  @override
  String get contentPreferencesAccountLabels => 'アカウントラベル';

  @override
  String get contentPreferencesAccountLabelsEmpty => '自分のコンテンツにラベルを付ける';

  @override
  String get contentPreferencesAccountContentLabels => 'アカウントのコンテンツラベル';

  @override
  String get contentPreferencesClearAll => 'すべてクリア';

  @override
  String get contentPreferencesSelectAllThatApply => 'あなたのアカウントに当てはまるものをすべて選択';

  @override
  String get contentPreferencesDoneNoLabels => '完了 (ラベルなし)';

  @override
  String contentPreferencesDoneCount(int count) {
    return '完了 ($count件選択)';
  }

  @override
  String get contentPreferencesAudioInputDevice => '音声入力デバイス';

  @override
  String get contentPreferencesAutoRecommended => '自動 (推奨)';

  @override
  String get contentPreferencesAutoSelectsBest => '最適なマイクを自動的に選択します';

  @override
  String get contentPreferencesSelectAudioInput => '音声入力を選択';

  @override
  String get contentPreferencesUnknownMicrophone => '不明なマイク';

  @override
  String get profileBlockedAccountNotAvailable => 'このアカウントは利用できません';

  @override
  String profileErrorPrefix(Object error) {
    return 'エラー: $error';
  }

  @override
  String get profileInvalidId => '無効なプロフィール ID';

  @override
  String profileShareText(String displayName, String npub) {
    return 'Divine の $displayName をチェック!\n\nhttps://divine.video/profile/$npub';
  }

  @override
  String profileShareSubject(String displayName) {
    return 'Divine の $displayName';
  }

  @override
  String profileShareFailed(Object error) {
    return 'プロフィールの共有に失敗しました: $error';
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
  String get profilePublicKeyCopied => '公開鍵をクリップボードにコピーしました';

  @override
  String get profileEmbedCodeCopied => '埋め込みコードをクリップボードにコピーしました';

  @override
  String get profileRefreshTooltip => '更新';

  @override
  String get profileRefreshSemanticLabel => 'プロフィールを更新';

  @override
  String get profileMoreTooltip => 'その他';

  @override
  String get profileMoreSemanticLabel => 'その他のオプション';

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
  String profileFollowerCountUsers(int count) {
    return '$count人';
  }

  @override
  String profileBlockTitle(String displayName) {
    return '$displayNameをブロックしますか?';
  }

  @override
  String get profileBlockExplanation => 'ユーザーをブロックすると:';

  @override
  String get profileBlockBulletHidePosts => 'その人の投稿はフィードに表示されなくなります。';

  @override
  String get profileBlockBulletCantView =>
      'その人はあなたのプロフィール閲覧、フォロー、投稿の閲覧ができなくなります。';

  @override
  String get profileBlockBulletNoNotify => 'この変更は相手に通知されません。';

  @override
  String get profileBlockBulletYouCanView => 'あなたはその人のプロフィールを引き続き閲覧できます。';

  @override
  String profileBlockConfirmButton(String displayName) {
    return '$displayNameをブロック';
  }

  @override
  String get profileCancelButton => 'キャンセル';

  @override
  String get profileLearnMore => '詳細を見る';

  @override
  String profileUnblockTitle(String displayName) {
    return '$displayNameのブロックを解除しますか?';
  }

  @override
  String get profileUnblockExplanation => 'このユーザーのブロックを解除すると:';

  @override
  String get profileUnblockBulletShowPosts => 'その人の投稿がフィードに表示されるようになります。';

  @override
  String get profileUnblockBulletCanView =>
      'その人はあなたのプロフィール閲覧、フォロー、投稿の閲覧ができるようになります。';

  @override
  String get profileUnblockBulletNoNotify => 'この変更は相手に通知されません。';

  @override
  String get profileLearnMoreAt => '詳細はこちら: ';

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
  String get profileUserBlockedTitle => 'ユーザーをブロックしました';

  @override
  String get profileUserBlockedContent => 'このユーザーのコンテンツはフィードに表示されません。';

  @override
  String get profileUserBlockedUnblockHint =>
      'いつでもプロフィールまたは[設定] > [安全]からブロックを解除できます。';

  @override
  String get profileCloseButton => '閉じる';

  @override
  String get profileNoCollabsTitle => 'コラボ動画はまだありません';

  @override
  String get profileCollabsOwnEmpty => 'あなたがコラボした動画がここに表示されます';

  @override
  String get profileCollabsOtherEmpty => 'この人がコラボした動画がここに表示されます';

  @override
  String get profileErrorLoadingCollabs => 'コラボ動画の読み込みエラー';

  @override
  String get profileNoCommentsOwnTitle => 'コメントはまだありません';

  @override
  String get profileNoCommentsOtherTitle => 'コメントなし';

  @override
  String get profileCommentsOwnEmpty => 'あなたのコメントと返信がここに表示されます';

  @override
  String get profileCommentsOtherEmpty => 'この人のコメントと返信がここに表示されます';

  @override
  String get profileErrorLoadingComments => 'コメントの読み込みエラー';

  @override
  String get profileVideoRepliesSection => '動画の返信';

  @override
  String get profileCommentsSection => 'コメント';

  @override
  String get profileEditLabel => '編集';

  @override
  String get profileLibraryLabel => 'ライブラリ';

  @override
  String get profileNoLikedVideosTitle => 'いいねした動画はまだありません';

  @override
  String get profileLikedOwnEmpty => 'あなたがいいねした動画がここに表示されます';

  @override
  String get profileLikedOtherEmpty => 'この人がいいねした動画がここに表示されます';

  @override
  String get profileErrorLoadingLiked => 'いいねした動画の読み込みエラー';

  @override
  String get profileNoRepostsTitle => 'リポストはまだありません';

  @override
  String get profileRepostsOwnEmpty => 'あなたがリポストした動画がここに表示されます';

  @override
  String get profileRepostsOtherEmpty => 'この人がリポストした動画がここに表示されます';

  @override
  String get profileErrorLoadingReposts => 'リポストした動画の読み込みエラー';

  @override
  String get profileLoadingTitle => 'プロフィールを読み込み中...';

  @override
  String get profileLoadingSubtitle => '少々お待ちください';

  @override
  String get profileLoadingVideos => '動画を読み込み中...';

  @override
  String get profileNoVideosTitle => '動画はまだありません';

  @override
  String get profileNoVideosOwnSubtitle => '最初の動画を共有してここに表示しましょう';

  @override
  String get profileNoVideosOtherSubtitle => 'このユーザーはまだ動画を共有していません';

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
  String get profileCompleteSubtitle => '名前、自己紹介、画像を追加して始めましょう';

  @override
  String get profileSetUpButton => '設定する';

  @override
  String get profileVerifyingEmail => 'メールを確認中...';

  @override
  String profileCheckEmailVerification(String email) {
    return '認証リンクは $email を確認してください';
  }

  @override
  String get profileWaitingForVerification => 'メール認証を待っています';

  @override
  String get profileVerificationFailed => '認証に失敗しました';

  @override
  String get profilePleaseTryAgain => 'もう一度お試しください';

  @override
  String get profileSecureYourAccount => 'アカウントを保護';

  @override
  String get profileSecureSubtitle => 'メールとパスワードを追加すれば、どのデバイスからでもアカウントを復元できます';

  @override
  String get profileRetryButton => '再試行';

  @override
  String get profileRegisterButton => '登録';

  @override
  String get profileSessionExpired => 'セッションの有効期限切れ';

  @override
  String get profileSignInToRestore => '再度サインインして完全なアクセスを復元してください';

  @override
  String get profileSignInButton => 'サインイン';

  @override
  String get profileDismissTooltip => '閉じる';

  @override
  String get profileLinkCopied => 'プロフィールのリンクをコピーしました';

  @override
  String get profileSetupEditProfileTitle => 'プロフィールを編集';

  @override
  String get profileSetupBackLabel => '戻る';

  @override
  String get profileSetupAboutNostr => 'Nostr について';

  @override
  String get profileSetupProfilePublished => 'プロフィールを公開しました!';

  @override
  String get profileSetupCreateNewProfile => '新しいプロフィールを作成しますか?';

  @override
  String get profileSetupNoExistingProfile =>
      'リレーに既存のプロフィールが見つかりませんでした。公開すると新しいプロフィールが作成されます。続けますか?';

  @override
  String get profileSetupPublishButton => '公開';

  @override
  String get profileSetupUsernameTaken => 'このユーザー名は今しがた取得されました。別の名前を選んでください。';

  @override
  String get profileSetupClaimFailed => 'ユーザー名の取得に失敗しました。もう一度お試しください。';

  @override
  String get profileSetupPublishFailed => 'プロフィールの公開に失敗しました。もう一度お試しください。';

  @override
  String get profileSetupDisplayNameLabel => '表示名';

  @override
  String get profileSetupDisplayNameHint => 'みんなに何と呼ばれたいですか?';

  @override
  String get profileSetupDisplayNameHelper => '好きな名前やラベルを使えます。一意である必要はありません。';

  @override
  String get profileSetupDisplayNameRequired => '表示名を入力してください';

  @override
  String get profileSetupBioLabel => '自己紹介 (任意)';

  @override
  String get profileSetupBioHint => 'あなた自身について書いてください...';

  @override
  String get profileSetupPublicKeyLabel => '公開鍵 (npub)';

  @override
  String get profileSetupUsernameLabel => 'ユーザー名 (任意)';

  @override
  String get profileSetupUsernameHint => 'ユーザー名';

  @override
  String get profileSetupUsernameHelper => 'Divine での固有の ID';

  @override
  String get profileSetupProfileColorLabel => 'プロフィールカラー (任意)';

  @override
  String get profileSetupSaveButton => '保存';

  @override
  String get profileSetupSavingButton => '保存中...';

  @override
  String get profileSetupImageUrlTitle => '画像 URL を追加';

  @override
  String get profileSetupPictureUploaded => 'プロフィール画像をアップロードしました!';

  @override
  String get profileSetupImageSelectionFailed =>
      '画像の選択に失敗しました。代わりに下に画像 URL を貼り付けてください。';

  @override
  String profileSetupCameraAccessFailed(Object error) {
    return 'カメラへのアクセスに失敗しました: $error';
  }

  @override
  String get profileSetupGotItButton => '了解';

  @override
  String profileSetupUploadFailedGeneric(Object error) {
    return '画像のアップロードに失敗しました: $error';
  }

  @override
  String get profileSetupUploadNetworkError =>
      'ネットワークエラー: インターネット接続を確認してもう一度お試しください。';

  @override
  String get profileSetupUploadAuthError => '認証エラー: 一度ログアウトして再度ログインしてください。';

  @override
  String get profileSetupUploadFileTooLarge =>
      'ファイルが大きすぎます: 小さい画像を選んでください (最大 10MB)。';

  @override
  String get profileSetupUsernameChecking => '利用可能か確認中...';

  @override
  String get profileSetupUsernameAvailable => 'このユーザー名は利用可能です!';

  @override
  String get profileSetupUsernameTakenIndicator => 'このユーザー名はすでに使われています';

  @override
  String get profileSetupUsernameReserved => 'このユーザー名は予約されています';

  @override
  String get profileSetupContactSupport => 'サポートに連絡';

  @override
  String get profileSetupCheckAgain => 'もう一度確認';

  @override
  String get profileSetupUsernameBurned => 'このユーザー名はもう利用できません';

  @override
  String get profileSetupUsernameInvalidFormat => '使えるのは英数字とハイフンのみです';

  @override
  String get profileSetupUsernameInvalidLength => 'ユーザー名は3〜20文字で入力してください';

  @override
  String get profileSetupUsernameNetworkError => '利用可能か確認できませんでした。もう一度お試しください。';

  @override
  String get profileSetupUsernameInvalidFormatGeneric => 'ユーザー名の形式が正しくありません';

  @override
  String get profileSetupUsernameCheckFailed => '利用可能か確認できませんでした';

  @override
  String get profileSetupUsernameReservedTitle => 'ユーザー名は予約済み';

  @override
  String profileSetupUsernameReservedBody(String username) {
    return '$username は予約済みの名前です。なぜあなたのものであるべきかを教えてください。';
  }

  @override
  String get profileSetupUsernameReservedHint => '例: ブランド名、アーティスト名など。';

  @override
  String get profileSetupUsernameReservedCheckHint =>
      'すでにサポートに連絡済みですか? [もう一度確認]をタップして、解放されたか確認してください。';

  @override
  String get profileSetupSupportRequestSent => 'サポートリクエストを送信しました! すぐにご連絡します。';

  @override
  String get profileSetupCouldntOpenEmail =>
      'メールアプリを開けませんでした。送信先: names@divine.video';

  @override
  String get profileSetupSendRequest => 'リクエストを送信';

  @override
  String get profileSetupPickColorTitle => '色を選ぶ';

  @override
  String get profileSetupSelectButton => '選択';

  @override
  String get profileSetupUseOwnNip05 => '自分の NIP-05 アドレスを使用';

  @override
  String get profileSetupNip05AddressLabel => 'NIP-05 アドレス';

  @override
  String get profileSetupProfilePicturePreview => 'プロフィール画像のプレビュー';

  @override
  String get nostrInfoIntroBuiltOn => 'DiVine は Nostr の上に作られています。';

  @override
  String get nostrInfoIntroDescription =>
      ' 検閲耐性のあるオープンなプロトコルで、特定の企業やプラットフォームに依存せずにオンラインでコミュニケーションできます。 ';

  @override
  String get nostrInfoIntroIdentity =>
      'Divine にサインアップすると、新しい Nostr ID が作成されます。';

  @override
  String get nostrInfoOwnership =>
      'Nostr なら自分のコンテンツ、ID、ソーシャルグラフを自分のものとして持てて、さまざまなアプリをまたいで使えます。結果として選択肢が増え、ロックインが減り、より健全でしなやかなソーシャルインターネットが実現します。';

  @override
  String get nostrInfoLingo => 'Nostr 用語:';

  @override
  String get nostrInfoNpubLabel => 'npub:';

  @override
  String get nostrInfoNpubDescription =>
      ' あなたの公開 Nostr アドレス。共有しても安全で、他の Nostr アプリ越しにあなたを見つけたり、フォローしたり、メッセージを送ったりできるようになります。';

  @override
  String get nostrInfoNsecLabel => 'nsec:';

  @override
  String get nostrInfoNsecDescription =>
      ' あなたの秘密鍵で、所有権の証明です。これによって Nostr ID を完全に掌握できるので、';

  @override
  String get nostrInfoNsecWarning => '絶対に秘密にしておいてください!';

  @override
  String get nostrInfoUsernameLabel => 'Nostr ユーザー名:';

  @override
  String get nostrInfoUsernameDescription =>
      ' 人間が読める名前 (例: @name.divine.video) で、あなたの npub にリンクします。メールアドレスのように、Nostr ID を認識したり確認しやすくしてくれます。';

  @override
  String get nostrInfoLearnMoreAt => '詳細はこちら: ';

  @override
  String get nostrInfoGotIt => '了解!';

  @override
  String get profileTabRefreshTooltip => '更新';

  @override
  String get videoGridRefreshLabel => 'さらに動画を検索中';

  @override
  String get videoGridOptionsTitle => '動画オプション';

  @override
  String get videoGridEditVideo => '動画を編集';

  @override
  String get videoGridEditVideoSubtitle => 'タイトル、説明、ハッシュタグを更新';

  @override
  String get videoGridDeleteVideo => '動画を削除';

  @override
  String get videoGridDeleteVideoSubtitle => 'このコンテンツを完全に削除';

  @override
  String get videoGridDeleteConfirmTitle => '動画を削除';

  @override
  String get videoGridDeleteConfirmMessage => 'この動画を本当に削除しますか?';

  @override
  String get videoGridDeleteConfirmNote =>
      'すべてのリレーに削除リクエスト (NIP-09) を送信します。一部のリレーではコンテンツが保持されたままになる場合があります。';

  @override
  String get videoGridDeleteCancel => 'キャンセル';

  @override
  String get videoGridDeleteConfirm => '削除';

  @override
  String get videoGridDeletingContent => 'コンテンツを削除中...';

  @override
  String get videoGridDeleteSuccess => '削除リクエストを送信しました';

  @override
  String videoGridDeleteFailure(Object error) {
    return 'コンテンツの削除に失敗しました: $error';
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
  String get exploreNoVideosAvailable => '利用可能な動画がありません';

  @override
  String exploreErrorPrefix(Object error) {
    return 'エラー: $error';
  }

  @override
  String get exploreDiscoverLists => 'リストを見つける';

  @override
  String get exploreAboutLists => 'リストについて';

  @override
  String get exploreAboutListsDescription =>
      'リストを使うと、Divine のコンテンツを2つの方法で整理・キュレーションできます:';

  @override
  String get explorePeopleLists => 'ピープルリスト';

  @override
  String get explorePeopleListsDescription => 'クリエイターのグループをフォローして、最新の動画を見よう';

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
    return 'リストの読み込みエラー: $error';
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
  String get videoPlayerEditVideo => '動画を編集';

  @override
  String get videoPlayerEditVideoTooltip => '動画を編集';

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
  String get contentWarningDescNudity => 'ヌードまたは部分的なヌードを含みます';

  @override
  String get contentWarningDescSexual => '性的なコンテンツを含みます';

  @override
  String get contentWarningDescPorn => '露骨なポルノコンテンツを含みます';

  @override
  String get contentWarningDescGraphicMedia => '刺激的または不快な映像を含みます';

  @override
  String get contentWarningDescViolence => '暴力的なコンテンツを含みます';

  @override
  String get contentWarningDescSelfHarm => '自傷行為への言及を含みます';

  @override
  String get contentWarningDescDrugs => '薬物関連のコンテンツを含みます';

  @override
  String get contentWarningDescAlcohol => 'アルコール関連のコンテンツを含みます';

  @override
  String get contentWarningDescTobacco => 'タバコ関連のコンテンツを含みます';

  @override
  String get contentWarningDescGambling => 'ギャンブル関連のコンテンツを含みます';

  @override
  String get contentWarningDescProfanity => '強い表現を含みます';

  @override
  String get contentWarningDescFlashingLights => '点滅する光を含みます (光過敏症への警告)';

  @override
  String get contentWarningDescAiGenerated => 'このコンテンツは AI によって生成されました';

  @override
  String get contentWarningDescSpoiler => 'ネタバレを含みます';

  @override
  String get contentWarningDescContentWarning => 'クリエイターがこれをセンシティブとしてマークしました';

  @override
  String get contentWarningDescDefault => 'クリエイターがこのコンテンツにフラグを立てました';

  @override
  String get contentWarningDetailsTitle => 'コンテンツ警告';

  @override
  String get contentWarningDetailsSubtitle => 'クリエイターが付けたラベル:';

  @override
  String get contentWarningManageFilters => 'コンテンツフィルターを管理';

  @override
  String get contentWarningViewAnyway => 'それでも表示';

  @override
  String get contentWarningHideAllLikeThis => 'こういうコンテンツをすべて非表示';

  @override
  String get contentWarningNoFilterYet => 'この警告に対する保存済みフィルターはまだありません。';

  @override
  String get contentWarningHiddenConfirmation => 'これ以降、このような投稿は非表示にします。';

  @override
  String get videoErrorNotFound => '動画が見つかりません';

  @override
  String get videoErrorNetwork => 'ネットワークエラー';

  @override
  String get videoErrorTimeout => '読み込みタイムアウト';

  @override
  String get videoErrorFormat => '動画フォーマットエラー\n(もう一度試すか、別のブラウザを使ってください)';

  @override
  String get videoErrorUnsupportedFormat => '非対応の動画フォーマット';

  @override
  String get videoErrorPlayback => '動画再生エラー';

  @override
  String get videoErrorAgeRestricted => '年齢制限のあるコンテンツ';

  @override
  String get videoErrorVerifyAge => '年齢を確認';

  @override
  String get videoErrorRetry => '再試行';

  @override
  String get videoErrorContentRestricted => 'コンテンツが制限されています';

  @override
  String get videoErrorContentRestrictedBody => 'この動画はリレーによって制限されました。';

  @override
  String get videoErrorVerifyAgeBody => 'この動画を見るには年齢確認が必要です。';

  @override
  String get videoErrorSkip => 'スキップ';

  @override
  String get videoErrorVerifyAgeButton => '年齢を確認';

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
    return '$_temp0。タップしてプロフィールを表示。';
  }

  @override
  String get listAttributionFallback => 'リスト';

  @override
  String get shareVideoLabel => '動画を共有';

  @override
  String sharePostSharedWith(String recipientName) {
    return '$recipientNameに投稿を共有しました';
  }

  @override
  String get shareFailedToSend => '動画の送信に失敗しました';

  @override
  String get shareAddedToBookmarks => 'ブックマークに追加しました';

  @override
  String get shareFailedToAddBookmark => 'ブックマークの追加に失敗しました';

  @override
  String get shareActionFailed => '操作に失敗しました';

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
  String shareSendingTo(String name) {
    return '$nameに送信中';
  }

  @override
  String get shareMessageHint => 'メッセージを追加 (任意)...';

  @override
  String get videoActionUnlike => '動画のいいねを取り消す';

  @override
  String get videoActionLike => '動画にいいね';

  @override
  String get videoActionRemoveRepost => 'リポストを取り消す';

  @override
  String get videoActionRepost => '動画をリポスト';

  @override
  String get videoActionViewComments => 'コメントを表示';

  @override
  String get videoActionMoreOptions => 'その他のオプション';

  @override
  String get videoActionHideSubtitles => '字幕を非表示';

  @override
  String get videoActionShowSubtitles => '字幕を表示';

  @override
  String videoDescriptionLoops(String count) {
    return '$countループ';
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
  String get metadataLoopsLabel => 'ループ';

  @override
  String get metadataLikesLabel => 'いいね';

  @override
  String get metadataCommentsLabel => 'コメント';

  @override
  String get metadataRepostsLabel => 'リポスト';

  @override
  String get devOptionsTitle => '開発者オプション';

  @override
  String get devOptionsPageLoadTimes => 'ページ読み込み時間';

  @override
  String get devOptionsNoPageLoads =>
      'ページ読み込みはまだ記録されていません。\nアプリ内を移動するとタイミングデータが表示されます。';

  @override
  String devOptionsPageLoadVisible(String visibleMs, String dataMs) {
    return '表示: ${visibleMs}ms  |  データ: ${dataMs}ms';
  }

  @override
  String get devOptionsSlowestScreens => '最も遅い画面';

  @override
  String get devOptionsVideoPlaybackFormat => '動画再生フォーマット';

  @override
  String get devOptionsSwitchEnvironmentTitle => '環境を切り替えますか?';

  @override
  String devOptionsSwitchEnvironmentMessage(String envName) {
    return '$envNameに切り替えますか?\n\nキャッシュされた動画データがクリアされ、新しいリレーに再接続されます。';
  }

  @override
  String get devOptionsCancel => 'キャンセル';

  @override
  String get devOptionsSwitch => '切り替え';

  @override
  String devOptionsSwitchedTo(String envName) {
    return '$envNameに切り替えました';
  }

  @override
  String devOptionsSwitchedFormat(String formatName) {
    return '$formatNameに切り替えました — キャッシュをクリアしました';
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
      'アプリがクラッシュしたり挙動がおかしい場合は、キャッシュのクリアを試してください。';

  @override
  String get featureFlagClearAllCache => 'すべてのキャッシュをクリア';

  @override
  String get featureFlagCacheInfo => 'キャッシュ情報';

  @override
  String get featureFlagClearCacheTitle => 'すべてのキャッシュをクリアしますか?';

  @override
  String get featureFlagClearCacheMessage =>
      '次のキャッシュデータをすべてクリアします:\n• 通知\n• ユーザープロフィール\n• ブックマーク\n• 一時ファイル\n\n再度ログインが必要になります。続けますか?';

  @override
  String get featureFlagClearCache => 'キャッシュをクリア';

  @override
  String get featureFlagClearingCache => 'キャッシュをクリア中...';

  @override
  String get featureFlagSuccess => '成功';

  @override
  String get featureFlagError => 'エラー';

  @override
  String get featureFlagClearCacheSuccess => 'キャッシュをクリアしました。アプリを再起動してください。';

  @override
  String get featureFlagClearCacheFailure =>
      '一部のキャッシュ項目のクリアに失敗しました。詳細はログをご確認ください。';

  @override
  String get featureFlagOk => 'OK';

  @override
  String get featureFlagCacheInformation => 'キャッシュ情報';

  @override
  String featureFlagTotalCacheSize(String size) {
    return 'キャッシュ合計サイズ: $size';
  }

  @override
  String get featureFlagCacheIncludes =>
      'キャッシュに含まれるもの:\n• 通知履歴\n• ユーザープロフィールデータ\n• 動画サムネイル\n• 一時ファイル\n• データベースインデックス';

  @override
  String get relaySettingsTitle => 'リレー';

  @override
  String get relaySettingsInfoTitle => 'Divine はオープンなシステムです——接続はあなたがコントロールできます';

  @override
  String get relaySettingsInfoDescription =>
      'これらのリレーは、あなたのコンテンツを分散型の Nostr ネットワークに配信します。リレーはお好みで追加・削除できます。';

  @override
  String get relaySettingsLearnMoreNostr => 'Nostr について詳しく →';

  @override
  String get relaySettingsFindPublicRelays => 'nostr.co.uk でパブリックリレーを探す →';

  @override
  String get relaySettingsAppNotFunctional => 'アプリが動作しません';

  @override
  String get relaySettingsRequiresRelay =>
      'Divine では、動画の読み込み、コンテンツの投稿、データの同期に少なくとも1つのリレーが必要です。';

  @override
  String get relaySettingsRestoreDefaultRelay => '既定のリレーを復元';

  @override
  String get relaySettingsAddCustomRelay => 'カスタムリレーを追加';

  @override
  String get relaySettingsAddRelay => 'リレーを追加';

  @override
  String get relaySettingsRetry => '再試行';

  @override
  String get relaySettingsNoStats => '統計情報はまだありません';

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
  String get relaySettingsRemoveRelayTitle => 'リレーを削除しますか?';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return 'このリレーを本当に削除しますか?\n\n$relayUrl';
  }

  @override
  String get relaySettingsCancel => 'キャンセル';

  @override
  String get relaySettingsRemove => '削除';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return 'リレーを削除しました: $relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay => 'リレーの削除に失敗しました';

  @override
  String get relaySettingsForcingReconnection => 'リレーの再接続を実行中...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    return '$count個のリレーに接続しました!';
  }

  @override
  String get relaySettingsFailedToConnectCheck =>
      'リレーへの接続に失敗しました。ネットワーク接続を確認してください。';

  @override
  String get relaySettingsAddRelayTitle => 'リレーを追加';

  @override
  String get relaySettingsAddRelayPrompt =>
      '追加したいリレーの WebSocket URL を入力してください:';

  @override
  String get relaySettingsBrowsePublicRelays => 'nostr.co.uk でパブリックリレーを見る';

  @override
  String get relaySettingsAdd => '追加';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return 'リレーを追加しました: $relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay =>
      'リレーの追加に失敗しました。URL を確認してもう一度お試しください。';

  @override
  String get relaySettingsInvalidUrl =>
      'リレー URL は wss:// または ws:// で始まる必要があります';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return '既定のリレーを復元しました: $defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault =>
      '既定のリレーの復元に失敗しました。ネットワーク接続を確認してください。';

  @override
  String get relaySettingsCouldNotOpenBrowser => 'ブラウザを開けませんでした';

  @override
  String get relaySettingsFailedToOpenLink => 'リンクを開けませんでした';

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
  String get relayDiagnosticReady => '準備完了';

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
      '• 緑のステータス = 接続済み・動作中\n• 赤のステータス = 接続に失敗\n• ネットワークテストが失敗する場合は、インターネット接続を確認してください\n• リレーが設定されているのに接続されない場合は [接続を再試行]をタップしてください\n• デバッグ用にこの画面をスクリーンショットしてください';

  @override
  String get relayDiagnosticAllEndpointsHealthy => 'すべての REST エンドポイントは正常です!';

  @override
  String get relayDiagnosticSomeEndpointsFailed =>
      '一部の REST エンドポイントが失敗しました - 上の詳細をご確認ください';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    return 'データベースで$count件の動画イベントが見つかりました';
  }

  @override
  String relayDiagnosticQueryFailed(String error) {
    return 'クエリに失敗しました: $error';
  }

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    return '$count個のリレーに接続しました!';
  }

  @override
  String get relayDiagnosticFailedToConnect => 'どのリレーにも接続できませんでした';

  @override
  String relayDiagnosticConnectionRetryFailed(String error) {
    return '接続の再試行に失敗しました: $error';
  }

  @override
  String get relayDiagnosticConnectedAuthenticated => '接続・認証済み';

  @override
  String get relayDiagnosticConnectedOnly => '接続済み';

  @override
  String get relayDiagnosticNotConnected => '未接続';

  @override
  String get relayDiagnosticNoRelaysConfigured => 'リレーが設定されていません';

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
  String get notificationSettingsLikesSubtitle => '誰かがあなたの動画にいいねしたとき';

  @override
  String get notificationSettingsComments => 'コメント';

  @override
  String get notificationSettingsCommentsSubtitle => '誰かがあなたの動画にコメントしたとき';

  @override
  String get notificationSettingsFollows => 'フォロー';

  @override
  String get notificationSettingsFollowsSubtitle => '誰かがあなたをフォローしたとき';

  @override
  String get notificationSettingsMentions => 'メンション';

  @override
  String get notificationSettingsMentionsSubtitle => 'あなたがメンションされたとき';

  @override
  String get notificationSettingsReposts => 'リポスト';

  @override
  String get notificationSettingsRepostsSubtitle => '誰かがあなたの動画をリポストしたとき';

  @override
  String get notificationSettingsSystem => 'システム';

  @override
  String get notificationSettingsSystemSubtitle => 'アプリのアップデートとシステムメッセージ';

  @override
  String get notificationSettingsPushNotificationsSection => 'プッシュ通知';

  @override
  String get notificationSettingsPushNotifications => 'プッシュ通知';

  @override
  String get notificationSettingsPushNotificationsSubtitle =>
      'アプリを閉じているときも通知を受け取る';

  @override
  String get notificationSettingsSound => 'サウンド';

  @override
  String get notificationSettingsSoundSubtitle => '通知音を鳴らす';

  @override
  String get notificationSettingsVibration => 'バイブレーション';

  @override
  String get notificationSettingsVibrationSubtitle => '通知時にバイブレーション';

  @override
  String get notificationSettingsActions => 'アクション';

  @override
  String get notificationSettingsMarkAllAsRead => 'すべて既読にする';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle => 'すべての通知を既読にします';

  @override
  String get notificationSettingsAllMarkedAsRead => 'すべての通知を既読にしました';

  @override
  String get notificationSettingsResetToDefaults => '設定を既定値にリセットしました';

  @override
  String get notificationSettingsAbout => '通知について';

  @override
  String get notificationSettingsAboutDescription =>
      '通知は Nostr プロトコルによって提供されます。リアルタイム更新は Nostr リレーへの接続状況に依存し、遅延することがあります。';

  @override
  String get safetySettingsTitle => '安全とプライバシー';

  @override
  String get safetySettingsLabel => '設定';

  @override
  String get safetySettingsShowDivineHostedOnly => 'Divine ホスト動画のみ表示';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle =>
      '他のメディアホストで配信されている動画を非表示にします';

  @override
  String get safetySettingsModeration => 'モデレーション';

  @override
  String get safetySettingsBlockedUsers => 'ブロック済みユーザー';

  @override
  String get safetySettingsAgeVerification => '年齢確認';

  @override
  String get safetySettingsAgeConfirmation => '私は18歳以上であることを確認します';

  @override
  String get safetySettingsAgeRequired => 'アダルトコンテンツの閲覧に必須です';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle => '公式モデレーションサービス (既定で有効)';

  @override
  String get safetySettingsPeopleIFollow => 'フォロー中のユーザー';

  @override
  String get safetySettingsPeopleIFollowSubtitle => 'フォローしている人のラベルを購読します';

  @override
  String get safetySettingsAddCustomLabeler => 'カスタムラベラーを追加';

  @override
  String get safetySettingsAddCustomLabelerHint => 'npub を入力...';

  @override
  String get safetySettingsAddCustomLabelerListTitle => 'カスタムラベラーを追加';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle => 'npub アドレスを入力してください';

  @override
  String get safetySettingsNoBlockedUsers => 'ブロック済みユーザーはいません';

  @override
  String get safetySettingsUnblock => 'ブロック解除';

  @override
  String get safetySettingsUserUnblocked => 'ユーザーのブロックを解除しました';

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
  String get analyticsRetry => '再試行';

  @override
  String get analyticsUnableToLoad => '分析データを読み込めません。';

  @override
  String get analyticsSignInRequired => 'クリエイター分析を表示するにはサインインしてください。';

  @override
  String get analyticsViewDataUnavailable =>
      'これらの投稿について、現在リレーから視聴データを取得できません。いいね・コメント・リポストの数値は引き続き正確です。';

  @override
  String get analyticsViewDataTitle => '視聴データ';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return '更新 $time • スコアは Funnelcake で利用可能な場合、いいね、コメント、リポスト、視聴/ループを使用します。';
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
  String get analyticsMostViewed => '最も視聴された';

  @override
  String get analyticsMostDiscussed => '最も話題になった';

  @override
  String get analyticsMostReposted => '最もリポストされた';

  @override
  String get analyticsNoVideosYet => '動画はまだありません';

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
  String get analyticsPublishPrompt => 'ランキングを見るには動画をいくつか公開してください。';

  @override
  String get analyticsEngagementRateExplainer =>
      '右側の % = エンゲージメント率 (インタラクション数 ÷ 視聴数)。';

  @override
  String get analyticsEngagementRateNoViews =>
      'エンゲージメント率には視聴データが必要です。視聴データが揃うまで N/A と表示されます。';

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
  String get analyticsNoActivityYet => 'この期間のアクティビティはまだありません。';

  @override
  String get analyticsDailyInteractionsExplainer =>
      'インタラクション = 投稿日ごとの いいね + コメント + リポスト。';

  @override
  String get analyticsDailyBarExplainer => 'バーの長さはこの期間で最も多かった日を基準とした相対値です。';

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
      'Funnelcake がオーディエンス分析エンドポイントを追加すると、オーディエンスのソース/地域/時間帯の内訳が入ります。';

  @override
  String get analyticsRetention => 'リテンション';

  @override
  String get analyticsRetentionWithViews =>
      'Funnelcake から秒単位/バケット単位のリテンションが届くと、リテンションカーブと視聴時間の内訳がここに表示されます。';

  @override
  String get analyticsRetentionWithoutViews =>
      'Funnelcake から視聴+視聴時間の分析が返されるまで、リテンションデータは利用できません。';

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
  String get analyticsDiagnosticsUseFixture => 'フィクスチャデータを使用';

  @override
  String get analyticsNa => 'N/A';

  @override
  String get authCreateNewAccount => '新しい Divine アカウントを作成';

  @override
  String get authSignInDifferentAccount => '別のアカウントでサインイン';

  @override
  String get authSignBackIn => '再度サインイン';

  @override
  String get authTermsPrefix =>
      '上のオプションを選ぶことで、あなたが16歳以上であることを確認し、次に同意したものとみなされます: ';

  @override
  String get authTermsOfService => '利用規約';

  @override
  String get authPrivacyPolicy => 'プライバシーポリシー';

  @override
  String get authTermsAnd => '、そして ';

  @override
  String get authSafetyStandards => '安全基準';

  @override
  String get authAmberNotInstalled => 'Amber アプリがインストールされていません';

  @override
  String get authAmberConnectionFailed => 'Amber との接続に失敗しました';

  @override
  String get authPasswordResetSent =>
      'そのメールアドレスのアカウントが存在すれば、パスワードリセットリンクを送信しました。';

  @override
  String get authSignInTitle => 'サインイン';

  @override
  String get authEmailLabel => 'メールアドレス';

  @override
  String get authPasswordLabel => 'パスワード';

  @override
  String get authForgotPassword => 'パスワードをお忘れですか?';

  @override
  String get authImportNostrKey => 'Nostr 鍵をインポート';

  @override
  String get authConnectSignerApp => '署名アプリで接続';

  @override
  String get authSignInWithAmber => 'Amber でサインイン';

  @override
  String get authSignInOptionsTitle => 'サインインオプション';

  @override
  String get authInfoEmailPasswordTitle => 'メールとパスワード';

  @override
  String get authInfoEmailPasswordDescription =>
      'Divine アカウントでサインインします。メールとパスワードで登録した場合はそれを使ってください。';

  @override
  String get authInfoImportNostrKeyDescription =>
      'すでに Nostr ID をお持ちですか? 別のクライアントから nsec 秘密鍵をインポートしてください。';

  @override
  String get authInfoSignerAppTitle => '署名アプリ';

  @override
  String get authInfoSignerAppDescription =>
      'nsecBunker のような NIP-46 対応のリモート署名アプリで接続して、鍵のセキュリティを強化できます。';

  @override
  String get authInfoAmberTitle => 'Amber';

  @override
  String get authInfoAmberDescription =>
      'Android 向けの Amber 署名アプリを使って、Nostr 鍵を安全に管理できます。';

  @override
  String get authCreateAccountTitle => 'アカウントを作成';

  @override
  String get authBackToInviteCode => '招待コードに戻る';

  @override
  String get authUseDivineNoBackup => 'バックアップなしで Divine を使う';

  @override
  String get authSkipConfirmTitle => '最後にひとつだけ...';

  @override
  String get authSkipConfirmKeyCreated => '準備完了! Divine アカウントを動かす安全な鍵を作成します。';

  @override
  String get authSkipConfirmKeyOnly =>
      'メールなしだと、この鍵が Divine にとってアカウントがあなたのものだと知る唯一の手段になります。';

  @override
  String get authSkipConfirmRecommendEmail =>
      'アプリ内で鍵にアクセスできますが、技術に詳しくない方は今すぐメールとパスワードを追加することをおすすめします。サインインが簡単になり、このデバイスを失くしたりリセットしたときにアカウントを復元しやすくなります。';

  @override
  String get authAddEmailPassword => 'メールとパスワードを追加';

  @override
  String get authUseThisDeviceOnly => 'このデバイスのみ使用';

  @override
  String get authCompleteRegistration => '登録を完了';

  @override
  String get authVerifying => '確認中...';

  @override
  String get authVerificationLinkSent => '認証リンクを送信しました:';

  @override
  String get authClickVerificationLink => '登録を完了するには、メール内のリンクをクリックしてください。';

  @override
  String get authPleaseWaitVerifying => 'メールを確認しています。しばらくお待ちください...';

  @override
  String get authWaitingForVerification => '認証を待機中';

  @override
  String get authOpenEmailApp => 'メールアプリを開く';

  @override
  String get authWelcomeToDivine => 'Divine へようこそ!';

  @override
  String get authEmailVerified => 'メールアドレスを確認しました。';

  @override
  String get authSigningYouIn => 'サインイン中';

  @override
  String get authErrorTitle => 'おっと。';

  @override
  String get authVerificationFailed => 'メールの確認に失敗しました。\nもう一度お試しください。';

  @override
  String get authStartOver => '最初からやり直す';

  @override
  String get authEmailVerifiedLogin => 'メールを確認しました! ログインして続けてください。';

  @override
  String get authVerificationLinkExpired => 'この認証リンクはもう有効ではありません。';

  @override
  String get authVerificationConnectionError =>
      'メールを確認できません。接続を確認してもう一度お試しください。';

  @override
  String get authWaitlistConfirmTitle => '登録完了!';

  @override
  String authWaitlistUpdatesAt(String email) {
    return 'アップデートは $email にお送りします。\n招待コードが追加で利用可能になったら、すぐにお知らせします。';
  }

  @override
  String get authOk => 'OK';

  @override
  String get authInviteUnavailable => '招待アクセスは一時的に利用できません。';

  @override
  String get authInviteUnavailableBody =>
      '少し時間をおいて再度お試しいただくか、参加にお困りの場合はサポートまでご連絡ください。';

  @override
  String get authTryAgain => 'もう一度試す';

  @override
  String get authContactSupport => 'サポートに連絡';

  @override
  String authCouldNotOpenEmail(String email) {
    return '$email を開けませんでした';
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
      'メールアドレスを教えてください。アクセス開放に合わせてアップデートをお送りします。';

  @override
  String get authInviteAccessHelp => '招待アクセスのヘルプ';

  @override
  String get authGeneratingConnection => '接続を生成中...';

  @override
  String get authConnectedAuthenticating => '接続しました! 認証中...';

  @override
  String get authConnectionTimedOut => '接続がタイムアウトしました';

  @override
  String get authApproveConnection => '署名アプリで接続を承認したか確認してください。';

  @override
  String get authConnectionCancelled => '接続がキャンセルされました';

  @override
  String get authConnectionCancelledMessage => '接続はキャンセルされました。';

  @override
  String get authConnectionFailed => '接続に失敗しました';

  @override
  String get authUnknownError => '不明なエラーが発生しました。';

  @override
  String get authUrlCopied => 'URL をクリップボードにコピーしました';

  @override
  String get authConnectToDivine => 'Divine に接続';

  @override
  String get authPasteBunkerUrl => 'bunker:// URL を貼り付け';

  @override
  String get authBunkerUrlHint => 'bunker:// URL';

  @override
  String get authInvalidBunkerUrl => '無効な bunker URL です。bunker:// で始まる必要があります';

  @override
  String get authScanSignerApp => '署名アプリで\nスキャンして接続。';

  @override
  String authWaitingForConnection(int seconds) {
    return '接続を待機中... $seconds秒';
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
  String get authFailedToConnect => '接続に失敗しました';

  @override
  String get authResetPasswordTitle => 'パスワードをリセット';

  @override
  String get authResetPasswordSubtitle => '新しいパスワードを入力してください。8文字以上である必要があります。';

  @override
  String get authNewPasswordLabel => '新しいパスワード';

  @override
  String get authPasswordTooShort => 'パスワードは8文字以上である必要があります';

  @override
  String get authPasswordResetSuccess => 'パスワードをリセットしました。ログインしてください。';

  @override
  String get authPasswordResetFailed => 'パスワードのリセットに失敗しました';

  @override
  String get authUnexpectedError => '予期しないエラーが発生しました。もう一度お試しください。';

  @override
  String get authUpdatePassword => 'パスワードを更新';

  @override
  String get authSecureAccountTitle => 'アカウントを保護';

  @override
  String get authUnableToAccessKeys => '鍵にアクセスできません。もう一度お試しください。';

  @override
  String get authRegistrationFailed => '登録に失敗しました';

  @override
  String get authRegistrationComplete => '登録完了。メールを確認してください。';

  @override
  String get authVerificationFailedTitle => '認証に失敗しました';

  @override
  String get authClose => '閉じる';

  @override
  String get authAccountSecured => 'アカウントを保護しました!';

  @override
  String get authAccountLinkedToEmail => 'アカウントがメールアドレスに紐づけられました。';

  @override
  String get authVerifyYourEmail => 'メールアドレスを確認してください';

  @override
  String get authClickLinkContinue =>
      'メール内のリンクをクリックして登録を完了してください。その間もアプリを使い続けられます。';

  @override
  String get authWaitingForVerificationEllipsis => '認証を待機中...';

  @override
  String get authContinueToApp => 'アプリに進む';

  @override
  String get authResetPassword => 'パスワードをリセット';

  @override
  String get authResetPasswordDescription =>
      'メールアドレスを入力してください。パスワードをリセットするリンクをお送りします。';

  @override
  String get authFailedToSendResetEmail => 'リセットメールの送信に失敗しました。';

  @override
  String get authUnexpectedErrorShort => '予期しないエラーが発生しました。';

  @override
  String get authSending => '送信中...';

  @override
  String get authSendResetLink => 'リセットリンクを送信';

  @override
  String get authEmailSent => 'メールを送信しました!';

  @override
  String authResetLinkSentTo(String email) {
    return '$email にパスワードリセットリンクを送信しました。メール内のリンクをクリックしてパスワードを更新してください。';
  }

  @override
  String get authSignInButton => 'サインイン';

  @override
  String get authVerificationErrorTimeout => '認証がタイムアウトしました。もう一度登録をお試しください。';

  @override
  String get authVerificationErrorMissingCode => '認証に失敗しました — 認可コードがありません。';

  @override
  String get authVerificationErrorPollFailed => '認証に失敗しました。もう一度お試しください。';

  @override
  String get authVerificationErrorNetworkExchange =>
      'サインイン中にネットワークエラーが発生しました。もう一度お試しください。';

  @override
  String get authVerificationErrorOAuthExchange => '認証に失敗しました。もう一度登録をお試しください。';

  @override
  String get authVerificationErrorSignInFailed =>
      'サインインに失敗しました。手動でログインしてみてください。';

  @override
  String get authInviteErrorAlreadyUsed =>
      'その招待コードはもう利用できません。招待コードに戻るか、ウェイトリストに参加するか、サポートにご連絡ください。';

  @override
  String get authInviteErrorInvalid =>
      'その招待コードは今は使えません。招待コードに戻るか、ウェイトリストに参加するか、サポートにご連絡ください。';

  @override
  String get authInviteErrorTemporary =>
      '招待を今は確認できませんでした。招待コードに戻ってもう一度試すか、サポートにご連絡ください。';

  @override
  String get authInviteErrorUnknown =>
      '招待を有効にできませんでした。招待コードに戻るか、ウェイトリストに参加するか、サポートにご連絡ください。';

  @override
  String get shareSheetSave => '保存';

  @override
  String get shareSheetSaveToGallery => 'ギャラリーに保存';

  @override
  String get shareSheetSaveWithWatermark => 'ウォーターマーク付きで保存';

  @override
  String get shareSheetSaveVideo => '動画を保存';

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
  String get watermarkDownloadSavedToCameraRoll => 'カメラロールに保存しました';

  @override
  String get watermarkDownloadShare => '共有';

  @override
  String get watermarkDownloadDone => '完了';

  @override
  String get watermarkDownloadPhotosAccessNeeded => '写真へのアクセスが必要';

  @override
  String get watermarkDownloadPhotosAccessDescription =>
      '動画を保存するには、設定で写真へのアクセスを許可してください。';

  @override
  String get watermarkDownloadOpenSettings => '設定を開く';

  @override
  String get watermarkDownloadNotNow => '今はしない';

  @override
  String get watermarkDownloadFailed => 'ダウンロードに失敗しました';

  @override
  String get watermarkDownloadDismiss => '閉じる';

  @override
  String get watermarkDownloadStageDownloading => '動画をダウンロード中';

  @override
  String get watermarkDownloadStageWatermarking => 'ウォーターマークを追加中';

  @override
  String get watermarkDownloadStageSaving => 'カメラロールに保存中';

  @override
  String get watermarkDownloadStageDownloadingDesc => 'ネットワークから動画を取得しています...';

  @override
  String get watermarkDownloadStageWatermarkingDesc =>
      'Divine ウォーターマークを適用しています...';

  @override
  String get watermarkDownloadStageSavingDesc =>
      'ウォーターマーク付き動画をカメラロールに保存しています...';

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
    return '再試行 (残り$count回)';
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
  String get badgeExplanationClose => '閉じる';

  @override
  String get badgeExplanationOriginalVineArchive => 'オリジナル Vine アーカイブ';

  @override
  String get badgeExplanationCameraProof => 'カメラ証明';

  @override
  String get badgeExplanationAuthenticitySignals => '真正性シグナル';

  @override
  String get badgeExplanationVineArchiveIntro =>
      'この動画はインターネットアーカイブから復元されたオリジナルの Vine です。';

  @override
  String get badgeExplanationVineArchiveHistory =>
      '2017年に Vine がサービスを終了する前、ArchiveTeam とインターネットアーカイブは数百万もの Vine を後世のために保存する活動をしていました。このコンテンツはその歴史的な保存活動の一部です。';

  @override
  String badgeExplanationOriginalStats(int loops) {
    return 'オリジナルの数値: $loopsループ';
  }

  @override
  String get badgeExplanationLearnVineArchive => 'Vine アーカイブの保存について詳しく';

  @override
  String get badgeExplanationLearnProofmode => 'Proofmode による認証について詳しく';

  @override
  String get badgeExplanationLearnAuthenticity => 'Divine の真正性シグナルについて詳しく';

  @override
  String get badgeExplanationInspectProofCheck => 'ProofCheck ツールで調査';

  @override
  String get badgeExplanationInspectMedia => 'メディアの詳細を確認';

  @override
  String get badgeExplanationProofmodeVerified =>
      'この動画の真正性は Proofmode 技術で検証されています。';

  @override
  String get badgeExplanationDivineHostedHumanMade =>
      'この動画は Divine でホストされており、AI 検出によって人間が作ったものである可能性が高いと判定されていますが、暗号学的なカメラ検証データは含まれていません。';

  @override
  String get badgeExplanationHumanMadeNoCrypto =>
      'AI 検出によってこの動画は人間が作ったものである可能性が高いと判定されていますが、暗号学的なカメラ検証データは含まれていません。';

  @override
  String get badgeExplanationDivineHostedNoCrypto =>
      'この動画は Divine でホストされていますが、まだ暗号学的なカメラ検証データは含まれていません。';

  @override
  String get badgeExplanationExternalNoCrypto =>
      'この動画は Divine の外部でホストされており、暗号学的なカメラ検証データは含まれていません。';

  @override
  String get badgeExplanationDeviceAttestation => 'デバイスの認証';

  @override
  String get badgeExplanationPgpSignature => 'PGP 署名';

  @override
  String get badgeExplanationC2paCredentials => 'C2PA コンテンツ認証情報';

  @override
  String get badgeExplanationProofManifest => '証明マニフェスト';

  @override
  String get badgeExplanationAiDetection => 'AI 検出';

  @override
  String get badgeExplanationAiNotScanned => 'AI スキャン: 未スキャン';

  @override
  String get badgeExplanationNoScanResults => 'スキャン結果はまだありません。';

  @override
  String get badgeExplanationCheckAiGenerated => 'AI 生成かチェック';

  @override
  String badgeExplanationAiLikelihood(int percentage) {
    return 'AI 生成の可能性 $percentage%';
  }

  @override
  String badgeExplanationScannedBy(String source) {
    return 'スキャン元: $source';
  }

  @override
  String get badgeExplanationVerifiedByModerator => '人間のモデレーターによって検証済み';

  @override
  String get badgeExplanationVerificationPlatinum =>
      'プラチナ: デバイスのハードウェア認証、暗号署名、コンテンツ認証 (C2PA)、AI スキャンが人間の作成であることを確認。';

  @override
  String get badgeExplanationVerificationGold =>
      'ゴールド: ハードウェア認証、暗号署名、コンテンツ認証 (C2PA) を備えた実機で撮影。';

  @override
  String get badgeExplanationVerificationSilver =>
      'シルバー: 暗号署名により、この動画が録画以降改変されていないことが証明されています。';

  @override
  String get badgeExplanationVerificationBronze => 'ブロンズ: 基本的なメタデータ署名があります。';

  @override
  String get badgeExplanationVerificationSilverAiScan =>
      'シルバー: AI スキャンにより、この動画は人間が作成した可能性が高いと判定されています。';

  @override
  String get badgeExplanationNoVerification => 'この動画には利用可能な検証データがありません。';

  @override
  String get shareMenuTitle => '動画を共有';

  @override
  String get shareMenuReportAiContent => 'AI コンテンツを報告';

  @override
  String get shareMenuReportAiContentSubtitle => 'AI 生成の疑いがあるコンテンツを素早く報告';

  @override
  String get shareMenuReportingAiContent => 'AI コンテンツを報告中...';

  @override
  String shareMenuFailedToReportContent(String error) {
    return 'コンテンツの報告に失敗しました: $error';
  }

  @override
  String shareMenuFailedToReportAiContent(String error) {
    return 'AI コンテンツの報告に失敗しました: $error';
  }

  @override
  String get shareMenuVideoStatus => '動画のステータス';

  @override
  String get shareMenuViewAllLists => 'すべてのリストを表示 →';

  @override
  String get shareMenuShareWith => '共有相手';

  @override
  String get shareMenuShareViaOtherApps => '他のアプリで共有';

  @override
  String get shareMenuShareViaOtherAppsSubtitle => '他のアプリで共有またはリンクをコピー';

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
  String get shareMenuCreateNewList => '新しいリストを作成';

  @override
  String get shareMenuCreateNewListSubtitle => '新しいキュレーションコレクションを開始';

  @override
  String get shareMenuRemovedFromList => 'リストから削除しました';

  @override
  String get shareMenuFailedToRemoveFromList => 'リストからの削除に失敗しました';

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
  String get shareMenuCreateFollowSet => 'フォローセットを作成';

  @override
  String get shareMenuCreateFollowSetSubtitle => 'このクリエイターで新しいコレクションを開始';

  @override
  String get shareMenuAddToFollowSet => 'フォローセットに追加';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    return '利用可能なフォローセット$count個';
  }

  @override
  String get shareMenuAddedToBookmarks => 'ブックマークに追加しました!';

  @override
  String get shareMenuFailedToAddBookmark => 'ブックマークの追加に失敗しました';

  @override
  String shareMenuCreatedListAndAddedVideo(String name) {
    return 'リスト「$name」を作成して動画を追加しました';
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
  String get shareMenuVideoInTheseLists => 'この動画が入っているリスト:';

  @override
  String shareMenuVideoCount(int count) {
    return '$count本の動画';
  }

  @override
  String get shareMenuClose => '閉じる';

  @override
  String get shareMenuDeleteConfirmation => 'この動画を本当に削除しますか?';

  @override
  String get shareMenuDeleteWarning =>
      'すべてのリレーに削除リクエスト (NIP-09) を送信します。一部のリレーではコンテンツが保持されたままになる場合があります。';

  @override
  String get shareMenuCancel => 'キャンセル';

  @override
  String get shareMenuDelete => '削除';

  @override
  String get shareMenuDeletingContent => 'コンテンツを削除中...';

  @override
  String get shareMenuDeleteRequestSent => '削除リクエストを送信しました';

  @override
  String shareMenuFailedToDeleteContent(String error) {
    return 'コンテンツの削除に失敗しました: $error';
  }

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
    return 'フォローセット「$name」を作成してクリエイターを追加しました';
  }

  @override
  String get shareMenuDone => '完了';

  @override
  String get shareMenuEditTitle => 'タイトル';

  @override
  String get shareMenuEditTitleHint => '動画のタイトルを入力';

  @override
  String get shareMenuEditDescription => '説明';

  @override
  String get shareMenuEditDescriptionHint => '動画の説明を入力';

  @override
  String get shareMenuEditHashtags => 'ハッシュタグ';

  @override
  String get shareMenuEditHashtagsHint => 'カンマ, 区切り, ハッシュタグ';

  @override
  String get shareMenuEditMetadataNote =>
      '注意: 編集できるのはメタデータのみです。動画のコンテンツは変更できません。';

  @override
  String get shareMenuDeleting => '削除中...';

  @override
  String get shareMenuUpdate => '更新';

  @override
  String get shareMenuVideoUpdated => '動画を更新しました';

  @override
  String shareMenuFailedToUpdateVideo(String error) {
    return '動画の更新に失敗しました: $error';
  }

  @override
  String get shareMenuDeleteVideoQuestion => '動画を削除しますか?';

  @override
  String get shareMenuDeleteRelayWarning =>
      'リレーに削除リクエストを送信します。注意: 一部のリレーではキャッシュされたコピーが残ることがあります。';

  @override
  String get shareMenuVideoDeletionRequested => '動画の削除をリクエストしました';

  @override
  String shareMenuFailedToDeleteVideo(String error) {
    return '動画の削除に失敗しました: $error';
  }

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
    return 'コラボレーターとして追加するには、$nameと相互フォローになっている必要があります。';
  }

  @override
  String get shareMenuLoading => '読み込み中...';

  @override
  String get shareMenuInspiredBy => 'インスパイア元';

  @override
  String get shareMenuAddInspirationCredit => 'インスピレーションクレジットを追加';

  @override
  String get shareMenuCreatorCannotBeReferenced => 'このクリエイターは参照できません。';

  @override
  String get shareMenuUnknown => '不明';

  @override
  String get shareMenuCreateBookmarkSet => 'ブックマークセットを作成';

  @override
  String get shareMenuSetName => 'セット名';

  @override
  String get shareMenuSetNameHint => '例: お気に入り、あとで見るなど';

  @override
  String get shareMenuCreateNewSet => '新しいセットを作成';

  @override
  String get shareMenuStartNewBookmarkCollection => '新しいブックマークコレクションを開始';

  @override
  String get shareMenuNoBookmarkSets => 'ブックマークセットはまだありません。最初のセットを作成しましょう!';

  @override
  String get shareMenuError => 'エラー';

  @override
  String get shareMenuFailedToLoadBookmarkSets => 'ブックマークセットの読み込みに失敗しました';

  @override
  String shareMenuCreatedSetAndAddedVideo(String name) {
    return '「$name」を作成して動画を追加しました';
  }

  @override
  String get shareMenuUseThisSound => 'このサウンドを使う';

  @override
  String get shareMenuOriginalSound => 'オリジナルサウンド';

  @override
  String get authSessionExpired => 'セッションの有効期限が切れました。再度サインインしてください。';

  @override
  String get authSignInFailed => 'サインインに失敗しました。もう一度お試しください。';

  @override
  String get localeAppLanguage => 'アプリの言語';

  @override
  String get localeDeviceDefault => 'デバイスの既定';

  @override
  String get localeSelectLanguage => '言語を選択';

  @override
  String get webAuthNotSupportedSecureMode =>
      'セキュアモードではウェブ認証は対応していません。安全な鍵管理にはモバイルアプリをご利用ください。';

  @override
  String webAuthIntegrationFailed(String error) {
    return '認証連携に失敗しました: $error';
  }

  @override
  String webAuthUnexpectedError(String error) {
    return '予期しないエラー: $error';
  }

  @override
  String get webAuthEnterBunkerUri => 'bunker URI を入力してください';

  @override
  String get webAuthConnectTitle => 'Divine に接続';

  @override
  String get webAuthChooseMethod => 'Nostr 認証方法を選んでください';

  @override
  String get webAuthBrowserExtension => 'ブラウザ拡張機能';

  @override
  String get webAuthRecommended => '推奨';

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
  String get webAuthNewToNostr => 'Nostr は初めてですか?';

  @override
  String get webAuthNostrHelp =>
      'もっとも簡単なのは Alby や nos2x のようなブラウザ拡張をインストールする方法です。安全なリモート署名なら nsec bunker を使ってください。';

  @override
  String get soundsTitle => 'サウンド';

  @override
  String get soundsSearchHint => 'サウンドを検索...';

  @override
  String get soundsPreviewUnavailable => 'サウンドをプレビューできません - 音声がありません';

  @override
  String soundsPreviewFailed(String error) {
    return 'プレビューの再生に失敗しました: $error';
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
  String get soundsNoSoundsAvailable => '利用可能なサウンドがありません';

  @override
  String get soundsNoSoundsDescription => 'クリエイターが音声を共有するとここに表示されます';

  @override
  String get soundsNoSoundsFound => 'サウンドが見つかりません';

  @override
  String get soundsNoSoundsFoundDescription => '別のキーワードで検索してみてください';

  @override
  String get soundsFailedToLoad => 'サウンドの読み込みに失敗しました';

  @override
  String get soundsRetry => '再試行';

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
    return '$nameをブロックしました';
  }

  @override
  String profileUnblockedUser(String name) {
    return '$nameのブロックを解除しました';
  }

  @override
  String profileUnfollowedUser(String name) {
    return '$nameのフォローを解除しました';
  }

  @override
  String profileError(String error) {
    return 'エラー: $error';
  }

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
  String get notificationsFailedToLoad => '通知の読み込みに失敗しました';

  @override
  String get notificationsRetry => '再試行';

  @override
  String get notificationsCheckingNew => '新しい通知を確認中';

  @override
  String get notificationsNoneYet => '通知はまだありません';

  @override
  String notificationsNoneForType(String type) {
    return '$typeの通知はありません';
  }

  @override
  String get notificationsEmptyDescription => 'あなたのコンテンツに誰かが反応したらここに表示されます';

  @override
  String notificationsLoadingType(String type) {
    return '$typeの通知を読み込み中...';
  }

  @override
  String get notificationsInviteSingular => '友達に共有できる招待が1つあります!';

  @override
  String notificationsInvitePlural(int count) {
    return '友達に共有できる招待が$count個あります!';
  }

  @override
  String get notificationsVideoNotFound => '動画が見つかりません';

  @override
  String get notificationsVideoUnavailable => '動画を利用できません';

  @override
  String get notificationsFromNotification => '通知から';

  @override
  String get feedFailedToLoadVideos => '動画の読み込みに失敗しました';

  @override
  String get feedRetry => '再試行';

  @override
  String get feedNoFollowedUsers =>
      'フォロー中のユーザーがいません。\n誰かをフォローすると、ここに動画が表示されます。';

  @override
  String feedNoVideosForMode(String mode) {
    return '$modeフィードの動画が見つかりません。';
  }

  @override
  String get feedExploreVideos => '動画を探す';

  @override
  String get feedExternalVideoSlow => '外部動画の読み込みに時間がかかっています';

  @override
  String get feedSkip => 'スキップ';

  @override
  String get uploadWaitingToUpload => 'アップロードを待機中';

  @override
  String get uploadUploadingVideo => '動画をアップロード中';

  @override
  String get uploadProcessingVideo => '動画を処理中';

  @override
  String get uploadProcessingComplete => '処理完了';

  @override
  String get uploadPublishedSuccessfully => '公開しました';

  @override
  String get uploadFailed => 'アップロードに失敗しました';

  @override
  String get uploadRetrying => 'アップロードを再試行中';

  @override
  String get uploadPaused => 'アップロード一時停止';

  @override
  String uploadPercentComplete(int percent) {
    return '$percent% 完了';
  }

  @override
  String get uploadQueuedMessage => '動画はアップロード待機中です';

  @override
  String get uploadUploadingMessage => 'サーバーにアップロード中...';

  @override
  String get uploadProcessingMessage => '動画を処理中 - 数分かかる場合があります';

  @override
  String get uploadReadyToPublishMessage => '動画の処理が完了し、公開の準備ができました';

  @override
  String get uploadPublishedMessage => '動画をプロフィールに公開しました';

  @override
  String get uploadFailedMessage => 'アップロードに失敗しました - もう一度お試しください';

  @override
  String get uploadRetryingMessage => 'アップロードを再試行中...';

  @override
  String get uploadPausedMessage => 'ユーザーによってアップロードが一時停止されました';

  @override
  String get uploadRetryButton => '再試行';

  @override
  String uploadRetryFailed(String error) {
    return 'アップロードの再試行に失敗しました: $error';
  }

  @override
  String get userSearchPrompt => 'ユーザーを検索';

  @override
  String get userSearchNoResults => 'ユーザーが見つかりません';

  @override
  String get userSearchFailed => '検索に失敗しました';

  @override
  String get forgotPasswordTitle => 'パスワードをリセット';

  @override
  String get forgotPasswordDescription =>
      'メールアドレスを入力してください。パスワードをリセットするリンクをお送りします。';

  @override
  String get forgotPasswordEmailLabel => 'メールアドレス';

  @override
  String get forgotPasswordCancel => 'キャンセル';

  @override
  String get forgotPasswordSendLink => 'リセットリンクを送信';

  @override
  String get ageVerificationContentWarning => 'コンテンツ警告';

  @override
  String get ageVerificationTitle => '年齢確認';

  @override
  String get ageVerificationAdultDescription =>
      'このコンテンツは成人向け素材が含まれる可能性があるとしてフラグが立てられています。閲覧には18歳以上である必要があります。';

  @override
  String get ageVerificationCreationDescription =>
      'カメラを使ってコンテンツを作成するには、16歳以上である必要があります。';

  @override
  String get ageVerificationAdultQuestion => 'あなたは18歳以上ですか?';

  @override
  String get ageVerificationCreationQuestion => 'あなたは16歳以上ですか?';

  @override
  String get ageVerificationNo => 'いいえ';

  @override
  String get ageVerificationYes => 'はい';

  @override
  String get shareLinkCopied => 'リンクをクリップボードにコピーしました';

  @override
  String get shareFailedToCopy => 'リンクのコピーに失敗しました';

  @override
  String get shareVideoSubject => 'Divine でこの動画をチェック';

  @override
  String get shareFailedToShare => '共有に失敗しました';

  @override
  String get shareVideoTitle => '動画を共有';

  @override
  String get shareToApps => 'アプリで共有';

  @override
  String get shareToAppsSubtitle => 'メッセージアプリや SNS で共有';

  @override
  String get shareCopyWebLink => 'ウェブリンクをコピー';

  @override
  String get shareCopyWebLinkSubtitle => '共有可能なウェブリンクをコピー';

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
  String get navMyProfile => 'マイプロフィール';

  @override
  String get navSearch => '検索';

  @override
  String get navNotifications => '通知';

  @override
  String get navSearchTooltip => '検索';

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
  String get routeNoVideosToDisplay => '表示する動画がありません';

  @override
  String get routeInvalidProfileId => '無効なプロフィール ID';

  @override
  String get routeDefaultListName => 'リスト';

  @override
  String get supportTitle => 'サポートセンター';

  @override
  String get supportContactSupport => 'サポートに連絡';

  @override
  String get supportContactSupportSubtitle => '会話を開始したり、過去のメッセージを確認します';

  @override
  String get supportReportBug => 'バグを報告';

  @override
  String get supportReportBugSubtitle => 'アプリの技術的な問題';

  @override
  String get supportRequestFeature => '機能をリクエスト';

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
  String get supportProofModeSubtitle => '検証と真正性について学ぶ';

  @override
  String get supportLoginRequired => 'サポートに連絡するにはログインしてください';

  @override
  String get supportExportingLogs => 'ログをエクスポート中...';

  @override
  String get supportExportLogsFailed => 'ログのエクスポートに失敗しました';

  @override
  String get supportChatNotAvailable => 'サポートチャットは利用できません';

  @override
  String get supportCouldNotOpenMessages => 'サポートメッセージを開けませんでした';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return '$pageNameを開けませんでした';
  }

  @override
  String supportErrorOpeningPage(String pageName, Object error) {
    return '$pageNameを開くときにエラー: $error';
  }

  @override
  String get reportTitle => 'コンテンツを報告';

  @override
  String get reportWhyReporting => 'このコンテンツを報告する理由は何ですか?';

  @override
  String get reportPolicyNotice =>
      'Divine はコンテンツの報告に対して24時間以内に対応し、問題のあるコンテンツを削除し、違反したユーザーを排除します。';

  @override
  String get reportAdditionalDetails => '追加の詳細 (任意)';

  @override
  String get reportBlockUser => 'このユーザーをブロック';

  @override
  String get reportCancel => 'キャンセル';

  @override
  String get reportSubmit => '報告';

  @override
  String get reportSelectReason => 'このコンテンツを報告する理由を選んでください';

  @override
  String get reportReasonSpam => 'スパムまたは迷惑なコンテンツ';

  @override
  String get reportReasonHarassment => '嫌がらせ、いじめ、または脅迫';

  @override
  String get reportReasonViolence => '暴力的または過激なコンテンツ';

  @override
  String get reportReasonSexualContent => '性的または成人向けコンテンツ';

  @override
  String get reportReasonCopyright => '著作権侵害';

  @override
  String get reportReasonFalseInfo => '虚偽の情報';

  @override
  String get reportReasonCsam => '子どもの安全に関する違反';

  @override
  String get reportReasonAiGenerated => 'AI 生成コンテンツ';

  @override
  String get reportReasonOther => 'その他のポリシー違反';

  @override
  String reportFailed(Object error) {
    return 'コンテンツの報告に失敗しました: $error';
  }

  @override
  String get reportReceivedTitle => '報告を受け付けました';

  @override
  String get reportReceivedThankYou => 'Divine を安全に保つためにご協力ありがとうございます。';

  @override
  String get reportReceivedReviewNotice =>
      'チームが報告を確認し、適切な対応を行います。ダイレクトメッセージでアップデートが届く場合があります。';

  @override
  String get reportLearnMore => '詳細を見る';

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
  String get listNewList => '新しいリスト';

  @override
  String get listDone => '完了';

  @override
  String get listErrorLoading => 'リストの読み込みエラー';

  @override
  String listRemovedFrom(String name) {
    return '$nameから削除しました';
  }

  @override
  String listAddedTo(String name) {
    return '$nameに追加しました';
  }

  @override
  String get listCreateNewList => '新しいリストを作成';

  @override
  String get listNameLabel => 'リスト名';

  @override
  String get listDescriptionLabel => '説明 (任意)';

  @override
  String get listPublicList => '公開リスト';

  @override
  String get listPublicListSubtitle => '他の人がフォローして閲覧できます';

  @override
  String get listCancel => 'キャンセル';

  @override
  String get listCreate => '作成';

  @override
  String get listCreateFailed => 'リストの作成に失敗しました';

  @override
  String get keyManagementTitle => 'Nostr 鍵';

  @override
  String get keyManagementWhatAreKeys => 'Nostr 鍵とは?';

  @override
  String get keyManagementExplanation =>
      'あなたの Nostr ID は暗号鍵のペアです:\n\n• 公開鍵 (npub) はユーザー名のようなもの - 自由に共有できます\n• 秘密鍵 (nsec) はパスワードのようなもの - 秘密にしておいてください!\n\nnsec があれば、どの Nostr アプリでもあなたのアカウントにアクセスできます。';

  @override
  String get keyManagementImportTitle => '既存の鍵をインポート';

  @override
  String get keyManagementImportSubtitle =>
      'すでに Nostr アカウントをお持ちですか? 秘密鍵 (nsec) を貼り付けてここからアクセスできます。';

  @override
  String get keyManagementImportButton => '鍵をインポート';

  @override
  String get keyManagementImportWarning => '現在の鍵が置き換えられます!';

  @override
  String get keyManagementBackupTitle => '鍵をバックアップ';

  @override
  String get keyManagementBackupSubtitle =>
      '秘密鍵 (nsec) を保存して、他の Nostr アプリでもこのアカウントを使えるようにします。';

  @override
  String get keyManagementCopyNsec => '自分の秘密鍵 (nsec) をコピー';

  @override
  String get keyManagementNeverShare => 'nsec は誰にも共有しないでください!';

  @override
  String get keyManagementPasteKey => '秘密鍵を貼り付けてください';

  @override
  String get keyManagementInvalidFormat => '鍵の形式が無効です。「nsec1」で始まる必要があります';

  @override
  String get keyManagementConfirmImportTitle => 'この鍵をインポートしますか?';

  @override
  String get keyManagementConfirmImportBody =>
      '現在のアイデンティティがインポートした鍵に置き換えられます。\n\n先にバックアップしておかないと、現在の鍵は失われます。';

  @override
  String get keyManagementImportConfirm => 'インポート';

  @override
  String get keyManagementImportSuccess => '鍵をインポートしました!';

  @override
  String keyManagementImportFailed(Object error) {
    return '鍵のインポートに失敗しました: $error';
  }

  @override
  String get keyManagementExportSuccess =>
      '秘密鍵をクリップボードにコピーしました!\n\n安全な場所に保管してください。';

  @override
  String keyManagementExportFailed(Object error) {
    return '鍵のエクスポートに失敗しました: $error';
  }

  @override
  String get saveOriginalSavedToCameraRoll => 'カメラロールに保存しました';

  @override
  String get saveOriginalShare => '共有';

  @override
  String get saveOriginalDone => '完了';

  @override
  String get saveOriginalPhotosAccessNeeded => '写真へのアクセスが必要';

  @override
  String get saveOriginalPhotosAccessMessage =>
      '動画を保存するには、設定で写真へのアクセスを許可してください。';

  @override
  String get saveOriginalOpenSettings => '設定を開く';

  @override
  String get saveOriginalNotNow => '今はしない';

  @override
  String get saveOriginalDownloadFailed => 'ダウンロードに失敗しました';

  @override
  String get saveOriginalDismiss => '閉じる';

  @override
  String get saveOriginalDownloadingVideo => '動画をダウンロード中';

  @override
  String get saveOriginalSavingToCameraRoll => 'カメラロールに保存中';

  @override
  String get saveOriginalFetchingVideo => 'ネットワークから動画を取得しています...';

  @override
  String get saveOriginalSavingVideo => 'オリジナル動画をカメラロールに保存しています...';

  @override
  String get soundTitle => 'サウンド';

  @override
  String get soundOriginalSound => 'オリジナルサウンド';

  @override
  String get soundVideosUsingThisSound => 'このサウンドを使っている動画';

  @override
  String get soundSourceVideo => '元動画';

  @override
  String get soundNoVideosYet => '動画はまだありません';

  @override
  String get soundBeFirstToUse => 'このサウンドを最初に使おう!';

  @override
  String get soundFailedToLoadVideos => '動画の読み込みに失敗しました';

  @override
  String get soundRetry => '再試行';

  @override
  String get soundVideosUnavailable => '動画を利用できません';

  @override
  String get soundCouldNotLoadDetails => '動画の詳細を読み込めませんでした';

  @override
  String get soundPreview => 'プレビュー';

  @override
  String get soundStop => '停止';

  @override
  String get soundUseSound => 'サウンドを使う';

  @override
  String get soundNoVideoCount => '動画はまだありません';

  @override
  String get soundOneVideo => '1本の動画';

  @override
  String soundVideoCount(int count) {
    return '$count本の動画';
  }

  @override
  String get soundUnableToPreview => 'サウンドをプレビューできません - 音声がありません';

  @override
  String soundPreviewFailed(Object error) {
    return 'プレビューの再生に失敗しました: $error';
  }

  @override
  String get soundViewSource => '元動画を見る';

  @override
  String get soundCloseTooltip => '閉じる';

  @override
  String get exploreNotExploreRoute => '探索ルートではありません';

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
    return '$pageNameを開けませんでした';
  }

  @override
  String legalErrorOpeningPage(String pageName, Object error) {
    return '$pageNameを開くときにエラー: $error';
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
}
