const crypto = require('crypto');
const https = require('https');

const hexSecret = "2c3d7d427565aa2a60f451355ec8451e";
const orgId = "64c6cbb6554ec6e3e9ec51a7";
const assetId = "64d28c927e5821954062dab2";
const expires = Math.round(Date.now() / 1000) + 3600;

// Convert HEX to Base64
const secretBytes = Buffer.from(hexSecret, 'hex');
const base64Secret = secretBytes.toString('base64');
console.log("Base64 Secret: ", base64Secret);

// Then use Buffer.from(..., 'base64')
const key = Buffer.from(base64Secret, 'base64');

// /${orgId}/${assetId}?expires=...
const stringToSign = `/${orgId}/${assetId}?expires=${expires}`;
console.log("String to sign: ", stringToSign);

// HMAC SHA1
const hashHex = crypto.createHmac('sha1', key).update(stringToSign).digest('hex');
const hashB64 = crypto.createHmac('sha1', key).update(stringToSign).digest('base64');

// What if stringToSign does NOT have the ?expires=... but just the value?
const stringToSign2 = `/${orgId}/${assetId}${expires}`;
const hash2Hex = crypto.createHmac('sha1', key).update(stringToSign2).digest('hex');
const hash2B64 = crypto.createHmac('sha1', key).update(stringToSign2).digest('base64');

const urls = [
  `https://widevine.gumlet.com/licence/${orgId}/${assetId}?token=${hashHex}&expires=${expires}`,
  `https://widevine.gumlet.com/licence/${orgId}/${assetId}?token=${encodeURIComponent(hashB64)}&expires=${expires}`,
  `https://widevine.gumlet.com/licence/${orgId}/${assetId}?token=${hashB64}&expires=${expires}`,
  `https://widevine.gumlet.com/licence/${orgId}/${assetId}?token=${hash2Hex}&expires=${expires}`,
  `https://widevine.gumlet.com/licence/${orgId}/${assetId}?token=${encodeURIComponent(hash2B64)}&expires=${expires}`
];

function testUrl(url, index) {
  return new Promise((resolve) => {
    const req = https.request(url, { method: 'POST' }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        console.log(`URL ${index+1} response: ${res.statusCode} - ${data}`);
        resolve();
      });
    });
    req.on('error', (e) => {
      resolve();
    });
    req.write('dummy_challenge');
    req.end();
  });
}

async function run() {
  for (let i = 0; i < urls.length; i++) {
    await testUrl(urls[i], i);
  }
}
run();
