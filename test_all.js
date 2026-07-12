const crypto = require('crypto');
const https = require('https');

const orgId1 = "64c6cbb6554ec6e3e9ec51a7"; // DRM Credentials Page
const orgId2 = "64c6cbba47b2326c9b8f29d9"; // Video URL

const assetId = "64d28c927e5821954062dab2";
const signSecret = "2c3d7d427565aa2a60f451355ec8451e";
const expires = Math.round(Date.now() / 1000) + 3600;

function getPermutations(orgId) {
  const p1 = `/${orgId}/${assetId}${expires}`;
  const p2 = `/${orgId}/${assetId}?expires=${expires}`;
  const p3 = `/${orgId}/${assetId}`;
  
  const signSecretB64 = Buffer.from(signSecret, 'base64');
  const signSecretHex = Buffer.from(signSecret, 'hex');
  const signSecretUtf8 = signSecret;
  
  const keys = [signSecretB64, signSecretHex, signSecretUtf8];
  const payloads = [p1, p2, p3];
  const algos = ['sha256', 'sha1', 'md5'];
  const outputs = ['base64', 'hex'];
  
  let urls = [];
  
  for (let key of keys) {
    for (let payload of payloads) {
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

let allUrls = [...getPermutations(orgId1), ...getPermutations(orgId2)];
console.log(`Total permutations to test: ${allUrls.length}`);

function testUrl(url, index) {
  return new Promise((resolve) => {
    const req = https.request(url, { method: 'POST' }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        if (res.statusCode !== 400) {
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
  console.log("Done testing all permutations!");
}

test();
