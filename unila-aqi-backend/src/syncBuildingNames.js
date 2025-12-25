const mongoose = require('mongoose');
require('dotenv').config();

async function syncBuildingNames() {
  try {
    console.log('🔄 Starting building name sync...');
    
    // Connect to MongoDB
    console.log('🔗 Connecting to MongoDB...');
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('✅ Connected to MongoDB');
    
    // Import models after connection
    const Building = require('./models/Building');
    const Room = require('./models/Room');
    
    // Get all buildings
    const buildings = await Building.find();
    console.log(`📊 Found ${buildings.length} buildings`);
    
    let totalUpdated = 0;
    
    // For each building, update all related rooms
    for (const building of buildings) {
      try {
        const result = await Room.updateMany(
          { building: building._id },
          { $set: { buildingName: building.name } }
        );
        
        if (result.modifiedCount > 0) {
          console.log(`✅ Updated ${result.modifiedCount} rooms in ${building.name}`);
          totalUpdated += result.modifiedCount;
        }
      } catch (buildingError) {
        console.error(`❌ Error updating rooms in ${building.name}:`, buildingError.message);
      }
    }
    
    console.log(`🎉 Sync completed! Total ${totalUpdated} rooms updated.`);
    
    // Verify sync
    console.log('🔍 Verifying sync...');
    const rooms = await Room.find();
    let mismatched = 0;
    
    for (const room of rooms) {
      try {
        if (room.building) {
          const building = await Building.findById(room.building);
          if (building && room.buildingName !== building.name) {
            mismatched++;
            console.log(`❌ Mismatch: Room "${room.name}" has "${room.buildingName}" but building is "${building.name}"`);
            
            // Auto-fix mismatch
            room.buildingName = building.name;
            await room.save();
            console.log(`   ↳ Fixed: Updated to "${building.name}"`);
          }
        }
      } catch (roomError) {
        console.error(`❌ Error checking room ${room.name}:`, roomError.message);
      }
    }
    
    if (mismatched > 0) {
      console.log(`⚠️  Found and fixed ${mismatched} mismatches`);
    } else {
      console.log('✅ All room building names are correctly synced!');
    }
    
    // Show summary
    console.log('\n📊 SYNC SUMMARY:');
    console.log('----------------');
    console.log(`Total buildings: ${buildings.length}`);
    console.log(`Total rooms: ${rooms.length}`);
    console.log(`Rooms updated: ${totalUpdated}`);
    console.log(`Mismatches fixed: ${mismatched}`);
    
    await mongoose.disconnect();
    console.log('🔌 Disconnected from MongoDB');
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    console.error('Stack:', error.stack);
    
    // Show connection string for debugging
    const uri = process.env.MONGODB_URI || '';
    const maskedUri = uri.replace(/:[^:@]*@/, ':****@');
    console.error('Connection string:', maskedUri);
    
    process.exit(1);
  }
}

// Run the sync
syncBuildingNames();