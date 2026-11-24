import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../application/app_preferences_controller.dart';
import '../../../application/user_error_message.dart';
import '../../../domain/models/app_preferences.dart';

class AppSettingsScreen extends ConsumerStatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  ConsumerState<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends ConsumerState<AppSettingsScreen> {
  bool _isSaving = false;
  String? _errorMessage;

  Future<void> _setThemeMode(AppThemeMode themeMode) async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await ref.read(appPreferencesProvider.notifier).setThemeMode(themeMode);
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
      appBar: AppBar(title: const Text('Uygulama ayarları')),
      body: preferences.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _SettingsLoadError(
          message: userMessageFor(error),
          onRetry: () => ref.invalidate(appPreferencesProvider),
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
                      leading: const Icon(Icons.palette_outlined),
                      title: Text(
                        'Görünüm',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      subtitle: const Text('Sistem, açık veya koyu tema'),
                    ),
                    SegmentedButton<AppThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: AppThemeMode.system,
                          label: Text('Sistem'),
                          icon: Icon(Icons.brightness_auto_outlined),
                        ),
                        ButtonSegment(
                          value: AppThemeMode.light,
                          label: Text('Açık'),
                          icon: Icon(Icons.light_mode_outlined),
                        ),
                        ButtonSegment(
                          value: AppThemeMode.dark,
                          label: Text('Koyu'),
                          icon: Icon(Icons.dark_mode_outlined),
                        ),
                      ],
                      selected: {value.themeMode},
                      onSelectionChanged: _isSaving
                          ? null
                          : (selection) => _setThemeMode(selection.single),
                    ),
                  ],
                ),
              ),
            ),
            if (_isSaving) const LinearProgressIndicator(),
            if (_errorMessage case final message?) ...[
              const SizedBox(height: 8),
              _SettingsSaveError(message: message),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsLoadError extends StatelessWidget {
  const _SettingsLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Ayarlar yüklenemedi: $message'),
            TextButton(onPressed: onRetry, child: const Text('Tekrar dene')),
          ],
        ),
      ),
    );
  }
}

class _SettingsSaveError extends StatelessWidget {
  const _SettingsSaveError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Ayar kaydedilemedi: $message',
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    );
  }
}
