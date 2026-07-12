import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
  
  String? _origin;
  String? _destination;
  DateTime _departureTime = DateTime.now().add(const Duration(hours: 1));
  String _vehicleType = 'Bike';
  int _availableSeats = 1;
  bool _helmetProvided = true;
  String _offeredFare = '50';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RideProvider>(context, listen: false).fetchHubs().then((_) {
        final hubs = Provider.of<RideProvider>(context, listen: false).hubs;
        if (hubs.isNotEmpty && mounted) {
          setState(() {
            _origin = hubs.first['name'];
            _destination = hubs.length > 1 ? hubs.last['name'] : hubs.first['name'];
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    _socketService.dispose();
    super.dispose();
  }

  void _submitOffer() async {
    if (!_formKey.currentState!.validate()) return;
    
    final hubs = Provider.of<RideProvider>(context, listen: false).hubs;
    final originHub = hubs.firstWhere((h) => h['name'] == _origin, orElse: () => null);
    final destHub = hubs.firstWhere((h) => h['name'] == _destination, orElse: () => null);

    if (originHub == null || destHub == null) return;

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
      originName: _origin!,
      originLat: double.parse(originHub['lat'].toString()),
      originLng: double.parse(originHub['lng'].toString()),
      destinationName: _destination!,
      destinationLat: double.parse(destHub['lat'].toString()),
      destinationLng: double.parse(destHub['lng'].toString()),
      departureTime: _departureTime,
      vehicleType: _vehicleType,
      availableSeats: _availableSeats,
      helmetProvided: _helmetProvided,
      offeredFare: double.tryParse(_offeredFare) ?? 50,
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

  void _respondToBid(String requestId, double proposedFare) {
    showDialog(
      context: context,
      builder: (ctx) {
        double bidAmount = proposedFare;
        bool isCountering = false;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Respond to Request'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Passenger is offering:', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text('$proposedFare BDT', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Color(0xFF101828))),
                  const SizedBox(height: 16),

                  if (!isCountering)
                    TextButton.icon(
                      onPressed: () => setStateDialog(() => isCountering = true),
                      icon: const Icon(Icons.local_offer),
                      label: const Text('Make a counter offer'),
                    )
                  else
                    TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Your Counter Offer (BDT)',
                        prefixIcon: Icon(Icons.money),
                      ),
                      onChanged: (val) {
                        if (val.isNotEmpty) {
                          bidAmount = double.tryParse(val) ?? proposedFare;
                        } else {
                          bidAmount = proposedFare;
                        }
                      },
                    )
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await Provider.of<RideProvider>(context, listen: false).respondToPassengerRequest(requestId, 'Rejected');
                  },
                  child: const Text('Reject entirely', style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    if (isCountering) {
                      await Provider.of<RideProvider>(context, listen: false).submitBid(requestId, bidAmount);
                    } else {
                      await Provider.of<RideProvider>(context, listen: false).respondToPassengerRequest(requestId, 'Accepted');
                    }
                  },
                  child: Text(isCountering ? 'Send Counter' : 'Accept Fare'),
                ),
              ],
            );
          }
        );
      }
    );
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

    const primaryColor = Color(0xFF101828);
    const accentColor = Color(0xFF2E90FA);

    final userActiveRides = rideProvider.activeRides.where((r) => r['rider_id'] == user?['id']).toList();
    final hasActiveOffer = userActiveRides.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offer a Commute', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 120), // Extra padding for floating bottom nav
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Premium GPS active driver console with Custom Painter VectorMap
            if (_isSimulating) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D2939), // Dark Slate
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF101828).withOpacity(0.2),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    )
                  ]
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.navigation, color: accentColor, size: 24),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('LIVE COMMUTE ACTIVE', style: TextStyle(color: accentColor, fontWeight: FontWeight.w600, fontSize: 12, letterSpacing: 0.5)),
                              Text('Broadcasting Location...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD92D20),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          onPressed: () => _stopRideSimulation(_activeRideId!),
                          child: const Text('End Ride', style: TextStyle(fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                    const SizedBox(height: 24),
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
              const Text('Active Commutes Offered', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
              const SizedBox(height: 16),
              ...userActiveRides.map((ride) {
                final rideId = ride['id'];
                
                return FutureBuilder(
                  future: Provider.of<RideProvider>(context, listen: false).fetchRideDetails(rideId),
                  builder: (context, snapshot) {
                    final details = rideProvider.selectedRideDetails;
                    if (details == null || details['ride']['id'] != rideId) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator())
                        )
                      );
                    }

                    final requests = details['requests'] as List;
                    final pendingRequests = requests.where((req) => req['status'] == 'Pending').toList();
                    final acceptedRequests = requests.where((req) => req['status'] == 'Accepted').toList();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 24),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF2F4F7),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.share_location, color: Color(0xFF475467), size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${ride['origin_name']} to',
                                        style: const TextStyle(color: Color(0xFF475467), fontSize: 13, fontWeight: FontWeight.w500),
                                      ),
                                      Text(
                                        ride['destination_name'],
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryColor),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: ride['status'] == 'Active' ? const Color(0xFFFEF0C7) : const Color(0xFFEFF8FF),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text(
                                    ride['status'],
                                    style: TextStyle(
                                      color: ride['status'] == 'Active' ? const Color(0xFFB54708) : const Color(0xFF175CD3),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                const Icon(Icons.access_time, size: 16, color: Color(0xFF667085)),
                                const SizedBox(width: 6),
                                Text('Departs at ${DateFormat('hh:mm a').format(DateTime.parse(ride['departure_time']))}', style: const TextStyle(color: Color(0xFF344054), fontSize: 14, fontWeight: FontWeight.w500)),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20.0),
                              child: Divider(height: 1, color: Color(0xFFEAECF0)),
                            ),
                            
                            // Accepted Passengers list
                            if (acceptedRequests.isNotEmpty) ...[
                              const Text('Passengers Joined', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: primaryColor)),
                              const SizedBox(height: 12),
                              ...acceptedRequests.map((req) => Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFEAECF0)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(color: Color(0xFF12B76A), shape: BoxShape.circle),
                                      child: const Icon(Icons.check, color: Colors.white, size: 12),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(req['name'], style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
                                          Text('Contact: ${req['phone']}', style: const TextStyle(fontSize: 12, color: Color(0xFF667085))),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(color: const Color(0xFFF2F4F7), borderRadius: BorderRadius.circular(8)),
                                      child: Text('${req['proposed_fare']} BDT', style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              )).toList().animate().fadeIn().slideX(begin: 0.1),
                              const SizedBox(height: 16),
                            ],

                            // Pending join requests
                            if (pendingRequests.isNotEmpty) ...[
                              const Text('Pending Requests', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFFDC6803))),
                              const SizedBox(height: 12),
                              ...pendingRequests.map((req) => Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFAEB),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFFEF0C7)),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        const CircleAvatar(
                                          radius: 16,
                                          backgroundColor: Color(0xFFF2F4F7),
                                          child: Icon(Icons.person, size: 18, color: Color(0xFF475467)),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(req['name'], style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 15)),
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  const Icon(Icons.star_rounded, color: Color(0xFFF79009), size: 14),
                                                  Text(' ${req['rating']}', style: const TextStyle(fontSize: 13, color: Color(0xFFB54708), fontWeight: FontWeight.w600)),
                                                ],
                                              ),
                                              if (req['bid_status'] == 'Rider_Counter')
                                                const Text('Waiting for passenger response', style: TextStyle(fontSize: 12, color: Color(0xFF667085))),
                                            ],
                                          ),
                                        ),
                                        Text('${req['proposed_fare']} BDT', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFB54708))),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    if (req['bid_status'] != 'Rider_Counter')
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: const Color(0xFFD92D20),
                                                side: const BorderSide(color: Color(0xFFFDA29B)),
                                              ),
                                              onPressed: () => rideProvider.respondToPassengerRequest(req['request_id'], 'Rejected'),
                                              child: const Text('Decline'),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF12B76A),
                                              ),
                                              onPressed: () => _respondToBid(req['request_id'], double.tryParse(req['proposed_fare'].toString()) ?? 0),
                                              child: const Text('Respond'),
                                            ),
                                          ),
                                        ],
                                      )
                                  ],
                                ),
                              )).toList().animate().fadeIn().slideX(begin: 0.1),
                              const SizedBox(height: 8),
                            ],

                            if (pendingRequests.isEmpty && acceptedRequests.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Text('No ride requests received yet.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 13)),
                              ),
                            
                            if (ride['status'] == 'Scheduled' && !_isSimulating)
                              Padding(
                                padding: const EdgeInsets.only(top: 16.0),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: accentColor,
                                      elevation: 0,
                                    ),
                                    onPressed: () => _startRideSimulation(
                                      rideId, 
                                      ride['origin_lat'], ride['origin_lng'], 
                                      ride['destination_lat'], ride['destination_lng']
                                    ),
                                    icon: const Icon(Icons.play_circle_fill),
                                    label: const Text('Start Commute Now'),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn().slideY(begin: 0.1);
                  },
                );
              }),
              const SizedBox(height: 32),
            ],

            // 3. Offer a Commute Form
            const Text('Publish a New Offer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Origin
                      if (rideProvider.hubs.isEmpty)
                        const CircularProgressIndicator()
                      else ...[
                        DropdownButtonFormField<String>(
                          value: _origin,
                          decoration: InputDecoration(
                            labelText: 'Starting Hub',
                            prefixIcon: const Icon(Icons.trip_origin, color: accentColor, size: 20),
                            fillColor: const Color(0xFFF9FAFB),
                          ),
                          items: rideProvider.hubs.map((h) => DropdownMenuItem<String>(value: h['name'], child: Text(h['name']))).toList(),
                          onChanged: (val) => setState(() => _origin = val!),
                        ),
                        const SizedBox(height: 16),

                        // Destination
                        DropdownButtonFormField<String>(
                          value: _destination,
                          decoration: InputDecoration(
                            labelText: 'Destination Hub',
                            prefixIcon: const Icon(Icons.location_on, color: primaryColor, size: 20),
                            fillColor: const Color(0xFFF9FAFB),
                          ),
                          items: rideProvider.hubs.map((h) => DropdownMenuItem<String>(value: h['name'], child: Text(h['name']))).toList(),
                          onChanged: (val) => setState(() => _destination = val!),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Time Selector Card
                      GestureDetector(
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
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFEAECF0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFEAECF0))),
                                child: const Icon(Icons.access_time, color: Color(0xFF475467)),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Departure Time', style: TextStyle(color: Color(0xFF667085), fontSize: 13, fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('MMM dd, yyyy  •  hh:mm a').format(_departureTime),
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 15),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Segmented Vehicle Type Cards
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 12.0, left: 4),
                          child: Text('Vehicle Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF344054))),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(child: _buildVehicleTab('Bike', Icons.motorcycle)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildVehicleTab('Car', Icons.directions_car)),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Seats selector
                      if (_vehicleType == 'Car')
                        DropdownButtonFormField<int>(
                          value: _availableSeats,
                          decoration: InputDecoration(
                            labelText: 'Available Seats',
                            prefixIcon: const Icon(Icons.event_seat_outlined, color: primaryColor, size: 20),
                            fillColor: const Color(0xFFF9FAFB),
                          ),
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('1 seat')),
                            DropdownMenuItem(value: 2, child: Text('2 seats')),
                            DropdownMenuItem(value: 3, child: Text('3 seats')),
                            DropdownMenuItem(value: 4, child: Text('4 seats')),
                          ],
                          onChanged: (val) => setState(() => _availableSeats = val!),
                        ).animate().fadeIn()
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF8FF),
                            border: Border.all(color: const Color(0xFFD1E9FF)),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, color: Color(0xFF175CD3), size: 20),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Bike commutes are limited to 1 passenger.',
                                  style: TextStyle(color: Color(0xFF175CD3), fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                              )
                            ],
                          ),
                        ).animate().fadeIn(),
                      const SizedBox(height: 20),

                      // Helmet Switch
                      if (_vehicleType == 'Bike')
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFEAECF0)),
                          ),
                          child: SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            title: const Text('Provide spare helmet?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: primaryColor)),
                            subtitle: const Text('Campus policy requires helmets for passenger safety', style: TextStyle(fontSize: 13, color: Color(0xFF667085))),
                            value: _helmetProvided,
                            activeColor: accentColor,
                            onChanged: (val) => setState(() => _helmetProvided = val),
                          ),
                        ).animate().fadeIn(),
                      const SizedBox(height: 24),

                      // Base Fare Request
                      TextFormField(
                        initialValue: _offeredFare,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Offered Fare (BDT)',
                          prefixIcon: const Icon(Icons.money, color: primaryColor, size: 20),
                          fillColor: const Color(0xFFF9FAFB),
                        ),
                        validator: (value) => value == null || value.isEmpty || int.tryParse(value) == null ? 'Enter valid amount' : null,
                        onSaved: (value) => _offeredFare = value!,
                        onChanged: (val) => setState(() => _offeredFare = val),
                      ).animate().fadeIn(),
                      const SizedBox(height: 32),

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: rideProvider.isLoading ? null : _submitOffer,
                          child: rideProvider.isLoading
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                              : const Text('Publish Commute Offer'),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
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
    const primaryColor = Color(0xFF101828);

    return GestureDetector(
      onTap: () {
        setState(() {
          _vehicleType = vehicle;
          _availableSeats = _vehicleType == 'Bike' ? 1 : 3;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 16),
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
            Icon(icon, color: isSelected ? Colors.white : const Color(0xFF667085), size: 22),
            const SizedBox(width: 10),
            Text(
              vehicle,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF344054),
                fontSize: 15
              ),
            )
          ],
        ),
      ),
    );
  }
}
