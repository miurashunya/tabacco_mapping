import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/smoking_spot_model.dart';
import '../providers/app_providers.dart';

/// 喫煙所詳細ボトムシート
/// 選択した喫煙所の詳細情報・評価・コメント機能を提供する
class SpotDetailSheet extends ConsumerStatefulWidget {
  /// 表示する喫煙所
  final SmokingSpotModel spot;

  /// 喫煙所詳細ボトムシートを生成する
  ///
  /// [spot] 詳細表示する喫煙所
  const SpotDetailSheet({
    super.key,
    required this.spot,
  });

  @override
  ConsumerState<SpotDetailSheet> createState() => _SpotDetailSheetState();
}

class _SpotDetailSheetState extends ConsumerState<SpotDetailSheet> {
  /// コメント入力コントローラー
  final _commentController = TextEditingController();

  /// 選択中の評価値（0は未選択）
  double _selectedRating = 0;

  /// 日付フォーマッタ
  final _dateFormat = DateFormat('yyyy/MM/dd HH:mm');

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  /// 評価を送信する
  ///
  /// [rating] 送信する評価値（1〜5）
  Future<void> _submitRating(double rating) async {
    final user = ref.read(firebaseAuthProvider).valueOrNull;
    if (user == null) {
      _showLoginRequired();
      return;
    }

    await ref.read(mapViewModelProvider.notifier).addRating(
          spotId: widget.spot.id,
          rating: rating,
        );

    if (mounted) {
      setState(() => _selectedRating = rating);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('評価を送信しました')),
      );
    }
  }

  /// コメントを送信する
  Future<void> _submitComment() async {
    final user = ref.read(firebaseAuthProvider).valueOrNull;
    if (user == null) {
      _showLoginRequired();
      return;
    }

    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    await ref.read(mapViewModelProvider.notifier).addComment(
          spotId: widget.spot.id,
          text: text,
          userId: user.uid,
          userName: user.displayName ?? 'ゲスト',
        );

    _commentController.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('コメントを投稿しました')),
      );
    }
  }

  /// ログインが必要であることをSnackBarで通知する
  void _showLoginRequired() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('この機能を利用するにはログインが必要です'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              // キーボード表示時のpadding
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 16),

                // 喫煙所名と種別チップ
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        widget.spot.name,
                        style:
                            Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(widget.spot.type.label),
                      backgroundColor: widget.spot.type == SpotType.indoor
                          ? Colors.blue[100]
                          : Colors.green[100],
                      labelStyle: TextStyle(
                        color: widget.spot.type == SpotType.indoor
                            ? Colors.blue[800]
                            : Colors.green[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // 投稿者・投稿日時
                Text(
                  '投稿: ${widget.spot.postedByName}  '
                  '${_dateFormat.format(widget.spot.createdAt)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 16),

                // 写真表示（ある場合のみ）
                if (widget.spot.photoUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      widget.spot.photoUrl!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      // 画像読み込み失敗時のフォールバック
                      errorBuilder: (_, __, ___) => Container(
                        height: 200,
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(Icons.image_not_supported, size: 48),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 評価セクション
                const Divider(),
                Text(
                  '評価',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),

                // 平均評価の表示
                Row(
                  children: [
                    Text(
                      widget.spot.averageRating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStarRow(widget.spot.averageRating, size: 20),
                        Text(
                          '${widget.spot.ratingCount}件の評価',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 評価送信UI
                Text(
                  'タップして評価する',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 4),
                Row(
                  children: List.generate(5, (i) {
                    final value = (i + 1).toDouble();
                    return IconButton(
                      icon: Icon(
                        value <= _selectedRating
                            ? Icons.star
                            : Icons.star_border,
                        color: Colors.amber,
                        size: 36,
                      ),
                      onPressed: () => _submitRating(value),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    );
                  }),
                ),

                // コメントセクション
                const Divider(),
                Text(
                  'コメント (${widget.spot.comments.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),

                // コメント入力フィールド
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: const InputDecoration(
                          hintText: 'コメントを入力...',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.all(12),
                        ),
                        maxLines: 3,
                        minLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      icon: const Icon(Icons.send),
                      onPressed: _submitComment,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // コメント一覧
                ...widget.spot.comments.map((comment) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // コメントヘッダー（ユーザー名・日時）
                          Row(
                            children: [
                              const Icon(Icons.person,
                                  size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                comment.userName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              const Spacer(),
                              Text(
                                _dateFormat.format(comment.createdAt),
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // コメント本文
                          Text(comment.text),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 星評価を表示するRowを構築する
  ///
  /// [rating] 評価値
  /// [size] 星のサイズ
  Widget _buildStarRow(double rating, {double size = 16}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final value = i + 1;
        if (value <= rating) {
          return Icon(Icons.star, color: Colors.amber, size: size);
        } else if (value - 0.5 <= rating) {
          return Icon(Icons.star_half, color: Colors.amber, size: size);
        } else {
          return Icon(Icons.star_border, color: Colors.amber, size: size);
        }
      }),
    );
  }
}
