import 'package:flutter_test/flutter_test.dart';
import 'package:jagacuan_app/data/repositories/supabase_nabar_repository.dart';
import 'package:jagacuan_app/ui/core/formatters.dart';

void main() {
  group('Nabar Invite Link & UUID Tests', () {
    const sampleUuid = 'f2ecfff8-a184-4d9a-b82b-696efe848256';

    test('formatTimeAgo formats minutes correctly across locales', () {
      final now = DateTime.now();
      final fiveMinAgo = now.subtract(const Duration(minutes: 5));
      expect(formatTimeAgo(fiveMinAgo, 'id'), equals('5 mnt lalu'));
      expect(formatTimeAgo(fiveMinAgo, 'it'), equals('5 min fa'));
      expect(formatTimeAgo(fiveMinAgo, 'en'), equals('5 min ago'));
      expect(formatTimeAgo(fiveMinAgo, 'de'), equals('vor 5 Min.'));
    });

    test('extractCodeFromInput extracts raw UUID', () {
      expect(extractCodeFromInput(sampleUuid), equals(sampleUuid));
    });

    test('extractCodeFromInput extracts from jagacuan://room/ URL', () {
      final url = 'jagacuan://room/$sampleUuid';
      expect(extractCodeFromInput(url), equals(sampleUuid));
    });

    test('extractCodeFromInput extracts from web URL', () {
      final url = 'https://jagacuan-app.vercel.app/room/$sampleUuid';
      expect(extractCodeFromInput(url), equals(sampleUuid));
    });

    test('extractCodeFromInput extracts UUID from entire WhatsApp invitation message', () {
      final message =
          '''
🎉 Yuk nabung bareng di Jagacuan!

Ruang: Liburan Bareng Keluarga
Target: Rp 15.000.000

Klik link berikut untuk bergabung:
jagacuan://room/$sampleUuid

(Jika link tidak bisa diklik di WhatsApp: Buka aplikasi Jagacuan > tekan [+] > pilih 'Gabung via Link Room' dan tempel pesan/link ini)
''';
      expect(extractCodeFromInput(message), equals(sampleUuid));
    });

    test('extractCodeFromInput extracts UUID from concise Ayo gabung invitation message', () {
      final message =
          '''
Ayo gabung ke grup Saya dan kita menabung bersama
https://jagacuan-app.vercel.app/room/$sampleUuid
''';
      expect(extractCodeFromInput(message), equals(sampleUuid));
    });

    test('generateUuidV4 generates valid RFC 4122 v4 UUID', () {
      final uuid = generateUuidV4();
      expect(uuid.length, equals(36));
      expect(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(uuid),
        isTrue,
      );
    });

    test('formatAmountOnly formats numeric inputs in Rupiah correctly', () {
      expect(formatAmountOnly(50000), equals('50.000'));
      expect(formatAmountOnly(1000), equals('1.000'));
      expect(formatAmountOnly(2500000), equals('2.500.000'));
    });
  });
}
