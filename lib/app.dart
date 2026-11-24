import 'package:material_ui/material_ui.dart';

import 'features/auth/presentation/auth_screen.dart';
import 'features/listings/presentation/listing_discovery_screen.dart';
import 'features/listings/presentation/listing_form_screen.dart';
import 'features/listings/presentation/my_listings_screen.dart';

class KapisApp extends StatelessWidget {
  const KapisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kapış',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        useMaterial3: true,
      ),
      home: const _WelcomeScreen(),
    );
  }
}

class _WelcomeScreen extends StatelessWidget {
  const _WelcomeScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kapış')),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(
                        Icons.volunteer_activism_outlined,
                        color: Theme.of(context).colorScheme.primary,
                        size: 36,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Kapış',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Text('Ücretsiz eşya paylaşımı'),
                    ],
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text('Bağışları keşfet'),
                onTap: () =>
                    _openDrawerPage(context, const ListingDiscoveryScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('Eşya bağışla'),
                onTap: () =>
                    _openDrawerPage(context, const ListingFormScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: const Text('Bağışlarım'),
                onTap: () => _openDrawerPage(context, const MyListingsScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: const Text('Hesap / öğrenci rozeti'),
                onTap: () => _openDrawerPage(context, const AuthScreen()),
              ),
            ],
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.volunteer_activism_outlined,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  'Kullanılabilir eşyalar, yeni sahiplerini bekliyor.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  'Yakınındaki eşyaları keşfet, bağışını doğrudan teslim al.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () =>
                        _openPage(context, const ListingDiscoveryScreen()),
                    icon: const Icon(Icons.search),
                    label: const Text('Bağışları keşfet'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _openPage(context, const ListingFormScreen()),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Eşya bağışla'),
                  ),
                ),
                TextButton(
                  onPressed: () => _openPage(context, const MyListingsScreen()),
                  child: const Text('Bağışlarım'),
                ),
                TextButton(
                  onPressed: () => _openPage(context, const AuthScreen()),
                  child: const Text('Hesap / öğrenci rozeti'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openPage(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  void _openDrawerPage(BuildContext context, Widget page) {
    Navigator.of(context).pop();
    _openPage(context, page);
  }
}
