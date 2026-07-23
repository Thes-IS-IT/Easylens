import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'danger_warning_service.dart';


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

  // Hazard / Warning State
  bool _isHazardActive = false;
  HazardSeverity _hazardSeverity = HazardSeverity.safe;
  String _activeHazardName = "";
  String _activeHazardMessage = "";
  DateTime? _hazardTimestamp;

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

  // Hazard getters
  bool get isHazardActive => _isHazardActive;
  HazardSeverity get hazardSeverity => _hazardSeverity;
  String get activeHazardName => _activeHazardName;
  String get activeHazardMessage => _activeHazardMessage;
  DateTime? get hazardTimestamp => _hazardTimestamp;

  void triggerHazardAlert({
    required String hazardName,
    required HazardSeverity severity,
    required String message,
  }) {
    _isHazardActive = true;
    _hazardSeverity = severity;
    _activeHazardName = hazardName;
    _activeHazardMessage = message;
    _hazardTimestamp = DateTime.now();
    notifyListeners();
  }

  void clearHazardAlert() {
    _isHazardActive = false;
    _hazardSeverity = HazardSeverity.safe;
    _activeHazardName = "";
    _activeHazardMessage = "";
    _hazardTimestamp = null;
    notifyListeners();
  }

  void triggerArrival() {
    _hasArrived = true;
    _isNavigating = false;
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
    _isHazardActive = false;
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
    _isHazardActive = false;
    _destinationName = "";
    _currentStepText = "";
    _distanceRemaining = "";
    _timeRemaining = "";
    _hasArrived = false;
    // Keep last known _currentLocation intact to avoid null errors in listening map UI
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

