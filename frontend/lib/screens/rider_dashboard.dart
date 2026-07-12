import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/ride_provider.dart';
import '../providers/auth_provider.dart';
import '../services/socket_service.dart';

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

  // Handle Hub selection coordinate parsing and database submission
  void _submitOffer() async {
    if (!_formKey.currentState!.validate()) return;
    
    final originCoords = _hubs[_origin]!;
    final destCoords = _hubs[_destination]!;

    if (_origin == _destination) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Origin and destination hubs cannot be the same.')),
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
        const SnackBar(content: Text('Ride offered successfully! Keep checking for passenger requests.')),
      );
      Provider.of<RideProvider>(context, listen: false).fetchActiveRides();
    }
  }

  // GPS Route Simulation
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

    // Simulate route in 10 steps towards destination
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

      // Broadcast throttled location to passengers in the room
      _socketService.updateLocation(rideId, _simulatedLat, _simulatedLng, speed: 45.0);
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
          const SnackBar(content: Text('Ride completed! Thanks for ridesharing.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rideProvider = Provider.of<RideProvider>(context);
    final user = Provider.of<AuthProvider>(context).user;

    const primaryColor = Color(0xFF0F5132); // DIU Green

    // Find if user already has an active ride offer
    final userActiveRides = rideProvider.activeRides.where((r) => r['rider_id'] == user?['id']).toList();
    final hasActiveOffer = userActiveRides.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offer a Ride', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Simulation banner
            if (_isSimulating)
              Card(
                color: Colors.amber[100],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      const Icon(Icons.sync, color: Colors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Active Ride Simulation running...', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('Current location: (${_simulatedLat.toStringAsFixed(4)}, ${_simulatedLng.toStringAsFixed(4)})'),
                            Text('Progress: ${(_simStep * 10)}% complete'),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                        onPressed: () => _stopRideSimulation(_activeRideId!),
                        child: const Text('Complete'),
                      )
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),

            // Offered Ride Requests Manager (If user offered a ride)
            if (hasActiveOffer) ...[
              const Text('Your Active Ride Offers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
              const SizedBox(height: 8),
              ...userActiveRides.map((ride) {
                final rideId = ride['id'];
                
                return FutureBuilder(
                  future: Provider.of<RideProvider>(context, listen: false).fetchRideDetails(rideId),
                  builder: (context, snapshot) {
                    final details = rideProvider.selectedRideDetails;
                    if (details == null || details['ride']['id'] != rideId) {
                      return const Card(child: Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())));
                    }

                    final requests = details['requests'] as List;
                    final pendingRequests = requests.where((req) => req['status'] == 'Pending').toList();
                    final acceptedRequests = requests.where((req) => req['status'] == 'Accepted').toList();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${ride['origin_name']} ➔ ${ride['destination_name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Chip(
                                  label: Text(ride['status']),
                                  backgroundColor: ride['status'] == 'Active' ? Colors.green[100] : Colors.blue[100],
                                ),
                              ],
                            ),
                            Text('Departure: ${DateFormat('hh:mm a').format(DateTime.parse(ride['departure_time']))}'),
                            Text('Available Seats: ${ride['available_seats']} | Vehicle: ${ride['vehicle_type']}'),
                            const Divider(),
                            
                            // Accepted Passengers & Dynamic Fare
                            if (acceptedRequests.isNotEmpty) ...[
                              const Text('Accepted Passengers (Splitting Fare)', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              ...acceptedRequests.map((req) => ListTile(
                                dense: true,
                                leading: const Icon(Icons.check_circle, color: Colors.green),
                                title: Text(req['name']),
                                subtitle: Text('Phone: ${req['phone']}'),
                                trailing: Text('${req['dynamic_fare_share']} BDT', style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
                              )),
                              const SizedBox(height: 8),
                            ],

                            // Pending passenger requests
                            if (pendingRequests.isNotEmpty) ...[
                              const Text('Pending Join Requests', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                              const SizedBox(height: 4),
                              ...pendingRequests.map((req) => Card(
                                color: Colors.orange[50],
                                child: ListTile(
                                  title: Text('${req['name']} (Rating: ${req['rating']})'),
                                  subtitle: Text('Est. Fare Share: ${req['dynamic_fare_share']} BDT'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.check, color: Colors.green),
                                        onPressed: () => rideProvider.respondToPassengerRequest(req['request_id'], 'Accepted'),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close, color: Colors.red),
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
                                child: Text('No requests received yet.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                              ),
                            
                            if (ride['status'] == 'Scheduled' && !_isSimulating)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
                                  onPressed: () => _startRideSimulation(
                                    rideId, 
                                    ride['origin_lat'], ride['origin_lng'], 
                                    ride['destination_lat'], ride['destination_lng']
                                  ),
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('Start commuting'),
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

            // Offer Ride Form
            const Text('Offer a New Commute', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
            const SizedBox(height: 12),
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Origin hub dropdown
                      DropdownButtonFormField<String>(
                        value: _origin,
                        decoration: const InputDecoration(labelText: 'Starting Hub', border: OutlineInputBorder()),
                        items: _hubs.keys.map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(),
                        onChanged: (val) => setState(() => _origin = val!),
                      ),
                      const SizedBox(height: 16),

                      // Destination hub dropdown
                      DropdownButtonFormField<String>(
                        value: _destination,
                        decoration: const InputDecoration(labelText: 'Destination Hub', border: OutlineInputBorder()),
                        items: _hubs.keys.map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(),
                        onChanged: (val) => setState(() => _destination = val!),
                      ),
                      const SizedBox(height: 16),

                      // Departure Time selector
                      ListTile(
                        shape: RoundedRectangleBorder(
                          side: const BorderSide(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        title: Text('Departure Time: ${DateFormat('yyyy-MM-dd hh:mm a').format(_departureTime)}'),
                        trailing: const Icon(Icons.access_time, color: primaryColor),
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
                      const SizedBox(height: 16),

                      // Vehicle selection
                      DropdownButtonFormField<String>(
                        value: _vehicleType,
                        decoration: const InputDecoration(labelText: 'Vehicle Type', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'Bike', child: Text('Motorcycle (Bike)')),
                          DropdownMenuItem(value: 'Car', child: Text('Private Car')),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _vehicleType = val!;
                            _availableSeats = _vehicleType == 'Bike' ? 1 : 3; // Reset seats default
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Seats selector
                      if (_vehicleType == 'Car')
                        DropdownButtonFormField<int>(
                          value: _availableSeats,
                          decoration: const InputDecoration(labelText: 'Vacant Seats', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('1 seat')),
                            DropdownMenuItem(value: 2, child: Text('2 seats')),
                            DropdownMenuItem(value: 3, child: Text('3 seats')),
                            DropdownMenuItem(value: 4, child: Text('4 seats')),
                          ],
                          onChanged: (val) => setState(() => _availableSeats = val!),
                        )
                      else
                        const ListTile(
                          title: Text('Seat Available: 1 seat max'),
                          subtitle: Text('Bikes are limited to 1 passenger seat by policy'),
                          leading: Icon(Icons.motorcycle, color: primaryColor),
                        ),
                      const SizedBox(height: 16),

                      // Helmet switch (Bike specific)
                      if (_vehicleType == 'Bike')
                        SwitchListTile(
                          title: const Text('Secondary Helmet Provided?'),
                          subtitle: const Text('Policy: passengers must wear a helmet during the ride'),
                          value: _helmetProvided,
                          activeColor: primaryColor,
                          onChanged: (val) => setState(() => _helmetProvided = val),
                        ),
                      const SizedBox(height: 20),

                      // Submit offer
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
                          onPressed: rideProvider.isLoading ? null : _submitOffer,
                          child: rideProvider.isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Publish Offer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
}
