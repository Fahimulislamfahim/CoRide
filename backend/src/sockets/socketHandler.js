// Memory cache to throttle location broadcasts per ride ID (5 seconds limit)
const lastBroadcasts = new Map();
const THROTTLE_LIMIT_MS = 5000;

const registerSocketHandlers = (io) => {
  io.on('connection', (socket) => {
    console.log(`[Socket Connected] Socket ID: ${socket.id}`);

    // Join room for a specific ride
    socket.on('join_ride_room', (rideId) => {
      if (!rideId) return;
      socket.join(rideId);
      console.log(`[Socket Room] Socket ${socket.id} joined room: ${rideId}`);
      
      // Let others in the room know someone joined
      socket.to(rideId).emit('member_joined', { socketId: socket.id });
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
        // Silently skip to protect bandwidth and Render CPU usage
        return;
      }

      // Update broadcast timestamp
      lastBroadcasts.set(rideId, now);

      // Broadcast location to all users in the specific ride room
      io.to(rideId).emit('location_update', {
        lat,
        lng,
        speed: speed || 0,
        timestamp: now
      });
      
      console.log(`[Geospatial Update] Ride ${rideId}: Lat ${lat}, Lng ${lng} broadcasted`);
    });

    // Ride status changed signal
    socket.on('ride_status_changed', (data) => {
      const { rideId, status } = data;
      if (!rideId || !status) return;

      // Broadcast the state change to everyone in the room (e.g. passengers, map trackers)
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

  // Periodically clean up throttle cache
  setInterval(() => {
    const now = Date.now();
    for (const [rideId, timestamp] of lastBroadcasts.entries()) {
      if (now - timestamp > 60000) { // stale after 1 minute
        lastBroadcasts.delete(rideId);
      }
    }
  }, 60000);
};

module.exports = registerSocketHandlers;
