require('dotenv').config();

const config = {
  port: process.env.PORT || 3000,
  aiApiUrl: process.env.AI_API_URL || null,
  wsUrl: process.env.WS_URL || null,
  aiApiKey: process.env.AI_API_KEY || null,
};

module.exports = config;
