import 'package:flutter/material.dart';

import 'package:family_tree/core/design/design.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/data/repositories/person_repository.dart';
import 'package:family_tree/data/services/api_service.dart';

/// Rewiring the tree: who somebody's parents are, and who they married.
///
/// An admin could add people and delete them but never move one, so a relative
/// filed under the wrong branch — which is how most family trees start — could
/// only be fixed by deleting them and everything below them and typing it all
/// in again. Spouses had no editor at all.
///
/// Moving somebody carries their whole subtree with them, which is what makes
/// it worth doing carefully: the sheet says how many people are about to move,
/// and refuses a move that would put somebody below their own descendant. The
/// server refuses that too — this is here so the reason arrives before the
/// tap, not after it.
Future<bool?> showRelationshipsSheet(
  BuildContext context, {
  required Person person,
  required List<Person> people,
  required Future<void> Function(Person updated) onSave,
}) {
  return showAppSheet<bool>(
    context: context,
    title: 'Where ${person.firstName} belongs',
    subtitle: 'Parents and marriages',
    initialSize: 0.88,
    body: (context, scroll) => _RelationshipsForm(
      person: person,
      people: people,
      onSave: onSave,
      scroll: scroll,
    ),
  );
}

class _RelationshipsForm extends StatefulWidget {
  const _RelationshipsForm({
    required this.person,
    required this.people,
    required this.onSave,
    required this.scroll,
  });

  final Person person;
  final List<Person> people;
  final Future<void> Function(Person updated) onSave;
  final ScrollController scroll;

  @override
  State<_RelationshipsForm> createState() => _RelationshipsFormState();
}

class _RelationshipsFormState extends State<_RelationshipsForm> {
  late final FamilyIndex _index = FamilyIndex(widget.people);

  late List<String> _parentIds =
      List<String>.from(widget.person.relationships.parentIds);
  late List<RelationshipConnection> _spouses =
      List<RelationshipConnection>.from(widget.person.relationships.spouses);

  /// A spouse married in from outside the family usually has no record to
  /// point at, so their name is typed rather than picked.
  late final TextEditingController _spouseName =
      TextEditingController(text: widget.person.spouseName ?? '');

  bool _saving = false;
  bool _dirty = false;
  String? _error;

  /// Everyone below this person, plus this person. Nobody in here can become
  /// their parent without making a loop.
  late final Set<String> _ownSubtree = _descendantsOf(widget.person.id);

  Set<String> _descendantsOf(String rootId) {
    final found = <String>{rootId};
    final queue = <String>[rootId];
    while (queue.isNotEmpty) {
      final current = _index.byId(queue.removeAt(0));
      if (current == null) continue;
      for (final child in _index.childrenOf(current)) {
        if (found.add(child.id)) queue.add(child.id);
      }
    }
    return found;
  }

  /// How many people move with them. A parent taking eleven descendants to a
  /// different branch is a different decision from a leaf moving alone.
  int get _movingCount => _ownSubtree.length;

  void _touch(VoidCallback change) => setState(() {
        change();
        _dirty = true;
        _error = null;
      });

  @override
  void dispose() {
    _spouseName.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    final updated = widget.person.copyWith(
      spouseName: _spouseName.text.trim(),
      relationships: widget.person.relationships.copyWith(
        parentIds: _parentIds,
        spouses: _spouses,
      ),
      updatedAt: DateTime.now(),
    );

    try {
      await widget.onSave(updated);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      Toast.success(context, 'Saved.');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = messageForError(error);
      });
    }
  }

  Future<void> _pickPerson({
    required String title,
    required String subtitle,
    required bool Function(Person) allowed,
    required ValueChanged<Person> onPicked,
  }) async {
    final picked = await showAppSheet<Person>(
      context: context,
      title: title,
      subtitle: subtitle,
      initialSize: 0.8,
      body: (context, scroll) => _PersonPicker(
        people: widget.people.where(allowed).toList(),
        index: _index,
        scroll: scroll,
      ),
    );
    if (picked != null) onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final parents = _parentIds.map(_index.byId).whereType<Person>().toList();

    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: widget.scroll,
            padding: const EdgeInsets.all(Insets.gutter),
            children: [
              AppSection(
                title: 'Parents',
                subtitle: parents.isEmpty
                    ? '${widget.person.firstName} is at the top of the tree.'
                    : 'Changing these moves ${widget.person.firstName} to a '
                        'different branch.',
                icon: Icons.arrow_upward_rounded,
                gap: Insets.sm,
                children: [
                  for (final parent in parents)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Insets.xs),
                      child: _PersonRow(
                        person: parent,
                        index: _index,
                        onRemove: () => _touch(
                          () => _parentIds = _parentIds
                              .where((id) => id != parent.id)
                              .toList(),
                        ),
                      ),
                    ),
                  if (_parentIds.length < 2)
                    SecondaryButton(
                      label: parents.isEmpty
                          ? 'Set a parent'
                          : 'Add the other parent',
                      icon: Icons.add_rounded,
                      onPressed: () => _pickPerson(
                        title: 'Who is the parent?',
                        subtitle: 'People below ${widget.person.firstName} are '
                            'not shown — that would make a loop.',
                        allowed: (p) =>
                            !_ownSubtree.contains(p.id) &&
                            !_parentIds.contains(p.id),
                        onPicked: (p) =>
                            _touch(() => _parentIds = [..._parentIds, p.id]),
                      ),
                    ),
                  if (parents.isNotEmpty && _movingCount > 1) ...[
                    const SizedBox(height: Insets.xs),
                    AppNotice(
                      tone: NoticeTone.warning,
                      message: 'Moving ${widget.person.firstName} takes '
                          '${_movingCount - 1} '
                          '${_movingCount == 2 ? 'descendant' : 'descendants'} '
                          'along with them.',
                    ),
                  ],
                ],
              ),
              const SizedBox(height: Insets.sectionGap),
              AppSection(
                title: 'Marriages',
                subtitle: 'Type the name of whoever they married. Linking to '
                    'somebody already in the tree is optional.',
                icon: Icons.favorite_outline_rounded,
                gap: Insets.sm,
                children: [
                  AppTextField(
                    label: 'Spouse name',
                    controller: _spouseName,
                    hint: 'Fatuma Ahmed',
                    icon: Icons.favorite_rounded,
                    textCapitalization: TextCapitalization.words,
                    helper: 'They do not need a record of their own — most '
                        'people who marry into the family never get one.',
                    onChanged: (_) => _touch(() {}),
                  ),
                  const SizedBox(height: Insets.sm),
                  for (final spouse in _spouses)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Insets.xs),
                      child: _SpouseRow(
                        connection: spouse,
                        person: _index.byId(spouse.personId),
                        onRemove: () => _touch(
                          () => _spouses = _spouses
                              .where((s) => s.personId != spouse.personId)
                              .toList(),
                        ),
                      ),
                    ),
                  SecondaryButton(
                    label: 'Link to someone in the tree',
                    icon: Icons.add_rounded,
                    onPressed: () => _pickPerson(
                      title: 'Married to whom?',
                      subtitle: 'Pick the other person in the tree.',
                      allowed: (p) =>
                          p.id != widget.person.id &&
                          !_spouses.any((s) => s.personId == p.id),
                      onPicked: (p) => _touch(
                        () => _spouses = [
                          ..._spouses,
                          RelationshipConnection(
                            personId: p.id,
                            type: RelationshipType.marriage,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: Insets.lg),
                AppNotice(message: _error!, tone: NoticeTone.danger),
              ],
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(Insets.gutter),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(top: BorderSide(color: c.hairline)),
          ),
          child: SafeArea(
            top: false,
            child: PrimaryButton(
              label: 'Save',
              icon: Icons.check_rounded,
              busy: _saving,
              busyLabel: 'Saving…',
              onPressed: _dirty ? _save : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.person,
    required this.index,
    required this.onRemove,
  });

  final Person person;
  final FamilyIndex index;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final childCount = index.childrenOf(person).length;

    return AppCard(
      padding: const EdgeInsets.all(Insets.xs),
      child: Row(
        children: [
          PersonAvatar(person: person, size: Sizes.avatarSm),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.fullName,
                  style: AppType.bodyStrong.copyWith(color: c.ink),
                ),
                if (childCount > 0)
                  Text(
                    '$childCount ${childCount == 1 ? 'child' : 'children'}',
                    style: AppType.caption.copyWith(color: c.inkMuted),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
            color: c.inkMuted,
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}

class _SpouseRow extends StatelessWidget {
  const _SpouseRow({
    required this.connection,
    required this.person,
    required this.onRemove,
  });

  final RelationshipConnection connection;

  /// Null when the record has been deleted from the tree but the marriage
  /// still names it. Showing it as missing is better than hiding it, because
  /// the only way to clear it is to see it.
  final Person? person;

  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return AppCard(
      padding: const EdgeInsets.all(Insets.xs),
      tone: person == null ? c.warning : null,
      child: Row(
        children: [
          if (person != null)
            PersonAvatar(person: person!, size: Sizes.avatarSm)
          else
            Container(
              width: Sizes.avatarSm,
              height: Sizes.avatarSm,
              decoration: BoxDecoration(
                color: c.warning.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_off_outlined,
                size: Sizes.iconSm,
                color: c.warning,
              ),
            ),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              person?.fullName ?? 'Someone no longer in the tree',
              style: AppType.bodyStrong.copyWith(
                color: person == null ? c.inkSoft : c.ink,
              ),
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
            color: c.inkMuted,
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}

/// Search the tree and pick one person.
class _PersonPicker extends StatefulWidget {
  const _PersonPicker({
    required this.people,
    required this.index,
    required this.scroll,
  });

  final List<Person> people;
  final FamilyIndex index;
  final ScrollController scroll;

  @override
  State<_PersonPicker> createState() => _PersonPickerState();
}

class _PersonPickerState extends State<_PersonPicker> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Person> get _matches {
    final matches = _query.trim().isEmpty
        ? [...widget.people]
        : widget.people.where((p) => p.matchesNameQuery(_query)).toList();
    matches.sort(
      (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
    );
    return matches;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final matches = _matches;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(Insets.gutter),
          child: TextField(
            controller: _search,
            autofocus: true,
            onChanged: (q) => setState(() => _query = q),
            style: AppType.body.copyWith(color: c.ink),
            decoration: const InputDecoration(
              hintText: 'Search by name',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
        ),
        Expanded(
          child: matches.isEmpty
              ? const AppEmptyState(
                  icon: Icons.person_search_rounded,
                  title: 'Nobody here',
                  message: 'No one in the tree matches, or everybody who could '
                      'be picked already is.',
                )
              : ListView.separated(
                  controller: widget.scroll,
                  padding: const EdgeInsets.fromLTRB(
                    Insets.gutter,
                    0,
                    Insets.gutter,
                    Insets.xl,
                  ),
                  itemCount: matches.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: Insets.xs),
                  itemBuilder: (context, i) {
                    final person = matches[i];
                    final parents = person.relationships.parentIds
                        .map(widget.index.byId)
                        .whereType<Person>()
                        .map((p) => p.firstName)
                        .join(' and ');

                    return AppCard(
                      padding: const EdgeInsets.all(Insets.xs),
                      onTap: () => Navigator.of(context).pop(person),
                      child: Row(
                        children: [
                          PersonAvatar(person: person, size: Sizes.avatarSm),
                          const SizedBox(width: Insets.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  person.fullName,
                                  style:
                                      AppType.bodyStrong.copyWith(color: c.ink),
                                ),
                                Text(
                                  parents.isEmpty
                                      ? 'Top of the family'
                                      : 'Child of $parents',
                                  style: AppType.caption
                                      .copyWith(color: c.inkMuted),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: c.inkMuted,
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
