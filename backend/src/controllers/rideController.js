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
    departure_time, vehicle_type, available_seats, helmet_provided, offered_fare
  } = req.body;

  // Input validation
  if (!origin_name || !origin_lat || !origin_lng || !destination_name || 
      !destination_lat || !destination_lng || !departure_time || 
      !vehicle_type || available_seats === undefined || !offered_fare) {
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
        departure_time, vehicle_type, available_seats, helmet_provided, offered_fare, status
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, 'Scheduled')
      RETURNING *
    `;
    const result = await db.query(insertQuery, [
      riderId, origin_name, origin_lat, origin_lng,
      destination_name, destination_lat, destination_lng,
      departure_time, vehicle_type, available_seats, helmet_provided || false, offered_fare
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
  const { origin, destination, vehicleType } = req.query;

  try {
    let query = `
      SELECT r.*, u.name as rider_name, u.rating as rider_rating, u.phone as rider_phone,
             rr.status as passenger_request_status, rr.id as passenger_request_id,
             rr.bid_status, rr.proposed_fare
      FROM rides r
      JOIN users u ON r.rider_id = u.id
      LEFT JOIN ride_requests rr ON rr.ride_id = r.id AND rr.passenger_id = $1
      WHERE r.status IN ('Scheduled', 'Active') 
        AND (r.available_seats > 0 OR rr.status IS NOT NULL)
        AND r.departure_time > NOW() - INTERVAL '30 minutes'
    `;
    
    const params = [passengerId];
    let paramIndex = 2;

    if (origin) {
      query += ` AND r.origin_name = $${paramIndex}`;
      params.push(origin);
      paramIndex++;
    }

    if (destination) {
      query += ` AND r.destination_name = $${paramIndex}`;
      params.push(destination);
      paramIndex++;
    }

    if (vehicleType) {
      query += ` AND r.vehicle_type = $${paramIndex}`;
      params.push(vehicleType);
      paramIndex++;
    }

    query += ` ORDER BY r.departure_time ASC`;

    const result = await db.query(query, params);

    res.json(result.rows);
  } catch (err) {
    console.error('Get active rides error:', err);
    res.status(500).json({ error: 'Failed to retrieve active rides.' });
  }
};

// Request a Ride (Initial Bid)
const requestRide = async (req, res) => {
  const passengerId = req.user.id;
  const { ride_id, bid_amount } = req.body;

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

    // 3. Determine if it's an acceptance or a counter bid
    let proposedFare = ride.offered_fare;
    let bidStatus = 'Initial'; // Assuming accepted directly
    let bidsCount = 0;

    if (bid_amount && Number(bid_amount) !== Number(ride.offered_fare)) {
      proposedFare = bid_amount;
      bidStatus = 'Passenger_Counter';
      bidsCount = 1; // Passenger used 1 bid
    }

    // 4. Insert request
    const insertRequest = `
      INSERT INTO ride_requests (ride_id, passenger_id, status, proposed_fare, bid_status, passenger_bids_count)
      VALUES ($1, $2, 'Pending', $3, $4, $5)
      RETURNING *
    `;
    const result = await db.query(insertRequest, [ride_id, passengerId, proposedFare, bidStatus, bidsCount]);

    res.status(201).json({
      message: bidStatus === 'Passenger_Counter' ? 'Bid submitted to rider.' : 'Ride requested at offered fare.',
      request: result.rows[0]
    });
  } catch (err) {
    console.error('Request ride error:', err);
    res.status(500).json({ error: 'Failed to submit ride request.' });
  }
};

// Handle Counter Bids (Passenger or Rider)
const submitBid = async (req, res) => {
  const userId = req.user.id;
  const requestId = req.params.id;
  const { proposed_fare } = req.body;

  if (!proposed_fare || isNaN(proposed_fare)) {
    return res.status(400).json({ error: 'Valid proposed_fare is required.' });
  }

  try {
    // Get request and ride info
    const query = `
      SELECT rr.*, r.rider_id
      FROM ride_requests rr
      JOIN rides r ON rr.ride_id = r.id
      WHERE rr.id = $1
    `;
    const result = await db.query(query, [requestId]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Ride request not found.' });
    }

    const request = result.rows[0];

    if (request.status !== 'Pending') {
      return res.status(400).json({ error: `Cannot bid on a request that is already ${request.status}.` });
    }

    const isRider = userId === request.rider_id;
    const isPassenger = userId === request.passenger_id;

    if (!isRider && !isPassenger) {
      return res.status(403).json({ error: 'Unauthorized to bid on this request.' });
    }

    let newBidStatus = '';
    let newBidsCount = request.passenger_bids_count;

    if (isRider) {
      if (request.bid_status === 'Rider_Counter') {
        return res.status(400).json({ error: 'You must wait for the passenger to respond to your last bid.' });
      }
      newBidStatus = 'Rider_Counter';
    } else if (isPassenger) {
      if (request.bid_status === 'Passenger_Counter') {
        return res.status(400).json({ error: 'You must wait for the rider to respond to your last bid.' });
      }
      if (request.passenger_bids_count >= 2) {
        // If passenger attempts a 3rd bid, automatically reject the request per rules
        await db.query("UPDATE ride_requests SET status = 'Rejected', bid_status = 'Rejected_Limit_Reached' WHERE id = $1", [requestId]);
        return res.status(400).json({ error: 'Bid limit reached. Request automatically rejected.' });
      }
      newBidStatus = 'Passenger_Counter';
      newBidsCount += 1;
    }

    // Update the request with the new bid
    const updateQuery = `
      UPDATE ride_requests
      SET proposed_fare = $1, bid_status = $2, passenger_bids_count = $3
      WHERE id = $4 RETURNING *
    `;
    const updated = await db.query(updateQuery, [proposed_fare, newBidStatus, newBidsCount, requestId]);

    res.json({ message: 'Counter offer submitted successfully.', request: updated.rows[0] });

  } catch (err) {
    console.error('Submit bid error:', err);
    res.status(500).json({ error: 'Failed to submit counter offer.' });
  }
};

// Accept or Reject Request (Rider or Passenger)
const respondToRequest = async (req, res) => {
  const userId = req.user.id;
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

    // Determine who is responding
    const isRider = userId === request.rider_id;
    const isPassenger = userId === request.passenger_id;

    if (!isRider && !isPassenger) {
      return res.status(403).json({ error: 'Unauthorized to respond to this request.' });
    }

    if (request.ride_status !== 'Scheduled') {
      return res.status(400).json({ error: 'Cannot accept/reject requests for a ride that is not Scheduled.' });
    }

    if (request.status !== 'Pending') {
       return res.status(400).json({ error: `Request is already ${request.status}.` });
    }

    // Logic: A user can only 'Accept' a counter-offer from the OTHER user, or a Rider can accept the 'Initial' request.
    if (action === 'Accepted') {
      if (isRider && request.bid_status === 'Rider_Counter') {
        return res.status(400).json({ error: 'You cannot accept your own counter offer. Wait for the passenger.' });
      }
      if (isPassenger && (request.bid_status === 'Initial' || request.bid_status === 'Passenger_Counter')) {
        return res.status(400).json({ error: 'You cannot accept your own bid.' });
      }

      // Check if seats are still available
      if (request.available_seats <= 0) {
        return res.status(400).json({ error: 'Cannot accept request. No seats available in this ride.' });
      }

      // Start transaction
      const client = await db.pool.connect();
      try {
        await client.query('BEGIN');
        
        // Update request status to Accepted and bid_status to Accepted
        await client.query(
          "UPDATE ride_requests SET status = 'Accepted', bid_status = 'Accepted' WHERE id = $1",
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

    } else {
      // Action is Rejected (by either party)
      await db.query(
        "UPDATE ride_requests SET status = 'Rejected', bid_status = $1 WHERE id = $2",
        [isRider ? 'Rejected_By_Rider' : 'Rejected_By_Passenger', request_id]
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
      SELECT rr.id as request_id, rr.status, rr.proposed_fare, rr.bid_status, u.id as passenger_id, u.name, u.phone, u.rating
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

    // 2. Perform cancellation and seat increment (if accepted)
    const client = await db.pool.connect();
    try {
      await client.query('BEGIN');

      // Mark request cancelled
      await client.query("UPDATE ride_requests SET status = 'Cancelled' WHERE id = $1", [request.id]);

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

    res.json({ message: 'Ride request cancelled successfully.' });
  } catch (err) {
    console.error('Cancel request error:', err);
    res.status(500).json({ error: 'Failed to cancel ride request.' });
  }
};

// Get Ride History (Past Rides)
const getRideHistory = async (req, res) => {
  const userId = req.user.id;

  try {
    // Get rides where user was the rider OR passenger and status is Completed or Cancelled
    const query = `
      SELECT DISTINCT r.*, u.name as rider_name, u.rating as rider_rating
      FROM rides r
      JOIN users u ON r.rider_id = u.id
      LEFT JOIN ride_requests rr ON rr.ride_id = r.id AND rr.passenger_id = $1
      WHERE (r.rider_id = $1 OR (rr.passenger_id = $1 AND rr.status = 'Accepted'))
        AND r.status IN ('Completed', 'Cancelled')
      ORDER BY r.departure_time DESC
    `;
    const result = await db.query(query, [userId]);
    res.json(result.rows);
  } catch (err) {
    console.error('Get history error:', err);
    res.status(500).json({ error: 'Failed to retrieve ride history.' });
  }
};

// Submit a Review
const submitReview = async (req, res) => {
  const reviewerId = req.user.id;
  const rideId = req.params.id;
  const { reviewee_id, rating, comment } = req.body;

  if (!reviewee_id || !rating || rating < 1 || rating > 5) {
    return res.status(400).json({ error: 'Valid reviewee_id and rating (1-5) are required.' });
  }

  if (reviewerId === reviewee_id) {
    return res.status(400).json({ error: 'You cannot review yourself.' });
  }

  try {
    // 1. Ensure ride is completed
    const rideResult = await db.query('SELECT status FROM rides WHERE id = $1', [rideId]);
    if (rideResult.rows.length === 0 || rideResult.rows[0].status !== 'Completed') {
      return res.status(400).json({ error: 'Reviews can only be submitted for completed rides.' });
    }

    // 2. Insert Review
    const client = await db.pool.connect();
    try {
      await client.query('BEGIN');

      const insertReview = `
        INSERT INTO reviews (ride_id, reviewer_id, reviewee_id, rating, comment)
        VALUES ($1, $2, $3, $4, $5)
        RETURNING *
      `;
      const reviewRecord = await client.query(insertReview, [rideId, reviewerId, reviewee_id, rating, comment]);

      // 3. Update User's Average Rating
      const avgQuery = `
        SELECT AVG(rating) as new_avg
        FROM reviews
        WHERE reviewee_id = $1
      `;
      const avgResult = await client.query(avgQuery, [reviewee_id]);
      const newAvg = parseFloat(avgResult.rows[0].new_avg).toFixed(2);

      await client.query('UPDATE users SET rating = $1 WHERE id = $2', [newAvg, reviewee_id]);

      await client.query('COMMIT');
      res.status(201).json({ message: 'Review submitted successfully.', review: reviewRecord.rows[0], newRating: newAvg });
    } catch (err) {
      await client.query('ROLLBACK');
      if (err.code === '23505') { // unique_violation
        return res.status(409).json({ error: 'You have already reviewed this user for this ride.' });
      }
      throw err;
    } finally {
      client.release();
    }
  } catch (err) {
    console.error('Submit review error:', err);
    res.status(500).json({ error: 'Failed to submit review.' });
  }
};

module.exports = {
  createRide,
  getActiveRides,
  requestRide,
  submitBid,
  respondToRequest,
  updateRideStatus,
  getRideDetails,
  cancelRequest,
  getRideHistory,
  submitReview,
};
