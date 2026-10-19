import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/nabar_room.dart';

String generateUuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
}

String parseInviteCode(String input) {
  final clean = input.trim();
  // 1. Search for standard 36-char UUID format
  final uuidMatch = RegExp(
    r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
  ).firstMatch(clean);
  if (uuidMatch != null) {
    return uuidMatch.group(0)!;
  }

  // 2. Search for jagacuan://room/<id> or /room/<id>
  final roomUrlMatch = RegExp(r'(?:jagacuan:\/\/room\/|\/room\/)([^\s\/?#]+)')
      .firstMatch(clean);
  if (roomUrlMatch != null) {
    return roomUrlMatch.group(1)!.trim();
  }

  // 3. Fallback: if it's already a single clean string/code
  if (clean.contains('://')) {
    final uri = Uri.tryParse(clean);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last.trim();
    }
  }
  return clean.replaceAll('/', '').trim();
}

String extractCodeFromInput(String input) => parseInviteCode(input);

class SupabaseNabarRepository extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;
  bool _isSigningIn = false;

  bool get isSigningIn => _isSigningIn;
  User? get currentUser => _client.auth.currentUser;

  String extractCodeFromInput(String input) => parseInviteCode(input);

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  SupabaseNabarRepository() {
    _client.auth.onAuthStateChange.listen((data) {
      notifyListeners();
    });
  }

  /// Mengembalikan full permanent public URL untuk cover image.
  /// Mendukung format full URL, nama file di storage, ataupun file lokal.
  String? resolveCoverUrl(String? coverImage) {
    if (coverImage == null || coverImage.trim().isEmpty) return null;
    final trimmed = coverImage.trim();

    // 1. Sudah berupa URL HTTP/HTTPS lengkap
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    // 2. Jika merupakan nama file/path di Supabase Storage (tidak diawali /)
    if (!trimmed.startsWith('/')) {
      return _client.storage.from('room-covers').getPublicUrl(trimmed);
    }

    // 3. Jika tersimpan sebagai path lokal hp (karena upload lama gagal),
    // cek apakah file fisik masih ada di perangkat ini
    try {
      final file = File(trimmed);
      if (file.existsSync()) return trimmed;
    } catch (_) {}
    return null;
  }

  Future<String?> _getSignedCoverUrl(String? coverImage) async {
    return resolveCoverUrl(coverImage);
  }

  // Google Sign-In Native / Web OAuth for Flutter
  Future<User?> signInWithGoogle() async {
    if (_isSigningIn) return currentUser;
    _isSigningIn = true;
    notifyListeners();

    try {
      final redirectUrl = kIsWeb
          ? null
          : 'io.supabase.jagacuan://login-callback';
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
        authScreenLaunchMode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      rethrow;
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

  Future<NabarRoomPreview?> getRoomPreview(String inviteInput) async {
    final cleanCode = extractCodeFromInput(inviteInput);
    if (cleanCode.isEmpty) return null;

    var roomRes = await _client
        .from('rooms')
        .select()
        .eq('id', cleanCode)
        .maybeSingle();

    if (roomRes == null) {
      final list = await _client
          .from('rooms')
          .select()
          .ilike('id', '${cleanCode.toLowerCase()}%')
          .limit(1);
      if (list.isNotEmpty) {
        roomRes = list.first;
      }
    }

    if (roomRes == null) return null;

    final roomId = roomRes['id'].toString();
    final ownerId = roomRes['owner_id']?.toString() ?? '';

    // Fetch owner name
    String ownerName = 'Host';
    try {
      final ownerMemberRes = await _client
          .from('room_members')
          .select('user_name')
          .eq('room_id', roomId)
          .eq('user_id', ownerId)
          .maybeSingle();
      if (ownerMemberRes != null && ownerMemberRes['user_name'] != null) {
        ownerName = ownerMemberRes['user_name'].toString();
      }
    } catch (_) {}

    String userStatus = 'non_member';
    final user = currentUser;
    if (user != null) {
      if (user.id == ownerId) {
        userStatus = 'owner';
      } else {
        try {
          final myMemberRes = await _client
              .from('room_members')
              .select('status')
              .eq('room_id', roomId)
              .eq('user_id', user.id)
              .maybeSingle();
          if (myMemberRes != null) {
            final st = myMemberRes['status']?.toString();
            if (st == 'approved') {
              userStatus = 'approved_member';
            } else if (st == 'pending') {
              userStatus = 'pending_member';
            }
          }
        } catch (_) {}
      }
    }

    final dateStr = roomRes['deadline_date'] ?? roomRes['start_date'];
    final parsedDate = dateStr != null
        ? DateTime.tryParse(dateStr.toString()) ?? DateTime.now()
        : DateTime.now();

    // Generate Signed URL untuk cover image
    final signedCoverUrl = await _getSignedCoverUrl(roomRes['cover_image']);

    return NabarRoomPreview(
      id: roomId,
      name: roomRes['title'] ?? 'Ruang Nabung',
      targetAmount: (roomRes['target_amount'] ?? 0).toDouble(),
      targetDate: parsedDate,
      ownerName: ownerName,
      coverUrl: signedCoverUrl,
      note: roomRes['note'],
      userStatus: userStatus,
    );
  }

  Future<NabarRoom?> joinRoomByInviteCode(String inviteCode) async {
    final user = currentUser;
    if (user == null) throw Exception('Anda harus login terlebih dahulu.');

    final cleanCode = extractCodeFromInput(inviteCode);
    if (cleanCode.isEmpty) {
      throw Exception('Kode atau link room tidak boleh kosong.');
    }

    var roomRes = await _client
        .from('rooms')
        .select('id, owner_id')
        .eq('id', cleanCode)
        .maybeSingle();

    if (roomRes == null) {
      final list = await _client
          .from('rooms')
          .select('id, owner_id')
          .ilike('id', '${cleanCode.toLowerCase()}%')
          .limit(1);
      if (list.isNotEmpty) {
        roomRes = list.first;
      }
    }

    if (roomRes == null) {
      throw Exception(
        'Ruang Nabung dengan link/kode "$cleanCode" tidak ditemukan.',
      );
    }

    final roomId = roomRes['id'].toString();
    final isOwner = roomRes['owner_id']?.toString() == user.id;

    final meta = user.userMetadata ?? {};
    final fullName =
        meta['full_name'] ??
        meta['name'] ??
        user.email?.split('@').first ??
        'Member';
    final avatarUrl = meta['avatar_url'] ?? meta['picture'];

    await _client.from('room_members').upsert({
      'room_id': roomId,
      'user_id': user.id,
      'user_name': fullName,
      'avatar_url': avatarUrl,
      'status': isOwner ? 'approved' : 'pending',
    }, onConflict: 'room_id, user_id');

    return getRoomById(roomId);
  }

  Future<String?> uploadRoomCover(File file, {String? roomId}) async {
    try {
      final ext = file.path.split('.').last.toLowerCase();
      final validExt = (ext == 'png' || ext == 'webp' || ext == 'gif')
          ? ext
          : 'jpg';
      final mimeType = (validExt == 'jpg' || validExt == 'jpeg')
          ? 'image/jpeg'
          : 'image/$validExt';
      final rId = roomId ?? generateUuidV4();
      final fileName =
          'cover_${rId}_${DateTime.now().millisecondsSinceEpoch}.$validExt';
      final bytes = await file.readAsBytes();

      await _client.storage
          .from('room-covers')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(contentType: mimeType, upsert: true),
          );

      // Return public URL permanen agar langsung dapat diakses oleh semua anggota dan web
      final publicUrl = _client.storage
          .from('room-covers')
          .getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading room cover to Supabase Storage: $e');
      return null;
    }
  }

  Future<void> updateRoomCover(String roomId, String coverUrl) async {
    try {
      await _client
          .from('rooms')
          .update({'cover_image': coverUrl})
          .eq('id', roomId);
    } catch (e) {
      debugPrint('Error updating room cover in Supabase: $e');
    }
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

    final roomId = generateUuidV4();

    final response = await _client
        .from('rooms')
        .insert({
          'id': roomId,
          'title': name,
          'target_amount': targetAmount,
          'current_amount': 0,
          'deadline_date': targetDate.toIso8601String().split('T').first,
          'owner_id': user.id,
          'note': note,
          'cover_image': coverUrl,
        })
        .select()
        .single();

    final createdRoomId = response['id'].toString();

    final meta = user.userMetadata ?? {};
    final fullName =
        meta['full_name'] ??
        meta['name'] ??
        user.email?.split('@').first ??
        'Owner';
    final avatarUrl = meta['avatar_url'] ?? meta['picture'];

    // Automatically insert owner into room_members
    await _client.from('room_members').insert({
      'room_id': createdRoomId,
      'user_id': user.id,
      'user_name': fullName,
      'avatar_url': avatarUrl,
      'status': 'approved',
    });

    return createdRoomId;
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
      final results = await Future.wait(
        roomsRes.map((r) => getRoomById(r['id'].toString())),
      );
      for (var room in results) {
        if (room != null) rooms.add(room);
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
      final roomRes = await _client
          .from('rooms')
          .select()
          .eq('id', roomId)
          .maybeSingle();
      if (roomRes == null) return null;

      final ownerId = roomRes['owner_id']?.toString() ?? '';

      final membersRes = await _client
          .from('room_members')
          .select('''
        id, user_id, status, user_name, avatar_url
      ''')
          .eq('room_id', roomId);

      final txRes = await _client
          .from('room_transactions')
          .select('''
        id, user_id, user_name, avatar_url, amount, is_income, action_label, created_at, status
      ''')
          .eq('room_id', roomId)
          .order('created_at', ascending: false);

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
      final parsedDate = dateStr != null
          ? DateTime.tryParse(dateStr.toString()) ?? DateTime.now()
          : DateTime.now();

      // Generate Signed URL untuk cover image
      final signedCoverUrl = await _getSignedCoverUrl(roomRes['cover_image']);

      double currentAmount = (roomRes['current_amount'] ?? 0).toDouble();
      final double approvedSum = activities.fold<double>(
        0.0,
        (sum, a) => sum + (a.isDeposit ? a.amount : -a.amount),
      );
      if (currentAmount <= 0 && approvedSum > 0) {
        currentAmount = approvedSum;
        _client
            .from('rooms')
            .update({'current_amount': currentAmount})
            .eq('id', roomId)
            .then((_) {})
            .catchError((_) {});
      }

      return NabarRoom(
        id: roomRes['id'].toString(),
        name: roomRes['title'] ?? 'Ruang Nabung',
        targetAmount: (roomRes['target_amount'] ?? 0).toDouble(),
        currentAmount: currentAmount,
        targetDate: parsedDate,
        ownerId: ownerId,
        note: roomRes['note'],
        coverUrl: signedCoverUrl,
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
    final fullName =
        meta['full_name'] ??
        meta['name'] ??
        user.email?.split('@').first ??
        'Anggota';
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

    if (status == 'approved') {
      try {
        final cur = room.currentAmount;
        final updatedAmount = isDeposit
            ? (cur + amount)
            : (cur - amount < 0 ? 0.0 : cur - amount);
        await _client
            .from('rooms')
            .update({'current_amount': updatedAmount})
            .eq('id', roomId);
      } catch (e) {
        debugPrint('Error updating rooms.current_amount in addRoomTransaction: $e');
      }
    }

    return status;
  }

  Future<void> approveRoomTransaction(String txId) async {
    final tx = await _client
        .from('room_transactions')
        .update({'status': 'approved'})
        .eq('id', txId)
        .select()
        .maybeSingle();

    if (tx != null) {
      try {
        final roomId = tx['room_id']?.toString();
        final amount = (tx['amount'] ?? 0).toDouble();
        final isIncome = tx['is_income'] ?? true;
        if (roomId != null) {
          final roomRes = await _client
              .from('rooms')
              .select('current_amount')
              .eq('id', roomId)
              .maybeSingle();
          if (roomRes != null) {
            final cur = (roomRes['current_amount'] ?? 0).toDouble();
            final updated = isIncome
                ? (cur + amount)
                : (cur - amount < 0 ? 0.0 : cur - amount);
            await _client
                .from('rooms')
                .update({'current_amount': updated})
                .eq('id', roomId);
          }
        }
      } catch (e) {
        debugPrint('Error updating rooms current_amount on approve: $e');
      }
    }
  }

  Future<void> rejectRoomTransaction(String txId) async {
    await _client
        .from('room_transactions')
        .update({'status': 'rejected'})
        .eq('id', txId);
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

  // ==========================================
  // NABAR CHAT & MESSAGING
  // ==========================================
  Future<List<NabarMessage>> getRoomMessages(
    String roomId, {
    int limit = 100,
  }) async {
    try {
      final res = await _client
          .from('room_messages')
          .select()
          .eq('room_id', roomId)
          .order('created_at', ascending: true)
          .limit(limit);

      return (res as List).map((m) => NabarMessage.fromMap(m)).toList();
    } catch (e) {
      debugPrint('Error getting room messages: $e');
      return [];
    }
  }

  Future<void> sendRoomMessage({
    required String roomId,
    required String message,
    String messageType = 'text',
  }) async {
    final user = currentUser;
    if (user == null) {
      throw Exception('Silakan login terlebih dahulu untuk mengirim pesan.');
    }

    final meta = user.userMetadata ?? {};
    final fullName =
        meta['full_name'] ??
        meta['name'] ??
        user.email?.split('@').first ??
        'Anggota';
    final avatar = meta['avatar_url'] ?? meta['picture'];

    await _client.from('room_messages').insert({
      'room_id': roomId,
      'user_id': user.id,
      'user_name': fullName,
      'avatar_url': avatar,
      'message': message.trim(),
      'message_type': messageType,
    });
  }

  Future<void> sendSystemMessage({
    required String roomId,
    required String message,
  }) async {
    final user = currentUser;
    if (user == null) return;
    try {
      await _client.from('room_messages').insert({
        'room_id': roomId,
        'user_id': user.id,
        'user_name': 'Jagacuan Bot',
        'avatar_url': null,
        'message': message.trim(),
        'message_type': 'system',
      });
    } catch (e) {
      debugPrint('Error sending system message: $e');
    }
  }

  Future<void> deleteRoomMessage(String messageId) async {
    await _client.from('room_messages').delete().eq('id', messageId);
  }

  Stream<List<NabarMessage>> streamRoomMessages(String roomId) {
    return _client
        .from('room_messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at', ascending: true)
        .map((maps) => maps.map((m) => NabarMessage.fromMap(m)).toList());
  }

  Future<void> leaveRoom(String roomId) async {
    final user = currentUser;
    if (user == null) throw Exception('Anda harus login terlebih dahulu.');

    await _client
        .from('room_members')
        .delete()
        .eq('room_id', roomId)
        .eq('user_id', user.id);
  }

  Future<void> deleteRoom(String roomId) async {
    final user = currentUser;
    if (user == null) throw Exception('Anda harus login terlebih dahulu.');

    final roomRes = await _client
        .from('rooms')
        .select()
        .eq('id', roomId)
        .maybeSingle();

    if (roomRes != null) {
      if (roomRes['owner_id']?.toString() != user.id) {
        throw Exception(
          'Hanya pemilik (Host) yang dapat membubarkan ruang ini.',
        );
      }
      final coverUrl =
          (roomRes['cover_image'] ?? roomRes['cover_url']) as String?;
      if (coverUrl != null && coverUrl.isNotEmpty) {
        try {
          final uri = Uri.tryParse(coverUrl);
          final fileName = uri != null && uri.pathSegments.isNotEmpty
              ? uri.pathSegments.last
              : coverUrl;
          await _client.storage.from('room-covers').remove([fileName]);
        } catch (e) {
          debugPrint('Error deleting cover file from storage: $e');
        }
      }
    }

    try {
      await _client.from('room_messages').delete().eq('room_id', roomId);
    } catch (e) {
      debugPrint('Error deleting room messages: $e');
    }

    try {
      await _client.from('room_activities').delete().eq('room_id', roomId);
    } catch (e) {
      debugPrint('Error deleting room activities: $e');
    }

    try {
      await _client.from('room_members').delete().eq('room_id', roomId);
    } catch (e) {
      debugPrint('Error deleting room members: $e');
    }

    await _client.from('rooms').delete().eq('id', roomId);
  }
}
