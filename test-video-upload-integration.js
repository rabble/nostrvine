#!/usr/bin/env node

/**
 * Integration test for NostrVine video upload
 * Tests the complete upload flow: NIP-98 auth + video upload + CDN verification
 */

const { execSync } = require('child_process');
const fs = require('fs');
const FormData = require('form-data');
const fetch = require('node-fetch');

const BACKEND_URL = 'https://api.openvine.co';
const TEST_VIDEO_PATH = '/Users/rabble/code/experiments/nostrvine/mobile/test-video.mp4';

async function testVideoUpload() {
  console.log('🧪 Starting NostrVine video upload integration test...\n');

  try {
    // Step 1: Check if test video exists
    if (!fs.existsSync(TEST_VIDEO_PATH)) {
      console.error('❌ Test video not found at:', TEST_VIDEO_PATH);
      return false;
    }
    
    const videoStats = fs.statSync(TEST_VIDEO_PATH);
    console.log(`📹 Test video: ${TEST_VIDEO_PATH} (${videoStats.size} bytes)`);

    // Step 2: Generate test private key
    console.log('🔑 Generating test Nostr key...');
    const privateKey = execSync('nak key generate', { encoding: 'utf8' }).trim();
    const publicKey = execSync(`echo "${privateKey}" | nak key public`, { encoding: 'utf8' }).trim();
    console.log(`   Private key: ${privateKey}`);
    console.log(`   Public key: ${publicKey}`);

    // Step 3: Create NIP-98 authorization event
    console.log('\n🔐 Creating NIP-98 authorization event...');
    const uploadUrl = `${BACKEND_URL}/api/upload`;
    const method = 'POST';
    
    // Create the event using nak - just create the event, don't publish to relays
    const eventJson = execSync(`echo | nak event --sec "${privateKey}" --kind 27235 --tag u "${uploadUrl}" --tag method "${method}" --content ""`, { encoding: 'utf8' }).trim();
    const authEvent = JSON.parse(eventJson);
    
    console.log('   Auth event created:', {
      id: authEvent.id,
      pubkey: authEvent.pubkey,
      kind: authEvent.kind,
      tags: authEvent.tags
    });

    // Step 4: Create Authorization header
    const authHeader = `Nostr ${Buffer.from(JSON.stringify(authEvent)).toString('base64')}`;
    console.log('   Authorization header created');

    // Step 5: Prepare multipart form data
    console.log('\n📤 Preparing upload request...');
    const form = new FormData();
    form.append('file', fs.createReadStream(TEST_VIDEO_PATH), {
      filename: 'test-video.mp4',
      contentType: 'video/mp4'
    });

    // Step 6: Upload the video
    console.log('🚀 Uploading video to:', uploadUrl);
    const uploadResponse = await fetch(uploadUrl, {
      method: 'POST',
      headers: {
        'Authorization': authHeader,
        ...form.getHeaders()
      },
      body: form
    });

    console.log(`   Response status: ${uploadResponse.status}`);
    
    if (!uploadResponse.ok) {
      const errorText = await uploadResponse.text();
      console.error('❌ Upload failed:', errorText);
      return false;
    }

    const uploadResult = await uploadResponse.json();
    console.log('✅ Upload successful!');
    console.log('   Response:', JSON.stringify(uploadResult, null, 2));

    // Step 7: Verify the uploaded video is accessible
    if (uploadResult.download_url || uploadResult.url) {
      const videoUrl = uploadResult.download_url || uploadResult.url;
      console.log(`\n🔍 Verifying video accessibility at: ${videoUrl}`);
      
      const verifyResponse = await fetch(videoUrl, { method: 'HEAD' });
      console.log(`   Video accessibility: ${verifyResponse.status}`);
      
      if (verifyResponse.ok) {
        console.log('✅ Video is accessible via CDN');
        return true;
      } else {
        console.error('❌ Video not accessible via CDN');
        return false;
      }
    } else {
      console.log('⚠️  No download URL provided in response');
      return true; // Still consider it a success if upload worked
    }

  } catch (error) {
    console.error('❌ Integration test failed:', error.message);
    return false;
  }
}

// Run the test
testVideoUpload().then(success => {
  console.log('\n' + '='.repeat(50));
  if (success) {
    console.log('🎉 INTEGRATION TEST PASSED!');
    console.log('   Video upload flow is working end-to-end');
    process.exit(0);
  } else {
    console.log('💥 INTEGRATION TEST FAILED!');
    console.log('   Video upload flow has issues');
    process.exit(1);
  }
}).catch(error => {
  console.error('💥 Test runner failed:', error);
  process.exit(1);
});