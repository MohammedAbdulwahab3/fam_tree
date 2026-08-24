import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:family_tree/core/design/design.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/data/services/api_service.dart';
import 'package:family_tree/data/services/storage_service.dart';
import 'package:family_tree/features/profile/photo_crop_sheet.dart';

/// Where somebody writes their own story down.
///
/// This is the point of the whole app — a tree with names in it is a diagram;
/// a tree with what people did, where they lived and what they cared about is
/// a family record. So the form is long, and every field is optional, and it
/// is arranged as sections that can be answered one at a time over months
/// rather than a wall that has to be filled in at once.
///
/// A member edits only their own record. The things they must not change about
/// themselves — who their parents are, whether they have died — are not hidden
/// to be tidy; the server refuses them either way. They are marked as an
/// admin's job so nobody wastes time looking for them.
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
  /// marking somebody as having died. The backend enforces the same split, so
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
      useSafeArea: true,
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

  late final _firstName = _track(TextEditingController(text: _p.firstName));
  late final _lastName = _track(TextEditingController(text: _p.lastName));
  late final _bio = _track(TextEditingController(text: _p.bio ?? ''));
  late final _occupation =
      _track(TextEditingController(text: _p.occupation ?? ''));
  late final _birthPlace =
      _track(TextEditingController(text: _p.birthPlace ?? ''));
  late final _residence =
      _track(TextEditingController(text: _p.currentResidence ?? ''));
  late final _education =
      _track(TextEditingController(text: _p.education ?? ''));
  late final _email =
      _track(TextEditingController(text: _p.contactEmail ?? ''));
  late final _phone =
      _track(TextEditingController(text: _p.contactPhone ?? ''));
  late final _spouseName =
      _track(TextEditingController(text: _p.spouseName ?? ''));
  final _interest = TextEditingController();

  Person get _p => widget.person;

  late DateTime? _birthDate = _p.birthDate;
  late DateTime? _deathDate = _p.deathDate;
  late String _gender = _p.gender ?? '';
  late String _maritalStatus = (_p.maritalStatus?.isNotEmpty ?? false)
      ? _p.maritalStatus!
      // An existing spouse record in the tree means married, even when nobody
      // ever ticked the box.
      : (widget.spouses.isNotEmpty ? 'married' : '');
  late bool _isDeceased = _p.isDeceased;
  late List<String> _interests = List<String>.from(_p.interests);
  late String _photoUrl = _p.profilePhotoUrl ?? '';

  bool _uploadingPhoto = false;
  bool _saving = false;
  bool _dirty = false;
  String? _error;

  TextEditingController _track(TextEditingController c) {
    c.addListener(() {
      if (!_dirty && mounted) setState(() => _dirty = true);
    });
    return c;
  }

  void _touch(VoidCallback change) => setState(() {
        change();
        _dirty = true;
      });

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
      _spouseName,
      _interest,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String _trimmed(TextEditingController c) => c.text.trim();

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    // copyWith keeps relationships, photos and life events exactly as they
    // were — this form has no business touching them.
    final updated = _p.copyWith(
      firstName: _trimmed(_firstName),
      lastName: _trimmed(_lastName),
      birthDate: _birthDate,
      gender: _gender,
      bio: _trimmed(_bio),
      occupation: _trimmed(_occupation),
      birthPlace: _trimmed(_birthPlace),
      currentResidence: _trimmed(_residence),
      education: _trimmed(_education),
      contactEmail: _trimmed(_email),
      contactPhone: _trimmed(_phone),
      interests: _interests,
      profilePhotoUrl: _photoUrl,
      maritalStatus: _maritalStatus,
      // Only meaningful while married; clearing it avoids a stale name
      // lingering after a divorce.
      spouseName: _maritalStatus == 'married' ? _trimmed(_spouseName) : '',
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
      Toast.success(context, 'Saved.');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = messageForError(error);
      });
    }
  }

  Future<void> _pickDate({required bool birth}) async {
    final now = DateTime.now();
    final current = birth ? _birthDate : _deathDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(now.year - (birth ? 30 : 0)),
      firstDate: DateTime(1850),
      lastDate: now,
      helpText: birth ? 'Date of birth' : 'Date of death',
    );
    if (picked == null) return;

    _touch(() {
      if (birth) {
        _birthDate = picked;
      } else {
        _deathDate = picked;
      }
    });
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
      title: widget.isAdmin && !_isSelf
          ? 'Position ${_p.firstName}’s photo'
          : 'Position your photo',
    );
    if (cropped == null || !mounted) return;

    setState(() {
      _uploadingPhoto = true;
      _error = null;
    });

    try {
      final url = await StorageService()
          .uploadProfilePhoto(cropped, '${picked.name}_square.png');
      if (!mounted) return;
      _touch(() {
        _photoUrl = url;
        _uploadingPhoto = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _uploadingPhoto = false;
        _error = 'Could not upload the photo. ${messageForError(error)}';
      });
    }
  }

  void _addInterest() {
    final value = _interest.text.trim();
    if (value.isEmpty) return;

    // Case-insensitive dedupe so "Football" and "football" don't both stick.
    final exists =
        _interests.any((i) => i.toLowerCase() == value.toLowerCase());
    if (!exists) _touch(() => _interests = [..._interests, value]);

    _interest.clear();
  }

  /// Whether this is a member editing themselves, as opposed to an admin
  /// editing somebody else. Changes only the wording.
  bool get _isSelf => !widget.isAdmin || (_p.authUserId?.isNotEmpty ?? false);

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    return confirm(
      context,
      title: 'Leave without saving?',
      message: 'What you have written here will be lost.',
      confirmLabel: 'Discard my changes',
      cancelLabel: 'Keep editing',
      destructive: true,
      icon: Icons.edit_off_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final you = _isSelf;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // Resolved before the confirmation is awaited, so nothing reads a
        // BuildContext on the far side of the gap.
        final navigator = Navigator.of(context);
        if (await _confirmDiscard() && mounted) {
          navigator.pop();
        }
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.94,
        minChildSize: 0.5,
        maxChildSize: 0.96,
        expand: false,
        builder: (context, scroll) => Container(
          decoration: BoxDecoration(
            color: c.ground,
            borderRadius: Corners.sheet,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _Header(
                title: you ? 'Your profile' : 'Editing ${_p.firstName}',
                dirty: _dirty,
                onClose: () async {
                  if (await _confirmDiscard() && context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              ),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    controller: scroll,
                    padding: const EdgeInsets.fromLTRB(
                      Insets.gutter,
                      Insets.lg,
                      Insets.gutter,
                      Insets.xxl,
                    ),
                    children: [
                      _photoPicker(you),
                      const SizedBox(height: Insets.sectionGap),
                      AppSection(
                        title: you ? 'Your name' : 'Name',
                        icon: Icons.badge_outlined,
                        children: [
                          AppTextField(
                            label: 'First name',
                            controller: _firstName,
                            textCapitalization: TextCapitalization.words,
                            validator: (v) => (v ?? '').trim().isEmpty
                                ? 'A first name is needed.'
                                : null,
                          ),
                          const SizedBox(height: Insets.md),
                          AppTextField(
                            label: 'Family name',
                            controller: _lastName,
                            optional: true,
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: Insets.md),
                          AppChoiceField<String>(
                            label: 'Gender',
                            value: _gender.isEmpty ? null : _gender,
                            optional: true,
                            options: const [
                              AppChoice(
                                value: 'male',
                                label: 'Male',
                                icon: Icons.male_rounded,
                              ),
                              AppChoice(
                                value: 'female',
                                label: 'Female',
                                icon: Icons.female_rounded,
                              ),
                            ],
                            onChanged: (v) => _touch(
                              () => _gender = _gender == v ? '' : v,
                            ),
                          ),
                          const SizedBox(height: Insets.md),
                          AppPickerField(
                            label: 'Date of birth',
                            optional: true,
                            icon: Icons.cake_outlined,
                            value: _birthDate == null
                                ? null
                                : _formatDate(_birthDate!),
                            placeholder: 'Choose a date',
                            helper: 'Even just the year helps the tree put '
                                'people in order.',
                            onTap: () => _pickDate(birth: true),
                            onClear: () => _touch(() => _birthDate = null),
                          ),
                        ],
                      ),
                      const SizedBox(height: Insets.sectionGap),
                      AppSection(
                        title: you ? 'Your life' : 'Life',
                        subtitle: 'The part a diagram cannot hold.',
                        icon: Icons.auto_stories_outlined,
                        children: [
                          AppTextField(
                            label: you ? 'About you' : 'About them',
                            controller: _bio,
                            optional: true,
                            maxLines: 5,
                            hint: you
                                ? 'Anything you would want your '
                                    'grandchildren to know.'
                                : 'Anything worth remembering.',
                          ),
                          const SizedBox(height: Insets.md),
                          AppTextField(
                            label: 'Work',
                            controller: _occupation,
                            optional: true,
                            icon: Icons.work_outline_rounded,
                            hint: 'Teacher, farmer, engineer…',
                          ),
                          const SizedBox(height: Insets.md),
                          AppTextField(
                            label: 'Education',
                            controller: _education,
                            optional: true,
                            icon: Icons.school_outlined,
                          ),
                          const SizedBox(height: Insets.md),
                          _interestsField(),
                        ],
                      ),
                      const SizedBox(height: Insets.sectionGap),
                      AppSection(
                        title: 'Places',
                        icon: Icons.place_outlined,
                        children: [
                          AppTextField(
                            label: 'Born in',
                            controller: _birthPlace,
                            optional: true,
                            hint: 'Harar, Addis Ababa…',
                          ),
                          const SizedBox(height: Insets.md),
                          AppTextField(
                            label: 'Lives in',
                            controller: _residence,
                            optional: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: Insets.sectionGap),
                      AppSection(
                        title: 'Family',
                        icon: Icons.favorite_outline_rounded,
                        children: [
                          AppChoiceField<String>(
                            label: 'Marital status',
                            value:
                                _maritalStatus.isEmpty ? null : _maritalStatus,
                            optional: true,
                            options: const [
                              AppChoice(value: 'single', label: 'Single'),
                              AppChoice(value: 'married', label: 'Married'),
                              AppChoice(value: 'divorced', label: 'Divorced'),
                              AppChoice(value: 'widowed', label: 'Widowed'),
                            ],
                            onChanged: (v) => _touch(
                              () =>
                                  _maritalStatus = _maritalStatus == v ? '' : v,
                            ),
                          ),
                          if (_maritalStatus == 'married') ...[
                            const SizedBox(height: Insets.md),
                            if (widget.spouses.isNotEmpty)
                              _spouseInTree()
                            else
                              AppTextField(
                                label: 'Married to',
                                controller: _spouseName,
                                optional: true,
                                icon: Icons.favorite_border_rounded,
                                helper: 'If they are not in the tree, their '
                                    'name here still records the marriage.',
                              ),
                          ],
                          const SizedBox(height: Insets.md),
                          _adminOnlyNote(),
                        ],
                      ),
                      const SizedBox(height: Insets.sectionGap),
                      AppSection(
                        title: 'How to reach ${you ? 'you' : 'them'}',
                        subtitle: 'Everyone signed in can see this. Leave it '
                            'blank if you would rather they did not.',
                        icon: Icons.contact_page_outlined,
                        children: [
                          AppTextField(
                            label: 'Email',
                            controller: _email,
                            optional: true,
                            icon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            textCapitalization: TextCapitalization.none,
                          ),
                          const SizedBox(height: Insets.md),
                          AppTextField(
                            label: 'Phone',
                            controller: _phone,
                            optional: true,
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                        ],
                      ),
                      if (widget.isAdmin) ...[
                        const SizedBox(height: Insets.sectionGap),
                        _deceasedSection(),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: Insets.lg),
                        AppNotice(message: _error!, tone: NoticeTone.danger),
                      ],
                    ],
                  ),
                ),
              ),
              _SaveBar(
                dirty: _dirty,
                saving: _saving,
                onSave: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoPicker(bool you) {
    final c = context.colors;

    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: Sizes.avatarXl,
                height: Sizes.avatarXl,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.accentSoft,
                  image: _photoUrl.isEmpty
                      ? null
                      : DecorationImage(
                          image: NetworkImage(_photoUrl),
                          fit: BoxFit.cover,
                        ),
                ),
                child: _uploadingPhoto
                    ? const Center(child: CircularProgressIndicator())
                    : _photoUrl.isEmpty
                        ? Icon(
                            Icons.person_rounded,
                            size: Sizes.iconXl,
                            color: c.accent,
                          )
                        : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Material(
                  color: c.accent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: _uploadingPhoto ? null : _pickPhoto,
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(Insets.xs),
                      child: Icon(
                        Icons.photo_camera_rounded,
                        size: Sizes.iconSm,
                        color: c.onAccent,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.xs),
          QuietButton(
            label: _photoUrl.isEmpty ? 'Add a photograph' : 'Change photograph',
            onPressed: _uploadingPhoto ? null : _pickPhoto,
          ),
          Text(
            you
                ? 'So your family recognises you in the tree.'
                : 'Shown on their card in the tree.',
            style: AppType.bodySmall.copyWith(color: context.colors.inkSoft),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _interestsField() {
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Interests', style: AppType.label.copyWith(color: c.ink)),
            const SizedBox(width: Insets.xs),
            Text('optional',
                style: AppType.caption.copyWith(color: c.inkMuted)),
          ],
        ),
        const SizedBox(height: Insets.xs),
        if (_interests.isNotEmpty) ...[
          Wrap(
            spacing: Insets.xs,
            runSpacing: Insets.xs,
            children: [
              for (final interest in _interests)
                Chip(
                  label: Text(interest),
                  onDeleted: () => _touch(
                    () => _interests =
                        _interests.where((i) => i != interest).toList(),
                  ),
                  deleteIcon: const Icon(Icons.close_rounded, size: 16),
                ),
            ],
          ),
          const SizedBox(height: Insets.xs),
        ],
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _interest,
                textCapitalization: TextCapitalization.words,
                onSubmitted: (_) => _addInterest(),
                style: AppType.body.copyWith(color: c.ink),
                decoration: const InputDecoration(
                  hintText: 'Football, cooking, poetry…',
                ),
              ),
            ),
            const SizedBox(width: Insets.xs),
            SizedBox(
              height: Sizes.control,
              child: SecondaryButton(
                label: 'Add',
                expand: false,
                onPressed: _addInterest,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _spouseInTree() {
    final c = context.colors;
    final names = widget.spouses.map((s) => s.fullName).join(', ');

    return Container(
      padding: const EdgeInsets.all(Insets.sm),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: Corners.medium,
      ),
      child: Row(
        children: [
          Icon(Icons.favorite_rounded, size: Sizes.iconSm, color: c.rose),
          const SizedBox(width: Insets.xs),
          Expanded(
            child: Text(
              'Married to $names',
              style: AppType.bodySmall.copyWith(color: c.ink),
            ),
          ),
        ],
      ),
    );
  }

  Widget _adminOnlyNote() {
    return const AppNotice(
      tone: NoticeTone.info,
      icon: Icons.lock_outline_rounded,
      message: 'Parents, children and marriages in the tree are set by an '
          'admin. Ask them if something here is wrong.',
    );
  }

  Widget _deceasedSection() {
    final c = context.colors;

    return AppSection(
      title: 'Admin only',
      subtitle: 'Members cannot set this about themselves.',
      icon: Icons.shield_outlined,
      children: [
        AppCard(
          tone: c.gold,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'This person has died',
                          style: AppType.bodyStrong.copyWith(color: c.ink),
                        ),
                        Text(
                          'Their record stays in the tree, marked.',
                          style: AppType.bodySmall.copyWith(color: c.inkSoft),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isDeceased,
                    onChanged: (v) => _touch(() {
                      _isDeceased = v;
                      if (!v) _deathDate = null;
                    }),
                  ),
                ],
              ),
              if (_isDeceased) ...[
                const SizedBox(height: Insets.md),
                AppPickerField(
                  label: 'Date of death',
                  optional: true,
                  icon: Icons.local_florist_outlined,
                  value: _deathDate == null ? null : _formatDate(_deathDate!),
                  placeholder: 'Choose a date',
                  helper: 'A family often knows before anyone can name the '
                      'date. Leaving it blank is fine.',
                  onTap: () => _pickDate(birth: false),
                  onClear: () => _touch(() => _deathDate = null),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _formatDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.dirty,
    required this.onClose,
  });

  final String title;
  final bool dirty;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: c.ground,
        border: Border(bottom: BorderSide(color: c.hairline)),
      ),
      child: Column(
        children: [
          const SizedBox(height: Insets.sm),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: c.hairline,
              borderRadius: Corners.pill,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.gutter,
              Insets.sm,
              Insets.xs,
              Insets.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: AppType.heading.copyWith(color: c.ink),
                        ),
                      ),
                      if (dirty) ...[
                        const SizedBox(width: Insets.xs),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: c.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.dirty,
    required this.saving,
    required this.onSave,
  });

  final bool dirty;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        Insets.gutter,
        Insets.sm,
        Insets.gutter,
        Insets.md,
      ),
      decoration: BoxDecoration(
        color: c.ground,
        border: Border(top: BorderSide(color: c.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!dirty && !saving) ...[
              Text(
                'Nothing to save yet',
                style: AppType.bodySmall.copyWith(color: c.inkMuted),
              ),
              const SizedBox(height: Insets.xs),
            ],
            PrimaryButton(
              label: 'Save',
              icon: Icons.check_rounded,
              busy: saving,
              busyLabel: 'Saving…',
              onPressed: dirty ? onSave : null,
            ),
          ],
        ),
      ),
    );
  }
}
