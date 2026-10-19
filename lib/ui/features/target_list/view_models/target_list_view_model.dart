import 'package:flutter/material.dart';

import '../../../../data/models/target_item.dart';
import '../../../../data/models/nabar_room.dart';
import '../../../../data/repositories/local_storage_repository.dart';

enum SortOption { newest, highestProgress, closestDeadline }

class TargetListViewModel extends ChangeNotifier {
  final LocalStorageRepository localRepo;

  TargetListViewModel({required this.localRepo}) {
    loadTargets();
    _initSettings();
  }

  Future<void> _initSettings() async {
    final savedLang = await localRepo.getSavedLanguage();
    if (savedLang != null && savedLang.isNotEmpty) {
      _language = savedLang;
    }
    final savedCurr = await localRepo.getSavedCurrency();
    if (savedCurr != null && savedCurr.isNotEmpty) {
      _currency = savedCurr;
    }
    final savedDark = await localRepo.getSavedDarkMode();
    if (savedDark != null) {
      _isDarkMode = savedDark;
    }
    notifyListeners();
  }

  List<TargetItem> _targets = [];
  bool _isLoading = false;
  String _searchQuery = '';
  SortOption _activeSort = SortOption.newest;
  int _activeTabIndex = 0; // 0: Berjalan, 1: Selesai
  bool _isDarkMode = true;
  String _currency = 'IDR';
  String _language = 'id';

  List<TargetItem> get targets => _targets;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  SortOption get activeSort => _activeSort;
  int get activeTabIndex => _activeTabIndex;
  bool get isDarkMode => _isDarkMode;
  String get currency => _currency;
  String get language => _language;

  void setCurrency(String cur) {
    _currency = cur;
    localRepo.saveCurrency(cur);
    notifyListeners();
  }

  void setLanguage(String lang) {
    _language = lang;
    localRepo.saveLanguage(lang);
    notifyListeners();
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    localRepo.saveDarkMode(_isDarkMode);
    notifyListeners();
  }

  List<TargetItem> get filteredTargets {
    List<TargetItem> list = _targets.where((t) {
      final isFinished = t.isCompleted || t.isArchived;
      final matchesTab = _activeTabIndex == 0 ? !isFinished : isFinished;
      final matchesSearch = t.title.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      return matchesTab && matchesSearch;
    }).toList();

    switch (_activeSort) {
      case SortOption.newest:
        list.sort((a, b) => b.startDate.compareTo(a.startDate));
        break;
      case SortOption.highestProgress:
        list.sort(
          (a, b) => b.progressPercentage.compareTo(a.progressPercentage),
        );
        break;
      case SortOption.closestDeadline:
        list.sort((a, b) => a.endDate.compareTo(b.endDate));
        break;
    }
    return list;
  }

  Future<void> loadTargets() async {
    _isLoading = true;
    notifyListeners();
    try {
      _targets = await localRepo.getTargets();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSortOption(SortOption option) {
    _activeSort = option;
    notifyListeners();
  }

  void setTabIndex(int index) {
    _activeTabIndex = index;
    notifyListeners();
  }

  Future<void> addTarget(TargetItem target) async {
    await localRepo.addTarget(target);
    await loadTargets();
  }

  Future<void> updateTarget(TargetItem target) async {
    await localRepo.updateTarget(target);
    await loadTargets();
  }

  Future<void> addTransaction(
    String targetId,
    double amount, {
    required bool isDeposit,
    String? note,
  }) async {
    final defaultNote = isDeposit ? 'Setoran tabungan' : 'Penarikan tabungan';
    await localRepo.addTransaction(
      targetId,
      amount,
      isDeposit,
      (note != null && note.trim().isNotEmpty) ? note.trim() : defaultNote,
    );
    await loadTargets();
  }

  Future<void> addQuickSetor(String targetId, double amount) async {
    await addTransaction(
      targetId,
      amount,
      isDeposit: true,
      note: 'Setoran cepat',
    );
  }

  Future<void> deleteTarget(String id, {dynamic supabaseRepo}) async {
    final target = _targets.cast<TargetItem?>().firstWhere(
      (t) => t?.id == id,
      orElse: () => null,
    );

    if (target != null &&
        target.type == TargetType.nabar &&
        supabaseRepo != null) {
      final roomId = target.roomId ?? target.id;
      try {
        await supabaseRepo.deleteRoom(roomId);
      } catch (e) {
        debugPrint('Error deleting remote Nabar room: $e');
      }
    }

    await localRepo.deleteTarget(id);
    await loadTargets();
  }

  Future<void> updateTargetAlarm(
    String id, {
    required bool alarmEnabled,
    required int alarmHour,
    required int alarmMinute,
    required String alarmDayKey,
  }) async {
    final idx = _targets.indexWhere((t) => t.id == id);
    if (idx != -1) {
      final updated = _targets[idx].copyWith(
        alarmEnabled: alarmEnabled,
        alarmHour: alarmHour,
        alarmMinute: alarmMinute,
        alarmDayKey: alarmDayKey,
      );
      await localRepo.updateTarget(updated);
      await loadTargets();
    }
  }

  Future<void> toggleArchiveTarget(String id) async {
    final idx = _targets.indexWhere((t) => t.id == id);
    if (idx != -1) {
      final updated = _targets[idx].copyWith(
        isArchived: !_targets[idx].isArchived,
      );
      _targets[idx] = updated;
      await localRepo.updateTarget(updated);
      await loadTargets();
    }
  }

  Future<void> syncNabarRooms(dynamic supabaseRepo) async {
    if (supabaseRepo == null) return;
    try {
      bool hasChanges = false;

      // 1. Sinkronisasi target lokal bertipe Nabar dengan data Supabase terbaru
      for (int i = 0; i < _targets.length; i++) {
        final t = _targets[i];
        if (t.type == TargetType.nabar) {
          final roomId = t.roomId ?? t.id;
          final NabarRoom? room = await supabaseRepo.getRoomById(roomId);
          if (room != null) {
            final updated = t.copyWith(
              currentAmount: room.currentAmount,
              targetAmount: room.targetAmount,
              title: room.name,
              coverUrl: room.coverUrl ?? t.coverUrl,
            );
            if (updated.currentAmount != t.currentAmount ||
                updated.targetAmount != t.targetAmount ||
                updated.title != t.title ||
                updated.coverUrl != t.coverUrl) {
              _targets[i] = updated;
              await localRepo.updateTarget(updated);
              hasChanges = true;
            }
          }
        }
      }

      // 2. Jika user terautentikasi, periksa seluruh ruangan pengguna di Supabase
      if (supabaseRepo.currentUser != null) {
        final List<NabarRoom> userRooms = await supabaseRepo.getUserRooms();
        for (final room in userRooms) {
          final existingIdx = _targets.indexWhere(
            (t) => t.id == room.id || t.roomId == room.id,
          );
          if (existingIdx != -1) {
            final t = _targets[existingIdx];
            final updated = t.copyWith(
              currentAmount: room.currentAmount,
              targetAmount: room.targetAmount,
              title: room.name,
              coverUrl: room.coverUrl ?? t.coverUrl,
            );
            if (updated.currentAmount != t.currentAmount ||
                updated.targetAmount != t.targetAmount ||
                updated.title != t.title ||
                updated.coverUrl != t.coverUrl) {
              _targets[existingIdx] = updated;
              await localRepo.updateTarget(updated);
              hasChanges = true;
            }
          } else {
            final newTarget = TargetItem(
              id: room.id,
              title: room.name,
              targetAmount: room.targetAmount,
              currentAmount: room.currentAmount,
              startDate: DateTime.now(),
              endDate: room.targetDate,
              note: room.note,
              coverUrl: room.coverUrl,
              type: TargetType.nabar,
              roomId: room.id,
            );
            _targets.insert(0, newTarget);
            await localRepo.addTarget(newTarget);
            hasChanges = true;
          }
        }
      }

      if (hasChanges) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error syncing Nabar rooms in ViewModel: $e');
    }
  }
}
