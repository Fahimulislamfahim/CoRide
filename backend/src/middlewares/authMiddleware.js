const jwt = require('jsonwebtoken');
require('dotenv').config();

const JWT_SECRET = process.env.JWT_SECRET || 'coride_diu_super_secret_key';

const verifyToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  if (!authHeader) {
    return res.status(401).json({ error: 'Access denied. No authorization header provided.' });
  }

  const tokenParts = authHeader.split(' ');
  if (tokenParts.length !== 2 || tokenParts[0] !== 'Bearer') {
    return res.status(401).json({ error: 'Access denied. Invalid authorization format. Use: Bearer <token>' });
  }

  const token = tokenParts[1];

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    
    // Strict verification of DIU email domain in JWT payload
    if (!decoded.email || !decoded.email.endsWith('@diu.edu.bd')) {
      return res.status(403).json({ error: 'Access forbidden. Non-DIU email domain rejected.' });
    }
    
    req.user = decoded;
    next();
  } catch (err) {
    console.error('JWT Verification Error:', err.message);
    return res.status(401).json({ error: 'Access denied. Invalid or expired token.' });
  }
};

module.exports = {
  verifyToken,
  JWT_SECRET,
};
