const io = require('socket.io-client');

const socket = io('http://localhost:5000');

socket.on('connect', () => {
  console.log('✅ Connected to server');
  
  // Join a test room
  socket.emit('join-room', '694d0ebcdccf55038bed798a');
  
  // Send ping
  socket.emit('ping');
});

socket.on('pong', (data) => {
  console.log('🏓 Pong received:', data);
});

socket.on('room-update', (data) => {
  console.log('📡 Room update:', data);
});

socket.on('disconnect', () => {
  console.log('❌ Disconnected from server');
});

socket.on('error', (error) => {
  console.error('❌ Socket error:', error);
});

// Test sending update after 5 seconds
setTimeout(() => {
  console.log('🔄 Testing room update...');
  socket.emit('room-update', {
    roomId: '694d0ebcdccf55038bed798a',
    data: {
      currentAQI: 45,
      currentData: {
        pm25: 10,
        pm10: 20,
        co2: 500,
        temperature: 25,
        humidity: 60,
        updatedAt: new Date()
      },
      updatedAt: new Date()
    }
  });
}, 5000);