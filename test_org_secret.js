const crypto = require('crypto');
const https = require('https');

const orgId = "64c6cbb6554ec6e3e9ec51a7";
const assetId = "64d28c927e5821954062dab2";
const expires = Math.round(Date.now() / 1000) + 3600;

function generateUrls() {
  const payloads = [
    `/licence/${orgId}/${assetId}${expires}`,
    `/licence/${orgId}/${assetId}?expires=${expires}`,
    `/${orgId}/${assetId}${expires}`,
    `/${orgId}/${assetId}?expires=${expires}`
  ];
  
  // What if the secret is just orgId?
  const secretHex = Buffer.from(orgId, 'hex');
  const secretUtf8 = orgId;
  
  const algos = ['sha1', 'sha256'];
  const keys = [secretHex, secretUtf8];
  const outputs = ['hex', 'base64'];

  let urls = [];
  
  for (let payload of payloads) {
    for (let key of keys) {
      for (let algo of algos) {
        for (let out of outputs) {
          try {
            const signature = crypto.createHmac(algo, key).update(payload).digest(out);
            urls.push(`https://widevine.gumlet.com/licence/${orgId}/${assetId}?token=${encodeURIComponent(signature)}&expires=${expires}`);
          } catch(e) {}
        }
      }
    }
  }
  return urls;
}

const allUrls = generateUrls();

function testUrl(url, index) {
  return new Promise((resolve) => {
    const req = https.request(url, { method: 'POST' }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        if (res.statusCode !== 400 && res.statusCode !== 401) {
           console.log(`!!! SUCCESS !!! Response ${index+1}: ${res.statusCode} - ${data} for URL: ${url}`);
        }
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
  for (let i = 0; i < allUrls.length; i++) {
    await testUrl(allUrls[i], i);
  }
  console.log("Done testing orgId as secret!");
}

test();
