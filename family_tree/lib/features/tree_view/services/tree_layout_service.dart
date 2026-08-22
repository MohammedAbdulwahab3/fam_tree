import 'dart:ui';
import 'package:family_tree/data/models/person.dart';

/// Service to calculate tree layouts using Walker's algorithm
class TreeLayoutService {
  static const double nodeWidth = 120.0;
  static const double nodeHeight = 160.0;
  static const double siblingSpacing = 40.0; // Reduced from 80
  static const double subtreeSpacing = 60.0; // Reduced from 100
  static const double defaultLevelSeparation = 2000.0; // Drastically increased to 2000 // Increased from 400

  /// Calculate positions for a list of persons in a tree structure
  static Map<String, Offset> calculateTreeLayout(
    List<Person> persons, {
    double? levelSeparation,
  }) {
    final effectiveLevelSeparation = levelSeparation ?? defaultLevelSeparation;
    if (persons.isEmpty) return {};

    // 1. Build Tree Structure
    final nodes = _buildTreeStructure(persons);
    final roots = nodes.values.where((n) => n.parent == null).toList();

    if (roots.isEmpty && nodes.isNotEmpty) {
      roots.add(nodes.values.first);
    }

    // 2. Calculate Subtree Widths (Bottom-Up)
    for (final root in roots) {
      _calculateSubtreeWidth(root);
    }

    // 3. Assign Positions (Top-Down)
    final positions = <String, Offset>{};
    double currentX = 0;

    for (final root in roots) {
      _assignPositions(root, currentX, 0, effectiveLevelSeparation);
      _collectPositions(root, positions);
      currentX += root.width + subtreeSpacing;
    }

    return positions;
  }

  static Map<String, _TreeNode> _buildTreeStructure(
    List<Person> persons,
  ) {
    final nodes = <String, _TreeNode>{};
    for (final person in persons) {
      nodes[person.id] = _TreeNode(person);
    }
    for (final person in persons) {
      final node = nodes[person.id]!; // Get the existing node
      
      for (final childId in person.relationships.childrenIds) {
          final childNode = nodes[childId];
          if (childNode != null) {
            node.children.add(childNode);
            childNode.parent = node;
          }
      }
    }
    return nodes;
  }

  /// Recursively calculate the width of each subtree
  static double _calculateSubtreeWidth(_TreeNode node) {
    if (node.children.isEmpty) {
      node.width = nodeWidth;
    } else {
      double childrenWidth = 0;
      for (var child in node.children) {
        childrenWidth += _calculateSubtreeWidth(child);
      }
      // Add spacing between children
      childrenWidth += (node.children.length - 1) * siblingSpacing;
      
      // Node width is max of its own width vs children width
      // We ensure the node reserves at least enough space for its children
      node.width = nodeWidth > childrenWidth ? nodeWidth : childrenWidth;
    }
    return node.width;
  }

  /// Recursively assign positions based on calculated widths
  static void _assignPositions(_TreeNode node, double x, double y, double levelSeparation) {
    // Center node in its reserved width
    // If node is wider than children (leaf or single child), it's just x
    // If children are wider, we center the parent relative to children
    
    node.finalX = x + (node.width - nodeWidth) / 2;
    node.finalY = y;

    // Position children
    // If parent is wider than children, we need to center the children group
    double childrenTotalWidth = 0;
    if (node.children.isNotEmpty) {
      for (var child in node.children) {
        childrenTotalWidth += child.width;
      }
      childrenTotalWidth += (node.children.length - 1) * siblingSpacing;
    }
    
    double currentChildX = x + (node.width - childrenTotalWidth) / 2;
    
    for (final child in node.children) {
      _assignPositions(child, currentChildX, y + levelSeparation, levelSeparation);
      currentChildX += child.width + siblingSpacing;
    }
  }

  static void _collectPositions(_TreeNode node, Map<String, Offset> positions) {
    positions[node.person.id] = Offset(node.finalX, node.finalY);
    for (final child in node.children) {
      _collectPositions(child, positions);
    }
  }
}

class _TreeNode {
  final Person person;
  _TreeNode? parent;
  List<_TreeNode> children = [];
  
  double width = 0;       // Total width of this subtree
  double finalX = 0;
  double finalY = 0;

  _TreeNode(this.person);
}
