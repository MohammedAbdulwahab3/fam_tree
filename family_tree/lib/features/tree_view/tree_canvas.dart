import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/core/theme/app_colors.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/data/repositories/person_repository.dart'
    show FamilyIndex;
import 'package:family_tree/features/tree_view/widgets/person_node.dart';
import 'package:family_tree/features/tree_view/widgets/tree_minimap.dart';
import 'package:family_tree/features/tree_view/widgets/tree_controls.dart';
import 'package:family_tree/features/tree_view/services/tree_layout_service.dart';

/// Layout mode for the tree
enum LayoutMode {
  tree,
  radial,
  timeline,
  list,
  focus,
}

/// Interactive canvas for family tree visualization
class TreeCanvas extends StatefulWidget {
  final List<Person> persons;
  final String? selectedPersonId;
  final String? focusedSubtreeRoot;
  final List<String> focusedPersonIds;
  final LayoutMode layoutMode;
  final Function(String) onPersonTapped;
  final Function(String) onPersonDoubleTapped;
  final Function(String) onPersonLongPressed;
  final VoidCallback? onClearSubtreeFocus;
  final VoidCallback? onBackgroundTapped;

  const TreeCanvas({
    super.key,
    required this.persons,
    required this.layoutMode,
    this.selectedPersonId,
    this.focusedSubtreeRoot,
    this.focusedPersonIds = const [],
    required this.onPersonTapped,
    required this.onPersonDoubleTapped,
    required this.onPersonLongPressed,
    this.onClearSubtreeFocus,
    this.onBackgroundTapped,
  });

  @override
  State<TreeCanvas> createState() => TreeCanvasState();
}

class TreeCanvasState extends State<TreeCanvas>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformationController =
      TransformationController();
  late AnimationController _tourController;
  Animation<Matrix4>? _tourAnimation;

  // Tour State
  bool _isTourActive = false;
  List<String> _tourPath = [];
  int _currentTourIndex = 0;

  // Canvas size
  Size _canvasSize = const Size(2000, 2000);

  // Node positions (will be calculated by layout algorithm)
  Map<String, Offset> _cachedPositions = {};
  Map<String, int> _cachedGenerations = {};
  bool _isInitialized = false;

  /// An id-keyed view of the family, rebuilt only when the people change.
  ///
  /// Every lookup here used to be a linear scan of the whole list, and
  /// root-finding asked, for each person, whether any of their parent ids
  /// matched any person in the list — quadratic, and written out separately in
  /// four places.
  late FamilyIndex _index = FamilyIndex(widget.persons);
  late List<Person> _roots = _index.roots(widget.persons);

  void _rebuildIndex() {
    _index = FamilyIndex(widget.persons);
    _roots = _index.roots(widget.persons);
  }

  /// The person with this id, or null. Callers used to fall back to
  /// `widget.persons.first`, which silently substituted an unrelated relative
  /// whenever an id did not resolve — and, in a traversal, could loop forever.
  Person? _person(String id) => _index.byId(id);

  // Navigation controls state
  bool _isMinimapVisible = true;
  int? _selectedGeneration;
  final String _searchQuery = '';
  double _currentZoom = 1.0;
  Rect _viewportRect = Rect.zero;

  // Focus mode state
  List<String> _focusStack = [];
  String? _selectedFocusChildId;
  final ScrollController _focusScrollController = ScrollController();

  // Node dimensions follow the active variant: the timeline layout uses the
  // wide parchment plaque, every other layout uses the classic portrait card.
  double get _nodeWidth => widget.layoutMode == LayoutMode.timeline
      ? PersonNode.treePlaqueWidth
      : PersonNode.classicWidth;
  double get _nodeHeight => widget.layoutMode == LayoutMode.timeline
      ? PersonNode.treePlaqueHeight
      : PersonNode.classicHeight;
  double get _nodeHalfWidth => _nodeWidth / 2;
  double get _nodeHalfHeight => _nodeHeight / 2;

  @override
  void initState() {
    super.initState();
    _tourController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..addListener(() {
        if (_tourAnimation != null) {
          _transformationController.value = _tourAnimation!.value;
        }
      });

    // Listen to transformation changes to update zoom and viewport
    _transformationController.addListener(_onTransformChanged);
  }

  void _onTransformChanged() {
    final matrix = _transformationController.value;
    final scale = matrix.getMaxScaleOnAxis();

    if (mounted) {
      setState(() {
        _currentZoom = scale;
        _updateViewportRect();
      });
    }
  }

  void _updateViewportRect() {
    if (!mounted) return;

    final matrix = _transformationController.value;
    final scale = matrix.getMaxScaleOnAxis();
    final translation = matrix.getTranslation();

    final screenSize = MediaQuery.of(context).size;

    // Calculate the visible area in canvas coordinates
    final left = -translation.x / scale;
    final top = -translation.y / scale;
    final width = screenSize.width / scale;
    final height = screenSize.height / scale;

    _viewportRect = Rect.fromLTWH(left, top, width, height);
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformChanged);
    _tourController.dispose();
    _transformationController.dispose();
    _focusScrollController.dispose();
    super.dispose();
  }

  /// Get the currently focused subtree persons for export.
  /// In focus mode, returns the focused person and all their descendants.
  /// Otherwise returns all persons.
  List<Person> getFocusedSubtreePersons() {
    if (widget.layoutMode != LayoutMode.focus || _focusStack.isEmpty) {
      return widget.persons;
    }

    final focusedPerson = _person(_focusStack.last);
    if (focusedPerson == null) return widget.persons;

    final includedIds = _descendantIdsOf(focusedPerson.id);
    return widget.persons.where((p) => includedIds.contains(p.id)).toList();
  }

  /// This person plus everyone below them. Iterative and visited-guarded: the
  /// recursive versions this replaced would not terminate on a cycle, which the
  /// admin screen can produce.
  Set<String> _descendantIdsOf(String rootId) {
    final found = <String>{rootId};
    final queue = <String>[rootId];

    while (queue.isNotEmpty) {
      final current = _person(queue.removeAt(0));
      if (current == null) continue;
      for (final child in _index.childrenOf(current)) {
        if (found.add(child.id)) queue.add(child.id);
      }
    }
    return found;
  }

  /// Get the name of the currently focused person (for export title)
  String? getFocusedPersonName() {
    if (widget.layoutMode != LayoutMode.focus || _focusStack.isEmpty) {
      return null;
    }
    return _person(_focusStack.last)?.fullName;
  }

  // ============ ZOOM CONTROLS ============

  void _zoomIn() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    // Smaller zoom increment (1.15x) with clamped range
    final newScale = (currentScale * 1.15).clamp(0.3, 2.0);
    _animateToScale(newScale);
  }

  void _zoomOut() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    // Smaller zoom decrement (1.15x) with clamped range
    final newScale = (currentScale / 1.15).clamp(0.3, 2.0);
    _animateToScale(newScale);
  }

  void _animateToScale(double targetScale) {
    final currentMatrix = _transformationController.value.clone();
    final currentScale = currentMatrix.getMaxScaleOnAxis();

    // Get screen center
    final screenSize = MediaQuery.of(context).size;
    final screenCenter = Offset(screenSize.width / 2, screenSize.height / 2);

    // Calculate the point in canvas coordinates that's at screen center
    final translation = currentMatrix.getTranslation();
    final canvasPoint = Offset(
      (screenCenter.dx - translation.x) / currentScale,
      (screenCenter.dy - translation.y) / currentScale,
    );

    // Create new matrix that zooms to/from screen center
    final newMatrix = Matrix4.identity()
      ..translate(screenCenter.dx, screenCenter.dy)
      ..scale(targetScale)
      ..translate(-canvasPoint.dx, -canvasPoint.dy);

    _transformationController.value = newMatrix;
  }

  void _zoomReset() {
    // Reset to fit all nodes instead of identity matrix
    _zoomToFitVisibleNodes();
  }

  void _navigateToPosition(Offset canvasPosition) {
    final screenSize = MediaQuery.of(context).size;
    final screenCenter = Offset(screenSize.width / 2, screenSize.height / 2);
    final currentScale = _transformationController.value.getMaxScaleOnAxis();

    final newMatrix = Matrix4.identity()
      ..translate(screenCenter.dx, screenCenter.dy)
      ..scale(currentScale)
      ..translate(-canvasPosition.dx, -canvasPosition.dy);

    _transformationController.value = newMatrix;
  }

  void _navigateToPerson(String personId) {
    final position = _cachedPositions[personId];
    if (position != null) {
      _navigateToPosition(position);
      widget.onPersonTapped(personId);
    }
  }

  void _onGenerationFilter(int? generation) {
    setState(() {
      _selectedGeneration = generation;
    });
  }

  void _onSearch(String query) {
    // Search is handled by TreeControls, but we can add highlighting here
  }

  // Helper for responsive buttons (compact on mobile)
  Widget _buildResponsiveButton(
    BuildContext context, {
    required String heroTag,
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color backgroundColor,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      return FloatingActionButton.small(
        heroTag: heroTag,
        onPressed: onPressed,
        tooltip: label,
        backgroundColor: backgroundColor,
        child: Icon(icon, size: 20),
      );
    }

    return FloatingActionButton.extended(
      heroTag: heroTag,
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      backgroundColor: backgroundColor,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _calculateNodePositions();
      _isInitialized = true;
      // Zoom to fit all nodes on initial load
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _zoomToFitVisibleNodes();
      });
    }
    _updateCanvasSize();
  }

  @override
  void didUpdateWidget(TreeCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.persons != widget.persons ||
        oldWidget.layoutMode != widget.layoutMode ||
        oldWidget.focusedSubtreeRoot != widget.focusedSubtreeRoot) {
      // The people changed, so the id index and the root list are stale.
      if (oldWidget.persons != widget.persons) _rebuildIndex();
      _calculateNodePositions();
      _updateCanvasSize();

      // Auto-zoom to fit when layout or subtree changes
      if (oldWidget.layoutMode != widget.layoutMode ||
          oldWidget.focusedSubtreeRoot != widget.focusedSubtreeRoot) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _zoomToFitVisibleNodes();
        });
      }
    }
  }

  void _zoomToFitVisibleNodes() {
    if (_cachedPositions.isEmpty || !mounted) return;

    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (final pos in _cachedPositions.values) {
      if (pos.dx < minX) minX = pos.dx;
      if (pos.dx > maxX) maxX = pos.dx;
      if (pos.dy < minY) minY = pos.dy;
      if (pos.dy > maxY) maxY = pos.dy;
    }

    // Account for node sizes (nodes are ~140px wide, ~160px tall)
    // Node positions are at center, so add half node size as margin
    final nodeMargin = 100.0;
    final screenPadding = 80.0; // Extra padding from screen edges

    final rect = Rect.fromLTRB(
        minX - nodeMargin - screenPadding,
        minY - nodeMargin - screenPadding,
        maxX + nodeMargin + screenPadding,
        maxY + nodeMargin + screenPadding);

    _zoomToFitRect(rect);
  }

  void _zoomToFitRect(Rect rect) {
    if (!mounted) return;

    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    // Calculate scale to fit content with proper margins
    final scaleX = screenWidth / rect.width;
    final scaleY = screenHeight / rect.height;

    // Use smaller scale to ensure all content fits, with reasonable limits
    final scale = (math.min(scaleX, scaleY) * 0.95).clamp(0.3, 1.5);

    // Calculate content center
    final contentCenterX = rect.center.dx;
    final contentCenterY = rect.center.dy;

    // Calculate screen center
    final screenCenter = Offset(screenWidth / 2, screenHeight / 2);

    // Build transformation matrix
    final matrix = Matrix4.identity();
    matrix.translate(screenCenter.dx, screenCenter.dy);
    matrix.scale(scale, scale);
    matrix.translate(-contentCenterX, -contentCenterY);

    _transformationController.value = matrix;
  }

  List<Person> _getFilteredPersons() {
    if (widget.focusedSubtreeRoot == null) {
      return widget.persons;
    }

    // The focused person, everyone below them, and their direct line upwards.
    final subtreeIds = _descendantIdsOf(widget.focusedSubtreeRoot!)
      ..addAll(_ancestorIdsOf(widget.focusedSubtreeRoot!));

    return widget.persons.where((p) => subtreeIds.contains(p.id)).toList();
  }

  /// This person plus everyone above them.
  Set<String> _ancestorIdsOf(String startId) {
    final found = <String>{startId};
    final queue = <String>[startId];

    while (queue.isNotEmpty) {
      final current = _person(queue.removeAt(0));
      if (current == null) continue;
      for (final parentId in current.relationships.parentIds) {
        if (_person(parentId) != null && found.add(parentId)) {
          queue.add(parentId);
        }
      }
    }
    return found;
  }

  void _calculateNodePositions() {
    switch (widget.layoutMode) {
      case LayoutMode.tree:
        _calculateTreeLayout();
        break;
      case LayoutMode.radial:
        _calculateRadialLayout();
        break;
      case LayoutMode.timeline:
        _calculateTimelineLayout();
        break;
      case LayoutMode.list:
        _calculateListLayout();
        break;
      case LayoutMode.focus:
        // Focus mode uses its own widget, no positions needed
        break;
    }
  }

  void _updateCanvasSize() {
    if (_cachedPositions.isEmpty) {
      _canvasSize = const Size(2000, 2000);
      return;
    }

    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (final pos in _cachedPositions.values) {
      if (pos.dx < minX) minX = pos.dx;
      if (pos.dx > maxX) maxX = pos.dx;
      if (pos.dy < minY) minY = pos.dy;
      if (pos.dy > maxY) maxY = pos.dy;
    }

    // Add padding
    final padding = 400.0;
    final width = (maxX - minX) + padding * 2;
    final height = (maxY - minY) + padding * 2;

    setState(() {
      _canvasSize = Size(width, height);

      // Center the tree initially if not touring
      if (!_isTourActive) {
        // ... initial centering logic if needed ...
      }
    });

    // We might need to shift all nodes if minX is negative to ensure they are within the canvas [0, width]
    // But InteractiveViewer with unbounded constraints can handle negative coordinates if we set boundaryMargin correctly.
    // However, CustomPaint usually clips to its size. It's safer to shift everything to positive coordinates.

    if (minX < 100 || minY < 100) {
      final offsetX = 100 - minX;
      final offsetY = 100 - minY;

      final newPositions = <String, Offset>{};
      for (final entry in _cachedPositions.entries) {
        newPositions[entry.key] = entry.value + Offset(offsetX, offsetY);
      }
      _cachedPositions = newPositions;
    }

    setState(() {});
  }

  // --- Tour Logic ---

  void _startTour() async {
    if (widget.persons.isEmpty) return;

    setState(() {
      _isTourActive = true;
      _tourPath = _calculateTourPath();
      _currentTourIndex = 0;
    });

    // Step 1: Zoom to Fit (Show all families)
    await _zoomToFit();

    if (!_isTourActive) return;

    // Step 2: Wait a bit for user to appreciate the view
    await Future.delayed(const Duration(seconds: 2));

    if (!_isTourActive) return;

    // Step 3: Start Traversal
    _animateToNextNode();
  }

  Future<void> _zoomToFit() async {
    if (_cachedPositions.isEmpty) return;

    // Calculate bounds
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (final pos in _cachedPositions.values) {
      if (pos.dx < minX) minX = pos.dx;
      if (pos.dx > maxX) maxX = pos.dx;
      if (pos.dy < minY) minY = pos.dy;
      if (pos.dy > maxY) maxY = pos.dy;
    }

    // Add padding
    final padding = 100.0;
    final contentWidth = (maxX - minX) + padding * 2;
    final contentHeight = (maxY - minY) + padding * 2;

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Calculate scale to fit
    final scaleX = screenWidth / contentWidth;
    final scaleY = screenHeight / contentHeight;
    final scale = math.min(scaleX, scaleY) * 0.9; // 90% fit

    // Calculate center of content
    final contentCenterX = minX + (maxX - minX) / 2;
    final contentCenterY = minY + (maxY - minY) / 2;

    // Calculate target matrix
    // T = Translate(ScreenCenter) * Scale(scale) * Translate(-ContentCenter)
    final screenCenter = Offset(screenWidth / 2, screenHeight / 2);

    final targetMatrix = Matrix4.identity()
      ..translate(screenCenter.dx, screenCenter.dy)
      ..scale(scale)
      ..translate(-contentCenterX, -contentCenterY);

    _tourAnimation = Matrix4Tween(
      begin: _transformationController.value,
      end: targetMatrix,
    ).animate(
        CurvedAnimation(parent: _tourController, curve: Curves.easeInOutCubic));

    _tourController.reset();
    await _tourController.forward();
  }

  void _stopTour() {
    setState(() {
      _isTourActive = false;
      _tourPath = [];
      _tourController.stop();
    });
  }

  List<String> _calculateTourPath() {
    // DFS Traversal
    final path = <String>[];
    final visited = <String>{};

    for (final root in _roots) {
      _dfsTraversal(root, path, visited);
    }
    return path;
  }

  void _dfsTraversal(Person node, List<String> path, Set<String> visited) {
    if (visited.contains(node.id)) return;
    visited.add(node.id);
    path.add(node.id);

    final children = widget.persons
        .where((p) => p.relationships.parentIds.contains(node.id))
        .toList();

    // Sort children by order added (createdAt)
    children.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    for (final child in children) {
      _dfsTraversal(child, path, visited);
    }
  }

  void _animateToNextNode() async {
    if (!_isTourActive || _currentTourIndex >= _tourPath.length) {
      _stopTour();
      return;
    }

    final nodeId = _tourPath[_currentTourIndex];
    final position = _cachedPositions[nodeId];

    if (position != null) {
      // Highlight the node
      widget.onPersonTapped(nodeId);

      // Calculate Bounding Box for Family Unit (Node + Children)
      double minX = position.dx;
      double maxX = position.dx;
      double minY = position.dy;
      double maxY = position.dy;

      // Add children to bounds
      final children = widget.persons
          .where((p) => p.relationships.parentIds.contains(nodeId));

      for (final child in children) {
        final childPos = _cachedPositions[child.id];
        if (childPos != null) {
          if (childPos.dx < minX) minX = childPos.dx;
          if (childPos.dx > maxX) maxX = childPos.dx;
          if (childPos.dy < minY) minY = childPos.dy;
          if (childPos.dy > maxY) maxY = childPos.dy;
        }
      }

      // Add padding
      final padding = 150.0; // Generous padding
      final rect = Rect.fromLTRB(minX, minY, maxX, maxY).inflate(padding);

      await _zoomToRect(rect);
    }

    // Wait before next node
    if (_isTourActive) {
      await Future.delayed(const Duration(seconds: 3)); // Longer pause to read
      setState(() {
        _currentTourIndex++;
      });
      _animateToNextNode();
    }
  }

  Future<void> _zoomToRect(Rect rect) async {
    if (!mounted) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Calculate scale to fit
    final scaleX = screenWidth / rect.width;
    final scaleY = screenHeight / rect.height;

    // On mobile, don't zoom out too much to keep text readable
    final minReadableScale = screenWidth < 600 ? 0.5 : 0.2;
    final scale = math.min(scaleX, scaleY).clamp(minReadableScale, 2.0);

    // Calculate center of content
    final contentCenterX = rect.center.dx;
    final contentCenterY = rect.center.dy;

    // Calculate target matrix
    final screenCenter = Offset(screenWidth / 2, screenHeight / 2);

    final targetMatrix = Matrix4.identity()
      ..translate(screenCenter.dx, screenCenter.dy)
      ..scale(scale)
      ..translate(-contentCenterX, -contentCenterY);

    _tourAnimation = Matrix4Tween(
      begin: _transformationController.value,
      end: targetMatrix,
    ).animate(
        CurvedAnimation(parent: _tourController, curve: Curves.easeInOutCubic));

    _tourController.reset();
    await _tourController.forward();
  }

  void _calculateTreeLayout() {
    final visible = _getFilteredPersons();

    // Spread the generations across the viewport, within sensible bounds.
    final screenHeight = MediaQuery.of(context).size.height;
    final depth = _generationDepth(visible);

    double levelSeparation = TreeLayoutService.defaultLevelSeparation;
    if (depth > 0) {
      levelSeparation = ((screenHeight - 200) / depth).clamp(300.0, 500.0);
    }

    final layout = TreeLayoutService.calculate(
      visible,
      levelSeparation: levelSeparation,
    );

    _cachedPositions = layout.positions;
    // Taken from the layout walk itself. Inferring it by dividing a y
    // coordinate by the level separation and rounding drifted whenever the
    // spacing was adjusted.
    _cachedGenerations = layout.generations;
  }

  /// How many generations deep [people] goes. Breadth-first from the roots,
  /// visited-guarded, so a cyclic relationship is bounded rather than fatal.
  int _generationDepth(List<Person> people) {
    if (people.isEmpty) return 0;

    final index = FamilyIndex(people);
    final seen = <String>{};
    var frontier = index.roots(people);
    for (final root in frontier) {
      seen.add(root.id);
    }

    var depth = 0;
    while (frontier.isNotEmpty) {
      final next = <Person>[];
      for (final person in frontier) {
        for (final child in index.childrenOf(person)) {
          if (seen.add(child.id)) next.add(child);
        }
      }
      if (next.isEmpty) break;
      depth++;
      frontier = next;
    }
    return depth;
  }

  void _calculateRadialLayout() {
    // Beautiful radial layout: root at center, children spread in arcs around parents
    _cachedPositions = {};
    _cachedGenerations = {};

    if (widget.persons.isEmpty) return;

    // Get screen center
    final screenSize = MediaQuery.of(context).size;
    final centerX = screenSize.width / 2;
    final centerY = screenSize.height / 2;

    final root = _roots.first;

    // Radius settings
    const baseRadius = 300.0;
    const radiusStep = 250.0;

    // Place root at center
    _cachedPositions[root.id] = Offset(centerX, centerY);
    _cachedGenerations[root.id] = 0;

    // Recursive function to place nodes in arcs
    void placeChildren(
        Person parent, int generation, double startAngle, double endAngle) {
      final children = widget.persons
          .where((p) => p.relationships.parentIds.contains(parent.id))
          .toList();

      if (children.isEmpty) return;

      // Sort children by order added (createdAt)
      children.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

      final radius = baseRadius + (generation * radiusStep);
      final angleRange = endAngle - startAngle;
      final angleStep = angleRange / children.length;

      for (var i = 0; i < children.length; i++) {
        final child = children[i];
        if (_cachedPositions.containsKey(child.id)) continue;

        // Place child at center of its arc segment
        final childAngle = startAngle + (i + 0.5) * angleStep;

        _cachedPositions[child.id] = Offset(
          centerX + radius * math.cos(childAngle),
          centerY + radius * math.sin(childAngle),
        );
        _cachedGenerations[child.id] = generation;

        // Recursively place this child's children in a sub-arc
        final childStartAngle = startAngle + i * angleStep;
        final childEndAngle = startAngle + (i + 1) * angleStep;
        placeChildren(child, generation + 1, childStartAngle, childEndAngle);
      }
    }

    // Start placing from root, using full 360 degrees
    placeChildren(root, 1, -math.pi, math.pi);
  }

  void _calculateTimelineLayout() {
    // Timeline: Hierarchical order - parent, then all their children, then next parent
    _cachedPositions = {};
    _cachedGenerations = {};

    if (widget.persons.isEmpty) return;

    final roots = _roots;

    // Sort roots by order added (createdAt)
    roots.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    // Layout settings
    const startX = 150.0;
    const startY = 100.0;
    const horizontalSpacing = 200.0; // Space between nodes in same row
    const verticalSpacing = 220.0; // Space between generations

    final visited = <String>{};

    // Track positions per generation for horizontal placement
    final genXPositions = <int, double>{};

    // BFS-style: process each parent, then immediately place all their children
    void layoutFamily(Person parent, int generation) {
      if (visited.contains(parent.id)) return;
      visited.add(parent.id);

      // Get X position for this generation
      final x = genXPositions[generation] ?? startX;
      final y = startY + (generation * verticalSpacing);

      _cachedPositions[parent.id] = Offset(x, y);
      _cachedGenerations[parent.id] = generation;

      // Update X position for next node in this generation
      genXPositions[generation] = x + horizontalSpacing;

      // Get and sort children
      final children = widget.persons
          .where((p) => p.relationships.parentIds.contains(parent.id))
          .toList();

      // Sort by order added
      children.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

      // Place ALL children of this parent first (in order)
      for (final child in children) {
        if (!visited.contains(child.id)) {
          visited.add(child.id);

          final childX = genXPositions[generation + 1] ?? startX;
          final childY = startY + ((generation + 1) * verticalSpacing);

          _cachedPositions[child.id] = Offset(childX, childY);
          _cachedGenerations[child.id] = generation + 1;

          genXPositions[generation + 1] = childX + horizontalSpacing;
        }
      }

      // Then recursively layout grandchildren (maintaining order)
      for (final child in children) {
        final grandchildren = widget.persons
            .where((p) => p.relationships.parentIds.contains(child.id))
            .toList();

        // Sort by order added
        grandchildren.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

        for (final grandchild in grandchildren) {
          layoutFamily(grandchild, generation + 2);
        }
      }
    }

    // Process each root family
    for (final root in roots) {
      layoutFamily(root, 0);
    }
  }

  void _calculateListLayout() {
    // Tree-style list layout with straight lines (like file explorer)
    _cachedPositions = {};
    _cachedGenerations = {};

    if (widget.persons.isEmpty) return;

    final roots = _roots;

    // Layout parameters - nodes are ~140x160px
    const double startX = 120;
    const double startY = 100;
    const double indentPerLevel = 200; // Horizontal indent per generation
    const double verticalSpacing =
        180; // Space between nodes (node height + gap)

    double currentY = startY;
    final visited = <String>{};

    // DFS traversal to create tree-like list
    void layoutNode(Person person, int depth) {
      if (visited.contains(person.id)) return;
      visited.add(person.id);

      final x = startX + (depth * indentPerLevel);
      _cachedPositions[person.id] = Offset(x, currentY);
      _cachedGenerations[person.id] = depth;
      currentY += verticalSpacing;

      // Get children and sort by order added
      final children = widget.persons
          .where((p) => p.relationships.parentIds.contains(person.id))
          .toList();

      // Sort by order added
      children.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

      for (final child in children) {
        layoutNode(child, depth + 1);
      }
    }

    // Layout each root tree
    for (final root in roots) {
      layoutNode(root, 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Focus mode has its own UI
    if (widget.layoutMode == LayoutMode.focus) {
      return _buildFocusLayout(context, isDark);
    }

    return Stack(
      children: [
        // Background with theme-aware gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      AppTheme.backgroundDark,
                      AppTheme.surfaceDark,
                    ]
                  : [
                      AppTheme.backgroundLight,
                      AppTheme.cardLight,
                    ],
            ),
          ),
          child: GestureDetector(
            onTap: widget.onBackgroundTapped,
            behavior: HitTestBehavior.translucent,
            child: InteractiveViewer(
              transformationController: _transformationController,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              minScale: 0.3,
              maxScale: 2.0,
              constrained: false,
              scaleEnabled:
                  false, // Disable scroll/pinch zoom - use buttons only
              panEnabled: true,
              child: SizedBox(
                width: _canvasSize.width,
                height: _canvasSize.height,
                child: CustomPaint(
                  painter: _ConnectionLinesPainter(
                    index: _index,
                    persons: widget.persons,
                    positions: _cachedPositions,
                    generations: _cachedGenerations,
                    selectedPersonId: widget.selectedPersonId,
                    focusedPersonIds: widget.focusedPersonIds.toSet(),
                    selectedGeneration: _selectedGeneration,
                    isDark: isDark,
                    layoutMode: widget.layoutMode,
                    nodeWidth: _nodeWidth,
                    nodeHeight: _nodeHeight,
                  ),
                  child: Stack(
                    children: [
                      ..._buildPersonNodes(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Minimap (top-left)
        if (_isMinimapVisible && widget.persons.length > 5)
          Positioned(
            top: 16,
            left: 16,
            child: TreeMinimap(
              persons: widget.persons,
              positions: _cachedPositions,
              generations: _cachedGenerations,
              selectedPersonId: widget.selectedPersonId,
              viewportRect: _viewportRect,
              canvasSize: _canvasSize,
              onNavigate: _navigateToPosition,
              onClose: () => setState(() => _isMinimapVisible = false),
            ),
          ),

        // Controls (top-right)
        Positioned(
          top: 16,
          right: 16,
          child: TreeControls(
            persons: widget.persons,
            currentZoom: _currentZoom,
            selectedGeneration: _selectedGeneration,
            searchQuery: _searchQuery,
            onZoomIn: _zoomIn,
            onZoomOut: _zoomOut,
            onZoomFit: _zoomToFitVisibleNodes,
            onZoomReset: _zoomReset,
            onGenerationFilter: _onGenerationFilter,
            onSearch: _onSearch,
            onPersonSelect: _navigateToPerson,
            isMinimapVisible: _isMinimapVisible,
            onToggleMinimap: () =>
                setState(() => _isMinimapVisible = !_isMinimapVisible),
          ),
        ),

        // Back to Full Tree button - simple and functional
        if (widget.focusedSubtreeRoot != null &&
            widget.onClearSubtreeFocus != null)
          Positioned(
            bottom: 80,
            left: 20,
            child: FloatingActionButton.extended(
              heroTag: 'back_button',
              onPressed: widget.onClearSubtreeFocus,
              backgroundColor: AppTheme.accentTeal,
              icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
              label: const Text('Back to Full Tree',
                  style: TextStyle(color: Colors.white)),
            ),
          ),

        // Tour button (responsive)
        Positioned(
          bottom: 20,
          left: 20,
          child: _buildResponsiveButton(
            context,
            heroTag: 'tour_fab',
            onPressed: _isTourActive ? _stopTour : _startTour,
            icon: _isTourActive ? Icons.stop : Icons.play_arrow,
            label: _isTourActive ? 'Stop Tour' : 'Start Tour',
            backgroundColor:
                _isTourActive ? AppTheme.error : AppTheme.primaryLight,
          ),
        ),

        // Person count indicator (bottom-right)
        Positioned(
          bottom: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.surfaceDark.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 18,
                  color: AppTheme.primaryLight,
                ),
                const SizedBox(width: 8),
                Text(
                  '${widget.persons.length} people',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppTheme.textPrimaryDark
                        : AppTheme.textPrimaryLight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Focus layout methods - uses tree visual style with focus navigation
  Widget _buildFocusLayout(BuildContext context, bool isDark) {
    if (widget.persons.isEmpty) return const SizedBox();

    final patriarch = _roots.first;

    // The person in focus, falling back to the top of the tree if the stack
    // points at somebody who has since been removed.
    final Person currentPerson = _focusStack.isEmpty
        ? patriarch
        : (_person(_focusStack.last) ?? patriarch);

    // Get children of focused person
    final children = widget.persons
        .where((p) => p.relationships.parentIds.contains(currentPerson.id))
        .toList()
      ..sort((a, b) => (a.displayOrder).compareTo(b.displayOrder));

    final isRoot = _focusStack.isEmpty;
    final gen = _getPersonGeneration(currentPerson);
    final color =
        AppTheme.generationColors[gen % AppTheme.generationColors.length];

    // Calculate positions for tree-style layout
    final Map<String, Offset> focusPositions = {};
    final Map<String, int> focusGenerations = {};

    // Screen dimensions for centering
    final screenWidth = MediaQuery.of(context).size.width;

    // Node dimensions - use same level spacing as full tree for proportional lines
    const nodeWidth = 140.0;
    const nodeHeight = 160.0;
    const levelSpacing = 350.0; // Match full tree height spacing

    // Position parent at top center
    final parentX = screenWidth / 2;
    const parentY = 140.0;
    focusPositions[currentPerson.id] = Offset(parentX, parentY);
    focusGenerations[currentPerson.id] = gen;

    // Position children in a row below
    if (children.isNotEmpty) {
      final childSpacing =
          math.min(180.0, (screenWidth - 80) / children.length);
      final totalChildWidth = (children.length - 1) * childSpacing;
      final startX = (screenWidth - totalChildWidth) / 2;
      final childY = parentY + levelSpacing;

      for (var i = 0; i < children.length; i++) {
        final child = children[i];
        focusPositions[child.id] = Offset(startX + (i * childSpacing), childY);
        focusGenerations[child.id] = gen + 1;
      }
    }

    return Container(
      color: isDark ? AppTheme.backgroundDark : const Color(0xFFFAF8F5),
      child: Column(
        children: [
          // Navigation header with back button and breadcrumb
          if (!isRoot) _buildFocusNav(currentPerson, color, isDark),

          // Tree visualization area - fixed vertically, horizontally scrollable if many children
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Recalculate positions based on actual available height
                final availableHeight = constraints.maxHeight;
                final availableWidth = constraints.maxWidth;

                // Adjust positions to fit within available space
                final adjustedParentY = availableHeight * 0.2; // 20% from top
                final adjustedChildY = availableHeight * 0.7; // 70% from top

                // Calculate if horizontal scroll is needed based on actual content width
                // Each child needs ~150px spacing, plus 80px margin
                const fixedChildSpacing = 150.0;
                final requiredWidth =
                    (children.length * fixedChildSpacing) + 100;
                final needsHorizontalScroll = requiredWidth > availableWidth;

                // Calculate canvas width
                final canvasWidth =
                    needsHorizontalScroll ? requiredWidth : availableWidth;

                // Update parent position (centered in canvas)
                focusPositions[currentPerson.id] =
                    Offset(canvasWidth / 2, adjustedParentY);

                if (children.isNotEmpty) {
                  final childSpacing = needsHorizontalScroll
                      ? fixedChildSpacing
                      : math.min(
                          150.0, (availableWidth - 80) / children.length);
                  final totalChildWidth = (children.length - 1) * childSpacing;
                  final startX = (canvasWidth - totalChildWidth) / 2;

                  for (var i = 0; i < children.length; i++) {
                    final child = children[i];
                    focusPositions[child.id] =
                        Offset(startX + (i * childSpacing), adjustedChildY);
                  }
                }

                Widget treeWidget = GestureDetector(
                  onTap: () => setState(() => _selectedFocusChildId =
                      null), // Clear selection on background tap
                  child: SizedBox(
                    width: canvasWidth,
                    height: availableHeight,
                    child: CustomPaint(
                      painter: _FocusConnectionsPainter(
                        parent: currentPerson,
                        children: children,
                        positions: focusPositions,
                        color: color,
                        isDark: isDark,
                        selectedChildId: _selectedFocusChildId,
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Parent node
                          Positioned(
                            left: focusPositions[currentPerson.id]!.dx -
                                (nodeWidth / 2),
                            top: focusPositions[currentPerson.id]!.dy -
                                (nodeHeight / 2),
                            child: GestureDetector(
                              onDoubleTap: () =>
                                  widget.onPersonDoubleTapped(currentPerson.id),
                              child: PersonNode(
                                person: currentPerson,
                                generation: gen,
                                isSelected: true,
                                isFocused: true,
                                isDimmed: false,
                                color: color,
                                onTap: () =>
                                    widget.onPersonTapped(currentPerson.id),
                                onDoubleTap: () => widget
                                    .onPersonDoubleTapped(currentPerson.id),
                                onLongPress: () {},
                              ),
                            ),
                          ),

                          // Child nodes (tappable to drill down)
                          ...children.map((child) {
                            final childGen = gen + 1;
                            final childColor = AppTheme.generationColors[
                                childGen % AppTheme.generationColors.length];
                            final hasGrandchildren = widget.persons.any((p) =>
                                p.relationships.parentIds.contains(child.id));

                            return Positioned(
                              left: focusPositions[child.id]!.dx -
                                  (nodeWidth / 2),
                              top: focusPositions[child.id]!.dy -
                                  (nodeHeight / 2),
                              child: GestureDetector(
                                onTap: () {
                                  // Drill down into this child's family
                                  setState(() => _focusStack.add(child.id));
                                },
                                onDoubleTap: () =>
                                    widget.onPersonDoubleTapped(child.id),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    PersonNode(
                                      person: child,
                                      generation: childGen,
                                      isSelected:
                                          _selectedFocusChildId == child.id,
                                      isFocused: true,
                                      isDimmed: false,
                                      color: childColor,
                                      onTap: () {
                                        setState(() {
                                          if (_selectedFocusChildId ==
                                              child.id) {
                                            // If already selected, drill down
                                            _focusStack.add(child.id);
                                            _selectedFocusChildId = null;
                                          } else {
                                            // First tap selects
                                            _selectedFocusChildId = child.id;
                                          }
                                        });
                                      },
                                      onDoubleTap: () =>
                                          widget.onPersonDoubleTapped(child.id),
                                      onLongPress: () {},
                                    ),
                                    // Count badge at TOP - shows number of direct children
                                    if (hasGrandchildren)
                                      Positioned(
                                        top: -8,
                                        right: -8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: childColor,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                                color: Colors.white, width: 2),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withValues(alpha: 0.2),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            '${widget.persons.where((p) => p.relationships.parentIds.contains(child.id)).length}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    // Simple tap button at BOTTOM
                                    if (hasGrandchildren)
                                      Positioned(
                                        bottom: -18,
                                        left: 0,
                                        right: 0,
                                        child: Center(
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () => setState(() {
                                              _focusStack.add(child.id);
                                              _selectedFocusChildId = null;
                                            }),
                                            child: Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: childColor,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                    color: Colors.white,
                                                    width: 2.5),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black26,
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(
                                                Icons.expand_more_rounded,
                                                color: Colors.white,
                                                size: 28,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }),

                          // Empty state
                          if (children.isEmpty)
                            Positioned(
                              left: 0,
                              right: 0,
                              top: adjustedParentY + 120,
                              child: Column(
                                children: [
                                  Icon(Icons.family_restroom_rounded,
                                      size: 48,
                                      color:
                                          Colors.grey.withValues(alpha: 0.3)),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No children recorded',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color:
                                            Colors.grey.withValues(alpha: 0.6)),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );

                // Wrap in horizontal scroll if many children
                if (needsHorizontalScroll) {
                  return ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      dragDevices: {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                        PointerDeviceKind.trackpad,
                      },
                    ),
                    child: Scrollbar(
                      controller: _focusScrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _focusScrollController,
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: treeWidget,
                      ),
                    ),
                  );
                }
                return treeWidget;
              },
            ),
          ),

          // Footer navigation (back to parent, sibling navigation)
          // Footer navigation removed as per user request
        ],
      ),
    );
  }

  Widget _buildFocusNav(Person person, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color: context.colors.surface,
          border:
              Border(bottom: BorderSide(color: color.withValues(alpha: 0.2)))),
      child: Row(children: [
        GestureDetector(
          onTap: () => setState(() {
            if (_focusStack.isNotEmpty) _focusStack.removeLast();
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color:
                    isDark ? AppTheme.backgroundDark : const Color(0xFFF5F0E8),
                borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Icon(Icons.arrow_back,
                  size: 16, color: context.colors.ink.withValues(alpha: 0.87)),
              const SizedBox(width: 6),
              Text('Back',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.colors.ink.withValues(alpha: 0.87))),
            ]),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  GestureDetector(
                      onTap: () => setState(() => _focusStack.clear()),
                      child: Text('Home',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.primaryLight,
                              fontWeight: FontWeight.w600))),
                  ..._focusStack.map((id) {
                    final p = widget.persons
                        .firstWhere((x) => x.id == id, orElse: () => person);
                    final isLast = id == _focusStack.last;
                    return Row(children: [
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(Icons.chevron_right,
                              size: 14, color: Colors.grey)),
                      GestureDetector(
                        onTap: isLast
                            ? null
                            : () => setState(() => _focusStack = _focusStack
                                .sublist(0, _focusStack.indexOf(id) + 1)),
                        child: Text(p.firstName,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight:
                                    isLast ? FontWeight.w700 : FontWeight.w500,
                                color: isLast
                                    ? (context.colors.ink
                                        .withValues(alpha: 0.87))
                                    : Colors.grey)),
                      ),
                    ]);
                  }),
                ]))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8)),
          child: Text('Gen ${_getPersonGeneration(person)}',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ),
      ]),
    );
  }

  int _getPersonGeneration(Person person) {
    if (person.relationships.parentIds.isEmpty) return 1;
    int gen = 1;
    var current = person;
    while (current.relationships.parentIds.isNotEmpty) {
      final parent = widget.persons.firstWhere(
          (p) => p.id == current.relationships.parentIds.first,
          orElse: () => current);
      if (parent.id == current.id) break;
      current = parent;
      gen++;
    }
    return gen;
  }

  List<Widget> _buildPersonNodes() {
    final root = _roots.first;

    // 2. Identify Generation 1 (Sons)
    final gen1Ids = widget.persons
        .where((p) => p.relationships.parentIds.contains(root.id))
        .map((p) => p.id)
        .toList();

    // 3. Map each person to their Gen 1 ancestor (Branch)
    final personBranchMap = <String, int>{};

    // Assign root to a default color (e.g., index 0)
    personBranchMap[root.id] = 0;

    // Assign Gen 1 to their own indices
    for (var i = 0; i < gen1Ids.length; i++) {
      personBranchMap[gen1Ids[i]] = i;
    }

    // Propagate branch index to descendants
    // We can do this by traversing down from each Gen 1 node
    for (var i = 0; i < gen1Ids.length; i++) {
      final queue = [gen1Ids[i]];
      final visited = {gen1Ids[i]};

      while (queue.isNotEmpty) {
        final currentId = queue.removeAt(0);
        personBranchMap[currentId] = i;

        final children = widget.persons
            .where((p) => p.relationships.parentIds.contains(currentId))
            .map((p) => p.id);

        for (final childId in children) {
          if (!visited.contains(childId)) {
            visited.add(childId);
            queue.add(childId);
          }
        }
      }
    }

    // 4. Calculate Spotlight (Focus+Context)
    Set<String> spotlightIds = {};
    if (widget.selectedPersonId != null) {
      final selectedId = widget.selectedPersonId!;
      final selectedPerson = _person(selectedId);
      if (selectedPerson != null) {
        spotlightIds.add(selectedId);
        spotlightIds.addAll(selectedPerson.relationships.parentIds);
        spotlightIds.addAll(_index.childrenOf(selectedPerson).map((c) => c.id));
        spotlightIds.addAll(
            selectedPerson.relationships.spouses.map((s) => s.personId));
      }
    }

    return widget.persons.map((person) {
      final position = _cachedPositions[person.id] ?? Offset.zero;
      final generation = _cachedGenerations[person.id] ?? 0; // Force update
      final isSelected = person.id == widget.selectedPersonId;
      final isFocused = widget.focusedPersonIds.isEmpty ||
          widget.focusedPersonIds.contains(person.id);

      // No dimming - just highlight selected nodes
      // Only apply subtle dimming for generation filter, not blur
      final isGenerationFiltered =
          _selectedGeneration != null && generation != _selectedGeneration;
      final isDimmed =
          isGenerationFiltered; // Only dim for generation filter, not selection

      // Determine color based on branch
      Color? nodeColor;
      if (personBranchMap.containsKey(person.id)) {
        final branchIndex = personBranchMap[person.id]!;
        // Use generation colors but cycle through them based on branch index
        // We skip index 0 (red) for root if we want, or just use it.
        // Let's shift by 1 to avoid Red for everyone if root is 0.
        nodeColor = AppTheme
            .generationColors[branchIndex % AppTheme.generationColors.length];
      }

      return Positioned(
        left: position.dx - _nodeHalfWidth,
        top: position.dy - _nodeHalfHeight,
        child: PersonNode(
          person: person,
          generation: generation,
          isSelected: isSelected,
          isFocused: isFocused,
          isDimmed: isDimmed,
          color: nodeColor,
          variant: widget.layoutMode == LayoutMode.timeline
              ? PersonNodeVariant.treePlaque
              : PersonNodeVariant.classic,
          onTap: () => widget.onPersonTapped(person.id),
          onDoubleTap: () => widget.onPersonDoubleTapped(person.id),
          onLongPress: () => widget.onPersonLongPressed(person.id),
        ),
      );
    }).toList();
  }
}

/// Custom painter for connection lines between persons
class _ConnectionLinesPainter extends CustomPainter {
  final List<Person> persons;

  /// Id-keyed view of [persons], built once by the canvas rather than rescanned
  /// per node while painting.
  final FamilyIndex index;
  final Map<String, Offset> positions;
  final Map<String, int> generations;
  final String? selectedPersonId;
  final Set<String> focusedPersonIds;
  final int? selectedGeneration;
  final bool isDark;
  final LayoutMode layoutMode;
  final double nodeWidth;
  final double nodeHeight;

  _ConnectionLinesPainter({
    required this.persons,
    required this.index,
    required this.positions,
    required this.generations,
    this.selectedPersonId,
    required this.focusedPersonIds,
    this.selectedGeneration,
    this.isDark = true,
    this.layoutMode = LayoutMode.tree,
    this.nodeWidth = PersonNode.classicWidth,
    this.nodeHeight = PersonNode.classicHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw based on layout mode
    if (layoutMode == LayoutMode.list) {
      _drawListConnections(canvas);
    } else if (layoutMode == LayoutMode.radial) {
      _drawRadialConnections(canvas);
    } else if (layoutMode == LayoutMode.timeline) {
      _drawTimelineConnections(canvas);
    } else {
      _drawTreeConnections(canvas);
    }
  }

  void _drawListConnections(Canvas canvas) {
    // Beautiful L-shaped connectors with gradients and decorations
    for (final person in persons) {
      final personPos = positions[person.id];
      if (personPos == null) continue;

      final parentGen = generations[person.id] ?? 0;
      final parentColor = AppTheme.getGenerationColor(parentGen);

      for (final childId in index.childrenOf(person).map((c) => c.id)) {
        final childPos = positions[childId];
        if (childPos == null) continue;

        final childGen = generations[childId] ?? (parentGen + 1);
        final childColor = AppTheme.getGenerationColor(childGen);

        final isHighlighted =
            person.id == selectedPersonId || childId == selectedPersonId;
        final isFilteredOut = selectedGeneration != null &&
            parentGen != selectedGeneration &&
            childGen != selectedGeneration;

        // Connection points
        final startX = personPos.dx + 70;
        final startY = personPos.dy;
        final endX = childPos.dx - 70;
        final endY = childPos.dy;
        final cornerX = startX + 50;

        // Create gradient paint
        final baseOpacity = isFilteredOut ? 0.2 : 0.7;
        final paint = Paint()
          ..shader = ui.Gradient.linear(
            Offset(startX, startY),
            Offset(endX, endY),
            [
              isHighlighted
                  ? AppTheme.primaryLight
                  : parentColor.withValues(alpha: baseOpacity),
              isHighlighted
                  ? AppTheme.accentTeal
                  : childColor.withValues(alpha: baseOpacity),
            ],
          )
          ..strokeWidth = isHighlighted ? 3 : 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

        // Draw glow for highlighted
        if (isHighlighted) {
          final glowPaint = Paint()
            ..color = AppTheme.primaryLight.withValues(alpha: 0.3)
            ..strokeWidth = 10
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

          final glowPath = Path()
            ..moveTo(startX, startY)
            ..lineTo(cornerX, startY)
            ..lineTo(cornerX, endY)
            ..lineTo(endX, endY);
          canvas.drawPath(glowPath, glowPaint);
        }

        // Draw main connector
        final path = Path()
          ..moveTo(startX, startY)
          ..lineTo(cornerX, startY)
          ..lineTo(cornerX, endY)
          ..lineTo(endX, endY);
        canvas.drawPath(path, paint);

        // Draw decorative dots at corners
        final dotColor = isHighlighted
            ? AppTheme.primaryLight
            : childColor.withValues(alpha: 0.8);
        final dotPaint = Paint()
          ..color = dotColor
          ..style = PaintingStyle.fill;

        // Corner dot
        canvas.drawCircle(
            Offset(cornerX, endY), isHighlighted ? 5 : 3, dotPaint);

        // Start and end dots
        if (isHighlighted) {
          canvas.drawCircle(Offset(startX, startY), 4, dotPaint);
          canvas.drawCircle(Offset(endX, endY), 4, dotPaint);
        }
      }
    }
  }

  void _drawRadialConnections(Canvas canvas) {
    // Draw stunning curved lines for radial layout with beautiful effects

    // First, draw concentric circle guides (subtle)
    if (positions.isNotEmpty) {
      final centerPos = positions.values.first;
      final guideColor = isDark
          ? Colors.white.withValues(alpha: 0.03)
          : Colors.black.withValues(alpha: 0.03);
      final guidePaint = Paint()
        ..color = guideColor
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;

      for (var r = 300.0; r <= 1200.0; r += 250.0) {
        canvas.drawCircle(centerPos, r, guidePaint);
      }
    }

    for (final person in persons) {
      final personPos = positions[person.id];
      if (personPos == null) continue;

      final parentGen = generations[person.id] ?? 0;
      final parentColor = AppTheme.getGenerationColor(parentGen);

      for (final childId in index.childrenOf(person).map((c) => c.id)) {
        final childPos = positions[childId];
        if (childPos == null) continue;

        final childGen = generations[childId] ?? (parentGen + 1);
        final childColor = AppTheme.getGenerationColor(childGen);

        final isHighlighted =
            person.id == selectedPersonId || childId == selectedPersonId;
        final isFilteredOut = selectedGeneration != null &&
            parentGen != selectedGeneration &&
            childGen != selectedGeneration;

        final baseOpacity = isFilteredOut ? 0.15 : 0.7;

        // Calculate curve control point
        final centerPos = positions.values.first;
        final midX = (personPos.dx + childPos.dx) / 2;
        final midY = (personPos.dy + childPos.dy) / 2;
        final dirX = midX - centerPos.dx;
        final dirY = midY - centerPos.dy;
        final dist = math.sqrt(dirX * dirX + dirY * dirY);
        final pushFactor = isHighlighted ? 40.0 : 25.0;
        final controlX = dist > 0 ? midX + (dirX / dist) * pushFactor : midX;
        final controlY = dist > 0 ? midY + (dirY / dist) * pushFactor : midY;

        final path = Path()
          ..moveTo(personPos.dx, personPos.dy)
          ..quadraticBezierTo(controlX, controlY, childPos.dx, childPos.dy);

        // Outer glow for highlighted
        if (isHighlighted && !isFilteredOut) {
          final outerGlow = Paint()
            ..color = AppTheme.primaryLight.withValues(alpha: 0.2)
            ..strokeWidth = 14
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
          canvas.drawPath(path, outerGlow);

          final innerGlow = Paint()
            ..color = AppTheme.accentTeal.withValues(alpha: 0.4)
            ..strokeWidth = 6
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
          canvas.drawPath(path, innerGlow);
        }

        // Main gradient line
        final paint = Paint()
          ..shader = ui.Gradient.linear(
            personPos,
            childPos,
            [
              isHighlighted
                  ? AppTheme.primaryLight
                  : parentColor.withValues(alpha: baseOpacity),
              isHighlighted
                  ? AppTheme.accentTeal
                  : childColor.withValues(alpha: baseOpacity),
            ],
          )
          ..strokeWidth = isHighlighted ? 3.5 : 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        canvas.drawPath(path, paint);

        // Connection dots
        final dotColor = isHighlighted
            ? AppTheme.primaryLight
            : childColor.withValues(alpha: 0.9);
        final dotPaint = Paint()
          ..color = dotColor
          ..style = PaintingStyle.fill;

        if (isHighlighted) {
          // Glowing dots for highlighted connections
          final glowDot = Paint()
            ..color = AppTheme.primaryLight.withValues(alpha: 0.4)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
          canvas.drawCircle(childPos, 8, glowDot);
          canvas.drawCircle(childPos, 4, dotPaint);
        } else {
          canvas.drawCircle(childPos, 3, dotPaint);
        }
      }
    }
  }

  void _drawTimelineConnections(Canvas canvas) {
    final nodeHalfHeight = nodeHeight / 2;
    // Draw beautiful flowing bezier curves for timeline
    for (final person in persons) {
      final personPos = positions[person.id];
      if (personPos == null) continue;

      final parentGen = generations[person.id] ?? 0;
      final parentColor = AppTheme.getGenerationColor(parentGen);

      for (final childId in index.childrenOf(person).map((c) => c.id)) {
        final childPos = positions[childId];
        if (childPos == null) continue;

        final childGen = generations[childId] ?? (parentGen + 1);
        final childColor = AppTheme.getGenerationColor(childGen);

        final isHighlighted =
            person.id == selectedPersonId || childId == selectedPersonId;
        final isFilteredOut = selectedGeneration != null &&
            parentGen != selectedGeneration &&
            childGen != selectedGeneration;

        final baseOpacity = isFilteredOut ? 0.15 : 0.7;

        // Connection points outside nodes
        final startY = personPos.dy + nodeHalfHeight;
        final endY = childPos.dy - nodeHalfHeight;

        // Control points for elegant S-curve
        final controlPoint1 =
            Offset(personPos.dx, startY + (endY - startY) * 0.4);
        final controlPoint2 =
            Offset(childPos.dx, startY + (endY - startY) * 0.6);

        final path = Path()
          ..moveTo(personPos.dx, startY)
          ..cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx,
              controlPoint2.dy, childPos.dx, endY);

        // Double glow for highlighted
        if (isHighlighted && !isFilteredOut) {
          final outerGlow = Paint()
            ..color = AppTheme.primaryLight.withValues(alpha: 0.15)
            ..strokeWidth = 16
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
          canvas.drawPath(path, outerGlow);

          final innerGlow = Paint()
            ..color = AppTheme.accentTeal.withValues(alpha: 0.35)
            ..strokeWidth = 7
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
          canvas.drawPath(path, innerGlow);
        }

        // Main gradient line
        final paint = Paint()
          ..shader = ui.Gradient.linear(
            Offset(personPos.dx, startY),
            Offset(childPos.dx, endY),
            [
              isHighlighted
                  ? AppTheme.primaryLight
                  : parentColor.withValues(alpha: baseOpacity),
              isHighlighted
                  ? AppTheme.accentTeal
                  : childColor.withValues(alpha: baseOpacity),
            ],
          )
          ..strokeWidth = isHighlighted ? 3.5 : 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        canvas.drawPath(path, paint);

        // Connection dots
        final dotColor = isHighlighted
            ? AppTheme.primaryLight
            : childColor.withValues(alpha: 0.9);
        final dotPaint = Paint()
          ..color = dotColor
          ..style = PaintingStyle.fill;

        // Start dot
        canvas.drawCircle(
            Offset(personPos.dx, startY), isHighlighted ? 4 : 2, dotPaint);

        // End dot with glow if highlighted
        if (isHighlighted) {
          final glowDot = Paint()
            ..color = AppTheme.accentTeal.withValues(alpha: 0.4)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
          canvas.drawCircle(Offset(childPos.dx, endY), 8, glowDot);
        }
        canvas.drawCircle(
            Offset(childPos.dx, endY), isHighlighted ? 4 : 2, dotPaint);
      }
    }
  }

  void _drawTreeConnections(Canvas canvas) {
    // Beautiful flowing bezier curves for tree layout
    final nodeHalfHeight = nodeHeight / 2;
    for (final person in persons) {
      final personPos = positions[person.id];
      if (personPos == null) continue;

      final parentGen = generations[person.id] ?? 0;
      final parentColor = AppTheme.getGenerationColor(parentGen);

      for (final childId in index.childrenOf(person).map((c) => c.id)) {
        final childPos = positions[childId];
        if (childPos == null) continue;

        final childGen = generations[childId] ?? (parentGen + 1);
        final childColor = AppTheme.getGenerationColor(childGen);

        final isFilteredOut = selectedGeneration != null &&
            parentGen != selectedGeneration &&
            childGen != selectedGeneration;

        final isHighlighted = !isFilteredOut &&
            ((focusedPersonIds.contains(person.id) &&
                    focusedPersonIds.contains(childId)) ||
                person.id == selectedPersonId ||
                childId == selectedPersonId);

        final baseOpacity = isFilteredOut ? 0.15 : 0.7;

        // Connection points
        final startY = personPos.dy + nodeHalfHeight;
        final endY = childPos.dy - nodeHalfHeight;

        // Elegant S-curve control points
        final controlPoint1 =
            Offset(personPos.dx, startY + (endY - startY) * 0.4);
        final controlPoint2 =
            Offset(childPos.dx, startY + (endY - startY) * 0.6);

        final path = Path()
          ..moveTo(personPos.dx, startY)
          ..cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx,
              controlPoint2.dy, childPos.dx, endY);

        // Double glow for highlighted connections
        if (isHighlighted && !isFilteredOut) {
          // Outer soft glow
          final outerGlow = Paint()
            ..color = AppTheme.primaryLight.withValues(alpha: 0.15)
            ..strokeWidth = 18
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
          canvas.drawPath(path, outerGlow);

          // Inner bright glow
          final innerGlow = Paint()
            ..color = AppTheme.accentTeal.withValues(alpha: 0.4)
            ..strokeWidth = 8
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
          canvas.drawPath(path, innerGlow);
        }

        // Main gradient line
        final paint = Paint()
          ..shader = ui.Gradient.linear(
            Offset(personPos.dx, startY),
            Offset(childPos.dx, endY),
            [
              isHighlighted
                  ? AppTheme.primaryLight
                  : parentColor.withValues(alpha: baseOpacity),
              isHighlighted
                  ? AppTheme.accentTeal
                  : childColor.withValues(alpha: baseOpacity),
            ],
          )
          ..strokeWidth = isHighlighted ? 3.5 : 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        canvas.drawPath(path, paint);

        // Decorative connection dots
        final dotColor = isHighlighted
            ? AppTheme.primaryLight
            : parentColor.withValues(alpha: 0.9);
        final dotPaint = Paint()
          ..color = dotColor
          ..style = PaintingStyle.fill;

        // Start dot at parent
        canvas.drawCircle(
            Offset(personPos.dx, startY), isHighlighted ? 4 : 2, dotPaint);

        // End dot at child with glow
        final childDotColor = isHighlighted
            ? AppTheme.accentTeal
            : childColor.withValues(alpha: 0.9);
        final childDotPaint = Paint()
          ..color = childDotColor
          ..style = PaintingStyle.fill;

        if (isHighlighted) {
          final glowDot = Paint()
            ..color = AppTheme.accentTeal.withValues(alpha: 0.4)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
          canvas.drawCircle(Offset(childPos.dx, endY), 10, glowDot);
        }
        canvas.drawCircle(
            Offset(childPos.dx, endY), isHighlighted ? 5 : 2, childDotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_ConnectionLinesPainter oldDelegate) {
    return oldDelegate.positions != positions ||
        oldDelegate.selectedPersonId != selectedPersonId ||
        oldDelegate.focusedPersonIds != focusedPersonIds ||
        oldDelegate.selectedGeneration != selectedGeneration ||
        oldDelegate.isDark != isDark ||
        oldDelegate.layoutMode != layoutMode;
  }
}

/// Custom painter for focus mode connection lines (parent to children)
/// Uses the same elegant S-curve bezier style as the full tree view
class _FocusConnectionsPainter extends CustomPainter {
  final Person parent;
  final List<Person> children;
  final Map<String, Offset> positions;
  final Color color;
  final bool isDark;
  final String? selectedChildId;

  _FocusConnectionsPainter({
    required this.parent,
    required this.children,
    required this.positions,
    required this.color,
    required this.isDark,
    this.selectedChildId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (children.isEmpty) return;

    final parentPos = positions[parent.id];
    if (parentPos == null) return;

    // Parent bottom center (where lines start) - matching tree style offset
    final startY = parentPos.dy + 80;

    // Draw elegant S-curve bezier to each child
    for (int i = 0; i < children.length; i++) {
      final child = children[i];
      final childPos = positions[child.id];
      if (childPos == null) continue;

      final endY = childPos.dy - 80;
      final isHighlighted = child.id == selectedChildId;

      // Calculate generation color for child
      final childGen = _getChildGeneration(child);
      final childColor = AppTheme
          .generationColors[childGen % AppTheme.generationColors.length];

      // Control points for elegant S-curve (same as tree view)
      final controlPoint1 =
          Offset(parentPos.dx, startY + (endY - startY) * 0.4);
      final controlPoint2 = Offset(childPos.dx, startY + (endY - startY) * 0.6);

      // Create the bezier path
      final path = Path()
        ..moveTo(parentPos.dx, startY)
        ..cubicTo(
          controlPoint1.dx,
          controlPoint1.dy,
          controlPoint2.dx,
          controlPoint2.dy,
          childPos.dx,
          endY,
        );

      // Highlighted glow effect (stronger when selected)
      if (isHighlighted) {
        final highlightGlow = Paint()
          ..color = AppTheme.primaryLight.withValues(alpha: 0.3)
          ..strokeWidth = 20
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
        canvas.drawPath(path, highlightGlow);

        final innerHighlight = Paint()
          ..color = AppTheme.accentTeal.withValues(alpha: 0.5)
          ..strokeWidth = 10
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
        canvas.drawPath(path, innerHighlight);
      } else {
        // Outer glow effect (normal)
        final outerGlow = Paint()
          ..color = color.withValues(alpha: 0.15)
          ..strokeWidth = 14
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawPath(path, outerGlow);

        // Inner glow
        final innerGlow = Paint()
          ..color = childColor.withValues(alpha: 0.25)
          ..strokeWidth = 6
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        canvas.drawPath(path, innerGlow);
      }

      // Main gradient line
      final paint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(parentPos.dx, startY),
          Offset(childPos.dx, endY),
          [
            isHighlighted
                ? AppTheme.primaryLight
                : color.withValues(alpha: 0.8),
            isHighlighted
                ? AppTheme.accentTeal
                : childColor.withValues(alpha: 0.8),
          ],
        )
        ..strokeWidth = isHighlighted ? 4.5 : 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, paint);

      // Start dot at parent
      final parentDotPaint = Paint()
        ..color = isHighlighted ? AppTheme.primaryLight : color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
          Offset(parentPos.dx, startY), isHighlighted ? 7 : 5, parentDotPaint);

      // End dot at child with glow
      final childDotGlow = Paint()
        ..color = (isHighlighted ? AppTheme.accentTeal : childColor)
            .withValues(alpha: 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, isHighlighted ? 8 : 4);
      canvas.drawCircle(
          Offset(childPos.dx, endY), isHighlighted ? 14 : 10, childDotGlow);

      final childDotPaint = Paint()
        ..color = isHighlighted ? AppTheme.accentTeal : childColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
          Offset(childPos.dx, endY), isHighlighted ? 7 : 5, childDotPaint);
    }
  }

  int _getChildGeneration(Person person) {
    // Simple estimate - children are parent gen + 1
    if (person.relationships.parentIds.isEmpty) return 1;
    return 2;
  }

  @override
  bool shouldRepaint(_FocusConnectionsPainter oldDelegate) {
    return oldDelegate.parent.id != parent.id ||
        oldDelegate.children.length != children.length ||
        oldDelegate.positions != positions ||
        oldDelegate.color != color ||
        oldDelegate.isDark != isDark ||
        oldDelegate.selectedChildId != selectedChildId;
  }
}
