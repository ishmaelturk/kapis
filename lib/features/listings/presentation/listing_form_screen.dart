import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../../domain/models/listing.dart';
import '../../../domain/models/listing_match.dart';
import '../../../domain/models/pickup_coordinates.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../firebase/firebase_providers.dart';
import '../../../firebase/firebase_runtime_config.dart';
import 'pickup_location_picker_screen.dart';

class ListingFormScreen extends ConsumerStatefulWidget {
  const ListingFormScreen({super.key});

  @override
  ConsumerState<ListingFormScreen> createState() => _ListingFormScreenState();
}

class _ListingFormScreenState extends ConsumerState<ListingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _areaController = TextEditingController();
  final _tagsController = TextEditingController();

  ListingCategory _category = ListingCategory.householdGoods;
  ItemCondition _condition = ItemCondition.good;
  PickupCoordinates? _pickupCoordinates;
  Uint8List? _suggestionPhoto;
  String? _suggestionPhotoMimeType;
  bool _isSaving = false;
  bool _isSuggesting = false;
  String? _errorMessage;
  String? _suggestionMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _areaController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _selectPickupPoint() async {
    final selected = await Navigator.of(context).push<PickupCoordinates>(
      MaterialPageRoute(
        builder: (_) =>
            PickupLocationPickerScreen(initialCoordinates: _pickupCoordinates),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _pickupCoordinates = selected;
        _errorMessage = null;
      });
    }
  }

  Future<void> _selectSuggestionPhoto() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (file == null || !mounted) return;

      final mimeType = _imageMimeType(file.mimeType, file.name);
      if (mimeType == null) {
        _showError('Yalnızca JPEG, PNG veya WebP fotoğraf seçebilirsin.');
        return;
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || bytes.length > 4 * 1024 * 1024) {
        _showError('Fotoğraf en fazla 4 MiB olmalı.');
        return;
      }
      setState(() {
        _suggestionPhoto = bytes;
        _suggestionPhotoMimeType = mimeType;
        _errorMessage = null;
        _suggestionMessage = null;
      });
    } on PlatformException catch (error) {
      _showError(error.message ?? error.code);
    }
  }

  Future<void> _suggestListing() async {
    final titleBeforeRequest = _titleController.text;
    final notesBeforeRequest = _descriptionController.text;
    setState(() {
      _isSuggesting = true;
      _errorMessage = null;
      _suggestionMessage = null;
    });
    try {
      final matchmaker = ref.read(listingMatchmakerProvider);
      final photoBytes = _suggestionPhoto;
      final result = await matchmaker.suggestListing(
        title: _titleController.text,
        notes: _descriptionController.text,
        photo: photoBytes == null
            ? null
            : ListingMatchPhoto(
                bytes: photoBytes,
                mimeType: _suggestionPhotoMimeType!,
              ),
      );
      if (!mounted) return;
      if (_titleController.text != titleBeforeRequest ||
          _descriptionController.text != notesBeforeRequest) {
        setState(() {
          _suggestionMessage =
              'Metin değiştiği için öneri uygulanmadı. Tekrar deneyebilirsin.';
        });
        return;
      }
      setState(() {
        _titleController.text = result.suggestion.title;
        _descriptionController.text = result.suggestion.description;
        _category = result.suggestion.category;
        _tagsController.text = result.suggestion.tags.join(', ');
        _suggestionMessage = result.usedFallback
            ? 'AI şu anda kullanılamıyor; yerel öneriyi gözden geçir.'
            : 'Öneri hazır. Yayınlamadan önce kontrol edebilirsin.';
      });
    } on ArgumentError catch (error) {
      _showError(error.message?.toString() ?? 'İlan bilgilerini kontrol et.');
    } on FirebaseConfigurationException catch (error) {
      _showError(error.toString());
    } on FirebaseAIException catch (error) {
      _showError(error.message);
    } on FirebaseAISdkException catch (error) {
      _showError(error.message);
    } on FirebaseException catch (error) {
      _showError(error.message ?? error.code);
    } finally {
      if (mounted) {
        setState(() => _isSuggesting = false);
      }
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    final pickupCoordinates = _pickupCoordinates;
    if (pickupCoordinates == null) {
      setState(() => _errorMessage = 'Önce teslim alma pinini seç.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final repository = await ref.read(listingRepositoryProvider.future);
      final listing = await repository.create(
        ListingDraft(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          pickupArea: _areaController.text.trim(),
          category: _category,
          condition: _condition,
          tags: _tagsController.text
              .split(',')
              .map((tag) => tag.trim())
              .where((tag) => tag.isNotEmpty)
              .toList(growable: false),
        ),
        pickupCoordinates: pickupCoordinates,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('“${listing.title}” bağış ilanı yayınlandı.')),
      );
      Navigator.of(context).pop();
    } on FirebaseConfigurationException catch (error) {
      _showError(error.toString());
    } on AuthenticationRequiredException catch (error) {
      _showError('$error Lütfen önce hesabına giriş yap.');
    } on FirebaseException catch (error) {
      _showError(error.message ?? error.code);
    } on StateError catch (error) {
      _showError(error.message);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      setState(() => _errorMessage = message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bağış ilanı oluştur')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'İlanlar ücretsizdir ve yalnızca elden teslim edilir.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Eşyanın adı',
                  border: OutlineInputBorder(),
                ),
                validator: _requiredText,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLength: 1000,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Açıklama',
                  border: OutlineInputBorder(),
                ),
                validator: _requiredText,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isSaving || _isSuggesting
                    ? null
                    : _selectSuggestionPhoto,
                icon: const Icon(Icons.photo_outlined),
                label: Text(
                  _suggestionPhoto == null
                      ? 'AI önerisi için isteğe bağlı fotoğraf ekle'
                      : 'Fotoğrafı değiştir',
                ),
              ),
              if (_suggestionPhoto case final photo?) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: Image.memory(photo, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _isSuggesting
                          ? null
                          : () => setState(() {
                              _suggestionPhoto = null;
                              _suggestionPhotoMimeType = null;
                            }),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Fotoğrafı kaldır'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              const Text(
                'İlan metni ve seçtiğin fotoğraf öneri için Firebase AI’ya '
                'gönderilir. Teslimat konumu gönderilmez.',
              ),
              OutlinedButton.icon(
                onPressed: _isSaving || _isSuggesting ? null : _suggestListing,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: _isSuggesting
                    ? const Text('Öneri hazırlanıyor...')
                    : const Text('İlan metni için AI önerisi al'),
              ),
              if (_suggestionMessage case final message?) ...[
                const SizedBox(height: 8),
                Text(message),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _areaController,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Semt / mahalle',
                  helperText:
                      'Sokak veya kapı numarası girme; kesin nokta alıcı '
                      'ayırtınca paylaşılır.',
                  border: OutlineInputBorder(),
                ),
                validator: _requiredText,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ListingCategory>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Kategori',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final category in ListingCategory.values)
                    DropdownMenuItem(
                      value: category,
                      child: Text(category.label),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _category = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ItemCondition>(
                initialValue: _condition,
                decoration: const InputDecoration(
                  labelText: 'Durum',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final condition in ItemCondition.values)
                    DropdownMenuItem(
                      value: condition,
                      child: Text(condition.label),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _condition = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'Etiketler (virgülle ayır)',
                  border: OutlineInputBorder(),
                ),
                validator: _validateTags,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _isSaving ? null : _selectPickupPoint,
                icon: const Icon(Icons.map_outlined),
                label: Text(
                  _pickupCoordinates == null
                      ? 'Teslim alma pinini haritada seç'
                      : 'Teslim alma pini seçildi',
                ),
              ),
              if (_errorMessage case final message?) ...[
                const SizedBox(height: 12),
                Text(
                  message,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _isSaving ? null : _submit,
                child: _isSaving
                    ? const CircularProgressIndicator()
                    : const Text('Ücretsiz ilanı yayınla'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _requiredText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Bu alan gerekli.';
    }
    return null;
  }

  String? _validateTags(String? value) {
    final tags = (value ?? '')
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty);
    if (tags.length > 10 || tags.any((tag) => tag.length > 32)) {
      return 'En fazla 10 etiket kullan; her biri 32 karakteri aşmasın.';
    }
    return null;
  }

  String? _imageMimeType(String? mimeType, String fileName) {
    if (mimeType != null &&
        const {'image/jpeg', 'image/png', 'image/webp'}.contains(mimeType)) {
      return mimeType;
    }
    return switch (fileName.toLowerCase().split('.').last) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => null,
    };
  }
}
