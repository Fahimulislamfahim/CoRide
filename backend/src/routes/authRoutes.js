const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const { authLimiter } = require('../middlewares/rateLimiter');

// Registration Route with brute-force protection rate limiter
router.post('/register', authLimiter, authController.register);

// Login Route
router.post('/login', authLimiter, authController.login);

module.exports = router;
