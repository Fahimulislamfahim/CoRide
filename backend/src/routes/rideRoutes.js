const express = require('express');
const router = express.Router();
const rideController = require('../controllers/rideController');
const { verifyToken } = require('../middlewares/authMiddleware');

// All ride routes are protected by JWT verification
router.use(verifyToken);

// Offer a ride
router.post('/offer', rideController.createRide);

// Get available rides
router.get('/active', rideController.getActiveRides);

// Request a ride
router.post('/request', rideController.requestRide);

// Accept/reject a ride request
router.post('/respond', rideController.respondToRequest);

// Update ride status (Active, Completed, Cancelled)
router.patch('/status', rideController.updateRideStatus);

// Get details of a specific ride (for active rooms)
router.get('/:id', rideController.getRideDetails);

module.exports = router;
