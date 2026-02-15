import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

import '../models/smoking_spot_model.dart';

/// 喫煙所リポジトリ
/// Firestoreへの喫煙所データ操作を管理する
class SmokingSpotRepository {
  /// Firestoreインスタンス
  final FirebaseFirestore _firestore;

  /// 喫煙所コレクションの参照
  late final CollectionReference<Map<String, dynamic>> _collection;

  /// 喫煙所リポジトリを生成する
  ///
  /// [firestore] テスト用のFirestoreインスタンス（省略時は実インスタンスを使用）
  SmokingSpotRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance {
    _collection = _firestore.collection('smoking_spots');
  }

  /// 指定した中心点・半径内の喫煙所をStreamで取得する
  ///
  /// [center] 検索中心のGeoFirePoint
  /// [radiusInKm] 検索半径（km）
  Stream<List<SmokingSpotModel>> getSpotsNearby({
    required GeoFirePoint center,
    required double radiusInKm,
  }) {
    // geoflutterfire_plusを使ってgeohashベースの近傍検索を実行
    return GeoCollectionReference<Map<String, dynamic>>(_collection)
        .subscribeWithin(
          center: center,
          radiusInKm: radiusInKm,
          field: 'position',
          // positionフィールド内のgeopointを指定
          geopointFrom: (data) =>
              (data['position']['geopoint'] as GeoPoint),
          strictMode: true,
        )
        .map(
          (docs) => docs
              .map(
                (doc) => SmokingSpotModel.fromFirestore(doc),
              )
              .toList(),
        );
  }

  /// 喫煙所を追加する
  ///
  /// [spot] 追加する喫煙所データ
  Future<void> addSpot(SmokingSpotModel spot) async {
    await _collection.doc(spot.id).set(spot.toFirestore());
  }

  /// 喫煙所の評価を追加する
  ///
  /// [spotId] 対象の喫煙所ID
  /// [rating] 評価値（1〜5）
  Future<void> addRating({
    required String spotId,
    required double rating,
  }) async {
    // アトミックに累計評価と件数をインクリメント
    await _collection.doc(spotId).update({
      'totalRating': FieldValue.increment(rating),
      'ratingCount': FieldValue.increment(1),
    });
  }

  /// 喫煙所にコメントを追加する
  ///
  /// [spotId] 対象の喫煙所ID
  /// [comment] 追加するコメント
  Future<void> addComment({
    required String spotId,
    required CommentModel comment,
  }) async {
    // arrayUnionでコメントをリストに追記
    await _collection.doc(spotId).update({
      'comments': FieldValue.arrayUnion([comment.toMap()]),
    });
  }

  /// 喫煙所を削除する
  ///
  /// [spotId] 削除する喫煙所のID
  /// Firestoreセキュリティルール側でも投稿者本人のみ許可している
  Future<void> deleteSpot({required String spotId}) async {
    await _collection.doc(spotId).delete();
  }
}
