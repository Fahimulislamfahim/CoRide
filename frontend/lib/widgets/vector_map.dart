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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 240,
        width: double.infinity,
        color: const Color(0xFFE2E8F0), // Light slate backdrop
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return CustomPaint(
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
    // 1. Draw Grid lines (Background map mesh)
    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 0.5;
    
    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double j = 0; j < size.height; j += 40) {
      canvas.drawLine(Offset(0, j), Offset(size.width, j), gridPaint);
    }

    // 2. Draw Scenic DIU Lake Area (Curved Blue Paths)
    final lakePaint = Paint()
      ..color = const Color(0xFFBBE5ED)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.4, size.height * 0.7),
        width: 140,
        height: 60,
      ),
      lakePaint,
    );

    // 3. Draw Roads (Birulia-Ashulia Embankment & campus roads)
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final roadBorderPaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Define main route paths
    final List<List<Offset>> routes = [
      // Birulia Embankment Road
      [
        Offset(0, size.height * 0.8),
        Offset(size.width * 0.3, size.height * 0.6),
        Offset(size.width * 0.7, size.height * 0.4),
        Offset(size.width, size.height * 0.2),
      ],
      // DIU Campus Path
      [
        Offset(size.width * 0.7, size.height * 0.4),
        Offset(size.width * 0.7, size.height * 0.9),
        Offset(size.width * 0.4, size.height * 0.9),
      ],
      // Mirpur connector
      [
        Offset(size.width * 0.3, size.height * 0.6),
        Offset(size.width * 0.3, size.height * 0.1),
      ]
    ];

    // Draw borders, then clean white roads
    for (var r in routes) {
      final path = Path()..moveTo(r[0].dx, r[0].dy);
      for (int i = 1; i < r.length; i++) {
        path.lineTo(r[i].dx, r[i].dy);
      }
      canvas.drawPath(path, roadBorderPaint);
      canvas.drawPath(path, roadPaint);
    }

    // 4. Draw DIU Smart City Campus Landmark
    final campusPaint = Paint()..color = const Color(0xFF0F5132).withOpacity(0.12);
    final campusOffset = _toCanvasOffset(23.8767, 90.3201, size); // DIU Hub coords
    canvas.drawCircle(campusOffset, 24, campusPaint);
    
    final campusBorder = Paint()
      ..color = const Color(0xFF0F5132)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(campusOffset, 24, campusBorder);
    
    // Draw tiny green flag or circle inside DIU Hub
    canvas.drawCircle(campusOffset, 6, Paint()..color = const Color(0xFF0F5132));

    // 5. Draw active mock vehicle markers (Visual background decoration)
    final mockMarkerPaint = Paint()..color = const Color(0xFF1E293B);
    final List<Offset> mockVehicles = [
      _toCanvasOffset(23.8300, 90.3500, size),
      _toCanvasOffset(23.8600, 90.2800, size),
      _toCanvasOffset(23.8500, 90.3800, size),
    ];
    for (var mv in mockVehicles) {
      canvas.drawCircle(mv, 4, mockMarkerPaint);
    }

    // 6. Draw User / Active Commuter pulsating GPS location marker
    if (currentLat != 0.0 && currentLng != 0.0) {
      final driverOffset = _toCanvasOffset(currentLat, currentLng, size);
      
      // Draw pulsating halo indicator (reconnect dropout assistance)
      final haloPaint = Paint()
        ..color = const Color(0xFF00B4D8).withOpacity(0.25)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(driverOffset, pulseRadius + 6, haloPaint);

      // Draw primary colored pin point
      final pinPaint = Paint()
        ..color = const Color(0xFF00B4D8)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(driverOffset, 6, pinPaint);

      // White inner ring
      canvas.drawCircle(
        driverOffset, 
        3, 
        Paint()..color = Colors.white..style = PaintingStyle.fill
      );

      // Render a mini card above the pin displaying the category
      final textPainter = TextPainter(
        text: TextSpan(
          text: vehicleType == 'Bike' ? '🏍️' : '🚗',
          style: const TextStyle(fontSize: 14),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      
      textPainter.paint(
        canvas, 
        Offset(driverOffset.dx - textPainter.width / 2, driverOffset.dy - 24)
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
