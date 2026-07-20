import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class ActiveNavigationService extends ChangeNotifier {
  static final ActiveNavigationService _instance = ActiveNavigationService._internal();
  factory ActiveNavigationService() => _instance;
  ActiveNavigationService._internal();

  bool _isNavigating = false;
  String _destinationName = "";
  String _currentStepText = "";
  String _distanceRemaining = "";
  String _timeRemaining = "";
  LatLng? _currentLocation;
  LatLng? _destinationLocation;
  List<LatLng> _routePoints = [];
  bool _hasArrived = false;

  Map<String, dynamic>? _activePlace;
  List<LatLng> _stepLocations = [];
  int _currentStepIndex = 0;

  bool get isNavigating => _isNavigating;
  String get destinationName => _destinationName;
  String get currentStepText => _currentStepText;
  String get distanceRemaining => _distanceRemaining;
  String get timeRemaining => _timeRemaining;
  LatLng? get currentLocation => _currentLocation;
  LatLng? get destinationLocation => _destinationLocation;
  List<LatLng> get routePoints => _routePoints;
  bool get hasArrived => _hasArrived;

  Map<String, dynamic>? get activePlace => _activePlace;
  List<LatLng> get stepLocations => _stepLocations;
  int get currentStepIndex => _currentStepIndex;

  void triggerArrival() {
    _hasArrived = true;
    try {
      WakelockPlus.disable();
    } catch (e) {
      debugPrint("Wakelock disable error on arrival: $e");
    }
    notifyListeners();
  }

  void startNavigation({
    required String destinationName,
    required LatLng destinationLocation,
    required List<LatLng> routePoints,
    Map<String, dynamic>? activePlace,
    List<LatLng> stepLocations = const [],
  }) {
    _isNavigating = true;
    _hasArrived = false;
    _destinationName = destinationName;
    _destinationLocation = destinationLocation;
    _routePoints = routePoints;
    _activePlace = activePlace;
    _stepLocations = stepLocations;
    _currentStepIndex = 0;
    try {
      WakelockPlus.enable();
    } catch (e) {
      debugPrint("Wakelock enable error: $e");
    }
    notifyListeners();
  }

  void updateProgress({
    required String currentStepText,
    required String distanceRemaining,
    required String timeRemaining,
    LatLng? currentLocation,
    int currentStepIndex = 0,
  }) {
    _currentStepText = currentStepText;
    _distanceRemaining = distanceRemaining;
    _timeRemaining = timeRemaining;
    _currentStepIndex = currentStepIndex;
    if (currentLocation != null) {
      _currentLocation = currentLocation;
    }
    notifyListeners();
  }

  void stopNavigation() {
    _isNavigating = false;
    _destinationName = "";
    _currentStepText = "";
    _distanceRemaining = "";
    _timeRemaining = "";
    _hasArrived = false;
    _currentLocation = null;
    _destinationLocation = null;
    _routePoints = [];
    _activePlace = null;
    _stepLocations = [];
    _currentStepIndex = 0;
    try {
      WakelockPlus.disable();
    } catch (e) {
      debugPrint("Wakelock disable error: $e");
    }
    notifyListeners();
  }
}
