import 'package:flutter/material.dart';
import '../../../data/models/room.dart';
import 'room_card.dart';

class BuildingSection extends StatelessWidget {
  final String buildingName;
  final List<Room> rooms;
  final Function(Room)? onRoomTap;
  
  const BuildingSection({
    super.key,
    required this.buildingName,
    required this.rooms,
    this.onRoomTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Building Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_city, size: 20),
                const SizedBox(width: 8),
                Text(
                  buildingName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${rooms.length} ruangan',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Rooms List
          ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: rooms.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final room = rooms[index];
              return RoomCard(
                room: room,
                onTap: () {
                  if (onRoomTap != null) {
                    onRoomTap!(room);
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }
}