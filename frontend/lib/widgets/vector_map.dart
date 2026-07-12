import 'package:flutter/material.dart';

class VectorMap extends StatefulWidget {
  final double currentLat;
  final double currentLng;
  final bool isActive;
  final String vehicleType;

  const VectorMap({
    super.key,
    required this.currentLat,
    required this.currentLng,
    this.isActive = false,
    this.vehicleType = 'Bike',
  });

  @override
  State<VectorMap> createState() => _VectorMapState();
}

class _VectorMapState extends State<VectorMap> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Extents for coordinates mapping (covers Ashulia / DIU area)
  // Lat: 23.8000 to 23.8900
  // Lng: 90.2500 to 90.4100
  final double minLat = 23.8000;
  final double maxLat = 23.8900;
  final double minLng = 90.2500;
  final double maxLng = 90.4100;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 4.0, end: 12.0).animate(_pulseController);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 240,
        width: double.infinity,
        decoration: BoxDecoration(
          color: widget.isActive ? const Color(0xFF1D2939) : const Color(0xFFF9FAFB),
          border: Border.all(color: widget.isActive ? const Color(0xFF344054) : const Color(0xFFEAECF0), width: 1),
        ),
        child: Stack(
          children: [
            // Ambient map gradient for premium depth
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.isActive
                      ? [const Color(0xFF101828).withOpacity(0.8), Colors.transparent]
                      : [Colors.white.withOpacity(0.5), Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(double.infinity, 240),
                  painter: MapPainter(
                    currentLat: widget.currentLat,
                    currentLng: widget.currentLng,
                    minLat: minLat,
                    maxLat: maxLat,
                    minLng: minLng,
                    maxLng: maxLng,
                    pulseRadius: _pulseAnimation.value,
                    isActive: widget.isActive,
                    vehicleType: widget.vehicleType,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class MapPainter extends CustomPainter {
  final double currentLat;
  final double currentLng;
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;
  final double pulseRadius;
  final bool isActive;
  final String vehicleType;

  MapPainter({
    required this.currentLat,
    required this.currentLng,
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
    required this.pulseRadius,
    required this.isActive,
    required this.vehicleType,
  });

  // Helper to translate GPS coordinates to Local Canvas X/Y values
  Offset _toCanvasOffset(double lat, double lng, Size size) {
    // Lng maps to X axis (horizontal)
    final double x = ((lng - minLng) / (maxLng - minLng)) * size.width;
    // Lat maps to Y axis (vertical, inverted in canvas coords)
    final double y = size.height - (((lat - minLat) / (maxLat - minLat)) * size.height);
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final themeRoadColor = isActive ? const Color(0xFF344054) : Colors.white;
    final themeRoadBorderColor = isActive ? const Color(0xFF101828) : const Color(0xFFEAECF0);
    final themeGridColor = isActive ? const Color(0xFF344054).withOpacity(0.3) : const Color(0xFFEAECF0);
    final themeLakeColor = isActive ? const Color(0xFF0B4A6F).withOpacity(0.5) : const Color(0xFFE0F2FE);
    final themeAccent = const Color(0xFF2E90FA);
    final themeLandmarkBg = isActive ? const Color(0xFF027A48).withOpacity(0.2) : const Color(0xFFD1FADF);
    final themeLandmarkBorder = const Color(0xFF027A48);

    // 1. Draw Grid lines (Background map mesh)
    final gridPaint = Paint()
      ..color = themeGridColor
      ..strokeWidth = 1.0;
    
    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double j = 0; j < size.height; j += 40) {
      canvas.drawLine(Offset(0, j), Offset(size.width, j), gridPaint);
    }

    // 2. Draw Scenic DIU Lake Area (Modern smooth blob)
    final lakePaint = Paint()
      ..color = themeLakeColor
      ..style = PaintingStyle.fill;

    final pathLake = Path()
      ..moveTo(size.width * 0.2, size.height * 0.6)
      ..quadraticBezierTo(size.width * 0.4, size.height * 0.4, size.width * 0.6, size.height * 0.6)
      ..quadraticBezierTo(size.width * 0.7, size.height * 0.8, size.width * 0.4, size.height * 0.8)
      ..quadraticBezierTo(size.width * 0.1, size.height * 0.8, size.width * 0.2, size.height * 0.6)
      ..close();
    canvas.drawPath(pathLake, lakePaint);

    // 3. Draw Roads (Slick clean lines)
    final roadPaint = Paint()
      ..color = themeRoadColor
      ..strokeWidth = 8
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final roadBorderPaint = Paint()
      ..color = themeRoadBorderColor
      ..strokeWidth = 12
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Define main route paths (smoother curves)
    final mainRoutePath = Path()
      ..moveTo(0, size.height * 0.8)
      ..quadraticBezierTo(size.width * 0.2, size.height * 0.7, size.width * 0.3, size.height * 0.6)
      ..quadraticBezierTo(size.width * 0.5, size.height * 0.4, size.width * 0.7, size.height * 0.4)
      ..lineTo(size.width, size.height * 0.2);

    final campusRoutePath = Path()
      ..moveTo(size.width * 0.7, size.height * 0.4)
      ..quadraticBezierTo(size.width * 0.7, size.height * 0.8, size.width * 0.4, size.height * 0.9);

    final mirpurRoutePath = Path()
      ..moveTo(size.width * 0.3, size.height * 0.6)
      ..lineTo(size.width * 0.3, size.height * 0.1);

    // Draw borders, then clean roads for a premium layered look
    canvas.drawPath(mainRoutePath, roadBorderPaint);
    canvas.drawPath(campusRoutePath, roadBorderPaint);
    canvas.drawPath(mirpurRoutePath, roadBorderPaint);

    canvas.drawPath(mainRoutePath, roadPaint);
    canvas.drawPath(campusRoutePath, roadPaint);
    canvas.drawPath(mirpurRoutePath, roadPaint);

    // 4. Draw DIU Smart City Campus Landmark
    final campusOffset = _toCanvasOffset(23.8767, 90.3201, size); // DIU Hub coords
    canvas.drawCircle(campusOffset, 20, Paint()..color = themeLandmarkBg);
    
    final campusBorder = Paint()
      ..color = themeLandmarkBorder
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(campusOffset, 20, campusBorder);
    canvas.drawCircle(campusOffset, 6, Paint()..color = themeLandmarkBorder);

    // 5. Draw User / Active Commuter pulsating GPS location marker
    if (currentLat != 0.0 && currentLng != 0.0) {
      final driverOffset = _toCanvasOffset(currentLat, currentLng, size);
      
      // Draw pulsating halo indicator
      final haloPaint = Paint()
        ..color = themeAccent.withOpacity(0.3)
        ..style = PaintingStyle.fill;

      // Double pulse effect for premium feel
      canvas.drawCircle(driverOffset, pulseRadius + 12, haloPaint..color = themeAccent.withOpacity(0.15));
      canvas.drawCircle(driverOffset, pulseRadius + 4, haloPaint..color = themeAccent.withOpacity(0.3));

      // Draw primary colored pin point with shadow
      canvas.drawCircle(
        Offset(driverOffset.dx, driverOffset.dy + 4),
        8,
        Paint()..color = Colors.black.withOpacity(0.2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
      );

      final pinPaint = Paint()
        ..color = themeAccent
        ..style = PaintingStyle.fill;
      canvas.drawCircle(driverOffset, 8, pinPaint);

      // White inner ring
      canvas.drawCircle(
        driverOffset, 
        3, 
        Paint()..color = Colors.white..style = PaintingStyle.fill
      );

      // Render a modern mini tag above the pin
      final textPainter = TextPainter(
        text: TextSpan(
          text: vehicleType == 'Bike' ? '🏍️' : '🚙',
          style: const TextStyle(fontSize: 16),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      
      // White bubble background for emoji
      final bubbleRect = Rect.fromCenter(
        center: Offset(driverOffset.dx, driverOffset.dy - 28),
        width: 32,
        height: 32,
      );

      // Shadow for bubble
      canvas.drawRRect(
        RRect.fromRectAndRadius(bubbleRect, const Radius.circular(16)),
        Paint()..color = Colors.black.withOpacity(0.12)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
      );

      // Actual white bubble
      canvas.drawRRect(
        RRect.fromRectAndRadius(bubbleRect, const Radius.circular(16)),
        Paint()..color = Colors.white
      );

      textPainter.paint(
        canvas, 
        Offset(driverOffset.dx - textPainter.width / 2, driverOffset.dy - 38)
      );
    }
  }

  @override
  bool shouldRepaint(covariant MapPainter oldDelegate) {
    return oldDelegate.currentLat != currentLat ||
        oldDelegate.currentLng != currentLng ||
        oldDelegate.pulseRadius != pulseRadius ||
        oldDelegate.isActive != isActive ||
        oldDelegate.vehicleType != vehicleType;
  }
}
