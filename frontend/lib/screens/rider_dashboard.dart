import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme, MaterialPageRoute;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/ride_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/vector_map.dart';
import '../main.dart';

class RiderDashboard extends StatefulWidget {
  const RiderDashboard({super.key});

  @override
  State<RiderDashboard> createState() => _RiderDashboardState();
}

class _RiderDashboardState extends State<RiderDashboard> {
  final _formKey = GlobalKey<FormState>();

  String? _origin;
  String? _destination;
  DateTime _departureTime = DateTime.now().add(const Duration(hours: 1));
  String _vehicleType = 'Bike';
  int _availableSeats = 1;
  bool _helmetProvided = true;
  String _offeredFare = '50';

  bool _isSimulating = false;
  double _simulatedProgress = 0.0;
  String? _simulatingRideId;
  String? _simulationMsg;
  double? _currLat;
  double? _currLng;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RideProvider>(context, listen: false).fetchHubs();
      Provider.of<RideProvider>(context, listen: false).fetchActiveRides();
    });
  }

  void _showDynamicIslandAlert(String title, {bool isError = false}) {
    showCupertinoDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && Navigator.of(ctx).canPop()) {
            Navigator.of(ctx).pop();
          }
        });
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 60),
            child: CupertinoPopupSurface(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: iosDarkGray,
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isError ? CupertinoIcons.xmark_circle_fill : CupertinoIcons.check_mark_circled_solid,
                         color: isError ? iosRed : iosGreen, size: 24),
                    const SizedBox(width: 12),
                    Text(title, style: const TextStyle(color: iosTextLight, fontSize: 15, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ).animate().slideY(begin: -1.0, curve: Curves.easeOutBack, duration: 400.ms),
          ),
        );
      }
    );
  }

  void _submitOffer() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final hubs = Provider.of<RideProvider>(context, listen: false).hubs;
    if (hubs.isEmpty || _origin == null || _destination == null) return;

    final originHub = hubs.firstWhere((h) => h['name'] == _origin);
    final destHub = hubs.firstWhere((h) => h['name'] == _destination);

    if (_origin == _destination) {
      _showDynamicIslandAlert('Origin and destination cannot be the same', isError: true);
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
      _showDynamicIslandAlert('Commute offered successfully');
      Provider.of<RideProvider>(context, listen: false).fetchActiveRides();
    }
  }

  void _respondToBid(String requestId, double proposedFare) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) {
        double bidAmount = proposedFare;
        bool isCountering = false;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return CupertinoAlertDialog(
              title: const Text('Respond to Bid'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  const Text('Passenger offered:', style: TextStyle(color: iosGrayText)),
                  const SizedBox(height: 4),
                  Text('$proposedFare BDT', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: iosTextLight)),
                  const SizedBox(height: 16),

                  if (!isCountering)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => setStateDialog(() => isCountering = true),
                      child: const Text('Make Counter Offer'),
                    )
                  else
                    CupertinoTextField(
                      keyboardType: TextInputType.number,
                      placeholder: 'Counter Offer (BDT)',
                      style: const TextStyle(color: iosTextLight),
                      decoration: BoxDecoration(color: iosDarkGray, borderRadius: BorderRadius.circular(8)),
                      onChanged: (val) {
                        if (val.isNotEmpty) {
                          bidAmount = double.tryParse(val) ?? proposedFare;
                        }
                      },
                    )
                ],
              ),
              actions: [
                CupertinoDialogAction(
                  isDestructiveAction: true,
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await Provider.of<RideProvider>(context, listen: false).respondToPassengerRequest(requestId, 'Rejected');
                  },
                  child: const Text('Decline'),
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    if (isCountering) {
                      await Provider.of<RideProvider>(context, listen: false).submitBid(requestId, bidAmount);
                    } else {
                      await Provider.of<RideProvider>(context, listen: false).respondToPassengerRequest(requestId, 'Accepted');
                    }
                  },
                  child: Text(isCountering ? 'Send' : 'Accept'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _startRideSimulation(String rideId, double oLat, double oLng, double dLat, double dLng) async {
    setState(() {
      _isSimulating = true;
      _simulatedProgress = 0.0;
      _simulatingRideId = rideId;
      _currLat = oLat;
      _currLng = oLng;
      _simulationMsg = "Starting Engine...";
    });
    final rideProvider = Provider.of<RideProvider>(context, listen: false);
    // Note: Simulated backend status update logic not present in provider yet, skipping for UI demonstration

    // Simulate steps
    final steps = 10;
    for (int i = 1; i <= steps; i++) {
      if (!mounted) break;
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _simulatedProgress = i / steps;
        _currLat = oLat + ((dLat - oLat) * _simulatedProgress);
        _currLng = oLng + ((dLng - oLng) * _simulatedProgress);
        _simulationMsg = i == steps ? "Arrived at destination" : "Driving... ${(i * 10)}% complete";
      });
    }

    if (!mounted) return;
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _isSimulating = false;
      _simulatingRideId = null;
      _currLat = null;
      _currLng = null;
      _simulationMsg = null;
    });
    _showDynamicIslandAlert('Trip Completed!');
    rideProvider.fetchActiveRides();
  }

  Widget _buildHubPicker(String title, String? value, void Function(String?) onChanged) {
    final hubs = Provider.of<RideProvider>(context, listen: false).hubs;
    return GestureDetector(
      onTap: () {
        showCupertinoModalPopup(
          context: context,
          builder: (ctx) => Container(
            height: 250,
            color: iosDarkGray,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(ctx)),
                    CupertinoButton(child: const Text('Done'), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 32.0,
                    onSelectedItemChanged: (idx) => onChanged(hubs[idx]['name']),
                    children: hubs.map((h) => Center(child: Text(h['name'], style: const TextStyle(color: iosTextLight)))).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(color: iosDarkGray, borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(value ?? title, style: TextStyle(color: value == null ? iosGrayText : iosTextLight)),
            const Icon(CupertinoIcons.chevron_down, color: iosGrayText, size: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rideProvider = Provider.of<RideProvider>(context);
    final myRides = rideProvider.activeRides.where((r) => r['rider_id'] == Provider.of<AuthProvider>(context).user?['id']).toList();

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Drive', style: TextStyle(color: iosTextLight, fontWeight: FontWeight.w700)),
        backgroundColor: iosBlack.withOpacity(0.8),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.square_arrow_right, color: iosRed),
          onPressed: () => Provider.of<AuthProvider>(context, listen: false).logout(),
        ),
      ),
      backgroundColor: iosBlack,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isSimulating && _simulatingRideId != null) ...[
              Container(
                decoration: BoxDecoration(
                  color: iosDarkGray,
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('Active Trip', style: TextStyle(color: iosTextLight, fontSize: 17, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Text(_simulationMsg ?? '', style: const TextStyle(color: iosBlue, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 200,
                        child: VectorMap(
                          currentLat: _currLat ?? 0,
                          currentLng: _currLng ?? 0,
                          isActive: true,
                          vehicleType: _vehicleType,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    CupertinoProgressBar(value: _simulatedProgress),
                  ],
                ),
              ).animate().fadeIn().scale(),
              const SizedBox(height: 24),
            ],

            const Padding(
              padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
              child: Text('Your Active Offers', style: TextStyle(color: iosTextLight, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
            ),

            if (myRides.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: Text('You have not published any commutes yet.',
                    style: TextStyle(color: iosTextLight.withOpacity(0.5))),
                ),
              )
            else
              ...myRides.map((ride) {
                // Temporary patch: We don't have getRequestsForRide on the Provider, so mock the requests list mapping
                // Assuming `ride['passenger_request_status']` is available from the active rides join
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: iosDarkGray,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: ride['status'] == 'Scheduled' ? iosBlue.withOpacity(0.2) : iosGreen.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(ride['status'], style: TextStyle(
                              color: ride['status'] == 'Scheduled' ? iosBlue : iosGreen,
                              fontSize: 12, fontWeight: FontWeight.w600
                            )),
                          ),
                          Text('${ride['available_seats']} seats left', style: const TextStyle(color: iosGrayText, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text('${ride['origin_name']} ➔ ${ride['destination_name']}',
                           style: const TextStyle(color: iosTextLight, fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text('Dept: ${DateFormat('MMM dd, hh:mm a').format(DateTime.parse(ride['departure_time']))}',
                           style: const TextStyle(color: iosGrayText, fontSize: 14)),

                      if (ride['passenger_request_status'] == 'Pending') ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: Container(height: 1, color: const Color(0x33FFFFFF)),
                        ),
                        const Text('Passenger Request Pending', style: TextStyle(color: iosTextLight, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: const Color(0x22FFFFFF), borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Passenger', style: TextStyle(color: iosTextLight, fontWeight: FontWeight.w500)),
                                  Text('${ride['offered_fare']} BDT', style: const TextStyle(color: iosGreen, fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                              CupertinoButton(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                color: iosBlue,
                                borderRadius: BorderRadius.circular(20),
                                child: const Text('Review', style: TextStyle(fontSize: 14)),
                                onPressed: () => _respondToBid(ride['passenger_request_id'], double.tryParse(ride['offered_fare'].toString()) ?? 0),
                              )
                            ],
                          ),
                        ),
                      ],

                      if (ride['status'] == 'Scheduled' && !_isSimulating) ...[
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: CupertinoButton(
                            color: iosGreen,
                            borderRadius: BorderRadius.circular(16),
                            child: const Text('Start Commute', style: TextStyle(fontWeight: FontWeight.w600)),
                            onPressed: () => _startRideSimulation(
                              ride['id'], ride['origin_lat'], ride['origin_lng'], ride['destination_lat'], ride['destination_lng']
                            ),
                          ),
                        )
                      ]
                    ],
                  ),
                ).animate().fadeIn().slideY(begin: 0.1);
              }),

            const SizedBox(height: 32),
            const Padding(
              padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
              child: Text('Publish New Offer', style: TextStyle(color: iosTextLight, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
            ),

            Container(
              decoration: BoxDecoration(
                color: iosDarkGray,
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (rideProvider.hubs.isEmpty)
                      const CupertinoActivityIndicator()
                    else ...[
                      _buildHubPicker('Select Origin Hub', _origin, (val) => setState(() => _origin = val)),
                      const SizedBox(height: 12),
                      _buildHubPicker('Select Destination Hub', _destination, (val) => setState(() => _destination = val)),
                    ],
                    const SizedBox(height: 16),

                    Container(
                      decoration: BoxDecoration(color: iosBlack, borderRadius: BorderRadius.circular(12)),
                      child: SizedBox(
                        height: 120,
                        child: CupertinoDatePicker(
                          initialDateTime: _departureTime,
                          mode: CupertinoDatePickerMode.dateAndTime,
                          use24hFormat: false,
                          onDateTimeChanged: (val) => setState(() => _departureTime = val),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    CupertinoSlidingSegmentedControl<String>(
                      backgroundColor: iosBlack,
                      thumbColor: iosBlue,
                      groupValue: _vehicleType,
                      children: const {
                        'Bike': Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text('Bike', style: TextStyle(color: iosWhite))),
                        'Car': Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text('Car', style: TextStyle(color: iosWhite))),
                      },
                      onValueChanged: (val) => setState(() {
                        _vehicleType = val!;
                        _availableSeats = val == 'Bike' ? 1 : 3;
                      }),
                    ),
                    const SizedBox(height: 16),

                    if (_vehicleType == 'Car')
                      CupertinoTextField(
                        keyboardType: TextInputType.number,
                        placeholder: 'Available Seats',
                        style: const TextStyle(color: iosTextLight),
                        decoration: BoxDecoration(color: iosBlack, borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.all(16),
                        onChanged: (val) => _availableSeats = int.tryParse(val) ?? 3,
                      ),

                    if (_vehicleType == 'Bike')
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Provide spare helmet?', style: TextStyle(color: iosTextLight)),
                          CupertinoSwitch(
                            value: _helmetProvided,
                            activeColor: iosBlue,
                            onChanged: (val) => setState(() => _helmetProvided = val),
                          )
                        ],
                      ),

                    const SizedBox(height: 16),

                    CupertinoTextFormFieldRow(
                      placeholder: 'Base Fare (BDT)',
                      keyboardType: TextInputType.number,
                      initialValue: _offeredFare,
                      style: const TextStyle(color: iosTextLight),
                      decoration: BoxDecoration(color: iosBlack, borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.all(16),
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                      onSaved: (val) => _offeredFare = val!,
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        color: iosBlue,
                        borderRadius: BorderRadius.circular(16),
                        onPressed: rideProvider.isLoading ? null : _submitOffer,
                        child: rideProvider.isLoading
                            ? const CupertinoActivityIndicator(color: iosWhite)
                            : const Text('Publish Commute', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 100), // padding for bottom scroll
          ],
        ),
      ),
    );
  }
}

class CupertinoProgressBar extends StatelessWidget {
  final double value;
  const CupertinoProgressBar({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      width: double.infinity,
      decoration: BoxDecoration(
        color: iosBlack,
        borderRadius: BorderRadius.circular(4),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: iosBlue,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}
