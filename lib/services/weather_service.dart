import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WeatherService {
  static final WeatherService _instance = WeatherService._internal();
  factory WeatherService() => _instance;
  WeatherService._internal();

  double? currentTemp;
  String? weatherDescription;
  int? weatherCode;
  bool isStormy = false;
  bool hasDismissedStormWarning = false;
  String? lastWarningDismissedDate;

  Future<void> fetchWeather() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('[Weather] Location services are disabled.');
        return;
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('[Weather] Location permissions are denied.');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        print('[Weather] Location permissions are permanently denied.');
        return;
      }

      // Get position (first try last known for speed, then try current with short timeout)
      Position? position = await Geolocator.getLastKnownPosition();
      if (position == null) {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 4),
        );
      }

      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=${position.latitude}&longitude=${position.longitude}&current=temperature_2m,weather_code&timezone=auto'
      );

      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final current = data['current'];
        if (current != null) {
          currentTemp = (current['temperature_2m'] as num?)?.toDouble();
          weatherCode = current['weather_code'] as int?;
          isStormy = _isWeatherStormy(weatherCode);
          weatherDescription = _getWeatherDescription(weatherCode);

          // Check if warning has been dismissed today
          final prefs = await SharedPreferences.getInstance();
          lastWarningDismissedDate = prefs.getString('last_weather_warning_dismissed_date');
          final todayStr = _getTodayDateString();
          hasDismissedStormWarning = lastWarningDismissedDate == todayStr;
          print('[Weather] Fetched successfully: $currentTemp°C, Code: $weatherCode, Stormy: $isStormy');
        }
      } else {
        print('[Weather] API error: ${response.statusCode}');
      }
    } catch (e) {
      print('[Weather] Failed to fetch weather: $e');
    }
  }

  bool _isWeatherStormy(int? code) {
    if (code == null) return false;
    // WMO Weather codes:
    // 95, 96, 99: Thunderstorms (stormy)
    // 65: Heavy rain
    // 67: Heavy freezing rain
    // 82: Violent rain showers
    // 86: Heavy snow showers
    return code >= 65 || code == 95 || code == 96 || code == 99;
  }

  String _getWeatherDescription(int? code) {
    if (code == null) return 'Clear';
    switch (code) {
      case 0: return 'Clear Sky';
      case 1:
      case 2:
      case 3: return 'Partly Cloudy';
      case 45:
      case 48: return 'Foggy';
      case 51:
      case 53:
      case 55: return 'Drizzle';
      case 56:
      case 57: return 'Freezing Drizzle';
      case 61:
      case 63: return 'Slight Rain';
      case 65: return 'Heavy Rain';
      case 66:
      case 67: return 'Freezing Rain';
      case 71:
      case 73:
      case 75: return 'Snow Fall';
      case 77: return 'Snow Grains';
      case 80:
      case 81: return 'Rain Showers';
      case 82: return 'Violent Rain Showers';
      case 85:
      case 86: return 'Snow Showers';
      case 95: return 'Thunderstorm';
      case 96:
      case 99: return 'Thunderstorm with Hail';
      default: return 'Clear';
    }
  }

  String _getTodayDateString() {
    final now = DateTime.now();
    return "${now.year}-${now.month}-${now.day}";
  }

  Future<void> dismissWarningForToday() async {
    final todayStr = _getTodayDateString();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_weather_warning_dismissed_date', todayStr);
    hasDismissedStormWarning = true;
  }
}
