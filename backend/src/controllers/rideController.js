const db = require('../config/db');

// Helper to calculate distance in km using Haversine formula
const calculateDistance = (lat1, lon1, lat2, lon2) => {
  const R = 6371; // Earth radius in km
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = 
    Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * 
    Math.sin(dLon/2) * Math.sin(dLon/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c;
};

// Calculate Base Ride Fare
// DIU rides usually run between hubs (Mirpur/Uttara) to Ashulia (approx 15-25km).
// Base price: Bike = 10 BDT/km, Car = 20 BDT/km.
const calculateBaseFare = (lat1, lon1, lat2, lon2, vehicleType) => {
  const distance = calculateDistance(lat1, lon1, lat2, lon2);
  const ratePerKm = vehicleType === 'Bike' ? 10 : 20;
  const basePrice = vehicleType === 'Bike' ? 30 : 60; // Flag drop fare
  return basePrice + (distance * ratePerKm);
};

// Create a Ride Offer
const createRide = async (req, res) => {
  const riderId = req.user.id;
  const { 
    origin_name, origin_lat, origin_lng, 
    destination_name, destination_lat, destination_lng, 
    departure_time, vehicle_type, available_seats, helmet_provided 
  } = req.body;

  // Input validation
  if (!origin_name || !origin_lat || !origin_lng || !destination_name || 
      !destination_lat || !destination_lng || !departure_time || 
      !vehicle_type || available_seats === undefined) {
    return res.status(400).json({ error: 'Missing required ride parameters.' });
  }

  // Validate seats constraint
  if (vehicle_type === 'Bike' && available_seats > 1) {
    return res.status(400).json({ error: 'Bikers can offer a maximum of 1 seat.' });
  }
  if (vehicle_type === 'Car' && (available_seats < 1 || available_seats > 4)) {
    return res.status(400).json({ error: 'Car owners can specify between 1 to 4 vacant seats.' });
  }

  try {
    const insertQuery = `
      INSERT INTO rides (
        rider_id, origin_name, origin_lat, origin_lng, 
        destination_name, destination_lat, destination_lng, 
        departure_time, vehicle_type, available_seats, helmet_provided, status
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, 'Scheduled')
      RETURNING *
    `;
    const result = await db.query(insertQuery, [
      riderId, origin_name, origin_lat, origin_lng,
      destination_name, destination_lat, destination_lng,
      departure_time, vehicle_type, available_seats, helmet_provided || false
    ]);

    res.status(201).json({
      message: 'Ride offered successfully',
      ride: result.rows[0]
    });
  } catch (err) {
    console.error('Create ride error:', err);
    res.status(500).json({ error: 'Failed to create ride offer.' });
  }
};

// Get active matching rides for passengers
const getActiveRides = async (req, res) => {
  const passengerId = req.user.id;
  try {
    // Return rides that are scheduled or active, and have seats left (or the user has already requested them)
    const query = `
      SELECT r.*, u.name as rider_name, u.rating as rider_rating, u.phone as rider_phone,
             rr.status as passenger_request_status, rr.id as passenger_request_id
      FROM rides r
      JOIN users u ON r.rider_id = u.id
      LEFT JOIN ride_requests rr ON rr.ride_id = r.id AND rr.passenger_id = $1
      WHERE r.status IN ('Scheduled', 'Active') 
        AND (r.available_seats > 0 OR rr.status IS NOT NULL)
        AND r.departure_time > NOW() - INTERVAL '30 minutes'
      ORDER BY r.departure_time ASC
    `;
    const result = await db.query(query, [passengerId]);
    
    // Add estimated fare share info to each ride based on 1 rider join
    const ridesWithFare = result.rows.map(ride => {
      const baseFare = calculateBaseFare(
        ride.origin_lat, ride.origin_lng, 
        ride.destination_lat, ride.destination_lng, 
        ride.vehicle_type
      );
      // Fare is split between rider and passengers.
      // If 1 passenger joins, split is 50/50.
      return {
        ...ride,
        estimated_fare: Math.round(baseFare / 2) 
      };
    });

    res.json(ridesWithFare);
  } catch (err) {
    console.error('Get active rides error:', err);
    res.status(500).json({ error: 'Failed to retrieve active rides.' });
  }
};

// Request a Ride
const requestRide = async (req, res) => {
  const passengerId = req.user.id;
  const { ride_id } = req.body;

  if (!ride_id) {
    return res.status(400).json({ error: 'Ride ID is required.' });
  }

  try {
    // 1. Check if ride exists, is active, and has seats
    const rideResult = await db.query('SELECT * FROM rides WHERE id = $1', [ride_id]);
    if (rideResult.rows.length === 0) {
      return res.status(404).json({ error: 'Ride not found.' });
    }
    const ride = rideResult.rows[0];

    if (ride.status !== 'Scheduled') {
      return res.status(400).json({ error: `Cannot request a ride that is already ${ride.status}.` });
    }
    if (ride.available_seats <= 0) {
      return res.status(400).json({ error: 'No seats available for this ride.' });
    }
    if (ride.rider_id === passengerId) {
      return res.status(400).json({ error: 'You cannot request your own ride.' });
    }

    // 2. Check if request already exists
    const requestCheck = await db.query(
      'SELECT * FROM ride_requests WHERE ride_id = $1 AND passenger_id = $2',
      [ride_id, passengerId]
    );
    if (requestCheck.rows.length > 0) {
      return res.status(409).json({ error: 'You have already requested this ride.' });
    }

    // 3. Count already accepted passengers for this ride to calculate dynamic fare share
    const acceptedCountResult = await db.query(
      "SELECT COUNT(*) FROM ride_requests WHERE ride_id = $1 AND status = 'Accepted'",
      [ride_id]
    );
    const acceptedPassengers = parseInt(acceptedCountResult.rows[0].count);

    // Dynamic Fare Calculation:
    // Base fare gets split equally among (Rider + Passengers).
    // Total participants = 1 (Rider) + acceptedPassengers + 1 (this new passenger request).
    const baseFare = calculateBaseFare(
      ride.origin_lat, ride.origin_lng,
      ride.destination_lat, ride.destination_lng,
      ride.vehicle_type
    );
    const splitCount = 1 + acceptedPassengers + 1;
    const dynamicFare = Math.round(baseFare / splitCount);

    // 4. Insert request
    const insertRequest = `
      INSERT INTO ride_requests (ride_id, passenger_id, status, dynamic_fare_share)
      VALUES ($1, $2, 'Pending', $3)
      RETURNING *
    `;
    const result = await db.query(insertRequest, [ride_id, passengerId, dynamicFare]);

    res.status(201).json({
      message: 'Ride requested successfully',
      request: result.rows[0]
    });
  } catch (err) {
    console.error('Request ride error:', err);
    res.status(500).json({ error: 'Failed to submit ride request.' });
  }
};

// Recalculate and update fare share for all accepted passengers of a ride
const updateDynamicFaresForRide = async (rideId) => {
  // 1. Get ride details
  const rideResult = await db.query('SELECT * FROM rides WHERE id = $1', [rideId]);
  if (rideResult.rows.length === 0) return;
  const ride = rideResult.rows[0];

  // 2. Get all accepted requests
  const acceptedRequests = await db.query(
    "SELECT id FROM ride_requests WHERE ride_id = $1 AND status = 'Accepted'",
    [rideId]
  );
  const count = acceptedRequests.rows.length;
  if (count === 0) return;

  // 3. Calculate new fare
  // Total participants = 1 (rider) + count (passengers)
  const baseFare = calculateBaseFare(
    ride.origin_lat, ride.origin_lng,
    ride.destination_lat, ride.destination_lng,
    ride.vehicle_type
  );
  const dynamicFare = Math.round(baseFare / (1 + count));

  // 4. Update database
  await db.query(
    "UPDATE ride_requests SET dynamic_fare_share = $1 WHERE ride_id = $2 AND status = 'Accepted'",
    [dynamicFare, rideId]
  );
};

// Accept or Reject Request (Rider Only)
const respondToRequest = async (req, res) => {
  const riderId = req.user.id;
  const { request_id, action } = req.body; // action: 'Accepted' or 'Rejected'

  if (!request_id || !action || !['Accepted', 'Rejected'].includes(action)) {
    return res.status(400).json({ error: 'Request ID and valid action (Accepted/Rejected) are required.' });
  }

  try {
    // 1. Get request and ride info
    const requestQuery = `
      SELECT rr.*, r.rider_id, r.available_seats, r.status as ride_status
      FROM ride_requests rr
      JOIN rides r ON rr.ride_id = r.id
      WHERE rr.id = $1
    `;
    const requestResult = await db.query(requestQuery, [request_id]);
    if (requestResult.rows.length === 0) {
      return res.status(404).json({ error: 'Request not found.' });
    }
    const request = requestResult.rows[0];

    // 2. Check if logged in user is the owner of the ride
    if (request.rider_id !== riderId) {
      return res.status(403).json({ error: 'Unauthorized. Only the ride owner can respond to requests.' });
    }

    if (request.ride_status !== 'Scheduled') {
      return res.status(400).json({ error: 'Cannot accept/reject requests for a ride that is not Scheduled.' });
    }

    if (action === 'Accepted') {
      // Check if seats are still available
      if (request.available_seats <= 0) {
        return res.status(400).json({ error: 'Cannot accept request. No seats available.' });
      }

      // Start transaction
      const client = await db.pool.connect();
      try {
        await client.query('BEGIN');
        
        // Update request status
        await client.query(
          "UPDATE ride_requests SET status = 'Accepted' WHERE id = $1",
          [request_id]
        );

        // Decrement available seats in ride
        await client.query(
          "UPDATE rides SET available_seats = available_seats - 1 WHERE id = $1",
          [request.ride_id]
        );

        await client.query('COMMIT');
      } catch (err) {
        await client.query('ROLLBACK');
        throw err;
      } finally {
        client.release();
      }

      // Re-calculate dynamic fare share for all accepted passengers in this ride
      await updateDynamicFaresForRide(request.ride_id);
    } else {
      // Action is Rejected
      await db.query(
        "UPDATE ride_requests SET status = 'Rejected' WHERE id = $1",
        [request_id]
      );
    }

    res.json({ message: `Request successfully ${action.toLowerCase()}.` });
  } catch (err) {
    console.error('Respond to request error:', err);
    res.status(500).json({ error: 'Failed to update request status.' });
  }
};

// Update Ride Status (Rider Only)
const updateRideStatus = async (req, res) => {
  const riderId = req.user.id;
  const { ride_id, status } = req.body;

  if (!ride_id || !status || !['Scheduled', 'Active', 'Completed', 'Cancelled'].includes(status)) {
    return res.status(400).json({ error: 'Ride ID and valid status are required.' });
  }

  try {
    // 1. Verify ownership
    const checkQuery = 'SELECT rider_id, status FROM rides WHERE id = $1';
    const checkResult = await db.query(checkQuery, [ride_id]);
    if (checkResult.rows.length === 0) {
      return res.status(404).json({ error: 'Ride not found.' });
    }
    const ride = checkResult.rows[0];

    if (ride.rider_id !== riderId) {
      return res.status(403).json({ error: 'Unauthorized. Only the rider can update the status.' });
    }

    // 2. Update status
    await db.query('UPDATE rides SET status = $1 WHERE id = $2', [status, ride_id]);

    // Handle cancellation: reject all pending requests
    if (status === 'Cancelled') {
      await db.query(
        "UPDATE ride_requests SET status = 'Rejected' WHERE ride_id = $1 AND status = 'Pending'",
        [ride_id]
      );
    }

    res.json({ message: `Ride status successfully updated to ${status}.` });
  } catch (err) {
    console.error('Update ride status error:', err);
    res.status(500).json({ error: 'Failed to update ride status.' });
  }
};

// Get Detailed Ride Info for rooms
const getRideDetails = async (req, res) => {
  const rideId = req.params.id;

  try {
    const rideQuery = `
      SELECT r.*, u.name as rider_name, u.phone as rider_phone, u.rating as rider_rating
      FROM rides r
      JOIN users u ON r.rider_id = u.id
      WHERE r.id = $1
    `;
    const rideResult = await db.query(rideQuery, [rideId]);
    if (rideResult.rows.length === 0) {
      return res.status(404).json({ error: 'Ride not found.' });
    }
    const ride = rideResult.rows[0];

    // Get passengers for this ride (both accepted and pending)
    const passengersQuery = `
      SELECT rr.id as request_id, rr.status, rr.dynamic_fare_share, u.id as passenger_id, u.name, u.phone, u.rating
      FROM ride_requests rr
      JOIN users u ON rr.passenger_id = u.id
      WHERE rr.ride_id = $1
    `;
    const passengersResult = await db.query(passengersQuery, [rideId]);

    res.json({
      ride,
      requests: passengersResult.rows
    });
  } catch (err) {
    console.error('Get ride details error:', err);
    res.status(500).json({ error: 'Failed to fetch ride details.' });
  }
};

// Cancel Ride Request (Passenger Only)
const cancelRequest = async (req, res) => {
  const passengerId = req.user.id;
  const { ride_id } = req.body;

  if (!ride_id) {
    return res.status(400).json({ error: 'Ride ID is required.' });
  }

  try {
    // 1. Find if the request exists and its status
    const requestQuery = `
      SELECT * FROM ride_requests 
      WHERE ride_id = $1 AND passenger_id = $2
    `;
    const requestResult = await db.query(requestQuery, [ride_id, passengerId]);
    if (requestResult.rows.length === 0) {
      return res.status(404).json({ error: 'Request not found.' });
    }
    const request = requestResult.rows[0];

    // 2. Perform deletion and seat increment (if accepted)
    const client = await db.pool.connect();
    try {
      await client.query('BEGIN');

      // Delete request record
      await client.query('DELETE FROM ride_requests WHERE id = $1', [request.id]);

      // If it was accepted, restore seat count
      if (request.status === 'Accepted') {
        await client.query(
          'UPDATE rides SET available_seats = available_seats + 1 WHERE id = $1',
          [ride_id]
        );
      }

      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }

    // 3. Recalculate dynamic fares for remaining passengers if this request was accepted
    if (request.status === 'Accepted') {
      await updateDynamicFaresForRide(ride_id);
    }

    res.json({ message: 'Ride request cancelled successfully.' });
  } catch (err) {
    console.error('Cancel request error:', err);
    res.status(500).json({ error: 'Failed to cancel ride request.' });
  }
};

module.exports = {
  createRide,
  getActiveRides,
  requestRide,
  respondToRequest,
  updateRideStatus,
  getRideDetails,
  cancelRequest,
};
