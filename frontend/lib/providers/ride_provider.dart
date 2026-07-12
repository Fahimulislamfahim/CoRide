import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RideProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<dynamic> _activeRides = [];
  Map<String, dynamic>? _selectedRideDetails;
  bool _isLoading = false;
  String? _error;

  List<dynamic> get activeRides => _activeRides;
  Map<String, dynamic>? get selectedRideDetails => _selectedRideDetails;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Fetch available rides for matching
  Future<void> fetchActiveRides() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.get('/rides/active');
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
  Future<bool> requestToJoinRide(String rideId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.post('/rides/request', data: {
        'ride_id': rideId,
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

  // Reset selected ride details
  void clearSelectedRide() {
    _selectedRideDetails = null;
    notifyListeners();
  }
}
