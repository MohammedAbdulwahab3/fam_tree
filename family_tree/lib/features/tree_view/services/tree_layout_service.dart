import 'dart:ui';

import 'package:family_tree/data/models/person.dart';

/// Positions every person on the canvas.
///
/// Two things about family data make this harder than laying out a plain tree,
/// and this used to get both wrong.
///
/// A child normally has two parents. The old version walked each person's
/// children and appended the child node to whichever parent it was visiting, so
/// a child with two parents in the tree was added to both parents' child lists,
/// had its parent pointer overwritten by whoever came last, and had its whole
/// subtree measured and positioned twice — the second pass overwriting the
/// first. Here each child is claimed by exactly one parent, and the other
/// parent's link is left to the canvas, which draws every parent-to-child line
/// from the family index and so connects both parents without either of them
/// distorting the layout.
///
/// And family data contains cycles. Nothing stops the admin screen from making
/// someone their own ancestor, and the old recursion had no visited set, so a
/// single bad edge was a stack overflow rather than a message.
class TreeLayoutService {
  static const double nodeWidth = 120.0;
  static const double nodeHeight = 160.0;
  static const double siblingSpacing = 40.0;
  static const double subtreeSpacing = 60.0;
  static const double defaultLevelSeparation = 400.0;

  /// Calculate positions for a list of persons.
  static Map<String, Offset> calculateTreeLayout(
    List<Person> persons, {
    double? levelSeparation,
  }) =>
      calculate(persons, levelSeparation: levelSeparation).positions;

  /// Calculate a full layout: where each person sits, and which generation
  /// they belong to.
  static TreeLayout calculate(
    List<Person> persons, {
    double? levelSeparation,
  }) {
    if (persons.isEmpty) return TreeLayout.empty;

    final separation = levelSeparation ?? defaultLevelSeparation;
    final build = _buildForest(persons);

    double currentX = 0;
    final positions = <String, Offset>{};
    final generations = <String, int>{};

    for (final root in build.roots) {
      _measure(root);
      _place(root, currentX, 0, separation);
      _collect(root, 0, positions, generations);
      currentX += root.width + subtreeSpacing;
    }

    return TreeLayout(positions: positions, generations: generations);
  }

  /// Build a forest in which every person appears exactly once.
  static _Forest _buildForest(List<Person> persons) {
    final nodes = {for (final p in persons) p.id: _TreeNode(p)};
    final claimedBy = <String, String>{};

    for (final person in persons) {
      for (final parentId in person.relationships.parentIds) {
        final parent = nodes[parentId];
        if (parent == null) continue;

        // Never let a person become their own descendant, however the data got
        // that way.
        if (parentId == person.id ||
            _isDescendantOf(claimedBy, parentId, person.id)) {
          continue;
        }

        // The first parent seen claims the child. A second parent is real and
        // still gets a connecting line on the canvas, but the child occupies
        // one place in the tree rather than two.
        if (claimedBy.containsKey(person.id)) continue;

        claimedBy[person.id] = parentId;
        parent.children.add(nodes[person.id]!);
        nodes[person.id]!.parent = parent;
      }
    }

    return _Forest(nodes.values.where((n) => n.parent == null).toList());
  }

  /// Walk up the claimed-parent chain to see whether [ancestorId] already sits
  /// below [descendantId]. Bounded by the chain length, and stops on a repeat.
  static bool _isDescendantOf(
    Map<String, String> claimedBy,
    String ancestorId,
    String descendantId,
  ) {
    final seen = <String>{};
    String? current = ancestorId;
    while (current != null && seen.add(current)) {
      if (current == descendantId) return true;
      current = claimedBy[current];
    }
    return false;
  }

  /// Width of each subtree, bottom-up.
  static double _measure(_TreeNode node) {
    if (node.children.isEmpty) {
      node.width = nodeWidth;
      return node.width;
    }

    double childrenWidth = 0;
    for (final child in node.children) {
      childrenWidth += _measure(child);
    }
    childrenWidth += (node.children.length - 1) * siblingSpacing;

    node.width = childrenWidth > nodeWidth ? childrenWidth : nodeWidth;
    return node.width;
  }

  /// Assign positions, top-down, centring each parent over its children.
  static void _place(
      _TreeNode node, double x, double y, double levelSeparation) {
    node.finalX = x + (node.width - nodeWidth) / 2;
    node.finalY = y;

    if (node.children.isEmpty) return;

    double childrenWidth = 0;
    for (final child in node.children) {
      childrenWidth += child.width;
    }
    childrenWidth += (node.children.length - 1) * siblingSpacing;

    double childX = x + (node.width - childrenWidth) / 2;
    for (final child in node.children) {
      _place(child, childX, y + levelSeparation, levelSeparation);
      childX += child.width + siblingSpacing;
    }
  }

  static void _collect(
    _TreeNode node,
    int generation,
    Map<String, Offset> positions,
    Map<String, int> generations,
  ) {
    positions[node.person.id] = Offset(node.finalX, node.finalY);
    generations[node.person.id] = generation;
    for (final child in node.children) {
      _collect(child, generation + 1, positions, generations);
    }
  }
}

/// The result of laying out a tree.
class TreeLayout {
  const TreeLayout({required this.positions, required this.generations});

  /// Where to draw each person.
  final Map<String, Offset> positions;

  /// How far below the top of the tree each person sits. Taken from the walk
  /// itself rather than inferred by dividing a y coordinate by the level
  /// separation and rounding, which drifted whenever spacing was adjusted.
  final Map<String, int> generations;

  static const empty = TreeLayout(positions: {}, generations: {});
}

class _Forest {
  _Forest(this.roots);

  final List<_TreeNode> roots;
}

class _TreeNode {
  _TreeNode(this.person);

  final Person person;
  _TreeNode? parent;
  final List<_TreeNode> children = [];

  double width = 0;
  double finalX = 0;
  double finalY = 0;
}
