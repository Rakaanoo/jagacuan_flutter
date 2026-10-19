class NabarMember {
  final String id;
  final String userId;
  final String name;
  final String status; // 'approved', 'pending', 'rejected'
  final String role; // 'owner', 'member'
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

  factory NabarMember.fromMap(Map<String, dynamic> map, {String? roomOwnerId}) {
    final meta = map['user_metadata'] as Map<String, dynamic>? ?? {};
    final fullName =
        map['user_name'] ??
        map['name'] ??
        meta['full_name'] ??
        meta['name'] ??
        map['email']?.split('@').first ??
        'Member';
    final avatar =
        map['avatar_url'] ??
        map['user_avatar'] ??
        meta['avatar_url'] ??
        meta['picture'];
    final uId = map['user_id'] ?? '';
    final computedRole = (roomOwnerId != null && uId == roomOwnerId)
        ? 'owner'
        : (map['role'] ?? 'member');

    return NabarMember(
      id: map['id']?.toString() ?? '',
      userId: uId,
      name: fullName,
      status: map['status'] ?? 'pending',
      role: computedRole,
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
      timestamp: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
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
  final String
  userStatus; // 'owner', 'approved_member', 'pending_member', 'non_member'
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

  NabarRoom copyWith({
    String? id,
    String? name,
    double? targetAmount,
    double? currentAmount,
    DateTime? targetDate,
    String? ownerId,
    String? note,
    String? coverUrl,
    String? inviteCode,
    String? userStatus,
    List<NabarMember>? members,
    List<NabarMember>? pendingMembers,
    List<NabarActivity>? activities,
    List<NabarActivity>? pendingActivities,
  }) {
    return NabarRoom(
      id: id ?? this.id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      targetDate: targetDate ?? this.targetDate,
      ownerId: ownerId ?? this.ownerId,
      note: note ?? this.note,
      coverUrl: coverUrl ?? this.coverUrl,
      inviteCode: inviteCode ?? this.inviteCode,
      userStatus: userStatus ?? this.userStatus,
      members: members ?? this.members,
      pendingMembers: pendingMembers ?? this.pendingMembers,
      activities: activities ?? this.activities,
      pendingActivities: pendingActivities ?? this.pendingActivities,
    );
  }
}

class NabarRoomPreview {
  final String id;
  final String name;
  final double targetAmount;
  final DateTime targetDate;
  final String ownerName;
  final String? coverUrl;
  final String? note;
  final String
  userStatus; // 'owner', 'approved_member', 'pending_member', 'non_member'

  NabarRoomPreview({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.targetDate,
    required this.ownerName,
    this.coverUrl,
    this.note,
    required this.userStatus,
  });
}

class NabarMessage {
  final String id;
  final String roomId;
  final String userId;
  final String userName;
  final String? avatarUrl;
  final String message;
  final String messageType; // 'text', 'cheer', 'system'
  final DateTime createdAt;

  NabarMessage({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.userName,
    this.avatarUrl,
    required this.message,
    this.messageType = 'text',
    required this.createdAt,
  });

  factory NabarMessage.fromMap(Map<String, dynamic> map) {
    return NabarMessage(
      id: map['id']?.toString() ?? '',
      roomId: map['room_id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      userName: map['user_name'] ?? 'Member',
      avatarUrl: map['avatar_url'],
      message: map['message'] ?? '',
      messageType: map['message_type'] ?? 'text',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'room_id': roomId,
      'user_id': userId,
      'user_name': userName,
      'avatar_url': avatarUrl,
      'message': message,
      'message_type': messageType,
    };
  }
}
