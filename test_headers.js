const https = require('https');

const orgId = "64c6cbb6554ec6e3e9ec51a7";
const assetId = "64d28c927e5821954062dab2";
const url = `https://widevine.gumlet.com/licence/${orgId}/${assetId}`;

function testUrl() {
  return new Promise((resolve) => {
    const req = https.request(url, { 
      method: 'POST',
      headers: {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Referer": "https://video.gumlet.io/",
        "Origin": "https://video.gumlet.io/"
      }
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        console.log(`Response: ${res.statusCode} - ${data}`);
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

testUrl();
