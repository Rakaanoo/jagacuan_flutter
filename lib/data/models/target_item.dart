import 'dart:convert';
import 'transaction_item.dart';

enum TargetType {
  target,   // Tabungan Target
  berkala,  // Tabungan Berkala
  nabar,    // Nabung Bareng
}

enum TargetFrequency {
  harian,
  mingguan,
  bulanan,
}

class TargetItem {
  final String id;
  final String title;
  final double targetAmount;
  final double currentAmount;
  final DateTime startDate;
  final DateTime endDate;
  final String? note;
  final TargetType type;
  final TargetFrequency? frequency;
  final double? targetNominalPerPeriod;
  final String? coverUrl;
  final String? roomId; // ID Ruang Supabase jika type == nabar
  final List<TransactionItem> transactions;
  final bool alarmEnabled;
  final int alarmHour;
  final int alarmMinute;
  final String alarmDayKey;

  TargetItem({
    required this.id,
    required this.title,
    required this.targetAmount,
    this.currentAmount = 0,
    required this.startDate,
    required this.endDate,
    this.note,
    this.type = TargetType.target,
    this.frequency,
    this.targetNominalPerPeriod,
    this.coverUrl,
    this.roomId,
    this.transactions = const [],
    this.alarmEnabled = false,
    this.alarmHour = 12,
    this.alarmMinute = 0,
    this.alarmDayKey = 'alarm.day_everyday',
  });

  double get progressPercentage {
    if (targetAmount <= 0) return 0;
    final pct = (currentAmount / targetAmount) * 100;
    return pct > 100 ? 100 : pct;
  }

  bool get isCompleted => currentAmount >= targetAmount;

  int get remainingDays {
    final now = DateTime.now();
    final diff = endDate.difference(DateTime(now.year, now.month, now.day)).inDays;
    return diff < 0 ? 0 : diff;
  }

  TargetItem copyWith({
    String? id,
    String? title,
    double? targetAmount,
    double? currentAmount,
    DateTime? startDate,
    DateTime? endDate,
    String? note,
    TargetType? type,
    TargetFrequency? frequency,
    double? targetNominalPerPeriod,
    String? coverUrl,
    String? roomId,
    List<TransactionItem>? transactions,
    bool? alarmEnabled,
    int? alarmHour,
    int? alarmMinute,
    String? alarmDayKey,
  }) {
    return TargetItem(
      id: id ?? this.id,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      note: note ?? this.note,
      type: type ?? this.type,
      frequency: frequency ?? this.frequency,
      targetNominalPerPeriod: targetNominalPerPeriod ?? this.targetNominalPerPeriod,
      coverUrl: coverUrl ?? this.coverUrl,
      roomId: roomId ?? this.roomId,
      transactions: transactions ?? this.transactions,
      alarmEnabled: alarmEnabled ?? this.alarmEnabled,
      alarmHour: alarmHour ?? this.alarmHour,
      alarmMinute: alarmMinute ?? this.alarmMinute,
      alarmDayKey: alarmDayKey ?? this.alarmDayKey,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'note': note,
      'type': type.name,
      'frequency': frequency?.name,
      'targetNominalPerPeriod': targetNominalPerPeriod,
      'coverUrl': coverUrl,
      'roomId': roomId,
      'transactions': transactions.map((t) => t.toMap()).toList(),
      'alarmEnabled': alarmEnabled,
      'alarmHour': alarmHour,
      'alarmMinute': alarmMinute,
      'alarmDayKey': alarmDayKey,
    };
  }

  factory TargetItem.fromMap(Map<String, dynamic> map) {
    return TargetItem(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      targetAmount: (map['targetAmount'] ?? 0).toDouble(),
      currentAmount: (map['currentAmount'] ?? 0).toDouble(),
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
      note: map['note'],
      type: TargetType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TargetType.target,
      ),
      frequency: map['frequency'] != null
          ? TargetFrequency.values.firstWhere(
              (e) => e.name == map['frequency'],
              orElse: () => TargetFrequency.harian,
            )
          : null,
      targetNominalPerPeriod: map['targetNominalPerPeriod'] != null
          ? (map['targetNominalPerPeriod'] as num).toDouble()
          : null,
      coverUrl: map['coverUrl'],
      roomId: map['roomId'],
      transactions: map['transactions'] != null
          ? (map['transactions'] as List)
              .map((t) => TransactionItem.fromMap(t))
              .toList()
          : [],
      alarmEnabled: map['alarmEnabled'] ?? false,
      alarmHour: map['alarmHour'] ?? 12,
      alarmMinute: map['alarmMinute'] ?? 0,
      alarmDayKey: map['alarmDayKey'] ?? 'alarm.day_everyday',
    );
  }

  String toJson() => json.encode(toMap());

  factory TargetItem.fromJson(String source) =>
      TargetItem.fromMap(json.decode(source));
}
