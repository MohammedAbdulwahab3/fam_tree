import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/core/theme/app_colors.dart';
import 'package:family_tree/core/theme/elegant_theme.dart';
import 'package:family_tree/core/design/typography.dart';

/// Pinch, drag and rotate a picture until the face sits right, then keep only
/// the square you framed.
///
/// Profile photos are drawn inside a circle with `BoxFit.cover`, which crops
/// whatever does not fit — off-centre and unpredictably. Cropping here means
/// the stored image already *is* the square everyone will see, so the card can
/// never cut someone's head off.
///
/// Uses `package:image` on the raw bytes rather than a platform cropper, so it
/// behaves identically on web, Android and iOS.
class PhotoCropSheet extends StatefulWidget {
  const PhotoCropSheet({
    super.key,
    required this.bytes,
    this.title = 'Position your photo',
  });

  final Uint8List bytes;
  final String title;

  /// Returns the cropped square as PNG bytes, or null if cancelled.
  static Future<Uint8List?> show(
    BuildContext context, {
    required Uint8List bytes,
    String title = 'Position your photo',
  }) {
    return showModalBottomSheet<Uint8List>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PhotoCropSheet(bytes: bytes, title: title),
    );
  }

  @override
  State<PhotoCropSheet> createState() => _PhotoCropSheetState();
}

class _PhotoCropSheetState extends State<PhotoCropSheet> {
  /// How much of the image is scaled up inside the frame. 1 means the image is
  /// exactly contained; larger zooms in.
  double _zoom = 1;

  /// Pan in frame pixels, from the centre.
  Offset _offset = Offset.zero;

  /// Quarter turns, for photos that arrive on their side.
  int _quarterTurns = 0;

  Offset _dragStart = Offset.zero;
  Offset _offsetStart = Offset.zero;
  double _zoomStart = 1;

  bool _working = false;
  String? _error;

  static const double _frame = 280;
  static const double _maxZoom = 4;

  img.Image? _decodedCache;
  bool _decodeAttempted = false;

  /// Decoded once, and defensively: `decodeImage` throws on a file that is not
  /// an image rather than returning null, which would otherwise crash the
  /// sheet instead of showing the "could not be read" message.
  img.Image? get _decoded {
    if (_decodeAttempted) return _decodedCache;
    _decodeAttempted = true;
    try {
      _decodedCache = img.decodeImage(widget.bytes);
    } catch (_) {
      _decodedCache = null;
    }
    return _decodedCache;
  }

  /// Clamp the pan so the image can never be dragged off the frame, leaving a
  /// blank wedge in the circle.
  Offset _clamp(Offset value, Size displaySize) {
    final scaled = Size(displaySize.width * _zoom, displaySize.height * _zoom);
    final slackX = math.max(0.0, (scaled.width - _frame) / 2);
    final slackY = math.max(0.0, (scaled.height - _frame) / 2);
    return Offset(
      value.dx.clamp(-slackX, slackX),
      value.dy.clamp(-slackY, slackY),
    );
  }

  /// The size the image is drawn at inside the frame before zoom — `contain`,
  /// so the whole picture is reachable.
  Size _displaySize(int width, int height) {
    if (width == 0 || height == 0) return const Size(_frame, _frame);
    final swapped = _quarterTurns.isOdd;
    final w = (swapped ? height : width).toDouble();
    final h = (swapped ? width : height).toDouble();
    final scale = math.max(_frame / w, _frame / h);
    return Size(w * scale, h * scale);
  }

  Future<void> _confirm(img.Image source) async {
    setState(() {
      _working = true;
      _error = null;
    });

    try {
      final rotated = _quarterTurns == 0
          ? source
          : img.copyRotate(source, angle: _quarterTurns * 90);

      final display = _displaySize(source.width, source.height);
      // Frame pixels -> source pixels. Both axes share a scale because the
      // display size was computed with a single uniform factor.
      final pixelsPerFrameUnit = rotated.width / display.width;

      final cropSide = (_frame / _zoom) * pixelsPerFrameUnit;
      final centreX = rotated.width / 2 - (_offset.dx / _zoom) * pixelsPerFrameUnit;
      final centreY =
          rotated.height / 2 - (_offset.dy / _zoom) * pixelsPerFrameUnit;

      final maxSide = math.min(rotated.width, rotated.height);
      final side = cropSide.round().clamp(1, maxSide).toInt();
      final left =
          (centreX - side / 2).round().clamp(0, rotated.width - side).toInt();
      final top =
          (centreY - side / 2).round().clamp(0, rotated.height - side).toInt();

      var cropped = img.copyCrop(
        rotated,
        x: left,
        y: top,
        width: side,
        height: side,
      );

      // Cap the stored size: a 12MP phone photo cropped to a square is still
      // several megabytes, and it is only ever shown at ~88px.
      if (cropped.width > 512) {
        cropped = img.copyResize(cropped, width: 512, height: 512);
      }

      final png = Uint8List.fromList(img.encodePng(cropped));
      if (!mounted) return;
      Navigator.pop(context, png);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = 'Could not crop that image: '
            '${e.toString().replaceAll('Exception: ', '')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final decoded = _decoded;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [AppTheme.surfaceDark, AppTheme.backgroundDark]
              : [ElegantColors.warmWhite, ElegantColors.cream],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 10),
                decoration: BoxDecoration(
                  color: context.colors.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                widget.title,
                style: AppType.sans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: context.colors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Drag to move, pinch or use the slider to zoom',
                style: AppType.sans(
                  fontSize: 13.5,
                  color: context.colors.inkMuted,
                ),
              ),
              const SizedBox(height: 18),
              if (decoded == null)
                _unreadable(isDark)
              else ...[
                _cropFrame(decoded, isDark),
                const SizedBox(height: 18),
                _zoomSlider(decoded, isDark),
                _rotateRow(isDark),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: AppType.sans(
                        fontSize: 12.5,
                        color: AppTheme.accentRose,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                _actions(decoded, isDark),
              ],
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cropFrame(img.Image decoded, bool isDark) {
    final display = _displaySize(decoded.width, decoded.height);

    return SizedBox(
      width: _frame,
      height: _frame,
      child: ClipOval(
        child: GestureDetector(
          onScaleStart: (details) {
            _dragStart = details.focalPoint;
            _offsetStart = _offset;
            _zoomStart = _zoom;
          },
          onScaleUpdate: (details) {
            setState(() {
              _zoom = (_zoomStart * details.scale).clamp(1.0, _maxZoom);
              _offset = _clamp(
                _offsetStart + (details.focalPoint - _dragStart),
                display,
              );
            });
          },
          child: Container(
            color: isDark ? Colors.black : ElegantColors.parchment,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.translate(
                  offset: _offset,
                  child: Transform.scale(
                    scale: _zoom,
                    child: RotatedBox(
                      quarterTurns: _quarterTurns,
                      child: Image.memory(
                        widget.bytes,
                        width: _quarterTurns.isOdd
                            ? display.height
                            : display.width,
                        height: _quarterTurns.isOdd
                            ? display.width
                            : display.height,
                        fit: BoxFit.fill,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                ),
                // The ring that shows exactly what will be kept.
                IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: (isDark
                                ? AppTheme.primaryLight
                                : ElegantColors.terracotta)
                            .withValues(alpha: 0.9),
                        width: 3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _zoomSlider(img.Image decoded, bool isDark) {
    final display = _displaySize(decoded.width, decoded.height);
    final accent = context.colors.accent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        children: [
          Icon(Icons.image_outlined, size: 17, color: accent),
          Expanded(
            child: Slider(
              value: _zoom,
              min: 1,
              max: _maxZoom,
              activeColor: accent,
              onChanged: (value) => setState(() {
                _zoom = value;
                _offset = _clamp(_offset, display);
              }),
            ),
          ),
          Icon(Icons.zoom_in_rounded, size: 20, color: accent),
        ],
      ),
    );
  }

  Widget _rotateRow(bool isDark) {
    return TextButton.icon(
      onPressed: () => setState(() {
        _quarterTurns = (_quarterTurns + 1) % 4;
        _offset = Offset.zero;
        _zoom = 1;
      }),
      icon: const Icon(Icons.rotate_90_degrees_cw_rounded, size: 17),
      label: const Text('Rotate'),
      style: TextButton.styleFrom(
        foregroundColor: context.colors.inkSoft,
        textStyle: AppType.sans(fontSize: 13),
      ),
    );
  }

  Widget _actions(img.Image decoded, bool isDark) {
    final accent = context.colors.accent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed:
                  _working ? null : () => Navigator.pop(context, null),
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    context.colors.inkSoft,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: _working ? null : () => _confirm(decoded),
              icon: _working
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
                _working ? 'Cropping…' : 'Use this photo',
                style: AppType.sans(fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _unreadable(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 12),
      child: Column(
        children: [
          const Icon(Icons.broken_image_outlined,
              size: 44, color: AppTheme.accentRose),
          const SizedBox(height: 12),
          Text(
            'That file could not be read as an image',
            textAlign: TextAlign.center,
            style: AppType.sans(
              fontSize: 13.5,
              color: context.colors.inkSoft,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
