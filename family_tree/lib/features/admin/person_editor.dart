import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:image_picker/image_picker.dart';

import 'package:family_tree/core/config.dart';
import 'package:family_tree/data/services/api_service.dart';
import 'package:family_tree/data/services/storage_service.dart';
import 'package:family_tree/features/profile/photo_crop_sheet.dart';
import 'package:family_tree/core/design/typography.dart';
import 'package:family_tree/core/theme/elegant_theme.dart';
import 'package:family_tree/data/models/person.dart';

/// The admin artboard's palette, under the name the rest of that screen uses.
typedef ArtboardColors = ElegantColors;

/// The whole of a person's record, in one form.
///
/// Adding and editing used to be two separate dialogs that each decided for
/// themselves which fields were worth showing, and they drifted: an admin
/// could type an occupation when creating somebody and then had no way to
/// change it afterwards, because the edit dialog only ever offered a name, a
/// year and a biography. One form serves both, so a field added here is
/// editable the moment it is fillable.
///
/// Returns the person to save — with an empty id when creating — or null if
/// the admin backed out. The caller does the saving, because creating and
/// updating differ in ways this form has no business knowing about (birth
/// order shuffling, which endpoint to call).
Future<Person?> showPersonEditor({
  required BuildContext context,
  required List<Person> people,
  Person? existing,
  Person? preSelectedParent,
}) {
  return showDialog<Person>(
    context: context,
    builder: (context) => _PersonEditorDialog(
      people: people,
      existing: existing,
      preSelectedParent: preSelectedParent,
    ),
  );
}

class _PersonEditorDialog extends StatefulWidget {
  const _PersonEditorDialog({
    required this.people,
    this.existing,
    this.preSelectedParent,
  });

  final List<Person> people;
  final Person? existing;
  final Person? preSelectedParent;

  @override
  State<_PersonEditorDialog> createState() => _PersonEditorDialogState();
}

class _PersonEditorDialogState extends State<_PersonEditorDialog> {
  late final bool _isNew = widget.existing == null;

  late final _firstName =
      TextEditingController(text: widget.existing?.firstName ?? '');
  late final _lastName = TextEditingController(
      text: widget.existing?.lastName ??
          widget.preSelectedParent?.firstName ??
          '');
  late final _bio = TextEditingController(text: widget.existing?.bio ?? '');
  late final _occupation =
      TextEditingController(text: widget.existing?.occupation ?? '');
  late final _birthPlace =
      TextEditingController(text: widget.existing?.birthPlace ?? '');
  late final _residence =
      TextEditingController(text: widget.existing?.currentResidence ?? '');
  late final _education =
      TextEditingController(text: widget.existing?.education ?? '');
  late final _contactEmail =
      TextEditingController(text: widget.existing?.contactEmail ?? '');
  late final _contactPhone =
      TextEditingController(text: widget.existing?.contactPhone ?? '');
  late final _spouseName =
      TextEditingController(text: widget.existing?.spouseName ?? '');
  late String _photoUrl = widget.existing?.profilePhotoUrl ?? '';
  bool _uploadingPhoto = false;
  String? _photoError;

  /// The person's own gallery, and the events worth not losing. Both are on
  /// the record and shown on their card, and neither could be edited anywhere
  /// in the app before.
  late List<String> _photos =
      List<String>.from(widget.existing?.photos ?? const <String>[]);
  late List<LifeEvent> _lifeEvents =
      List<LifeEvent>.from(widget.existing?.lifeEvents ?? const <LifeEvent>[]);
  late final _interests =
      TextEditingController(text: widget.existing?.interests.join(', ') ?? '');

  /// The app is bilingual and the backend has always served a per-person
  /// Amharic name, but nothing in the app could ever write one.
  late final _amharicFirst =
      TextEditingController(text: _localized?.firstName ?? '');
  late final _amharicLast =
      TextEditingController(text: _localized?.lastName ?? '');

  LocalizedPersonName? get _localized => widget.existing?.localizedNames['am'];

  late String _gender = widget.existing?.gender ?? 'male';
  late String _maritalStatus = widget.existing?.maritalStatus ?? '';
  late DateTime? _birthDate = widget.existing?.birthDate;
  late DateTime? _deathDate = widget.existing?.deathDate;
  late bool _isDeceased = widget.existing?.isDeceasedFlag ?? false;
  late int _displayOrder = (widget.existing?.displayOrder ?? 0) > 0
      ? widget.existing!.displayOrder
      : 1;

  /// Descent is stored as a list of parents. The app has always written only
  /// the first, so a mother could be recorded by nobody — this exposes both.
  late String? _fatherId = _parentAt(0);
  late String? _motherId = _parentAt(1);

  String? _parentAt(int index) {
    final ids = widget.existing?.relationships.parentIds ??
        (widget.preSelectedParent == null
            ? const <String>[]
            : <String>[widget.preSelectedParent!.id]);
    return index < ids.length ? ids[index] : null;
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
      _contactEmail,
      _contactPhone,
      _spouseName,
      _interests,
      _amharicFirst,
      _amharicLast,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Nobody can be their own parent, and nobody below them can be either —
  /// that is how the tree grows a loop the canvas then walks forever.
  Set<String> get _ownSubtree {
    final self = widget.existing;
    if (self == null) return const {};
    final byParent = <String, List<Person>>{};
    for (final p in widget.people) {
      for (final parent in p.relationships.parentIds) {
        byParent.putIfAbsent(parent, () => []).add(p);
      }
    }
    final found = <String>{self.id};
    final queue = <String>[self.id];
    while (queue.isNotEmpty) {
      for (final child in byParent[queue.removeAt(0)] ?? const <Person>[]) {
        if (found.add(child.id)) queue.add(child.id);
      }
    }
    return found;
  }

  Person _result() {
    String? filled(TextEditingController c) {
      final text = c.text.trim();
      return text.isEmpty ? null : text;
    }

    final parentIds = <String>[
      if (_fatherId != null) _fatherId!,
      if (_motherId != null) _motherId!,
    ];

    final base = widget.existing;
    final relationships =
        (base?.relationships ?? Relationships()).copyWith(parentIds: parentIds);

    if (base != null) {
      return base.copyWith(
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        gender: _gender,
        birthDate: _birthDate,
        deathDate: _deathDate,
        clearBirthDate: _birthDate == null,
        clearDeathDate: _deathDate == null,
        isDeceasedFlag: _isDeceased,
        bio: _bio.text.trim(),
        occupation: _occupation.text.trim(),
        birthPlace: _birthPlace.text.trim(),
        currentResidence: _residence.text.trim(),
        education: _education.text.trim(),
        contactEmail: _contactEmail.text.trim(),
        contactPhone: _contactPhone.text.trim(),
        maritalStatus: _maritalStatus,
        spouseName: _spouseName.text.trim(),
        profilePhotoUrl: _photoUrl,
        photos: _photos,
        lifeEvents: _lifeEvents,
        interests: _splitInterests(),
        localizedNames: _localizedNames(),
        relationships: relationships,
        displayOrder: _displayOrder,
        updatedAt: DateTime.now(),
      );
    }

    return Person(
      id: '',
      familyTreeId: AppConfig.familyTreeId,
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      gender: _gender,
      birthDate: _birthDate,
      deathDate: _deathDate,
      isDeceasedFlag: _isDeceased,
      bio: filled(_bio),
      occupation: filled(_occupation),
      birthPlace: filled(_birthPlace),
      currentResidence: filled(_residence),
      education: filled(_education),
      contactEmail: filled(_contactEmail),
      contactPhone: filled(_contactPhone),
      maritalStatus: _maritalStatus.isEmpty ? null : _maritalStatus,
      spouseName: filled(_spouseName),
      profilePhotoUrl: _photoUrl.isEmpty ? null : _photoUrl,
      photos: _photos,
      lifeEvents: _lifeEvents,
      interests: _splitInterests(),
      localizedNames: _localizedNames(),
      relationships: relationships,
      displayOrder: _displayOrder,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Only kept when something was actually typed, so an untouched form does
  /// not write an empty Amharic name over whatever the backend had.
  Map<String, LocalizedPersonName> _localizedNames() {
    final first = _amharicFirst.text.trim();
    final last = _amharicLast.text.trim();
    final existing = Map<String, LocalizedPersonName>.from(
        widget.existing?.localizedNames ?? const {});
    if (first.isEmpty && last.isEmpty) {
      existing.remove('am');
    } else {
      existing['am'] = LocalizedPersonName(firstName: first, lastName: last);
    }
    return existing;
  }

  List<String> _splitInterests() => _interests.text
      .split(',')
      .map((i) => i.trim())
      .where((i) => i.isNotEmpty)
      .toList();

  void _submit() {
    if (_firstName.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a first name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    Navigator.of(context).pop(_result());
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: ArtboardColors.warmWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _section('Name'),
                    _field(_firstName, 'First name *', Icons.person_rounded,
                        capitalise: true),
                    _gap(),
                    _field(_lastName, "Father's name", Icons.person_outline,
                        capitalise: true),
                    _gap(),
                    _genderRow(),
                    _section('Amharic name'),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        'Shown to anyone reading the tree in አማርኛ. Leave it '
                        'blank to fall back to the English name.',
                        style: AppType.sans(
                            fontSize: 12, color: ArtboardColors.warmGray),
                      ),
                    ),
                    _field(_amharicFirst, 'የመጀመሪያ ስም — first name',
                        Icons.translate_rounded),
                    _gap(),
                    _field(_amharicLast, 'የአባት ስም — father\'s name',
                        Icons.translate_rounded),
                    _section('Descent'),
                    _parentPicker(
                      label: 'Father',
                      selectedId: _fatherId,
                      onPicked: (id) => setState(() => _fatherId = id),
                    ),
                    _gap(),
                    _parentPicker(
                      label: 'Mother',
                      selectedId: _motherId,
                      onPicked: (id) => setState(() => _motherId = id),
                    ),
                    _gap(),
                    _birthOrderRow(),
                    _section('Life'),
                    Row(
                      children: [
                        Expanded(
                          child: _dateField(
                            'Born',
                            _birthDate,
                            (d) => setState(() => _birthDate = d),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _dateField(
                            'Died',
                            _deathDate,
                            (d) => setState(() {
                              _deathDate = d;
                              if (d != null) _isDeceased = true;
                            }),
                          ),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      activeThumbColor: ArtboardColors.terracotta,
                      value: _isDeceased,
                      onChanged: (v) => setState(() => _isDeceased = v),
                      title: Text('Has passed away',
                          style: AppType.sans(
                              fontSize: 14, color: ArtboardColors.charcoal)),
                      subtitle: Text(
                        'The date can be left blank if nobody remembers it.',
                        style: AppType.sans(
                            fontSize: 12, color: ArtboardColors.warmGray),
                      ),
                    ),
                    _section('Marriage'),
                    _maritalStatusField(),
                    _gap(),
                    _field(_spouseName, 'Spouse name', Icons.favorite_rounded,
                        capitalise: true,
                        helper: 'Type the name — they do not need to be in '
                            'the tree.'),
                    _section('About'),
                    _field(_occupation, 'Occupation', Icons.work_outline),
                    _gap(),
                    _field(_education, 'Education', Icons.school_outlined),
                    _gap(),
                    _field(_interests, 'Interests', Icons.interests_outlined,
                        helper: 'Separate them with commas.'),
                    _gap(),
                    _field(_bio, 'About them', Icons.notes_rounded,
                        maxLines: 3),
                    _section('Places'),
                    _field(_birthPlace, 'Born in', Icons.place_outlined,
                        capitalise: true),
                    _gap(),
                    _field(_residence, 'Lives in', Icons.home_outlined,
                        capitalise: true),
                    _section('Contact'),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        'Kept inside the family — the public tree never shows '
                        'these.',
                        style: AppType.sans(
                            fontSize: 12, color: ArtboardColors.warmGray),
                      ),
                    ),
                    _field(_contactPhone, 'Phone', Icons.phone_outlined,
                        keyboard: TextInputType.phone),
                    _gap(),
                    _field(_contactEmail, 'Email', Icons.mail_outline_rounded,
                        keyboard: TextInputType.emailAddress, noSpaces: true),
                    _section('Photo'),
                    _photoPicker(),
                    _section('Gallery'),
                    _galleryEditor(),
                    _section('Life events'),
                    _lifeEventsEditor(),
                  ],
                ),
              ),
            ),
            _actions(),
          ],
        ),
      ),
    );
  }

  // ── pieces ───────────────────────────────────────────────────────────────

  Widget _gap() => const SizedBox(height: 12);

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ArtboardColors.terracotta.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ArtboardColors.terracotta,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isNew ? Icons.person_add_alt_1 : Icons.edit_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isNew ? 'Add a person' : 'Edit ${widget.existing!.firstName}',
              style: AppType.sans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: ArtboardColors.charcoal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Row(
        children: [
          Container(width: 3, height: 14, color: ArtboardColors.terracotta),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: AppType.sans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: ArtboardColors.warmGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
    String? helper,
    bool capitalise = false,
    bool noSpaces = false,
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboard,
      textCapitalization:
          capitalise ? TextCapitalization.words : TextCapitalization.sentences,
      inputFormatters:
          noSpaces ? [FilteringTextInputFormatter.deny(RegExp(r'\s'))] : null,
      style: AppType.sans(fontSize: 16, color: ArtboardColors.charcoal),
      decoration: _decoration(label, icon, helper),
    );
  }

  InputDecoration _decoration(String label, IconData icon, String? helper) {
    return InputDecoration(
      labelText: label,
      labelStyle: AppType.sans(color: ArtboardColors.warmGray),
      helperText: helper,
      helperMaxLines: 2,
      helperStyle: AppType.sans(fontSize: 11, color: ArtboardColors.warmGray),
      prefixIcon: Icon(icon, color: ArtboardColors.warmGray, size: 20),
      filled: true,
      fillColor: ArtboardColors.cream,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: ArtboardColors.champagne),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: ArtboardColors.champagne),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: ArtboardColors.terracotta, width: 2),
      ),
    );
  }

  Widget _genderRow() {
    Widget chip(String value, String label, IconData icon, Color colour) {
      final selected = _gender == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _gender = value),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? colour.withValues(alpha: 0.15)
                  : ArtboardColors.cream,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? colour : ArtboardColors.champagne,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 20,
                    color: selected ? colour : ArtboardColors.warmGray),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppType.sans(
                    color: selected ? colour : ArtboardColors.warmGray,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        chip('male', 'Male', Icons.male, Colors.blue),
        const SizedBox(width: 12),
        chip('female', 'Female', Icons.female, Colors.pink),
      ],
    );
  }

  Widget _maritalStatusField() {
    return DropdownButtonFormField<String>(
      initialValue: _maritalStatus.isEmpty ? '' : _maritalStatus,
      isExpanded: true,
      style: AppType.sans(fontSize: 16, color: ArtboardColors.charcoal),
      dropdownColor: ArtboardColors.warmWhite,
      decoration:
          _decoration('Marital status', Icons.favorite_outline_rounded, null),
      items: const [
        DropdownMenuItem(value: '', child: Text('Not stated')),
        DropdownMenuItem(value: 'single', child: Text('Single')),
        DropdownMenuItem(value: 'married', child: Text('Married')),
        DropdownMenuItem(value: 'divorced', child: Text('Divorced')),
        DropdownMenuItem(value: 'widowed', child: Text('Widowed')),
      ],
      onChanged: (v) => setState(() => _maritalStatus = v ?? ''),
    );
  }

  /// Both parents are chosen the same way, from the people already in the
  /// tree. "Nobody" is a real answer — it is what makes somebody a root.
  Widget _parentPicker({
    required String label,
    required String? selectedId,
    required ValueChanged<String?> onPicked,
  }) {
    final blocked = _ownSubtree;
    final candidates =
        widget.people.where((p) => !blocked.contains(p.id)).toList()
          ..sort((a, b) => a.fullName.toLowerCase().compareTo(
                b.fullName.toLowerCase(),
              ));

    // A parent who is no longer a valid choice (they are in this person's own
    // subtree) would otherwise vanish silently from the dropdown and be
    // dropped on save, so the value is only kept when it is still offered.
    final value = candidates.any((p) => p.id == selectedId) ? selectedId : null;

    return DropdownButtonFormField<String?>(
      initialValue: value,
      isExpanded: true,
      style: AppType.sans(fontSize: 16, color: ArtboardColors.charcoal),
      dropdownColor: ArtboardColors.warmWhite,
      decoration: _decoration(
        label,
        label == 'Mother' ? Icons.woman_rounded : Icons.man_rounded,
        null,
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('Nobody in the tree'),
        ),
        for (final p in candidates)
          DropdownMenuItem<String?>(
            value: p.id,
            child: Text(p.fullName, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onPicked,
    );
  }

  Widget _birthOrderRow() {
    return Row(
      children: [
        Icon(Icons.format_list_numbered,
            color: ArtboardColors.warmGray, size: 20),
        const SizedBox(width: 10),
        Text(
          'Birth order',
          style: AppType.sans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: ArtboardColors.charcoal,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: ArtboardColors.cream,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ArtboardColors.champagne),
          ),
          child: DropdownButton<int>(
            value: _displayOrder.clamp(1, 30),
            underline: const SizedBox(),
            dropdownColor: ArtboardColors.warmWhite,
            style: AppType.sans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: ArtboardColors.charcoal,
            ),
            items: [
              for (var n = 1; n <= 30; n++)
                DropdownMenuItem(value: n, child: Text(_ordinal(n))),
            ],
            onChanged: (v) => setState(() => _displayOrder = v ?? 1),
          ),
        ),
      ],
    );
  }

  static String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    return switch (n % 10) {
      1 => '${n}st',
      2 => '${n}nd',
      3 => '${n}rd',
      _ => '${n}th',
    };
  }

  Widget _dateField(
    String label,
    DateTime? value,
    ValueChanged<DateTime?> onPick,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime(1980),
          firstDate: DateTime(1700),
          lastDate: DateTime.now(),
        );
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: _decoration(label, Icons.event_outlined, null).copyWith(
          suffixIcon: value == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  color: ArtboardColors.warmGray,
                  tooltip: 'Clear',
                  onPressed: () => onPick(null),
                ),
        ),
        child: Text(
          value == null ? 'Not known' : _formatDate(value),
          style: AppType.sans(
            fontSize: 15,
            color: value == null
                ? ArtboardColors.warmGray
                : ArtboardColors.charcoal,
          ),
        ),
      ),
    );
  }

  // ── photo, gallery, life events ──────────────────────────────────────────

  /// Picks, frames and uploads one image, returning the stored URL.
  ///
  /// Framing before upload means the stored file already is the square every
  /// card shows, rather than every card cropping a rectangle at display time.
  Future<String?> _pickAndUpload(String title) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return null;

    final original = await picked.readAsBytes();
    if (!mounted) return null;

    final cropped =
        await PhotoCropSheet.show(context, bytes: original, title: title);
    if (cropped == null || !mounted) return null;

    return StorageService()
        .uploadProfilePhoto(cropped, '${picked.name}_square.png');
  }

  Future<void> _pickProfilePhoto() async {
    setState(() {
      _uploadingPhoto = true;
      _photoError = null;
    });
    try {
      final url = await _pickAndUpload(
          'Position ${_firstName.text.trim().isEmpty ? 'the' : "${_firstName.text.trim()}’s"} photo');
      if (!mounted) return;
      setState(() {
        if (url != null) _photoUrl = url;
        _uploadingPhoto = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _uploadingPhoto = false;
        _photoError = 'Could not upload the photo. ${messageForError(error)}';
      });
    }
  }

  Widget _photoPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ArtboardColors.cream,
                border: Border.all(color: ArtboardColors.champagne),
                image: _photoUrl.isEmpty
                    ? null
                    : DecorationImage(
                        image: NetworkImage(_photoUrl),
                        fit: BoxFit.cover,
                      ),
              ),
              child: _photoUrl.isEmpty
                  ? Icon(Icons.person_rounded,
                      size: 32, color: ArtboardColors.warmGray)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton.icon(
                    onPressed: _uploadingPhoto ? null : _pickProfilePhoto,
                    icon: _uploadingPhoto
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_rounded, size: 18),
                    label: Text(
                      _uploadingPhoto
                          ? 'Uploading…'
                          : (_photoUrl.isEmpty
                              ? 'Choose a photo'
                              : 'Replace photo'),
                      style: AppType.sans(),
                    ),
                  ),
                  if (_photoUrl.isNotEmpty)
                    TextButton.icon(
                      onPressed: _uploadingPhoto
                          ? null
                          : () => setState(() => _photoUrl = ''),
                      icon: Icon(Icons.delete_outline_rounded,
                          size: 18, color: ArtboardColors.rust),
                      label: Text('Remove',
                          style: AppType.sans(color: ArtboardColors.rust)),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (_photoError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_photoError!,
                style: AppType.sans(fontSize: 12, color: ArtboardColors.rust)),
          ),
      ],
    );
  }

  Future<void> _addGalleryPhoto() async {
    try {
      final url = await _pickAndUpload('Position the photo');
      if (url == null || !mounted) return;
      setState(() => _photos = [..._photos, url]);
    } catch (error) {
      if (!mounted) return;
      setState(() => _photoError =
          'Could not upload the photo. ${messageForError(error)}');
    }
  }

  Widget _galleryEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_photos.isEmpty)
          Text('No photos yet.',
              style: AppType.sans(fontSize: 13, color: ArtboardColors.warmGray))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final url in _photos)
                Stack(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: ArtboardColors.champagne),
                        image: DecorationImage(
                          image: NetworkImage(url),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: GestureDetector(
                        onTap: () => setState(() =>
                            _photos = _photos.where((p) => p != url).toList()),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _addGalleryPhoto,
          icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
          label: Text('Add a photo', style: AppType.sans()),
        ),
      ],
    );
  }

  Future<void> _editLifeEvent({LifeEvent? existing}) async {
    final result = await showDialog<LifeEvent>(
      context: context,
      builder: (context) => _LifeEventDialog(existing: existing),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (existing == null) {
        _lifeEvents = [..._lifeEvents, result];
      } else {
        _lifeEvents = [
          for (final e in _lifeEvents)
            if (e.id == existing.id) result else e,
        ];
      }
      _lifeEvents.sort((a, b) => a.date.compareTo(b.date));
    });
  }

  Widget _lifeEventsEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_lifeEvents.isEmpty)
          Text('Nothing recorded yet.',
              style: AppType.sans(fontSize: 13, color: ArtboardColors.warmGray))
        else
          for (final event in _lifeEvents)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: ArtboardColors.cream,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ArtboardColors.champagne),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event.title,
                            style: AppType.sans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: ArtboardColors.charcoal)),
                        Text(
                          [
                            _formatDate(event.date),
                            if ((event.location ?? '').trim().isNotEmpty)
                              event.location!.trim(),
                          ].join(' · '),
                          style: AppType.sans(
                              fontSize: 12, color: ArtboardColors.warmGray),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    color: ArtboardColors.warmGray,
                    tooltip: 'Edit',
                    onPressed: () => _editLifeEvent(existing: event),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    color: ArtboardColors.rust,
                    tooltip: 'Remove',
                    onPressed: () => setState(() => _lifeEvents =
                        _lifeEvents.where((e) => e.id != event.id).toList()),
                  ),
                ],
              ),
            ),
        TextButton.icon(
          onPressed: () => _editLifeEvent(),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text('Add an event', style: AppType.sans()),
        ),
      ],
    );
  }

  Widget _actions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: ArtboardColors.champagne)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel',
                style: AppType.sans(color: ArtboardColors.warmGray)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ArtboardColors.terracotta,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _submit,
            child: Text(
              _isNew ? 'Add' : 'Save',
              style: AppType.sans(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

/// One life event: what happened, when, where, in as few boxes as that needs.
class _LifeEventDialog extends StatefulWidget {
  const _LifeEventDialog({this.existing});

  final LifeEvent? existing;

  @override
  State<_LifeEventDialog> createState() => _LifeEventDialogState();
}

class _LifeEventDialogState extends State<_LifeEventDialog> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _description =
      TextEditingController(text: widget.existing?.description ?? '');
  late final _location =
      TextEditingController(text: widget.existing?.location ?? '');
  late DateTime _date = widget.existing?.date ?? DateTime.now();

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        labelStyle: AppType.sans(color: ArtboardColors.warmGray),
        prefixIcon: Icon(icon, color: ArtboardColors.warmGray, size: 20),
        filled: true,
        fillColor: ArtboardColors.cream,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ArtboardColors.champagne),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: ArtboardColors.warmWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        widget.existing == null ? 'Add an event' : 'Edit event',
        style: AppType.sans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: ArtboardColors.charcoal,
        ),
      ),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                style: AppType.sans(fontSize: 16),
                decoration: _decoration('What happened *', Icons.event_note),
              ),
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(1700),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
                child: InputDecorator(
                  decoration: _decoration('When', Icons.event_outlined),
                  child: Text(
                    _formatDate(_date),
                    style: AppType.sans(
                        fontSize: 15, color: ArtboardColors.charcoal),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _location,
                textCapitalization: TextCapitalization.words,
                style: AppType.sans(fontSize: 16),
                decoration: _decoration('Where', Icons.place_outlined),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                style: AppType.sans(fontSize: 16),
                decoration: _decoration('More about it', Icons.notes_rounded),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel',
              style: AppType.sans(color: ArtboardColors.warmGray)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: ArtboardColors.terracotta,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            if (_title.text.trim().isEmpty) return;
            Navigator.of(context).pop(LifeEvent(
              // Keeping the id means editing replaces the event rather than
              // adding a second copy of it.
              id: widget.existing?.id ??
                  DateTime.now().microsecondsSinceEpoch.toString(),
              title: _title.text.trim(),
              description: _description.text.trim().isEmpty
                  ? null
                  : _description.text.trim(),
              date: _date,
              location:
                  _location.text.trim().isEmpty ? null : _location.text.trim(),
              photos: widget.existing?.photos ?? const [],
            ));
          },
          child: Text('Save',
              style: AppType.sans(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

/// Shared by the editor and its life-event dialog.
String _formatDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}
