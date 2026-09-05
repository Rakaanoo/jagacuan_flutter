import 'dart:convert';

class TransactionItem {
  final String id;
  final double amount;
  final bool isDeposit; // true: Setor, false: Tarik
  final String note;
  final DateTime timestamp;

  TransactionItem({
    required this.id,
    required this.amount,
    required this.isDeposit,
    required this.note,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'isDeposit': isDeposit,
      'note': note,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory TransactionItem.fromMap(Map<String, dynamic> map) {
    return TransactionItem(
      id: map['id'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      isDeposit: map['isDeposit'] ?? true,
      note: map['note'] ?? '',
      timestamp: DateTime.parse(map['timestamp']),
    );
  }

  String toJson() => json.encode(toMap());

  factory TransactionItem.fromJson(String source) =>
      TransactionItem.fromMap(json.decode(source));
}
