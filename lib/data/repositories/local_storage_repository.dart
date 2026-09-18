import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/target_item.dart';
import '../models/transaction_item.dart';

class LocalStorageRepository {
  static const String _targetsKey = 'jagacuan_targets_v2';

  Future<List<TargetItem>> getTargets() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_targetsKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    try {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList.map((item) => TargetItem.fromMap(item)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveTargets(List<TargetItem> targets) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = targets.map((t) => t.toMap()).toList();
    await prefs.setString(_targetsKey, json.encode(jsonList));
  }

  Future<void> addTarget(TargetItem target) async {
    final targets = await getTargets();
    targets.insert(0, target);
    await saveTargets(targets);
  }

  Future<void> updateTarget(TargetItem target) async {
    final targets = await getTargets();
    final index = targets.indexWhere((t) => t.id == target.id);
    if (index != -1) {
      targets[index] = target;
      await saveTargets(targets);
    }
  }

  Future<void> deleteTarget(String id) async {
    final targets = await getTargets();
    targets.removeWhere((t) => t.id == id);
    await saveTargets(targets);
  }

  Future<void> addTransaction(String targetId, double amount, bool isDeposit, String note) async {
    final targets = await getTargets();
    final index = targets.indexWhere((t) => t.id == targetId);
    if (index != -1) {
      final target = targets[index];
      final newTx = TransactionItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        amount: amount,
        isDeposit: isDeposit,
        note: note,
        timestamp: DateTime.now(),
      );

      final updatedCurrent = isDeposit
          ? target.currentAmount + amount
          : (target.currentAmount - amount < 0 ? 0.0 : target.currentAmount - amount);

      final updatedTxList = List<TransactionItem>.from(target.transactions)..insert(0, newTx);

      targets[index] = target.copyWith(
        currentAmount: updatedCurrent,
        transactions: updatedTxList,
      );

      await saveTargets(targets);
    }
  }

  Future<bool> hasPromptedInitialNotification() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('jagacuan_initial_notif_prompted') ?? (prefs.getBool('jagacuan_google_notif_prompted') ?? false);
  }

  Future<void> setPromptedInitialNotification() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('jagacuan_initial_notif_prompted', true);
  }

  Future<bool> hasPromptedGoogleNotification() async {
    return hasPromptedInitialNotification();
  }

  Future<void> setPromptedGoogleNotification() async {
    await setPromptedInitialNotification();
  }
}
