import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';

/// 認証モードの列挙
enum _AuthMode { signIn, register }

/// 認証画面
/// ログイン・新規登録をボトムシート形式で提供する
class AuthView extends ConsumerStatefulWidget {
  /// 認証画面を生成する
  const AuthView({super.key});

  @override
  ConsumerState<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends ConsumerState<AuthView> {
  /// フォームキー
  final _formKey = GlobalKey<FormState>();

  /// メールアドレス入力コントローラー
  final _emailController = TextEditingController();

  /// パスワード入力コントローラー
  final _passwordController = TextEditingController();

  /// 表示名入力コントローラー（新規登録時のみ使用）
  final _displayNameController = TextEditingController();

  /// 現在の認証モード
  _AuthMode _authMode = _AuthMode.signIn;

  /// 処理中フラグ
  bool _isLoading = false;

  /// エラーメッセージ（エラーなしはnull）
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  /// ログインモードと新規登録モードを切り替える
  void _toggleAuthMode() {
    setState(() {
      _authMode =
          _authMode == _AuthMode.signIn ? _AuthMode.register : _AuthMode.signIn;
      _errorMessage = null;
    });
  }

  /// メール/パスワードで認証を実行する
  Future<void> _submitForm() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      if (_authMode == _AuthMode.signIn) {
        // ログイン処理
        await authRepo.signInWithEmailPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        // 新規登録処理
        await authRepo.createUserWithEmailPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _displayNameController.text.trim(),
        );
      }
      // 認証成功時にボトムシートを閉じる
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _errorMessage = _parseFirebaseError(e.toString());
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Googleアカウントでサインインする
  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _errorMessage = 'Googleサインインに失敗しました。ポップアップがブロックされていないか確認してください。';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Firebaseのエラーコードをユーザーフレンドリーなメッセージに変換する
  ///
  /// [error] エラーの文字列表現
  String _parseFirebaseError(String error) {
    if (error.contains('user-not-found')) return 'このメールアドレスは登録されていません';
    if (error.contains('wrong-password')) return 'パスワードが正しくありません';
    if (error.contains('email-already-in-use')) return 'このメールアドレスは既に使用されています';
    if (error.contains('weak-password')) return 'パスワードが弱すぎます（6文字以上必要）';
    if (error.contains('invalid-email')) return 'メールアドレスの形式が正しくありません';
    if (error.contains('network-request-failed')) return 'ネットワークエラーが発生しました';
    return '認証エラーが発生しました。もう一度お試しください。';
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ドラッグハンドル
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // タイトル
              Text(
                _authMode == _AuthMode.signIn ? 'ログイン' : 'アカウント作成',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // 入力フォーム
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // 表示名（新規登録時のみ表示）
                    if (_authMode == _AuthMode.register) ...[
                      TextFormField(
                        controller: _displayNameController,
                        decoration: const InputDecoration(
                          labelText: '表示名',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? '表示名を入力してください' : null,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // メールアドレス
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'メールアドレス',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'メールアドレスを入力してください' : null,
                    ),
                    const SizedBox(height: 16),

                    // パスワード
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'パスワード',
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      validator: (v) => (v == null || v.length < 6)
                          ? '6文字以上のパスワードを入力してください'
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // エラーメッセージ表示
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red[700]),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 16),

              // メール認証ボタン
              ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _authMode == _AuthMode.signIn ? 'ログイン' : 'アカウントを作成',
                      ),
              ),
              const SizedBox(height: 12),

              // 区切り
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('または', style: TextStyle(color: Colors.grey)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 12),

              // Googleサインインボタン
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _signInWithGoogle,
                icon: const Icon(Icons.g_mobiledata, size: 24),
                label: const Text('Googleでログイン'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 16),

              // モード切り替えリンク
              TextButton(
                onPressed: _toggleAuthMode,
                child: Text(
                  _authMode == _AuthMode.signIn
                      ? 'アカウントをお持ちでない方はこちら'
                      : 'すでにアカウントをお持ちの方はこちら',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
