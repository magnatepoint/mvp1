// Generate Apple OAuth Client Secret
// Run: node generate-apple-secret.js

const jwt = require('jsonwebtoken');
const fs = require('fs');

// Replace these with your values:
const TEAM_ID = 'YOUR_TEAM_ID'; // Your Apple Developer Team ID (e.g., ABC123XYZ) - NOT the bundle ID!
// Find it at: https://developer.apple.com/account (shown in top right)
const CLIENT_ID = 'MagnatePoint.ios-monytix'; // Your Service ID or App ID
const KEY_ID = 'T3Y839CT78'; // From the key filename (AuthKey_T3Y839CT78.p8)
const PRIVATE_KEY_PATH = './AuthKey_T3Y839CT78.p8'; // Path to downloaded .p8 file

const privateKey = fs.readFileSync(PRIVATE_KEY_PATH);

const token = jwt.sign(
  {
    iss: TEAM_ID,
    iat: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + 86400 * 180, // 6 months
    aud: 'https://appleid.apple.com',
    sub: CLIENT_ID,
  },
  privateKey,
  {
    algorithm: 'ES256',
    keyid: KEY_ID,
  }
);

console.log('Apple OAuth Client Secret:');
console.log(token);
console.log('\nCopy this and paste it into Supabase "Secret Key (for OAuth)" field');

