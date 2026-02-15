# 喫煙所マップ (tabacco_mapping)

喫煙所の位置をユーザーが投稿・共有できるFlutter Webアプリです。

## 機能

- **地図表示** - OpenStreetMap（無料・APIキー不要）で喫煙所をピン表示
- **現在地表示** - 起動時に自動で現在地に移動
- **喫煙所追加** - 地図上で位置を指定してピンを追加（ログイン必須）
- **屋内/屋外フィルター** - 種別でピンを絞り込み
- **評価・コメント** - 喫煙所ごとに星評価とコメントを投稿（ログイン必須）
- **写真アップロード** - 喫煙所の写真を添付
- **削除** - 自分が投稿したピンのみ削除可能
- **認証** - Googleアカウントまたはメール/パスワードでログイン
- **ゲストモード** - ログインなしで地図閲覧可能
- **PWA対応** - ホーム画面への追加に対応

## 技術スタック

| カテゴリ | 使用技術 |
|---------|---------|
| フレームワーク | Flutter Web |
| 状態管理 | Riverpod |
| アーキテクチャ | MVVM |
| 地図 | flutter_map + OpenStreetMap |
| バックエンド | Firebase (Auth / Firestore / Storage) |
| 地理検索 | geoflutterfire_plus (Geohash) |
| 位置情報 | geolocator |

## セットアップ

### 1. 依存パッケージのインストール

```bash
flutter pub get
```

### 2. Firebase設定

`lib/firebase_options.dart` にFirebaseプロジェクトの設定値を記入してください。

```
Firebase コンソール → プロジェクト設定 → アプリの設定からコピー
```

または FlutterFire CLI を使って自動生成:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

> `lib/firebase_options.dart` は `.gitignore` に追加済みのため、Gitには含まれません。

### 3. Firebase サービスの有効化

Firebase コンソールで以下を有効化してください。

- **Authentication** → Sign-in method → メール/パスワード・Google を有効化
- **Firestore Database** → 作成（本番モードで開始）
- **Storage** → 作成

### 4. Firestore セキュリティルール

Firebase コンソール → Firestore → ルール に以下を設定:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /smoking_spots/{spotId} {
      allow read: if true;
      allow create: if request.auth != null;
      allow update: if request.auth != null
        && request.resource.data.diff(resource.data).affectedKeys()
            .hasOnly(['totalRating', 'ratingCount', 'comments']);
      allow delete: if request.auth != null
        && request.auth.uid == resource.data.postedBy;
    }
  }
}
```

### 5. 開発サーバーの起動

```bash
flutter run -d chrome
```

## ビルド・デプロイ

```bash
# Webビルド
flutter build web

# Firebase Hosting へデプロイ
firebase deploy
```

## プロジェクト構成

```
lib/
├── main.dart                          # エントリーポイント・Firebase初期化
├── firebase_options.dart              # Firebase設定（Gitignore対象）
├── models/
│   └── smoking_spot_model.dart        # データモデル（SpotType / CommentModel / SmokingSpotModel）
├── repositories/
│   ├── auth_repository.dart           # Firebase Auth操作
│   └── smoking_spot_repository.dart   # Firestore CRUD・Geohash検索
├── services/
│   └── storage_service.dart           # Firebase Storage 画像アップロード
├── providers/
│   └── app_providers.dart             # Riverpod プロバイダー定義
├── viewmodels/
│   ├── map_state.dart                 # 地図画面の状態クラス
│   └── map_view_model.dart            # 地図画面のビジネスロジック
├── views/
│   ├── map_view.dart                  # メイン地図画面
│   └── auth_view.dart                 # ログイン・新規登録画面
└── widgets/
    ├── cookie_consent_banner.dart     # Cookie同意バナー
    ├── add_spot_dialog.dart           # 喫煙所追加フォーム
    └── spot_detail_sheet.dart         # 喫煙所詳細・評価・コメント
```

## 地図操作

| 操作 | 動作 |
|------|------|
| ドラッグ | 地図を移動 |
| スクロール | ズームイン/アウト |
| 「追加」ボタン | ピン設置モードに入る |
| ピン設置モード中に地図を移動 | 設置位置を決める |
| 「ここに追加」ボタン | 喫煙所情報の入力フォームを開く |
| ピンをタップ | 喫煙所の詳細を表示 |
| 現在地ボタン（右下） | 現在地に地図を移動 |

## 注意事項

- `lib/firebase_options.dart` は **Gitにコミットしないでください**（`.gitignore` 設定済み）
- 地図タイルは OpenStreetMap を使用しています。[利用規約](https://www.openstreetmap.org/copyright)に従ってください
- 位置情報の取得にはブラウザの許可が必要です
