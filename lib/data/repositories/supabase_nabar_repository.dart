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

  // Google Sign-In Native / Web OAuth for Flutter
  Future<User?> signInWithGoogle() async {
    if (_isSigningIn) return currentUser;
    _isSigningIn = true;
    notifyListeners();

    try {
      // Use custom scheme deep link on Mobile, or null (current URL) on Web
      final redirectUrl = kIsWeb ? null : 'io.supabase.jagacuan://login-callback';
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
        authScreenLaunchMode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
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
        .eq('id', cleanCode)
        .maybeSingle();

    if (roomRes == null) throw Exception('Ruang Nabung dengan ID "$cleanCode" tidak ditemukan.');

    final roomId = roomRes['id'].toString();

    final meta = user.userMetadata ?? {};
    final fullName = meta['full_name'] ?? meta['name'] ?? user.email?.split('@').first ?? 'Member';
    final avatarUrl = meta['avatar_url'] ?? meta['picture'];

    await _client.from('room_members').upsert({
      'room_id': roomId,
      'user_id': user.id,
      'user_name': fullName,
      'avatar_url': avatarUrl,
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
      'title': name,
      'target_amount': targetAmount,
      'current_amount': 0,
      'deadline_date': targetDate.toIso8601String().split('T').first,
      'owner_id': user.id,
      'note': note,
      'cover_image': coverUrl,
    }).select().single();

    final roomId = response['id'].toString();

    final meta = user.userMetadata ?? {};
    final fullName = meta['full_name'] ?? meta['name'] ?? user.email?.split('@').first ?? 'Owner';
    final avatarUrl = meta['avatar_url'] ?? meta['picture'];

    // Automatically insert owner into room_members
    await _client.from('room_members').insert({
      'room_id': roomId,
      'user_id': user.id,
      'user_name': fullName,
      'avatar_url': avatarUrl,
      'status': 'approved',
    });

    return roomId;
  }

  Future<List<NabarRoom>> getUserRooms() async {
    final user = currentUser;
    if (user == null) return [];

    try {
      final memberRows = await _client
          .from('room_members')
          .select('room_id')
          .eq('user_id', user.id);

      final List<String> memberRoomIds = (memberRows as List)
          .map((r) => r['room_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      late final List roomsRes;
      if (memberRoomIds.isNotEmpty) {
        final idsStr = memberRoomIds.join(',');
        roomsRes = await _client
            .from('rooms')
            .select()
            .or('owner_id.eq.${user.id},id.in.($idsStr)')
            .order('created_at', ascending: false);
      } else {
        roomsRes = await _client
            .from('rooms')
            .select()
            .eq('owner_id', user.id)
            .order('created_at', ascending: false);
      }

      final List<NabarRoom> rooms = [];
      for (var r in (roomsRes as List)) {
        final roomId = r['id'].toString();
        final detailed = await getRoomById(roomId);
        if (detailed != null) rooms.add(detailed);
      }
      return rooms;
    } catch (e) {
      debugPrint('Error getting user rooms: $e');
      return [];
    }
  }

  Future<NabarRoom?> getRoomById(String roomId) async {
    if (roomId.isEmpty || roomId == 'demo_room') return null;
    final user = currentUser;

    try {
      final roomRes = await _client.from('rooms').select().eq('id', roomId).maybeSingle();
      if (roomRes == null) return null;

      final ownerId = roomRes['owner_id']?.toString() ?? '';

      final membersRes = await _client.from('room_members').select('''
        id, user_id, status, user_name, avatar_url
      ''').eq('room_id', roomId);

      final txRes = await _client.from('room_transactions').select('''
        id, user_id, user_name, avatar_url, amount, is_income, action_label, created_at, status
      ''').eq('room_id', roomId).order('created_at', ascending: false);

      final List<NabarMember> members = [];
      final List<NabarMember> pendingMembers = [];
      String userStatus = 'non_member';

      for (var m in (membersRes as List)) {
        final member = NabarMember.fromMap(m, roomOwnerId: ownerId);
        if (user != null && member.userId == user.id) {
          if (ownerId == user.id) {
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

      final dateStr = roomRes['deadline_date'] ?? roomRes['start_date'];
      final parsedDate = dateStr != null ? DateTime.tryParse(dateStr.toString()) ?? DateTime.now() : DateTime.now();

      return NabarRoom(
        id: roomRes['id'].toString(),
        name: roomRes['title'] ?? 'Ruang Nabung',
        targetAmount: (roomRes['target_amount'] ?? 0).toDouble(),
        currentAmount: (roomRes['current_amount'] ?? 0).toDouble(),
        targetDate: parsedDate,
        ownerId: ownerId,
        note: roomRes['note'],
        coverUrl: roomRes['cover_image'],
        inviteCode: roomRes['id'].toString(),
        userStatus: userStatus,
        members: members,
        pendingMembers: pendingMembers,
        activities: activities,
        pendingActivities: pendingActivities,
      );
    } catch (e) {
      debugPrint('Error fetching room by ID ($roomId): $e');
      return null;
    }
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
      'avatar_url': avatar,
      'amount': amount,
      'is_income': isDeposit,
      'action_label': note ?? 'Setoran tabungan',
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
