import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../application/app_preferences_controller.dart';
import '../../../application/user_error_message.dart';
import '../../../domain/models/app_preferences.dart';

class AccessibilitySettingsScreen extends ConsumerStatefulWidget {
  const AccessibilitySettingsScreen({super.key});

  @override
  ConsumerState<AccessibilitySettingsScreen> createState() =>
      _AccessibilitySettingsScreenState();
}

class _AccessibilitySettingsScreenState
    extends ConsumerState<AccessibilitySettingsScreen> {
  bool _isSaving = false;
  String? _errorMessage;

  Future<void> _setTextSize(AccessibilityTextSize textSize) async {
    await _savePreference(
      () => ref
          .read(appPreferencesProvider.notifier)
          .setAccessibilityTextSize(textSize),
    );
  }

  Future<void> _setHighContrast(bool enabled) async {
    await _savePreference(
      () => ref
          .read(appPreferencesProvider.notifier)
          .setHighContrastEnabled(enabled),
    );
  }

  Future<void> _setReduceMotion(bool enabled) async {
    await _savePreference(
      () => ref.read(appPreferencesProvider.notifier).setReduceMotion(enabled),
    );
  }

  Future<void> _savePreference(Future<void> Function() save) async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await save();
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = userMessageFor(error));
      }
    } on StateError catch (error) {
      if (mounted) {
        setState(() => _errorMessage = userMessageFor(error));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(appPreferencesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Erişilebilirlik ayarları')),
      body: preferences.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(userMessageFor(error)),
                TextButton(
                  onPressed: () => ref.invalidate(appPreferencesProvider),
                  child: const Text('Tekrar dene'),
                ),
              ],
            ),
          ),
        ),
        data: (value) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.text_fields),
                      title: Text(
                        'Metin boyutu',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      subtitle: const Text('Sistem metin büyütmesi korunur.'),
                    ),
                    SegmentedButton<AccessibilityTextSize>(
                      segments: const [
                        ButtonSegment(
                          value: AccessibilityTextSize.normal,
                          label: Text('Normal'),
                        ),
                        ButtonSegment(
                          value: AccessibilityTextSize.large,
                          label: Text('Büyük'),
                        ),
                        ButtonSegment(
                          value: AccessibilityTextSize.extraLarge,
                          label: Text('Daha büyük'),
                        ),
                      ],
                      selected: {value.accessibilityTextSize},
                      onSelectionChanged: _isSaving
                          ? null
                          : (selection) => _setTextSize(selection.single),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Yüksek karşıtlık'),
                      subtitle: const Text(
                        'Metin ve arka plan renkleri arasındaki farkı artırır.',
                      ),
                      value: value.highContrastEnabled,
                      onChanged: _isSaving ? null : _setHighContrast,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Hareketleri azalt'),
                      subtitle: const Text(
                        'Tema geçişlerini ve hareketli arayüz efektlerini azaltır.',
                      ),
                      value: value.reduceMotion,
                      onChanged: _isSaving ? null : _setReduceMotion,
                    ),
                  ],
                ),
              ),
            ),
            if (_isSaving) const LinearProgressIndicator(),
            if (_errorMessage case final message?) ...[
              const SizedBox(height: 8),
              Text(
                'Ayar kaydedilemedi: $message',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
