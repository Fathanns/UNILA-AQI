const Building = require('../models/Building');
const Room = require('../models/Room');
const IoTDevice = require('../models/IoTDevice');

const sampleBuildings = [
  {
    name: 'Gedung H',
    code: 'H',
    description: 'Gedung Fakultas Teknik'
  },
  {
    name: 'Gedung M',
    code: 'M',
    description: 'Gedung Fakultas MIPA'
  },
  {
    name: 'Gedung A',
    code: 'A',
    description: 'Gedung Administrasi'
  },
  {
    name: 'Perpustakaan Pusat',
    code: 'LIB',
    description: 'Perpustakaan Universitas'
  }
];

const sampleRooms = [
  // Gedung H
  { name: 'H101', buildingCode: 'H', dataSource: 'simulation' },
  { name: 'H102', buildingCode: 'H', dataSource: 'simulation' },
  { name: 'H201', buildingCode: 'H', dataSource: 'simulation' },
  { name: 'Lab Komputer H', buildingCode: 'H', dataSource: 'simulation' },
  
  // Gedung M
  { name: 'M101', buildingCode: 'M', dataSource: 'simulation' },
  { name: 'M102', buildingCode: 'M', dataSource: 'simulation' },
  { name: 'Lab Kimia M', buildingCode: 'M', dataSource: 'simulation' },
  
  // Gedung A
  { name: 'A101', buildingCode: 'A', dataSource: 'simulation' },
  { name: 'Ruang Rapat A', buildingCode: 'A', dataSource: 'simulation' },
  
  // Perpustakaan
  { name: 'Lobi Perpustakaan', buildingCode: 'LIB', dataSource: 'simulation' },
  { name: 'Ruang Baca', buildingCode: 'LIB', dataSource: 'simulation' }
];

const seedSampleData = async () => {
  try {
    console.log('🌱 Seeding sample data...');

    // CREATE BUILDINGS tanpa menggunakan save() yang trigger hooks
    const buildings = {};
    
    for (const buildingData of sampleBuildings) {
      try {
        // Cek apakah building sudah ada
        const existingBuilding = await Building.findOne({ code: buildingData.code });
        
        if (existingBuilding) {
          console.log(`⏩ Building ${buildingData.code} already exists, skipping`);
          buildings[buildingData.code] = existingBuilding;
          continue;
        }

        // Gunakan insertOne untuk bypass hooks
        const result = await Building.collection.insertOne({
          ...buildingData,
          roomCount: 0,
          createdAt: new Date(),
          updatedAt: new Date()
        });
        
        const building = await Building.findById(result.insertedId);
        buildings[buildingData.code] = building;
        console.log(`✅ Created building: ${building.name} (${building.code})`);
      } catch (error) {
        console.error(`❌ Error creating building ${buildingData.code}:`, error.message);
      }
    }

    // CREATE ROOMS dengan buildingName yang benar
    let roomCount = 0;
    for (const roomData of sampleRooms) {
      try {
        const building = buildings[roomData.buildingCode];
        if (building) {
          // Cek apakah room sudah ada
          const existingRoom = await Room.findOne({ 
            name: roomData.name, 
            building: building._id 
          });
          
          if (existingRoom) {
            console.log(`⏩ Room ${roomData.name} already exists, skipping`);
            continue;
          }

          // Gunakan insertOne untuk bypass hooks dengan buildingName yang benar
          const result = await Room.collection.insertOne({
            name: roomData.name,
            building: building._id,
            buildingName: building.name,
            dataSource: roomData.dataSource,
            currentAQI: 0,
            currentData: {
              pm25: 0,
              pm10: 0,
              co2: 0,
              temperature: 0,
              humidity: 0,
              updatedAt: new Date()
            },
            createdAt: new Date(),
            updatedAt: new Date()
          });
          
          // Update building room count secara manual
          await Building.collection.updateOne(
            { _id: building._id },
            { $inc: { roomCount: 1 } }
          );
          
          roomCount++;
          console.log(`✅ Created room: ${roomData.name} in ${building.name}`);
        }
      } catch (error) {
        console.error(`❌ Error creating room ${roomData.name}:`, error.message);
      }
    }

    console.log(`🎉 Sample data seeding completed! Created ${roomCount} rooms.`);
    return { success: true, message: `Created ${roomCount} rooms` };
    
  } catch (error) {
    console.error('❌ Error seeding sample data:', error);
    return { success: false, message: error.message };
  }
};

const clearSampleData = async () => {
  try {
    await Room.deleteMany({});
    await Building.deleteMany({});
    console.log('🗑️  Sample data cleared');
    return { success: true, message: 'Data cleared' };
  } catch (error) {
    console.error('❌ Error clearing data:', error);
    return { success: false, message: error.message };
  }
};

// Fungsi untuk sync building names
const syncBuildingNames = async () => {
  try {
    console.log('🔄 Syncing building names in rooms...');
    
    const rooms = await Room.find().populate('building', 'name');
    let updatedCount = 0;
    
    for (const room of rooms) {
      if (room.building && room.buildingName !== room.building.name) {
        room.buildingName = room.building.name;
        await room.save();
        updatedCount++;
      }
    }
    
    console.log(`✅ Synced building names for ${updatedCount} rooms`);
    return { success: true, message: `Synced ${updatedCount} rooms` };
  } catch (error) {
    console.error('❌ Error syncing building names:', error);
    return { success: false, message: error.message };
  }
};

// PERHATIAN: Ekspor dengan nama yang benar!
module.exports = {
  seedSampleData,
  clearSampleData,
  syncBuildingNames  // Tambahkan fungsi sync
};