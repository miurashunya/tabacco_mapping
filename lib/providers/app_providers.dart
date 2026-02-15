import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../repositories/auth_repository.dart';
import '../repositories/smoking_spot_repository.dart';
import '../services/storage_service.dart';
import '../viewmodels/map_state.dart';
import '../viewmodels/map_view_model.dart';

/// Firebase Auth認証状態のStreamProvider
/// ログイン/ログアウト時に自動的にUserオブジェクトを流す
final firebaseAuthProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// 認証リポジトリのProvider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// 喫煙所リポジトリのProvider
final smokingSpotRepositoryProvider = Provider<SmokingSpotRepository>((ref) {
  return SmokingSpotRepository();
});

/// ストレージサービスのProvider
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

/// マップViewModelのProvider
final mapViewModelProvider =
    StateNotifierProvider<MapViewModel, MapState>((ref) {
  return MapViewModel(
    spotRepository: ref.watch(smokingSpotRepositoryProvider),
    storageService: ref.watch(storageServiceProvider),
  );
});

/// Cookie同意状態を管理するNotifier
class CookieConsentNotifier extends StateNotifier<bool> {
  /// Cookie同意Notifierを生成する
  CookieConsentNotifier() : super(false) {
    _loadConsent();
  }

  /// 保存済みのCookie同意状態をSharedPreferencesから読み込む
  Future<void> _loadConsent() async {
    final prefs = await SharedPreferences.getInstance();
    // まだ読み込まれていない場合のみ更新
    if (mounted) {
      state = prefs.getBool('cookie_consent') ?? false;
    }
  }

  /// Cookie使用に同意してSharedPreferencesに保存する
  Future<void> acceptCookies() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cookie_consent', true);
    state = true;
  }
}

/// Cookie同意状態のStateNotifierProvider
final cookieConsentNotifierProvider =
    StateNotifierProvider<CookieConsentNotifier, bool>((ref) {
  return CookieConsentNotifier();
});
