import 'package:flutter/material.dart';
import '../../../../data/models/target_item.dart';
import '../../../../data/repositories/local_storage_repository.dart';

enum SortOption { newest, highestProgress, closestDeadline }

class TargetListViewModel extends ChangeNotifier {
  final LocalStorageRepository _localRepo;

  TargetListViewModel(this._localRepo) {
    loadTargets();
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
    notifyListeners();
  }

  void setLanguage(String lang) {
    _language = lang;
    notifyListeners();
  }

  List<TargetItem> get filteredTargets {
    List<TargetItem> list = _targets.where((t) {
      final matchesTab = _activeTabIndex == 0 ? !t.isCompleted : t.isCompleted;
      final matchesSearch = t.title.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesTab && matchesSearch;
    }).toList();

    switch (_activeSort) {
      case SortOption.newest:
        list.sort((a, b) => b.startDate.compareTo(a.startDate));
        break;
      case SortOption.highestProgress:
        list.sort((a, b) => b.progressPercentage.compareTo(a.progressPercentage));
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
      _targets = await _localRepo.getTargets();
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

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  Future<void> addTarget(TargetItem target) async {
    await _localRepo.addTarget(target);
    await loadTargets();
  }

  Future<void> addQuickSetor(String targetId, double amount) async {
    await _localRepo.addTransaction(targetId, amount, true, 'Setoran cepat');
    await loadTargets();
  }

  Future<void> deleteTarget(String id) async {
    await _localRepo.deleteTarget(id);
    await loadTargets();
  }
}
