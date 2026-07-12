const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const db = require('../config/db');
const { JWT_SECRET } = require('../middlewares/authMiddleware');

// User Registration
const register = async (req, res) => {
  const { name, email, password, student_id, phone, role } = req.body;

  // Basic validation
  if (!name || !email || !password || !student_id || !phone || !role) {
    return res.status(400).json({ error: 'All fields are required.' });
  }

  // Strict email check
  if (!email.endsWith('@diu.edu.bd')) {
    return res.status(400).json({ error: 'Registration is restricted to Daffodil International University emails (@diu.edu.bd) only.' });
  }

  // Role validation
  if (!['Rider', 'Passenger', 'Both'].includes(role)) {
    return res.status(400).json({ error: 'Invalid role. Must be Rider, Passenger, or Both.' });
  }

  try {
    // Check if user already exists
    const userCheck = await db.query('SELECT * FROM users WHERE email = $1', [email]);
    if (userCheck.rows.length > 0) {
      return res.status(409).json({ error: 'A user with this DIU email already exists.' });
    }

    // Hash password
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(password, salt);

    // Insert user
    const insertQuery = `
      INSERT INTO users (name, email, password_hash, student_id, phone, role)
      VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING id, name, email, student_id, phone, role, rating, created_at
    `;
    const result = await db.query(insertQuery, [name, email, passwordHash, student_id, phone, role]);
    const user = result.rows[0];

    // Generate JWT
    const token = jwt.sign(
      { id: user.id, name: user.name, email: user.email, role: user.role },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.status(201).json({
      message: 'Registration successful',
      token,
      user,
    });
  } catch (err) {
    console.error('Registration error:', err);
    res.status(500).json({ error: 'Internal server error during registration.' });
  }
};

// User Login
const login = async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ error: 'Email and password are required.' });
  }

  try {
    // Find user
    const result = await db.query('SELECT * FROM users WHERE email = $1', [email]);
    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid email or password.' });
    }

    const user = result.rows[0];

    // Verify password
    const isMatch = await bcrypt.compare(password, user.password_hash);
    if (!isMatch) {
      return res.status(401).json({ error: 'Invalid email or password.' });
    }

    // Generate JWT
    const token = jwt.sign(
      { id: user.id, name: user.name, email: user.email, role: user.role },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    // Remove password hash from response
    delete user.password_hash;

    res.json({
      message: 'Login successful',
      token,
      user,
    });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ error: 'Internal server error during login.' });
  }
};

module.exports = {
  register,
  login,
};
