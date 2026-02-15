import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

/// Firebase Storageサービス
/// 喫煙所の写真アップロードを管理する
class StorageService {
  /// Firebase Storageインスタンス
  final FirebaseStorage _storage;

  /// UUID生成器
  static const _uuid = Uuid();

  /// ストレージサービスを生成する
  ///
  /// [storage] テスト用のFirebaseStorageインスタンス（省略時は実インスタンスを使用）
  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  /// 喫煙所の写真をアップロードしてダウンロードURLを返す
  ///
  /// [imageBytes] アップロードする画像のバイトデータ
  /// [fileName] 元のファイル名（拡張子取得用）
  Future<String> uploadSpotPhoto({
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    // 拡張子を取得
    final ext = fileName.split('.').last.toLowerCase();
    // ユニークなファイル名を生成して重複を防ぐ
    final uniqueFileName = '${_uuid.v4()}.$ext';
    final ref = _storage.ref('spot_photos/$uniqueFileName');

    // Content-Typeを設定してアップロード
    final metadata = SettableMetadata(contentType: 'image/$ext');
    await ref.putData(imageBytes, metadata);

    // アップロード完了後にダウンロードURLを取得
    return await ref.getDownloadURL();
  }
}
