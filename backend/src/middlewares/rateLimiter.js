const rateLimit = require('express-rate-limit');

// Rate limiter to prevent DDoS during rush hours (8:00 AM - 8:30 AM & 4:30 PM - 5:15 PM)
// Configured to be lightweight for Neon/Render Free Tier
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 150, // Limit each IP to 150 requests per window
  standardHeaders: true, // Return rate limit info in the `RateLimit-*` headers
  legacyHeaders: false, // Disable the `X-RateLimit-*` headers
  message: {
    error: 'Too many requests from this IP. Please try again after 15 minutes.',
  },
  handler: (req, res, next, options) => {
    // Log rate limit hits during rush hours
    const now = new Date();
    const hours = now.getHours();
    const minutes = now.getMinutes();
    
    // Check if within rush hours (8:00-8:30 AM or 4:30-5:15 PM)
    const isMorningRush = (hours === 8 && minutes <= 30);
    const isEveningRush = (hours === 16 && minutes >= 30) || (hours === 17 && minutes <= 15);
    
    if (isMorningRush || isEveningRush) {
      console.warn(`[RUSH HOUR RATE LIMIT HIT] IP: ${req.ip} triggered rate limiting at ${hours}:${minutes}`);
    }
    
    res.status(options.statusCode).send(options.message);
  }
});

// A more strict limiter specifically for login/register endpoints to prevent brute force
const authLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour window
  max: 10, // Start blocking after 10 requests
  message: {
    error: 'Too many authentication attempts. Please try again after an hour.',
  },
  standardHeaders: true,
  legacyHeaders: false,
});

module.exports = {
  apiLimiter,
  authLimiter,
};
