import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:uuid/uuid.dart';

import '../models/smoking_spot_model.dart';
import '../repositories/smoking_spot_repository.dart';
import '../services/storage_service.dart';
import 'map_state.dart';

/// マップ画面のViewModel
/// 喫煙所データの取得・追加・評価・コメントを管理する
class MapViewModel extends StateNotifier<MapState> {
  /// 喫煙所リポジトリ
  final SmokingSpotRepository _spotRepository;

  /// ストレージサービス
  final StorageService _storageService;

  /// 現在のSpotデータStreamのサブスクリプション
  StreamSubscription<List<SmokingSpotModel>>? _spotsSubscription;

  /// UUID生成器
  static const _uuid = Uuid();

  /// マップViewModelを生成する
  ///
  /// [spotRepository] 喫煙所リポジトリ
  /// [storageService] ストレージサービス
  MapViewModel({
    required SmokingSpotRepository spotRepository,
    required StorageService storageService,
  })  : _spotRepository = spotRepository,
        _storageService = storageService,
        super(const MapState.initial());

  @override
  void dispose() {
    // Streamリークを防ぐためdisposeでキャンセル
    _spotsSubscription?.cancel();
    super.dispose();
  }

  /// 指定した地点周辺の喫煙所をリアルタイム取得する
  ///
  /// [latitude] 中心緯度
  /// [longitude] 中心経度
  /// [radiusInKm] 検索半径（km）
  void loadSpotsNearby({
    required double latitude,
    required double longitude,
    required double radiusInKm,
  }) {
    // 前のサブスクリプションをキャンセルして再購読
    _spotsSubscription?.cancel();
    state = state.copyWith(isLoading: true, clearError: true);

    final center = GeoFirePoint(GeoPoint(latitude, longitude));

    _spotsSubscription = _spotRepository
        .getSpotsNearby(
          center: center,
          radiusInKm: radiusInKm,
        )
        .listen(
          (spots) {
            state = state.copyWith(
              spots: spots,
              isLoading: false,
            );
          },
          onError: (Object error) {
            state = state.copyWith(
              isLoading: false,
              errorMessage: '喫煙所の読み込みに失敗しました: $error',
            );
          },
        );
  }

  /// 喫煙所を選択状態にする
  ///
  /// [spot] 選択する喫煙所
  void selectSpot(SmokingSpotModel spot) {
    state = state.copyWith(selectedSpot: spot);
  }

  /// 喫煙所の選択を解除する
  void deselectSpot() {
    state = state.copyWith(clearSelectedSpot: true);
  }

  /// 新しい喫煙所を追加する
  ///
  /// [name] 喫煙所名
  /// [latitude] 緯度
  /// [longitude] 経度
  /// [type] 種類（屋内/屋外）
  /// [postedBy] 投稿者UID
  /// [postedByName] 投稿者表示名
  /// [imageBytes] 写真データ（任意）
  /// [imageFileName] 写真ファイル名（任意）
  Future<void> addSpot({
    required String name,
    required double latitude,
    required double longitude,
    required SpotType type,
    required String postedBy,
    required String postedByName,
    Uint8List? imageBytes,
    String? imageFileName,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // 写真がある場合はStorageにアップロード
      String? photoUrl;
      if (imageBytes != null && imageFileName != null) {
        photoUrl = await _storageService.uploadSpotPhoto(
          imageBytes: imageBytes,
          fileName: imageFileName,
        );
      }

      // GeoFirePointからGeohashを計算
      final geoPoint = GeoPoint(latitude, longitude);
      final firePoint = GeoFirePoint(geoPoint);
      final geohash = firePoint.geohash;

      // 喫煙所モデルを構築
      final spot = SmokingSpotModel(
        id: _uuid.v4(),
        name: name,
        latitude: latitude,
        longitude: longitude,
        geohash: geohash,
        type: type,
        photoUrl: photoUrl,
        totalRating: 0,
        ratingCount: 0,
        comments: const [],
        postedBy: postedBy,
        postedByName: postedByName,
        createdAt: DateTime.now(),
      );

      await _spotRepository.addSpot(spot);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '喫煙所の追加に失敗しました: $e',
      );
    }
  }

  /// 喫煙所に評価を追加する
  ///
  /// [spotId] 対象の喫煙所ID
  /// [rating] 評価値（1〜5）
  Future<void> addRating({
    required String spotId,
    required double rating,
  }) async {
    try {
      await _spotRepository.addRating(spotId: spotId, rating: rating);
    } catch (e) {
      state = state.copyWith(
        errorMessage: '評価の送信に失敗しました: $e',
      );
    }
  }

  /// 喫煙所にコメントを追加する
  ///
  /// [spotId] 対象の喫煙所ID
  /// [text] コメント本文
  /// [userId] 投稿者UID
  /// [userName] 投稿者表示名
  Future<void> addComment({
    required String spotId,
    required String text,
    required String userId,
    required String userName,
  }) async {
    try {
      final comment = CommentModel(
        id: _uuid.v4(),
        text: text,
        userId: userId,
        userName: userName,
        createdAt: DateTime.now(),
      );
      await _spotRepository.addComment(spotId: spotId, comment: comment);
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'コメントの送信に失敗しました: $e',
      );
    }
  }

  /// エラーメッセージをクリアする
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}
