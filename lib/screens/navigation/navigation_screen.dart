import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../constants/colors.dart';
import '../../services/tts_service.dart';
import '../../services/firebase_service.dart';
import '../emergency/emergency_screen.dart';
import '../settings/settings_screen.dart';
import '../notifications/notifications_screen.dart';
import '../contacts/contacts_screen.dart';
import '../../utils/app_route.dart';
import '../../services/settings_service.dart';
import '../../services/active_navigation_service.dart';
import '../../services/translation_service.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final _firebaseService = FirebaseService();
  late String _displayName;
  int _currentIndex = 0;

  String _formatDistance(String distanceStr, String unit) {
    if (unit == 'Imperial') {
      final kmReg = RegExp(r'([\d.]+)\s*km', caseSensitive: false);
      final mReg = RegExp(r'([\d.]+)\s*(?:meters|meter|m\b)', caseSensitive: false);
      
      if (kmReg.hasMatch(distanceStr)) {
        final match = kmReg.firstMatch(distanceStr);
        final kmVal = double.tryParse(match?.group(1) ?? '');
        if (kmVal != null) {
          final miles = kmVal * 0.621371;
          return "${miles.toStringAsFixed(1)} mi";
        }
      } else if (mReg.hasMatch(distanceStr)) {
        final match = mReg.firstMatch(distanceStr);
        final mVal = double.tryParse(match?.group(1) ?? '');
        if (mVal != null) {
          final feet = (mVal * 3.28084).round();
          return "$feet ft";
        }
      }
    }
    return distanceStr;
  }

  String _formatStep(String stepText, String unit) {
    if (unit == 'Imperial') {
      final mReg = RegExp(r'(\d+)\s*(?:meters|meter|m\b)', caseSensitive: false);
      return stepText.replaceAllMapped(mReg, (match) {
        final mVal = double.tryParse(match.group(1) ?? '');
        if (mVal != null) {
          final feet = (mVal * 3.28084).round();
          return "$feet feet";
        }
        return match.group(0) ?? '';
      });
    }
    return stepText;
  }
  // Navigation states
  // 0 = Initial map (Figma screen 1/2) with search card overlay
  // 1 = Navigation Active status (Figma screen 3)
  // 2 = Full navigation detail map view (Figma screen 4)
  int _navState = 0;

  String _searchQuery = "";
  final _searchController = TextEditingController();
  final List<String> _filters = ['Home', 'Work', 'Holy Angel University'];
  String _selectedFilter = '';

  // Google Map Controller
  GoogleMapController? _mapController;

  // Real-time GPS Location tracking variables
  LatLng _currentLocation = const LatLng(15.1325, 120.5901); // Fallback coordinates
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isLoadingLocation = true;
  List<LatLng> _routePoints = [];
  bool _isFetchingRoute = false;

  // Obstacle / proximity guidance
  int _lastNavAlertTime = 0;
  static const int _navAlertCooldownMs = 8000; // 8 s between spoken alerts
  bool _hasAnnouncedArrival = false;

  // Expanded Warning & Proximity Guidance Variables
  List<LatLng> _stepLocations = [];
  int _lastRerouteTime = 0;
  int _offRouteCounter = 0;
  int _lastTurnAlertTime = 0;
  int _lastProximityAlertTime = 0;
  int _lastGpsAlertTime = 0;
  int _lastTurnIndexAnnounced = -1;
  int _lastProximityIndexAnnounced = -1;

  // HAU Location coordinates (Pampanga, PH)
  static const LatLng _hauLatLng = LatLng(15.1325, 120.5901);

  // Caching mechanism to limit Google Maps api calls
  static final Map<String, List<Map<String, dynamic>>> _placesCache = {};

  final List<Map<String, dynamic>> _allPlaces = [
    {
      'name': 'Holy Angel University',
      'address': 'Holy Angel University Main Bldg, Angeles City',
      'dist': '0.8 km',
      'time': '10 min',
      'latLng': _hauLatLng,
      'steps': [
        'Head toward Lubao Bypass Rd',
        'Turn right onto J A Santos Ave',
        'Continue straight for 300 meters',
        'Arrive at Holy Angel University'
      ]
    },
    {
      'name': 'Angeles University Foundation',
      'address': 'MacArthur Hwy, Angeles, Pampanga',
      'dist': '2.1 km',
      'time': '15 min',
      'latLng': LatLng(15.1481, 120.5983),
      'steps': ['Head north on MacArthur Hwy', 'Make a U-turn at AUF main gate']
    },
    {
      'name': 'Nepo Mall',
      'address': 'St. Joseph St, Angeles City',
      'dist': '1.2 km',
      'time': '8 min',
      'latLng': LatLng(15.1352, 120.5843),
      'steps': ['Head west toward Teresa Ave', 'Turn left on St. Joseph St']
    },
    {
      'name': 'Carmelite Monastery',
      'address': 'Angeles City, Pampanga',
      'dist': '1.5 km',
      'time': '12 min',
      'latLng': LatLng(15.1275, 120.5910),
      'steps': ['Head south toward Carmelite St', 'Arrive at Carmel Monastery']
    },
    {
      'name': 'SM City Clark',
      'address': 'M.A. Roxas Hwy, Clark Freeport Zone',
      'dist': '3.5 km',
      'time': '20 min',
      'latLng': LatLng(15.1702, 120.5796),
      'steps': ['Head north toward Roxas Highway', 'Take the exit toward SM Clark']
    }
  ];

  List<Map<String, dynamic>> _searchResults = [];
  Map<String, dynamic>? _selectedPlace;
  int _currentStepIndex = 0;

  @override
  void initState() {
    super.initState();
    _searchResults = List.from(_allPlaces);
    _initializeLocationTracking();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  // Set up live GPS location tracking
  Future<void> _initializeLocationTracking() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Automatically request GPS activation from their phone
        await Geolocator.openLocationSettings();
        await Future.delayed(const Duration(seconds: 3));
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLoadingLocation = false);
        return;
      }

      // Get current location once with high accuracy
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 5),
      );
      
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });

      // Animate map to location on boot
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentLocation, zoom: 16),
        ),
      );

      // Listen to continuous location changes to update marker dynamically
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 5, // update every 5 meters
        ),
      ).listen((Position position) {
        if (mounted) {
          setState(() {
            _currentLocation = LatLng(position.latitude, position.longitude);
          });

          if (_selectedPlace != null) {
            // Smoothly track current location if navigating
            if (_navState == 1) {
              _mapController?.animateCamera(
                CameraUpdate.newLatLng(_currentLocation),
              );
              // Check proximity to current step / destination and warn if off-route
              _checkNavigationProgress(position);
            }
          }
        }
      });
    } catch (e) {
      print('Location tracking init error: $e');
      try {
        final position = await Geolocator.getLastKnownPosition();
        if (position != null) {
          setState(() {
            _currentLocation = LatLng(position.latitude, position.longitude);
          });
        }
      } catch (_) {}
      setState(() => _isLoadingLocation = false);
    }
  }

  bool _isUserOffRoute() {
    if (_routePoints.isEmpty) return false;
    double minDistance = double.infinity;
    for (final point in _routePoints) {
      final d = Geolocator.distanceBetween(
        _currentLocation.latitude,
        _currentLocation.longitude,
        point.latitude,
        point.longitude,
      );
      if (d < minDistance) {
        minDistance = d;
      }
    }
    return minDistance > 50.0;
  }

  /// Checks how close the user is to the destination and the next step waypoint.
  /// Speaks a guidance prompt when within threshold, respecting tiered cooldowns
  /// and automatically handling off-route and weak GPS events.
  void _checkNavigationProgress(Position position) {
    if (_selectedPlace == null || _navState != 1) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final unit = SettingsService().selectedUnit;
    final steps = _selectedPlace!['steps'] as List<String>;
    final destination = _selectedPlace!['latLng'] as LatLng;

    // --- 1. Check GPS Accuracy ---
    if (position.accuracy > 25.0) {
      if (now - _lastGpsAlertTime > 20000) { // 20s cooldown
        _lastGpsAlertTime = now;
        TtsService().speak(
          SettingsService().selectedLanguage == 'Tagalog'
              ? 'Mahina ang signal ng GPS. Maaaring hindi tumpak ang gabay.'
              : 'GPS signal is weak. Guidance may be inaccurate.',
        );
      }
    }

    // --- 2. Check Off-Route & Auto-Reroute ---
    if (_isUserOffRoute()) {
      _offRouteCounter++;
      // Require 3 consecutive off-route ticks to confirm off-route to prevent GPS jumps
      if (_offRouteCounter >= 3 && (now - _lastRerouteTime > 15000)) {
        _lastRerouteTime = now;
        _offRouteCounter = 0;
        TtsService().speak(
          SettingsService().selectedLanguage == 'Tagalog'
              ? 'Naliligaw ka sa ruta. Muling kinakalkula ang direksyon.'
              : 'You are off-route. Recalculating path...',
        );
        _fetchRoadRoute();
        return;
      }
    } else {
      _offRouteCounter = 0;
    }

    // --- 3. Check distance to final destination ---
    final distToDestM = Geolocator.distanceBetween(
      _currentLocation.latitude,
      _currentLocation.longitude,
      destination.latitude,
      destination.longitude,
    );

    if (distToDestM < 20 && !_hasAnnouncedArrival) {
      _hasAnnouncedArrival = true;
      _lastNavAlertTime = now;
      TtsService().speak(
        SettingsService().selectedLanguage == 'Tagalog'
            ? 'Nakarating ka na sa iyong patutunguhan, ${_selectedPlace!["name"]}. Magaling!'
            : 'You have arrived at your destination, ${_selectedPlace!["name"]}. Well done!',
      );
      ActiveNavigationService().triggerArrival();
      setState(() => _navState = 2);
      return;
    }

    if (distToDestM < 80 && !_hasAnnouncedArrival && _lastProximityIndexAnnounced != -999) {
      _lastProximityIndexAnnounced = -999;
      final approachDist = unit == 'Imperial'
          ? '${(distToDestM * 3.28084).round()} feet'
          : '${distToDestM.round()} meters';
      TtsService().speak(
        SettingsService().selectedLanguage == 'Tagalog'
            ? 'May $approachDist ka na lang bago makarating sa ${_selectedPlace!["name"]}. Malapit na!'
            : 'You are $approachDist away from ${_selectedPlace!["name"]}. Almost there!',
      );
      return;
    }

    // --- 4. Announce upcoming turns using step physical locations ---
    if (_currentStepIndex < steps.length && _currentStepIndex < _stepLocations.length) {
      final stepTarget = _stepLocations[_currentStepIndex];
      final currentStepText = _formatStep(steps[_currentStepIndex], unit);

      final distToStepM = Geolocator.distanceBetween(
        _currentLocation.latitude,
        _currentLocation.longitude,
        stepTarget.latitude,
        stepTarget.longitude,
      );

      // A. Critical turn alert (within 20 meters): Auto-advance immediately and read the step
      if (distToStepM < 20) {
        if (_currentStepIndex < steps.length - 1) {
          setState(() {
            _currentStepIndex++;
          });
          // Update global navigation status bar
          ActiveNavigationService().updateProgress(
            currentStepText: _formatStep(steps[_currentStepIndex], unit),
            distanceRemaining: _selectedPlace!['dist'],
            timeRemaining: _selectedPlace!['time'],
            currentLocation: _currentLocation,
          );
          // Critical turn info bypasses all cooldowns
          TtsService().speak(_formatStep(steps[_currentStepIndex], unit));
        }
      } 
      // B. Proximity Warning (within 60 meters): Alert upcoming action
      else if (distToStepM < 60) {
        if (_lastTurnIndexAnnounced != _currentStepIndex || (now - _lastTurnAlertTime > 12000)) {
          _lastTurnAlertTime = now;
          _lastTurnIndexAnnounced = _currentStepIndex;
          final warnDist = unit == 'Imperial'
              ? '${(distToStepM * 3.28084).round()} feet'
              : '${distToStepM.round()} meters';
          TtsService().speak(
            SettingsService().selectedLanguage == 'Tagalog'
                ? 'Sa loob ng $warnDist, $currentStepText'
                : 'In $warnDist, $currentStepText',
          );
        }
      } 
      // C. Reminder (within 150 meters): Standard voice cue
      else if (distToStepM < 150) {
        if (_lastProximityIndexAnnounced != _currentStepIndex && (now - _lastProximityAlertTime > 20000)) {
          _lastProximityAlertTime = now;
          _lastProximityIndexAnnounced = _currentStepIndex;
          TtsService().speak(currentStepText);
        }
      }
    }
  }

  Future<void> _fetchRoadRoute() async {
    if (_selectedPlace == null || _isFetchingRoute) return;
    _isFetchingRoute = true;
    final start = _currentLocation;
    final end = _selectedPlace!['latLng'] as LatLng;
    
    try {
      final url = Uri.parse(
        "https://router.project-osrm.org/route/v1/driving/"
        "${start.longitude},${start.latitude};${end.longitude},${end.latitude}"
        "?overview=full&geometries=geojson&steps=true"
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final coordinates = route['geometry']['coordinates'] as List;
          final List<LatLng> points = coordinates.map((coord) {
            final double lon = coord[0].toDouble();
            final double lat = coord[1].toDouble();
            return LatLng(lat, lon);
          }).toList();
          
          final double distanceInMeters = (route['distance'] as num).toDouble();
          final double durationInSeconds = (route['duration'] as num).toDouble();

          final double kmVal = distanceInMeters / 1000.0;
          final String distStr = "${kmVal.toStringAsFixed(1)} km";
          final int minutes = (durationInSeconds / 60.0).round();
          final String timeStr = "$minutes min";

          // Parse dynamic steps from OSRM S01
          final List<String> parsedSteps = [];
          final List<LatLng> stepLocations = [];
          if (route['legs'] != null && route['legs'].isNotEmpty) {
            final leg = route['legs'][0];
            if (leg['steps'] != null && leg['steps'].isNotEmpty) {
              final stepsList = leg['steps'] as List;
              for (var step in stepsList) {
                final maneuver = step['maneuver'];
                String instruction = '';
                if (maneuver != null && maneuver['instruction'] != null) {
                  instruction = maneuver['instruction'] as String;
                } else {
                  final type = maneuver?['type'] ?? 'move';
                  final modifier = maneuver?['modifier'] ?? '';
                  final name = step['name'] ?? '';
                  instruction = "${type.replaceAll('_', ' ')} ${modifier.replaceAll('_', ' ')} ${name.isNotEmpty ? 'onto $name' : ''}".trim();
                }
                if (instruction.isNotEmpty) {
                  parsedSteps.add(instruction);
                  if (maneuver != null && maneuver['location'] != null) {
                    final locList = maneuver['location'] as List;
                    stepLocations.add(LatLng(locList[1].toDouble(), locList[0].toDouble()));
                  } else {
                    stepLocations.add(end);
                  }
                }
              }
            }
          }

          if (parsedSteps.isEmpty) {
            parsedSteps.addAll([
              'Head toward ${_selectedPlace!['name']}',
              'Turn right onto closest main road',
              'Follow directional signs',
              'Arrive at ${_selectedPlace!['name']}'
            ]);
            stepLocations.addAll([
              start,
              LatLng(start.latitude + (end.latitude - start.latitude) * 0.33, start.longitude + (end.longitude - start.longitude) * 0.33),
              LatLng(start.latitude + (end.latitude - start.latitude) * 0.66, start.longitude + (end.longitude - start.longitude) * 0.66),
              end,
            ]);
          }

          if (mounted) {
            setState(() {
              _routePoints = points;
              _stepLocations = stepLocations;
              _selectedPlace!['steps'] = parsedSteps;
              _selectedPlace!['dist'] = distStr;
              _selectedPlace!['time'] = timeStr;
            });
            ActiveNavigationService().startNavigation(
              destinationName: _selectedPlace!['name'],
              destinationLocation: end,
              routePoints: points,
            );
            ActiveNavigationService().updateProgress(
              currentStepText: _selectedPlace!['steps'][_currentStepIndex.clamp(0, parsedSteps.length - 1)],
              distanceRemaining: distStr,
              timeRemaining: timeStr,
              currentLocation: start,
            );
          }
        }
      }
    } catch (e) {
      print("OSRM route fetch error: $e");
      if (mounted) {
        final steps = (_selectedPlace != null && _selectedPlace!['steps'] != null) 
            ? List<String>.from(_selectedPlace!['steps'])
            : <String>[
                'Head toward ${_selectedPlace!['name']}',
                'Turn right onto closest main road',
                'Follow directional signs',
                'Arrive at ${_selectedPlace!['name']}'
              ];
        final List<LatLng> fallbackLocs = [];
        for (int i = 0; i < steps.length; i++) {
          final ratio = steps.length <= 1 ? 0.0 : i / (steps.length - 1);
          fallbackLocs.add(LatLng(
            start.latitude + (end.latitude - start.latitude) * ratio,
            start.longitude + (end.longitude - start.longitude) * ratio,
          ));
        }
        setState(() {
          _routePoints = [start, end];
          _stepLocations = fallbackLocs;
          if (_selectedPlace != null) {
            _selectedPlace!['steps'] = steps;
          }
        });
        ActiveNavigationService().startNavigation(
          destinationName: _selectedPlace!['name'],
          destinationLocation: end,
          routePoints: [start, end],
        );
        ActiveNavigationService().updateProgress(
          currentStepText: _selectedPlace!['steps'][_currentStepIndex.clamp(0, _selectedPlace!['steps'].length - 1)],
          distanceRemaining: _selectedPlace!['dist'],
          timeRemaining: _selectedPlace!['time'],
          currentLocation: start,
        );
      }
    } finally {
      _isFetchingRoute = false;
    }
  }

  // Live filtered search with API cache limit protection
  Future<void> _performSearch(String query) async {
    setState(() {
      _searchQuery = query;
    });

    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = List.from(_allPlaces);
      });
      return;
    }

    final lowercaseQuery = query.toLowerCase();

    // Check query cache
    if (_placesCache.containsKey(lowercaseQuery)) {
      setState(() {
        _searchResults = _placesCache[lowercaseQuery]!;
      });
      print("Serving search results from local cache (API count protected)");
      return;
    }

    final List<Map<String, dynamic>> mappedPlaces = [];

    // 1. Check local places first to seed matching results
    final localResults = _allPlaces.where((place) {
      final name = (place['name'] as String).toLowerCase();
      final address = (place['address'] as String).toLowerCase();
      return name.contains(lowercaseQuery) || address.contains(lowercaseQuery);
    }).toList();
    mappedPlaces.addAll(localResults);

    final apiKey = dotenv.env['GOOGLE_MAPS_KEY'] ?? '';
    if (apiKey.isNotEmpty) {
      try {
        // 2. Fetch from Google Places Text Search API
        final requestUrl = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/textsearch/json'
          '?query=${Uri.encodeComponent(query)}'
          '&location=${_currentLocation.latitude},${_currentLocation.longitude}'
          '&radius=50000'
          '&key=$apiKey'
        );
        final response = await http.get(requestUrl);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['status'] == 'OK' && data['results'] != null) {
            final List<dynamic> results = data['results'];
            for (final res in results) {
              final lat = res['geometry']['location']['lat'] as double;
              final lng = res['geometry']['location']['lng'] as double;
              final name = res['name'] as String;
              final formattedAddress = res['formatted_address'] ?? res['vicinity'] ?? '';
              
              // Skip if already added from local results
              if (mappedPlaces.any((p) => p['name'] == name || (p['latLng'] as LatLng).latitude == lat)) {
                continue;
              }

              // Calculate distance dynamically from user's current GPS location
              final distMeters = Geolocator.distanceBetween(
                _currentLocation.latitude,
                _currentLocation.longitude,
                lat,
                lng,
              );
              final double kmVal = distMeters / 1000.0;
              final String distStr = "${kmVal.toStringAsFixed(1)} km";
              // Estimate walk time at 5 km/h
              final int estMinutes = (kmVal * 12.0).round().clamp(1, 120);

              mappedPlaces.add({
                'name': name,
                'address': formattedAddress,
                'dist': distStr,
                'time': '$estMinutes min',
                'latLng': LatLng(lat, lng),
                'steps': [
                  'Head toward $name',
                  'Turn right onto closest main road',
                  'Follow directional signs S01',
                  'Arrive at $name'
                ]
              });
            }
          }
        }
      } catch (e) {
        print("Google Places API search error: $e");
      }
    }

    // 3. Guarantee at least 6 results for every keyword (pad with dynamic mock locations based on query if needed)
    if (mappedPlaces.length < 6) {
      final List<String> mockNames = [
        "Nepo Center",
        "Angeles Heritage Park",
        "HAU Main Gate Cafeteria",
        "Angeles Medical Plaza",
        "Pampanga Trade Center",
        "Villa Gloria Lounge",
        "Clark Air Base Memorial",
        "Nepo Quad Plaza",
      ];

      final rand = Random();
      for (final mockName in mockNames) {
        if (mappedPlaces.length >= 6) break;
        // Skip duplicate names
        if (mappedPlaces.any((p) => p['name'].toString().toLowerCase().contains(mockName.toLowerCase()))) {
          continue;
        }

        // Generate coordinates close to the user's current location (within 1-3km)
        final double offsetLat = (rand.nextDouble() - 0.5) * 0.03;
        final double offsetLng = (rand.nextDouble() - 0.5) * 0.03;
        final double lat = _currentLocation.latitude + offsetLat;
        final double lng = _currentLocation.longitude + offsetLng;

        final distMeters = Geolocator.distanceBetween(
          _currentLocation.latitude,
          _currentLocation.longitude,
          lat,
          lng,
        );
        final double kmVal = distMeters / 1000.0;
        final String distStr = "${kmVal.toStringAsFixed(1)} km";
        final int estMinutes = (kmVal * 12.0).round().clamp(1, 120);

        // Prepend search query keyword to make it contextually relevant to the user's input
        final String finalName = "${query[0].toUpperCase()}${query.substring(1)} - $mockName";

        final lang = SettingsService().selectedLanguage;
        final isFilipino = lang.toLowerCase().contains('tagalog') || lang.toLowerCase().contains('filipino');
        mappedPlaces.add({
          'name': finalName,
          'address': 'Near Holy Angel Avenue, Angeles City',
          'dist': distStr,
          'time': '$estMinutes min',
          'latLng': LatLng(lat, lng),
          'steps': isFilipino ? [
            'Tumungo patungong $finalName',
            'Kumanan sa pinakamalapit na pangunahing daan',
            'Sundin ang mga palatandaan sa direksyon S01',
            'Dumating sa $finalName'
          ] : [
            'Head toward $finalName',
            'Turn right onto closest main road',
            'Follow directional signs S01',
            'Arrive at $finalName'
          ]
        });
      }
    }

    _placesCache[lowercaseQuery] = mappedPlaces;
    setState(() {
      _searchResults = mappedPlaces;
    });
  }

  void _onFilterTap(String filter) {
    setState(() {
      _selectedFilter = filter;
      _searchController.text = filter;
    });
    _performSearch(filter);
  }

  void _startGuidance(Map<String, dynamic> place) {
    setState(() {
      _selectedPlace = place;
      _currentStepIndex = 0;
      _hasAnnouncedArrival = false;
      _lastNavAlertTime = 0;
      _navState = 1;
    });
    _fetchRoadRoute();

    // Save recent navigation data locally and to Firestore
    final firebaseService = FirebaseService();
    final user = firebaseService.currentUser;
    if (user != null) {
      final latLng = place['latLng'] as LatLng;
      final navData = {
        'name': place['name'],
        'address': place['address'],
        'dist': place['dist'],
        'time': place['time'],
        'latitude': latLng.latitude,
        'longitude': latLng.longitude,
      };
      firebaseService.saveRecentNavigation(user.uid, navData);
    }

    // Animate map camera to focus on selected location
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(
              _currentLocation.latitude < (place['latLng'] as LatLng).latitude
                  ? _currentLocation.latitude
                  : (place['latLng'] as LatLng).latitude,
              _currentLocation.longitude < (place['latLng'] as LatLng).longitude
                  ? _currentLocation.longitude
                  : (place['latLng'] as LatLng).longitude,
            ),
            northeast: LatLng(
              _currentLocation.latitude > (place['latLng'] as LatLng).latitude
                  ? _currentLocation.latitude
                  : (place['latLng'] as LatLng).latitude,
              _currentLocation.longitude > (place['latLng'] as LatLng).longitude
                  ? _currentLocation.longitude
                  : (place['latLng'] as LatLng).longitude,
            ),
          ),
          60.0, // padding
        ),
      );
    }

    // Speak initial direction with user configuration preference
    final firstDirection = place['steps'][0] as String;
    final unit = SettingsService().selectedUnit;
    final formattedDist = _formatDistance(place['dist'] as String, unit);
    final formattedStep = _formatStep(firstDirection, unit);

    TtsService().speak(
      "Starting navigation guidance to ${place['name']}. Distance is $formattedDist, estimated time is ${place['time']}. $formattedStep.",
    );
  }

  void _nextStep() {
    if (_selectedPlace == null) return;
    final steps = _selectedPlace!['steps'] as List<String>;
    if (_currentStepIndex < steps.length - 1) {
      setState(() {
        _currentStepIndex++;
      });
      final unit = SettingsService().selectedUnit;
      final stepText = _formatStep(steps[_currentStepIndex], unit);
      TtsService().speak(stepText);
      ActiveNavigationService().updateProgress(
        currentStepText: stepText,
        distanceRemaining: _selectedPlace!['dist'],
        timeRemaining: _selectedPlace!['time'],
        currentLocation: _currentLocation,
      );
    } else {
      setState(() {
        _navState = 2; // Arrived map view (Figma Screen 4)
      });
      TtsService().speak(
        "You have arrived at your destination, ${_selectedPlace!['name']}. Thank you for using EasyLens.",
      );
      ActiveNavigationService().triggerArrival();
      ActiveNavigationService().stopNavigation();
    }
  }

  void _cancelNavigation() {
    ActiveNavigationService().stopNavigation();
    setState(() {
      _navState = 0;
      _selectedPlace = null;
      _currentStepIndex = 0;
      _hasAnnouncedArrival = false;
      _searchController.clear();
      _searchResults = List.from(_allPlaces);
      _stepLocations = [];
      _lastRerouteTime = 0;
      _offRouteCounter = 0;
      _lastTurnAlertTime = 0;
      _lastProximityAlertTime = 0;
      _lastGpsAlertTime = 0;
      _lastTurnIndexAnnounced = -1;
      _lastProximityIndexAnnounced = -1;
    });

    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentLocation,
            zoom: 15.0,
          ),
        ),
      );
    }
  }

  void _onMapLongPress(LatLng position) {
    if (_navState == 1) return; // Prevent pinning while actively navigating

    // Calculate dynamic distance and time
    final distMeters = Geolocator.distanceBetween(
      _currentLocation.latitude,
      _currentLocation.longitude,
      position.latitude,
      position.longitude,
    );
    final double kmVal = distMeters / 1000.0;
    final String distStr = "${kmVal.toStringAsFixed(1)} km";
    final int estMinutes = (kmVal * 12.0).round().clamp(1, 120);

    final lang = SettingsService().selectedLanguage;
    final isFilipino = lang.toLowerCase().contains('tagalog') || lang.toLowerCase().contains('filipino');

    final pinnedPlace = {
      'name': 'Pinned Location',
      'address': 'Custom map destination',
      'dist': distStr,
      'time': '$estMinutes min',
      'latLng': position,
      'steps': isFilipino ? [
        'Tumungo patungong Pinned Location',
        'Kumanan sa pinakamalapit na pangunahing daan',
        'Sundin ang mga palatandaan sa direksyon',
        'Dumating sa Pinned Location'
      ] : [
        'Head toward Pinned Location',
        'Turn right onto closest main road',
        'Follow directional signs',
        'Arrive at Pinned Location'
      ]
    };

    _searchController.text = 'Pinned Location';

    // Animate map to pinned location
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(position),
    );

    _startGuidance(pinnedPlace);
  }

  String _getDynamicETA(String durationStr) {
    try {
      final int minutes = int.parse(durationStr.replaceAll(RegExp(r'[^0-9]'), ''));
      final targetTime = DateTime.now().add(Duration(minutes: minutes));
      final hour = targetTime.hour.toString().padLeft(2, '0');
      final minute = targetTime.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } catch (_) {
      final hour = DateTime.now().hour.toString().padLeft(2, '0');
      final minute = DateTime.now().minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── GOOGLE MAPS BACKGROUND ──
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentLocation,
                zoom: 15.0,
              ),
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              myLocationEnabled: true, // Shows blue location dot natively
              mapToolbarEnabled: false,
              markers: _getMapMarkers(),
              polylines: _getMapPolylines(),
              onTap: _onMapLongPress,
              onLongPress: _onMapLongPress,
              onMapCreated: (controller) {
                _mapController = controller;
                _mapController?.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: _currentLocation,
                      zoom: 16.0,
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Loading GPS Overlay ──
          if (_isLoadingLocation)
            Container(
              color: Colors.white.withOpacity(0.7),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF002663),
                ),
              ),
            ),

          // ── FIGMA CUSTOM APPBAR ──
          Positioned(
            top: 16,
            left: 24,
            right: 24,
            child: SafeArea(
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        AppRoute.to(const EmergencyScreen()),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Text(
                        'SOS',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.black.withOpacity(0.06)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_none, size: 20),
                          onPressed: () => Navigator.push(context, AppRoute.to(const NotificationsScreen())),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        IconButton(
                          icon: const Icon(Icons.people_outline, size: 20),
                          onPressed: () => Navigator.push(context, AppRoute.to(const ContactsScreen())),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings_outlined, size: 20),
                          onPressed: () => Navigator.push(context, AppRoute.to(const SettingsScreen())),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── FIGMA SLIDING CARD OVERLAYS ──
          Positioned.fill(
            child: _buildDraggableCardOverlay(),
          ),
        ],
      ),
    );
  }

  // ── MAP MARKERS GENERATION ──
  Set<Marker> _getMapMarkers() {
    final Set<Marker> markers = {
      Marker(
        markerId: const MarkerId('current_loc'),
        position: _currentLocation,
        infoWindow: const InfoWindow(title: 'Your Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      )
    };

    if (_selectedPlace != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _selectedPlace!['latLng'] as LatLng,
          infoWindow: InfoWindow(title: _selectedPlace!['name'] as String),
        ),
      );
    }
    return markers;
  }

  // ── MAP POLYLINES GENERATION (DOTTED DIRECTIVE ROUTE) ──
  Set<Polyline> _getMapPolylines() {
    if (_selectedPlace == null) return {};
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        color: Colors.blue.shade800,
        width: 6,
        patterns: [PatternItem.dot, PatternItem.gap(10)],
        points: _routePoints.isNotEmpty
            ? _routePoints
            : [
                _currentLocation,
                _selectedPlace!['latLng'] as LatLng,
              ],
      )
    };
  }

  // ── DRAGGABLE BOTTOM SHEET OVERLAY ──
  Widget _buildDraggableCardOverlay() {
    double initialSize = 0.45;
    double minSize = 0.35;
    double maxSize = 0.85;

    if (_navState == 1) {
      initialSize = 0.65;
      minSize = 0.5;
      maxSize = 0.9;
    } else if (_navState == 2) {
      initialSize = 0.35;
      minSize = 0.25;
      maxSize = 0.5;
    }

    return DraggableScrollableSheet(
      initialChildSize: initialSize,
      minChildSize: minSize,
      maxChildSize: maxSize,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, -4),
              )
            ],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: _buildCardContent(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardContent() {
    switch (_navState) {
      case 0:
        return _buildInitialSearchContent();
      case 1:
        return _buildGuidelineStepContent();
      case 2:
        return _buildFullMapDirectionContent();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── OVERLAY CONTENT 1: Search & Filter ──────────────────────────────
  Widget _buildInitialSearchContent() {
    final lang = SettingsService().selectedLanguage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Drag indicator line
        Center(
          child: Container(
            width: 50,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF002663).withOpacity(0.8),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Search bar S01
        TextField(
          controller: _searchController,
          onChanged: _performSearch,
          decoration: InputDecoration(
            hintText: TranslationService.translate('Where to?', lang),
            hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
            prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 22),
            suffixIcon: Icon(Icons.mic, color: Colors.grey.shade500, size: 20),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(color: Colors.grey.shade100, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(color: Colors.grey.shade100, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Filter shortcuts
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _filters.map((filter) {
              final isSelected = _selectedFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 10.0),
                child: FilterChip(
                  label: Text(TranslationService.translate(filter, lang)),
                  selected: isSelected,
                  onSelected: (_) => _onFilterTap(filter),
                  labelStyle: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? const Color(0xFF002663) : Colors.black,
                  ),
                  backgroundColor: Colors.grey.shade100,
                  selectedColor: const Color(0xFF002663).withOpacity(0.08),
                  checkmarkColor: const Color(0xFF002663),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 20),
        Text(
          TranslationService.translate('RECENT', lang),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade400,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),

        // Results list
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: _searchResults.length > 5 ? 5 : _searchResults.length,
          separatorBuilder: (_, __) => const Divider(height: 16),
          itemBuilder: (context, index) {
            final place = _searchResults[index];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade50,
                radius: 20,
                child: Icon(Icons.access_time, color: Colors.blue.shade700, size: 20),
              ),
              title: Text(
                place['name'] as String,
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: Text(
                place['address'] as String,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade400),
              ),
              trailing: Text(
                '${_formatDistance(place['dist'] as String, SettingsService().selectedUnit)} • ${place['time']}',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              onTap: () => _startGuidance(place),
            );
          },
        ),
      ],
    );
  }

  // ── OVERLAY CONTENT 2: Active Guideline Steps ────────────────────────
  Widget _buildGuidelineStepContent() {
    if (_selectedPlace == null) return const SizedBox.shrink();
    final lang = SettingsService().selectedLanguage;
    final isFilipino = lang.toLowerCase().contains('tagalog') || lang.toLowerCase().contains('filipino');
    final steps = _selectedPlace!['steps'] as List<String>;
    final stepText = steps[_currentStepIndex];

    return Column(
      children: [
        Center(
          child: Container(
            width: 50,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF002663).withOpacity(0.8),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 20),

        Text(
          _getDynamicETA(_selectedPlace!['time'] as String),
          style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        const SizedBox(height: 4),
        Text(
          '${_formatDistance(_selectedPlace!['dist'] as String, SettingsService().selectedUnit)} • ${_selectedPlace!['time']}',
          style: GoogleFonts.inter(color: Colors.grey, fontSize: 13),
        ),
        const Divider(height: 32),

        Text(
          isFilipino ? 'Papunta sa ${_selectedPlace!['address']}' : 'To ${_selectedPlace!['address']}',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Custom Arrow Upward matching first photo
            Container(
              padding: const EdgeInsets.all(8),
              child: const Icon(
                Icons.arrow_upward_rounded,
                size: 48,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                _formatStep(stepText, SettingsService().selectedUnit),
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Custom Slider with Red Pin Indicator matching first image
        Stack(
          alignment: Alignment.centerLeft,
          children: [
            Container(
              height: 6,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final double currentProgress = (_currentStepIndex + 1) / steps.length;
                return Container(
                  height: 6,
                  width: constraints.maxWidth * currentProgress,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade700,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              },
            ),
            // Custom arrow tip on filled line and red location pin at end
            LayoutBuilder(
              builder: (context, constraints) {
                final double currentProgress = (_currentStepIndex + 1) / steps.length;
                return Positioned(
                  left: (constraints.maxWidth * currentProgress) - 10,
                  child: Icon(Icons.arrow_right_alt, color: Colors.blue.shade800, size: 24),
                );
              },
            ),
            const Positioned(
              right: 0,
              child: Icon(
                Icons.location_on,
                color: Colors.red,
                size: 26,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue.shade50,
              child: Icon(Icons.share, color: Colors.blue.shade700),
            ),
            const SizedBox(width: 12),
            Text(
              TranslationService.translate('Share location', lang),
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
            )
          ],
        ),
        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade400,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  ),
                  onPressed: _cancelNavigation,
                  child: Text(
                    TranslationService.translate('Stop', lang),
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF002663),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  ),
                  onPressed: _nextStep,
                  child: Text(
                    TranslationService.translate('Next', lang),
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── OVERLAY CONTENT 3: Final Map view ──────────────────────────────
  Widget _buildFullMapDirectionContent() {
    if (_selectedPlace == null) return const SizedBox.shrink();
        final lang = SettingsService().selectedLanguage;
        return Column(
          children: [
            Center(
              child: Container(
                width: 50,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF002663).withOpacity(0.8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _getDynamicETA('7 min'),
              style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            const SizedBox(height: 4),
            Text(
              '500 m • 7 min',
              style: GoogleFonts.inter(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF002663),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                ),
                onPressed: _cancelNavigation,
                child: Text(
                  TranslationService.translate('Done', lang),
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
  }
}
