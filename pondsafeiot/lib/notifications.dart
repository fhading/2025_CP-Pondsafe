import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  // Determine card color based on status
  Color getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case "OVERFLOW":
        return Colors.red.shade400; 
      case "WARNING":
        return Colors.yellow.shade400;
      default:
        return Colors.blue.shade200;
    }
  }

 
  DateTime? parseKeyToDateTime(String key) {
    try {
      final parts = key.split("_");
      final dateParts = parts[0].split("-");
      final timeParts = parts[1].split(":");
      return DateTime(
        int.parse(dateParts[2]),
        int.parse(dateParts[1]),
        int.parse(dateParts[0]),
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
        int.parse(timeParts[2]),
      );
    } catch (_) {
      return null;
    }
  }

  String formatDate(String dateStr) {
    try {
      final parts = dateStr.split("-");
      final dt = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      return DateFormat.MMMd().format(dt); 
    } catch (_) {
      return dateStr;
    }
  }

  String formatTime(String timeStr) {
    try {
      final parts = timeStr.split(":");
      final dt = DateTime(0, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
      return DateFormat.jm().format(dt); 
    } catch (_) {
      return timeStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final DatabaseReference ref = FirebaseDatabase.instance.ref("sensors/history");

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text(
          "Notifications",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue.shade800,
        elevation: 4,
      ),
      body: StreamBuilder(
        stream: ref.onValue,
        builder: (context, snapshot) {
          if (snapshot.hasData &&
              (snapshot.data! as DatabaseEvent).snapshot.value != null) {
            final data = Map<String, dynamic>.from(
                (snapshot.data! as DatabaseEvent).snapshot.value as Map);

            //  WARNING/OVERFLOW or rain detected
            final filtered = data.entries.where((entry) {
              final item = Map<String, dynamic>.from(entry.value);
              final status = (item["water_status"] ?? "").toString().toUpperCase();
              final rain = (item["rain_detected"] ?? "No").toString().toUpperCase();
              return status == "WARNING" || status == "OVERFLOW" || rain == "YES";
            }).toList();

            // Sort latest to oldest
            filtered.sort((a, b) {
              final dtA = parseKeyToDateTime(a.key) ?? DateTime(0);
              final dtB = parseKeyToDateTime(b.key) ?? DateTime(0);
              return dtB.compareTo(dtA);
            });

            if (filtered.isEmpty) {
              return const Center(
                  child: Text(
                "No warnings or alerts",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final item = Map<String, dynamic>.from(filtered[index].value);
                final status = (item["water_status"] ?? "").toString();
                final cardColor = getStatusColor(status);

                return Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  elevation: 6,
                  shadowColor: cardColor.withOpacity(0.3),
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          "${formatDate(item["date"] ?? "-")}  |  ${formatTime(item["time"] ?? "-")}",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow("Water",
                            "${item["water_status"]} (${item["water_percent"]}%)", cardColor),
                        const SizedBox(height: 6),
                        _buildInfoRow("Distance",
                            "${item["distance_inches"]} in", Colors.indigo.shade400),
                        const SizedBox(height: 6),
                        _buildInfoRow("Rain",
                            "${item["rain_detected"]} | Intensity: ${item["rain_intensity"]}", Colors.deepPurple.shade400),
                      ],
                    ),
                  ),
                );
              },
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }

  Widget _buildInfoRow(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Text(
            "$title: ",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
