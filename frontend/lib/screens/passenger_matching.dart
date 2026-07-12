import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF0F5132), size: 20),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 13)),
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

  // Hubs mapping
  final Map<String, List<double>> _hubs = {
    'Mirpur 10 Hub': [23.8069, 90.3687],
    'Uttara House Building Hub': [23.8729, 90.4007],
    'Dhanmondi 27 Hub': [23.7538, 90.3768],
    'Savar Bus Stand Hub': [23.8442, 90.2581],
    'DIU Smart City (Ashulia)': [23.8767, 90.3201],
  };

  // Route parameters
  String _origin = 'Mirpur 10 Hub';
  String _destination = 'DIU Smart City (Ashulia)';
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
    const accentColor = Color(0xFF00B4D8); // Sky Teal

    // Extract first name for greeting
    final fullName = user?['name'] ?? 'Commuter';
    final firstName = fullName.split(' ')[0];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), // Extends scroll past bottom nav
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Reference Profile Header Card
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: primaryColor.withOpacity(0.08),
                              child: const Icon(Icons.person, color: primaryColor),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Hello $firstName,', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))),
                                const Text('Where to go?', style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ],
                        ),
                        // Top Up Credit badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.wallet, color: primaryColor, size: 16),
                              SizedBox(width: 6),
                              Text('100.00 BDT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

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

                    // 3. Category Selector Chips (Reference matching horizontal scrolling selector)
                    const Text('Vehicle Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B))),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _buildCategoryTab('Bike', Icons.motorcycle_outlined)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildCategoryTab('Car', Icons.directions_car_filled_outlined)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 4. Routing swap card panel (From / To inputs)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Stack(
                          alignment: Alignment.centerRight,
                          children: [
                            Column(
                              children: [
                                // Origin Field
                                DropdownButtonFormField<String>(
                                  value: _origin,
                                  decoration: const InputDecoration(
                                    labelText: 'From Hub',
                                    prefixIcon: Icon(Icons.circle_outlined, color: accentColor, size: 16),
                                  ),
                                  items: _hubs.keys.map((h) => DropdownMenuItem(value: h, child: Text(h, style: const TextStyle(fontSize: 13)))).toList(),
                                  onChanged: (val) => setState(() => _origin = val!),
                                ),
                                const SizedBox(height: 16),
                                
                                // Destination Field
                                DropdownButtonFormField<String>(
                                  value: _destination,
                                  decoration: const InputDecoration(
                                    labelText: 'To Hub',
                                    prefixIcon: Icon(Icons.location_on, color: primaryColor, size: 18),
                                  ),
                                  items: _hubs.keys.map((h) => DropdownMenuItem(value: h, child: Text(h, style: const TextStyle(fontSize: 13)))).toList(),
                                  onChanged: (val) => setState(() => _destination = val!),
                                ),
                              ],
                            ),
                            // Swapping rotation button
                            Positioned(
                              right: 12,
                              top: 40,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.grey.shade200),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 4,
                                    )
                                  ]
                                ),
                                child: AnimatedRotation(
                                  turns: _swapRotation,
                                  duration: const Duration(milliseconds: 300),
                                  child: IconButton(
                                    icon: const Icon(Icons.swap_vert, color: primaryColor, size: 20),
                                    onPressed: _swapRoutes,
                                  ),
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

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
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E293B), // Dark Slate
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => rideProvider.fetchActiveRides(),
                        child: rideProvider.isLoading
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Search Match Commutes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // 6. Matching Results list
                    const Text('Available Matches', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))),
                    const SizedBox(height: 12),

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
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          const Icon(Icons.circle, color: accentColor, size: 10),
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
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(color: primaryColor.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                                      child: Text('${ride['estimated_fare']} BDT', style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 13)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundColor: primaryColor.withOpacity(0.06),
                                      child: const Icon(Icons.person, size: 12, color: primaryColor),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(ride['rider_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    const SizedBox(width: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.star, color: Colors.amber, size: 14),
                                        Text(' ${ride['rider_rating']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                      ],
                                    ),
                                    const Spacer(),
                                    Text(timeStr, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                                const Divider(height: 24),
                                Row(
                                  children: [
                                    Icon(ride['vehicle_type'] == 'Bike' ? Icons.motorcycle : Icons.directions_car, color: primaryColor, size: 18),
                                    const SizedBox(width: 6),
                                    Text('Available seats: ${ride['available_seats']}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Request State Card banner
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
                                            'Status: ${ride['passenger_request_status']}',
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

                                // Card actions
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    if (ride['status'] == 'Active' && ride['passenger_request_status'] == 'Accepted')
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.amber.shade800,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () => _startTrackingRide(ride['id'], ride['vehicle_type']),
                                        icon: const Icon(Icons.navigation, size: 18),
                                        label: const Text('Track Live', style: TextStyle(fontWeight: FontWeight.bold)),
                                      )
                                    else
                                      const SizedBox.shrink(),
                                      
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
    const primaryColor = Color(0xFF0F5132);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedVehicle = vehicle;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.white,
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey.shade600,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              vehicle,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontSize: 13,
              ),
            )
          ],
        ),
      ),
    );
  }
}
