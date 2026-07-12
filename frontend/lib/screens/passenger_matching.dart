import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/ride_provider.dart';
import '../providers/auth_provider.dart';
import '../services/socket_service.dart';

class PassengerMatching extends StatefulWidget {
  const PassengerMatching({super.key});

  @override
  State<PassengerMatching> createState() => _PassengerMatchingState();
}

class _PassengerMatchingState extends State<PassengerMatching> {
  final SocketService _socketService = SocketService();
  bool _isTracking = false;
  
  // Real-time tracking data
  double _currentLat = 0.0;
  double _currentLng = 0.0;
  double _currentSpeed = 0.0;
  String _rideStatus = 'Active';
  bool _socketOnline = true;
  
  StreamSubscription? _locationSub;
  StreamSubscription? _statusSub;
  StreamSubscription? _connectionSub;

  @override
  void initState() {
    super.initState();
    _socketService.connect();
    
    // Listen to socket connection state for embankment drops
    _connectionSub = _socketService.connectionStream.listen((isConnected) {
      setState(() {
        _socketOnline = isConnected;
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RideProvider>(context, listen: false).fetchActiveRides();
    });
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _statusSub?.cancel();
    _connectionSub?.cancel();
    _socketService.dispose();
    super.dispose();
  }

  void _startTrackingRide(String rideId) {
    _socketService.joinRideRoom(rideId);
    
    setState(() {
      _isTracking = true;
      _rideStatus = 'Active';
    });

    _locationSub = _socketService.locationStream.listen((data) {
      if (data['lat'] != null && data['lng'] != null) {
        setState(() {
          _currentLat = data['lat'];
          _currentLng = data['lng'];
          _currentSpeed = (data['speed'] as num).toDouble();
        });
      }
    });

    _statusSub = _socketService.statusStream.listen((data) {
      if (data['status'] != null) {
        setState(() {
          _rideStatus = data['status'];
        });
        if (data['status'] == 'Completed' || data['status'] == 'Cancelled') {
          _stopTracking();
        }
      }
    });
  }

  void _stopTracking() {
    _locationSub?.cancel();
    _statusSub?.cancel();
    setState(() {
      _isTracking = false;
    });
    Provider.of<RideProvider>(context, listen: false).fetchActiveRides();
  }

  void _requestJoin(String rideId) async {
    final success = await Provider.of<RideProvider>(context, listen: false).requestToJoinRide(rideId);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Join request sent! Waiting for rider approval.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Provider.of<RideProvider>(context, listen: false).fetchActiveRides();
    }
  }

  void _cancelRequest(String rideId) async {
    final success = await Provider.of<RideProvider>(context, listen: false).cancelRideRequest(rideId);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride request cancelled successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Provider.of<RideProvider>(context, listen: false).fetchActiveRides();
    }
  }

  @override
  Widget build(BuildContext context) {
    final rideProvider = Provider.of<RideProvider>(context);
    final user = Provider.of<AuthProvider>(context).user;

    const primaryColor = Color(0xFF0F5132); // DIU Green
    const accentColor = Color(0xFF00B4D8);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Find Commutes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Embankment offline warning indicator
          if (!_socketOnline)
            Container(
              color: Colors.red.shade700,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: const Row(
                children: [
                  Icon(Icons.wifi_off, color: Colors.white, size: 18),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Embankment signal weak. Automatically reconnecting...',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          // Live Telemetry GPS Tracking Console
          if (_isTracking)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B), // Dark Slate
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.gps_fixed, color: Colors.green, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('LIVE COMMUTE MAP SYNC', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5)),
                            Text('Driver Status: $_rideStatus', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.08),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onPressed: _stopTracking,
                        child: const Text('Close Console', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      )
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildTrackerMetric('LATITUDE', _currentLat.toStringAsFixed(5)),
                      _buildTrackerMetric('LONGITUDE', _currentLng.toStringAsFixed(5)),
                      _buildTrackerMetric('SPEED', '${_currentSpeed.toStringAsFixed(1)} km/h'),
                    ],
                  )
                ],
              ),
            ),

          // Matches List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => rideProvider.fetchActiveRides(),
              child: rideProvider.isLoading && rideProvider.activeRides.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : rideProvider.activeRides.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Center(child: Icon(Icons.commute_outlined, size: 64, color: Colors.grey)),
                            SizedBox(height: 16),
                            Center(child: Text('No active commutes matching currently.', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold))),
                            Center(child: Text('Pull down to search again.', style: TextStyle(color: Colors.grey, fontSize: 12))),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: rideProvider.activeRides.length,
                          itemBuilder: (ctx, i) {
                            final ride = rideProvider.activeRides[i];
                            
                            if (ride['rider_id'] == user?['id']) {
                              return const SizedBox.shrink();
                            }

                            final timeStr = DateFormat('hh:mm a').format(DateTime.parse(ride['departure_time']));

                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Route & Fare Header
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Visual Route Indicators
                                        Expanded(
                                          child: Row(
                                            children: [
                                              const Icon(Icons.adjust, color: accentColor, size: 18),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  '${ride['origin_name']} ➔ ${ride['destination_name']}',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: primaryColor.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(100),
                                          ),
                                          child: Text(
                                            '${ride['estimated_fare']} BDT',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryColor),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    
                                    // Rider profile & departure time
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: primaryColor.withOpacity(0.06),
                                          radius: 14,
                                          child: const Icon(Icons.person_outline, size: 14, color: primaryColor),
                                        ),
                                        const SizedBox(width: 8),
                                        Text('${ride['rider_name']} ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(6)),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.star, color: Colors.amber, size: 12),
                                              Text(' ${ride['rider_rating']}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                        const Spacer(),
                                        const Icon(Icons.access_time, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(timeStr, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                    const Divider(height: 24),

                                    // Vehicle information
                                    Row(
                                      children: [
                                        Icon(
                                          ride['vehicle_type'] == 'Bike' ? Icons.motorcycle : Icons.directions_car,
                                          size: 18,
                                          color: primaryColor,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${ride['vehicle_type']} | Seats: ${ride['available_seats']} left',
                                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                        ),
                                        if (ride['vehicle_type'] == 'Bike' && ride['helmet_provided']) ...[
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(6)),
                                            child: const Row(
                                              children: [
                                                Icon(Icons.safety_check_outlined, size: 14, color: primaryColor),
                                                SizedBox(width: 4),
                                                Text('Helmet Provided', style: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                        ]
                                      ],
                                    ),
                                    const SizedBox(height: 16),

                                    // Request Status Banner
                                    if (ride['passenger_request_status'] != null)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 12.0),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: ride['passenger_request_status'] == 'Accepted'
                                                ? Colors.green.shade50.withOpacity(0.4)
                                                : ride['passenger_request_status'] == 'Pending'
                                                    ? Colors.orange.shade50.withOpacity(0.4)
                                                    : Colors.red.shade50.withOpacity(0.4),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: ride['passenger_request_status'] == 'Accepted'
                                                  ? Colors.green.shade100
                                                  : ride['passenger_request_status'] == 'Pending'
                                                      ? Colors.orange.shade100
                                                      : Colors.red.shade100,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                ride['passenger_request_status'] == 'Accepted'
                                                    ? Icons.check_circle_outline
                                                    : ride['passenger_request_status'] == 'Pending'
                                                        ? Icons.hourglass_empty
                                                        : Icons.cancel_outlined,
                                                color: ride['passenger_request_status'] == 'Accepted'
                                                    ? Colors.green.shade700
                                                    : ride['passenger_request_status'] == 'Pending'
                                                        ? Colors.orange.shade700
                                                        : Colors.red.shade700,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Request Status: ${ride['passenger_request_status']}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                  color: ride['passenger_request_status'] == 'Accepted'
                                                      ? Colors.green.shade800
                                                      : ride['passenger_request_status'] == 'Pending'
                                                          ? Colors.orange.shade800
                                                          : Colors.red.shade800,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                    // Card actions buttons
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Track Commute
                                        if (ride['status'] == 'Active' && ride['passenger_request_status'] == 'Accepted')
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.amber.shade800,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                            onPressed: () => _startTrackingRide(ride['id']),
                                            icon: const Icon(Icons.navigation, size: 18),
                                            label: const Text('Track Live', style: TextStyle(fontWeight: FontWeight.bold)),
                                          )
                                        else
                                          const SizedBox.shrink(),
                                          
                                        // Request Join / Cancel Request
                                        if (ride['passenger_request_status'] == null)
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: primaryColor,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                            onPressed: () => _requestJoin(ride['id']),
                                            child: const Text('Request Join', style: TextStyle(fontWeight: FontWeight.bold)),
                                          )
                                        else if (ride['passenger_request_status'] == 'Pending' || ride['passenger_request_status'] == 'Accepted')
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red.shade50,
                                              foregroundColor: Colors.red.shade700,
                                              side: BorderSide(color: Colors.red.shade100, width: 1),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                            onPressed: () => _cancelRequest(ride['id']),
                                            child: const Text('Cancel Request', style: TextStyle(fontWeight: FontWeight.bold)),
                                          )
                                        else
                                          const SizedBox.shrink(),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackerMetric(String label, String val) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}
