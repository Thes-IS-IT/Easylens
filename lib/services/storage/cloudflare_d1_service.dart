import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../../models/user_preferences.dart';
import '../../models/emergency_contact.dart';

class CloudflareD1Service {
  static final CloudflareD1Service _instance = CloudflareD1Service._internal();

  factory CloudflareD1Service() {
    return _instance;
  }

  CloudflareD1Service._internal();

  bool _initialized = false;

  /// Helper to send query requests to the Cloudflare D1 HTTP endpoint.
  Future<http.Response> _executeQuery(String sql, List<dynamic> params) async {
    final accountId = dotenv.env['ACCOUNT_ID'] ?? '';
    final databaseId = dotenv.env['D1_DTABASE'] ?? '';
    final tokenValue = dotenv.env['TOKEN_VALUE'] ?? '';

    if (accountId.isEmpty || databaseId.isEmpty || tokenValue.isEmpty) {
      print("Warning: Cloudflare D1 credentials are not fully configured in .env.");
      return http.Response('{"success":false,"errors":["Missing credentials"]}', 401);
    }

    final url = 'https://api.cloudflare.com/client/v4/accounts/$accountId/d1/database/$databaseId/query';
    
    // Cloudflare D1 query body S01
    final body = jsonEncode({
      'sql': sql,
      'params': params,
    });

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $tokenValue',
          'Content-Type': 'application/json',
        },
        body: body,
      );
      return response;
    } catch (e) {
      print("D1 Query Network Error: $e");
      rethrow;
    }
  }

  /// Initializes database tables in D1.
  Future<void> initializeDatabase() async {
    if (_initialized) return;

    final accountId = dotenv.env['ACCOUNT_ID'] ?? '';
    if (accountId.isEmpty) return; // Silent skip if no config

    print("Initializing Cloudflare D1 tables...");
    
    const usersTableSql = '''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        email TEXT,
        display_name TEXT,
        preferences_json TEXT,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      );
    ''';

    const contactsTableSql = '''
      CREATE TABLE IF NOT EXISTS contacts (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        name TEXT,
        phone TEXT,
        relationship TEXT,
        is_active INTEGER,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      );
    ''';

    try {
      final res1 = await _executeQuery(usersTableSql, []);
      final res2 = await _executeQuery(contactsTableSql, []);
      
      if (res1.statusCode == 200 && res2.statusCode == 200) {
        _initialized = true;
        print("Cloudflare D1 tables verified successfully.");
      } else {
        print("Failed to initialize D1 tables. Statuses: ${res1.statusCode}, ${res2.statusCode}");
      }
    } catch (e) {
      print("Error initializing D1 tables: $e");
    }
  }

  /// Synchronizes user preferences to D1.
  Future<void> syncPreferences(String userId, String email, String displayName, UserPreferences prefs) async {
    await initializeDatabase();
    
    final preferencesJsonStr = jsonEncode(prefs.toJson());
    
    const sql = '''
      INSERT INTO users (id, email, display_name, preferences_json, updated_at)
      VALUES (?, ?, ?, ?, datetime('now'))
      ON CONFLICT(id) DO UPDATE SET
        email = excluded.email,
        display_name = excluded.display_name,
        preferences_json = excluded.preferences_json,
        updated_at = datetime('now');
    ''';

    try {
      final response = await _executeQuery(sql, [userId, email, displayName, preferencesJsonStr]);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          print("Cloudflare D1: Preferences synced successfully for user $userId.");
          return;
        }
      }
      print("Cloudflare D1: Preferences sync failed. Status: ${response.statusCode}, Body: ${response.body}");
    } catch (e) {
      print("Error syncing preferences to D1: $e");
    }
  }

  /// Synchronizes an emergency contact to D1.
  Future<void> syncContact(String userId, EmergencyContact contact) async {
    await initializeDatabase();

    // ID is derived from contact phone number combined with user ID for uniqueness S01
    final contactId = '${userId}_${contact.phone.replaceAll(' ', '')}';
    final isActiveInt = contact.isActive ? 1 : 0;

    const sql = '''
      INSERT INTO contacts (id, user_id, name, phone, relationship, is_active, created_at)
      VALUES (?, ?, ?, ?, ?, ?, datetime('now'))
      ON CONFLICT(id) DO UPDATE SET
        name = excluded.name,
        phone = excluded.phone,
        relationship = excluded.relationship,
        is_active = excluded.is_active;
    ''';

    try {
      final response = await _executeQuery(sql, [
        contactId,
        userId,
        contact.name,
        contact.phone,
        contact.relationship,
        isActiveInt
      ]);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          print("Cloudflare D1: Contact synced successfully for user $userId.");
          return;
        }
      }
      print("Cloudflare D1: Contact sync failed. Status: ${response.statusCode}, Body: ${response.body}");
    } catch (e) {
      print("Error syncing contact to D1: $e");
    }
  }
}
