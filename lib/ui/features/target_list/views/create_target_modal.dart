import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../view_models/target_list_view_model.dart';
import '../../../../data/repositories/supabase_nabar_repository.dart';
import '../../../../data/models/target_item.dart';
import '../../../core/formatters.dart';
import '../../../core/i18n.dart';

class CreateTargetModal extends StatefulWidget {
  final TargetType initialType;
  final DateTime? initialDeadlineDate;

  const CreateTargetModal({
    super.key,
    this.initialType = TargetType.target,
    this.initialDeadlineDate,
  });

  @override
  State<CreateTargetModal> createState() => _CreateTargetModalState();
}

class _CreateTargetModalState extends State<CreateTargetModal> {
  late TargetType _selectedType;
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime _startDate = DateTime.now();
  DateTime? _deadlineDate;
  String? _coverUrl;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    if (widget.initialDeadlineDate != null) {
      _deadlineDate = widget.initialDeadlineDate;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onAmountChanged(String val) {
    final numeric = val.replaceAll(RegExp(r'\D'), '');
    if (numeric.isEmpty) {
      _amountController.text = '';
      return;
    }
    final number = double.tryParse(numeric) ?? 0;
    final vm = context.read<TargetListViewModel>();
    final symbol = currencySymbolMap[vm.currency] ?? 'Rp ';
    final formatted = formatCurrency(number, vm.currency).replaceAll(symbol, '');
    _amountController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  Future<void> _pickCoverImage() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _coverUrl = image.path;
        });
      }
    } catch (e) {
      debugPrint('Error picking image from storage: $e');
    }
  }

  Future<void> _handleSave() async {
    final title = _titleController.text.trim();
    final amountStr = _amountController.text.replaceAll(RegExp(r'\D'), '');
    final amount = double.tryParse(amountStr) ?? 0;

    if (title.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap isi judul target dan nominal tabungan!')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final vm = context.read<TargetListViewModel>();
      final baseTargetAmount = toBaseIDR(amount, vm.currency);
      final id = DateTime.now().millisecondsSinceEpoch.toString();

      if (_selectedType == TargetType.nabar) {
        final supabaseRepo = context.read<SupabaseNabarRepository>();
        final roomId = await supabaseRepo.createRoom(
          name: title,
          targetAmount: baseTargetAmount,
          targetDate: _deadlineDate ?? _startDate.add(const Duration(days: 30)),
          note: _noteController.text,
        );

        final target = TargetItem(
          id: id,
          title: title,
          targetAmount: baseTargetAmount,
          startDate: _startDate,
          endDate: _deadlineDate ?? _startDate.add(const Duration(days: 30)),
          note: _noteController.text,
          coverUrl: _coverUrl,
          type: TargetType.nabar,
          roomId: roomId,
        );

        await vm.addTarget(target);
      } else {
        final target = TargetItem(
          id: id,
          title: title,
          targetAmount: baseTargetAmount,
          startDate: _startDate,
          endDate: _deadlineDate ?? _startDate.add(const Duration(days: 30)),
          note: _noteController.text,
          coverUrl: _coverUrl,
          type: _selectedType,
        );

        await vm.addTarget(target);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_selectedType == TargetType.nabar
                ? 'Ruang Nabung Bareng berhasil dibuat!'
                : 'Target tabungan berhasil dibuat!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat target: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _formatDateDisplay(DateTime? date) {
    if (date == null) return 'mm / dd / yyyy';
    return DateFormat('dd / MM / yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TargetListViewModel>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final lang = vm.language;

    final bg = isDark ? const Color(0xFF181920) : const Color(0xFFFAF6EF);
    final cardBg = isDark ? const Color(0xFF1F212D) : const Color(0xFFEFEADF);
    final borderCol = isDark ? const Color(0xFF333748) : const Color(0xFFDDD5C7);
    final inputBorderFocus = isDark ? const Color(0xFF808CFF) : const Color(0xFF4F5BD5);
    final textColor = isDark ? Colors.white : const Color(0xFF2C2418);
    final labelColor = isDark ? const Color(0xFF808CFF) : const Color(0xFF4F5BD5);
    final mutedColor = isDark ? const Color(0xFF9EA3B2) : const Color(0xFF7A6F60);
    final btnSaveBg = const Color(0xFF808CFF);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Image Upload Area ("Tambah gambar barang impian")
            InkWell(
              onTap: _pickCoverImage,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: double.infinity,
                height: 100,
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _coverUrl != null
                        ? inputBorderFocus
                        : (isDark ? const Color(0xFF3B4055) : const Color(0xFFDDD5C7)),
                    width: 1.5,
                  ),
                ),
                child: _coverUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _coverUrl!.startsWith('http://') || _coverUrl!.startsWith('https://')
                                ? Image.network(_coverUrl!, fit: BoxFit.cover)
                                : Image.file(File(_coverUrl!), fit: BoxFit.cover),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: InkWell(
                                onTap: () => setState(() => _coverUrl = null),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(LucideIcons.x, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              LucideIcons.image,
                              size: 36,
                              color: labelColor,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              AppTranslations.tr(lang, 'create.image_upload'),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: labelColor,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // Form Section Title
            Text(
              _selectedType == TargetType.nabar
                  ? AppTranslations.tr(lang, 'create.title_nabar')
                  : (_selectedType == TargetType.berkala
                      ? AppTranslations.tr(lang, 'create.title_berkala')
                      : AppTranslations.tr(lang, 'create.title_nabung')),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 18),

            // Field 1: Nama Target
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderCol, width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppTranslations.tr(lang, 'create.name_label'),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: labelColor),
                  ),
                  TextField(
                    controller: _titleController,
                    style: TextStyle(color: textColor, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: _selectedType == TargetType.nabar
                          ? AppTranslations.tr(lang, 'create.name_hint_nabar')
                          : AppTranslations.tr(lang, 'create.name_hint_nabung'),
                      hintStyle: TextStyle(fontSize: 13, color: mutedColor),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Field 2: Jumlah Target (Rp)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderCol, width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${AppTranslations.tr(lang, 'create.amount_label')} (${currencySymbolMap[vm.currency] ?? 'Rp '})',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: mutedColor),
                  ),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    onChanged: _onAmountChanged,
                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: TextStyle(fontSize: 15, color: mutedColor, fontWeight: FontWeight.bold),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Field 3: Tanggal Mulai
            Text(AppTranslations.tr(lang, 'create.start_date'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: mutedColor)),
            const SizedBox(height: 6),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
                if (picked != null) setState(() => _startDate = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderCol, width: 1.2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDateDisplay(_startDate),
                      style: TextStyle(fontSize: 14, color: textColor),
                    ),
                    Icon(LucideIcons.calendar, size: 18, color: mutedColor),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Field 4: Deadline (opsional)
            Text(AppTranslations.tr(lang, 'create.deadline_optional'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: mutedColor)),
            const SizedBox(height: 6),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _deadlineDate ?? DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2035),
                );
                if (picked != null) setState(() => _deadlineDate = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderCol, width: 1.2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDateDisplay(_deadlineDate),
                      style: TextStyle(fontSize: 14, color: textColor),
                    ),
                    Icon(LucideIcons.calendar, size: 18, color: mutedColor),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Field 5: Catatan
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderCol, width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppTranslations.tr(lang, 'create.note'),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: mutedColor),
                  ),
                  TextField(
                    controller: _noteController,
                    maxLines: 3,
                    style: TextStyle(color: textColor, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: AppTranslations.tr(lang, 'create.note_hint'),
                      hintStyle: TextStyle(fontSize: 13, color: mutedColor),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Subtitle helper text
            Text(
              AppTranslations.tr(lang, 'create.note_subtext'),
              style: TextStyle(fontSize: 11, color: mutedColor),
            ),
            const SizedBox(height: 24),

            // Bottom Buttons Row (Batal & Simpan Target)
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: cardBg,
                        foregroundColor: textColor,
                        side: BorderSide(color: borderCol, width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        AppTranslations.tr(lang, 'common.cancel'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: btnSaveBg,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              AppTranslations.tr(lang, 'create.button_save'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
