const db = require('../config/db');

const getHubs = async (req, res) => {
  try {
    const result = await db.query('SELECT * FROM hubs ORDER BY name ASC');
    res.json(result.rows);
  } catch (err) {
    console.error('Get hubs error:', err);
    res.status(500).json({ error: 'Failed to retrieve hubs.' });
  }
};

module.exports = {
  getHubs,
};