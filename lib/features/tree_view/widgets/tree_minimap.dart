import 'package:flutter/material.dart';
import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/data/models/person.dart';

/// A minimap widget that provides an overview of the entire family tree
/// and allows quick navigation to any part of the tree.
class TreeMinimap extends StatelessWidget {
  final List<Person> persons;
  final Map<String, Offset> positions;
  final Map<String, int> generations;
  final String? selectedPersonId;
  final Rect viewportRect;
  final Size canvasSize;
  final Function(Offset) onNavigate;
  final VoidCallback? onClose;

  const TreeMinimap({
    super.key,
    required this.persons,
    required this.positions,
    required this.generations,
    this.selectedPersonId,
    required this.viewportRect,
    required this.canvasSize,
    required this.onNavigate,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: 200,
      height: 150,
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.surfaceDark.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Minimap content
            GestureDetector(
              onTapDown: (details) => _handleTap(details.localPosition),
              onPanUpdate: (details) => _handleTap(details.localPosition),
              child: CustomPaint(
                size: const Size(200, 150),
                painter: _MinimapPainter(
                  persons: persons,
                  positions: positions,
                  generations: generations,
                  selectedPersonId: selectedPersonId,
                  viewportRect: viewportRect,
                  canvasSize: canvasSize,
                  isDark: isDark,
                ),
              ),
            ),
            
            // Header
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.map_outlined,
                      size: 14,
                      color: isDark
                          ? AppTheme.textSecondaryDark
                          : AppTheme.textSecondaryLight,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Overview',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppTheme.textSecondaryDark
                            : AppTheme.textSecondaryLight,
                      ),
                    ),
                    const Spacer(),
                    if (onClose != null)
                      GestureDetector(
                        onTap: onClose,
                        child: Icon(
                          Icons.close,
                          size: 14,
                          color: isDark
                              ? AppTheme.textMutedDark
                              : AppTheme.textMutedLight,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Person count badge
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${persons.length} people',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primaryLight,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleTap(Offset localPosition) {
    // Convert minimap position to canvas position
    const minimapSize = Size(200, 150);
    const padding = 20.0;
    
    // Calculate scale
    final scaleX = (canvasSize.width) / (minimapSize.width - padding * 2);
    final scaleY = (canvasSize.height) / (minimapSize.height - padding * 2);
    
    // Convert to canvas coordinates
    final canvasX = (localPosition.dx - padding) * scaleX;
    final canvasY = (localPosition.dy - padding) * scaleY;
    
    onNavigate(Offset(canvasX, canvasY));
  }
}

class _MinimapPainter extends CustomPainter {
  final List<Person> persons;
  final Map<String, Offset> positions;
  final Map<String, int> generations;
  final String? selectedPersonId;
  final Rect viewportRect;
  final Size canvasSize;
  final bool isDark;

  _MinimapPainter({
    required this.persons,
    required this.positions,
    required this.generations,
    this.selectedPersonId,
    required this.viewportRect,
    required this.canvasSize,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (positions.isEmpty) return;
    
    const padding = 20.0;
    final drawArea = Rect.fromLTWH(
      padding,
      padding + 10, // Extra for header
      size.width - padding * 2,
      size.height - padding * 2 - 10,
    );
    
    // Calculate bounds
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    
    for (final pos in positions.values) {
      if (pos.dx < minX) minX = pos.dx;
      if (pos.dx > maxX) maxX = pos.dx;
      if (pos.dy < minY) minY = pos.dy;
      if (pos.dy > maxY) maxY = pos.dy;
    }
    
    // Add margin
    const margin = 50.0;
    minX -= margin;
    minY -= margin;
    maxX += margin;
    maxY += margin;
    
    final contentWidth = maxX - minX;
    final contentHeight = maxY - minY;
    
    // Scale factors
    final scaleX = drawArea.width / contentWidth;
    final scaleY = drawArea.height / contentHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;
    
    // Center offset
    final offsetX = drawArea.left + (drawArea.width - contentWidth * scale) / 2;
    final offsetY = drawArea.top + (drawArea.height - contentHeight * scale) / 2;
    
    // Draw connections
    final connectionPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    
    for (final person in persons) {
      final pos = positions[person.id];
      if (pos == null) continue;
      
      for (final childId in person.relationships.childrenIds) {
        final childPos = positions[childId];
        if (childPos == null) continue;
        
        final startX = offsetX + (pos.dx - minX) * scale;
        final startY = offsetY + (pos.dy - minY) * scale;
        final endX = offsetX + (childPos.dx - minX) * scale;
        final endY = offsetY + (childPos.dy - minY) * scale;
        
        canvas.drawLine(
          Offset(startX, startY),
          Offset(endX, endY),
          connectionPaint,
        );
      }
    }
    
    // Draw nodes
    for (final person in persons) {
      final pos = positions[person.id];
      if (pos == null) continue;
      
      final generation = generations[person.id] ?? 0;
      final color = AppTheme.getGenerationColor(generation);
      final isSelected = person.id == selectedPersonId;
      
      final nodeX = offsetX + (pos.dx - minX) * scale;
      final nodeY = offsetY + (pos.dy - minY) * scale;
      
      final paint = Paint()
        ..color = isSelected ? AppTheme.primaryLight : color
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(
        Offset(nodeX, nodeY),
        isSelected ? 4 : 2.5,
        paint,
      );
      
      if (isSelected) {
        final ringPaint = Paint()
          ..color = AppTheme.primaryLight.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        
        canvas.drawCircle(
          Offset(nodeX, nodeY),
          6,
          ringPaint,
        );
      }
    }
    
    // Draw viewport rectangle
    if (canvasSize.width > 0 && canvasSize.height > 0) {
      final viewportPaint = Paint()
        ..color = AppTheme.primaryLight.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;
      
      final viewportStrokePaint = Paint()
        ..color = AppTheme.primaryLight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      
      // Calculate viewport in minimap coordinates
      final vpLeft = offsetX + (viewportRect.left - minX) * scale;
      final vpTop = offsetY + (viewportRect.top - minY) * scale;
      final vpWidth = viewportRect.width * scale;
      final vpHeight = viewportRect.height * scale;
      
      final vpRect = Rect.fromLTWH(
        vpLeft.clamp(drawArea.left, drawArea.right - 10),
        vpTop.clamp(drawArea.top, drawArea.bottom - 10),
        vpWidth.clamp(10, drawArea.width),
        vpHeight.clamp(10, drawArea.height),
      );
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(vpRect, const Radius.circular(2)),
        viewportPaint,
      );
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(vpRect, const Radius.circular(2)),
        viewportStrokePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_MinimapPainter oldDelegate) {
    return oldDelegate.selectedPersonId != selectedPersonId ||
           oldDelegate.viewportRect != viewportRect ||
           oldDelegate.positions != positions;
  }
}
