const mongoose = require('mongoose');
require('dotenv').config();

async function checkDatabase() {
  try {
    console.log('🔍 Checking MongoDB Atlas Connection...');
    
    // Check if MONGODB_URI is set
    if (!process.env.MONGODB_URI) {
      throw new Error('MONGODB_URI is not set in environment variables');
    }
    
    // Mask password for logging (before connection attempt)
    const uri = process.env.MONGODB_URI;
    const maskedUri = uri.replace(/:[^:@]*@/, ':****@');
    console.log(`Using connection string: ${maskedUri}`);
    
    // Connect with timeout
    await mongoose.connect(process.env.MONGODB_URI, {
      serverSelectionTimeoutMS: 10000, // 10 seconds timeout
      socketTimeoutMS: 45000, // 45 seconds socket timeout
    });
    
    console.log('✅ Connected to MongoDB Atlas');
    console.log(`📍 Host: ${mongoose.connection.host}`);
    console.log(`📊 Database: ${mongoose.connection.db.databaseName}`);
    console.log(`📡 State: ${mongoose.connection.readyState === 1 ? 'Connected' : 'Disconnected'}`);
    
    // List all collections
    console.log('\n📚 Collections:');
    const collections = await mongoose.connection.db.listCollections().toArray();
    
    if (collections.length === 0) {
      console.log('   No collections found in database');
    } else {
      collections.forEach(col => {
        console.log(`   - ${col.name}`);
      });
    }
    
    // Count documents in each collection (including dynamically found ones)
    console.log('\n📊 Document Counts:');
    
    // Use the actual collection names we found, or fall back to expected ones
    const collectionNames = collections.length > 0 
      ? collections.map(col => col.name)
      : ['buildings', 'rooms', 'users', 'iotdevices', 'sensordatas'];
    
    for (const colName of collectionNames) {
      try {
        const count = await mongoose.connection.db.collection(colName).countDocuments();
        console.log(`   ${colName}: ${count} documents`);
      } catch (err) {
        if (err.codeName === 'NamespaceNotFound') {
          console.log(`   ${colName}: Collection doesn't exist`);
        } else {
          console.log(`   ${colName}: Error - ${err.message}`);
        }
      }
    }
    
    // Additional info with safer version checking
    console.log('\n🔧 Additional Info:');
    console.log(`   Mongoose version: ${mongoose.version}`);
    
    // Safer way to get MongoDB driver version
    try {
      const client = mongoose.connection.getClient();
      let driverVersion = 'Unknown';
      
      // Try different ways to get driver version
      if (client && client.options && client.options.metadata && client.options.metadata.driver) {
        driverVersion = client.options.metadata.driver.version;
      } else if (client && client.options && client.options.driverInfo) {
        driverVersion = client.options.driverInfo.version || 'Available in driverInfo';
      } else if (client && client.topology && client.topology.s && client.topology.s.options) {
        driverVersion = client.topology.s.options.metadata?.driver?.version || 'Available in topology';
      }
      
      console.log(`   MongoDB driver version: ${driverVersion}`);
    } catch (driverErr) {
      console.log(`   MongoDB driver version: Could not retrieve (${driverErr.message})`);
    }
    
    // Get server info
    try {
      const serverStatus = await mongoose.connection.db.admin().serverStatus();
      console.log(`   MongoDB server version: ${serverStatus.version}`);
      console.log(`   MongoDB storage engine: ${serverStatus.storageEngine?.name || 'Unknown'}`);
    } catch (statusErr) {
      console.log(`   MongoDB server info: Could not retrieve (${statusErr.message})`);
    }
    
    // Close connection gracefully
    await mongoose.disconnect();
    console.log('\n🔌 Disconnected from MongoDB');
    
    process.exit(0);
  } catch (error) {
    console.error('\n❌ Connection Error:', error.message);
    
    // More detailed error analysis
    if (error.name === 'MongooseServerSelectionError') {
      console.error('   This is a connection error. Possible causes:');
      console.error('   - Network connectivity issues');
      console.error('   - Incorrect connection string');
      console.error('   - IP not whitelisted in Atlas');
      console.error('   - Database cluster is paused or down');
    } else if (error.name === 'MongooseError') {
      console.error('   Mongoose-specific error occurred');
    }
    
    console.error('\n🔧 Debug Information:');
    console.error(`   Error name: ${error.name}`);
    console.error(`   Error code: ${error.code || 'N/A'}`);
    
    // Check if it's an authentication error
    if (error.message.includes('authentication')) {
      console.error('   Authentication failed. Check username/password in connection string.');
    }
    
    // Check if it's a DNS error
    if (error.message.includes('getaddrinfo') || error.message.includes('ENOTFOUND')) {
      console.error('   DNS resolution failed. Check the hostname in your connection string.');
    }
    
    // Try to parse the connection string for debugging
    try {
      const uri = process.env.MONGODB_URI || '';
      const match = uri.match(/mongodb\+srv:\/\/([^:]+):[^@]+@([^/]+)\/([^?]+)/);
      if (match) {
        console.error('\n📋 Connection String Analysis:');
        console.error(`   Username: ${match[1]}`);
        console.error(`   Cluster: ${match[2]}`);
        console.error(`   Database: ${match[3]}`);
      }
    } catch (parseErr) {
      // Ignore parse errors
    }
    
    process.exit(1);
  }
}

// Handle script termination
process.on('SIGINT', async () => {
  console.log('\n\n⚠️  Script interrupted by user');
  try {
    if (mongoose.connection.readyState === 1) {
      await mongoose.disconnect();
      console.log('🔌 Disconnected from MongoDB');
    }
  } catch (err) {
    console.error('Error during disconnect:', err.message);
  }
  process.exit(0);
});

checkDatabase();