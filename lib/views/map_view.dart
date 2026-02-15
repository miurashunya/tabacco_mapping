import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
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

  /// ピン設置モード中かどうか
  bool _isPlacingMode = false;

  @override
  void initState() {
    super.initState();
    // ウィジェット構築後に現在地へ移動してからデータを読み込む
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _moveToCurrentLocation();
      _loadSpots();
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// ブラウザの位置情報許可を得て現在地に地図を移動する
  /// 許可拒否や取得失敗の場合はデフォルト位置（東京）のまま継続する
  Future<void> _moveToCurrentLocation() async {
    try {
      // 位置情報の許可状態を確認
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        // 未許可の場合はブラウザの許可ダイアログを表示
        permission = await Geolocator.requestPermission();
      }

      // 許可が得られない場合はデフォルト位置のまま
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      // 現在地を取得（タイムアウト10秒）
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final currentLatLng = LatLng(position.latitude, position.longitude);

      if (!mounted) return;

      // 地図を現在地に移動
      setState(() => _center = currentLatLng);
      _mapController.move(currentLatLng, _currentZoom);
    } catch (_) {
      // 取得失敗時はデフォルト位置（東京）のまま継続
    }
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

  /// ピン設置モードを開始する（ログイン確認付き）
  void _enterPlacingMode() {
    final user = ref.read(firebaseAuthProvider).valueOrNull;
    if (user == null) {
      _showLoginRequiredDialog();
      return;
    }
    setState(() => _isPlacingMode = true);
  }

  /// ピン設置モードをキャンセルする
  void _cancelPlacingMode() {
    setState(() => _isPlacingMode = false);
  }

  /// 現在の中央座標で喫煙所追加ダイアログを表示する
  void _confirmPlacingPosition() {
    setState(() => _isPlacingMode = false);
    showDialog(
      context: context,
      builder: (context) => AddSpotDialog(position: _center),
    );
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

          // 現在地ボタン（右下）
          Positioned(
            bottom: cookieConsent ? 96 : 184,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'my_location',
              onPressed: () async {
                await _moveToCurrentLocation();
                _loadSpots();
              },
              tooltip: '現在地を表示',
              child: const Icon(Icons.my_location),
            ),
          ),

          // ピン設置モード: 画面中央に固定ピンを表示
          if (_isPlacingMode)
            IgnorePointer(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 吹き出しラベル
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '地図を動かして位置を合わせてください',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // ピンアイコン（中心が地面に刺さるよう下にオフセット）
                    const Icon(
                      Icons.location_pin,
                      color: Colors.red,
                      size: 56,
                    ),
                    // ピンの影（接地感を出す）
                    Container(
                      width: 12,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    // ピンの高さ分の余白（中心がずれないよう調整）
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),

          // ピン設置モード: 確定・キャンセルボタン
          if (_isPlacingMode)
            Positioned(
              bottom: 32,
              left: 24,
              right: 24,
              child: Row(
                children: [
                  // キャンセルボタン
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _cancelPlacingMode,
                      icon: const Icon(Icons.close),
                      label: const Text('キャンセル'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 確定ボタン
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _confirmPlacingPosition,
                      icon: const Icon(Icons.check),
                      label: const Text('ここに追加'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
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

      // 喫煙所追加FAB（設置モード中は非表示）
      floatingActionButton: _isPlacingMode
          ? null
          : FloatingActionButton.extended(
              heroTag: 'add_spot',
              onPressed: _enterPlacingMode,
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
