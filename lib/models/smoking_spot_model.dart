import 'package:cloud_firestore/cloud_firestore.dart';

/// 喫煙所の種類（屋内・屋外）
enum SpotType {
  indoor('屋内'),
  outdoor('屋外');

  /// 表示用ラベル
  final String label;

  const SpotType(this.label);

  /// 文字列からSpotTypeに変換する
  ///
  /// [value] 変換元の文字列
  static SpotType fromString(String value) {
    return SpotType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SpotType.outdoor,
    );
  }
}

/// コメントモデル
class CommentModel {
  /// コメントの一意識別子
  final String id;

  /// コメント本文
  final String text;

  /// 投稿者のUID
  final String userId;

  /// 投稿者の表示名
  final String userName;

  /// 投稿日時
  final DateTime createdAt;

  /// コメントモデルを生成する
  ///
  /// [id] コメントID
  /// [text] コメント本文
  /// [userId] 投稿者UID
  /// [userName] 投稿者表示名
  /// [createdAt] 投稿日時
  const CommentModel({
    required this.id,
    required this.text,
    required this.userId,
    required this.userName,
    required this.createdAt,
  });

  /// FirestoreドキュメントのMapからCommentModelを生成する
  ///
  /// [map] Firestoreから取得したデータMap
  factory CommentModel.fromMap(Map<String, dynamic> map) {
    return CommentModel(
      id: map['id'] as String,
      text: map['text'] as String,
      userId: map['userId'] as String,
      userName: map['userName'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  /// FirestoreへシリアライズするためのMapを返す
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'userId': userId,
      'userName': userName,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// 喫煙所データモデル
class SmokingSpotModel {
  /// 喫煙所の一意識別子
  final String id;

  /// 喫煙所名
  final String name;

  /// 緯度
  final double latitude;

  /// 経度
  final double longitude;

  /// Geohash（地理検索用）
  final String geohash;

  /// 種類（屋内/屋外）
  final SpotType type;

  /// 写真URL（任意）
  final String? photoUrl;

  /// 累計評価点
  final double totalRating;

  /// 評価件数
  final int ratingCount;

  /// コメントリスト
  final List<CommentModel> comments;

  /// 投稿者のUID
  final String postedBy;

  /// 投稿者の表示名
  final String postedByName;

  /// 投稿日時
  final DateTime createdAt;

  /// 喫煙所モデルを生成する
  const SmokingSpotModel({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.geohash,
    required this.type,
    this.photoUrl,
    required this.totalRating,
    required this.ratingCount,
    required this.comments,
    required this.postedBy,
    required this.postedByName,
    required this.createdAt,
  });

  /// 平均評価を計算して返す
  double get averageRating => ratingCount > 0 ? totalRating / ratingCount : 0.0;

  /// FirestoreドキュメントからSmokingSpotModelを生成する
  ///
  /// [doc] Firestoreのドキュメントスナップショット
  factory SmokingSpotModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;

    // Firestoreのポジションデータ（geopoint + geohash）を取得
    final position = data['position'] as Map<String, dynamic>;
    final geopoint = position['geopoint'] as GeoPoint;

    // コメントリストを変換
    final commentsData = data['comments'] as List<dynamic>? ?? [];
    final comments = commentsData
        .map((c) => CommentModel.fromMap(c as Map<String, dynamic>))
        .toList();

    return SmokingSpotModel(
      id: doc.id,
      name: data['name'] as String,
      latitude: geopoint.latitude,
      longitude: geopoint.longitude,
      geohash: position['geohash'] as String,
      type: SpotType.fromString(data['type'] as String),
      photoUrl: data['photoUrl'] as String?,
      totalRating: (data['totalRating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: (data['ratingCount'] as int?) ?? 0,
      comments: comments,
      postedBy: data['postedBy'] as String,
      postedByName: data['postedByName'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  /// FirestoreへシリアライズするためのMapを返す
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      // geoflutterfire_plus が検索に使用するpositionフィールド
      'position': {
        'geopoint': GeoPoint(latitude, longitude),
        'geohash': geohash,
      },
      'type': type.name,
      'photoUrl': photoUrl,
      'totalRating': totalRating,
      'ratingCount': ratingCount,
      'comments': comments.map((c) => c.toMap()).toList(),
      'postedBy': postedBy,
      'postedByName': postedByName,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
