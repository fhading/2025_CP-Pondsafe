import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class RainHistoryPage extends StatefulWidget {
  const RainHistoryPage({super.key});

  @override
  State<RainHistoryPage> createState() => _RainHistoryPageState();
}

class _RainHistoryPageState extends State<RainHistoryPage> {
  final DatabaseReference ref = FirebaseDatabase.instance.ref("sensors/history");

  String filter = "day"; // "hourly", "day", "week", "month"
  DateTime selectedDate = DateTime.now();

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
      final startOfWeek =
          selectedDate.subtract(Duration(days: selectedDate.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      return !dt.isBefore(startOfWeek) && !dt.isAfter(endOfWeek);
    } else if (filter == "month") {
      return dt.year == selectedDate.year && dt.month == selectedDate.month;
    }
    return false;
  }

  List<Map<String, dynamic>> groupAndAverage(List<Map<String, dynamic>> history) {
    final Map<String, Map<String, dynamic>> temp = {};
    DateTime startOfWeek =
        selectedDate.subtract(Duration(days: selectedDate.weekday - 1));

    for (var e in history) {
      final DateTime dt = e['dateTime'] as DateTime;
      final int intensity = e['intensity'] as int;
      String label;
      int sortKey;

      if (filter == "hourly") {
        label = DateFormat('h:mm a').format(dt); // include minutes
        sortKey = dt.hour * 60 + dt.minute;
      } else if (filter == "day") {
        label = DateFormat('h a').format(dt).replaceAll(' ', '');
        sortKey = dt.hour;
      } else if (filter == "week") {
        label = DateFormat('EEE').format(dt);
        sortKey = dt.difference(startOfWeek).inDays;
      } else {
        label = DateFormat('MMM d').format(dt);
        sortKey = dt.day;
      }

      if (!temp.containsKey(label)) {
        temp[label] = {'sum': 0.0, 'count': 0, 'sort': sortKey};
      }

      temp[label]!['sum'] = (temp[label]!['sum'] as double) + intensity;
      temp[label]!['count'] = (temp[label]!['count'] as int) + 1;
    }

    final List<Map<String, dynamic>> buckets = [];
    temp.forEach((label, data) {
      final sum = data['sum'] as double;
      final count = data['count'] as int;
      final avg = (count > 0) ? sum / count : 0.0;
      buckets.add({
        'label': label,
        'avg': avg,
        'sort': data['sort'] as int,
      });
    });

    buckets.sort((a, b) => (a['sort'] as int).compareTo(b['sort'] as int));
    return buckets;
  }

  String getDisplayedDate() {
    if (filter == "day") {
      return DateFormat("MMM d, yyyy").format(selectedDate);
    } else if (filter == "week") {
      final startOfWeek =
          selectedDate.subtract(Duration(days: selectedDate.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      return "${DateFormat("MMM d").format(startOfWeek)} - ${DateFormat("MMM d").format(endOfWeek)}";
    } else if (filter == "month") {
      return DateFormat("MMMM yyyy").format(selectedDate);
    } else {
      return DateFormat("MMM d, yyyy HH:00").format(selectedDate);
    }
  }

  DateTime parseDateKey(String key) {
    try {
      return DateFormat("dd-MM-yyyy_HH:mm:ss").parse(key);
    } catch (_) {
      return DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 1, 33, 148),
        title: const Text(
          "Rain History",
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          // Filter controls
          Padding(
            padding: const EdgeInsets.all(12),
            child: Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
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

          // Data + Chart
          Expanded(
            child: StreamBuilder(
              stream: ref.onValue,
              builder: (context, snapshot) {
                if (!snapshot.hasData ||
                    (snapshot.data! as DatabaseEvent).snapshot.value == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                final raw = (snapshot.data! as DatabaseEvent).snapshot.value as Map;
                final List<Map<String, dynamic>> history = [];

                raw.forEach((key, value) {
                  final Map<String, dynamic> entry = Map<String, dynamic>.from(value);
                  final DateTime dt = parseDateKey(key);
                  if (!matchFilter(dt)) return;

                  final int intensity = _mapRainIntensity(entry['rain_intensity']?.toString());
                  history.add({'dateTime': dt, 'intensity': intensity});
                });

                if (history.isEmpty) {
                  return const Center(child: Text("No rain data available"));
                }

                final buckets = groupAndAverage(history);
                final spots = <FlSpot>[];
                for (int i = 0; i < buckets.length; i++) {
                  spots.add(FlSpot(i.toDouble(), buckets[i]['avg']));
                }

                final labels = buckets.map((b) => b['label'] as String).toList();

                return Column(
                  children: [
                    // Chart card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Card(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        elevation: 6,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                            height: 240,
                            child: LineChart(
                              LineChartData(
                                minY: 0,
                                maxY: 3,
                                gridData: FlGridData(show: true),
                                borderData: FlBorderData(show: true),
                                titlesData: FlTitlesData(
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      interval: 1,
                                      getTitlesWidget: (value, meta) {
                                        final idx = value.toInt();
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
                                      interval: 1,
                                      reservedSize: 46,
                                      getTitlesWidget: (value, meta) {
                                        return Text(_intensityLabel(value), style: const TextStyle(fontSize: 11));
                                      },
                                    ),
                                  ),
                                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: spots,
                                    isCurved: true,
                                    color: Colors.blue,
                                    barWidth: 2.5,
                                    dotData: FlDotData(show: true),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // List cards
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        itemCount: buckets.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, idx) {
                          final b = buckets[idx];
                          return Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
