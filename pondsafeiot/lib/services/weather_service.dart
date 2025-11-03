import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  final String apiKey = "ac4dc1960d7844f326d783e5c644ee98";
  final double lat =  7.3711; // Barangay Vitali
  final double lon = 122.2886;

  Future<Map<String, dynamic>?> fetchForecast() async {
    final url =
        "https://api.openweathermap.org/data/2.5/forecast?lat=$lat&lon=$lon&appid=$apiKey&units=metric";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("Failed: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching weather: $e");
    }
    return null;
  }

  static Future fetchWeather(String s) async {}
}
