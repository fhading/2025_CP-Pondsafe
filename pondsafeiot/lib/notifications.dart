import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  Color getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case "OVERFLOW":
        return Colors.red.shade700;
      case "WARNING":
        return Colors.yellow.shade700;
      default:
        return const Color(0xFF1565C0);
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
        centerTitle: true,
        backgroundColor: Colors.blue.shade800,
        title: const Text(
          "Notifications",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        elevation: 4,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: StreamBuilder(
            stream: ref.onValue,
            builder: (context, snapshot) {
              if (snapshot.hasData && (snapshot.data!).snapshot.value != null) {
                final data = Map<String, dynamic>.from((snapshot.data!).snapshot.value as Map);

                final filtered = data.entries.where((entry) {
                  final item = Map<String, dynamic>.from(entry.value);
                  final status = (item["water_status"] ?? "").toString().toUpperCase();
                  final rain = (item["rain_detected"] ?? "No").toString().toUpperCase();
                  return status == "WARNING" || status == "OVERFLOW" || rain == "YES";
                }).toList();

                filtered.sort((a, b) {
                  final dtA = parseKeyToDateTime(a.key) ?? DateTime(0);
                  final dtB = parseKeyToDateTime(b.key) ?? DateTime(0);
                  return dtB.compareTo(dtA);
                });

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        "No warnings or alerts",
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: filtered.map((entry) {
                    final item = Map<String, dynamic>.from(entry.value);
                    final status = (item["water_status"] ?? "").toString();
                    final color = getStatusColor(status);

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(color: color, width: 1.5),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.notifications_active, color: color, size: 26),
                              const SizedBox(width: 10),
                              Text(
                                "${formatDate(item["date"] ?? "-")} • ${formatTime(item["time"] ?? "-")}",
                                style: GoogleFonts.roboto(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildRow("Water Status", "${item["water_status"]} (${item["water_percent"]}%)", color),
                          _buildRow("Distance", "${item["distance_inches"]} in", Colors.blue.shade800),
                          _buildRow("Rain", "${item["rain_detected"]} | Intensity: ${item["rain_intensity"]}", Colors.blue.shade800),
                        ],
                      ),
                    );
                  }).toList(),
                );
              } else {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String title, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            "$title: ",
            style: GoogleFonts.roboto(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.roboto(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
