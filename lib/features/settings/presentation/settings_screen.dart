import 'package:material_ui/material_ui.dart';

import '../../auth/presentation/auth_screen.dart';
import 'accessibility_settings_screen.dart';
import 'app_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: const Text('Hesap ayarları'),
              subtitle: const Text(
                'Giriş, e-posta doğrulaması ve öğrenci rozeti',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openPage(context, const AuthScreen()),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('Uygulama ayarları'),
              subtitle: const Text('Görünüm ve tema'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openPage(context, const AppSettingsScreen()),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.accessibility_new),
              title: const Text('Erişilebilirlik ayarları'),
              subtitle: const Text('Metin boyutu, karşıtlık ve hareket'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  _openPage(context, const AccessibilitySettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  void _openPage(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}
