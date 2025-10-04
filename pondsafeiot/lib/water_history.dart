import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class WaterHistoryPage extends StatefulWidget {
  const WaterHistoryPage({super.key});

  @override
  State<WaterHistoryPage> createState() => _WaterHistoryPageState();
}

class _WaterHistoryPageState extends State<WaterHistoryPage> {
  final DatabaseReference ref = FirebaseDatabase.instance.ref("sensors/history");
  final double maxDepthIn = 65.0; // 0 = overflow, 65 = empty

  String filter = "day"; // "hourly", "day", "week", "month"
  DateTime selectedDate = DateTime.now();

  DateTime parseDateKey(String key) {
    try {
      return DateFormat("dd-MM-yyyy_HH:mm:ss").parse(key);
    } catch (_) {
      return DateTime.now();
    }
  }

  double percentToInches(double percent) {
    return maxDepthIn - (percent / 100 * maxDepthIn);
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

  List<Map<String, dynamic>> groupAndAverage(
      List<Map<String, dynamic>> history) {
    final Map<String, Map<String, dynamic>> temp = {};
    DateTime startOfWeek =
        selectedDate.subtract(Duration(days: selectedDate.weekday - 1));

    for (var e in history) {
      final DateTime dt = e['dateTime'] as DateTime;
      final double inches = (e['inches'] as double);
      String label;
      int sortKey;

      if (filter == "hourly") {
        label = DateFormat('mm').format(dt);
        sortKey = dt.minute;
      } else if (filter == "day") {
        label = DateFormat('ha').format(dt).replaceAll(' ', '');
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

      temp[label]!['sum'] = (temp[label]!['sum'] as double) + inches;
      temp[label]!['count'] = (temp[label]!['count'] as int) + 1;
    }

    final List<Map<String, dynamic>> buckets = [];
    temp.forEach((label, data) {
      final sum = data['sum'] as double;
      final count = data['count'] as int;
      final avg = (count > 0) ? sum / count : 0.0;
      final percent = ((maxDepthIn - avg) / maxDepthIn) * 100.0;
      buckets.add({
        'label': label,
        'inches': avg,
        'percent': percent,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.blue.shade800,
        title: const Text(
          "Water History",
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          // filter controls in card
          Padding(
            padding: const EdgeInsets.all(12),
            child: Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 6,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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

                    // 👇 Date Display
                    Expanded(
                      child: Text(
                        getDisplayedDate(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500),
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
                    if (filter == 'hourly')
                      IconButton(
                        icon: const Icon(Icons.access_time,
                            color: Colors.deepOrange),
                        onPressed: () async {
                          final TimeOfDay? t = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(selectedDate),
                          );
                          if (t != null) {
                            setState(() {
                              selectedDate = DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                                t.hour,
                              );
                            });
                          }
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),

          // data + chart
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
                  final Map<String, dynamic> entry =
                      Map<String, dynamic>.from(value);
                  final DateTime dt = parseDateKey(key);
                  if (!matchFilter(dt)) return;

                  final double percent =
                      double.tryParse(entry['water_percent'].toString()) ?? 0.0;
                  final double inches = percentToInches(percent);
                  history.add(
                      {'dateTime': dt, 'percent': percent, 'inches': inches});
                });

                if (history.isEmpty) {
                  return const Center(child: Text("No data available"));
                }

                final buckets = groupAndAverage(history);
                if (buckets.isEmpty) {
                  return const Center(child: Text("No grouped data"));
                }

                final spots = <FlSpot>[];
                for (int i = 0; i < buckets.length; i++) {
                  final double inches = buckets[i]['inches'] as double;
                  final double plottedY = maxDepthIn - inches;
                  spots.add(FlSpot(i.toDouble(), plottedY));
                }

                final labels =
                    buckets.map((b) => b['label'] as String).toList();

                return Column(
                  children: [
                    // chart card
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
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
                                maxY: maxDepthIn,
                                gridData: FlGridData(show: true),
                                borderData: FlBorderData(show: true),
                                titlesData: FlTitlesData(
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        final idx = value.toInt();
                                        if (idx >= 0 && idx < labels.length) {
                                          return Padding(
                                            padding:
                                                const EdgeInsets.only(top: 6),
                                            child: Text(labels[idx],
                                                style: const TextStyle(
                                                    fontSize: 11)),
                                          );
                                        }
                                        return const Text('');
                                      },
                                      reservedSize: 28,
                                      interval: 1,
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 46,
                                      interval: 10,
                                      getTitlesWidget: (value, meta) {
                                        final double inches =
                                            (maxDepthIn - value);
                                        return Text(
                                          "${inches.toStringAsFixed(0)} in",
                                          style:
                                              const TextStyle(fontSize: 11),
                                        );
                                      },
                                    ),
                                  ),
                                  rightTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 40,
                                      interval: 10,
                                      getTitlesWidget: (value, meta) {
                                        final double percent =
                                            (value / maxDepthIn) * 100;
                                        return Text(
                                          "${percent.toStringAsFixed(0)}%",
                                          style:
                                              const TextStyle(fontSize: 11),
                                        );
                                      },
                                    ),
                                  ),
                                  topTitles: AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
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

                    // list cards
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        itemCount: buckets.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 6),
                        itemBuilder: (context, idx) {
                          final b = buckets[idx];
                          final String label = b['label'] as String;
                          final double inches = b['inches'] as double;
                          final double percent = b['percent'] as double;

                          return Card(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 4,
                            shadowColor: Colors.blue.withOpacity(0.2),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.shade700,
                                child: const Icon(Icons.water_drop,
                                    color: Colors.white),
                              ),
                              title: Text(label,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                  "${inches.toStringAsFixed(1)} in | ${percent.toStringAsFixed(1)}%"),
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
