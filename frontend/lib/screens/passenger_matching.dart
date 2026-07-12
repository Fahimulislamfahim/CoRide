import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/ride_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/vector_map.dart';
import '../main.dart';

class PassengerMatching extends StatefulWidget {
  const PassengerMatching({super.key});

  @override
  State<PassengerMatching> createState() => _PassengerMatchingState();
}

class _PassengerMatchingState extends State<PassengerMatching> {
  String? _origin;
  String? _destination;
  String _selectedVehicle = 'All';

  bool _isTracking = false;
  String? _trackingRideId;
  double? _currLat;
  double? _currLng;
  double? _destLat;
  double? _destLng;
  String? _trackingVehicleType;

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

  void _requestJoin(String rideId, double baseFare) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) {
        double bidAmount = baseFare;
        bool isBidding = false;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return CupertinoAlertDialog(
              title: const Text('Join Commute'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  const Text('Rider is asking for:', style: TextStyle(color: iosGrayText)),
                  const SizedBox(height: 4),
                  Text('$baseFare BDT', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: iosTextLight)),
                  const SizedBox(height: 16),

                  if (!isBidding)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => setStateDialog(() => isBidding = true),
                      child: const Text('Offer a different fare'),
                    )
                  else
                    CupertinoTextField(
                      keyboardType: TextInputType.number,
                      placeholder: 'Your Fare Offer (BDT)',
                      style: const TextStyle(color: iosTextLight),
                      decoration: BoxDecoration(color: iosDarkGray, borderRadius: BorderRadius.circular(8)),
                      onChanged: (val) {
                        if (val.isNotEmpty) {
                          bidAmount = double.tryParse(val) ?? baseFare;
                        }
                      },
                    )
                ],
              ),
              actions: [
                CupertinoDialogAction(
                  isDestructiveAction: true,
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    final success = await Provider.of<RideProvider>(context, listen: false).requestToJoinRide(rideId, isBidding ? bidAmount : null);
                    if (success && mounted) {
                      _showDynamicIslandAlert('Request Sent');
                      Provider.of<RideProvider>(context, listen: false).fetchActiveRides();
                    }
                  },
                  child: Text(isBidding ? 'Send Offer' : 'Accept Fare'),
                ),
              ],
            );
          },
        );
      },
    );
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
              title: const Text('Respond to Rider Counter'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  const Text('Rider countered with:', style: TextStyle(color: iosGrayText)),
                  const SizedBox(height: 4),
                  Text('$proposedFare BDT', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: iosTextLight)),
                  const SizedBox(height: 16),

                  if (!isCountering)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => setStateDialog(() => isCountering = true),
                      child: const Text('Make another counter'),
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

  void _cancelRequest(String rideId) async {
    final success = await Provider.of<RideProvider>(context, listen: false).cancelRideRequest(rideId);
    if (success && mounted) {
      _showDynamicIslandAlert('Request Cancelled');
      Provider.of<RideProvider>(context, listen: false).fetchActiveRides();
    }
  }

  void _startTrackingRide(String rideId, String vehicleType, double destLat, double destLng) {
    setState(() {
      _isTracking = true;
      _trackingRideId = rideId;
      _currLat = destLat - 0.05; // mock distance
      _currLng = destLng - 0.05; // mock distance
      _destLat = destLat;
      _destLng = destLng;
      _trackingVehicleType = vehicleType;
    });

    // Mock live progress
    _mockLiveUpdates();
  }

  void _mockLiveUpdates() async {
    final steps = 15;
    for (int i = 1; i <= steps; i++) {
      if (!mounted || !_isTracking) return;
      await Future.delayed(const Duration(seconds: 1));

      setState(() {
        _currLat = _currLat! + ((_destLat! - _currLat!) * (1/steps));
        _currLng = _currLng! + ((_destLng! - _currLng!) * (1/steps));
      });
    }

    if (!mounted) return;
    setState(() {
      _isTracking = false;
      _trackingRideId = null;
    });
    _showDynamicIslandAlert('Arrived at Destination');
    Provider.of<RideProvider>(context, listen: false).fetchActiveRides();
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
                    CupertinoButton(
                      child: const Text('Clear', style: TextStyle(color: iosRed)),
                      onPressed: () {
                        onChanged(null);
                        Navigator.pop(ctx);
                      }
                    ),
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

  void _searchRides() {
    Provider.of<RideProvider>(context, listen: false).fetchActiveRides(
      origin: _origin,
      destination: _destination,
      vehicleType: _selectedVehicle == 'All' ? null : _selectedVehicle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final rideProvider = Provider.of<RideProvider>(context);
    final rides = rideProvider.activeRides;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Ride', style: TextStyle(color: iosTextLight, fontWeight: FontWeight.w700)),
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
            if (_isTracking && _trackingRideId != null) ...[
              Container(
                decoration: BoxDecoration(
                  color: iosDarkGray,
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('Live Commute Tracking', style: TextStyle(color: iosTextLight, fontSize: 17, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 250,
                        child: VectorMap(
                          currentLat: _currLat ?? 0,
                          currentLng: _currLng ?? 0,
                          isActive: true,
                          vehicleType: _trackingVehicleType ?? 'Bike',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    CupertinoButton(
                      color: iosDarkGray,
                      child: const Text('Hide Tracking', style: TextStyle(color: iosRed)),
                      onPressed: () => setState(() => _isTracking = false),
                    )
                  ],
                ),
              ).animate().fadeIn().scale(),
              const SizedBox(height: 24),
            ],

            const Padding(
              padding: EdgeInsets.only(left: 8.0, bottom: 16.0),
              child: Text('Find a Commute', style: TextStyle(color: iosTextLight, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -1)),
            ),

            Container(
              decoration: BoxDecoration(
                color: iosDarkGray.withOpacity(0.5),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildHubPicker('From', _origin, (val) => setState(() => _origin = val)),
                  const SizedBox(height: 12),
                  _buildHubPicker('To', _destination, (val) => setState(() => _destination = val)),
                  const SizedBox(height: 16),

                  CupertinoSlidingSegmentedControl<String>(
                    backgroundColor: iosBlack,
                    thumbColor: iosBlue,
                    groupValue: _selectedVehicle,
                    children: const {
                      'All': Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text('Any', style: TextStyle(color: iosWhite))),
                      'Bike': Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text('Bike', style: TextStyle(color: iosWhite))),
                      'Car': Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text('Car', style: TextStyle(color: iosWhite))),
                    },
                    onValueChanged: (val) => setState(() => _selectedVehicle = val!),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      color: iosBlue,
                      borderRadius: BorderRadius.circular(16),
                      onPressed: _searchRides,
                      child: const Text('Search', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  )
                ],
              ),
            ),

            const SizedBox(height: 32),
            const Padding(
              padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
              child: Text('Available Offers', style: TextStyle(color: iosTextLight, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
            ),

            if (rideProvider.isLoading)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(child: CupertinoActivityIndicator(radius: 16)),
              )
            else if (rides.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32.0),
                child: Center(
                  child: Text('No commutes found matching your search.',
                    style: TextStyle(color: iosTextLight.withOpacity(0.5))),
                ),
              )
            else
              ...rides.map((ride) {
                final isPending = ride['passenger_request_status'] == 'Pending';
                final isAccepted = ride['passenger_request_status'] == 'Accepted';
                final isRequested = isPending || isAccepted;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: iosDarkGray,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isAccepted ? iosGreen.withOpacity(0.5) :
                             isPending ? iosBlue.withOpacity(0.5) :
                             const Color(0x00000000), // transparent
                      width: 1.5
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(ride['vehicle_type'] == 'Bike' ? CupertinoIcons.wind : CupertinoIcons.car_detailed, color: iosGrayText, size: 20),
                              const SizedBox(width: 8),
                              Text(ride['rider_name'], style: const TextStyle(color: iosTextLight, fontWeight: FontWeight.w600)),
                              const SizedBox(width: 8),
                              Icon(CupertinoIcons.star_fill, color: iosBlue, size: 14),
                              Text(' ${ride['rider_rating']}', style: const TextStyle(color: iosBlue, fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Text('${ride['offered_fare']} BDT', style: const TextStyle(color: iosGreen, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text('${ride['origin_name']} ➔ ${ride['destination_name']}',
                           style: const TextStyle(color: iosTextLight, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('Dept: ${DateFormat('MMM dd, hh:mm a').format(DateTime.parse(ride['departure_time']))}',
                           style: const TextStyle(color: iosGrayText, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('${ride['available_seats']} seats left • Helmet: ${ride['helmet_provided'] ? 'Yes' : 'No'}',
                           style: const TextStyle(color: iosGrayText, fontSize: 13)),

                      if (isRequested) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isAccepted ? iosGreen.withOpacity(0.1) : iosBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(isAccepted ? CupertinoIcons.check_mark_circled : CupertinoIcons.time,
                                   color: isAccepted ? iosGreen : iosBlue, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  isAccepted ? 'Request Accepted' :
                                  (ride['bid_status'] == 'Rider_Counter' ? 'Rider countered: ${ride['proposed_fare']} BDT' : 'Waiting for rider response'),
                                  style: TextStyle(color: isAccepted ? iosGreen : iosBlue, fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),
                      Row(
                        children: [
                          if (ride['status'] == 'Active' && isAccepted)
                            Expanded(
                              child: CupertinoButton(
                                color: iosBlue,
                                padding: EdgeInsets.zero,
                                onPressed: () => _startTrackingRide(ride['id'], ride['vehicle_type'], ride['destination_lat'], ride['destination_lng']),
                                child: const Text('Track Live', style: TextStyle(fontWeight: FontWeight.w600)),
                              ),
                            ),

                          if (!isRequested)
                            Expanded(
                              child: CupertinoButton(
                                color: iosDarkGray.withOpacity(0.8),
                                padding: EdgeInsets.zero,
                                child: const Text('Request to Join', style: TextStyle(color: iosBlue, fontWeight: FontWeight.w600)),
                                onPressed: () => _requestJoin(ride['id'], double.tryParse(ride['offered_fare'].toString()) ?? 0),
                              ),
                            )
                          else if (isPending || isAccepted) ...[
                            if (ride['bid_status'] == 'Rider_Counter')
                              Expanded(
                                child: CupertinoButton(
                                  color: iosBlue,
                                  padding: EdgeInsets.zero,
                                  onPressed: () => _respondToBid(ride['passenger_request_id'], double.tryParse(ride['proposed_fare'].toString()) ?? 0),
                                  child: const Text('Review Counter'),
                                ),
                              )
                            else
                              Expanded(
                                child: CupertinoButton(
                                  color: iosRed.withOpacity(0.1),
                                  padding: EdgeInsets.zero,
                                  onPressed: () => _cancelRequest(ride['id']),
                                  child: const Text('Cancel', style: TextStyle(color: iosRed, fontWeight: FontWeight.w600)),
                                ),
                              )
                          ]
                        ],
                      )
                    ],
                  ),
                ).animate().fadeIn().slideY(begin: 0.1);
              }).toList(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}
