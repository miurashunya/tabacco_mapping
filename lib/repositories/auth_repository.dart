import 'package:firebase_auth/firebase_auth.dart';

/// 認証リポジトリ
/// Firebase Authenticationを使った認証処理を一元管理する
class AuthRepository {
  /// Firebase Authインスタンス
  final FirebaseAuth _auth;

  /// 認証リポジトリを生成する
  ///
  /// [auth] テスト用のFirebaseAuthインスタンス（省略時は実インスタンスを使用）
  AuthRepository({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  /// 認証状態変化のStream
  /// ログイン/ログアウト時にUserオブジェクトを流す
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// 現在ログイン中のユーザー
  User? get currentUser => _auth.currentUser;

  /// Googleアカウントでサインインする
  /// Web環境ではポップアップ方式を使用
  Future<UserCredential> signInWithGoogle() async {
    final provider = GoogleAuthProvider();
    // Webではポップアップを使用（リダイレクト方式はSPA向けではない）
    return await _auth.signInWithPopup(provider);
  }

  /// メール/パスワードでサインインする
  ///
  /// [email] メールアドレス
  /// [password] パスワード
  Future<UserCredential> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// 新規アカウントを作成する
  ///
  /// [email] メールアドレス
  /// [password] パスワード
  /// [displayName] 表示名
  Future<UserCredential> createUserWithEmailPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    // 表示名を設定
    await credential.user?.updateDisplayName(displayName);
    return credential;
  }

  /// サインアウトする
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
