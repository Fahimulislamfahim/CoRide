const { Pool } = require('pg');
const crypto = require('crypto');
require('dotenv').config();

const connectionString = process.env.DATABASE_URL;
let pool;
let useMock = false;

// In-Memory Database Store for offline testing
const store = {
  users: [],
  rides: [],
  ride_requests: []
};

if (!connectionString) {
  console.warn('==================================================');
  console.warn('  WARNING: DATABASE_URL not detected in environment.  ');
  console.warn('  Enabling In-Memory Mock Database Fallback.          ');
  console.warn('==================================================');
  useMock = true;
} else {
  const isProduction = process.env.NODE_ENV === 'production';
  pool = new Pool({
    connectionString: connectionString,
    ssl: isProduction || process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
    max: 10,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 2000,
  });

  pool.on('connect', () => {
    console.log('PostgreSQL database pool connected successfully');
  });

  pool.on('error', (err) => {
    console.error('Unexpected error on idle database client', err);
  });
}

// In-Memory Mock Query Runner
const mockQuery = async (text, params) => {
  const sql = text.replace(/\s+/g, ' ').trim();
  
  // 1. User Lookups
  if (sql.includes('SELECT * FROM users WHERE email =')) {
    const email = params[0];
    const rows = store.users.filter(u => u.email === email);
    return { rows };
  }

  // 2. User Insertions
  if (sql.includes('INSERT INTO users')) {
    const user = {
      id: crypto.randomUUID(),
      name: params[0],
      email: params[1],
      password_hash: params[2],
      student_id: params[3],
      phone: params[4],
      role: params[5],
      rating: 5.00,
      created_at: new Date()
    };
    store.users.push(user);
    return { rows: [user] };
  }

  // 3. Create Ride Offer
  if (sql.includes('INSERT INTO rides')) {
    const ride = {
      id: crypto.randomUUID(),
      rider_id: params[0],
      origin_name: params[1],
      origin_lat: parseFloat(params[2]),
      origin_lng: parseFloat(params[3]),
      destination_name: params[4],
      destination_lat: parseFloat(params[5]),
      destination_lng: parseFloat(params[6]),
      departure_time: params[7],
      vehicle_type: params[8],
      available_seats: parseInt(params[9]),
      helmet_provided: !!params[10],
      status: 'Scheduled',
      created_at: new Date()
    };
    store.rides.push(ride);
    return { rows: [ride] };
  }

  // 4. Get Active Rides (List matching)
  if (sql.includes('SELECT r.*, u.name as rider_name')) {
    // Return all scheduled/active rides with joined rider profiles
    const rows = store.rides
      .filter(r => ['Scheduled', 'Active'].includes(r.status))
      .map(r => {
        const u = store.users.find(user => user.id === r.rider_id) || {};
        return {
          ...r,
          rider_name: u.name || 'DIU Commuter',
          rider_rating: u.rating || 5.0,
          rider_phone: u.phone || '01700000000'
        };
      });
    return { rows };
  }

  // 5. Query specific ride
  if (sql.includes('SELECT rider_id, status FROM rides WHERE id =')) {
    const rideId = params[0];
    const ride = store.rides.find(r => r.id === rideId);
    return { rows: ride ? [ride] : [] };
  }
  if (sql.includes('SELECT r.*, u.name as rider_name') && sql.includes('WHERE r.id =')) {
    const rideId = params[0];
    const r = store.rides.find(ride => ride.id === rideId);
    if (!r) return { rows: [] };
    const u = store.users.find(user => user.id === r.rider_id) || {};
    const rideWithProfile = {
      ...r,
      rider_name: u.name || 'DIU Commuter',
      rider_rating: u.rating || 5.0,
      rider_phone: u.phone || '01700000000'
    };
    return { rows: [rideWithProfile] };
  }

  // 6. Ride request double check
  if (sql.includes('SELECT * FROM ride_requests WHERE ride_id =') && sql.includes('passenger_id =')) {
    const rideId = params[0];
    const passengerId = params[1];
    const match = store.ride_requests.filter(req => req.ride_id === rideId && req.passenger_id === passengerId);
    return { rows: match };
  }

  // 7. Request Count
  if (sql.includes('SELECT COUNT(*) FROM ride_requests WHERE ride_id =') && sql.includes("status = 'Accepted'")) {
    const rideId = params[0];
    const count = store.ride_requests.filter(req => req.ride_id === rideId && req.status === 'Accepted').length;
    return { rows: [{ count: count.toString() }] };
  }

  // 8. Create Request
  if (sql.includes('INSERT INTO ride_requests')) {
    const req = {
      id: crypto.randomUUID(),
      ride_id: params[0],
      passenger_id: params[1],
      status: 'Pending',
      dynamic_fare_share: parseFloat(params[2]),
      created_at: new Date()
    };
    store.ride_requests.push(req);
    return { rows: [req] };
  }

  // 9. Get accepted requests list
  if (sql.includes('SELECT id FROM ride_requests WHERE ride_id =') && sql.includes("status = 'Accepted'")) {
    const rideId = params[0];
    const rows = store.ride_requests.filter(req => req.ride_id === rideId && req.status === 'Accepted');
    return { rows };
  }

  // 10. Update Dynamic Fares
  if (sql.includes('UPDATE ride_requests SET dynamic_fare_share =') && sql.includes("status = 'Accepted'")) {
    const newFare = parseFloat(params[0]);
    const rideId = params[1];
    store.ride_requests.forEach(req => {
      if (req.ride_id === rideId && req.status === 'Accepted') {
        req.dynamic_fare_share = newFare;
      }
    });
    return { rows: [] };
  }

  // 11. Fetch Request for Respond Join Check
  if (sql.includes('SELECT rr.*, r.rider_id')) {
    const requestId = params[0];
    const req = store.ride_requests.find(r => r.id === requestId);
    if (!req) return { rows: [] };
    const r = store.rides.find(ride => ride.id === req.ride_id) || {};
    return {
      rows: [{
        ...req,
        rider_id: r.rider_id,
        available_seats: r.available_seats,
        ride_status: r.status
      }]
    };
  }

  // 12. Accept / Reject Request updates
  if (sql.includes("UPDATE ride_requests SET status = 'Accepted'")) {
    const requestId = params[0];
    const req = store.ride_requests.find(r => r.id === requestId);
    if (req) req.status = 'Accepted';
    return { rows: [] };
  }
  if (sql.includes("UPDATE ride_requests SET status = 'Rejected'")) {
    const requestId = params[0];
    const req = store.ride_requests.find(r => r.id === requestId);
    if (req) req.status = 'Rejected';
    return { rows: [] };
  }
  if (sql.includes('UPDATE rides SET available_seats = available_seats - 1')) {
    const rideId = params[0];
    const r = store.rides.find(ride => ride.id === rideId);
    if (r) r.available_seats = Math.max(0, r.available_seats - 1);
    return { rows: [] };
  }

  // 13. Update Ride Status
  if (sql.includes('UPDATE rides SET status = $1 WHERE id = $2')) {
    const status = params[0];
    const rideId = params[1];
    const r = store.rides.find(ride => ride.id === rideId);
    if (r) r.status = status;
    return { rows: [] };
  }
  if (sql.includes("UPDATE ride_requests SET status = 'Rejected' WHERE ride_id = $1 AND status = 'Pending'")) {
    const rideId = params[0];
    store.ride_requests.forEach(req => {
      if (req.ride_id === rideId && req.status === 'Pending') {
        req.status = 'Rejected';
      }
    });
    return { rows: [] };
  }

  // 14. Fetch Passenger request profiles
  if (sql.includes('SELECT rr.id as request_id')) {
    const rideId = params[0];
    const requests = store.ride_requests.filter(req => req.ride_id === rideId);
    const rows = requests.map(req => {
      const u = store.users.find(user => user.id === req.passenger_id) || {};
      return {
        request_id: req.id,
        status: req.status,
        dynamic_fare_share: req.dynamic_fare_share,
        passenger_id: req.passenger_id,
        name: u.name || 'DIU Passenger',
        phone: u.phone || '01700000000',
        rating: u.rating || 5.0
      };
    });
    return { rows };
  }

  return { rows: [] };
};

// Unified queries exporter
const query = async (text, params) => {
  if (useMock) {
    return await mockQuery(text, params);
  }
  return await pool.query(text, params);
};

module.exports = {
  query,
  pool: useMock ? {
    query: mockQuery,
    connect: async () => ({
      query: mockQuery,
      release: () => {}
    })
  } : pool,
};
