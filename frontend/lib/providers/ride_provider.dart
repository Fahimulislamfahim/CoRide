import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RideProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<dynamic> _activeRides = [];
  List<dynamic> _rideHistory = [];
  List<dynamic> _hubs = [];
  Map<String, dynamic>? _selectedRideDetails;
  bool _isLoading = false;
  String? _error;

  List<dynamic> get activeRides => _activeRides;
  List<dynamic> get rideHistory => _rideHistory;
  List<dynamic> get hubs => _hubs;
  Map<String, dynamic>? get selectedRideDetails => _selectedRideDetails;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Fetch dynamic locations
  Future<void> fetchHubs() async {
    try {
      final response = await _apiService.get('/hubs');
      if (response.statusCode == 200) {
        _hubs = response.data;
        notifyListeners();
      }
    } catch (e) {
      print('Failed to fetch hubs: $e');
    }
  }

  // Fetch available rides for matching with filters
  Future<void> fetchActiveRides({String? origin, String? destination, String? vehicleType}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final queryParams = <String, dynamic>{};
      if (origin != null && origin.isNotEmpty) queryParams['origin'] = origin;
      if (destination != null && destination.isNotEmpty) queryParams['destination'] = destination;
      if (vehicleType != null && vehicleType.isNotEmpty) queryParams['vehicleType'] = vehicleType;

      final response = await _apiService.get('/rides/active', queryParameters: queryParams);
      if (response.statusCode == 200) {
        _activeRides = response.data;
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // Create a new ride offer (Rider Dashboard)
  Future<bool> offerRide({
    required String originName,
    required double originLat,
    required double originLng,
    required String destinationName,
    required double destinationLat,
    required double destinationLng,
    required DateTime departureTime,
    required String vehicleType,
    required int availableSeats,
    required bool helmetProvided,
    required double offeredFare,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.post('/rides/offer', data: {
        'origin_name': originName,
        'origin_lat': originLat,
        'origin_lng': originLng,
        'destination_name': destinationName,
        'destination_lat': destinationLat,
        'destination_lng': destinationLng,
        'departure_time': departureTime.toIso8601String(),
        'vehicle_type': vehicleType,
        'available_seats': availableSeats,
        'helmet_provided': helmetProvided,
        'offered_fare': offeredFare,
      });

      if (response.statusCode == 201) {
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Request to join a ride (Passenger Matching)
  Future<bool> requestToJoinRide(String rideId, [double? bidAmount]) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = {'ride_id': rideId};
      if (bidAmount != null) {
        data['bid_amount'] = bidAmount.toString();
      }

      final response = await _apiService.post('/rides/request', data: data);

      if (response.statusCode == 201) {
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Submit a Counter Bid
  Future<bool> submitBid(String requestId, double proposedFare) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.post('/rides/request/$requestId/bid', data: {
        'proposed_fare': proposedFare,
      });

      if (response.statusCode == 200) {
        // Refresh details
        if (_selectedRideDetails != null && _selectedRideDetails!['ride']['id'] != null) {
          await fetchRideDetails(_selectedRideDetails!['ride']['id']);
        } else {
          await fetchActiveRides();
        }
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Cancel a ride request (Passenger only)
  Future<bool> cancelRideRequest(String rideId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.post('/rides/cancel-request', data: {
        'ride_id': rideId,
      });

      if (response.statusCode == 200) {
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Accept/Reject request (Rider only)
  Future<bool> respondToPassengerRequest(String requestId, String action) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.post('/rides/respond', data: {
        'request_id': requestId,
        'action': action, // 'Accepted' or 'Rejected'
      });

      if (response.statusCode == 200) {
        // If we are currently viewing details of this ride, reload them
        if (_selectedRideDetails != null && 
            _selectedRideDetails!['ride'] != null && 
            _selectedRideDetails!['ride']['id'] != null) {
          await fetchRideDetails(_selectedRideDetails!['ride']['id']);
        }
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Update overall ride status (Active, Completed, Cancelled)
  Future<bool> updateStatus(String rideId, String status) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.patch('/rides/status', data: {
        'ride_id': rideId,
        'status': status,
      });

      if (response.statusCode == 200) {
        if (_selectedRideDetails != null && _selectedRideDetails!['ride']['id'] == rideId) {
          _selectedRideDetails!['ride']['status'] = status;
        }
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Fetch full details of a specific ride (for the active chat/room view)
  Future<void> fetchRideDetails(String rideId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.get('/rides/$rideId');
      if (response.statusCode == 200) {
        _selectedRideDetails = response.data;
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // Fetch Ride History
  Future<void> fetchRideHistory() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.get('/rides/history');
      if (response.statusCode == 200) {
        _rideHistory = response.data;
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // Submit a Review
  Future<bool> submitReview(String rideId, String revieweeId, int rating, String comment) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.post('/rides/$rideId/review', data: {
        'reviewee_id': revieweeId,
        'rating': rating,
        'comment': comment,
      });

      if (response.statusCode == 201) {
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Reset selected ride details
  void clearSelectedRide() {
    _selectedRideDetails = null;
    notifyListeners();
  }
}
