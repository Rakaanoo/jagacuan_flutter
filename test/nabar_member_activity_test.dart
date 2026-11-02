import 'package:flutter_test/flutter_test.dart';
import 'package:jagacuan_app/data/models/nabar_room.dart';

void main() {
  group('Nabar Member Activity Chart Logic Tests', () {
    test('Calculates deposit counts and sorts members from least to most active', () {
      final members = [
        NabarMember(
          id: '1',
          userId: 'user_active',
          name: 'Budi Aktif',
          status: 'approved',
          role: 'member',
          avatarBg: '#7C8BFF',
        ),
        NabarMember(
          id: '2',
          userId: 'user_zero',
          name: 'Siti Belum Setor',
          status: 'approved',
          role: 'member',
          avatarBg: '#7C8BFF',
        ),
        NabarMember(
          id: '3',
          userId: 'user_host',
          name: 'Andi Host',
          status: 'approved',
          role: 'owner',
          avatarBg: '#7C8BFF',
        ),
      ];

      final activities = [
        // Budi has 3 deposits
        NabarActivity(
          id: 'tx1',
          userId: 'user_active',
          name: 'Budi Aktif',
          amount: 50000,
          isDeposit: true,
          note: 'Setor 1',
          timestamp: DateTime(2026, 11, 1),
          status: 'approved',
        ),
        NabarActivity(
          id: 'tx2',
          userId: 'user_active',
          name: 'Budi Aktif',
          amount: 50000,
          isDeposit: true,
          note: 'Setor 2',
          timestamp: DateTime(2026, 11, 2),
          status: 'approved',
        ),
        NabarActivity(
          id: 'tx3',
          userId: 'user_active',
          name: 'Budi Aktif',
          amount: 25000,
          isDeposit: true,
          note: 'Setor 3',
          timestamp: DateTime(2026, 11, 3),
          status: 'approved',
        ),
        // Andi Host has 1 deposit
        NabarActivity(
          id: 'tx4',
          userId: 'user_host',
          name: 'Andi Host',
          amount: 100000,
          isDeposit: true,
          note: 'Setor Host',
          timestamp: DateTime(2026, 11, 2),
          status: 'approved',
        ),
        // Siti has 0 deposits (or only unapproved/withdrawn)
        NabarActivity(
          id: 'tx5',
          userId: 'user_zero',
          name: 'Siti Belum Setor',
          amount: 50000,
          isDeposit: true,
          note: 'Setor Pending',
          timestamp: DateTime(2026, 11, 2),
          status: 'pending', // Pending does not count as active
        ),
      ];

      // Calculation
      final memberStats = members.map((mem) {
        final approvedDeposits = activities
            .where((a) => a.userId == mem.userId && a.isDeposit && a.status == 'approved')
            .toList();
        final count = approvedDeposits.length;
        final total = approvedDeposits.fold<double>(0.0, (s, a) => s + a.amount);
        return {
          'member': mem,
          'count': count,
          'total': total,
        };
      }).toList();

      // Sort: least to most active
      memberStats.sort((a, b) {
        final countA = a['count'] as int;
        final countB = b['count'] as int;
        if (countA != countB) return countA.compareTo(countB);
        final totalA = a['total'] as double;
        final totalB = b['total'] as double;
        return totalA.compareTo(totalB);
      });

      // Verify Order: Siti (0x) -> Andi (1x) -> Budi (3x)
      expect((memberStats[0]['member'] as NabarMember).userId, 'user_zero');
      expect(memberStats[0]['count'], 0);
      expect(memberStats[0]['total'], 0.0);

      expect((memberStats[1]['member'] as NabarMember).userId, 'user_host');
      expect(memberStats[1]['count'], 1);
      expect(memberStats[1]['total'], 100000.0);

      expect((memberStats[2]['member'] as NabarMember).userId, 'user_active');
      expect(memberStats[2]['count'], 3);
      expect(memberStats[2]['total'], 125000.0);
    });
  });
}
