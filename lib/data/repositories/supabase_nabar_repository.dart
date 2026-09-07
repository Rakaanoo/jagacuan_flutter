import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/nabar_room.dart';

class SupabaseNabarRepository extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;
  bool _isSigningIn = false;

  bool get isSigningIn => _isSigningIn;
  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  SupabaseNabarRepository() {
    _client.auth.onAuthStateChange.listen((data) {
      notifyListeners();
    });
  }

  // Google Sign-In Native / Web OAuth for Flutter Mobile
  Future<User?> signInWithGoogle() async {
    if (_isSigningIn) return currentUser;
    _isSigningIn = true;
    notifyListeners();

    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.jagacuan://login-callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } finally {
      _isSigningIn = false;
      notifyListeners();
    }
    return _client.auth.currentUser;
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    notifyListeners();
  }

  Future<NabarRoom?> joinRoomByInviteCode(String inviteCode) async {
    final user = currentUser;
    if (user == null) throw Exception('Anda harus login terlebih dahulu.');

    final cleanCode = inviteCode.trim();
    if (cleanCode.isEmpty) throw Exception('Kode invite tidak boleh kosong.');

    final roomRes = await _client
        .from('rooms')
        .select('id')
        .or('invite_code.eq.$cleanCode,id.eq.$cleanCode')
        .maybeSingle();

    if (roomRes == null) throw Exception('Ruang / Kode Invite "$cleanCode" tidak ditemukan.');

    final roomId = roomRes['id'].toString();

    await _client.from('room_members').upsert({
      'room_id': roomId,
      'user_id': user.id,
      'role': 'member',
      'status': 'approved',
    }, onConflict: 'room_id, user_id');

    return getRoomById(roomId);
  }

  Future<String> createRoom({
    required String name,
    required double targetAmount,
    required DateTime targetDate,
    String? note,
    String? coverUrl,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('Anda harus login terlebih dahulu.');

    final response = await _client.from('rooms').insert({
      'name': name,
      'target_amount': targetAmount,
      'current_amount': 0,
      'target_date': targetDate.toIso8601String().split('T').first,
      'owner_id': user.id,
      'note': note,
      'cover_url': coverUrl,
    }).select().single();

    final roomId = response['id'].toString();

    // Automatically insert owner into room_members
    await _client.from('room_members').insert({
      'room_id': roomId,
      'user_id': user.id,
      'role': 'owner',
      'status': 'approved',
    });

    return roomId;
  }

  Future<NabarRoom?> getRoomById(String roomId) async {
    final user = currentUser;

    final roomRes = await _client.from('rooms').select().eq('id', roomId).maybeSingle();
    if (roomRes == null) return null;

    final membersRes = await _client.from('room_members').select('''
      id, user_id, role, status
    ''').eq('room_id', roomId);

    final txRes = await _client.from('room_transactions').select('''
      id, user_id, user_name, user_avatar, amount, is_deposit, note, created_at, status
    ''').eq('room_id', roomId).order('created_at', ascending: false);

    final List<NabarMember> members = [];
    final List<NabarMember> pendingMembers = [];
    String userStatus = 'non_member';

    for (var m in (membersRes as List)) {
      final member = NabarMember.fromMap(m);
      if (user != null && member.userId == user.id) {
        if (member.role == 'owner') {
          userStatus = 'owner';
        } else if (member.status == 'approved') {
          userStatus = 'approved_member';
        } else if (member.status == 'pending') {
          userStatus = 'pending_member';
        }
      }

      if (member.status == 'approved') {
        members.add(member);
      } else if (member.status == 'pending') {
        pendingMembers.add(member);
      }
    }

    final List<NabarActivity> activities = [];
    final List<NabarActivity> pendingActivities = [];

    for (var t in (txRes as List)) {
      final act = NabarActivity.fromMap(t);
      if (act.status == 'approved') {
        activities.add(act);
      } else if (act.status == 'pending') {
        pendingActivities.add(act);
      }
    }

    return NabarRoom(
      id: roomRes['id'].toString(),
      name: roomRes['name'] ?? '',
      targetAmount: (roomRes['target_amount'] ?? 0).toDouble(),
      currentAmount: (roomRes['current_amount'] ?? 0).toDouble(),
      targetDate: DateTime.parse(roomRes['target_date']),
      ownerId: roomRes['owner_id'] ?? '',
      note: roomRes['note'],
      coverUrl: roomRes['cover_url'],
      inviteCode: roomRes['invite_code'] ?? roomRes['id'].toString(),
      userStatus: userStatus,
      members: members,
      pendingMembers: pendingMembers,
      activities: activities,
      pendingActivities: pendingActivities,
    );
  }

  Future<String> addRoomTransaction({
    required String roomId,
    required double amount,
    required bool isDeposit,
    String? note,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('Anda harus login terlebih dahulu.');

    final room = await getRoomById(roomId);
    if (room == null) throw Exception('Room tidak ditemukan.');

    final isOwner = room.ownerId == user.id;
    final status = isOwner ? 'approved' : 'pending';

    final meta = user.userMetadata ?? {};
    final fullName = meta['full_name'] ?? meta['name'] ?? user.email?.split('@').first ?? 'Anggota';
    final avatar = meta['avatar_url'] ?? meta['picture'];

    await _client.from('room_transactions').insert({
      'room_id': roomId,
      'user_id': user.id,
      'user_name': fullName,
      'user_avatar': avatar,
      'amount': amount,
      'is_deposit': isDeposit,
      'note': note ?? 'Setoran tabungan',
      'status': status,
    });

    return status;
  }

  Future<void> approveRoomTransaction(String txId) async {
    await _client.from('room_transactions').update({'status': 'approved'}).eq('id', txId);
  }

  Future<void> rejectRoomTransaction(String txId) async {
    await _client.from('room_transactions').update({'status': 'rejected'}).eq('id', txId);
  }

  Future<void> approveMember(String roomId, String memberUserId) async {
    await _client
        .from('room_members')
        .update({'status': 'approved'})
        .eq('room_id', roomId)
        .eq('user_id', memberUserId);
  }

  Future<void> rejectMember(String roomId, String memberUserId) async {
    await _client
        .from('room_members')
        .update({'status': 'rejected'})
        .eq('room_id', roomId)
        .eq('user_id', memberUserId);
  }
}
