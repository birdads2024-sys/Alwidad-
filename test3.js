const crypto = require('crypto');
const https = require('https');

const orgId = "64c6cbb6554ec6e3e9ec51a7";
const assetId = "64d28c927e5821954062dab2";
const signSecret = "2c3d7d427565aa2a60f451355ec8451e";
const expires = Math.round(Date.now() / 1000) + 3600;

// stringToSign = /orgId/assetId
// update(stringToSign + expires)
const payload = `/${orgId}/${assetId}${expires}`;

const signSecretB64 = Buffer.from(signSecret, 'base64');
const signSecretHex = Buffer.from(signSecret, 'hex');

const signatures = [
  // 1. sha256, base64 key, base64 out
  crypto.createHmac('sha256', signSecretB64).update(payload).digest('base64'),
  // 2. sha256, utf8 key, base64 out
  crypto.createHmac('sha256', signSecret).update(payload).digest('base64'),
  // 3. sha256, hex key, base64 out
  crypto.createHmac('sha256', signSecretHex).update(payload).digest('base64'),
  // 4. sha256, hex key, hex out
  crypto.createHmac('sha256', signSecretHex).update(payload).digest('hex'),
  // 5. sha1, hex key, hex out
  crypto.createHmac('sha1', signSecretHex).update(payload).digest('hex'),
  // 6. sha1, utf8 key, hex out
  crypto.createHmac('sha1', signSecret).update(payload).digest('hex')
];

function testUrl(url, index) {
  return new Promise((resolve) => {
    const req = https.request(url, { method: 'POST' }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        console.log(`Response ${index+1}: ${res.statusCode} - ${data}`);
        resolve();
      });
    });
    req.on('error', (e) => {
      console.log(`Error ${index+1}: ${e.message}`);
      resolve();
    });
    req.write('dummy_challenge');
    req.end();
  });
}

async function test() {
  for (let i = 0; i < signatures.length; i++) {
    const url = `https://widevine.gumlet.com/licence/${orgId}/${assetId}?token=${encodeURIComponent(signatures[i])}&expires=${expires}`;
    console.log(`Testing URL ${i+1}...`);
    await testUrl(url, i);
  }
}

test();
