import 'package:flutter/material.dart';

class UndoAction {
  final String description;
  final VoidCallback undo;

  UndoAction({
    required this.description,
    required this.undo,
  });
}

class UndoService {
  static final UndoService _instance = UndoService._internal();

  factory UndoService() {
    return _instance;
  }

  UndoService._internal();

  final List<UndoAction> _history = [];

  void add(VoidCallback undo, {String description = "Action"}) {
    _history.add(UndoAction(description: description, undo: undo));
    // Limit history stack size to 25 items to prevent memory leaks
    if (_history.length > 25) {
      _history.removeAt(0);
    }
    print("[UndoService] Added action: $description. Total actions: ${_history.length}");
  }

  bool performUndo() {
    if (_history.isEmpty) {
      print("[UndoService] Nothing to undo.");
      return false;
    }
    final lastAction = _history.removeLast();
    print("[UndoService] Performing undo for: ${lastAction.description}");
    try {
      lastAction.undo();
      return true;
    } catch (e) {
      print("[UndoService] Error executing undo action: $e");
      return false;
    }
  }

  void clear() {
    _history.clear();
    print("[UndoService] History cleared.");
  }
}
