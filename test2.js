const crypto = require('crypto');
const https = require('https');

const orgId = "64c6cbb6554ec6e3e9ec51a7";
const assetId = "64d28c927e5821954062dab2";
const signSecret = "2c3d7d427565aa2a60f451355ec8451e";
const expires = Math.round(Date.now() / 1000) + 3600;

const stringToSign = `/${orgId}/${assetId}${expires}`;

const signSecretB64 = Buffer.from(signSecret, 'base64');
const signTokenBase64 = crypto.createHmac('sha256', signSecretB64).update(stringToSign).digest('base64');
const signTokenHex = crypto.createHmac('sha256', signSecretB64).update(stringToSign).digest('hex');

const signTokenBase64Encoded = encodeURIComponent(signTokenBase64);

const urls = [
  `https://widevine.gumlet.com/licence/${orgId}/${assetId}?token=${signTokenBase64Encoded}&expires=${expires}`,
  `https://widevine.gumlet.com/licence/${orgId}/${assetId}?token=${signTokenHex}&expires=${expires}`,
  `https://widevine.gumlet.com/licence/${orgId}/${assetId}?token=${encodeURIComponent(crypto.createHmac('sha256', signSecret).update(stringToSign).digest('base64'))}&expires=${expires}`
];

function testUrl(url, index) {
  return new Promise((resolve) => {
    const req = https.request(url, { method: 'POST' }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        console.log(`Response ${index+1} (base64/hex): ${res.statusCode} - ${data}`);
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
