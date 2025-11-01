import 'package:flutter/material.dart'; // UI
import 'package:firebase_database/firebase_database.dart'; // Firebase history data
import 'package:fl_chart/fl_chart.dart'; // Graphs
import 'package:intl/intl.dart'; // Date formatting

class WaterHistoryPage extends StatefulWidget {
  const WaterHistoryPage({super.key});

  @override
  State<WaterHistoryPage> createState() => _WaterHistoryPageState();
}

class _WaterHistoryPageState extends State<WaterHistoryPage> {
  final DatabaseReference ref = FirebaseDatabase.instance.ref("sensors/history");
  final double maxDepthIn = 65.0;

  String filter = "day";
  DateTime selectedDate = DateTime.now();

  // Parse timestamp key into DateTime
  DateTime parseDateKey(String key) {
    try {
      return DateFormat("dd-MM-yyyy_HH:mm:ss").parse(key);
    } catch (_) {
      return DateTime.now();
    }
  }

  // Check if date fits filter selection
  bool matchFilter(DateTime dt) {
    if (filter == "hourly") {
      return dt.year == selectedDate.year &&
          dt.month == selectedDate.month &&
          dt.day == selectedDate.day &&
          dt.hour == selectedDate.hour;
    } else if (filter == "day") {
      return dt.year == selectedDate.year &&
          dt.month == selectedDate.month &&
          dt.day == selectedDate.day;
    } else if (filter == "week") {
      final start = selectedDate.subtract(Duration(days: selectedDate.weekday - 1));
      final end = start.add(const Duration(days: 6));
      return !dt.isBefore(start) && !dt.isAfter(end);
    } else if (filter == "month") {
      return dt.year == selectedDate.year && dt.month == selectedDate.month;
    }
    return false;
  }

  //  filter date
  String getDisplayedDate() {
    if (filter == "day") {
      return DateFormat("MMM d, yyyy").format(selectedDate);
    } else if (filter == "week") {
      final start = selectedDate.subtract(Duration(days: selectedDate.weekday - 1));
      final end = start.add(const Duration(days: 6));
      return "${DateFormat("MMM d").format(start)} - ${DateFormat("MMM d").format(end)}";
    } else if (filter == "month") {
      return DateFormat("MMMM yyyy").format(selectedDate);
    } else {
      return DateFormat("MMM d, yyyy HH:00").format(selectedDate);
    }
  }

  //  water depth in inches
  double percentToInches(double percent) {
    return maxDepthIn - (percent / 100 * maxDepthIn);
  }


  int _mapRainIntensity(String? value) {
    if (value == null) return 0;
    switch (value.toUpperCase()) {
      case "NONE":
        return 0;
      case "LIGHT":
        return 1;
      case "MEDIUM":
        return 2;
      case "HEAVY":
        return 3;
      default:
        return 0;
    }
  }

  // Convert number to label
  String _intensityLabel(double value) {
    int v = value.round();
    switch (v) {
      case 0:
        return "None";
      case 1:
        return "Light";
      case 2:
        return "Medium";
      case 3:
        return "Heavy";
      default:
        return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.blue.shade800,
        title: const Text(
          "Rain & Water History",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
         
          Padding(
            padding: const EdgeInsets.all(12),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 6,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    DropdownButton<String>(
                      value: filter,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: "hourly", child: Text("Hourly")),
                        DropdownMenuItem(value: "day", child: Text("Day")),
                        DropdownMenuItem(value: "week", child: Text("Week")),
                        DropdownMenuItem(value: "month", child: Text("Month")),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => filter = v);
                      },
                    ),
                    Expanded(
                      child: Text(
                        getDisplayedDate(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.date_range, color: Colors.blue),
                      onPressed: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setState(() => selectedDate = picked);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          //  historical data 
          Expanded(
            child: StreamBuilder(
              stream: ref.onValue,
              builder: (context, snapshot) {
                if (!snapshot.hasData || (snapshot.data!).snapshot.value == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                final raw = (snapshot.data!).snapshot.value as Map;

                // Water list
                final List<Map<String, dynamic>> waterHistory = [];
                raw.forEach((key, value) {
                  final entry = Map<String, dynamic>.from(value);
                  final dt = parseDateKey(key);
                  if (!matchFilter(dt)) return;

                  final percent = double.tryParse(entry['water_percent'].toString()) ?? 0.0;
                  final inches = percentToInches(percent);
                  waterHistory.add({'dateTime': dt, 'percent': percent, 'inches': inches});
                });

                // Rain list
                final List<Map<String, dynamic>> rainHistory = [];
                raw.forEach((key, value) {
                  final entry = Map<String, dynamic>.from(value);
                  final dt = parseDateKey(key);
                  if (!matchFilter(dt)) return;

                  final intensity = _mapRainIntensity(entry['rain_intensity']?.toString());
                  rainHistory.add({'dateTime': dt, 'intensity': intensity});
                });

                if (waterHistory.isEmpty && rainHistory.isEmpty) {
                  return const Center(child: Text("No data available"));
                }

                //  chart
                List<Map<String, dynamic>> group(List<Map<String, dynamic>> history, String key) {
                  final Map<String, Map<String, dynamic>> temp = {};
                  DateTime startOfWeek =
                      selectedDate.subtract(Duration(days: selectedDate.weekday - 1));

                  for (var e in history) {
                    final DateTime dt = e['dateTime'];
                    final double val = (e[key] as num).toDouble();
                    String label;
                    int sortKey;

                    if (filter == "hourly") {
                      label = DateFormat('h:mm a').format(dt);
                      sortKey = dt.hour * 60 + dt.minute;
                    } else if (filter == "day") {
                      label = DateFormat('h a').format(dt);
                      sortKey = dt.hour;
                    } else if (filter == "week") {
                      label = DateFormat('EEE').format(dt);
                      sortKey = dt.difference(startOfWeek).inDays;
                    } else {
                      label = DateFormat('MMM d').format(dt);
                      sortKey = dt.day;
                    }

                    temp.putIfAbsent(label, () => {'sum': 0.0, 'count': 0, 'sort': sortKey});
                    temp[label]!['sum'] = (temp[label]!['sum'] as double) + val;
                    temp[label]!['count'] = (temp[label]!['count'] as int) + 1;
                  }

                  return temp.entries
                      .map((e) => {
                            'label': e.key,
                            'avg': (e.value['count'] as int) > 0
                                ? (e.value['sum'] as double) /
                                    (e.value['count'] as int)
                                : 0.0,
                            'sort': e.value['sort'],
                          })
                      .toList()
                    ..sort((a, b) => (a['sort'] as int).compareTo(b['sort'] as int));
                }

                final waterBuckets = group(waterHistory, 'inches');
                final rainBuckets = group(rainHistory, 'intensity');

                // Chart points
                final waterSpots = [
                  for (int i = 0; i < waterBuckets.length; i++)
                    FlSpot(i.toDouble(), maxDepthIn - waterBuckets[i]['avg'])
                ];
                final rainSpots = [
                  for (int i = 0; i < rainBuckets.length; i++)
                    FlSpot(i.toDouble(), rainBuckets[i]['avg'])
                ];

                final waterLabels = waterBuckets.map((b) => b['label'] as String).toList();
                final rainLabels = rainBuckets.map((b) => b['label'] as String).toList();

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Rain Chart
                      const Text("Rain Intensity", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      _buildChartCard(
                        spots: rainSpots,
                        maxY: 3,
                        labels: rainLabels,
                        leftTitle: (v) => _intensityLabel(v),
                        color: Colors.blue,
                      ),

                      // Water Chart
                      const SizedBox(height: 16),
                      const Text("Water Level", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      _buildChartCard(
                        spots: waterSpots,
                        maxY: maxDepthIn,
                        labels: waterLabels,
                        leftTitle: (v) => "${(maxDepthIn - v).toStringAsFixed(0)} in",
                        color: Colors.teal,
                      ),

                      // Rain List
                      const SizedBox(height: 16),
                      const Text("Rain History", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...rainBuckets.map((b) => Card(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 4,
                            shadowColor: Colors.blue.withOpacity(0.2),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.shade700,
                                child: const Icon(Icons.cloud, color: Colors.white),
                              ),
                              title: Text(b['label']),
                              subtitle: Text("Average: ${_intensityLabel(b['avg'])}"),
                            ),
                          )),

                      // Water List
                      const SizedBox(height: 16),
                      const Text("Water Level History", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...waterBuckets.map((b) => Card(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 4,
                            shadowColor: Colors.teal.withOpacity(0.2),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.teal,
                                child: const Icon(Icons.water_drop, color: Colors.white),
                              ),
                              title: Text(b['label']),
                              subtitle: Text("${b['avg'].toStringAsFixed(1)} in"),
                            ),
                          )),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Graph card widget
  Widget _buildChartCard({
    required List<FlSpot> spots,
    required double maxY,
    required List<String> labels,
    required String Function(double) leftTitle,
    required Color color,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 240,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxY,
              gridData: FlGridData(show: true),
              borderData: FlBorderData(show: true),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (v, _) {
                      final idx = v.toInt();
                      if (idx >= 0 && idx < labels.length) {
                        return Text(labels[idx], style: const TextStyle(fontSize: 11));
                      }
                      return const Text('');
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: maxY / 3,
                    reservedSize: 46,
                    getTitlesWidget: (v, _) => Text(leftTitle(v), style: const TextStyle(fontSize: 11)),
                  ),
                ),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: color,
                  barWidth: 2.5,
                  dotData: FlDotData(show: true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
