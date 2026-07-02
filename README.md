# giracle-frontend-flutter

Giracle チャットの Flutter クライアント (iOS / Android)。
`reference/giracle-frontend-solid` に SolidJS 版フロントエンドを git submodule として置いており、
API 仕様・型の一次資料はそちらを参照します。

## セットアップ

```sh
git clone --recurse-submodules <this repo>
# 後追いで submodule を入れる場合
git submodule update --init --recursive

flutter pub get
```

## 実行

- 開発用サーバー URL は起動後のログイン画面で入力できます (`SharedPreferences` に永続化)。
- あるいはコンパイル時に埋め込むことも可能:

```sh
flutter run --dart-define=GIRACLE_SERVER_URL=http://localhost:3000
```

### Android

```sh
flutter run -d <android-device-id>
```

初回は Android Studio (もしくは `cmdline-tools`) と `ANDROID_HOME` 設定が必要です。
`INTERNET` 権限と平文通信 (`usesCleartextTraffic=true`) を許可済み。

### iOS

```sh
cd ios && pod install && cd -
flutter run -d <ios-device-id>
```

CocoaPods (`brew install cocoapods`) と Xcode の署名設定が必要。
ローカルサーバー向けに `NSAllowsArbitraryLoads` / `NSAllowsLocalNetworking` を許可済み。

## 構成

```
lib/
├── main.dart                # 起点 (ApiClient を作って ProviderScope で公開)
├── app.dart                 # GoRouter とテーマ
├── config/env.dart          # 既定 URL・SharedPreferences のキー
├── models/                  # types/*.ts の Dart 化
├── api/                     # API/**/*.ts に対応する Dio クライアント
├── ws/ws_controller.dart    # WS/WScontroller.ts の Dart 化 (再接続・ping)
├── stores/
│   ├── providers.dart       # Riverpod (AppStatus / MyUser / History / …)
│   └── init_load.dart       # utils/InitLoad.ts と WS ハンドラ配線
├── screens/
│   ├── splash_screen.dart      # /auth 判定
│   ├── login_screen.dart       # /auth の Login タブ相当
│   ├── home_screen.dart        # /app のホーム
│   ├── channel_screen.dart     # /app/channel/:id
│   ├── channel_browser_screen.dart
│   └── config_screen.dart
└── widgets/sidebar.dart     # Sidebar.tsx 相当
```

## 環境要件

`flutter doctor` で以下を満たすように準備してください。

- **iOS**: Xcode 26.5 で iOS 26 プラットフォームランタイムが未インストールだとビルドできません。Xcode → Settings → Components から iOS 26.5 を追加するか、`xcodebuild -downloadPlatform iOS` を実行してください。CocoaPods は `brew install cocoapods` 済み想定。
- **Android**: Android Studio (もしくは Command Line Tools) と `ANDROID_HOME` の設定が必要です。

コード自体は `flutter analyze` / `flutter test` は通ります (error 0 / info 13)。

## 実装済み / 未実装

- 認証: ログイン、Cookie 永続化、`verify-token` によるスプラッシュ復元。
- チャンネル: 一覧 / 参加チャンネル表示 / メッセージ履歴 (`/channel/get-history`) / 参加。
- メッセージ: 送信 / 受信 (WS `message::SendMessage` / `message::MessageDeleted`)。
- WebSocket: 再接続、ping、cookie 付き接続。
- 未着手 (今後): 新規登録画面、リアクション操作、インボックス、ファイル添付・URL プレビュー UI、ロール権限に基づくメニュー、絵文字ピッカー、Minesweeper 等の周辺機能。

新規追加時は `reference/giracle-frontend-solid/src/api/**` と `WS/**` を参照して、
`lib/api/*.dart` / `lib/ws/ws_controller.dart` に対応関数・シグナル分岐を追加してください。
