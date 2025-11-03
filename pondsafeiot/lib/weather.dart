import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

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
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    fetchForecast();

    // Auto-refresh every 10 minutes
    _timer = Timer.periodic(const Duration(minutes: 10), (_) => fetchForecast());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
        debugPrint("Failed: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetching weather: $e");
    }
  }

  Map<String, List<dynamic>> groupByDay(List<dynamic> list) {
    final grouped = <String, List<dynamic>>{};
    for (var item in list) {
      String day =
          DateFormat('EEEE, MMM d').format(DateTime.parse(item['dt_txt']));
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

  /// 🕐 Find the forecast closest to the current time
  dynamic _getNearestForecastToNow(List<dynamic> list) {
    final now = DateTime.now();
    dynamic nearest = list.first;
    Duration smallestDiff = now.difference(DateTime.parse(list.first['dt_txt'])).abs();

    for (var item in list) {
      final itemTime = DateTime.parse(item['dt_txt']);
      final diff = now.difference(itemTime).abs();
      if (diff < smallestDiff) {
        smallestDiff = diff;
        nearest = item;
      }
    }
    return nearest;
  }

  // ===== MAIN BLUE CARD =====
  Widget _buildMainCard() {
    final current = _getNearestForecastToNow(_data!['list']);
    final temp = (current['main']['temp'] as num).toDouble();
    final icon = current['weather'][0]['icon'] as String;
    final condition = _getCondition(current);
    final pop = ((current['pop'] ?? 0.0) * 100).toStringAsFixed(0);
    final rain = current['rain'] != null ? (current['rain']['3h'] ?? 0.0) : 0.0;
    final time = DateFormat('EEEE, MMM d • h:mm a')
        .format(DateTime.parse(current['dt_txt']));

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade800, Colors.blue.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade300.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.network(
            "https://openweathermap.org/img/wn/$icon@2x.png",
            width: 85,
            height: 85,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.cloud_off, size: 60, color: Colors.white54),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Barangay Vitali • PH',
                    style: GoogleFonts.roboto(
                        fontSize: 15,
                        color: Colors.white,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Text(time,
                    style: GoogleFonts.roboto(
                        color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 10),
                Text('${temp.toStringAsFixed(1)}°C',
                    style: GoogleFonts.roboto(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                Text(condition,
                    style: GoogleFonts.roboto(
                        fontSize: 16, color: Colors.white70)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.water_drop,
                          size: 15, color: Colors.white70),
                      const SizedBox(width: 6),
                      Text('Rain: ${rain.toString()} mm',
                          style: GoogleFonts.roboto(
                              fontSize: 13, color: Colors.white70)),
                    ]),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.cloud_queue,
                          size: 15, color: Colors.white70),
                      const SizedBox(width: 6),
                      Text('Chance: $pop%',
                          style: GoogleFonts.roboto(
                              fontSize: 13, color: Colors.white70)),
                    ]),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===== SMALL WHITE FORECAST CARDS =====
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
        width: 120,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
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
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.network(
              "https://openweathermap.org/img/wn/$icon.png",
              width: 45,
              height: 45,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.cloud, size: 40, color: Colors.blueGrey),
            ),
            const SizedBox(height: 6),
            Text(time,
                style: GoogleFonts.roboto(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: Colors.black87)),
            const SizedBox(height: 4),
            Text('${temp.toStringAsFixed(1)}°C',
                style: GoogleFonts.roboto(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700)),
            const SizedBox(height: 2),
            Text(
              condition,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.roboto(fontSize: 12, color: Colors.black54),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(children: [
                    const Icon(Icons.water_drop,
                        size: 14, color: Colors.blueGrey),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text('$pop%',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.roboto(
                              fontSize: 12, color: Colors.black87)),
                    ),
                  ]),
                ),
                Flexible(
                  child: Row(children: [
                    const Icon(Icons.grain, size: 14, color: Colors.blueGrey),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text('${rain.toString()} mm',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.roboto(
                              fontSize: 12, color: Colors.black87)),
                    ),
                  ]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Forecast Details',
            style: GoogleFonts.roboto(
                fontWeight: FontWeight.w600, color: Colors.blue.shade800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(time, style: GoogleFonts.roboto(color: Colors.black54)),
            const SizedBox(height: 10),
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
            child: Text('Close',
                style: GoogleFonts.roboto(color: Colors.blue.shade700)),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        title: Text('Weather Forecast',
            style: GoogleFonts.roboto(
                fontWeight: FontWeight.w600, fontSize: 20)),
        centerTitle: true,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : RefreshIndicator(
              onRefresh: fetchForecast,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: ListView(
                  children: [
                    _buildMainCard(),
                    const SizedBox(height: 20),
                    ...groupByDay(_data!['list']).entries.map((entry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.key,
                              style: GoogleFonts.roboto(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade800)),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 200,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children:
                                  entry.value.map(_buildForecastCard).toList(),
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
    );
  }
}
