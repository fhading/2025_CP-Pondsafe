import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class WeatherPage extends StatefulWidget {
  const WeatherPage({super.key});

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  final String apiKey = "ac4dc1960d7844f326d783e5c644ee98";
  final double lat = 7.1153;
  final double lon = 122.3255;

  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    fetchForecast();
  }

  Future<void> fetchForecast() async {
    final url =
        "https://api.openweathermap.org/data/2.5/forecast?lat=$lat&lon=$lon&appid=$apiKey&units=metric";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        setState(() {
          _data = jsonDecode(response.body);
          _loading = false;
        });
      } else {
        print("Failed: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching weather: $e");
    }
  }

  Map<String, List<dynamic>> groupByDay(List<dynamic> list) {
    Map<String, List<dynamic>> grouped = {};
    for (var item in list) {
      String day = DateFormat('EEEE, MMM d')
          .format(DateTime.parse(item['dt_txt'].toString()));
      grouped.putIfAbsent(day, () => []).add(item);
    }
    return grouped;
  }

  String _getCondition(dynamic item) {
    final descRaw = item['weather'][0]['main'] as String;
    final rain = item['rain'] != null ? (item['rain']['3h'] ?? 0.0) : 0.0;
    final pop = (item['pop'] ?? 0.0) * 100;

    if (rain > 0.1) {
      return rain < 2 ? 'Light Rain' : 'Rainy';
    } else if (descRaw.toLowerCase().contains('clear') && pop < 20) {
      return 'Sunny';
    } else if (descRaw.toLowerCase().contains('cloud')) {
      return 'Cloudy';
    } else if (descRaw.toLowerCase().contains('storm')) {
      return 'Thunderstorm';
    } else {
      return 'No Rain';
    }
  }

  /// Finds the most recent forecast to the current time
  dynamic _getLatestForecastBeforeNow(List<dynamic> list) {
    final now = DateTime.now();
    dynamic latest = list.first;
    for (var item in list) {
      final itemTime = DateTime.parse(item['dt_txt']);
      if (itemTime.isBefore(now) || itemTime.isAtSameMomentAs(now)) {
        latest = item;
      } else {
        break;
      }
    }
    return latest;
  }

  void _showDetailDialog(BuildContext context, dynamic item) {
    final temp = (item['main']['temp'] as num).toDouble();
    final humidity = item['main']['humidity'];
    final wind = item['wind']['speed'];
    final condition = _getCondition(item);
    final pop = ((item['pop'] ?? 0.0) * 100).toStringAsFixed(0);
    final rain = item['rain'] != null ? (item['rain']['3h'] ?? 0.0) : 0.0;
    final time = DateFormat('EEEE, MMM d • h a')
        .format(DateTime.parse(item['dt_txt'].toString()));

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Forecast Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(time),
            const SizedBox(height: 8),
            Text('Condition: $condition'),
            Text('Temperature: ${temp.toStringAsFixed(1)}°C'),
            Text('Humidity: $humidity%'),
            Text('Wind: ${wind.toString()} m/s'),
            Text('Chance of Rain: $pop%'),
            Text('Rainfall: ${rain.toString()} mm'),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Close'),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
    );
  }

  Widget _buildMainCard() {
    final current = _getLatestForecastBeforeNow(_data!['list']);
    final temp = (current['main']['temp'] as num).toDouble();
    final icon = current['weather'][0]['icon'] as String;
    final condition = _getCondition(current);
    final pop = ((current['pop'] ?? 0.0) * 100).toStringAsFixed(0);
    final rain = current['rain'] != null ? (current['rain']['3h'] ?? 0.0) : 0.0;
    final time = DateFormat('EEEE, MMM d • h:mm a')
        .format(DateTime.parse(current['dt_txt']));

    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade700,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.blue.shade200.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, 5))
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Image.network(
            "https://openweathermap.org/img/wn/$icon@2x.png",
            width: 90,
            height: 90,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Barangay Vitali • PH',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 4),
                Text(time,
                    style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                Text(
                  '${temp.toStringAsFixed(1)}°C',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold),
                ),
                Text(condition,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('Rain: ${rain.toString()} mm',
                        style: const TextStyle(color: Colors.white70)),
                    const SizedBox(width: 12),
                    Text('Chance: $pop%',
                        style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastCard(dynamic item) {
    final dtTxt = item['dt_txt'];
    final time = DateFormat('h a').format(DateTime.parse(dtTxt));
    final temp = (item['main']['temp'] as num).toDouble();
    final icon = item['weather'][0]['icon'] as String;
    final pop = ((item['pop'] ?? 0.0) * 100).toStringAsFixed(0);
    final rain = item['rain'] != null ? (item['rain']['3h'] ?? 0.0) : 0.0;
    final condition = _getCondition(item);

    return GestureDetector(
      onTap: () => _showDetailDialog(context, item),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade50,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.network(
                  "https://openweathermap.org/img/wn/$icon.png",
                  width: 36,
                  height: 36,
                ),
                const SizedBox(width: 8),
                Text(time,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 4),
            Text('${temp.toStringAsFixed(1)}°C',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(condition, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.water_drop,
                      size: 14, color: Colors.blueAccent),
                  const SizedBox(width: 4),
                  Text('$pop%', style: const TextStyle(fontSize: 12)),
                ]),
                Row(children: [
                  const Icon(Icons.grain, size: 14, color: Colors.lightBlue),
                  const SizedBox(width: 4),
                  Text('${rain.toString()} mm',
                      style: const TextStyle(fontSize: 12)),
                ]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Weather Forecast'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  _buildMainCard(),
                  const SizedBox(height: 20),
                  ...groupByDay(_data!['list']).entries.map((entry) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.key,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 180,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children:
                                entry.value.map(_buildForecastCard).toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
