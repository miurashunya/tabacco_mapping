import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../models/smoking_spot_model.dart';
import '../providers/app_providers.dart';

/// 喫煙所追加ダイアログ
/// 新しい喫煙所の情報を入力するフォームを表示する
class AddSpotDialog extends ConsumerStatefulWidget {
  /// 追加する喫煙所の位置
  final LatLng position;

  /// 喫煙所追加ダイアログを生成する
  ///
  /// [position] 追加位置の緯度経度
  const AddSpotDialog({
    super.key,
    required this.position,
  });

  @override
  ConsumerState<AddSpotDialog> createState() => _AddSpotDialogState();
}

class _AddSpotDialogState extends ConsumerState<AddSpotDialog> {
  /// フォームキー
  final _formKey = GlobalKey<FormState>();

  /// 喫煙所名の入力コントローラー
  final _nameController = TextEditingController();

  /// 選択された喫煙所種類
  SpotType _selectedType = SpotType.outdoor;

  /// 選択された画像のバイトデータ
  Uint8List? _imageBytes;

  /// 選択された画像のファイル名
  String? _imageFileName;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// ファイルピッカーで画像を選択する
  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      // Web環境ではbytesが必須（パスは取得できない）
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      setState(() {
        _imageBytes = file.bytes;
        _imageFileName = file.name;
      });
    }
  }

  /// フォームを送信して喫煙所を追加する
  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // ログイン状態を確認
    final user = ref.read(firebaseAuthProvider).valueOrNull;
    if (user == null) return;

    await ref.read(mapViewModelProvider.notifier).addSpot(
          name: _nameController.text.trim(),
          latitude: widget.position.latitude,
          longitude: widget.position.longitude,
          type: _selectedType,
          postedBy: user.uid,
          postedByName: user.displayName ?? 'ゲスト',
          imageBytes: _imageBytes,
          imageFileName: _imageFileName,
        );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapViewModelProvider);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.add_location, color: Colors.green),
          SizedBox(width: 8),
          Text('喫煙所を追加'),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 選択位置の表示
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${widget.position.latitude.toStringAsFixed(6)}, '
                        '${widget.position.longitude.toStringAsFixed(6)}',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 喫煙所名の入力フィールド
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '喫煙所名',
                  hintText: '例：○○ビル喫煙スペース',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.smoking_rooms),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? '喫煙所名を入力してください' : null,
              ),
              const SizedBox(height: 16),

              // 種類の選択（屋内/屋外）
              const Text(
                '種類',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: SpotType.values.map((type) {
                  return ChoiceChip(
                    label: Text(type.label),
                    selected: _selectedType == type,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedType = type);
                    },
                    selectedColor: type == SpotType.indoor
                        ? Colors.blue[200]
                        : Colors.green[200],
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // 写真の選択（任意）
              const Text(
                '写真（任意）',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),

              if (_imageBytes != null)
                // 選択済み画像のプレビュー
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        _imageBytes!,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    // 選択解除ボタン
                    Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: IconButton(
                        icon:
                            const Icon(Icons.close, color: Colors.white, size: 18),
                        onPressed: () {
                          setState(() {
                            _imageBytes = null;
                            _imageFileName = null;
                          });
                        },
                      ),
                    ),
                  ],
                )
              else
                // 写真選択ボタン
                OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('写真を選択'),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: mapState.isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: mapState.isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('追加', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
