import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/ride_provider.dart';
import '../providers/auth_provider.dart';
import '../services/socket_service.dart';
import '../widgets/vector_map.dart'; // Import custom vector map

class PassengerMatching extends StatefulWidget {
  const PassengerMatching({super.key});

  @override
  State<PassengerMatching> createState() => _PassengerMatchingState();
}

class _KeyMetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _KeyMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEAECF0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ]
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F4F7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF475467), size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Color(0xFF667085), fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF101828), fontSize: 14)),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
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
  String _activeVehicleType = 'Bike';
  
  StreamSubscription? _locationSub;
  StreamSubscription? _statusSub;
  StreamSubscription? _connectionSub;

  // Route parameters
  String? _origin;
  String? _destination;
  DateTime _departureTime = DateTime.now().add(const Duration(hours: 1));
  int _passengerCount = 1;
  String _selectedVehicle = 'Bike';

  // Rotation turns count for route swap animation
  double _swapRotation = 0.0;

  @override
  void initState() {
    super.initState();
    _socketService.connect();
    
    _connectionSub = _socketService.connectionStream.listen((isConnected) {
      setState(() {
        _socketOnline = isConnected;
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = Provider.of<RideProvider>(context, listen: false);
      await provider.fetchHubs();
      if (provider.hubs.isNotEmpty) {
        if (mounted) {
          setState(() {
            _origin = provider.hubs[0]['name'];
            if (provider.hubs.length > 1) {
              _destination = provider.hubs[1]['name'];
            }
          });
        }
      }
      provider.fetchActiveRides(origin: _origin, destination: _destination, vehicleType: _selectedVehicle);
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

  // Rotates swap icon 180 degrees and swaps text values of From & To
  void _swapRoutes() {
    setState(() {
      _swapRotation += 0.5; // 180 degrees turn
      final temp = _origin;
      _origin = _destination;
      _destination = temp;
    });
  }

  void _startTrackingRide(String rideId, String vehicleType) {
    _socketService.joinRideRoom(rideId);
    
    setState(() {
      _isTracking = true;
      _activeVehicleType = vehicleType;
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

  void _requestJoin(String rideId, double offeredFare) {
    showDialog(
      context: context,
      builder: (ctx) {
        double bidAmount = offeredFare;
        bool isBidding = false;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Join Commute'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('The rider is asking for:', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text('$offeredFare BDT', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Color(0xFF101828))),
                  const SizedBox(height: 16),

                  if (!isBidding)
                    TextButton.icon(
                      onPressed: () => setStateDialog(() => isBidding = true),
                      icon: const Icon(Icons.local_offer),
                      label: const Text('Make a counter offer (Bid)'),
                    )
                  else
                    TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Your Bid (BDT)',
                        prefixIcon: Icon(Icons.money),
                      ),
                      onChanged: (val) {
                        if (val.isNotEmpty) {
                          bidAmount = double.tryParse(val) ?? offeredFare;
                        } else {
                          bidAmount = offeredFare;
                        }
                      },
                    )
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    final success = await Provider.of<RideProvider>(context, listen: false).requestToJoinRide(rideId, isBidding ? bidAmount : null);
                    if (success && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isBidding ? 'Counter offer sent!' : 'Join request sent!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      Provider.of<RideProvider>(context, listen: false).fetchActiveRides(origin: _origin, destination: _destination, vehicleType: _selectedVehicle);
                    }
                  },
                  child: Text(isBidding ? 'Submit Bid' : 'Accept Fare & Request'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  void _respondToBid(String requestId, double currentBid) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Counter Offer Received'),
          content: Text('The rider has countered with $currentBid BDT. Do you accept?'),
          actions: [
             TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                final success = await Provider.of<RideProvider>(context, listen: false).respondToPassengerRequest(requestId, 'Rejected');
                 if (success && mounted) {
                  Provider.of<RideProvider>(context, listen: false).fetchActiveRides(origin: _origin, destination: _destination, vehicleType: _selectedVehicle);
                }
              },
              child: const Text('Reject', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                final success = await Provider.of<RideProvider>(context, listen: false).respondToPassengerRequest(requestId, 'Accepted');
                if (success && mounted) {
                  Provider.of<RideProvider>(context, listen: false).fetchActiveRides(origin: _origin, destination: _destination, vehicleType: _selectedVehicle);
                }
              },
              child: const Text('Accept Bid'),
            ),
          ]
        );
      }
    );
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

    const primaryColor = Color(0xFF101828);
    const accentColor = Color(0xFF2E90FA);

    // Extract first name for greeting
    final fullName = user?['name'] ?? 'Commuter';
    final firstName = fullName.split(' ')[0];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Connection drops warning banner
            if (!_socketOnline)
              Container(
                color: Colors.red.shade700,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: const Row(
                  children: [
                    Icon(Icons.wifi_off, color: Colors.white, size: 16),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Embankment connection lost. Reconnecting...',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

            // Main Content Area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 120), // Extends scroll past bottom nav
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Reference Profile Header Card
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFEAECF0), width: 2),
                              ),
                              child: const CircleAvatar(
                                radius: 24,
                                backgroundColor: Color(0xFFF2F4F7),
                                child: Icon(Icons.person_outline, color: Color(0xFF475467)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Hello $firstName,', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: primaryColor)),
                                const Text('Where are we heading?', style: TextStyle(color: Color(0xFF667085), fontSize: 14, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ],
                        ),
                        // Top Up Credit badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(color: const Color(0xFFEAECF0)),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))
                            ]
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.account_balance_wallet_outlined, color: primaryColor, size: 18),
                              SizedBox(width: 8),
                              Text('100 BDT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryColor)),
                            ],
                          ),
                        ),
                      ],
                    ).animate().fadeIn().slideY(begin: -0.2),
                    const SizedBox(height: 32),

                    // 2. Mock map search preview (Floating Card)
                    if (_isTracking) ...[
                      // Live GPS Telemetry Dashboard
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
                                  child: const Icon(Icons.my_location, color: accentColor, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('REAL-TIME TRACKING', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 10)),
                                      Text('Rider Status: $_rideStatus', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                                  onPressed: _stopTracking,
                                )
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Render our beautiful vector map CustomPainter here!
                            VectorMap(
                              currentLat: _currentLat,
                              currentLng: _currentLng,
                              isActive: true,
                              vehicleType: _activeVehicleType,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    const Text('SPEED', style: TextStyle(color: Colors.white60, fontSize: 10)),
                                    Text('${_currentSpeed.toStringAsFixed(1)} km/h', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                  ],
                                ),
                                Column(
                                  children: [
                                    const Text('COORDINATES', style: TextStyle(color: Colors.white60, fontSize: 10)),
                                    Text('${_currentLat.toStringAsFixed(4)}, ${_currentLng.toStringAsFixed(4)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                  ],
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // 3. Category Selector Chips
                    const Text('Vehicle Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryColor)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildCategoryTab('Bike', Icons.motorcycle_outlined)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildCategoryTab('Car', Icons.directions_car_filled_outlined)),
                      ],
                    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),
                    const SizedBox(height: 32),

                    // 4. Routing swap card panel
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Stack(
                          alignment: Alignment.centerRight,
                          children: [
                            Column(
                              children: [
                                // Origin Field
                                DropdownButtonFormField<String>(
                                  value: _origin,
                                  decoration: const InputDecoration(
                                    labelText: 'Pickup Location',
                                    prefixIcon: Icon(Icons.trip_origin, color: accentColor, size: 20),
                                    fillColor: Color(0xFFF9FAFB),
                                  ),
                                  items: rideProvider.hubs.map((h) => DropdownMenuItem<String>(value: h['name'], child: Text(h['name'], style: const TextStyle(fontSize: 14)))).toList(),
                                  onChanged: (val) => setState(() => _origin = val),
                                ),
                                const SizedBox(height: 16),
                                
                                // Destination Field
                                DropdownButtonFormField<String>(
                                  value: _destination,
                                  decoration: const InputDecoration(
                                    labelText: 'Drop-off Location',
                                    prefixIcon: Icon(Icons.location_on, color: primaryColor, size: 20),
                                    fillColor: Color(0xFFF9FAFB),
                                  ),
                                  items: rideProvider.hubs.map((h) => DropdownMenuItem<String>(value: h['name'], child: Text(h['name'], style: const TextStyle(fontSize: 14)))).toList(),
                                  onChanged: (val) => setState(() => _destination = val),
                                ),
                              ],
                            ),
                            // Swapping rotation button
                            Positioned(
                              right: 16,
                              top: 48,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFEAECF0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                ),
                                child: AnimatedRotation(
                                  turns: _swapRotation,
                                  duration: const Duration(milliseconds: 300),
                                  child: IconButton(
                                    icon: const Icon(Icons.swap_vert, color: primaryColor, size: 22),
                                    onPressed: _swapRoutes,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
                    const SizedBox(height: 24),

                    // 5. Date picker and Passenger Selector cards
                    Row(
                      children: [
                        _KeyMetricCard(
                          icon: Icons.calendar_month,
                          label: 'Departing',
                          value: DateFormat('MM-dd').format(_departureTime),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _departureTime,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 7)),
                            );
                            if (date != null && mounted) {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.fromDateTime(_departureTime),
                              );
                              if (time != null) {
                                setState(() {
                                  _departureTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                                });
                              }
                            }
                          },
                        ),
                        const SizedBox(width: 12),
                        _KeyMetricCard(
                          icon: Icons.people_outline,
                          label: 'Passengers',
                          value: '$_passengerCount Person',
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Number of passengers'),
                                content: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [1, 2, 3, 4].map((count) => ChoiceChip(
                                    label: Text('$count'),
                                    selected: _passengerCount == count,
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() {
                                          _passengerCount = count;
                                        });
                                        Navigator.of(ctx).pop();
                                      }
                                    },
                                  )).toList(),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Search Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () => rideProvider.fetchActiveRides(origin: _origin, destination: _destination, vehicleType: _selectedVehicle),
                        child: rideProvider.isLoading
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                            : const Text('Find Commute Options', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      ),
                    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),
                    const SizedBox(height: 40),

                    // 6. Matching Results list
                    const Text('Available Matches', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: primaryColor)),
                    const SizedBox(height: 16),

                    if (rideProvider.activeRides.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32.0),
                          child: Column(
                            children: [
                              Icon(Icons.commute, color: Colors.grey.shade400, size: 48),
                              const SizedBox(height: 8),
                              const Text('No rides match your search filters.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                            ],
                          ),
                        ),
                      )
                    else
                      ...rideProvider.activeRides.map((ride) {
                        if (ride['rider_id'] == user?['id']) {
                          return const SizedBox.shrink();
                        }

                        // Apply client side category filter
                        if (ride['vehicle_type'] != _selectedVehicle) {
                          return const SizedBox.shrink();
                        }

                        final timeStr = DateFormat('hh:mm a').format(DateTime.parse(ride['departure_time']));

                        return Card(
                          margin: const EdgeInsets.only(bottom: 20),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(color: const Color(0xFFEFF8FF), borderRadius: BorderRadius.circular(8)),
                                      child: Row(
                                        children: [
                                          Icon(ride['vehicle_type'] == 'Bike' ? Icons.motorcycle : Icons.directions_car, color: accentColor, size: 16),
                                          const SizedBox(width: 6),
                                          Text(ride['vehicle_type'], style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF175CD3), fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(color: const Color(0xFFF2F4F7), borderRadius: BorderRadius.circular(8)),
                                      child: Text('${ride['offered_fare']} BDT', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF344054), fontSize: 14)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEAECF0),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.person, color: Color(0xFF475467)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(ride['rider_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryColor)),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.star_rounded, color: Color(0xFFF79009), size: 16),
                                              Text(' ${ride['rider_rating']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF475467))),
                                              const SizedBox(width: 12),
                                              const Icon(Icons.event_seat, color: Color(0xFF98A2B3), size: 14),
                                              Text(' ${ride['available_seats']} left', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Color(0xFF475467))),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        const Text('Departs at', style: TextStyle(color: Color(0xFF667085), fontSize: 11, fontWeight: FontWeight.w500)),
                                        const SizedBox(height: 2),
                                        Text(timeStr, style: const TextStyle(color: primaryColor, fontSize: 15, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ],
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16.0),
                                  child: Divider(height: 1, color: Color(0xFFEAECF0)),
                                ),
                                Row(
                                  children: [
                                    Column(
                                      children: [
                                        const Icon(Icons.trip_origin, color: accentColor, size: 12),
                                        const SizedBox(height: 4),
                                        Container(width: 2, height: 12, color: const Color(0xFFEAECF0)),
                                        const SizedBox(height: 4),
                                        const Icon(Icons.location_on, color: primaryColor, size: 12),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(ride['origin_name'], style: const TextStyle(fontSize: 14, color: Color(0xFF344054), fontWeight: FontWeight.w500)),
                                          const SizedBox(height: 16),
                                          Text(ride['destination_name'], style: const TextStyle(fontSize: 14, color: Color(0xFF344054), fontWeight: FontWeight.w500)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),

                                // Request State Card banner
                                if (ride['passenger_request_status'] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 16.0),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: ride['passenger_request_status'] == 'Accepted'
                                            ? const Color(0xFFECFDF3)
                                            : ride['passenger_request_status'] == 'Pending'
                                                ? const Color(0xFFFFFAEB)
                                                : const Color(0xFFFEF3F2),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: ride['passenger_request_status'] == 'Accepted'
                                              ? const Color(0xFFD1FADF)
                                              : ride['passenger_request_status'] == 'Pending'
                                                  ? const Color(0xFFFEF0C7)
                                                  : const Color(0xFFFEE4E2),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            ride['passenger_request_status'] == 'Accepted'
                                                ? Icons.check_circle
                                                : ride['passenger_request_status'] == 'Pending'
                                                    ? Icons.access_time_filled
                                                    : Icons.cancel,
                                            color: ride['passenger_request_status'] == 'Accepted'
                                                ? const Color(0xFF12B76A)
                                                : ride['passenger_request_status'] == 'Pending'
                                                    ? const Color(0xFFF79009)
                                                    : const Color(0xFFF04438),
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Request ${ride['passenger_request_status']}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                    color: ride['passenger_request_status'] == 'Accepted'
                                                        ? const Color(0xFF027A48)
                                                        : ride['passenger_request_status'] == 'Pending'
                                                            ? const Color(0xFFB54708)
                                                            : const Color(0xFFB42318),
                                                  ),
                                                ),
                                                if (ride['passenger_request_status'] == 'Pending')
                                                  Text(
                                                    ride['bid_status'] == 'Initial' ? 'Waiting for rider response'
                                                    : ride['bid_status'] == 'Passenger_Counter' ? 'You bid ${ride['proposed_fare']} BDT'
                                                    : 'Rider countered with ${ride['proposed_fare']} BDT',
                                                    style: const TextStyle(fontSize: 12, color: Color(0xFFB54708)),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                // Card actions
                                Row(
                                  children: [
                                    if (ride['status'] == 'Active' && ride['passenger_request_status'] == 'Accepted')
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFF79009),
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                          ),
                                          onPressed: () => _startTrackingRide(ride['id'], ride['vehicle_type']),
                                          icon: const Icon(Icons.near_me),
                                          label: const Text('Track Live Commute'),
                                        ),
                                      ),
                                      
                                    if (ride['passenger_request_status'] == null)
                                      Expanded(
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                          ),
                                          onPressed: () => _requestJoin(ride['id'], double.tryParse(ride['offered_fare'].toString()) ?? 0),
                                          child: const Text('Request to Join'),
                                        ),
                                      )
                                    else if (ride['passenger_request_status'] == 'Pending' || ride['passenger_request_status'] == 'Accepted') ...[
                                      if (ride['bid_status'] == 'Rider_Counter')
                                        Expanded(
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF79009)),
                                            onPressed: () => _respondToBid(ride['passenger_request_id'], double.tryParse(ride['proposed_fare'].toString()) ?? 0),
                                            child: const Text('Respond to Counter Bid'),
                                          ),
                                        )
                                      else
                                        Expanded(
                                          child: OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(0xFFD92D20),
                                              side: const BorderSide(color: Color(0xFFFDA29B)),
                                              padding: const EdgeInsets.symmetric(vertical: 14),
                                            ),
                                            onPressed: () => _cancelRequest(ride['id']),
                                            child: const Text('Cancel Request'),
                                          ),
                                        )
                                    ]
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1);
                      }).toList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTab(String vehicle, IconData icon) {
    final isSelected = _selectedVehicle == vehicle;
    const primaryColor = Color(0xFF101828);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedVehicle = vehicle;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.white,
          border: Border.all(
            color: isSelected ? primaryColor : const Color(0xFFEAECF0),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected ? [
            BoxShadow(
              color: primaryColor.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ] : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : const Color(0xFF667085),
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              vehicle,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF344054),
                fontSize: 15,
              ),
            )
          ],
        ),
      ),
    );
  }
}
