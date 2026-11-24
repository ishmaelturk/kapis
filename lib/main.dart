import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'application/local_database_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: KapisBootstrap()));
}

class KapisBootstrap extends ConsumerWidget {
  const KapisBootstrap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(localDatabaseProvider)
        .when(
          data: (_) => const KapisApp(),
          loading: () => const MaterialApp(
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          ),
          error: (error, _) => MaterialApp(
            home: Scaffold(
              appBar: AppBar(title: const Text('Başlangıç hatası')),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Yerel veritabanı açılamadı: $error'),
                      TextButton(
                        onPressed: () => ref.invalidate(localDatabaseProvider),
                        child: const Text('Tekrar dene'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
  }
}
