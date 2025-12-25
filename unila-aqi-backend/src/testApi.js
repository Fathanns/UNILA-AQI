const axios = require('axios');

async function testApi() {
  const baseUrl = 'http://localhost:5000/api';
  
  console.log('🧪 Testing API Endpoints...\n');
  
  try {
    // Test 1: Public endpoints
    console.log('1. Testing public endpoints...');
    const statusRes = await axios.get(`${baseUrl}/test/status`);
    console.log(`   Status: ${JSON.stringify(statusRes.data.data)}`);
    
    // Test 2: Get buildings
    console.log('\n2. Testing buildings endpoint...');
    const buildingsRes = await axios.get(`${baseUrl}/test/buildings`);
    console.log(`   Buildings count: ${buildingsRes.data.count}`);
    
    // Test 3: Get rooms
    console.log('\n3. Testing rooms endpoint...');
    const roomsRes = await axios.get(`${baseUrl}/test/rooms`);
    console.log(`   Rooms count: ${roomsRes.data.count}`);
    
    // Test 4: Auth check
    console.log('\n4. Testing auth endpoint...');
    const authRes = await axios.get(`${baseUrl}/auth/check-admin`);
    console.log(`   Admin registered: ${authRes.data.isRegistered}`);
    
    console.log('\n✅ All API tests passed!');
  } catch (error) {
    console.error('❌ API Test failed:', error.message);
  }
}

testApi();