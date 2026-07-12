const crypto = require('crypto');
const https = require('https');

const orgId = "64c6cbb6554ec6e3e9ec51a7";
const assetId = "64d28c927e5821954062dab2";
const signSecret = "2c3d7d427565aa2a60f451355ec8451e";
const expires = Math.round(Date.now() / 1000) + 3600;

const stringToSign = `/${orgId}/${assetId}`;
const queryParams = `?expires=${expires}`;
const stringForTokenGeneration = `${stringToSign}${queryParams}`;

// Try 1: base64
const signSecretB64 = Buffer.from(signSecret, 'base64');
const signature1 = crypto.createHmac('sha1', signSecretB64).update(stringForTokenGeneration).digest('hex');

// Try 2: hex
const signSecretHex = Buffer.from(signSecret, 'hex');
const signature2 = crypto.createHmac('sha1', signSecretHex).update(stringForTokenGeneration).digest('hex');

// Try 3: utf8
const signature3 = crypto.createHmac('sha1', signSecret).update(stringForTokenGeneration).digest('hex');

// Try 4: sha256 base64
const signature4 = crypto.createHmac('sha256', signSecretB64).update(stringForTokenGeneration).digest('hex');

console.log("1. SHA1 (base64):", signature1);
console.log("2. SHA1 (hex):", signature2);
console.log("3. SHA1 (utf8):", signature3);
console.log("4. SHA256 (base64):", signature4);

const urls = [
  `https://widevine.gumlet.com/licence/${orgId}/${assetId}?token=${signature1}&expires=${expires}`,
  `https://widevine.gumlet.com/licence/${orgId}/${assetId}?token=${signature2}&expires=${expires}`,
  `https://widevine.gumlet.com/licence/${orgId}/${assetId}?token=${signature3}&expires=${expires}`,
  `https://widevine.gumlet.com/licence/${orgId}/${assetId}?token=${signature4}&expires=${expires}`
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
  for (let i = 0; i < urls.length; i++) {
    console.log(`Testing URL ${i+1}...`);
    await testUrl(urls[i], i);
  }
}

test();
