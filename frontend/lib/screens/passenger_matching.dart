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

  // Start tracking accepted ride coordinates
  void _startTrackingRide(String rideId) {
    _socketService.joinRideRoom(rideId);
    
    setState(() {
      _isTracking = true;
      _rideStatus = 'Active';
    });

    // Listen to real-time coordinates
    _locationSub = _socketService.locationStream.listen((data) {
      if (data['lat'] != null && data['lng'] != null) {
        setState(() {
          _currentLat = data['lat'];
          _currentLng = data['lng'];
          _currentSpeed = (data['speed'] as num).toDouble();
        });
      }
    });

    // Listen to ride lifecycle status updates (e.g. Completed)
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
        const SnackBar(content: Text('Join request sent! Waiting for rider approval.')),
      );
      Provider.of<RideProvider>(context, listen: false).fetchActiveRides();
    }
  }

  void _cancelRequest(String rideId) async {
    final success = await Provider.of<RideProvider>(context, listen: false).cancelRideRequest(rideId);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ride request cancelled successfully.')),
      );
      Provider.of<RideProvider>(context, listen: false).fetchActiveRides();
    }
  }

  @override
  Widget build(BuildContext context) {
    final rideProvider = Provider.of<RideProvider>(context);
    final user = Provider.of<AuthProvider>(context).user;

    const primaryColor = Color(0xFF0F5132); // DIU Green

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Commute Matches', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Embankment offline safety warning indicator
          if (!_socketOnline)
            Container(
              color: Colors.red[800],
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: const Row(
                children: [
                  Icon(Icons.wifi_off, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Connection drops along Embankment. Attempting to reconnect...',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          // Real-time passenger tracking overlay
          if (_isTracking)
            Card(
              margin: const EdgeInsets.all(12),
              color: Colors.green[50],
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: primaryColor, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Tracking Live Commute', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryColor)),
                              Text('Ride Status: $_rideStatus', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700], foregroundColor: Colors.white),
                          onPressed: _stopTracking,
                          child: const Text('Stop Map'),
                        )
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('Latitude', style: TextStyle(color: Colors.grey)),
                            Text(_currentLat.toStringAsFixed(5), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        Column(
                          children: [
                            const Text('Longitude', style: TextStyle(color: Colors.grey)),
                            Text(_currentLng.toStringAsFixed(5), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        Column(
                          children: [
                            const Text('Speed', style: TextStyle(color: Colors.grey)),
                            Text('${_currentSpeed.toStringAsFixed(1)} km/h', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () => rideProvider.fetchActiveRides(),
              child: rideProvider.isLoading && rideProvider.activeRides.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : rideProvider.activeRides.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 100),
                            Center(child: Text('No active commutes matching now.', style: TextStyle(color: Colors.grey))),
                            Center(child: Text('Pull down to refresh.', style: TextStyle(color: Colors.grey, fontSize: 12))),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: rideProvider.activeRides.length,
                          itemBuilder: (ctx, i) {
                            final ride = rideProvider.activeRides[i];
                            
                            // Prevent passengers listing their own ride offers
                            if (ride['rider_id'] == user?['id']) {
                              return const SizedBox.shrink();
                            }

                            final timeStr = DateFormat('hh:mm a').format(DateTime.parse(ride['departure_time']));

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(14.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('${ride['origin_name']} ➔ Hub', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                        Text(
                                          '${ride['estimated_fare']} BDT',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryColor),
                                        ),
                                      ],
                                    ),
                                    Text('Destination: ${ride['destination_name']}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.person, size: 16, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text('${ride['rider_name']} (${ride['rider_rating']}★)'),
                                        const Spacer(),
                                        const Icon(Icons.access_time, size: 16, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(timeStr),
                                      ],
                                    ),
                                    const Divider(),
                                    Row(
                                      children: [
                                        Icon(
                                          ride['vehicle_type'] == 'Bike' ? Icons.motorcycle : Icons.directions_car,
                                          size: 18,
                                          color: primaryColor,
                                        ),
                                        const SizedBox(width: 6),
                                        Text('${ride['vehicle_type']} | Seats: ${ride['available_seats']} left'),
                                        if (ride['vehicle_type'] == 'Bike' && ride['helmet_provided']) ...[
                                          const Spacer(),
                                          const Icon(Icons.safety_check, size: 18, color: Colors.blue),
                                          const SizedBox(width: 4),
                                          const Text('Helmet Provided', style: TextStyle(color: Colors.blue, fontSize: 12)),
                                        ]
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    const SizedBox(height: 6),
                                    // Status Badge rendering
                                    if (ride['passenger_request_status'] != null)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 8.0),
                                        child: Row(
                                          children: [
                                            const Text('Request Status: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                            Chip(
                                              label: Text(ride['passenger_request_status']),
                                              backgroundColor: ride['passenger_request_status'] == 'Accepted'
                                                  ? Colors.green[100]
                                                  : ride['passenger_request_status'] == 'Pending'
                                                      ? Colors.orange[100]
                                                      : Colors.red[100],
                                            ),
                                          ],
                                        ),
                                      ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Trigger live tracking room if user is accepted and rider starts
                                        if (ride['status'] == 'Active' && ride['passenger_request_status'] == 'Accepted')
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.amber[800],
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: () => _startTrackingRide(ride['id']),
                                            icon: const Icon(Icons.map),
                                            label: const Text('Track Commute'),
                                          )
                                        else
                                          const SizedBox.shrink(),
                                          
                                        // Dynamic action buttons
                                        if (ride['passenger_request_status'] == null)
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: primaryColor,
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: () => _requestJoin(ride['id']),
                                            child: const Text('Request Join'),
                                          )
                                        else if (ride['passenger_request_status'] == 'Pending' || ride['passenger_request_status'] == 'Accepted')
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red[800],
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: () => _cancelRequest(ride['id']),
                                            child: const Text('Cancel Request'),
                                          )
                                        else
                                          const SizedBox.shrink(), // Rejected requests can't cancel or rejoin
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
}
