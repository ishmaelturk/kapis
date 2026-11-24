import 'package:material_ui/material_ui.dart';

class LegalInformationScreen extends StatelessWidget {
  const LegalInformationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gizlilik ve kullanım koşulları')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          Text(
            'Gizlilik bildirimi',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          Text(
            'Kapış, kişilerin kullanılabilir eşyaları ücretsiz ve elden '
            'teslimle paylaşmasına yardımcı olur. Hesap oluşturduğunda '
            'e-posta adresin Firebase Authentication tarafından; ilan, '
            'ayırtma ve teslim bilgilerin Firebase hizmetlerinde işlenir.',
          ),
          SizedBox(height: 12),
          Text(
            'İlanların yaklaşık konumu herkese açık olarak gösterilir. Kesin '
            'teslimat koordinatları ayrı ve erişimi kurallarla kısıtlanmış '
            'bir kayıtta tutulur; ilan sahibi ve etkin ayırtmayı yapan kişi '
            'tarafından görülebilir. Teslim doğrulaması için uygulama '
            'konumunu, yalnızca cihazdaki yakınlık kontrolünde kullanır.',
          ),
          SizedBox(height: 12),
          Text(
            'Yapay zekâ ile ilan önerisi istersen girdiğin başlık, açıklama '
            've seçtiğin fotoğraf Firebase AI Logic üzerinden Google yapay '
            'zekâ hizmetine gönderilir. Alıcı eşleştirmesi için ihtiyaç '
            'açıklaman ve en fazla 15 ilanın herkese açık metin alanları '
            'gönderilir. Kesin koordinatlar ve mahalle bilgisi bu isteklere '
            'eklenmez. Fotoğraflar yükleme öncesi yeniden kodlanarak EXIF '
            'konum bilgileri çıkarılır. Bu özelliği kullanmak isteğe bağlıdır.',
          ),
          SizedBox(height: 12),
          Text(
            'Hesap silme isteğini Hesap ayarları bölümünden başlatabilirsin. '
            'İlanların yayından kaldırılır ve etkin ayırtmaların serbest '
            'bırakılır. Güvenlik, yedekleme veya yasal yükümlülükler nedeniyle '
            'hizmet sağlayıcı kayıtlarının silinmesi zaman alabilir.',
          ),
          SizedBox(height: 24),
          Text(
            'Kullanım koşulları',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          Text(
            'Kapış bir ilan ve iletişim aracıdır; eşyanın mülkiyetini, '
            'durumunu veya teslimini garanti etmez. İlan sahibi eşya üzerinde '
            'paylaşma yetkisine sahip olmalı ve ilanı doğru bilgilerle '
            'hazırlamalıdır. Bağışlar ücretsizdir; uygulama içinden ödeme '
            'alınmaz. Teslimat, tarafların kararlaştırdığı yerde elden yapılır.',
          ),
          SizedBox(height: 12),
          Text(
            'Kişisel iletişim ve konum bilgilerini yalnızca gerekli kişilerle '
            'paylaş. Teslimat yerini ve zamanını dikkatle seç; şüpheli veya '
            'uygunsuz içerikleri bildir. Kuralları ihlal eden ilanlar '
            'kaldırılabilir veya hesap erişimi sınırlandırılabilir.',
          ),
          SizedBox(height: 24),
          Text(
            'Bu ekran genel bilgilendirme içindir; uygulamayı yayımlamadan '
            'önce KVKK ve tüketici hukuku bakımından uzman incelemesi ve '
            'iletişim/veri sorumlusu bilgilerinin eklenmesi gerekir.',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
