import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/data/models/person.dart';
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
    Key? key,
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
  }) : super(key: key);

  @override
  State<TreeCanvas> createState() => _TreeCanvasState();
}

class _TreeCanvasState extends State<TreeCanvas> with SingleTickerProviderStateMixin {
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
  
  // Navigation controls state
  bool _isMinimapVisible = true;
  int? _selectedGeneration;
  String _searchQuery = '';
  double _currentZoom = 1.0;
  Rect _viewportRect = Rect.zero;
  
  // Focus mode state
  List<String> _focusStack = [];

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
    super.dispose();
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
      maxY + nodeMargin + screenPadding
    );
    
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
    
    // Get root person + all descendants + direct ancestors
    final subtreeIds = <String>{};
    
    // Helper to add descendants
    void addDescendants(String personId) {
      if (subtreeIds.contains(personId)) return;
      subtreeIds.add(personId);
      
      final person = widget.persons.firstWhere(
        (p) => p.id == personId,
        orElse: () => widget.persons.first,
      );
      
      for (final childId in person.relationships.childrenIds) {
        addDescendants(childId);
      }
    }
    
    // Helper to add ancestors
    void addAncestors(String personId) {
      if (subtreeIds.contains(personId)) return;
      subtreeIds.add(personId);
      
      final person = widget.persons.firstWhere(
        (p) => p.id == personId,
        orElse: () => widget.persons.first,
      );
      
      for (final parentId in person.relationships.parentIds) {
        addAncestors(parentId);
      }
    }
    
    addDescendants(widget.focusedSubtreeRoot!);
    addAncestors(widget.focusedSubtreeRoot!);
    
    return widget.persons.where((p) => subtreeIds.contains(p.id)).toList();
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
    ).animate(CurvedAnimation(parent: _tourController, curve: Curves.easeInOutCubic));

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
    
    // Find roots
    final roots = widget.persons.where((p) {
      if (p.relationships.parentIds.isEmpty) return true;
      return !p.relationships.parentIds.any((pid) => widget.persons.any((p2) => p2.id == pid));
    }).toList();
    
    if (roots.isEmpty && widget.persons.isNotEmpty) roots.add(widget.persons.first);

    for (final root in roots) {
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
    
    // Sort children by birth date (Oldest first)
    children.sort((a, b) {
      if (a.birthDate == null && b.birthDate == null) return 0;
      if (a.birthDate == null) return 1;
      if (b.birthDate == null) return -1;
      return a.createdAt.compareTo(b.createdAt);
    });
        
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
    ).animate(CurvedAnimation(parent: _tourController, curve: Curves.easeInOutCubic));

    _tourController.reset();
    await _tourController.forward();
  }

  void _calculateTreeLayout() {
    // Calculate optimal level separation based on viewport height
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Calculate max generation depth
    int maxGeneration = 0;
    final visited = <String>{};
    
    void countGenerations(Person person, int generation) {
      if (visited.contains(person.id)) return;
      visited.add(person.id);
      if (generation > maxGeneration) maxGeneration = generation;
      
      final children = widget.persons
          .where((p) => p.relationships.parentIds.contains(person.id));
      for (final child in children) {
        countGenerations(child, generation + 1);
      }
    }
    
    // Find roots and count generations
    final roots = widget.persons.where((p) {
      if (p.relationships.parentIds.isEmpty) return true;
      return !p.relationships.parentIds.any((pid) => widget.persons.any((p2) => p2.id == pid));
    }).toList();
    
    if (roots.isEmpty && widget.persons.isNotEmpty) roots.add(widget.persons.first);
    for (final root in roots) {
      countGenerations(root, 0);
    }
    
    // Calculate dynamic spacing: use full height but respect min/max
    double levelSeparation = TreeLayoutService.defaultLevelSeparation;
    if (maxGeneration > 0) {
      final availableHeight = screenHeight - 200; // Reserve space for UI elements
      levelSeparation = (availableHeight / maxGeneration).clamp(300.0, 500.0);
    }
    
    // Use the robust layout service with dynamic spacing
    _cachedPositions = TreeLayoutService.calculateTreeLayout(
      _getFilteredPersons(),
      levelSeparation: levelSeparation,
    );
    
    // Calculate generations for rendering
    _cachedGenerations = {};
    // We can infer generation from Y position since it's fixed height
    for (final entry in _cachedPositions.entries) {
      _cachedGenerations[entry.key] = (entry.value.dy / levelSeparation).round();
    }
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

    // Find root
    final root = widget.persons.firstWhere(
      (p) => p.relationships.parentIds.isEmpty,
      orElse: () => widget.persons.first,
    );

    // Radius settings
    const baseRadius = 300.0;
    const radiusStep = 250.0;

    // Place root at center
    _cachedPositions[root.id] = Offset(centerX, centerY);
    _cachedGenerations[root.id] = 0;

    // Recursive function to place nodes in arcs
    void placeChildren(Person parent, int generation, double startAngle, double endAngle) {
      final children = widget.persons
          .where((p) => p.relationships.parentIds.contains(parent.id))
          .toList();
      
      if (children.isEmpty) return;

      // Sort children by birth date for consistent ordering
      children.sort((a, b) {
        if (a.birthDate == null && b.birthDate == null) return 0;
        if (a.birthDate == null) return 1;
        if (b.birthDate == null) return -1;
        return a.createdAt.compareTo(b.createdAt);
      });

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

    // Find root(s)
    final roots = widget.persons.where((p) {
      if (p.relationships.parentIds.isEmpty) return true;
      return !p.relationships.parentIds.any(
        (pid) => widget.persons.any((p2) => p2.id == pid)
      );
    }).toList();

    if (roots.isEmpty && widget.persons.isNotEmpty) {
      roots.add(widget.persons.first);
    }

    // Sort roots by birth date
    roots.sort((a, b) {
      if (a.birthDate == null && b.birthDate == null) return 0;
      if (a.birthDate == null) return 1;
      if (b.birthDate == null) return -1;
      return a.createdAt.compareTo(b.createdAt);
    });

    // Layout settings
    const startX = 150.0;
    const startY = 100.0;
    const horizontalSpacing = 200.0; // Space between nodes in same row
    const verticalSpacing = 220.0;   // Space between generations
    
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
      
      children.sort((a, b) {
        if (a.birthDate == null && b.birthDate == null) return 0;
        if (a.birthDate == null) return 1;
        if (b.birthDate == null) return -1;
        return a.createdAt.compareTo(b.createdAt);
      });

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
        
        grandchildren.sort((a, b) {
          if (a.birthDate == null && b.birthDate == null) return 0;
          if (a.birthDate == null) return 1;
          if (b.birthDate == null) return -1;
          return a.createdAt.compareTo(b.createdAt);
        });

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

  Set<String> _getVisibleNodeIds() {
    final visibleIds = <String>{};
    // Find roots (no parents or parents not in list)
    final roots = widget.persons.where((p) {
      if (p.relationships.parentIds.isEmpty) return true;
      return !p.relationships.parentIds.any((pid) => widget.persons.any((p2) => p2.id == pid));
    }).toList();
    
    if (roots.isEmpty && widget.persons.isNotEmpty) roots.add(widget.persons.first);

    for (final root in roots) {
      _collectVisibleDescendants(root, visibleIds);
    }
    return visibleIds;
  }

  void _collectVisibleDescendants(Person node, Set<String> visibleIds) {
    if (visibleIds.contains(node.id)) return;
    visibleIds.add(node.id);
    
    final children = widget.persons
        .where((p) => p.relationships.parentIds.contains(node.id));
        
    for (final child in children) {
      _collectVisibleDescendants(child, visibleIds);
    }
  }

  int _calculateGeneration(Person person, {Set<String>? visited}) {
    visited ??= {};
    if (visited.contains(person.id)) return 0;
    visited.add(person.id);

    if (person.relationships.parentIds.isEmpty) return 0;
    
    int maxParentGen = -1;
    for (final parentId in person.relationships.parentIds) {
      final parent = widget.persons.firstWhere(
        (p) => p.id == parentId,
        orElse: () => person,
      );
      if (parent.id != person.id) {
        maxParentGen = math.max(maxParentGen, _calculateGeneration(parent, visited: visited));
      }
    }
    return maxParentGen + 1;
  }

  void _calculateListLayout() {
    // Tree-style list layout with straight lines (like file explorer)
    _cachedPositions = {};
    _cachedGenerations = {};

    if (widget.persons.isEmpty) return;

    // Find roots
    final roots = widget.persons.where((p) {
      if (p.relationships.parentIds.isEmpty) return true;
      return !p.relationships.parentIds.any(
        (pid) => widget.persons.any((p2) => p2.id == pid)
      );
    }).toList();

    if (roots.isEmpty && widget.persons.isNotEmpty) {
      roots.add(widget.persons.first);
    }

    // Layout parameters - nodes are ~140x160px
    const double startX = 120;
    const double startY = 100;
    const double indentPerLevel = 200; // Horizontal indent per generation
    const double verticalSpacing = 180; // Space between nodes (node height + gap)
    
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

      // Get children and sort by birth date
      final children = widget.persons
          .where((p) => p.relationships.parentIds.contains(person.id))
          .toList();
      
      children.sort((a, b) {
        if (a.birthDate == null && b.birthDate == null) return 0;
        if (a.birthDate == null) return 1;
        if (b.birthDate == null) return -1;
        return a.createdAt.compareTo(b.createdAt);
      });

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
              scaleEnabled: false, // Disable scroll/pinch zoom - use buttons only
              panEnabled: true,
              child: SizedBox(
                width: _canvasSize.width,
                height: _canvasSize.height,
                child: CustomPaint(
                  painter: _ConnectionLinesPainter(
                    persons: widget.persons,
                    positions: _cachedPositions,
                    generations: _cachedGenerations,
                    selectedPersonId: widget.selectedPersonId,
                    focusedPersonIds: widget.focusedPersonIds.toSet(),
                    selectedGeneration: _selectedGeneration,
                    isDark: isDark,
                    layoutMode: widget.layoutMode,
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
            onToggleMinimap: () => setState(() => _isMinimapVisible = !_isMinimapVisible),
          ),
        ),
        
        // Back to Full Tree button - simple and functional
        if (widget.focusedSubtreeRoot != null && widget.onClearSubtreeFocus != null)
          Positioned(
            bottom: 80,
            left: 20,
            child: FloatingActionButton.extended(
              heroTag: 'back_button',
              onPressed: widget.onClearSubtreeFocus,
              backgroundColor: AppTheme.accentTeal,
              icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
              label: const Text('Back to Full Tree', style: TextStyle(color: Colors.white)),
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
            backgroundColor: _isTourActive ? AppTheme.error : AppTheme.primaryLight,
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

  // Focus layout methods
  Widget _buildFocusLayout(BuildContext context, bool isDark) {
    if (widget.persons.isEmpty) return const SizedBox();
    
    final patriarch = widget.persons.firstWhere(
      (p) => p.relationships.parentIds.isEmpty, orElse: () => widget.persons.first);
    
    Person currentPerson = _focusStack.isEmpty ? patriarch : widget.persons.firstWhere(
      (p) => p.id == _focusStack.last, orElse: () => patriarch);
    
    final children = widget.persons.where((p) => 
      p.relationships.parentIds.contains(currentPerson.id)).toList()
      ..sort((a, b) => (a.createdAt).compareTo(b.createdAt));
    
    final isRoot = _focusStack.isEmpty;
    final gen = _getPersonGeneration(currentPerson);
    final color = AppTheme.generationColors[gen % AppTheme.generationColors.length];
    final childCount = children.length;
    
    return Container(
      color: isDark ? AppTheme.backgroundDark : const Color(0xFFFAF8F5),
      child: Column(
        children: [
          if (!isRoot) _buildFocusNav(currentPerson, color, isDark),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFocusPersonCard(currentPerson, color, gen, isRoot, isDark, childCount),
                    if (children.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(width: 3, height: 20, decoration: BoxDecoration(
                        color: color.withOpacity(0.4), borderRadius: BorderRadius.circular(2))),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.surfaceDark : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: color.withOpacity(0.2))),
                        child: Text('${children.length} ${children.length == 1 ? 'Child' : 'Children'}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(builder: (context, constraints) {
                        return Wrap(
                          spacing: _getCardSpacing(childCount),
                          runSpacing: _getCardSpacing(childCount),
                          alignment: WrapAlignment.center,
                          children: children.asMap().entries.map((e) => 
                            _buildFocusChildCard(e.value, e.key, isDark, childCount)).toList(),
                        );
                      }),
                    ] else ...[
                      const SizedBox(height: 32),
                      Icon(Icons.family_restroom_rounded, size: 36, color: Colors.grey.withOpacity(0.25)),
                      const SizedBox(height: 8),
                      Text('No children recorded', style: TextStyle(fontSize: 13, color: Colors.grey.withOpacity(0.6))),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (!isRoot) _buildFocusFooterNav(currentPerson, isDark),
        ],
      ),
    );
  }
  
  double _getCardSpacing(int count) {
    if (count <= 3) return 16;
    if (count <= 6) return 12;
    return 8;
  }
  
  double _getChildCardWidth(int count) {
    if (count == 1) return 180;
    if (count == 2) return 160;
    if (count <= 4) return 140;
    if (count <= 6) return 120;
    if (count <= 9) return 105;
    return 95;
  }
  
  double _getChildAvatarSize(int count) {
    if (count <= 2) return 50;
    if (count <= 4) return 44;
    if (count <= 6) return 38;
    return 32;
  }
  
  double _getChildFontSize(int count) {
    if (count <= 2) return 14;
    if (count <= 4) return 13;
    if (count <= 6) return 12;
    return 11;
  }

  Widget _buildFocusNav(Person person, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: isDark ? AppTheme.surfaceDark : Colors.white, border: Border(bottom: BorderSide(color: color.withOpacity(0.2)))),
      child: Row(children: [
        GestureDetector(
          onTap: () => setState(() { if (_focusStack.isNotEmpty) _focusStack.removeLast(); }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: isDark ? AppTheme.backgroundDark : const Color(0xFFF5F0E8), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Icon(Icons.arrow_back, size: 16, color: isDark ? Colors.white : Colors.black87),
              const SizedBox(width: 6),
              Text('Back', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
            ]),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          GestureDetector(onTap: () => setState(() => _focusStack.clear()),
            child: Text('Home', style: TextStyle(fontSize: 13, color: AppTheme.primaryLight, fontWeight: FontWeight.w600))),
          ..._focusStack.map((id) {
            final p = widget.persons.firstWhere((x) => x.id == id, orElse: () => person);
            final isLast = id == _focusStack.last;
            return Row(children: [
              Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.chevron_right, size: 14, color: Colors.grey)),
              GestureDetector(
                onTap: isLast ? null : () => setState(() => _focusStack = _focusStack.sublist(0, _focusStack.indexOf(id) + 1)),
                child: Text(p.firstName, style: TextStyle(fontSize: 13, fontWeight: isLast ? FontWeight.w700 : FontWeight.w500, color: isLast ? (isDark ? Colors.white : Colors.black87) : Colors.grey)),
              ),
            ]);
          }),
        ]))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
          child: Text('Gen ${_getPersonGeneration(person)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ),
      ]),
    );
  }

  Widget _buildFocusPersonCard(Person person, Color color, int gen, bool isRoot, bool isDark, int childCount) {
    final descCount = _getDescendantCount(person);
    // Adjust parent card size based on child count
    final avatarSize = childCount > 6 ? 55.0 : 65.0;
    final fontSize = childCount > 6 ? 16.0 : 18.0;
    final padding = childCount > 6 ? 16.0 : 20.0;
    
    return Container(
      constraints: BoxConstraints(maxWidth: childCount > 6 ? 360 : 400),
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Row(children: [
        Container(width: avatarSize, height: avatarSize,
          decoration: BoxDecoration(gradient: LinearGradient(colors: [color.withOpacity(0.8), color]), shape: BoxShape.circle),
          child: Center(child: Text(person.firstName[0], style: TextStyle(fontSize: avatarSize * 0.4, fontWeight: FontWeight.bold, color: Colors.white)))),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
            child: Text(isRoot ? '★ PATRIARCH' : 'GEN $gen', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1))),
          const SizedBox(height: 5),
          Text(person.fullName, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          if (person.lifespan.isNotEmpty) Text(person.lifespan, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 3),
          Text('$descCount descendants', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ])),
      ]),
    );
  }

  Widget _buildFocusChildCard(Person person, int index, bool isDark, int totalChildren) {
    final color = AppTheme.generationColors[_getPersonGeneration(person) % AppTheme.generationColors.length];
    final descCount = _getDescendantCount(person);
    final hasChildren = descCount > 0;
    
    // Dynamic sizing based on total children count
    final cardWidth = _getChildCardWidth(totalChildren);
    final avatarSize = _getChildAvatarSize(totalChildren);
    final fontSize = _getChildFontSize(totalChildren);
    final isCompact = totalChildren > 6;
    final padding = isCompact ? 10.0 : 14.0;
    
    return GestureDetector(
      onTap: () => setState(() => _focusStack.add(person.id)),
      child: Container(
        width: cardWidth,
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(isCompact ? 12 : 14),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3))]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: avatarSize, height: avatarSize,
            decoration: BoxDecoration(gradient: LinearGradient(colors: [color.withOpacity(0.8), color]), shape: BoxShape.circle),
            child: Center(child: Text(person.firstName[0], style: TextStyle(fontSize: avatarSize * 0.44, fontWeight: FontWeight.bold, color: Colors.white)))),
          SizedBox(height: isCompact ? 6 : 10),
          Text(person.firstName, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87), overflow: TextOverflow.ellipsis, maxLines: 1),
          if (!isCompact) Text(person.lastName, style: TextStyle(fontSize: fontSize - 3, color: Colors.grey), overflow: TextOverflow.ellipsis),
          SizedBox(height: isCompact ? 4 : 8),
          Text(hasChildren ? '$descCount desc.' : 'No children', style: TextStyle(fontSize: isCompact ? 9 : 10, color: hasChildren ? color : Colors.grey)),
          SizedBox(height: isCompact ? 4 : 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 12, vertical: isCompact ? 4 : 6),
            decoration: BoxDecoration(color: hasChildren ? color : Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
            child: Text(hasChildren ? 'Explore' : 'View', style: TextStyle(fontSize: isCompact ? 10 : 11, fontWeight: FontWeight.w600, color: Colors.white))),
        ]),
      ),
    );
  }

  Widget _buildFocusFooterNav(Person person, bool isDark) {
    List<Person> siblings = [];
    if (person.relationships.parentIds.isNotEmpty) {
      final parentId = person.relationships.parentIds.first;
      siblings = widget.persons.where((p) => p.relationships.parentIds.contains(parentId)).toList();
    }
    final idx = siblings.indexWhere((p) => p.id == person.id);
    final hasPrev = idx > 0;
    final hasNext = idx < siblings.length - 1;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: isDark ? AppTheme.surfaceDark : Colors.white, border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2)))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        if (hasPrev) _buildSiblingBtn(siblings[idx - 1], true, isDark) else const SizedBox(width: 100),
        GestureDetector(
          onTap: () => setState(() { if (_focusStack.isNotEmpty) _focusStack.removeLast(); }),
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [const Icon(Icons.arrow_upward, size: 16, color: Colors.white), const SizedBox(width: 6),
              const Text('Back to Parent', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white))])),
        ),
        if (hasNext) _buildSiblingBtn(siblings[idx + 1], false, isDark) else const SizedBox(width: 100),
      ]),
    );
  }

  Widget _buildSiblingBtn(Person sibling, bool isPrev, bool isDark) {
    final color = AppTheme.generationColors[_getPersonGeneration(sibling) % AppTheme.generationColors.length];
    return GestureDetector(
      onTap: () => setState(() { if (_focusStack.isNotEmpty) _focusStack[_focusStack.length - 1] = sibling.id; }),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.3))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (isPrev) Icon(Icons.arrow_back, size: 14, color: color),
          if (isPrev) const SizedBox(width: 6),
          Container(width: 24, height: 24, decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Center(child: Text(sibling.firstName[0], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)))),
          const SizedBox(width: 6),
          Text(sibling.firstName, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          if (!isPrev) const SizedBox(width: 6),
          if (!isPrev) Icon(Icons.arrow_forward, size: 14, color: color),
        ]),
      ),
    );
  }

  int _getPersonGeneration(Person person) {
    if (person.relationships.parentIds.isEmpty) return 1;
    int gen = 1;
    var current = person;
    while (current.relationships.parentIds.isNotEmpty) {
      final parent = widget.persons.firstWhere((p) => p.id == current.relationships.parentIds.first, orElse: () => current);
      if (parent.id == current.id) break;
      current = parent;
      gen++;
    }
    return gen;
  }

  int _getDescendantCount(Person person) {
    int count = 0;
    final children = widget.persons.where((p) => p.relationships.parentIds.contains(person.id));
    for (final child in children) {
      count += 1 + _getDescendantCount(child);
    }
    return count;
  }

  List<Widget> _buildPersonNodes() {
    // 1. Identify the root (Mohammed)
    final root = widget.persons.firstWhere(
      (p) => p.relationships.parentIds.isEmpty,
      orElse: () => widget.persons.first,
    );

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
      final selectedPerson = widget.persons.firstWhere(
        (p) => p.id == selectedId, 
        orElse: () => widget.persons.first
      );
      
      spotlightIds.add(selectedId);
      // Add Parents
      spotlightIds.addAll(selectedPerson.relationships.parentIds);
      // Add Children
      spotlightIds.addAll(selectedPerson.relationships.childrenIds);
      // Add Spouses
      spotlightIds.addAll(selectedPerson.relationships.spouses.map((s) => s.personId));
    }

    return widget.persons.map((person) {
      final position = _cachedPositions[person.id] ?? Offset.zero;
      final generation = _cachedGenerations[person.id] ?? 0; // Force update
      final isSelected = person.id == widget.selectedPersonId;
      final isFocused = widget.focusedPersonIds.isEmpty ||
          widget.focusedPersonIds.contains(person.id);
      
      // No dimming - just highlight selected nodes
      // Only apply subtle dimming for generation filter, not blur
      final isGenerationFiltered = _selectedGeneration != null && generation != _selectedGeneration;
      final isDimmed = isGenerationFiltered; // Only dim for generation filter, not selection

      // Determine color based on branch
      Color? nodeColor;
      if (personBranchMap.containsKey(person.id)) {
        final branchIndex = personBranchMap[person.id]!;
        // Use generation colors but cycle through them based on branch index
        // We skip index 0 (red) for root if we want, or just use it.
        // Let's shift by 1 to avoid Red for everyone if root is 0.
        nodeColor = AppTheme.generationColors[branchIndex % AppTheme.generationColors.length];
      }

      return Positioned(
        left: position.dx - 60,
        top: position.dy - 80,
        child: PersonNode(
          person: person,
          generation: generation,
          isSelected: isSelected,
          isFocused: isFocused,
          isDimmed: isDimmed,
          color: nodeColor,
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
  final Map<String, Offset> positions;
  final Map<String, int> generations;
  final String? selectedPersonId;
  final Set<String> focusedPersonIds;
  final int? selectedGeneration;
  final bool isDark;
  final LayoutMode layoutMode;

  _ConnectionLinesPainter({
    required this.persons,
    required this.positions,
    required this.generations,
    this.selectedPersonId,
    required this.focusedPersonIds,
    this.selectedGeneration,
    this.isDark = true,
    this.layoutMode = LayoutMode.tree,
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

      for (final childId in person.relationships.childrenIds) {
        final childPos = positions[childId];
        if (childPos == null) continue;
        
        final childGen = generations[childId] ?? (parentGen + 1);
        final childColor = AppTheme.getGenerationColor(childGen);

        final isHighlighted = person.id == selectedPersonId || childId == selectedPersonId;
        final isFilteredOut = selectedGeneration != null &&
            parentGen != selectedGeneration && childGen != selectedGeneration;

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
              isHighlighted ? AppTheme.primaryLight : parentColor.withValues(alpha: baseOpacity),
              isHighlighted ? AppTheme.accentTeal : childColor.withValues(alpha: baseOpacity),
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
        final dotColor = isHighlighted ? AppTheme.primaryLight : childColor.withValues(alpha: 0.8);
        final dotPaint = Paint()
          ..color = dotColor
          ..style = PaintingStyle.fill;
        
        // Corner dot
        canvas.drawCircle(Offset(cornerX, endY), isHighlighted ? 5 : 3, dotPaint);
        
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

      for (final childId in person.relationships.childrenIds) {
        final childPos = positions[childId];
        if (childPos == null) continue;
        
        final childGen = generations[childId] ?? (parentGen + 1);
        final childColor = AppTheme.getGenerationColor(childGen);

        final isHighlighted = person.id == selectedPersonId || childId == selectedPersonId;
        final isFilteredOut = selectedGeneration != null &&
            parentGen != selectedGeneration && childGen != selectedGeneration;

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
              isHighlighted ? AppTheme.primaryLight : parentColor.withValues(alpha: baseOpacity),
              isHighlighted ? AppTheme.accentTeal : childColor.withValues(alpha: baseOpacity),
            ],
          )
          ..strokeWidth = isHighlighted ? 3.5 : 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        canvas.drawPath(path, paint);
        
        // Connection dots
        final dotColor = isHighlighted ? AppTheme.primaryLight : childColor.withValues(alpha: 0.9);
        final dotPaint = Paint()..color = dotColor..style = PaintingStyle.fill;
        
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
    // Draw beautiful flowing bezier curves for timeline
    for (final person in persons) {
      final personPos = positions[person.id];
      if (personPos == null) continue;
      
      final parentGen = generations[person.id] ?? 0;
      final parentColor = AppTheme.getGenerationColor(parentGen);

      for (final childId in person.relationships.childrenIds) {
        final childPos = positions[childId];
        if (childPos == null) continue;
        
        final childGen = generations[childId] ?? (parentGen + 1);
        final childColor = AppTheme.getGenerationColor(childGen);

        final isHighlighted = person.id == selectedPersonId || childId == selectedPersonId;
        final isFilteredOut = selectedGeneration != null &&
            parentGen != selectedGeneration && childGen != selectedGeneration;

        final baseOpacity = isFilteredOut ? 0.15 : 0.7;

        // Connection points outside nodes
        final startY = personPos.dy + 80;
        final endY = childPos.dy - 80;
        
        // Control points for elegant S-curve
        final controlPoint1 = Offset(personPos.dx, startY + (endY - startY) * 0.4);
        final controlPoint2 = Offset(childPos.dx, startY + (endY - startY) * 0.6);

        final path = Path()
          ..moveTo(personPos.dx, startY)
          ..cubicTo(controlPoint1.dx, controlPoint1.dy,
                    controlPoint2.dx, controlPoint2.dy,
                    childPos.dx, endY);

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
              isHighlighted ? AppTheme.primaryLight : parentColor.withValues(alpha: baseOpacity),
              isHighlighted ? AppTheme.accentTeal : childColor.withValues(alpha: baseOpacity),
            ],
          )
          ..strokeWidth = isHighlighted ? 3.5 : 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        canvas.drawPath(path, paint);
        
        // Connection dots
        final dotColor = isHighlighted ? AppTheme.primaryLight : childColor.withValues(alpha: 0.9);
        final dotPaint = Paint()..color = dotColor..style = PaintingStyle.fill;
        
        // Start dot
        canvas.drawCircle(Offset(personPos.dx, startY), isHighlighted ? 4 : 2, dotPaint);
        
        // End dot with glow if highlighted
        if (isHighlighted) {
          final glowDot = Paint()
            ..color = AppTheme.accentTeal.withValues(alpha: 0.4)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
          canvas.drawCircle(Offset(childPos.dx, endY), 8, glowDot);
        }
        canvas.drawCircle(Offset(childPos.dx, endY), isHighlighted ? 4 : 2, dotPaint);
      }
    }
  }

  void _drawTreeConnections(Canvas canvas) {
    // Beautiful flowing bezier curves for tree layout
    for (final person in persons) {
      final personPos = positions[person.id];
      if (personPos == null) continue;
      
      final parentGen = generations[person.id] ?? 0;
      final parentColor = AppTheme.getGenerationColor(parentGen);

      for (final childId in person.relationships.childrenIds) {
        final childPos = positions[childId];
        if (childPos == null) continue;
        
        final childGen = generations[childId] ?? (parentGen + 1);
        final childColor = AppTheme.getGenerationColor(childGen);

        final isFilteredOut = selectedGeneration != null &&
            parentGen != selectedGeneration && childGen != selectedGeneration;

        final isHighlighted = !isFilteredOut &&
            ((focusedPersonIds.contains(person.id) &&
                focusedPersonIds.contains(childId)) ||
            person.id == selectedPersonId ||
            childId == selectedPersonId);

        final baseOpacity = isFilteredOut ? 0.15 : 0.7;

        // Connection points
        final startY = personPos.dy + 80;
        final endY = childPos.dy - 80;

        // Elegant S-curve control points
        final controlPoint1 = Offset(personPos.dx, startY + (endY - startY) * 0.4);
        final controlPoint2 = Offset(childPos.dx, startY + (endY - startY) * 0.6);

        final path = Path()
          ..moveTo(personPos.dx, startY)
          ..cubicTo(controlPoint1.dx, controlPoint1.dy,
                    controlPoint2.dx, controlPoint2.dy,
                    childPos.dx, endY);

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
              isHighlighted ? AppTheme.primaryLight : parentColor.withValues(alpha: baseOpacity),
              isHighlighted ? AppTheme.accentTeal : childColor.withValues(alpha: baseOpacity),
            ],
          )
          ..strokeWidth = isHighlighted ? 3.5 : 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        canvas.drawPath(path, paint);
        
        // Decorative connection dots
        final dotColor = isHighlighted ? AppTheme.primaryLight : parentColor.withValues(alpha: 0.9);
        final dotPaint = Paint()..color = dotColor..style = PaintingStyle.fill;
        
        // Start dot at parent
        canvas.drawCircle(Offset(personPos.dx, startY), isHighlighted ? 4 : 2, dotPaint);
        
        // End dot at child with glow
        final childDotColor = isHighlighted ? AppTheme.accentTeal : childColor.withValues(alpha: 0.9);
        final childDotPaint = Paint()..color = childDotColor..style = PaintingStyle.fill;
        
        if (isHighlighted) {
          final glowDot = Paint()
            ..color = AppTheme.accentTeal.withValues(alpha: 0.4)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
          canvas.drawCircle(Offset(childPos.dx, endY), 10, glowDot);
        }
        canvas.drawCircle(Offset(childPos.dx, endY), isHighlighted ? 5 : 2, childDotPaint);
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

class _LeafCounter {
  int value = 0;
}
