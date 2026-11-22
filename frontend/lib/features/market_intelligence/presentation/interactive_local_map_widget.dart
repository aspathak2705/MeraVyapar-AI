import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/market_event_model.dart';

class InteractiveLocalMapWidget extends StatefulWidget {
  final List<MarketEventModel> businesses;
  final MarketEventModel? selectedBusiness;
  final ValueChanged<MarketEventModel>? onBusinessSelected;
  final double height;

  const InteractiveLocalMapWidget({
    super.key,
    required this.businesses,
    this.selectedBusiness,
    this.onBusinessSelected,
    this.height = 320,
  });

  @override
  State<InteractiveLocalMapWidget> createState() => _InteractiveLocalMapWidgetState();
}

class _InteractiveLocalMapWidgetState extends State<InteractiveLocalMapWidget> {
  late final TransformationController _transformController;
  final Size _canvasSize = const Size(1000, 750);

  @override
  void initState() {
    super.initState();
    _transformController = TransformationController();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _zoom(double factor) {
    final matrix = _transformController.value.clone();
    matrix.scale(factor, factor);
    _transformController.value = matrix;
  }

  void _recenter() {
    _transformController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mappedBusinesses = widget.businesses.where((b) => b.latitude != null && b.longitude != null).toList();
    final unmappedCount = widget.businesses.length - mappedBusinesses.length;

    if (mappedBusinesses.isEmpty) {
      return Container(
        height: widget.height,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey.shade300,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off_outlined,
              size: 48,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            const SizedBox(height: 12),
            Text(
              'No Geographic Coordinates Provided',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Supplier addresses and phone numbers are available in the list view below.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    // Compute bounding box
    double minLat = mappedBusinesses.first.latitude!;
    double maxLat = mappedBusinesses.first.latitude!;
    double minLng = mappedBusinesses.first.longitude!;
    double maxLng = mappedBusinesses.first.longitude!;

    for (final b in mappedBusinesses) {
      if (b.latitude! < minLat) minLat = b.latitude!;
      if (b.latitude! > maxLat) maxLat = b.latitude!;
      if (b.longitude! < minLng) minLng = b.longitude!;
      if (b.longitude! > maxLng) maxLng = b.longitude!;
    }

    double spanLat = maxLat - minLat;
    double spanLng = maxLng - minLng;
    if (spanLat < 0.01) spanLat = 0.02;
    if (spanLng < 0.01) spanLng = 0.02;

    const double padding = 80.0;
    final usableW = _canvasSize.width - 2 * padding;
    final usableH = _canvasSize.height - 2 * padding;

    // Map each business to (Offset, MarketEventModel)
    final pinPositions = <MapEntry<Offset, MarketEventModel>>[];
    for (final b in mappedBusinesses) {
      final x = padding + ((b.longitude! - (minLng - spanLng * 0.1)) / (spanLng * 1.2)) * usableW;
      final y = padding + (((maxLat + spanLat * 0.1) - b.latitude!) / (spanLat * 1.2)) * usableH;
      pinPositions.add(MapEntry(Offset(x.clamp(padding, _canvasSize.width - padding), y.clamp(padding, _canvasSize.height - padding)), b));
    }

    return Container(
      height: widget.height,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222D) : const Color(0xFFE8EEF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Interactive Pan & Zoom Canvas
          InteractiveViewer(
            transformationController: _transformController,
            boundaryMargin: const EdgeInsets.all(200),
            minScale: 0.5,
            maxScale: 3.5,
            child: GestureDetector(
              onTapUp: (details) {
                // Determine which pin was tapped
                final tapPos = details.localPosition;
                MarketEventModel? closest;
                double closestDist = 45.0; // hit radius
                for (final entry in pinPositions) {
                  final dist = (entry.key - tapPos).distance;
                  if (dist < closestDist) {
                    closestDist = dist;
                    closest = entry.value;
                  }
                }
                if (closest != null) {
                  widget.onBusinessSelected?.call(closest);
                }
              },
              child: CustomPaint(
                size: _canvasSize,
                painter: _MapCanvasPainter(
                  pinPositions: pinPositions,
                  selectedBusinessId: widget.selectedBusiness?.id,
                  isDark: isDark,
                ),
              ),
            ),
          ),

          // Top Info Status Pill
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: (isDark ? Colors.black87 : Colors.white).withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.pin_drop, size: 14, color: AppColors.primaryPurple),
                  const SizedBox(width: 4),
                  Text(
                    '${mappedBusinesses.length} on map${unmappedCount > 0 ? " ($unmappedCount unmapped)" : ""}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Zoom & Recenter Controls Overlay
          Positioned(
            right: 12,
            bottom: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMapButton(
                  icon: Icons.add,
                  onPressed: () => _zoom(1.25),
                  isDark: isDark,
                  tooltip: 'Zoom In',
                ),
                const SizedBox(height: 6),
                _buildMapButton(
                  icon: Icons.remove,
                  onPressed: () => _zoom(0.8),
                  isDark: isDark,
                  tooltip: 'Zoom Out',
                ),
                const SizedBox(height: 6),
                _buildMapButton(
                  icon: Icons.my_location,
                  onPressed: _recenter,
                  isDark: isDark,
                  tooltip: 'Recenter Map',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapButton({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isDark,
    required String tooltip,
  }) {
    return Material(
      color: (isDark ? const Color(0xFF2B303C) : Colors.white).withOpacity(0.92),
      borderRadius: BorderRadius.circular(8),
      elevation: 2,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(
              icon,
              size: 18,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _MapCanvasPainter extends CustomPainter {
  final List<MapEntry<Offset, MarketEventModel>> pinPositions;
  final String? selectedBusinessId;
  final bool isDark;

  _MapCanvasPainter({
    required this.pinPositions,
    required this.selectedBusinessId,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw stylized background grid & roads
    final gridPaint = Paint()
      ..color = isDark ? const Color(0xFF272D3B) : const Color(0xFFDDE3EC)
      ..strokeWidth = 1.0;

    const double step = 60.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Arterial road lines for cartographic texture
    final roadPaint = Paint()
      ..color = isDark ? const Color(0xFF333A4D) : const Color(0xFFCED6E2)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final path1 = Path()
      ..moveTo(0, size.height * 0.35)
      ..quadraticBezierTo(size.width * 0.45, size.height * 0.4, size.width, size.height * 0.25);
    canvas.drawPath(path1, roadPaint);

    final path2 = Path()
      ..moveTo(size.width * 0.2, 0)
      ..quadraticBezierTo(size.width * 0.35, size.height * 0.55, size.width * 0.8, size.height);
    canvas.drawPath(path2, roadPaint);

    // Compass Rose in top-right
    _drawCompass(canvas, Offset(size.width - 50, 50));

    // 2. Draw Pins (Draw unselected first, selected last on top)
    MapEntry<Offset, MarketEventModel>? selectedEntry;

    for (final entry in pinPositions) {
      if (entry.value.id == selectedBusinessId) {
        selectedEntry = entry;
      } else {
        _drawPin(canvas, entry.key, entry.value, isSelected: false);
      }
    }

    if (selectedEntry != null) {
      _drawPin(canvas, selectedEntry.key, selectedEntry.value, isSelected: true);
      _drawCallout(canvas, selectedEntry.key, selectedEntry.value);
    }
  }

  void _drawCompass(Canvas canvas, Offset center) {
    final paint = Paint()
      ..color = isDark ? Colors.white24 : Colors.black12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, 18, paint);

    final nPaint = Paint()
      ..color = isDark ? Colors.redAccent.shade100 : Colors.red.shade700
      ..style = PaintingStyle.fill;
    final nPath = Path()
      ..moveTo(center.dx, center.dy - 16)
      ..lineTo(center.dx - 4, center.dy)
      ..lineTo(center.dx + 4, center.dy)
      ..close();
    canvas.drawPath(nPath, nPaint);
  }

  void _drawPin(Canvas canvas, Offset pos, MarketEventModel business, {required bool isSelected}) {
    if (isSelected) {
      // Pulsing outer halo
      final haloPaint = Paint()
        ..color = AppColors.primaryPurple.withOpacity(0.25)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, 24, haloPaint);

      final outerRingPaint = Paint()
        ..color = AppColors.primaryPurple.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(pos, 18, outerRingPaint);
    }

    // Pin shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(pos.translate(0, 2), isSelected ? 12 : 9, shadowPaint);

    // Pin head circle
    final pinPaint = Paint()
      ..color = isSelected ? const Color(0xFF6C47FF) : (isDark ? const Color(0xFF4A5568) : const Color(0xFF5A677D))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos, isSelected ? 11 : 8, pinPaint);

    // Pin inner dot
    final innerPaint = Paint()
      ..color = isSelected ? Colors.white : Colors.white70
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos, isSelected ? 4.5 : 3.0, innerPaint);
  }

  void _drawCallout(Canvas canvas, Offset pos, MarketEventModel business) {
    final title = business.title.length > 20 ? '${business.title.substring(0, 18)}...' : business.title;
    final ratingText = business.rating != null ? '★ ${business.rating!.toStringAsFixed(1)}' : '';
    final displayText = ratingText.isNotEmpty ? '$title ($ratingText)' : title;

    final textSpan = TextSpan(
      text: displayText,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 220);

    const padH = 10.0;
    const padV = 6.0;
    final bubbleW = textPainter.width + padH * 2;
    final bubbleH = textPainter.height + padV * 2;
    final bubbleTop = pos.dy - 20 - bubbleH;
    final bubbleLeft = pos.dx - bubbleW / 2;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(bubbleLeft, bubbleTop, bubbleW, bubbleH),
      const Radius.circular(8),
    );

    // Bubble shadow
    canvas.drawRRect(
      rrect.shift(const Offset(0, 3)),
      Paint()
        ..color = Colors.black38
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Bubble body
    final bubblePaint = Paint()
      ..color = const Color(0xFF1E1B2E)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, bubblePaint);

    // Pointer down triangle
    final pointerPath = Path()
      ..moveTo(pos.dx - 6, bubbleTop + bubbleH)
      ..lineTo(pos.dx + 6, bubbleTop + bubbleH)
      ..lineTo(pos.dx, bubbleTop + bubbleH + 6)
      ..close();
    canvas.drawPath(pointerPath, bubblePaint);

    // Render Text
    textPainter.paint(canvas, Offset(bubbleLeft + padH, bubbleTop + padV));
  }

  @override
  bool shouldRepaint(covariant _MapCanvasPainter oldDelegate) {
    return oldDelegate.selectedBusinessId != selectedBusinessId ||
        oldDelegate.pinPositions != pinPositions ||
        oldDelegate.isDark != isDark;
  }
}
