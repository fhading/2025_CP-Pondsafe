import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DatabaseReference ref =
      FirebaseDatabase.instance.ref().child("sensors/history");

  Map<String, dynamic>? currentData;
  int? lastDisplayedHour;

  Timer? hourlyTimer;
  Timer? shortTimer;
  Timer? flashTimer;
  bool flashToggle = false;

  @override
  void initState() {
    super.initState();
    _fetchLatestData(); // fetch on startup
    _startHourlyTimer();
    _startShortTimer();
    _startFlashTimer();
  }

  @override
  void dispose() {
    hourlyTimer?.cancel();
    shortTimer?.cancel();
    flashTimer?.cancel();
    super.dispose();
  }

  // Hourly timer for normal updates
  void _startHourlyTimer() {
    hourlyTimer = Timer.periodic(const Duration(hours: 1), (timer) {
      _fetchLatestData(updateImmediately: false);
    });
  }

  // Short timer for urgent checks every 5 seconds
  void _startShortTimer() {
    shortTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchLatestData(updateImmediately: true);
    });
  }

  void _startFlashTimer() {
    flashTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (currentData != null) {
        final status =
            (currentData!["water_status"] ?? "").toString().toUpperCase();
        if (status == "WARNING" || status == "OVERFLOW") {
          if (mounted) setState(() => flashToggle = !flashToggle);
        } else if (flashToggle) {
          if (mounted) setState(() => flashToggle = false);
        }
      }
    });
  }

  Future<void> _fetchLatestData({bool updateImmediately = false}) async {
    final snapshot = await ref.get();
    if (snapshot.value == null || snapshot.value is! Map) return;

    final dataMap = Map<dynamic, dynamic>.from(snapshot.value as Map);
    final latest = _getLatest(dataMap);
    if (latest == null) return;

    final timeString = latest["time"] ?? "00:00:00";
    final hour = int.tryParse(timeString.split(":")[0]) ?? 0;
    final status = (latest["water_status"] ?? "").toString().toUpperCase();

    // Update UI if:
    // 1. Immediate urgent check (WARNING/OVERFLOW)
    // 2. Hourly update for normal data
    // 3. First load
    if (currentData == null ||
        (updateImmediately && (status == "WARNING" || status == "OVERFLOW")) ||
        (hour != lastDisplayedHour && status != "WARNING" && status != "OVERFLOW")) {
      lastDisplayedHour = hour;
      if (mounted) {
        setState(() {
          currentData = latest;
        });
      }
    }
  }

  Map<String, dynamic>? _getLatest(Map<dynamic, dynamic> data) {
    DateTime? latestTime;
    String? latestKey;

    data.forEach((key, value) {
      try {
        final parts = key.split("_");
        final dateParts = parts[0].split("-");
        final timeParts = parts[1].split(":");

        final dt = DateTime(
          int.parse(dateParts[2]),
          int.parse(dateParts[1]),
          int.parse(dateParts[0]),
          int.parse(timeParts[0]),
          int.parse(timeParts[1]),
          int.parse(timeParts[2]),
        );

        if (latestTime == null || dt.isAfter(latestTime!)) {
          latestTime = dt;
          latestKey = key;
        }
      } catch (_) {}
    });

    if (latestKey != null) {
      return Map<String, dynamic>.from(data[latestKey]);
    }
    return null;
  }

  Color getWaterStatusColor(String status) {
    switch (status.toUpperCase()) {
      case "OVERFLOW":
        return flashToggle ? Colors.red.shade300 : Colors.red.shade700;
      case "WARNING":
        return flashToggle ? Colors.yellow.shade300 : Colors.yellow.shade700;
      default:
        return Colors.blue.shade700;
    }
  }

  Future<void> _manualRefresh() async {
    await _fetchLatestData(updateImmediately: true);
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentData == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final waterStatus = currentData!["water_status"] ?? "-";
    final cardColor = getWaterStatusColor(waterStatus);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.blue.shade800,
        title: const Text(
          "PondSafe Monitoring",
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: _manualRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text("Update Latest Data"),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [cardColor, cardColor.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: cardColor.withOpacity(0.5),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    const Icon(Icons.water_drop, size: 55, color: Colors.white),
                    const SizedBox(width: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Water Status",
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.white70)),
                        Text(
                          waterStatus,
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  _buildInfoCard(Icons.percent, "Water Percent",
                      "${currentData!["water_percent"] ?? "-"}%", Colors.teal.shade400),
                  _buildInfoCard(Icons.straighten, "Distance",
                      "${currentData!["distance_inches"] ?? "-"} in", Colors.indigo.shade400),
                  _buildInfoCard(Icons.cloud, "Rain Detected",
                      "${currentData!["rain_detected"] ?? "-"}", Colors.deepPurple.shade400),
                  _buildInfoCard(Icons.bolt, "Rain Intensity",
                      "${currentData!["rain_intensity"] ?? "-"}", Colors.orange.shade400),
                  _buildInfoCard(Icons.calendar_today, "Date",
                      "${currentData!["date"] ?? "-"}", Colors.green.shade400),
                  _buildInfoCard(Icons.access_time, "Time",
                      "${currentData!["time"] ?? "-"}", Colors.red.shade400),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(
      IconData icon, String title, String value, Color color) {
    return SizedBox(
      width: 160,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
        shadowColor: color.withOpacity(0.3),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                  backgroundColor: color,
                  radius: 28,
                  child: Icon(icon, color: Colors.white, size: 30)),
              const SizedBox(height: 16),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87)),
              const SizedBox(height: 10),
              Text(value,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black)),
            ],
          ),
        ),
      ),
    );
  }
}
