const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');
require('dotenv').config();

const db = require('./config/db');
const authRoutes = require('./routes/authRoutes');
const rideRoutes = require('./routes/rideRoutes');
const { apiLimiter } = require('./middlewares/rateLimiter');
const registerSocketHandlers = require('./sockets/socketHandler');

const app = express();
const server = http.createServer(app);

// Initialize Socket.io with permissive CORS options for cross-platform Flutter clients
const io = socketIo(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST', 'PATCH'],
  }
});

// Middleware
app.use(cors());
app.use(express.json());

// Global API rate limiting
app.use('/api/', apiLimiter);

// Database connection health check on startup
db.pool.query('SELECT NOW()', (err, res) => {
  if (err) {
    console.error('Critical: Database initialization failed!', err.stack);
  } else {
    console.log('Database connection initialized successfully at:', res.rows[0].now);
  }
});

// Render Free Tier Keep-Alive Endpoint
// Call this endpoint every 12 minutes using cron or external scheduler (e.g. UptimeRobot)
app.get('/ping', (req, res) => {
  const diagnostics = {
    status: 'healthy',
    message: 'CoRide backend is active and listening.',
    uptime: `${Math.round(process.uptime())} seconds`,
    timestamp: new Date().toISOString(),
    node_version: process.version,
    memory_usage: `${Math.round(process.memoryUsage().heapUsed / 1024 / 1024)} MB`
  };
  res.status(200).json(diagnostics);
});

// API Routes
app.use('/api/auth', authRoutes);
app.use('/api/rides', rideRoutes);

// Global Error Handler
app.use((err, req, res, next) => {
  console.error('[Global Error Middleware]', err.stack);
  res.status(err.status || 500).json({
    error: err.message || 'Internal server error'
  });
});

// Socket.io handlers
registerSocketHandlers(io);

// Server startup
const PORT = process.env.PORT || 5000;
server.listen(PORT, '0.0.0.0', () => {
  console.log(`====================================================`);
  console.log(`  CoRide Server Running on Port: ${PORT}`);
  console.log(`  Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`====================================================`);
});

// Graceful Shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM signal received: closing HTTP server');
  server.close(() => {
    console.log('HTTP server closed');
    db.pool.end(() => {
      console.log('Database pool connection closed');
      process.exit(0);
    });
  });
});
