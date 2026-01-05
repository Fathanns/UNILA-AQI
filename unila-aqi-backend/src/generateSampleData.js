// File: src/generateSampleData.js
const mongoose = require('mongoose');
const SensorData = require('./models/SensorData');
const Room = require('./models/Room');
const { calculateAQIFromPM25 } = require('./utils/aqiCalculator');
require('dotenv').config();

async function generateSampleData() {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('✅ Connected to MongoDB');
    
    // Get all rooms
    const rooms = await Room.find({ isActive: true });
    console.log(`Found ${rooms.length} active rooms`);
    
    for (const room of rooms) {
      console.log(`\n📊 Generating sample data for ${room.name}...`);
      
      // Delete existing historical data for this room
      await SensorData.deleteMany({ roomId: room._id });
      console.log(`   Cleared existing data`);
      
      const sampleData = [];
      const now = new Date();
      
      // Generate 7 days of data (every 15 minutes)
      for (let day = 7; day >= 0; day--) {
        for (let hour = 0; hour < 24; hour++) {
          for (let minute = 0; minute < 60; minute += 15) {
            const timestamp = new Date(now);
            timestamp.setDate(now.getDate() - day);
            timestamp.setHours(hour, minute, 0, 0);
            
            // Add realistic variation based on time of day
            let variation = 1.0;
            if (hour >= 8 && hour <= 17) {
              // Office hours - higher pollution
              variation = 1.2 + Math.random() * 0.3;
            } else if (hour >= 18 && hour <= 22) {
              // Evening - moderate
              variation = 1.0 + Math.random() * 0.2;
            } else {
              // Night - lower
              variation = 0.8 + Math.random() * 0.2;
            }
            
            const pm25 = Math.max(5, Math.min(150, room.currentData.pm25 * variation));
            const pm10 = Math.max(10, Math.min(200, room.currentData.pm10 * variation));
            const co2 = Math.max(400, Math.min(1500, room.currentData.co2 * variation));
            const temperature = room.currentData.temperature + (Math.random() * 4 - 2);
            const humidity = Math.max(30, Math.min(80, room.currentData.humidity + (Math.random() * 10 - 5)));
            
            const { aqi, category } = calculateAQIFromPM25(pm25);
            
            sampleData.push({
              roomId: room._id,
              roomName: room.name,
              buildingName: room.buildingName,
              aqi: aqi,
              pm25: parseFloat(pm25.toFixed(1)),
              pm10: parseFloat(pm10.toFixed(1)),
              co2: Math.round(co2),
              temperature: parseFloat(temperature.toFixed(1)),
              humidity: Math.round(humidity),
              category: category,
              timestamp: timestamp
            });
          }
        }
      }
      
      // Insert in batches
      const batchSize = 100;
      for (let i = 0; i < sampleData.length; i += batchSize) {
        const batch = sampleData.slice(i, i + batchSize);
        await SensorData.insertMany(batch);
        console.log(`   Inserted batch ${Math.floor(i/batchSize) + 1}/${Math.ceil(sampleData.length/batchSize)}`);
      }
      
      console.log(`✅ Generated ${sampleData.length} data points for ${room.name}`);
    }
    
    console.log('\n🎉 Sample data generation completed!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

generateSampleData();