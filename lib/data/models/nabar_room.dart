class NabarMember {
  final String id;
  final String userId;
  final String name;
  final String status; // 'approved', 'pending', 'rejected'
  final String role;   // 'owner', 'member'
  final String? avatarUrl;
  final String avatarBg;

  NabarMember({
    required this.id,
    required this.userId,
    required this.name,
    required this.status,
    required this.role,
    this.avatarUrl,
    required this.avatarBg,
  });

  factory NabarMember.fromMap(Map<String, dynamic> map) {
    final meta = map['user_metadata'] as Map<String, dynamic>? ?? {};
    final fullName = meta['full_name'] ?? meta['name'] ?? map['email']?.split('@').first ?? 'Member';
    final avatar = meta['avatar_url'] ?? meta['picture'];

    return NabarMember(
      id: map['id']?.toString() ?? '',
      userId: map['user_id'] ?? '',
      name: fullName,
      status: map['status'] ?? 'pending',
      role: map['role'] ?? 'member',
      avatarUrl: avatar,
      avatarBg: '#7C8BFF',
    );
  }
}

class NabarActivity {
  final String id;
  final String userId;
  final String name;
  final double amount;
  final bool isDeposit;
  final String note;
  final DateTime timestamp;
  final String status; // 'pending', 'approved', 'rejected'
  final String? avatarUrl;

  NabarActivity({
    required this.id,
    required this.userId,
    required this.name,
    required this.amount,
    required this.isDeposit,
    required this.note,
    required this.timestamp,
    required this.status,
    this.avatarUrl,
  });

  factory NabarActivity.fromMap(Map<String, dynamic> map) {
    return NabarActivity(
      id: map['id']?.toString() ?? '',
      userId: map['user_id'] ?? '',
      name: map['user_name'] ?? 'Member',
      amount: (map['amount'] ?? 0).toDouble(),
      isDeposit: map['is_deposit'] ?? map['is_income'] ?? true,
      note: map['note'] ?? map['action_label'] ?? '',
      timestamp: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
      status: map['status'] ?? 'approved',
      avatarUrl: map['user_avatar'] ?? map['avatar_url'],
    );
  }
}

class NabarRoom {
  final String id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime targetDate;
  final String ownerId;
  final String? note;
  final String? coverUrl;
  final String inviteCode;
  final String userStatus; // 'owner', 'approved_member', 'pending_member', 'non_member'
  final List<NabarMember> members;
  final List<NabarMember> pendingMembers;
  final List<NabarActivity> activities;
  final List<NabarActivity> pendingActivities;

  NabarRoom({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    required this.targetDate,
    required this.ownerId,
    this.note,
    this.coverUrl,
    required this.inviteCode,
    required this.userStatus,
    required this.members,
    required this.pendingMembers,
    required this.activities,
    required this.pendingActivities,
  });

  double get progressPercentage {
    if (targetAmount <= 0) return 0;
    final pct = (currentAmount / targetAmount) * 100;
    return pct > 100 ? 100 : pct;
  }
}
