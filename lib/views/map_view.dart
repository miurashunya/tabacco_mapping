import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../models/smoking_spot_model.dart';
import '../providers/app_providers.dart';
import '../widgets/add_spot_dialog.dart';
import '../widgets/cookie_consent_banner.dart';
import '../widgets/spot_detail_sheet.dart';
import 'auth_view.dart';

/// マップメイン画面
/// flutter_map + OpenStreetMapで喫煙所を表示・追加・検索するアプリのメイン画面
class MapView extends ConsumerStatefulWidget {
  /// マップ画面を生成する
  const MapView({super.key});

  @override
  ConsumerState<MapView> createState() => _MapViewState();
}

class _MapViewState extends ConsumerState<MapView> {
  /// flutter_mapのコントローラー
  final _mapController = MapController();

  /// 現在の地図中心座標（初期値: 東京）
  LatLng _center = const LatLng(35.6812, 139.7671);

  /// 現在のズームレベル
  double _currentZoom = 14.0;

  /// 屋内のみ表示フィルター
  bool _filterIndoor = false;

  /// 屋外のみ表示フィルター
  bool _filterOutdoor = false;

  @override
  void initState() {
    super.initState();
    // ウィジェット構築後に初期データを読み込む
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSpots();
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// 現在の地図位置周辺の喫煙所を読み込む
  void _loadSpots() {
    final radius = _calculateRadius(_currentZoom);
    ref.read(mapViewModelProvider.notifier).loadSpotsNearby(
          latitude: _center.latitude,
          longitude: _center.longitude,
          radiusInKm: radius,
        );
  }

  /// ズームレベルに応じた検索半径（km）を返す
  ///
  /// [zoom] flutter_mapのズームレベル
  double _calculateRadius(double zoom) {
    if (zoom >= 16) return 0.5;
    if (zoom >= 14) return 2.0;
    if (zoom >= 12) return 5.0;
    if (zoom >= 10) return 15.0;
    return 30.0;
  }

  /// 喫煙所マーカーのタップ処理
  ///
  /// [spot] タップされた喫煙所
  void _onMarkerTapped(SmokingSpotModel spot) {
    ref.read(mapViewModelProvider.notifier).selectSpot(spot);
    _showSpotDetail(spot);
  }

  /// 喫煙所詳細ボトムシートを表示する
  ///
  /// [spot] 詳細表示する喫煙所
  void _showSpotDetail(SmokingSpotModel spot) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SpotDetailSheet(spot: spot),
    ).then((_) {
      // ボトムシートを閉じたら選択を解除
      ref.read(mapViewModelProvider.notifier).deselectSpot();
    });
  }

  /// 喫煙所追加ダイアログを表示する（ログイン確認付き）
  ///
  /// [position] 追加する位置の緯度経度
  void _showAddSpotDialog(LatLng position) {
    final user = ref.read(firebaseAuthProvider).valueOrNull;
    if (user == null) {
      _showLoginRequiredDialog();
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AddSpotDialog(position: position),
    );
  }

  /// ログインが必要なアクションを試みた時のダイアログを表示する
  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ログインが必要です'),
        content: const Text('喫煙所の追加・評価・コメントにはログインが必要です。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showAuthView();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('ログイン', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// 認証ボトムシートを表示する
  void _showAuthView() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const AuthView(),
    );
  }

  /// 表示中の喫煙所リストからフィルター適用済みのMarkerリストを構築する
  ///
  /// [spots] 全喫煙所リスト
  List<Marker> _buildMarkers(List<SmokingSpotModel> spots) {
    // フィルター条件を適用
    final filtered = spots.where((spot) {
      if (_filterIndoor && spot.type != SpotType.indoor) return false;
      if (_filterOutdoor && spot.type != SpotType.outdoor) return false;
      return true;
    }).toList();

    return filtered.map((spot) {
      // 屋内は青、屋外は緑のピンで視覚的に区別
      final color =
          spot.type == SpotType.indoor ? Colors.blue[700]! : Colors.green[700]!;

      return Marker(
        point: LatLng(spot.latitude, spot.longitude),
        width: 44,
        height: 44,
        child: GestureDetector(
          onTap: () => _onMarkerTapped(spot),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              // ピンアイコン
              Icon(Icons.location_pin, color: color, size: 44),
              // 種別バッジ（屋内/屋外）
              Positioned(
                top: 4,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      spot.type == SpotType.indoor
                          ? Icons.home
                          : Icons.park,
                      size: 10,
                      color: color,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapViewModelProvider);
    final authState = ref.watch(firebaseAuthProvider);
    final cookieConsent = ref.watch(cookieConsentNotifierProvider);

    return Scaffold(
      body: Stack(
        children: [
          // flutter_map（OpenStreetMap）
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: _currentZoom,
              // 長押しで喫煙所追加
              onLongPress: (tapPosition, point) => _showAddSpotDialog(point),
              // カメラ移動完了時にデータ再取得
              onMapEvent: (event) {
                if (event is MapEventMoveEnd ||
                    event is MapEventFlingAnimationEnd ||
                    event is MapEventScrollWheelZoom) {
                  _center = event.camera.center;
                  _currentZoom = event.camera.zoom;
                  _loadSpots();
                }
              },
            ),
            children: [
              // OpenStreetMapタイルレイヤー（無料）
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.tabacco_mapping',
                // タイル読み込み失敗時の最大リトライ回数
                maxNativeZoom: 19,
              ),
              // 喫煙所マーカーレイヤー
              MarkerLayer(
                markers: _buildMarkers(mapState.spots),
              ),
            ],
          ),

          // データ読み込み中インジケーター
          if (mapState.isLoading)
            const Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('読み込み中...', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 上部コントロールパネル（タイトル + 認証ボタン）
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: Row(
              children: [
                // アプリタイトルカード
                const Expanded(
                  child: Card(
                    elevation: 4,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.smoking_rooms, color: Colors.green),
                          SizedBox(width: 8),
                          Text(
                            '喫煙所マップ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 認証状態に応じてユーザーボタンまたはログインボタンを表示
                authState.when(
                  data: (user) => user != null
                      ? _buildUserButton(user)
                      : _buildLoginButton(),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => _buildLoginButton(),
                ),
              ],
            ),
          ),

          // フィルターチップ（右上）
          Positioned(
            top: 104,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildFilterChip(
                  '屋内',
                  _filterIndoor,
                  Colors.blue[200]!,
                  (v) => setState(() {
                    _filterIndoor = v;
                    if (v) _filterOutdoor = false;
                  }),
                ),
                const SizedBox(height: 4),
                _buildFilterChip(
                  '屋外',
                  _filterOutdoor,
                  Colors.green[200]!,
                  (v) => setState(() {
                    _filterOutdoor = v;
                    if (v) _filterIndoor = false;
                  }),
                ),
              ],
            ),
          ),

          // 再検索ボタン（右下）
          Positioned(
            bottom: cookieConsent ? 96 : 184,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'reload',
              onPressed: _loadSpots,
              tooltip: '現在の範囲を再検索',
              child: const Icon(Icons.refresh),
            ),
          ),

          // Cookie同意バナー（未同意時に画面下部に表示）
          if (!cookieConsent)
            const Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: CookieConsentBanner(),
            ),

          // エラーメッセージバー
          if (mapState.errorMessage != null)
            Positioned(
              bottom: cookieConsent ? 16 : 104,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.red[50],
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          mapState.errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          ref
                              .read(mapViewModelProvider.notifier)
                              .clearError();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),

      // 喫煙所追加FAB
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_spot',
        onPressed: () => _showAddSpotDialog(_center),
        icon: const Icon(Icons.add_location_alt),
        label: const Text('追加'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
    );
  }

  /// ログイン済みユーザーのアイコンとポップアップメニューを構築する
  ///
  /// [user] 現在のFirebaseユーザー
  Widget _buildUserButton(User user) {
    return Card(
      elevation: 4,
      child: PopupMenuButton<String>(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ユーザーアイコン（プロフィール画像または頭文字）
              CircleAvatar(
                radius: 14,
                backgroundImage: user.photoURL != null
                    ? NetworkImage(user.photoURL!)
                    : null,
                backgroundColor: Colors.green[100],
                child: user.photoURL == null
                    ? Text(
                        (user.displayName ?? 'U')
                            .substring(0, 1)
                            .toUpperCase(),
                        style: const TextStyle(fontSize: 12),
                      )
                    : null,
              ),
              const SizedBox(width: 6),
              Text(
                user.displayName ?? 'ユーザー',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        itemBuilder: (context) => [
          // ログアウトメニュー項目
          const PopupMenuItem<String>(
            value: 'signout',
            child: Row(
              children: [
                Icon(Icons.logout, size: 18),
                SizedBox(width: 8),
                Text('ログアウト'),
              ],
            ),
          ),
        ],
        onSelected: (value) {
          if (value == 'signout') {
            ref.read(authRepositoryProvider).signOut();
          }
        },
      ),
    );
  }

  /// 未ログイン時のログインボタンを構築する
  Widget _buildLoginButton() {
    return ElevatedButton.icon(
      onPressed: _showAuthView,
      icon: const Icon(Icons.login, size: 18),
      label: const Text('ログイン'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.green,
        elevation: 4,
      ),
    );
  }

  /// フィルターチップを構築する
  ///
  /// [label] チップのラベル
  /// [value] 選択状態
  /// [selectedColor] 選択時の背景色
  /// [onChanged] 選択状態変更コールバック
  Widget _buildFilterChip(
    String label,
    bool value,
    Color selectedColor,
    ValueChanged<bool> onChanged,
  ) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: value,
      onSelected: onChanged,
      backgroundColor: Colors.white,
      selectedColor: selectedColor,
      elevation: 2,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
