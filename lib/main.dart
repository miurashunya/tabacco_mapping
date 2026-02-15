import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'views/map_view.dart';

/// アプリのエントリーポイント
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebaseの初期化（アプリ起動前に完了させる）
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    // ProviderScopeでRiverpodを全ウィジェットから利用可能にする
    const ProviderScope(
      child: SmokingMapApp(),
    ),
  );
}

/// アプリのルートウィジェット
class SmokingMapApp extends StatelessWidget {
  /// アプリのルートウィジェットを生成する
  const SmokingMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '喫煙所マップ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // グリーンをベースカラーに設定
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const MapView(),
    );
  }
}
