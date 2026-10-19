import 'package:flutter_test/flutter_test.dart';
import 'package:jagacuan_app/data/models/nabar_room.dart';
import 'package:jagacuan_app/data/models/target_item.dart';
import 'package:jagacuan_app/data/repositories/local_storage_repository.dart';
import 'package:jagacuan_app/ui/features/target_list/view_models/target_list_view_model.dart';

class FakeLocalStorageRepository extends LocalStorageRepository {
  final List<TargetItem> _storage = [];

  @override
  Future<List<TargetItem>> getTargets() async => List.from(_storage);

  @override
  Future<void> addTarget(TargetItem target) async {
    _storage.insert(0, target);
  }

  @override
  Future<void> updateTarget(TargetItem target) async {
    final idx = _storage.indexWhere((t) => t.id == target.id);
    if (idx != -1) {
      _storage[idx] = target;
    }
  }

  @override
  Future<String?> getSavedLanguage() async => 'id';

  @override
  Future<String?> getSavedCurrency() async => 'IDR';

  @override
  Future<bool?> getSavedDarkMode() async => true;
}

class FakeSupabaseNabarRepository {
  final Map<String, NabarRoom> rooms = {};
  dynamic currentUser;

  Future<NabarRoom?> getRoomById(String roomId) async => rooms[roomId];

  Future<List<NabarRoom>> getUserRooms() async => rooms.values.toList();
}

void main() {
  group('Target Completion and Synchronization Tests', () {
    test('TargetItem.isCompleted behaves accurately with amounts', () {
      final activeTarget = TargetItem(
        id: '1',
        title: 'Nabung Mobil',
        targetAmount: 80000000,
        currentAmount: 0,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 30)),
        type: TargetType.nabar,
      );
      expect(activeTarget.isCompleted, isFalse);
      expect(activeTarget.progressPercentage, equals(0));

      final completedTarget = activeTarget.copyWith(currentAmount: 80000000);
      expect(completedTarget.isCompleted, isTrue);
      expect(completedTarget.progressPercentage, equals(100));

      final overCompletedTarget = activeTarget.copyWith(currentAmount: 699999999);
      expect(overCompletedTarget.isCompleted, isTrue);
      expect(overCompletedTarget.progressPercentage, equals(100));
    });

    test('TargetListViewModel filters completed targets into tab 1 (Selesai)', () async {
      final fakeRepo = FakeLocalStorageRepository();
      final vm = TargetListViewModel(localRepo: fakeRepo);

      final nabarTarget = TargetItem(
        id: 'room-123',
        roomId: 'room-123',
        title: 'Nabar Liburan',
        targetAmount: 50000000,
        currentAmount: 0,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 30)),
        type: TargetType.nabar,
      );

      await vm.addTarget(nabarTarget);

      // Initially active (Tab 0)
      vm.setTabIndex(0);
      expect(vm.filteredTargets.length, equals(1));
      expect(vm.filteredTargets.first.id, equals('room-123'));

      // Tab 1 (Selesai) should be empty
      vm.setTabIndex(1);
      expect(vm.filteredTargets.isEmpty, isTrue);

      // Now sync with Supabase where savings reached Rp 50.000.000 (100%)
      final fakeSupabase = FakeSupabaseNabarRepository();
      fakeSupabase.rooms['room-123'] = NabarRoom(
        id: 'room-123',
        name: 'Nabar Liburan',
        targetAmount: 50000000,
        currentAmount: 50000000,
        targetDate: DateTime.now().add(const Duration(days: 30)),
        ownerId: 'user-1',
        inviteCode: 'room-123',
        userStatus: 'owner',
        members: [],
        pendingMembers: [],
        activities: [],
        pendingActivities: [],
      );

      await vm.syncNabarRooms(fakeSupabase);

      // Should now automatically disappear from Tab 0 (Berjalan)
      vm.setTabIndex(0);
      expect(vm.filteredTargets.isEmpty, isTrue);

      // And appear in Tab 1 (Selesai) with 100% progress
      vm.setTabIndex(1);
      expect(vm.filteredTargets.length, equals(1));
      expect(vm.filteredTargets.first.currentAmount, equals(50000000));
      expect(vm.filteredTargets.first.isCompleted, isTrue);
      expect(vm.filteredTargets.first.progressPercentage, equals(100));
    });

    test('Creating a dummy target and archiving it moves it between Berjalan and Selesai', () async {
      final fakeRepo = FakeLocalStorageRepository();
      final vm = TargetListViewModel(localRepo: fakeRepo);
      await vm.loadTargets();

      // 1. Buat tabungan dummy yang belum selesai (0%)
      final dummyTarget = TargetItem(
        id: 'dummy-1',
        title: 'Tabungan Dummy Arsip',
        targetAmount: 100000,
        currentAmount: 0,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 10)),
        type: TargetType.target,
      );

      await vm.addTarget(dummyTarget);

      // Verifikasi di Tab 0 (Berjalan)
      vm.setTabIndex(0);
      expect(vm.filteredTargets.any((t) => t.id == 'dummy-1'), isTrue);
      expect(vm.filteredTargets.firstWhere((t) => t.id == 'dummy-1').isArchived, isFalse);

      // Verifikasi di Tab 1 (Selesai) belum ada
      vm.setTabIndex(1);
      expect(vm.filteredTargets.any((t) => t.id == 'dummy-1'), isFalse);

      // 2. Arsipkan target dummy ini
      await vm.toggleArchiveTarget('dummy-1');

      // Verifikasi sekarang HILANG dari Tab 0 (Berjalan)
      vm.setTabIndex(0);
      expect(vm.filteredTargets.any((t) => t.id == 'dummy-1'), isFalse);

      // Dan MUNCUL di Tab 1 (Selesai/Arsip) dengan status isArchived == true
      vm.setTabIndex(1);
      expect(vm.filteredTargets.any((t) => t.id == 'dummy-1'), isTrue);
      final archivedTarget = vm.filteredTargets.firstWhere((t) => t.id == 'dummy-1');
      expect(archivedTarget.isArchived, isTrue);

      // 3. Batalkan arsip (Unarchive)
      await vm.toggleArchiveTarget('dummy-1');

      // Verifikasi kembali lagi ke Tab 0 (Berjalan)
      vm.setTabIndex(0);
      expect(vm.filteredTargets.any((t) => t.id == 'dummy-1'), isTrue);
      expect(vm.filteredTargets.firstWhere((t) => t.id == 'dummy-1').isArchived, isFalse);
    });
  });
}
