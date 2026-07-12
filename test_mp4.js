const crypto = require('crypto');
const https = require('https');

const secret = "2c3d7d427565aa2a60f451355ec8451e";
const playBackUrl = "https://video.gumlet.io/64c6cbba47b2326c9b8f29d9/64d28c927e5821954062dab2/main.mp4";
const expires = Math.round(Date.now() / 1000) + 3600;

// Gumlet docs say: secretBuffer = Buffer.from(secret, 'base64'); 
// But the secret is hex! Let's try both.
const secretHex = Buffer.from(secret, 'hex');
const secretB64 = Buffer.from(secret, 'base64');
const secretUtf8 = secret;

const path = playBackUrl.slice(23); // "64c6cbba47b2326c9b8f29d9/64d28c927e5821954062dab2/main.mp4"
const stringToSign = path + String(expires);

const keys = [secretHex, secretB64, secretUtf8];

function testUrl(url, index) {
  return new Promise((resolve) => {
    https.get(url, (res) => {
      console.log(`Response ${index+1}: ${res.statusCode}`);
      resolve();
    }).on('error', (e) => {
      resolve();
    });
  });
}

async function test() {
  let i = 0;
  for (let key of keys) {
    const signature = crypto.createHmac('sha1', key).update(stringToSign).digest('hex');
    const url = `${playBackUrl}?token=${signature}&expires=${expires}`;
    console.log(`Testing: ${url}`);
    await testUrl(url, i++);
  }
}

test();
