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
import '../../widgets/speech_navigation_overlay.dart';
import '../../widgets/screen_tutorial_card.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:typed_data';
import '../../services/danger_warning_service.dart';
import '../../widgets/critical_danger_overlay.dart';
import '../../services/navigation_voice_assistant.dart';

class NavigationScreen extends StatefulWidget {
  final bool isActive;
  const NavigationScreen({super.key, this.isActive = true});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {

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

  final _searchController = TextEditingController();
  final List<String> _filters = ['Home', 'Work', 'Holy Angel University'];
  String _selectedFilter = '';

  // Google Map Controller & Native Map availability flag
  GoogleMapController? _mapController;
  bool _isNativeMapAvailable = true;

  LatLng _currentLocation = const LatLng(15.1325, 120.5901); // Fallback coordinates
  StreamSubscription<Position>? _positionStreamSubscription;
  List<LatLng> _routePoints = [];
  bool _isFetchingRoute = false;

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
  double? _lastDynamicAnnouncedDistanceM;

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
  Map<String, dynamic>? _pendingPlaceToConfirm;
  int _currentStepIndex = 0;

  void _updateSearchResults(List<Map<String, dynamic>> results) {
    setState(() {
      _searchResults = results;
    });
    SpeechNavigationNotifier.activeSearchResults = results;
  }

  void _activateVoiceSearch() {
    NavigationVoiceAssistant.activateSearchAssistant(
      context: context,
      onQueryDiscovered: (query) {
        if (mounted) {
          _searchController.text = query;
          _performSearch(query);
        }
      },
      getSearchResults: () => _searchResults,
      onPlaceConfirmed: (place) {
        if (mounted) {
          _requestNavigationConfirmation(place);
        }
      },
    );
  }

  void _onVoiceSearchRequested() {
    final query = SpeechNavigationNotifier.searchPlaceNotifier.value;
    if (query != null && query.isNotEmpty && mounted) {
      _searchController.text = query;
      _performSearch(query);
    }
  }

  void _onVoiceSelectRequested() {
    final index = SpeechNavigationNotifier.selectResultNotifier.value;
    if (index != null && index >= 0 && index < _searchResults.length && mounted) {
      final place = _searchResults[index];
      _requestNavigationConfirmation(place);
    }
  }

  void _onVoiceConfirmRequested() {
    final place = SpeechNavigationNotifier.confirmPlaceNotifier.value;
    if (place != null && mounted) {
      _confirmPendingNavigation();
    }
  }

  void _onVoiceStopRouteRequested() {
    if (SpeechNavigationNotifier.stopRouteNotifier.value == true && mounted) {
      _cancelNavigation();
    }
  }

  Map<String, String> _calculateDistanceAndTime(LatLng destination) {
    final distMeters = Geolocator.distanceBetween(
      _currentLocation.latitude,
      _currentLocation.longitude,
      destination.latitude,
      destination.longitude,
    );
    final double kmVal = distMeters / 1000.0;
    
    int estMinutes = (kmVal * 12.0).round();
    if (estMinutes < 1) estMinutes = 1;

    String distStr;
    if (kmVal < 0.1) {
      distStr = "${distMeters.round()} m";
    } else {
      distStr = "${kmVal.toStringAsFixed(1)} km";
    }

    String timeStr = "$estMinutes min";
    if (estMinutes >= 60) {
      final hours = estMinutes ~/ 60;
      final mins = estMinutes % 60;
      timeStr = mins > 0 ? "$hours hr $mins min" : "$hours hr";
    }

    return {
      'dist': distStr,
      'time': timeStr,
    };
  }

  void _requestNavigationConfirmation(Map<String, dynamic> place) {
    final lang = SettingsService().selectedLanguage;
    final isTagalog = lang.toLowerCase().contains('tagalog') || lang.toLowerCase().contains('filipino');
    
    if (place['latLng'] is LatLng) {
      final calc = _calculateDistanceAndTime(place['latLng'] as LatLng);
      place['dist'] = calc['dist']!;
      place['time'] = calc['time']!;
    }

    setState(() {
      _pendingPlaceToConfirm = place;
    });

    final placeName = place['name'] as String;
    final prompt = isTagalog
        ? "Kumpirmahin ang paglakad patungo sa $placeName. Sabihin ang 'Oo', 'Kumpirmahin', o 'Sige' para simulan ang ruta, o 'Hindi' para kanselahin."
        : "Confirm navigation to $placeName? Say 'Yes', 'Confirm', or 'Search' to start guidance, or 'No' to cancel.";
    
    TtsService().speak(prompt);
  }

  void _confirmPendingNavigation() {
    if (_pendingPlaceToConfirm == null) return;
    final place = _pendingPlaceToConfirm!;
    setState(() {
      _pendingPlaceToConfirm = null;
    });
    _startGuidance(place);
  }

  void _cancelPendingNavigation() {
    final lang = SettingsService().selectedLanguage;
    final isTagalog = lang.toLowerCase().contains('tagalog') || lang.toLowerCase().contains('filipino');
    setState(() {
      _pendingPlaceToConfirm = null;
    });
    TtsService().speak(isTagalog ? "Kinansela ang paghahanap ng ruta." : "Navigation setup cancelled.");
  }

  void _clearHazardAlert() {
    ActiveNavigationService().clearHazardAlert();
    if (mounted) setState(() {});
  }


  final _firebaseService = FirebaseService();

  Future<void> _loadRecentNavigations() async {
    try {
      final user = _firebaseService.currentUser;
      final rawRecents = await _firebaseService.getRecentNavigations(user?.uid);
      if (rawRecents.isNotEmpty && mounted) {
        final List<Map<String, dynamic>> parsed = [];
        for (final item in rawRecents) {
          double lat = 0.0;
          double lng = 0.0;
          if (item['latLng'] is LatLng) {
            final l = item['latLng'] as LatLng;
            lat = l.latitude;
            lng = l.longitude;
          } else if (item['latitude'] != null && item['longitude'] != null) {
            lat = (item['latitude'] as num).toDouble();
            lng = (item['longitude'] as num).toDouble();
          }

          if (lat != 0.0 && lng != 0.0) {
            final calc = _calculateDistanceAndTime(LatLng(lat, lng));
            parsed.add({
              'name': item['name'] ?? 'Recent Location',
              'address': item['address'] ?? '',
              'dist': calc['dist']!,
              'time': calc['time']!,
              'latLng': LatLng(lat, lng),
              'steps': item['steps'] ?? [
                'Head toward ${item['name']}',
                'Turn right onto closest main road',
                'Follow directional signs',
                'Arrive at ${item['name']}'
              ],
            });
          }
        }

        if (parsed.isNotEmpty) {
          setState(() {
            final Set<String> recentNames = parsed.map((e) => e['name'].toString().toLowerCase()).toSet();
            final remainingDefaults = _allPlaces.where((p) => !recentNames.contains(p['name'].toString().toLowerCase())).toList();
            _searchResults = [...parsed, ...remainingDefaults];
            SpeechNavigationNotifier.activeSearchResults = _searchResults;
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading recent navigations: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _searchResults = List.from(_allPlaces);
    SpeechNavigationNotifier.activeSearchResults = _searchResults;
    _initializeLocationTracking();
    _loadRecentNavigations();
    SpeechNavigationNotifier.searchPlaceNotifier.addListener(_onVoiceSearchRequested);
    SpeechNavigationNotifier.selectResultNotifier.addListener(_onVoiceSelectRequested);
    SpeechNavigationNotifier.confirmPlaceNotifier.addListener(_onVoiceConfirmRequested);
    SpeechNavigationNotifier.stopRouteNotifier.addListener(_onVoiceStopRouteRequested);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScreenTutorialCard.showIfNeeded(
        context,
        tutorialKey: 'navigation',
        titleKey: 'tutorial_navigation_title',
        descriptionKey: 'tutorial_navigation_desc',
        mascotAsset: 'assets/Mascots/03 Loading.gif',
      );

      final activeNav = ActiveNavigationService();
      if (activeNav.isNavigating && activeNav.activePlace != null) {
        setState(() {
          _selectedPlace = Map<String, dynamic>.from(activeNav.activePlace!);
          _routePoints = List<LatLng>.from(activeNav.routePoints);
          _stepLocations = List<LatLng>.from(activeNav.stepLocations);
          _currentStepIndex = activeNav.currentStepIndex;
          _lastDynamicAnnouncedDistanceM = null;
          _navState = 1;
        });
        if (activeNav.destinationLocation != null) {
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(activeNav.destinationLocation!, 16.0),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    SpeechNavigationNotifier.searchPlaceNotifier.removeListener(_onVoiceSearchRequested);
    SpeechNavigationNotifier.selectResultNotifier.removeListener(_onVoiceSelectRequested);
    SpeechNavigationNotifier.confirmPlaceNotifier.removeListener(_onVoiceConfirmRequested);
    SpeechNavigationNotifier.stopRouteNotifier.removeListener(_onVoiceStopRouteRequested);
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
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      // Get current location once with high accuracy
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 5),
      );
      
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
      }

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

      // A2. Periodic 30m voice guidance update
      if (_lastDynamicAnnouncedDistanceM == null) {
        _lastDynamicAnnouncedDistanceM = distToStepM;
      } else {
        final diff = (_lastDynamicAnnouncedDistanceM! - distToStepM).abs();
        if (diff >= 30.0) {
          _lastDynamicAnnouncedDistanceM = distToStepM;
          final announceDist = unit == 'Imperial'
              ? '${(distToStepM * 3.28084).round()} feet'
              : '${distToStepM.round()} meters';
          final isTagalog = SettingsService().selectedLanguage == 'Tagalog';
          TtsService().speak(
            isTagalog
                ? 'Maglakad nang diretso nang $announceDist, tapos $currentStepText'
                : 'Go forward for $announceDist, then $currentStepText'
          );
        }
      }

      // A. Critical turn alert (within 20 meters): Auto-advance immediately and read the step
      if (distToStepM < 20) {
        if (_currentStepIndex < steps.length - 1) {
          setState(() {
            _currentStepIndex++;
            _lastDynamicAnnouncedDistanceM = null;
          });
          // Update global navigation status bar
          ActiveNavigationService().updateProgress(
            currentStepText: _formatStep(steps[_currentStepIndex], unit),
            distanceRemaining: _selectedPlace!['dist'],
            timeRemaining: _selectedPlace!['time'],
            currentLocation: _currentLocation,
            currentStepIndex: _currentStepIndex,
          );
          // Critical turn info bypasses all cooldowns
          TtsService().speak(_formatStep(steps[_currentStepIndex], unit));
        }
      } 
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
              activePlace: _selectedPlace,
              stepLocations: stepLocations,
            );
            ActiveNavigationService().updateProgress(
              currentStepText: _selectedPlace!['steps'][_currentStepIndex.clamp(0, parsedSteps.length - 1)],
              distanceRemaining: distStr,
              timeRemaining: timeStr,
              currentLocation: start,
              currentStepIndex: _currentStepIndex,
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
          activePlace: _selectedPlace,
          stepLocations: fallbackLocs,
        );
        ActiveNavigationService().updateProgress(
          currentStepText: _selectedPlace!['steps'][_currentStepIndex.clamp(0, _selectedPlace!['steps'].length - 1)],
          distanceRemaining: _selectedPlace!['dist'],
          timeRemaining: _selectedPlace!['time'],
          currentLocation: start,
          currentStepIndex: _currentStepIndex,
        );
      }
    } finally {
      _isFetchingRoute = false;
    }
  }

  // Live filtered search with API cache limit protection
  Future<void> _performSearch(String query) async {

    if (query.trim().isEmpty) {
      _updateSearchResults(List.from(_allPlaces));
      return;
    }

    final lowercaseQuery = query.toLowerCase();

    // Check query cache
    if (_placesCache.containsKey(lowercaseQuery)) {
      _updateSearchResults(_placesCache[lowercaseQuery]!);
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
          '&radius=100000'
          '&key=$apiKey'
        );
        final response = await http.get(requestUrl);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['status'] == 'OK' && data['results'] != null) {
            final List<dynamic> results = data['results'];
            for (final res in results) {
              final lat = (res['geometry']['location']['lat'] as num).toDouble();
              final lng = (res['geometry']['location']['lng'] as num).toDouble();
              final name = res['name'] as String;
              final formattedAddress = res['formatted_address'] ?? res['vicinity'] ?? '';
              
              // Skip if already added from local results
              if (mappedPlaces.any((p) => p['name'] == name || (p['latLng'] as LatLng).latitude == lat)) {
                continue;
              }

              final calc = _calculateDistanceAndTime(LatLng(lat, lng));

              mappedPlaces.add({
                'name': name,
                'address': formattedAddress,
                'dist': calc['dist']!,
                'time': calc['time']!,
                'latLng': LatLng(lat, lng),
                'steps': [
                  'Head toward $name',
                  'Turn right onto closest main road',
                  'Follow directional signs',
                  'Arrive at $name'
                ]
              });
            }
          }
        }
      } catch (e) {
        debugPrint("Google Places API search error: $e");
      }
    }

    // 3. Fallback to OpenStreetMap (Nominatim) search if Google Places returns no results
    if (mappedPlaces.isEmpty) {
      try {
        final osmUrl = Uri.parse(
          'https://nominatim.openstreetmap.org/search'
          '?q=${Uri.encodeComponent(query)}'
          '&format=json'
          '&addressdetails=1'
          '&limit=10'
        );
        final response = await http.get(osmUrl, headers: {
          'User-Agent': 'EasyLensApp/1.0 (contact@easylens.com)'
        });
        if (response.statusCode == 200) {
          final List<dynamic> results = jsonDecode(response.body);
          for (final res in results) {
            final lat = double.tryParse(res['lat'].toString()) ?? 0.0;
            final lng = double.tryParse(res['lon'].toString()) ?? 0.0;
            if (lat == 0.0 && lng == 0.0) continue;

            final name = (res['name'] != null && res['name'].toString().isNotEmpty)
                ? res['name'].toString()
                : (res['display_name'] ?? '').toString().split(',')[0];
            final formattedAddress = (res['display_name'] ?? '').toString();

            if (mappedPlaces.any((p) => p['name'] == name || (p['latLng'] as LatLng).latitude == lat)) {
              continue;
            }

            final calc = _calculateDistanceAndTime(LatLng(lat, lng));

            mappedPlaces.add({
              'name': name,
              'address': formattedAddress,
              'dist': calc['dist']!,
              'time': calc['time']!,
              'latLng': LatLng(lat, lng),
              'steps': [
                'Head toward $name',
                'Turn right onto closest main road',
                'Follow directional signs',
                'Arrive at $name'
              ]
            });
          }
        }
      } catch (e) {
        debugPrint("Nominatim search error: $e");
      }
    }

    _placesCache[lowercaseQuery] = mappedPlaces;
    _updateSearchResults(mappedPlaces);
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
      _lastDynamicAnnouncedDistanceM = null;
      _hasAnnouncedArrival = false;
      _navState = 1;
    });
    _fetchRoadRoute();

    // Save recent navigation data locally and to Firestore
    final user = _firebaseService.currentUser;
    if (place['latLng'] is LatLng) {
      final latLng = place['latLng'] as LatLng;
      final navData = {
        'name': place['name'],
        'address': place['address'],
        'dist': place['dist'],
        'time': place['time'],
        'latitude': latLng.latitude,
        'longitude': latLng.longitude,
      };
      _firebaseService.saveRecentNavigation(user?.uid ?? 'guest', navData);
      _loadRecentNavigations();
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
        currentStepIndex: _currentStepIndex,
      );
    } else {
      setState(() {
        _navState = 2; // Arrived map view (Figma Screen 4)
      });
      TtsService().speak(
        "You have arrived at your destination, ${_selectedPlace!['name']}. Thank you for using EasyLens.",
      );
      ActiveNavigationService().triggerArrival();
    }
  }

  void _cancelNavigation() {
    ActiveNavigationService().stopNavigation();
    setState(() {
      _navState = 0;
      _selectedPlace = null;
      _currentStepIndex = 0;
      _lastDynamicAnnouncedDistanceM = null;
      _hasAnnouncedArrival = false;
      _searchController.clear();
      _searchResults = List.from(_allPlaces);
      SpeechNavigationNotifier.activeSearchResults = _searchResults;
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
      try {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: _currentLocation,
              zoom: 15.0,
            ),
          ),
        );
      } catch (e) {
        debugPrint("Map animateCamera error on cancel: $e");
      }
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
    final bool canPop = _navState == 0;
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        final lang = SettingsService().selectedLanguage;
        final isTagalog = lang.toLowerCase().contains('tagalog') || lang.toLowerCase().contains('filipino');
        
        TtsService().speak(
          isTagalog
              ? "Sigurado ka bang nais mong lumabas? Mananatiling aktibo ang iyong nabigasyon sa background."
              : "Are you sure you want to exit? Your navigation will remain active in the background."
        );
        
        final action = await showDialog<String>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                isTagalog ? "Aktibong Nabigasyon" : "Active Navigation",
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
              content: Text(
                isTagalog
                    ? "Nais mo bang lumabas at panatilihin ang nabigasyon, o ganap na ihinto ito?"
                    : "Do you want to exit and keep navigation active, or stop it entirely?",
                style: GoogleFonts.inter(fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop('keep'),
                  child: Text(
                    isTagalog ? "Ipagpatuloy sa Background" : "Keep in Background",
                    style: GoogleFonts.inter(color: const Color(0xFF002663), fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop('stop'),
                  child: Text(
                    isTagalog ? "Ihinto" : "Stop Navigation",
                    style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop('cancel'),
                  child: Text(
                    isTagalog ? "Ipagpatuloy Dito" : "Cancel",
                    style: GoogleFonts.inter(color: Colors.grey),
                  ),
                ),
              ],
            );
          },
        );
        
        if (!context.mounted) return;
        
        if (action == 'stop') {
          _cancelNavigation();
        }
      },
      child: ListenableBuilder(
        listenable: SettingsService(),
        builder: (context, _) {
          final isDefaultTheme = SettingsService().selectedContrastTheme == 'Default';
          return Scaffold(
            backgroundColor: isDefaultTheme ? const Color(0xFFE2E8F0) : AppColors.primaryBackground,
            body: Stack(
              fit: StackFit.expand,
              children: [
          // ── GOOGLE MAPS BACKGROUND WITH STYLIZED CANVAS FALLBACK ──
          Positioned.fill(
            child: SizedBox.expand(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _MapCanvasPainter(
                        isNavigating: _navState == 1 || _selectedPlace != null,
                        destinationName: _selectedPlace != null ? _selectedPlace!['name'] as String? : null,
                      ),
                    ),
                  ),
                  if (_isNativeMapAvailable)
                    Positioned.fill(
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _currentLocation,
                          zoom: 15.0,
                        ),
                        zoomControlsEnabled: false,
                        myLocationButtonEnabled: false,
                        myLocationEnabled: false, // Prevents native SecurityException crash on Android
                        mapToolbarEnabled: false,
                        compassEnabled: false,
                        mapType: MapType.normal,
                        markers: _getMapMarkers(),
                        polylines: _getMapPolylines(),
                        onTap: _onMapLongPress,
                        onLongPress: _onMapLongPress,
                        onMapCreated: (controller) {
                          _mapController = controller;
                          if (mounted) {
                            setState(() {
                              _isNativeMapAvailable = true;
                            });
                          }
                          try {
                            _mapController?.animateCamera(
                              CameraUpdate.newCameraPosition(
                                CameraPosition(
                                  target: _currentLocation,
                                  zoom: 16.0,
                                ),
                              ),
                            );
                          } catch (_) {}
                        },
                      ),
                    ),
                ],
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
                          icon: Icon(
                            _isNativeMapAvailable ? Icons.map : Icons.map_outlined,
                            size: 20,
                            color: _isNativeMapAvailable ? const Color(0xFF002663) : Colors.black87,
                          ),
                          onPressed: () {
                            setState(() {
                              _isNativeMapAvailable = !_isNativeMapAvailable;
                            });
                          },
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
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

          // ── CRITICAL DANGER / HAZARD OVERLAY ──
          ListenableBuilder(
            listenable: ActiveNavigationService(),
            builder: (context, child) {
              if (!ActiveNavigationService().isHazardActive) {
                return const SizedBox.shrink();
              }
              return Positioned(
                top: 80,
                left: 12,
                right: 12,
                child: SafeArea(
                  child: CriticalDangerOverlay(
                    severity: ActiveNavigationService().hazardSeverity,
                    title: ActiveNavigationService().activeHazardName,
                    message: ActiveNavigationService().activeHazardMessage,
                    hazardName: ActiveNavigationService().activeHazardName,
                    onDismiss: _clearHazardAlert,
                    onReannounce: () {
                      TtsService().speak(ActiveNavigationService().activeHazardMessage);
                    },
                    onEmergencyCall: () {
                      Navigator.push(context, AppRoute.to(const EmergencyScreen()));
                    },
                  ),
                ),
              );
            },
          ),

          // ── FIGMA SLIDING CARD OVERLAYS ──
          Positioned.fill(
            child: _buildDraggableCardOverlay(),
          ),

          // ── SPEECH NAVIGATION DESTINATION CONFIRMATION CARD OVERLAY ──
          Positioned.fill(
            child: _buildNavigationConfirmationCardOverlay(),
          ),

        ],
      ),
    );
        },
      ),
    );
  }

  /// Interactive Confirmation Card Dialog Overlay for Hands-Free Speech Navigation
  Widget _buildNavigationConfirmationCardOverlay() {
    if (_pendingPlaceToConfirm == null) return const SizedBox.shrink();

    final settings = SettingsService();
    final isTagalog = settings.selectedLanguage.toLowerCase().contains('tagalog') ||
        settings.selectedLanguage.toLowerCase().contains('filipino');

    final place = _pendingPlaceToConfirm!;
    final name = place['name'] as String;
    final address = place['address'] as String? ?? '';
    
    String dist = place['dist'] as String? ?? '';
    String time = place['time'] as String? ?? '';
    if (place['latLng'] is LatLng) {
      final calc = _calculateDistanceAndTime(place['latLng'] as LatLng);
      dist = calc['dist']!;
      time = calc['time']!;
    }

    final bgColor = AppColors.primaryBackground;
    final textColor = AppColors.primaryText;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.cardBorder,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Mascot or Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryButton.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.navigation_rounded, color: AppColors.primaryButton, size: 32),
              ),
              const SizedBox(height: 14),

              Text(
                isTagalog ? 'Kumpirmahin ang Ruta' : 'Confirm Destination',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                name,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryButton == Colors.white ? Colors.white : AppColors.primaryButton,
                ),
              ),
              if (address.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  address,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // Distance & Time pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryButton.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${_formatDistance(dist, SettingsService().selectedUnit)} • $time',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Voice prompt instruction text (Only show if Speech Navigation setting is enabled)
              if (SettingsService().voiceNavigationEnabled) ...[
                Text(
                  isTagalog
                      ? "Sabihin ang 'Oo', 'Kumpirmahin', o 'Sige' para magpatuloy, o 'Hindi' / 'Kanselahin'."
                      : "Say 'Yes', 'Confirm', or 'Search' to proceed, or 'No' / 'Cancel'.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 20),
              ] else
                const SizedBox(height: 12),

              // Action Buttons Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _cancelPendingNavigation,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: const BorderSide(color: Colors.red, width: 1.5),
                      ),
                      child: Text(
                        isTagalog ? 'Kanselahin' : 'Cancel',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _confirmPendingNavigation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryButton,
                        foregroundColor: AppColors.primaryButtonText,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        isTagalog ? 'Simulan' : 'Start',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
    if (_pendingPlaceToConfirm != null) return const SizedBox.shrink();

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
            color: AppColors.primaryBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
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
    final isTagalog = lang.toLowerCase().contains('tagalog') || lang.toLowerCase().contains('filipino');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Drag indicator line
        Center(
          child: Container(
            width: 50,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.primaryText.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Search bar S01
        TextField(
          controller: _searchController,
          onChanged: _performSearch,
          style: GoogleFonts.inter(fontSize: 15, color: AppColors.primaryText),
          decoration: InputDecoration(
            hintText: TranslationService.translate('Where to?', lang),
            hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
            prefixIcon: Icon(Icons.search, color: AppColors.textMuted, size: 22),
            suffixIcon: IconButton(
              icon: Icon(Icons.mic, color: AppColors.primaryButton, size: 22),
              tooltip: isTagalog ? "Magsalita para maghanap" : "Voice search",
              onPressed: _activateVoiceSearch,
            ),
            filled: true,
            fillColor: AppColors.lightBackground,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.3), width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.3), width: 1.5),
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
                    color: isSelected ? AppColors.primaryButtonText : AppColors.primaryText,
                  ),
                  backgroundColor: AppColors.lightBackground,
                  selectedColor: AppColors.primaryButton,
                  checkmarkColor: AppColors.primaryButtonText,
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
            color: AppColors.textMuted,
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
          separatorBuilder: (_, __) => Divider(height: 16, color: AppColors.cardBorder.withValues(alpha: 0.2)),
          itemBuilder: (context, index) {
            final place = _searchResults[index];
            String placeDist = place['dist'] as String;
            String placeTime = place['time'] as String;
            if (place['latLng'] is LatLng) {
              final calc = _calculateDistanceAndTime(place['latLng'] as LatLng);
              placeDist = calc['dist']!;
              placeTime = calc['time']!;
            }

            return Theme(
              data: Theme.of(context).copyWith(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                hoverColor: Colors.transparent,
                focusColor: Colors.transparent,
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                tileColor: Colors.transparent,
                selectedTileColor: Colors.transparent,
                leading: CircleAvatar(
                  backgroundColor: AppColors.primaryButton.withValues(alpha: 0.12),
                  radius: 20,
                  child: Icon(Icons.access_time, color: AppColors.primaryButton, size: 20),
                ),
                title: Text(
                  place['name'] as String,
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryText),
                ),
                subtitle: Text(
                  place['address'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                ),
                trailing: Text(
                  '${_formatDistance(placeDist, SettingsService().selectedUnit)} • $placeTime',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryText),
                ),
                onTap: () => _requestNavigationConfirmation(place),
              ),
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
              color: AppColors.cardBorder.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 20),

        Text(
          _getDynamicETA(_selectedPlace!['time'] as String),
          style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primaryText),
        ),
        const SizedBox(height: 4),
        Text(
          '${_formatDistance(_selectedPlace!['dist'] as String, SettingsService().selectedUnit)} • ${_selectedPlace!['time']}',
          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        Divider(height: 32, color: AppColors.cardBorder.withValues(alpha: 0.3)),

        Text(
          isFilipino ? 'Papunta sa ${_selectedPlace!['address']}' : 'To ${_selectedPlace!['address']}',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.primaryText.withValues(alpha: 0.8), fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.arrow_upward_rounded,
                size: 48,
                color: AppColors.primaryButton,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                _formatStep(stepText, SettingsService().selectedUnit),
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Custom Slider with Red Pin Indicator
        LayoutBuilder(
          builder: (context, constraints) {
            final double currentProgress = (_currentStepIndex + 1) / steps.length;
            return Stack(
              alignment: Alignment.centerLeft,
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 6,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Container(
                  height: 6,
                  width: constraints.maxWidth * currentProgress,
                  decoration: BoxDecoration(
                    color: AppColors.primaryButton,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Positioned(
                  left: (constraints.maxWidth * currentProgress) - 10,
                  child: Icon(Icons.arrow_right_alt, color: AppColors.primaryButton, size: 24),
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
            );
          },
        ),
        const SizedBox(height: 24),

        // ── HAZARD WARNING SYSTEM PANEL ──
        _buildHazardTestPanel(),

        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade500,
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
                    backgroundColor: AppColors.primaryButton,
                    foregroundColor: AppColors.primaryButtonText,
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

  Widget _buildHazardTestPanel() {
    return ListenableBuilder(
      listenable: ActiveNavigationService(),
      builder: (context, child) {
        final navService = ActiveNavigationService();
        final isHazard = navService.isHazardActive;
        final isTagalog = SettingsService().selectedLanguage.toLowerCase().contains('tagalog');
        final isDark = SettingsService().isDarkMode || SettingsService().selectedContrastTheme != 'Default';

        final Color cardBg = isHazard
            ? (navService.hazardSeverity == HazardSeverity.critical
                ? (isDark ? Colors.red.shade900.withValues(alpha: 0.3) : Colors.red.shade50)
                : (isDark ? Colors.orange.shade900.withValues(alpha: 0.3) : Colors.orange.shade50))
            : (isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50);

        final Color borderColor = isHazard
            ? (navService.hazardSeverity == HazardSeverity.critical
                ? Colors.red.shade400
                : Colors.orange.shade400)
            : AppColors.cardBorder.withValues(alpha: 0.4);

        final Color iconColor = isHazard
            ? (navService.hazardSeverity == HazardSeverity.critical
                ? Colors.red.shade400
                : Colors.orange.shade400)
            : AppColors.primaryButton;

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: isHazard
                ? [
                    BoxShadow(
                      color: (navService.hazardSeverity == HazardSeverity.critical
                              ? Colors.red
                              : Colors.orange)
                          .withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Icon(
                    isHazard ? Icons.warning_amber_rounded : Icons.shield_outlined,
                    size: 20,
                    color: iconColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isTagalog ? "SISTEMA NG BABALA SA PANGANIB" : "HAZARD WARNING SYSTEM",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: iconColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isHazard ? Colors.red.shade900.withValues(alpha: 0.3) : Colors.green.shade900.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isHazard ? Colors.red.shade400 : Colors.green.shade400,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isHazard ? Colors.red : Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isHazard ? "WARNING" : "ACTIVE",
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isHazard ? Colors.red.shade400 : Colors.green.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Dynamic Body Content
              if (isHazard) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: navService.hazardSeverity == HazardSeverity.critical
                            ? Colors.red.shade900.withValues(alpha: 0.4)
                            : Colors.orange.shade900.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        navService.hazardSeverity == HazardSeverity.critical
                            ? Icons.report_problem_rounded
                            : Icons.warning_amber_rounded,
                        color: navService.hazardSeverity == HazardSeverity.critical
                            ? Colors.red.shade300
                            : Colors.orange.shade300,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            navService.activeHazardName.isNotEmpty
                                ? navService.activeHazardName
                                : "Hazard Detected",
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: navService.hazardSeverity == HazardSeverity.critical
                                  ? Colors.red.shade300
                                  : Colors.orange.shade300,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            navService.activeHazardMessage.isNotEmpty
                                ? navService.activeHazardMessage
                                : "Caution! An obstacle has been detected in your navigation path.",
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: navService.hazardSeverity == HazardSeverity.critical
                                  ? Colors.red.shade800
                                  : Colors.orange.shade800,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // ── Directional Avoidance Guidance Strip ──
                if (navService.avoidanceDirection.isNotEmpty &&
                    navService.avoidanceDirection != 'center') ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: navService.avoidanceDirection == 'left'
                            ? [const Color(0xFF1565C0), const Color(0xFF42A5F5)]
                            : [const Color(0xFF42A5F5), const Color(0xFF1565C0)],
                        begin: navService.avoidanceDirection == 'left'
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        end: navService.avoidanceDirection == 'left'
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (navService.avoidanceDirection == 'left') ...[
                          const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                          const SizedBox(width: 8),
                        ],
                        Icon(
                          navService.avoidanceDirection == 'left'
                              ? Icons.turn_left_rounded
                              : Icons.turn_right_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isTagalog
                              ? (navService.avoidanceDirection == 'left'
                                  ? "LUMIPAT SA KALIWA"
                                  : "LUMIPAT SA KANAN")
                              : (navService.avoidanceDirection == 'left'
                                  ? "MOVE TO YOUR LEFT"
                                  : "MOVE TO YOUR RIGHT"),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (navService.avoidanceDirection == 'right') ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
                        ],
                      ],
                    ),
                  ),
                ] else if (navService.avoidanceDirection == 'center') ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.pan_tool_rounded, color: Colors.white, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          isTagalog ? "HUMINTO AT TUMABI" : "STOP & STEP ASIDE",
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: navService.hazardSeverity == HazardSeverity.critical
                          ? Colors.red.shade900
                          : Colors.orange.shade900,
                      side: BorderSide(
                        color: navService.hazardSeverity == HazardSeverity.critical
                            ? Colors.red.shade300
                            : Colors.orange.shade300,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _clearHazardAlert,
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: Text(
                      isTagalog ? "I-dismiss" : "Dismiss Warning",
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green.shade700,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isTagalog ? "Ligtas ang Daan • AI Monitoring" : "Path Clear • AI Radar Active",
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isTagalog
                                ? "Kasalukuyang sinusuri ang iyong paligid para sa anumang panganib."
                                : "Real-time AI vision is actively scanning your path for hazards.",
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }


  // ── OVERLAY CONTENT 3: Final Map view (Destination Arrived) ────────
  Widget _buildFullMapDirectionContent() {
    if (_selectedPlace == null) return _buildInitialSearchContent();
    final lang = SettingsService().selectedLanguage;
    final isTagalog = lang.toLowerCase().contains('tagalog') || lang.toLowerCase().contains('filipino');
    final placeName = _selectedPlace!['name'] as String? ?? (isTagalog ? 'Patutunguhan' : 'Destination');
    final placeAddr = _selectedPlace!['address'] as String? ?? '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
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
        const SizedBox(height: 16),

        // Success Icon Badge
        CircleAvatar(
          radius: 28,
          backgroundColor: Colors.green.shade50,
          child: Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 36),
        ),
        const SizedBox(height: 12),

        // Arrived Headline
        Text(
          isTagalog ? 'Nakarating Ka Na!' : 'You Have Arrived!',
          style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        const SizedBox(height: 4),

        // Destination Name
        Text(
          placeName,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF002663)),
        ),
        if (placeAddr.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            placeAddr,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],

        const SizedBox(height: 12),

        // Reached Status Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isTagalog ? '0 m • Nakarating Na' : '0 m • Destination Reached',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade800),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Done Action Button
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

class _MapCanvasPainter extends CustomPainter {
  final bool isNavigating;
  final String? destinationName;

  _MapCanvasPainter({this.isNavigating = false, this.destinationName});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Light Slate Background
    final bgPaint = Paint()..color = const Color(0xFFF1F5F9);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 2. White Primary Road Grid
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final secondaryRoadPaint = Paint()
      ..color = const Color(0xFFF8FAFC)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke;

    final roadPath = Path();
    roadPath.moveTo(0, size.height * 0.35);
    roadPath.quadraticBezierTo(size.width * 0.4, size.height * 0.3, size.width, size.height * 0.42);

    roadPath.moveTo(size.width * 0.25, 0);
    roadPath.lineTo(size.width * 0.35, size.height);

    roadPath.moveTo(size.width * 0.65, 0);
    roadPath.lineTo(size.width * 0.75, size.height);

    roadPath.moveTo(0, size.height * 0.65);
    roadPath.lineTo(size.width, size.height * 0.72);

    canvas.drawPath(roadPath, roadPaint);
    canvas.drawPath(roadPath, secondaryRoadPaint);

    // 3. Route Line (if navigating or place selected)
    if (isNavigating) {
      final routePaint = Paint()
        ..color = const Color(0xFF1D4ED8)
        ..strokeWidth = 8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final routePath = Path();
      routePath.moveTo(size.width * 0.35, size.height * 0.55);
      routePath.lineTo(size.width * 0.35, size.height * 0.35);
      routePath.quadraticBezierTo(size.width * 0.4, size.height * 0.3, size.width * 0.65, size.height * 0.32);
      routePath.lineTo(size.width * 0.68, size.height * 0.22);

      canvas.drawPath(routePath, routePaint);

      // Destination Pin Marker
      final destPinPaint = Paint()..color = const Color(0xFFDC2626);
      canvas.drawCircle(Offset(size.width * 0.68, size.height * 0.22), 12, destPinPaint);
      final destInner = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(size.width * 0.68, size.height * 0.22), 5, destInner);
    }

    // 4. Current Location Pulsing Pin Marker (Blue Dot)
    final locOffset = Offset(size.width * 0.35, size.height * 0.55);
    final pulsePaint = Paint()
      ..color = const Color(0x402563EB)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(locOffset, 22, pulsePaint);

    final bluePin = Paint()..color = const Color(0xFF2563EB);
    canvas.drawCircle(locOffset, 10, bluePin);

    final whiteCenter = Paint()..color = Colors.white;
    canvas.drawCircle(locOffset, 4, whiteCenter);
  }

  @override
  bool shouldRepaint(covariant _MapCanvasPainter oldDelegate) =>
      oldDelegate.isNavigating != isNavigating || oldDelegate.destinationName != destinationName;
}
