const jwt = require('jsonwebtoken');
const { JWT_SECRET } = require('../middlewares/authMiddleware');

// Cache to store last known location for active rides: { rideId: { lat, lng, speed, timestamp } }
const lastKnownLocations = new Map();

// Memory cache to throttle location broadcasts per ride ID (5 seconds limit)
const lastBroadcasts = new Map();
const THROTTLE_LIMIT_MS = 5000;

const registerSocketHandlers = (io) => {
  // 1. Socket.io Connection Handshake Middleware for Strict JWT Authentication
  io.use((socket, next) => {
    const token = socket.handshake.auth.token;
    
    if (!token) {
      console.warn(`[Socket Connection Rejected] Connection attempt without token.`);
      return next(new Error('Authentication error: Token required.'));
    }

    try {
      const decoded = jwt.verify(token, JWT_SECRET);
      
      // Strict academic domain check on socket connect
      if (!decoded.email || !decoded.email.endsWith('@diu.edu.bd')) {
        console.warn(`[Socket Connection Rejected] Non-DIU email domain: ${decoded.email}`);
        return next(new Error('Authentication error: Non-DIU email rejected.'));
      }
      
      socket.user = decoded; // Store decoded session on the socket object
      next();
    } catch (err) {
      console.warn(`[Socket Connection Rejected] Invalid token: ${err.message}`);
      return next(new Error('Authentication error: Invalid or expired token.'));
    }
  });

  io.on('connection', (socket) => {
    console.log(`[Socket Connected] Socket ID: ${socket.id} | User: ${socket.user.email}`);

    // Join room for a specific ride
    socket.on('join_ride_room', (rideId) => {
      if (!rideId) return;
      socket.join(rideId);
      console.log(`[Socket Room] Socket ${socket.id} joined room: ${rideId}`);
      
      // Send last known location immediately from cache (resolves embankment dropout blackouts)
      const cachedLoc = lastKnownLocations.get(rideId);
      if (cachedLoc) {
        socket.emit('location_update', cachedLoc);
        console.log(`[Socket Room] Immediately sent cached location for ride ${rideId} to socket ${socket.id}`);
      }
      
      // Let others in the room know someone joined
      socket.to(rideId).emit('member_joined', { socketId: socket.id, email: socket.user.email });
    });

    // Throttled geospatial broadcast
    socket.on('update_location', (data) => {
      const { rideId, lat, lng, speed } = data;
      if (!rideId || lat === undefined || lng === undefined) {
        return;
      }

      const now = Date.now();
      const lastBroadcast = lastBroadcasts.get(rideId) || 0;

      // Server-side safety throttle check
      if (now - lastBroadcast < THROTTLE_LIMIT_MS) {
        return;
      }

      // Update broadcast timestamp and cache last known coordinates
      lastBroadcasts.set(rideId, now);
      
      const locationData = {
        lat,
        lng,
        speed: speed || 0,
        timestamp: now
      };
      
      lastKnownLocations.set(rideId, locationData);

      // Broadcast location to all users in the specific ride room
      io.to(rideId).emit('location_update', locationData);
      
      console.log(`[Geospatial Update] Ride ${rideId}: Lat ${lat}, Lng ${lng} cached and broadcasted`);
    });

    // Ride status changed signal
    socket.on('ride_status_changed', (data) => {
      const { rideId, status } = data;
      if (!rideId || !status) return;

      // Clean up cached location when the ride terminates
      if (['Completed', 'Cancelled'].includes(status)) {
        lastKnownLocations.delete(rideId);
        lastBroadcasts.delete(rideId);
        console.log(`[Cache Cleanup] Cleared location caches for ended/cancelled Ride ID: ${rideId}`);
      }

      // Broadcast the state change to everyone in the room
      io.to(rideId).emit('status_update', {
        status,
        timestamp: Date.now()
      });

      console.log(`[Ride State Sync] Ride ${rideId} changed to: ${status}`);
    });

    // Clean up on disconnect
    socket.on('disconnect', () => {
      console.log(`[Socket Disconnected] Socket ID: ${socket.id}`);
    });
  });

  // Periodically clean up stale location cache
  setInterval(() => {
    const now = Date.now();
    for (const [rideId, timestamp] of lastBroadcasts.entries()) {
      if (now - timestamp > 300000) { // stale after 5 minutes of no activity
        lastKnownLocations.delete(rideId);
        lastBroadcasts.delete(rideId);
      }
    }
  }, 120000);
};

module.exports = registerSocketHandlers;
