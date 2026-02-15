import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';

/// Cookie同意バナーWidget
/// 初回アクセス時に画面下部に表示し、Cookie/LocalStorageの使用に同意を求める
class CookieConsentBanner extends ConsumerWidget {
  /// Cookie同意バナーを生成する
  const CookieConsentBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: Colors.grey[900],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // 説明テキスト
            const Expanded(
              child: Text(
                'このサイトはCookieとLocalStorageを使用しています。'
                'ログイン状態の維持のために使用します。',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
            const SizedBox(width: 12),
            // 同意ボタン
            ElevatedButton(
              onPressed: () {
                ref
                    .read(cookieConsentNotifierProvider.notifier)
                    .acceptCookies();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              child: const Text('同意する'),
            ),
          ],
        ),
      ),
    );
  }
}
