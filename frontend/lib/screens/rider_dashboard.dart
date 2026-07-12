import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/ride_provider.dart';
import '../providers/auth_provider.dart';
import '../services/socket_service.dart';
import '../widgets/vector_map.dart'; // Import custom vector map

class RiderDashboard extends StatefulWidget {
  const RiderDashboard({super.key});

  @override
  State<RiderDashboard> createState() => _RiderDashboardState();
}

class _RiderDashboardState extends State<RiderDashboard> {
  final _formKey = GlobalKey<FormState>();
  final SocketService _socketService = SocketService();
  
  // Coordinates mapping for major DIU commuter hubs
  final Map<String, List<double>> _hubs = {
    'Mirpur 10 Hub': [23.8069, 90.3687],
    'Uttara House Building Hub': [23.8729, 90.4007],
    'Dhanmondi 27 Hub': [23.7538, 90.3768],
    'Savar Bus Stand Hub': [23.8442, 90.2581],
    'DIU Smart City (Ashulia)': [23.8767, 90.3201],
  };

  String _origin = 'Mirpur 10 Hub';
  String _destination = 'DIU Smart City (Ashulia)';
  DateTime _departureTime = DateTime.now().add(const Duration(hours: 1));
  String _vehicleType = 'Bike';
  int _availableSeats = 1;
  bool _helmetProvided = true;

  // Active ride tracking simulation states
  String? _activeRideId;
  bool _isSimulating = false;
  Timer? _simulationTimer;
  double _simulatedLat = 0.0;
  double _simulatedLng = 0.0;
  int _simStep = 0;

  @override
  void initState() {
    super.initState();
    _socketService.connect();
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    _socketService.dispose();
    super.dispose();
  }

  void _submitOffer() async {
    if (!_formKey.currentState!.validate()) return;
    
    final originCoords = _hubs[_origin]!;
    final destCoords = _hubs[_destination]!;

    if (_origin == _destination) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Origin and destination hubs cannot be the same.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final success = await Provider.of<RideProvider>(context, listen: false).offerRide(
      originName: _origin,
      originLat: originCoords[0],
      originLng: originCoords[1],
      destinationName: _destination,
      destinationLat: destCoords[0],
      destinationLng: destCoords[1],
      departureTime: _departureTime,
      vehicleType: _vehicleType,
      availableSeats: _availableSeats,
      helmetProvided: _helmetProvided,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride offered successfully!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Provider.of<RideProvider>(context, listen: false).fetchActiveRides();
    }
  }

  void _startRideSimulation(String rideId, double startLat, double startLng, double endLat, double endLng) async {
    final success = await Provider.of<RideProvider>(context, listen: false).updateStatus(rideId, 'Active');
    if (!success) return;

    setState(() {
      _activeRideId = rideId;
      _isSimulating = true;
      _simulatedLat = startLat;
      _simulatedLng = startLng;
      _simStep = 0;
    });

    _socketService.joinRideRoom(rideId);
    _socketService.updateRideStatus(rideId, 'Active');

    _simulationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_simStep >= 10) {
        _stopRideSimulation(rideId);
        return;
      }

      setState(() {
        _simStep++;
        _simulatedLat = startLat + (endLat - startLat) * (_simStep / 10.0);
        _simulatedLng = startLng + (endLng - startLng) * (_simStep / 10.0);
      });

      _socketService.updateLocation(rideId, _simulatedLat, _simulatedLng, speed: 48.5);
    });
  }

  void _stopRideSimulation(String rideId) async {
    _simulationTimer?.cancel();
    final success = await Provider.of<RideProvider>(context, listen: false).updateStatus(rideId, 'Completed');
    
    if (success) {
      _socketService.updateRideStatus(rideId, 'Completed');
      setState(() {
        _isSimulating = false;
        _activeRideId = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ride completed! Thanks for ridesharing.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rideProvider = Provider.of<RideProvider>(context);
    final user = Provider.of<AuthProvider>(context).user;

    const primaryColor = Color(0xFF0F5132); // DIU Green
    const accentColor = Color(0xFF00B4D8);

    final userActiveRides = rideProvider.activeRides.where((r) => r['rider_id'] == user?['id']).toList();
    final hasActiveOffer = userActiveRides.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Publish Commute', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), // Extra padding for floating bottom nav
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Premium GPS active driver console with Custom Painter VectorMap
            if (_isSimulating) ...[
              Container(
                width: double.infinity,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.navigation, color: accentColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('LIVE COMMUTE ACTIVE', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
                              Text('Broadcasting GPS signals...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          onPressed: () => _stopRideSimulation(_activeRideId!),
                          child: const Text('Arrived', style: TextStyle(fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Vector Map Simulation render
                    VectorMap(
                      currentLat: _simulatedLat,
                      currentLng: _simulatedLng,
                      isActive: true,
                      vehicleType: _vehicleType,
                    ),
                    const SizedBox(height: 16),
                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _simStep / 10.0,
                        backgroundColor: Colors.white.withOpacity(0.08),
                        valueColor: const AlwaysStoppedAnimation<Color>(accentColor),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildConsoleMetric('LATITUDE', _simulatedLat.toStringAsFixed(5)),
                        _buildConsoleMetric('LONGITUDE', _simulatedLng.toStringAsFixed(5)),
                        _buildConsoleMetric('SPEED', '48 km/h'),
                      ],
                    )
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // 2. Active Ride Details & Request Monitor
            if (hasActiveOffer) ...[
              const Text('Active Commutes Offered', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor)),
              const SizedBox(height: 10),
              ...userActiveRides.map((ride) {
                final rideId = ride['id'];
                
                return FutureBuilder(
                  future: Provider.of<RideProvider>(context, listen: false).fetchRideDetails(rideId),
                  builder: (context, snapshot) {
                    final details = rideProvider.selectedRideDetails;
                    if (details == null || details['ride']['id'] != rideId) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24), 
                          child: Center(child: CircularProgressIndicator())
                        )
                      );
                    }

                    final requests = details['requests'] as List;
                    final pendingRequests = requests.where((req) => req['status'] == 'Pending').toList();
                    final acceptedRequests = requests.where((req) => req['status'] == 'Accepted').toList();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 20),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.share_location, color: primaryColor, size: 24),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${ride['origin_name']} ➔ ${ride['destination_name']}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: ride['status'] == 'Active' ? Colors.amber.shade50 : Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text(
                                    ride['status'],
                                    style: TextStyle(
                                      color: ride['status'] == 'Active' ? Colors.amber.shade800 : Colors.blue.shade700,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text('Departure: ${DateFormat('hh:mm a').format(DateTime.parse(ride['departure_time']))}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                            const Divider(height: 24),
                            
                            // Accepted Passengers list
                            if (acceptedRequests.isNotEmpty) ...[
                              const Text('Passengers sharing this ride:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                              const SizedBox(height: 8),
                              ...acceptedRequests.map((req) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  dense: true,
                                  leading: const CircleAvatar(
                                    backgroundColor: Colors.green,
                                    radius: 12,
                                    child: Icon(Icons.check, color: Colors.white, size: 14),
                                  ),
                                  title: Text(req['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('Call: ${req['phone']}'),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: primaryColor.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                                    child: Text('${req['dynamic_fare_share']} BDT', style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              )),
                              const SizedBox(height: 8),
                            ],

                            // Pending join requests
                            if (pendingRequests.isNotEmpty) ...[
                              const Text('Join Requests (Pending)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange)),
                              const SizedBox(height: 8),
                              ...pendingRequests.map((req) => Card(
                                color: Colors.orange.shade50.withOpacity(0.4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.orange.shade100)
                                ),
                                child: ListTile(
                                  title: Text(req['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Row(
                                    children: [
                                      const Icon(Icons.star, color: Colors.amber, size: 14),
                                      Text(' ${req['rating']} | ', style: const TextStyle(fontSize: 12)),
                                      Text('Fare: ${req['dynamic_fare_share']} BDT', style: const TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.check_circle, color: Colors.green, size: 28),
                                        onPressed: () => rideProvider.respondToPassengerRequest(req['request_id'], 'Accepted'),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.cancel, color: Colors.red, size: 28),
                                        onPressed: () => rideProvider.respondToPassengerRequest(req['request_id'], 'Rejected'),
                                      ),
                                    ],
                                  ),
                                ),
                              )),
                              const SizedBox(height: 8),
                            ],

                            if (pendingRequests.isEmpty && acceptedRequests.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Text('No ride requests received yet.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 13)),
                              ),
                            
                            if (ride['status'] == 'Scheduled' && !_isSimulating)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 46,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
                                    onPressed: () => _startRideSimulation(
                                      rideId, 
                                      ride['origin_lat'], ride['origin_lng'], 
                                      ride['destination_lat'], ride['destination_lng']
                                    ),
                                    icon: const Icon(Icons.play_arrow),
                                    label: const Text('Start Commuting Session', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }),
              const SizedBox(height: 24),
            ],

            // 3. Offer a Commute Form
            const Text('Publish a New Offer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor)),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Origin
                      DropdownButtonFormField<String>(
                        value: _origin,
                        decoration: const InputDecoration(
                          labelText: 'Starting Hub',
                          prefixIcon: Icon(Icons.my_location, color: primaryColor, size: 20),
                        ),
                        items: _hubs.keys.map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(),
                        onChanged: (val) => setState(() => _origin = val!),
                      ),
                      const SizedBox(height: 16),

                      // Destination
                      DropdownButtonFormField<String>(
                        value: _destination,
                        decoration: const InputDecoration(
                          labelText: 'Destination Hub',
                          prefixIcon: Icon(Icons.location_on_outlined, color: primaryColor, size: 20),
                        ),
                        items: _hubs.keys.map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(),
                        onChanged: (val) => setState(() => _destination = val!),
                      ),
                      const SizedBox(height: 16),

                      // Time Selector Card
                      InkWell(
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
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time, color: primaryColor),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Selected Departure Time', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat('yyyy-MM-dd | hh:mm a').format(_departureTime),
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Segmented Vehicle Type Cards
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 8.0, left: 4),
                          child: Text('Vehicle Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(child: _buildVehicleTab('Bike', Icons.motorcycle)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildVehicleTab('Car', Icons.directions_car)),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Seats selector
                      if (_vehicleType == 'Car')
                        DropdownButtonFormField<int>(
                          value: _availableSeats,
                          decoration: const InputDecoration(
                            labelText: 'Vacant Seats',
                            prefixIcon: Icon(Icons.event_seat_outlined, color: primaryColor, size: 20),
                          ),
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('1 seat')),
                            DropdownMenuItem(value: 2, child: Text('2 seats')),
                            DropdownMenuItem(value: 3, child: Text('3 seats')),
                            DropdownMenuItem(value: 4, child: Text('4 seats')),
                          ],
                          onChanged: (val) => setState(() => _availableSeats = val!),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50.withOpacity(0.2),
                            border: Border.all(color: Colors.teal.shade100),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, color: primaryColor, size: 20),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Bike offered commutes are capped at 1 passenger seat.',
                                  style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              )
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Helmet Switch
                      if (_vehicleType == 'Bike')
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: SwitchListTile(
                            title: const Text('Provide Secondary Helmet?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                            subtitle: const Text('DIU policy requires helmets for passenger insurance', style: TextStyle(fontSize: 11)),
                            value: _helmetProvided,
                            activeColor: primaryColor,
                            onChanged: (val) => setState(() => _helmetProvided = val),
                          ),
                        ),
                      const SizedBox(height: 24),

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: rideProvider.isLoading ? null : _submitOffer,
                          child: rideProvider.isLoading
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Publish Commute Offer', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildConsoleMetric(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildVehicleTab(String vehicle, IconData icon) {
    final isSelected = _vehicleType == vehicle;
    const primaryColor = Color(0xFF0F5132);

    return InkWell(
      onTap: () {
        setState(() {
          _vehicleType = vehicle;
          _availableSeats = _vehicleType == 'Bike' ? 1 : 3;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withOpacity(0.08) : Colors.white,
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? primaryColor : Colors.grey.shade600, size: 20),
            const SizedBox(width: 8),
            Text(
              vehicle,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? primaryColor : Colors.grey.shade700,
                fontSize: 13
              ),
            )
          ],
        ),
      ),
    );
  }
}
