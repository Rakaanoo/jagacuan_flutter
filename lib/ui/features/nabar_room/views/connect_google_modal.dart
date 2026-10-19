import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../data/repositories/supabase_nabar_repository.dart';
import '../../../../data/models/nabar_room.dart';
import '../../../../data/models/target_item.dart';
import '../../target_list/view_models/target_list_view_model.dart';
import '../../target_list/views/create_target_modal.dart';
import '../views/nabar_room_view.dart';
import '../../../core/i18n.dart';
import '../../../core/formatters.dart';
import '../../../core/theme.dart';

class ConnectGoogleModal extends StatefulWidget {
  const ConnectGoogleModal({super.key});

  @override
  State<ConnectGoogleModal> createState() => _ConnectGoogleModalState();
}

class _ConnectGoogleModalState extends State<ConnectGoogleModal> {
  List<NabarRoom> _rooms = [];
  bool _isLoadingRooms = false;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    final repo = context.read<SupabaseNabarRepository>();
    if (repo.currentUser == null) return;
    setState(() => _isLoadingRooms = true);
    try {
      final userRooms = await repo.getUserRooms();
      if (mounted) {
        setState(() {
          _rooms = userRooms;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoadingRooms = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TargetListViewModel>();
    final repo = context.watch<SupabaseNabarRepository>();
    final user = repo.currentUser;

    final bg = context.appBg;
    final cardBg = context.appCard;
    final iconBoxBg = context.appSurface;
    final cardBorder = context.appBorder;
    final textColor = context.appTextPrimary;
    final mutedTextColor = context.appTextMuted;
    final accentCol = context.appAccent;

    final meta = user?.userMetadata ?? {};
    final fullName =
        meta['full_name'] ??
        meta['name'] ??
        user?.email?.split('@').first ??
        'Pengguna';
    final avatarUrl = meta['avatar_url'] ?? meta['picture'];
    final email = user?.email ?? '';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cardBorder, width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 30,
                offset: Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row (Icon + Title + Close X)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(LucideIcons.users, color: textColor, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          AppTranslations.tr(
                            vm.language,
                            'connect_google.header',
                          ),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        LucideIcons.x,
                        color: mutedTextColor,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Divider(color: cardBorder, height: 1),
                const SizedBox(height: 20),

                if (user == null) ...[
                  // Non-Logged In State (Connect Google Card)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: cardBorder, width: 1),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: iconBoxBg,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Center(
                            child: Icon(
                              LucideIcons.logIn,
                              color: accentCol,
                              size: 28,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          AppTranslations.tr(
                            vm.language,
                            'connect_google.title',
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          AppTranslations.tr(
                            vm.language,
                            'connect_google.desc',
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: mutedTextColor,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: context.appBadgeSuccessBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: context.appBadgeSuccessBorder,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                LucideIcons.shieldCheck,
                                color: context.appBadgeSuccessText,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  AppTranslations.tr(
                                    vm.language,
                                    'connect_google.safe_notice',
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.appBadgeSuccessText,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: repo.isSigningIn
                                ? null
                                : () async {
                                    try {
                                      await repo.signInWithGoogle();
                                      _loadRooms();
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text('Google Sign-In: $e'),
                                          ),
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF1F212D),
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            child: repo.isSigningIn
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF4285F4),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.asset(
                                        'assets/images/google-logo.png',
                                        height: 20,
                                        errorBuilder: (_, _, _) => const Text(
                                          'G',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: Color(0xFF4285F4),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        AppTranslations.tr(
                                          vm.language,
                                          'connect_google.button',
                                        ),
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1F212D),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Logged-in User Profile Card (Matches User's UI/UX Screenshot)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorder, width: 1),
                    ),
                    child: Row(
                      children: [
                        // Avatar Circle
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF5B50D6),
                            image:
                                (avatarUrl != null &&
                                    avatarUrl.toString().isNotEmpty)
                                ? DecorationImage(
                                    image: NetworkImage(avatarUrl.toString()),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child:
                              (avatarUrl == null ||
                                  avatarUrl.toString().isEmpty)
                              ? Center(
                                  child: Text(
                                    fullName.isNotEmpty
                                        ? fullName[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),

                        // Name + Green Google Badge + Email
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      fullName,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF16A34A),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          LucideIcons.checkCircle2,
                                          color: Colors.white,
                                          size: 10,
                                        ),
                                        SizedBox(width: 3),
                                        Text(
                                          'Google',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                email,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: mutedTextColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // Sign Out Button
                        IconButton(
                          icon: Icon(
                            LucideIcons.logOut,
                            color: mutedTextColor,
                            size: 18,
                          ),
                          tooltip: AppTranslations.tr(
                            vm.language,
                            'connect_google.sign_out_tooltip',
                          ),
                          onPressed: () async {
                            await repo.signOut();
                            if (mounted) {
                              setState(() {
                                _rooms = [];
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Main Content: Rooms List or Empty State Text
                  if (_isLoadingRooms)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_rooms.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          AppTranslations.tr(
                            vm.language,
                            'connect_google.no_rooms',
                          ),
                          style: TextStyle(
                            fontSize: 14,
                            color: mutedTextColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                  else
                    Column(
                      children: _rooms.map((r) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: cardBorder),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: context.appSurface,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                LucideIcons.users,
                                color: accentCol,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              r.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            subtitle: Text(
                              '${AppTranslations.tr(vm.language, 'nabar.target')} ${formatRupiah(r.targetAmount, vm.currency)}',
                            ),
                            trailing: Icon(
                              LucideIcons.chevronRight,
                              color: mutedTextColor,
                              size: 18,
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => NabarRoomView(roomId: r.id),
                                ),
                              );
                            },
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 16),

                  // Primary Button "+ Buat Room Kolaborasi Baru"
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => const CreateTargetModal(
                            initialType: TargetType.nabar,
                          ),
                        );
                      },
                      icon: const Icon(LucideIcons.plus, size: 18),
                      label: Text(
                        AppTranslations.tr(
                          vm.language,
                          'connect_google.create_new_room',
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentCol,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
