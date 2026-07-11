import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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

  bool get isNavigating => _isNavigating;
  String get destinationName => _destinationName;
  String get currentStepText => _currentStepText;
  String get distanceRemaining => _distanceRemaining;
  String get timeRemaining => _timeRemaining;
  LatLng? get currentLocation => _currentLocation;
  LatLng? get destinationLocation => _destinationLocation;
  List<LatLng> get routePoints => _routePoints;
  bool get hasArrived => _hasArrived;

  void triggerArrival() {
    _hasArrived = true;
    notifyListeners();
  }

  void startNavigation({
    required String destinationName,
    required LatLng destinationLocation,
    required List<LatLng> routePoints,
  }) {
    _isNavigating = true;
    _hasArrived = false;
    _destinationName = destinationName;
    _destinationLocation = destinationLocation;
    _routePoints = routePoints;
    notifyListeners();
  }

  void updateProgress({
    required String currentStepText,
    required String distanceRemaining,
    required String timeRemaining,
    LatLng? currentLocation,
  }) {
    _currentStepText = currentStepText;
    _distanceRemaining = distanceRemaining;
    _timeRemaining = timeRemaining;
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
    notifyListeners();
  }
}
