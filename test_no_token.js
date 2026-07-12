const https = require('https');

const url1 = "https://widevine.gumlet.com/licence/64c6cbb6554ec6e3e9ec51a7";
const url2 = "https://widevine.gumlet.com/licence/64c6cbb6554ec6e3e9ec51a7/64d28c927e5821954062dab2";
const url3 = "https://widevine.gumlet.com/licence/64c6cbba47b2326c9b8f29d9/64d28c927e5821954062dab2";

const urls = [url1, url2, url3];

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
