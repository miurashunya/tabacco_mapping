// このファイルはFlutterFire CLIで自動生成されます。
// `flutterfire configure` コマンドを実行して生成することを推奨します。
// または Firebase コンソールから手動でコピーしてください。
//
// 手順:
// 1. Firebase コンソール (https://console.firebase.google.com/) でプロジェクトを作成
// 2. ウェブアプリを追加してFirebase設定をコピー
// 3. 以下のプレースホルダーを実際の値に置き換える
//    または `dart pub global activate flutterfire_cli` → `flutterfire configure` で自動生成

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// FirebaseのデフォルトOptions設定
class DefaultFirebaseOptions {
  /// 現在のプラットフォームに対応したFirebaseOptionsを返す
  static FirebaseOptions get currentPlatform {
    // Webの場合はweb設定を返す
    if (kIsWeb) return web;
    // Androidの場合はandroid設定を返す
    if (defaultTargetPlatform == TargetPlatform.android) return android;
    // サポートされていないプラットフォームの場合はエラーをスロー
    throw UnsupportedError('このプラットフォームはサポートされていません: $defaultTargetPlatform');
  }

  /// Web用設定
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyAh8pJVGabOAIpAkl_sVmos84tV383hp2w",
    authDomain: "tabacco-mapping.firebaseapp.com",
    projectId: "tabacco-mapping",
    storageBucket: "tabacco-mapping.firebasestorage.app",
    messagingSenderId: "955821461487",
    appId: "1:955821461487:web:58338299262f7e56aff01a",
    measurementId: "G-JRLYN6SF24",
  );

  /// Android用設定
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDAVbt3RvyZ5wZy_mTpKuKygvk9c3rxJTo',
    appId: '1:955821461487:android:1eceaffa057c5ff9aff01a',
    messagingSenderId: '955821461487',
    projectId: 'tabacco-mapping',
    storageBucket: 'tabacco-mapping.firebasestorage.app',
  );
}
