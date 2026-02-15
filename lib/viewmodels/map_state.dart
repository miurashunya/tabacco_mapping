import '../models/smoking_spot_model.dart';

/// マップ画面の状態クラス
class MapState {
  /// 表示中の喫煙所リスト
  final List<SmokingSpotModel> spots;

  /// データ読み込み中かどうか
  final bool isLoading;

  /// 詳細表示中の喫煙所（選択時のみセット）
  final SmokingSpotModel? selectedSpot;

  /// エラーメッセージ（エラーなしの場合はnull）
  final String? errorMessage;

  /// マップ状態を生成する
  const MapState({
    required this.spots,
    required this.isLoading,
    this.selectedSpot,
    this.errorMessage,
  });

  /// 初期状態を生成する
  const MapState.initial()
      : spots = const [],
        isLoading = false,
        selectedSpot = null,
        errorMessage = null;

  /// 一部のフィールドを変更したコピーを返す
  ///
  /// [clearSelectedSpot] trueの場合selectedSpotをnullにする
  /// [clearError] trueの場合errorMessageをnullにする
  MapState copyWith({
    List<SmokingSpotModel>? spots,
    bool? isLoading,
    SmokingSpotModel? selectedSpot,
    bool clearSelectedSpot = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MapState(
      spots: spots ?? this.spots,
      isLoading: isLoading ?? this.isLoading,
      selectedSpot:
          clearSelectedSpot ? null : (selectedSpot ?? this.selectedSpot),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
