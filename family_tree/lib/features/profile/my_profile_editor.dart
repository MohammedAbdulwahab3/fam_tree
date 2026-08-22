import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/core/theme/app_colors.dart';
import 'package:family_tree/core/theme/elegant_theme.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/data/services/storage_service.dart';
import 'package:family_tree/features/profile/photo_crop_sheet.dart';
import 'package:image_picker/image_picker.dart';

/// What a linked member can say about themselves.
///
/// Everything here lands on the person's card in the tree, so the form is
/// written as prompts rather than database labels — "Where were you born?"
/// instead of "birth_place". Structure (who your parents are, who you are
/// married to) is deliberately *not* editable: the backend refuses those from
/// non-admins, and the form reflects that rather than offering fields that
/// would be silently dropped.
class MyProfileEditor extends ConsumerStatefulWidget {
  const MyProfileEditor({
    super.key,
    required this.person,
    required this.spouses,
    required this.onSave,
    this.isAdmin = false,
  });

  final Person person;

  /// Named for display only — a member cannot rewire their own marriages.
  final List<Person> spouses;

  /// Persists the edited record. Throws to signal failure.
  final Future<void> Function(Person updated) onSave;

  /// Admins get the controls a member must not have over their own record:
  /// marking someone as having died. The backend enforces the same split, so
  /// hiding these is honesty rather than security.
  final bool isAdmin;

  static Future<bool?> show(
    BuildContext context, {
    required Person person,
    required List<Person> spouses,
    required Future<void> Function(Person updated) onSave,
    bool isAdmin = false,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MyProfileEditor(
        person: person,
        spouses: spouses,
        onSave: onSave,
        isAdmin: isAdmin,
      ),
    );
  }

  @override
  ConsumerState<MyProfileEditor> createState() => _MyProfileEditorState();
}

class _MyProfileEditorState extends ConsumerState<MyProfileEditor> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _bio;
  late final TextEditingController _occupation;
  late final TextEditingController _birthPlace;
  late final TextEditingController _residence;
  late final TextEditingController _education;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _interest;

  late final TextEditingController _spouseName;

  late DateTime? _birthDate;
  late DateTime? _deathDate;
  late String _gender;
  late String _maritalStatus;
  late bool _isDeceased;
  late List<String> _interests;
  late String _photoUrl;

  bool _uploadingPhoto = false;

  bool _saving = false;
  String? _error;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final p = widget.person;
    _firstName = _track(TextEditingController(text: p.firstName));
    _lastName = _track(TextEditingController(text: p.lastName));
    _bio = _track(TextEditingController(text: p.bio ?? ''));
    _occupation = _track(TextEditingController(text: p.occupation ?? ''));
    _birthPlace = _track(TextEditingController(text: p.birthPlace ?? ''));
    _residence = _track(TextEditingController(text: p.currentResidence ?? ''));
    _education = _track(TextEditingController(text: p.education ?? ''));
    _email = _track(TextEditingController(text: p.contactEmail ?? ''));
    _phone = _track(TextEditingController(text: p.contactPhone ?? ''));
    _interest = TextEditingController();
    _spouseName = _track(TextEditingController(text: p.spouseName ?? ''));
    _birthDate = p.birthDate;
    _deathDate = p.deathDate;
    _gender = p.gender ?? '';
    // An existing spouse record in the tree means married, even when nobody
    // ever ticked the box.
    _maritalStatus = (p.maritalStatus?.isNotEmpty ?? false)
        ? p.maritalStatus!
        : (widget.spouses.isNotEmpty ? 'married' : '');
    _isDeceased = p.isDeceased;
    _interests = List<String>.from(p.interests);
    _photoUrl = p.profilePhotoUrl ?? '';
  }

  TextEditingController _track(TextEditingController c) {
    c.addListener(() {
      if (!_dirty) setState(() => _dirty = true);
    });
    return c;
  }

  @override
  void dispose() {
    for (final c in [
      _firstName,
      _lastName,
      _bio,
      _occupation,
      _birthPlace,
      _residence,
      _education,
      _email,
      _phone,
      _interest,
      _spouseName,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _trimmedOrNull(TextEditingController c) {
    final value = c.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    // copyWith keeps relationships, photos and life events exactly as they
    // were — this form has no business touching them.
    final updated = widget.person.copyWith(
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      birthDate: _birthDate,
      gender: _gender,
      bio: _trimmedOrNull(_bio) ?? '',
      occupation: _trimmedOrNull(_occupation) ?? '',
      birthPlace: _trimmedOrNull(_birthPlace) ?? '',
      currentResidence: _trimmedOrNull(_residence) ?? '',
      education: _trimmedOrNull(_education) ?? '',
      contactEmail: _trimmedOrNull(_email) ?? '',
      contactPhone: _trimmedOrNull(_phone) ?? '',
      interests: _interests,
      profilePhotoUrl: _photoUrl,
      maritalStatus: _maritalStatus,
      // Only meaningful while married; clearing it avoids a stale name
      // lingering after a divorce.
      spouseName:
          _maritalStatus == 'married' ? (_trimmedOrNull(_spouseName) ?? '') : '',
      isDeceasedFlag: _isDeceased,
      deathDate: _isDeceased ? _deathDate : null,
      clearBirthDate: _birthDate == null,
      clearDeathDate: !_isDeceased || _deathDate == null,
      updatedAt: DateTime.now(),
    );

    try {
      await widget.onSave(updated);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 30),
      firstDate: DateTime(1850),
      lastDate: now,
      helpText: 'When were you born?',
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _dirty = true;
      });
    }
  }

  void _addInterest() {
    final value = _interest.text.trim();
    if (value.isEmpty) return;
    // Case-insensitive dedupe so "Football" and "football" don't both stick.
    final exists = _interests
        .any((i) => i.toLowerCase() == value.toLowerCase());
    if (!exists) {
      setState(() {
        _interests = [..._interests, value];
        _dirty = true;
      });
    }
    _interest.clear();
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Discard changes?',
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Your edits have not been saved yet.',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.accentRose,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard() && mounted) {
          navigator.pop(false);
        }
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.96,
        expand: false,
        builder: (context, scroll) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [AppTheme.surfaceDark, AppTheme.backgroundDark]
                  : [ElegantColors.warmWhite, ElegantColors.cream],
            ),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            children: [
              _handle(isDark),
              _header(isDark),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    controller: scroll,
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    children: [
                      _photoPicker(isDark),
                      const SizedBox(height: 24),
                      _section('Your name', isDark),
                      Row(
                        children: [
                          Expanded(
                            child: _field(
                              controller: _firstName,
                              label: 'First name',
                              icon: Icons.person_outline_rounded,
                              isDark: isDark,
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'A first name is required'
                                      : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _field(
                              controller: _lastName,
                              label: 'Last name',
                              icon: Icons.badge_outlined,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 22),
                      _section('About you', isDark),
                      _dateField(isDark),
                      const SizedBox(height: 14),
                      _genderField(isDark),
                      const SizedBox(height: 14),
                      _field(
                        controller: _bio,
                        label: 'Your story',
                        hint: 'A few lines about your life, in your own words',
                        icon: Icons.auto_stories_outlined,
                        isDark: isDark,
                        maxLines: 5,
                        maxLength: 1000,
                      ),

                      const SizedBox(height: 22),
                      _section('Life & work', isDark),
                      _field(
                        controller: _occupation,
                        label: 'What you do',
                        hint: 'Teacher, farmer, engineer…',
                        icon: Icons.work_outline_rounded,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 14),
                      _field(
                        controller: _education,
                        label: 'Education',
                        hint: 'School or university',
                        icon: Icons.school_outlined,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 14),
                      _field(
                        controller: _birthPlace,
                        label: 'Where you were born',
                        icon: Icons.cake_outlined,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 14),
                      _field(
                        controller: _residence,
                        label: 'Where you live now',
                        icon: Icons.home_outlined,
                        isDark: isDark,
                      ),

                      const SizedBox(height: 22),
                      _section('Marital status', isDark),
                      _maritalStatusField(isDark),
                      if (_maritalStatus == 'married') ...[
                        const SizedBox(height: 14),
                        _field(
                          controller: _spouseName,
                          label: 'Spouse\u2019s name',
                          hint: 'Their full name',
                          icon: Icons.favorite_outline_rounded,
                          isDark: isDark,
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Add your spouse\u2019s name, or change the status'
                                  : null,
                        ),
                      ],

                      if (widget.isAdmin) ...[
                        const SizedBox(height: 22),
                        _section('Living status', isDark),
                        _lifeStatusField(isDark),
                      ],

                      const SizedBox(height: 22),
                      _section('Interests', isDark),
                      _interestsField(isDark),

                      const SizedBox(height: 22),
                      _section('How family can reach you', isDark),
                      _field(
                        controller: _email,
                        label: 'Email',
                        icon: Icons.alternate_email_rounded,
                        isDark: isDark,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          final value = v?.trim() ?? '';
                          if (value.isEmpty) return null;
                          return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                  .hasMatch(value)
                              ? null
                              : 'That does not look like an email address';
                        },
                      ),
                      const SizedBox(height: 14),
                      _field(
                        controller: _phone,
                        label: 'Phone',
                        icon: Icons.phone_outlined,
                        isDark: isDark,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9+\-\s()]'),
                          ),
                        ],
                      ),

                      if (widget.spouses.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        _section('Family', isDark),
                        _spouseNote(isDark),
                      ],

                      if (_error != null) ...[
                        const SizedBox(height: 18),
                        _errorBox(isDark),
                      ],
                    ],
                  ),
                ),
              ),
              _saveBar(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _handle(bool isDark) => Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: 12, bottom: 4),
        decoration: BoxDecoration(
          color: context.colors.hairline,
          borderRadius: BorderRadius.circular(2),
        ),
      );

  Widget _header(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isAdmin ? 'Edit profile' : 'My profile',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: context.colors.ink,
                  ),
                ),
                Text(
                  widget.isAdmin
                      ? 'Everything here shows on ${widget.person.firstName}\u2019s card'
                      : 'Everything here shows on your card in the family tree',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 13.5,
                    color: context.colors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: () async {
              final navigator = Navigator.of(context);
              if (await _confirmDiscard() && mounted) {
                navigator.pop(false);
              }
            },
            icon: Icon(
              Icons.close_rounded,
              color: context.colors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: context.colors.inkMuted,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : ElegantColors.champagne,
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    String? hint,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    final accent = context.colors.accent;

    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: GoogleFonts.inter(
        fontSize: 14,
        color: context.colors.ink,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: maxLines > 1,
        labelStyle: GoogleFonts.inter(
          fontSize: 13.5,
          color: context.colors.inkMuted,
        ),
        hintStyle: GoogleFonts.cormorantGaramond(
          fontSize: 14,
          color: context.colors.inkMuted,
        ),
        prefixIcon: Icon(icon, size: 19, color: accent),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : ElegantColors.warmWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : ElegantColors.champagne,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : ElegantColors.champagne,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent, width: 1.6),
        ),
      ),
    );
  }

  Widget _dateField(bool isDark) {
    final accent = context.colors.accent;
    final age = _birthDate == null ? null : _ageFrom(_birthDate!);

    return InkWell(
      onTap: _pickBirthDate,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Date of birth',
          labelStyle: GoogleFonts.inter(
            fontSize: 13.5,
            color: context.colors.inkMuted,
          ),
          prefixIcon:
              Icon(Icons.calendar_today_rounded, size: 18, color: accent),
          suffixIcon: _birthDate == null
              ? null
              : IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () => setState(() {
                    _birthDate = null;
                    _dirty = true;
                  }),
                ),
          filled: true,
          fillColor: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : ElegantColors.warmWhite,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : ElegantColors.champagne,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : ElegantColors.champagne,
            ),
          ),
        ),
        child: Text(
          _birthDate == null
              ? 'Tap to choose'
              // Age is derived, never stored — a stored age is wrong within a
              // year of writing it down.
              : '${DateFormat('d MMMM yyyy').format(_birthDate!)}   ·   $age years old',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: _birthDate == null
                ? (context.colors.inkMuted)
                : (context.colors.ink),
          ),
        ),
      ),
    );
  }

  static int _ageFrom(DateTime birth) {
    final now = DateTime.now();
    var age = now.year - birth.year;
    final hadBirthday = now.month > birth.month ||
        (now.month == birth.month && now.day >= birth.day);
    if (!hadBirthday) age--;
    return age;
  }

  Widget _genderField(bool isDark) {
    const options = {
      'male': 'Male',
      'female': 'Female',
      'other': 'Other',
    };
    final accent = context.colors.accent;

    return Row(
      children: options.entries.map((entry) {
        final selected = _gender == entry.key;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() {
                // Tapping the selected one clears it — not everyone wants to
                // record this.
                _gender = selected ? '' : entry.key;
                _dirty = true;
              }),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 13),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? accent.withValues(alpha: isDark ? 0.2 : 0.12)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : ElegantColors.warmWhite),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? accent
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : ElegantColors.champagne),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  entry.value,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected
                        ? accent
                        : (context.colors.inkMuted),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// The photo everyone sees on this person's card in the tree.
  ///
  /// This is the person record's photo, not the login's avatar — the old
  /// account-photo control set a picture that never appeared in the tree at
  /// all, which is why it has been folded into here.
  Widget _photoPicker(bool isDark) {
    final accent = context.colors.accent;
    final hasPhoto = _photoUrl.trim().isNotEmpty;

    return Center(
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.12),
                  border: Border.all(color: accent.withValues(alpha: 0.4), width: 2),
                  image: hasPhoto
                      ? DecorationImage(
                          image: NetworkImage(_photoUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                alignment: Alignment.center,
                child: _uploadingPhoto
                    ? CircularProgressIndicator(strokeWidth: 2.5, color: accent)
                    : hasPhoto
                        ? null
                        : Icon(Icons.person_rounded, size: 46, color: accent),
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: Material(
                  color: accent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _uploadingPhoto ? null : _pickPhoto,
                    child: const Padding(
                      padding: EdgeInsets.all(9),
                      child: Icon(Icons.photo_camera_rounded,
                          size: 17, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            widget.isAdmin
                ? 'Shown on this person\u2019s card to everyone'
                : 'Shown on your card to the whole family',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 13,
              color: context.colors.inkMuted,
            ),
          ),
          if (hasPhoto && !_uploadingPhoto)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: _pickPhoto,
                  icon: const Icon(Icons.crop_rounded, size: 16),
                  label: const Text('Change & crop'),
                  style: TextButton.styleFrom(
                    foregroundColor: accent,
                    textStyle: GoogleFonts.inter(fontSize: 12.5),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setState(() {
                    _photoUrl = '';
                    _dirty = true;
                  }),
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Remove'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.accentRose,
                    textStyle: GoogleFonts.inter(fontSize: 12.5),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    // No maxWidth/maxHeight here: the cropper wants the full picture to work
    // from, and it downscales the result itself.
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final original = await picked.readAsBytes();
    if (!mounted) return;

    // Frame it before uploading, so the stored image already is the square
    // every card shows. Cancelling the cropper cancels the whole change.
    final cropped = await PhotoCropSheet.show(
      context,
      bytes: original,
      title: widget.isAdmin
          ? 'Position ${widget.person.firstName}\u2019s photo'
          : 'Position your photo',
    );
    if (cropped == null || !mounted) return;

    setState(() {
      _uploadingPhoto = true;
      _error = null;
    });

    try {
      final bytes = cropped;
      final url = await StorageService()
          .uploadProfilePhoto(bytes, '${picked.name}_square.png');
      if (!mounted) return;
      setState(() {
        _photoUrl = url;
        _uploadingPhoto = false;
        _dirty = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadingPhoto = false;
        _error = 'Could not upload the photo: '
            '${e.toString().replaceAll('Exception: ', '')}';
      });
    }
  }

  Widget _maritalStatusField(bool isDark) {
    const options = {
      'single': ('Single', Icons.person_rounded),
      'married': ('Married', Icons.favorite_rounded),
      'divorced': ('Divorced', Icons.heart_broken_rounded),
      'widowed': ('Widowed', Icons.local_florist_rounded),
    };
    final accent = context.colors.accent;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.entries.map((entry) {
        final selected = _maritalStatus == entry.key;
        final (label, icon) = entry.value;
        return InkWell(
          onTap: () => setState(() {
            // Tapping the current choice clears it — not everyone wants this
            // on their card.
            _maritalStatus = selected ? '' : entry.key;
            _dirty = true;
          }),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: selected
                  ? accent.withValues(alpha: isDark ? 0.2 : 0.12)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : ElegantColors.warmWhite),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? accent
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : ElegantColors.champagne),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 15,
                    color: selected
                        ? accent
                        : (isDark
                            ? Colors.white54
                            : ElegantColors.warmGray)),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected
                        ? accent
                        : (isDark
                            ? Colors.white60
                            : ElegantColors.warmGray),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Admin-only. Marking someone as having died is a statement about a real
  /// person, so it reads as a deliberate switch rather than a checkbox, and
  /// the date stays optional — families often know long before they know when.
  Widget _lifeStatusField(bool isDark) {
    final tone = _isDeceased
        ? (context.colors.inkMuted)
        : (context.colors.secondary);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : ElegantColors.warmWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : ElegantColors.champagne,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _isDeceased
                      ? Icons.local_florist_rounded
                      : Icons.favorite_rounded,
                  size: 18,
                  color: tone,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isDeceased ? 'Passed away' : 'Living',
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color:
                            context.colors.ink,
                      ),
                    ),
                    Text(
                      _isDeceased
                          ? 'Shown in remembrance on the tree'
                          : 'Shown as a living member',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 12.5,
                        color: isDark
                            ? Colors.white54
                            : ElegantColors.warmGray,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _isDeceased,
                activeThumbColor: tone,
                onChanged: (value) => setState(() {
                  _isDeceased = value;
                  if (!value) _deathDate = null;
                  _dirty = true;
                }),
              ),
            ],
          ),
          if (_isDeceased) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _deathDate ?? DateTime.now(),
                  firstDate: _birthDate ?? DateTime(1850),
                  lastDate: DateTime.now(),
                  helpText: 'Date of passing (optional)',
                );
                if (picked != null) {
                  setState(() {
                    _deathDate = picked;
                    _dirty = true;
                  });
                }
              },
              borderRadius: BorderRadius.circular(11),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 13, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : ElegantColors.parchment,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event_rounded, size: 16, color: tone),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _deathDate == null
                            ? 'Add a date of passing (optional)'
                            : DateFormat('d MMMM yyyy').format(_deathDate!),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: _deathDate == null
                              ? (isDark
                                  ? Colors.white38
                                  : ElegantColors.warmGray)
                              : (isDark
                                  ? Colors.white
                                  : ElegantColors.charcoal),
                        ),
                      ),
                    ),
                    if (_deathDate != null)
                      IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.clear_rounded, size: 17),
                        onPressed: () => setState(() {
                          _deathDate = null;
                          _dirty = true;
                        }),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _interestsField(bool isDark) {
    final accent = context.colors.secondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _field(
                controller: _interest,
                label: 'Add an interest',
                hint: 'Cooking, football, poetry…',
                icon: Icons.interests_outlined,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: _addInterest,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: const Icon(Icons.add_rounded, size: 20),
              ),
            ),
          ],
        ),
        if (_interests.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _interests
                .map((interest) => Chip(
                      label: Text(
                        interest,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color:
                              context.colors.ink,
                        ),
                      ),
                      backgroundColor:
                          accent.withValues(alpha: isDark ? 0.16 : 0.12),
                      side: BorderSide(color: accent.withValues(alpha: 0.3)),
                      deleteIcon: const Icon(Icons.close_rounded, size: 15),
                      onDeleted: () => setState(() {
                        _interests =
                            _interests.where((i) => i != interest).toList();
                        _dirty = true;
                      }),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  /// Marriages are structural, so they are shown but not editable here — the
  /// backend would reject the change and silently keep the old value.
  Widget _spouseNote(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : ElegantColors.parchment,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.favorite_rounded,
            size: 17,
            color: context.colors.rose,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.spouses.length == 1
                      ? 'Married to ${widget.spouses.first.fullName}'
                      : 'Married to ${widget.spouses.map((s) => s.fullName).join(', ')}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.colors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Ask an admin to change who you are connected to in the '
                  'tree — that keeps everyone\'s branches consistent.',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 13,
                    height: 1.35,
                    color: context.colors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBox(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.accentRose.withValues(alpha: isDark ? 0.14 : 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.accentRose.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 17, color: AppTheme.accentRose),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                height: 1.35,
                color: context.colors.inkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _saveBar(bool isDark) {
    final accent = context.colors.accent;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : ElegantColors.warmWhite,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : ElegantColors.champagne,
          ),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _saving || !_dirty ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_rounded, size: 18),
          label: Text(
            _saving
                ? 'Saving…'
                : _dirty
                    ? 'Save my profile'
                    : 'Nothing to save yet',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}
