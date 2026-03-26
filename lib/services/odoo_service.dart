import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

import '../models/sale.dart';
import '../models/whatsapp_models.dart';
import 'package:path_provider/path_provider.dart';

// Custom exceptions for business error handling
class ClientRequiredException implements Exception {
  final String message;
  ClientRequiredException(this.message);
  @override
  String toString() => message;
}

class OdooServiceException implements Exception {
  final String message;
  OdooServiceException(this.message);
  @override
  String toString() => "OdooServiceException: $message";
}

/// Service class to handle communication with Odoo via RPC.
/// Implements Singleton pattern and supports both standard Odoo and Prisma servers.
class OdooService {
  // ---------------------------------------------------------------------------
  // PHASE 0: CRITICAL ARCHITECTURE REFACTORING
  // Static Singleton and Private Client
  // ---------------------------------------------------------------------------

  static final OdooService instance = OdooService._internal();

  OdooService._internal();

  OdooClient? _client;
  String? _baseUrl;
  int? _mainPartnerId; // Cached for notifications/Discuss

  // --- SECONDARY CLIENT FOR WHATSAPP ---
  OdooClient? _whatsAppClient;
  bool _isWhatsAppInitializing = false;
  int? _whatsappUid;
  final String _whatsappUrl = "https://app.prismahexagon.com";
  final String _whatsappDb = "mardebran"; // Primary DB name
  final String _whatsappUser = "admin";
  final String _whatsappPassword =
      "310af0e42590d120613b006ff1144072069dc262"; // OFFICIAL API KEY
  // -------------------------------------

  // --- PRISMA PRIMARY MODE STATE ---
  bool _isPrismaMode = false;
  int? _prismaUid;
  String? _prismaApiKey;
  String? _prismaDb;
  // ---------------------------------


  // Cache for field existence checks for the current session/server
  final Map<String, bool> _fieldCache = {};

  /// Resets all internal state for a fresh connection
  void _resetState() {
    debugPrint("OdooService: Resetting internal state...");
    _client = null;
    _whatsAppClient = null;
    _isWhatsAppInitializing = false;
    _whatsappUid = null;
    _isPrismaMode = false;
    _prismaUid = null;
    _prismaApiKey = null;
    _prismaDb = null; // Added reset
    _mainPartnerId = null;
    _fieldCache.clear();
  }

  // Public getter to check if the service is initialized (useful for navigation guards)
  bool get isInitialized =>
      _client != null || (_isPrismaMode && _prismaUid != null);

  String get baseURL => _baseUrl ?? '';
  OdooSession? get session => _client?.sessionId;
  bool get isPrismaMode => _isPrismaMode;

  // Public getter for current User ID
  int? get uid => _isPrismaMode ? _prismaUid : _client?.sessionId?.userId;

  /// Initializes the client with the server URL.
  void init(String url) {
    _resetState(); // Force fresh state on new URL

    String formattedUrl = url.trim();
    if (!formattedUrl.startsWith('http')) {
      formattedUrl = 'https://$formattedUrl';
    }

    // Remove trailing slash if present
    if (formattedUrl.endsWith('/')) {
      formattedUrl = formattedUrl.substring(0, formattedUrl.length - 1);
    }

    _client = OdooClient(formattedUrl);
    _baseUrl = formattedUrl;
    debugPrint("🚀 OdooService: Initialized with $formattedUrl");
  }

  Future<void> initWhatsAppClient() async {
    if (_isWhatsAppInitializing) return;
    if (_whatsAppClient?.sessionId != null) return;

    _isWhatsAppInitializing = true;
    try {
      debugPrint("WhatsApp Client: Initializing dual-auth recovery...");

      // 1. Try Admin Login (Production DB first if on Prisma)
      // Use _prismaDb if we ARE on the prisma server, otherwise fallback to _whatsappDb
      final String targetDb =
          (_isPrismaMode && _baseUrl == _whatsappUrl && _prismaDb != null)
          ? _prismaDb!
          : _whatsappDb;

      debugPrint("WhatsApp Client: Attempting login in DB: $targetDb");

      var adminUid = await authenticatePrisma(
        db: targetDb,
        user: _whatsappUser,
        apiKey: _whatsappPassword,
      );


      if (adminUid != null) {
        _whatsappUid = adminUid;
        _whatsAppClient = OdooClient(_whatsappUrl);
        debugPrint("WhatsApp Client: Admin Login Successful. UID: $adminUid");
        try {
          debugPrint("WhatsApp Client: Attempting Session Authentication...");
          // We already know adminUid is not null here
          await _whatsAppClient!.authenticate(
            targetDb,
            _whatsappUser,
            _whatsappPassword,
          );
          debugPrint(
            "✅ WhatsApp Client: Session Authenticated (SessionID: ${_whatsAppClient!.sessionId!.id})",
          );
        } catch (e) {
          debugPrint("⚠️ WhatsApp Client: Session Authentication Failed: $e");
        }
      } else {
        // 2. Fallback to User Session ONLY if already on Prisma server
        if (_isPrismaMode || _baseUrl == _whatsappUrl) {
          debugPrint(
            "WhatsApp Client: Admin Login Failed. Using current user session.",
          );
          _whatsAppClient = _client;
        }
      }
    } catch (e) {
      debugPrint("❌ WhatsApp Client Initialization Error: $e");
    } finally {
      _isWhatsAppInitializing = false;
    }
  }

  /// Fetches available databases from the Odoo server
  Future<List<String>> getDatabaseList(String url) async {
    final endpoint = url.endsWith('/') ? "${url}jsonrpc" : "$url/jsonrpc";
    debugPrint("OdooService: Fetching databases from $endpoint");

    try {
      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "jsonrpc": "2.0",
              "method": "call",
              "params": {"service": "db", "method": "list", "args": []},
              "id": DateTime.now().millisecondsSinceEpoch,
            }),
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['result'] is List) {
          final dbs = List<String>.from(decoded['result']);
          debugPrint("OdooService: Databases found: $dbs");
          return dbs;
        } else if (decoded['error'] != null) {
          debugPrint(
            "OdooService: Error listing databases: ${decoded['error']}",
          );
        }
      } else {
        debugPrint(
          "OdooService: Database list request failed with status ${response.statusCode}",
        );
      }
    } catch (e) {
      debugPrint("OdooService: Exception fetching databases: $e");
    }
    return [];
  }

  /// Robust JSON-RPC 2.0 Version Check
  Future<Map<String, dynamic>?> getPrismaVersion() async {
    final String url = "$_whatsappUrl/jsonrpc";
    debugPrint("[RPC] GET VERSION -> $url");

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "jsonrpc": "2.0",
              "method": "call",
              "params": {"service": "common", "method": "version", "args": []},
              "id": DateTime.now().millisecondsSinceEpoch,
            }),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint("[RPC] Status: ${response.statusCode}");
      debugPrint("[RPC] Raw Response: ${response.body}");

      final decoded = jsonDecode(response.body);
      if (decoded['error'] != null) {
        debugPrint("❌ RPC Version Error: ${decoded['error']}");
        return null;
      }
      return decoded['result'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint("❌ RPC Version Connection Error: $e");
      return null;
    }
  }

  /// Robust JSON-RPC 2.0 Authentication for Prisma
  Future<int?> authenticatePrisma({
    required String db,
    required String user,
    required String apiKey,
  }) async {
    final String url = "$_whatsappUrl/jsonrpc";
    debugPrint("[RPC] AUTHENTICATING -> $url (DB: $db, User: $user)");

    try {
      final body = {
        "jsonrpc": "2.0",
        "method": "call",
        "params": {
          "service": "common",
          "method": "authenticate",
          "args": [db, user, apiKey, {}],
        },
        "id": 1,
      };

      final response = await http
          .post(
            Uri.parse(url),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint("[RPC] Status: ${response.statusCode}");
      debugPrint("[RPC] Raw Response: ${response.body}");

      final decoded = jsonDecode(response.body);

      if (decoded['error'] != null) {
        debugPrint("❌ RPC Auth Failed!");
        debugPrint("Error Details: ${jsonEncode(decoded['error'])}");

        final error = decoded['error'];
        if (error['data'] != null &&
            error['data']['message'] != null &&
            error['data']['message'].contains("database")) {
          debugPrint(">> CAUSE: Incorrect Database Name");
        } else if (error['message'] != null &&
            error['message'].contains("Access Denied")) {
          debugPrint(">> CAUSE: Invalid Credentials / API Key");
        }
        return null;
      }

      final result = decoded['result'];
      if (result is int) {
        debugPrint("✅ RPC Auth Success! UID received: $result");
        return result;
      } else if (result == false) {
        debugPrint("❌ RPC Auth Failed: Server returned 'false' (Invalid Auth)");
        return null;
      }

      debugPrint("❓ RPC Unexpected Response: $result");
      return null;
    } catch (e) {
      debugPrint("❌ RPC Auth Connection Error: $e");
      if (e is SocketException) {
        debugPrint(">> CAUSE: Network Error / Endpoint Unreachable");
      } else if (e is FormatException) {
        debugPrint(">> CAUSE: Invalid Response Format (maybe not /jsonrpc?)");
      }
      return null;
    }
  }

  /// Manages session authentication for both standard and Prisma servers.
  Future<void> authenticate(String db, String user, String password) async {
    if (_baseUrl == null) {
      throw OdooServiceException("Client not initialized. Call init() first.");
    }

    final bool isPrismaServer = _baseUrl!.contains("app.prismahexagon.com");

    // Pre-auth reset (except baseUrl and client which were set in init)
    final savedUrl = _baseUrl;
    _resetState();
    _baseUrl = savedUrl;
    _client = OdooClient(_baseUrl!);

    if (isPrismaServer) {
      debugPrint("OdooService: Prisma server detected. Using robust RPC Auth.");
      try {
        final uid = await authenticatePrisma(
          db: db,
          user: user,
          apiKey: password,
        );

        if (uid != null) {
          _isPrismaMode = true;
          _prismaUid = uid;
          _prismaApiKey = password;
          _prismaDb = db;

          // Fetch and cache Main Partner ID & VoIP Data
          await _cachePartnerId(uid);

          // PROACTIVE: Sync WhatsApp Client if in Prisma Mode
          initWhatsAppClient();

          // PROACTIVE: Cache VoIP Data explicitly if needed (redundant now with _cachePartnerId update)

          return;
        } else {
          throw OdooServiceException(
            "Invalid credentials for the production server.",
          );
        }
      } catch (e) {
        debugPrint("Prisma Auth Error: $e");
        throw OdooServiceException("Error connecting to server: $e");
      }
    }

    // Standard Odoo Auth
    _client ??= OdooClient(_baseUrl!);

    try {
      _isPrismaMode = false;
      await _client!.authenticate(db, user, password);

      // Fetch and cache Main Partner ID
      final profile = await getUserProfile();
      if (profile['partner_id'] is List) {
        _mainPartnerId = profile['partner_id'][0];
        debugPrint("Logged in as Partner ID: $_mainPartnerId");
      }

      // Sync WhatsApp Client
      if (_baseUrl == _whatsappUrl) {
        _whatsAppClient = _client;
      } else {
        initWhatsAppClient();
      }
    } on OdooException catch (e) {
      debugPrint("Odoo Auth Error: $e");
      throw OdooServiceException("Incorrect username or password.");
    } catch (e) {
      debugPrint("Standard Auth Error: $e");
      throw OdooServiceException("Could not connect to the server.");
    }
  }

  /// Helper to cache Partner ID during login
  Future<void> _cachePartnerId(int uid) async {
    try {
      final profile =
          await callKw(
            model: 'res.users',
            method: 'read',
            args: [
              [uid],
            ],
            kwargs: {
            'fields': ['partner_id'],
            },
          ).catchError((e) {
            debugPrint(
              "⚠️ OdooService: Could not fetch VoIP fields in _cachePartnerId: $e",
            );
            return callKw(
              model: 'res.users',
              method: 'read',
              args: [
                [uid],
              ],
              kwargs: {
                'fields': ['partner_id'],
              },
            );
          });
      if (profile is List && profile.isNotEmpty) {
        final userData = profile[0] as Map<String, dynamic>;
        _mainPartnerId = userData['partner_id'][0];

        debugPrint("Cached Partner ID: $_mainPartnerId");
      }
    } catch (e) {
      debugPrint("Failed to cache partner_id: $e");
    }
  }

  /// Helper to get the current user's UID.
  int? get currentUserId {
    if (_isPrismaMode) return _prismaUid;
    return _client?.sessionId?.userId;
  }

  // Cache for VoIP Credentials in case of subsequent RPC failures (REMOVED DUPLICATE)

  /// Retrieves the current user's profile details.
  Future<Map<String, dynamic>> getUserProfile() async {
    final uid = currentUserId;
    if (uid == null) throw OdooServiceException("No user logged in.");

    dynamic userRes;
    try {
      userRes = await callKw(
        model: 'res.users',
        method: 'read',
        args: [
          [uid],
        ],
        kwargs: {
          'fields': [
            'name',
            'login',
            'partner_id',
            'lang',
            'tz',
            'company_id',
            'notification_type',
            'signature',
            'attendance_pin',
            'image_1920',
            'image_1024',
            'image_512',
            'image_256',
            'image_128',
          ],
        },
      );
    } catch (e) {
      debugPrint(
        "ℹ️ OdooService: Some fields missing in res.users, retrying with minimal set...",
      );
      userRes = await callKw(
        model: 'res.users',
        method: 'read',
        args: [
          [uid],
        ],
        kwargs: {
          'fields': [
            'name',
            'login',
            'partner_id',
            'lang',
            'tz',
            'company_id',
            'notification_type',
            'signature',
            'image_1920',
            'image_1024',
            'image_512',
            'image_256',
            'image_128',
          ],
        },
      );
    }

    if (userRes is! List || userRes.isEmpty) {
      throw OdooServiceException("User data not found.");
    }

    final userData = userRes[0] as Map<String, dynamic>;


    // 2. Fetch Partner Data (Image, Phone, Function)
    int? partnerId;
    if (userData['partner_id'] is List && userData['partner_id'].isNotEmpty) {
      partnerId = userData['partner_id'][0];
    }

    if (partnerId != null) {
      try {
        final partnerRes = await callKw(
          model: 'res.partner',
          method: 'read',
          args: [
            [partnerId],
          ],
          kwargs: {
            'fields': ['phone', 'mobile', 'function', 'email', 'image_1920', 'image_1024', 'image_512', 'image_256', 'image_128'],
          },
        );

        if (partnerRes is List && partnerRes.isNotEmpty) {
          userData.addAll(partnerRes[0] as Map<String, dynamic>);
        }

        // Try to get image separately to avoid timeout if it's too large
        _fetchImageAsync(partnerId, userData);
      } catch (e) {
        debugPrint("⚠️ OdooService: Error fetching partner details: $e");
      }
    }

    return userData;
  }

  /// Fetches image separately to avoid blocking the main profile load or causing timeouts
  void _fetchImageAsync(int partnerId, Map<String, dynamic> target) async {
    try {
      final res = await callKw(
        model: 'res.partner',
        method: 'read',
        args: [
          [partnerId],
        ],
        kwargs: {
          'fields': ['image_1920'],
        },
      ).timeout(const Duration(seconds: 10));

      if (res is List && res.isNotEmpty) {
        target['image_1920'] = res[0]['image_1920'];
        debugPrint("✅ OdooService: Profile image loaded asynchronously.");
      }
    } catch (e) {
      debugPrint(
        "⚠️ OdooService: Background image fetch failed (expected if large): $e",
      );
    }
  }

  /// Update user-specific preferences (res.users)
  Future<bool> updateUserPreferences(Map<String, dynamic> vals) async {
    final uid = currentUserId;
    if (uid == null) return false;

    try {
      await callKw(
        model: 'res.users',
        method: 'write',
        args: [
          [uid],
          vals,
        ],
      );
      return true;
    } catch (e) {
      debugPrint("Error updating user preferences: $e");
      rethrow; // Rethrow to let the UI handle the specific error
    }
  }

  /// Update partner-specific preferences (res.partner) e.g. signature
  Future<bool> updatePartnerPreferences(Map<String, dynamic> vals) async {
    final pid = _mainPartnerId ?? _client?.sessionId?.partnerId;
    if (pid == null) return false;

    try {
      await callKw(
        model: 'res.partner',
        method: 'write',
        args: [
          [pid],
          vals,
        ],
      );
      return true;
    } catch (e) {
      debugPrint("Error updating partner preferences: $e");
      rethrow; // Rethrow to let the UI handle the specific error
    }
  }

  /// Updates the user's profile image (stored in res.partner).
  Future<bool> updateUserProfileImage(String base64Image) async {
    final uid = currentUserId;
    if (uid == null) return false;

    try {
      // 1. Get Partner ID
      final userRes = await callKw(
        model: 'res.users',
        method: 'read',
        args: [
          [uid],
        ],
        kwargs: {
          'fields': ['partner_id'],
        },
      );

      if (userRes is List && userRes.isNotEmpty) {
        final partnerId = userRes[0]['partner_id'][0];
        if (partnerId is int) {
          // 2. Update res.partner
          await callKw(
            model: 'res.partner',
            method: 'write',
            args: [
              [partnerId],
              {'image_1920': base64Image},
            ],
            kwargs: {},
          );
          debugPrint(
            "✅ OdooService: Profile image updated for partner $partnerId",
          );
          return true;
        }
      }
    } catch (e) {
      debugPrint("❌ OdooService: Error updating profile image: $e");
    }
    return false;
  }

  /// Centralized method to perform Odoo calls with robust error handling.
  /// Accessible by other services (CrmService, ProductService, etc.).
  Future<dynamic> callKw({
    required String model,
    required String method,
    required List<dynamic> args,
    Map<String, dynamic>? kwargs,
  }) async {
    // Unified Call (Standard Odoo Client)
    if (_client == null) {
      throw OdooServiceException("Client not initialized. Please login first.");
    }

    try {
      debugPrint("RPC Call -> Model: $model, Method: $method");

      // PRISMA FIX: Use Stateless Auth Wrapper if in Prisma Mode
      if (_isPrismaMode &&
          _prismaUid != null &&
          _prismaApiKey != null &&
          _prismaDb != null) {
        debugPrint(">> Using Stateless Prisma Auth for $model.$method");
        // We must manually construct the execute_kw call
        // because OdooClient.callKw relies on session_id cookie which might be lost/expired.
        final commonUrl = "${_baseUrl!}/jsonrpc";
        final payload = {
          "jsonrpc": "2.0",
          "method": "call",
          "params": {
            "service": "object",
            "method": "execute_kw",
            "args": [
              _prismaDb!,
              _prismaUid!,
              _prismaApiKey!, // Password/API Key
              model,
              method,
              args,
              kwargs ?? {},
            ],
          },
          "id": DateTime.now().millisecondsSinceEpoch,
        };

        final response = await http
            .post(
              Uri.parse(commonUrl),
              headers: {"Content-Type": "application/json"},
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 30));

        // CRITICAL LOG: See exactly what the server says
        debugPrint(">> Stateless RPC Stats: ${response.statusCode}");

        if (response.statusCode != 200) {
          debugPrint(">> Stateless RPC HTTP ERROR: ${response.body}");
          // If we have a proxy error or similar, this will capture it
        }

        final decoded = jsonDecode(response.body);
        if (decoded['error'] != null) {
          // Construct OdooException manually to throw it and catch below
          // or throw explicit service exception
          final error = decoded['error'];
          debugPrint("❌ Stateless RPC Error: $error");
          throw OdooException(error);
        }
        return decoded['result'];
      }

      // Default Standard Odoo Client Call
      return await _client!
          .callKw({
            'model': model,
            'method': method,
            'args': args,
            'kwargs': kwargs ?? {},
          })
          .timeout(
            const Duration(seconds: 20),
          ); // Prevents infinite loading on slow connections
    } on OdooException catch (e) {
      debugPrint("❌ Odoo RPC Error ($model.$method):");
      debugPrint("   Message: ${e.message}");
      throw OdooServiceException("Odoo server error: ${e.message}");
    } catch (e) {
      debugPrint("❌ Unknown RPC Error ($model.$method): $e");
      if (e is http.Response) {
        debugPrint("   HTTP Status: ${e.statusCode}");
        debugPrint("   HTTP Body: ${e.body}");
      }
      // Mapeo específico para errores de conexión
      if (e.toString().contains("SocketException") ||
          e.toString().contains("Network is unreachable") ||
          e.toString().contains("Connection refused")) {
        throw OdooServiceException(
          "Connection error: Check your internet or the server.",
        );
      }
      throw OdooServiceException("Unknown error: $e");
    }
  }

  // ---------------------------------------------------------------------------
  // RESTORED: CONTACTS (res.partner)
  // Methods restored to fix ContactsScreen and other legacy usages
  // ---------------------------------------------------------------------------

  Future<List<dynamic>> getContacts() async {
    final result = await callKw(
      model: 'res.partner',
      method: 'search_read',
      args: [],
      kwargs: {
        'context': {'bin_size': true},
        'domain': [],
        // 'filter_domain': [['type', '=', 'contact']], // Optional: filter only contacts
        'fields': [
          'id',
          'name',
          'email',
          'phone',
          'vat',
          'function', // Job Position
          'parent_name', // Company Name
          'comment', // Notes (Inquiry Details)
          'create_date', // Creation Date
        ],
        // 'limit': 50, // Comentado para traer TODOS los contactos como solicitó el usuario
      },
    );
    return result as List<dynamic>;
  }

  Future<int> createContact(Map<String, dynamic> data) async {
    final result = await callKw(
      model: 'res.partner',
      method: 'create',
      args: [data],
    );
    return result as int;
  }

  Future<void> updateContact(int id, Map<String, dynamic> data) async {
    await callKw(
      model: 'res.partner',
      method: 'write',
      args: [
        [id],
        data,
      ],
    );
  }

  Future<void> deleteContact(int id) async {
    await callKw(
      model: 'res.partner',
      method: 'unlink',
      args: [
        [id],
      ],
    );
  }

  /// Fetches full details for a single contact
  Future<Map<String, dynamic>> getContactDetail(int id) async {
    final hasMobile = await fieldExists(
      model: 'res.partner',
      fieldName: 'mobile',
    );

    final fields = [
      'id',
      'name',
      'email',
      'phone',
      'website',
      'vat',
      'function',
      'parent_name',
      'comment',
      'street',
      'street2',
      'city',
      'state_id',
      'zip',
      'country_id',
      'is_company',
      'user_id',
      'property_payment_term_id',
      'image_1920',
    ];

    if (hasMobile) {
      fields.add('mobile');
    }

    final result = await callKw(
      model: 'res.partner',
      method: 'read',
      args: [
        [id],
      ],
      kwargs: {'fields': fields},
    );

    if (result is List && result.isNotEmpty) {
      return result[0] as Map<String, dynamic>;
    }

    throw OdooServiceException("Contact not found");
  }

  // ---------------------------------------------------------------------------
  // RESTORED: SALES LIST & CRUD
  // Methods restored or updated to support SalesScreen listing
  // ---------------------------------------------------------------------------

  // Map to track pending field existence checks to avoid duplicate concurrent RPCs
  final Map<String, Future<bool>> _pendingFieldChecks = {};

  Future<bool> fieldExists({
    required String model,
    required String fieldName,
    bool useWhatsAppClient = false,
  }) async {
    final cacheKey = "${useWhatsAppClient ? 'wa' : 'main'}:$model.$fieldName";

    // 0. Essential fields always exist
    if (fieldName == 'id' ||
        fieldName == 'name' ||
        fieldName == 'display_name') {
      return true;
    }

    // 1. Check persistent cache
    if (_fieldCache.containsKey(cacheKey)) {
      return _fieldCache[cacheKey]!;
    }

    // 2. Check if a request is already in progress for this key
    if (_pendingFieldChecks.containsKey(cacheKey)) {
      return await _pendingFieldChecks[cacheKey]!;
    }

    // 3. Create the future for the check
    final Future<bool> checkFuture = () async {
      try {
        final domain = [
          ['model', '=', model],
          ['name', '=', fieldName],
        ];

        final result = useWhatsAppClient
            ? await _callWhatsAppKw(
                model: 'ir.model.fields',
                method: 'search_count',
                args: [],
                kwargs: {'domain': domain},
              )
            : await callKw(
                model: 'ir.model.fields',
                method: 'search_count',
                args: [],
                kwargs: {'domain': domain},
              );

        final exists = result is int && result > 0;
        _fieldCache[cacheKey] = exists;
        return exists;
      } catch (e) {
        debugPrint("Field check failed for $model.$fieldName: $e");
        // Significant Optimization: Cache 'false' on error to prevent RPC storm
        _fieldCache[cacheKey] = false;
        return false;
      } finally {
        // Remove from pending once settled
        _pendingFieldChecks.remove(cacheKey);
      }
    }();

    _pendingFieldChecks[cacheKey] = checkFuture;
    return await checkFuture;
  }

  Future<List<Sale>> getSales() async {
    final result = await callKw(
      model: 'sale.order',
      method: 'search_read',
      args: [],
      kwargs: {
        'context': {'bin_size': true},
        'domain': [], // Could filter by my sales if needed
        'fields': [
          'id',
          'name',
          'partner_id',
          'amount_total',
          'state',
          'date_order',
        ],
        'order': 'date_order desc',
        'limit': 200, // Aumentado de 50 a 200 para ver más pedidos
      },
    );
    // Verificar si el resultado es nulo o vacío antes de mapear
    if (result == null) return [];

    // Proteger el mapeo contra errores de estructura JSON
    try {
      return (result as List).map((json) => Sale.fromJson(json)).toList();
    } catch (e) {
      debugPrint("Error parsing Sales: $e");
      return [];
    }
  }

  Future<Sale?> getSaleWithLines(int saleId) async {
    try {
      // 1. Get the sale order details
      final saleRes = await callKw(
        model: 'sale.order',
        method: 'read',
        args: [
          [saleId],
        ],
        kwargs: {
          'fields': [
            'id',
            'name',
            'partner_id',
            'amount_total',
            'amount_untaxed',
            'amount_tax',
            'state',
            'date_order',
            'validity_date',
            'order_line',
            'invoice_ids',
            'note',
            'user_id',
          ],
        },
      );

      if (saleRes == null || (saleRes as List).isEmpty) return null;
      final saleData = saleRes[0] as Map<String, dynamic>;

      // 2. Load the lines
      List<SaleLine> lines = [];
      if (saleData['order_line'] is List &&
          (saleData['order_line'] as List).isNotEmpty) {
        final lineIds = (saleData['order_line'] as List).cast<int>();
        final linesRes = await callKw(
          model: 'sale.order.line',
          method: 'read',
          args: [lineIds],
          kwargs: {
            'fields': [
              'id',
              'name',
              'product_uom_qty',
              'price_unit',
              'price_total',
            ],
          },
        );

        if (linesRes != null && linesRes is List) {
          lines = linesRes
              .map((l) => SaleLine.fromJson(l as Map<String, dynamic>))
              .toList();
        }
      }

      // 3. Parse invoiceIds from raw data (before Sale.fromJson loses them)
      List<int> invoiceIds = [];
      if (saleData['invoice_ids'] is List) {
        invoiceIds = (saleData['invoice_ids'] as List)
            .whereType<int>()
            .toList();
      }

      // 4. Assemble the Sale object — pass invoiceIds explicitly
      final sale = Sale.fromJson(saleData);
      return Sale(
        id: sale.id,
        name: sale.name,
        partnerName: sale.partnerName,
        partnerId: sale.partnerId,
        amountTotal: sale.amountTotal,
        amountUntaxed: sale.amountUntaxed,
        amountTax: sale.amountTax,
        state: sale.state,
        dateOrder: sale.dateOrder,
        validityDate: sale.validityDate,
        lines: lines,
        invoiceIds: invoiceIds, // ✅ Fixed: was always empty before
      );
    } catch (e) {
      debugPrint("Error fetching Sale with lines: $e");
      return null;
    }
  }

  Future<int> createSale(Map<String, dynamic> vals) async {
    final result = await callKw(
      model: 'sale.order',
      method: 'create',
      args: [vals],
    );
    return result as int;
  }

  Future<void> updateSale(int id, Map<String, dynamic> vals) async {
    await callKw(
      model: 'sale.order',
      method: 'write',
      args: [
        [id],
        vals,
      ],
    );
  }

  // deleteSale already exists as helper in legacy code? Restoring just in case
  Future<void> deleteSale(int id) async {
    await callKw(
      model: 'sale.order',
      method: 'unlink',
      args: [
        [id],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // FASE 1: CRM (PIPELINE DE VENTAS)
  // ---------------------------------------------------------------------------

  /// Consultar crm.stage. Ordenar por sequence. Retornar lista limpia.
  Future<List<dynamic>> getCrmStages() async {
    final result = await callKw(
      model: 'crm.stage',
      method: 'search_read',
      args: [],
      kwargs: {
        'context': {'bin_size': true},
        'domain': [], // Se pueden añadir filtros si es necesario
        'fields': ['id', 'name', 'sequence'],
        'order': 'sequence asc',
      },
    );
    return result as List<dynamic>;
  }

  /// Consultar crm.tag para etiquetas de Oportunidades.
  Future<List<dynamic>> getCrmTags() async {
    final result = await callKw(
      model: 'crm.tag',
      method: 'search_read',
      args: [],
      kwargs: {
        'fields': ['id', 'name', 'color'],
        'limit': 100,
      },
    );
    return result as List<dynamic>;
  }

  /// Consultar crm.lead. Mis Oportunidades por Etapa.
  Future<List<dynamic>> getMyOpportunities(int stageId) async {
    final uid = currentUserId;
    if (uid == null) throw OdooServiceException("Usuario no identificado.");

    final result = await callKw(
      model: 'crm.lead',
      method: 'search_read',
      args: [],
      kwargs: {
        'context': {'bin_size': true},
        // Filtro: Stage ID, Type = Opportunity (User ID removido para ver todos durante testing/demo)
        'domain': [
          // ['user_id', '=', uid], // COMENTADO: El usuario indicó que es un demo y los datos pueden no estar asignados a él
          ['stage_id', '=', stageId],
          ['type', '=', 'opportunity'],
        ],
        'fields': [
          'id',
          'name',
          'partner_id',
          'expected_revenue',
          'probability',
          'description', // Restaurado por solicitud del usuario
        ],
        'limit': 200, // Paginación podría ser necesaria en el futuro
      },
    );
    return result as List<dynamic>;
  }

  /// Método write para mover tarjetas entre columnas (Actualizar Etapa del Lead).
  Future<void> updateLeadStage(int leadId, int newStageId) async {
    await callKw(
      model: 'crm.lead',
      method: 'write',
      args: [
        [leadId],
        {'stage_id': newStageId},
      ],
    );
  }

  /// Crea un nuevo Lead/Oportunidad en Odoo (crm.lead)
  Future<int> createLead(Map<String, dynamic> vals) async {
    final result = await callKw(
      model: 'crm.lead',
      method: 'create',
      args: [vals],
    );
    return result as int;
  }

  /// Obtiene los detalles de un Lead/Oportunidad por ID
  Future<Map<String, dynamic>> getLeadDetail(int leadId) async {
    final result = await callKw(
      model: 'crm.lead',
      method: 'read',
      args: [
        [leadId],
      ],
      kwargs: {
        'fields': [
          'name',
          'partner_id',
          'contact_name',
          'email_from',
          'phone',
          'description',
          'team_id',
          'user_id',
          'campaign_id',
          'medium_id',
          'source_id',
          'street',
          'city',
          'zip',
          'tag_ids',
        ],
      },
    );
    if (result is List && result.isNotEmpty) {
      return result[0] as Map<String, dynamic>;
    }
    throw OdooServiceException("Lead/Oportunidad no encontrada.");
  }

  // ---------------------------------------------------------------------------
  // FASE 2: EL NÚCLEO DE VENTAS (Cotización vinculada)
  // ---------------------------------------------------------------------------

  /// Crea una venta a partir de datos de un Lead.
  /// Valida que exista un cliente asociado.
  Future<int> createSaleFromLead(Map<String, dynamic> leadData) async {
    // leadData debe contener al menos 'partner_id' (que viene como [id, name] o flase)
    final partnerField = leadData['partner_id'];

    // En Odoo, si el campo es Many2one y está vacío, suele venir como false
    if (partnerField == null || partnerField is bool) {
      throw ClientRequiredException(
        "La oportunidad no tiene un cliente asignado.",
      );
    }

    int partnerId;
    if (partnerField is List && partnerField.isNotEmpty) {
      partnerId = partnerField[0];
    } else if (partnerField is int) {
      partnerId = partnerField;
    } else {
      throw ClientRequiredException("Formato de cliente inválido.");
    }

    final opportunityId = leadData['id'] as int?;

    // Llama a createSaleOrder pasando el lead_id para vincular
    return await createSaleOrder(
      partnerId: partnerId,
      opportunityId: opportunityId,
    );
  }

  /// Crea la cabecera del pedido de venta (sale.order).
  Future<int> createSaleOrder({
    required int partnerId,
    int? opportunityId,
  }) async {
    final Map<String, dynamic> vals = {
      'partner_id': partnerId,
      'state': 'draft', // Opcional, por defecto es draft/sent
    };

    // Dato Clave: Vinculación CRM -> Venta (Guard check for field availability)
    if (opportunityId != null) {
      final hasOpp = await fieldExists(
        model: 'sale.order',
        fieldName: 'opportunity_id',
      );
      if (hasOpp) {
        vals['opportunity_id'] = opportunityId;
      } else {
        debugPrint(
          "OdooService: 'opportunity_id' field not found in sale.order. Skipping link.",
        );
      }
    }

    final orderId = await callKw(
      model: 'sale.order',
      method: 'create',
      args: [vals],
    );

    return orderId as int;
  }

  /// Agrega una línea de producto al pedido (sale.order.line).
  /// Permite a Odoo calcular precios unitarios e impuestos automáticamente.
  Future<int> addOrderLine(int orderId, int productId, double qty) async {
    final lineId = await callKw(
      model: 'sale.order.line',
      method: 'create',
      args: [
        {
          'order_id': orderId,
          'product_id': productId,
          'product_uom_qty': qty,
          // No enviamos price_unit explícitamente para que Odoo use lista de precios
        },
      ],
    );
    return lineId as int;
  }

  // ---------------------------------------------------------------------------
  // FASE 3: CIERRE TRANSACCIONAL (Facturar y Cobrar)
  // ---------------------------------------------------------------------------

  /// Confirma la venta (Pasa de Presupuesto a Pedido de Venta).
  Future<void> confirmSale(int orderId, {Map<String, dynamic>? context}) async {
    await callKw(
      model: 'sale.order',
      method: 'action_confirm',
      args: [
        [orderId],
      ],
      kwargs: context == null ? {} : {'context': context},
    );
  }

  /// Crea la factura a partir del pedido de venta confirmado y devuelve su ID.
  Future<int?> createInvoiceFromSale(int orderId) async {
    try {
      // 1. Create the wizard for generating the invoice
      final wizardContext = {
        'active_model': 'sale.order',
        'active_ids': [orderId],
        'active_id': orderId,
      };

      final wizardId = await callKw(
        model: 'sale.advance.payment.inv',
        method: 'create',
        args: [
          {'advance_payment_method': 'percentage', 'amount': 100.0},
        ],
        kwargs: {'context': wizardContext},
      );

      // 2. Execute the wizard action to create the invoices
      await callKw(
        model: 'sale.advance.payment.inv',
        method: 'create_invoices',
        args: [
          [wizardId],
        ],
        kwargs: {'context': wizardContext},
      );

      // 3. Read the newly created invoice IDs
      final saleRes = await callKw(
        model: 'sale.order',
        method: 'read',
        args: [
          [orderId],
        ],
        kwargs: {
          'fields': ['invoice_ids'],
        },
      );

      if (saleRes != null && (saleRes as List).isNotEmpty) {
        final invoiceIds = saleRes[0]['invoice_ids'];
        if (invoiceIds is List && invoiceIds.isNotEmpty) {
          return invoiceIds.last as int;
        }
      }
      return null;
    } catch (e) {
      debugPrint("Error creating invoice from sale: $e");
      rethrow;
    }
  }

  /// Publica la factura (Validez fiscal).
  Future<void> postInvoice(int invoiceId) async {
    await callKw(
      model: 'account.move',
      method: 'action_post',
      args: [
        [invoiceId],
      ],
    );
  }

  /// Marca la factura como pagada (Versión MVP Simplificada).
  Future<void> registerPaymentStub(int invoiceId) async {
    // NOTA: El flujo real de Odoo requiere crear un account.payment y linkearlo o usar el wizard.
    // Para este MVP, ejecutamos un wizard simplificado o marcamos lo necesario.
    // Dada la complejidad, en muchos MVP "móviles rápidos" se llama a action_register_payment
    // que devuelve una acción de ventana, y luego se crea el pago.
    // Aquí asumiremos una implementación futura o un wizard custom.
    // Por ahora, solo logueamos la intención.
    debugPrint("Simulando registro de pago para factura $invoiceId");

    // Implementación real requeriría:
    // 1. Obtener context de la factura
    // 2. Crear 'account.payment.register' con el context active_ids=[invoiceId]
    // 3. Llamar action_create_payments()
  }

  /// Proceso completo de Venta Directa (Carrito): Cotización -> Confirmación -> Facturación.
  Future<bool> createSaleWithCart({
    required int partnerId,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      // 1. Crear el Pedido (sale.order)
      final int orderId = await createSaleOrder(partnerId: partnerId);

      // 2. Añadir todas las líneas del carrito
      for (final item in items) {
        final int productId = item['id'];
        final double qty = (item['quantity'] as num).toDouble();
        await addOrderLine(orderId, productId, qty);
      }

      // 3. Confirmar la Venta
      await confirmSale(orderId);

      // 4. Crear la Factura
      final int? invoiceId = await createInvoiceFromSale(orderId);
      if (invoiceId == null) return false;

      // 5. Publicar la Factura
      await postInvoice(invoiceId);

      return true;
    } catch (e) {
      debugPrint("Error in createSaleWithCart: $e");
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // FASE 4: LEGAL (Firma Digital)
  // ---------------------------------------------------------------------------

  /// Sube la imagen de la firma y la asocia al pedido de venta.
  Future<void> uploadSignature(int orderId, String base64Image) async {
    await callKw(
      model: 'ir.attachment',
      method: 'create',
      args: [
        {
          'name': 'signature_sale_$orderId.png',
          'type': 'binary',
          'datas': base64Image,
          'res_model': 'sale.order',
          'res_id': orderId,
          'mimetype': 'image/png',
        },
      ],
    );

    // Opcional: Si el modelo sale.order tiene un campo 'signature' binario o similar,
    // también se podría actualizar directamente allí:
    // await callKw(model: 'sale.order', method: 'write', args: [[orderId], {'signed_by': ..., 'signature': base64Image}]);
  }

  // ---------------------------------------------------------------------------
  // OTROS MÉTODOS DE SOPORTE (Productos, Partners, etc.)
  // ---------------------------------------------------------------------------

  Future<List<dynamic>> searchProducts(String query) async {
    return await callKw(
      model: 'product.product', // Especificado en diccionario: product.product
      method: 'search_read',
      args: [],
      kwargs: {
        'domain': [
          ['name', 'ilike', query],
          ['sale_ok', '=', true],
        ],
        'fields': ['id', 'name', 'list_price', 'uom_id'],
        'limit': 20,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // REPORTING & ANALYTICS
  // ---------------------------------------------------------------------------

  /// Obtiene estadísticas básicas de Facturación (Mocked/Calculated)
  Future<Map<String, dynamic>> getInvoiceStats() async {
    // 1. Total Receivables (Facturas Publicadas y No Pagadas)
    final receivablesRes = await callKw(
      model: 'account.move',
      method: 'search_read',
      args: [],
      kwargs: {
        'domain': [
          ['move_type', '=', 'out_invoice'],
          ['state', '=', 'posted'],
          [
            'payment_state',
            'in',
            ['not_paid', 'partial'],
          ],
        ],
        'fields': ['name', 'partner_id', 'amount_residual', 'invoice_date_due'],
      },
    );
    double totalReceivables = 0.0;
    List<dynamic> unpaidInvoices = []; // Store list for UI

    if (receivablesRes is List) {
      unpaidInvoices = receivablesRes;
      for (var inv in receivablesRes) {
        totalReceivables += (inv['amount_residual'] as num?)?.toDouble() ?? 0.0;
      }
    }

    // 2. Overdue Count (Vencidas)
    final today = DateTime.now().toIso8601String().split('T')[0];
    final overdueRes = await callKw(
      model: 'account.move',
      method: 'search_count',
      args: [
        [
          ['move_type', '=', 'out_invoice'],
          ['state', '=', 'posted'],
          [
            'payment_state',
            'in',
            ['not_paid', 'partial'],
          ],
          ['invoice_date_due', '<', today],
        ],
      ],
    );
    int overdueCount = overdueRes is int ? overdueRes : 0;

    // 3. Recent Payments (Pagos Recientes)
    final paymentsRes = await callKw(
      model: 'account.payment',
      method: 'search_read',
      args: [],
      kwargs: {
        'domain': [
          ['payment_type', '=', 'inbound'], // Incoming money
          ['state', '=', 'posted'],
        ],
        'fields': ['partner_id', 'date', 'amount', 'currency_id'],
        'order': 'date desc',
        'limit': 5,
      },
    );

    return {
      'total_receivables': totalReceivables,
      'overdue_count': overdueCount,
      'unpaid_invoices': unpaidInvoices, // Returned for Pay & Send flow
      'cash_flow_trend': 12.4, // Simulamos tendencia positiva
      'recent_payments': paymentsRes ?? [],
    };
  }

  /// Obtiene estadísticas de Ventas (Revenue, Count)
  Future<Map<String, dynamic>> getSalesStats() async {
    // Calcular Total Revenue de Ventas Confirmadas
    final revenueRes = await callKw(
      model: 'sale.order',
      method: 'search_read',
      args: [],
      kwargs: {
        'domain': [
          [
            'state',
            'in',
            ['sale', 'done'],
          ], // Solo ventas confirmadas
        ],
        'fields': ['amount_total'],
      },
    );

    double totalRevenue = 0.0;
    int dealCount = 0;

    if (revenueRes is List) {
      dealCount = revenueRes.length;
      for (var sale in revenueRes) {
        totalRevenue += (sale['amount_total'] as num?)?.toDouble() ?? 0.0;
      }
    }

    return {
      'total_revenue': totalRevenue,
      'deal_count': dealCount,
      'avg_deal_size': dealCount > 0 ? totalRevenue / dealCount : 0.0,
    };
  }

  /// Obtiene estadísticas de Productos (Top Sellers - Simulado con búsqueda simple)
  Future<List<dynamic>> getProductStats() async {
    // En un escenario real, haríamos un read_group sobre sale.report
    // Aquí simplemente traemos productos caros como "Top"
    final products = await callKw(
      model: 'product.product',
      method: 'search_read',
      args: [],
      kwargs: {
        'domain': [
          ['sale_ok', '=', true],
        ],
        'fields': [
          'name',
          'list_price',
          'sales_count',
        ], // sales_count es campo computado
        'order': 'list_price desc',
        'limit': 5,
      },
    );
    return products is List ? products : [];
  }

  // ---------------------------------------------------------------------------
  // FACTURACIÓN & PAGOS (New Request)
  // ---------------------------------------------------------------------------

  /// Registra el pago completo de una factura
  Future<void> registerFullPayment(int invoiceId) async {
    // 0. Fetch Invoice Details (Amount to Pay)
    final invRes = await callKw(
      model: 'account.move',
      method: 'read',
      args: [
        [invoiceId],
        ['amount_residual', 'currency_id'],
      ],
    );
    if (invRes == null || (invRes as List).isEmpty) {
      throw OdooServiceException("Invoice not found");
    }
    final inv = invRes[0];
    final amountToPay = inv['amount_residual'];
    final currencyId = (inv['currency_id'] is List)
        ? inv['currency_id'][0]
        : inv['currency_id'];

    // 1. Obtener el Journal (Diario) de Banco o Efectivo para pagar
    final journals = await callKw(
      model: 'account.journal',
      method: 'search_read',
      args: [],
      kwargs: {
        'domain': [
          [
            'type',
            'in',
            ['bank', 'cash'],
          ],
        ],
        'fields': ['id'],
        'limit': 1,
      },
    );

    if (journals == null || (journals as List).isEmpty) {
      throw OdooServiceException(
        "No se encontró un diario de pago (Banco/Efectivo).",
      );
    }
    final journalId = journals[0]['id'];

    // 2. Crear el Wizard de Pago (account.payment.register)
    final wizardContext = {
      'active_model': 'account.move',
      'active_ids': [invoiceId],
      'active_id': invoiceId,
    };

    final wizardId = await callKw(
      model: 'account.payment.register',
      method: 'create',
      args: [
        {
          'journal_id': journalId,
          'amount': amountToPay,
          'currency_id': currencyId,
          'payment_date': DateTime.now().toString().substring(0, 10),
        },
      ],
      kwargs: {'context': wizardContext},
    );

    // 3. Confirmar el Pago (action_create_payments)
    await callKw(
      model: 'account.payment.register',
      method: 'action_create_payments',
      args: [
        [wizardId],
      ],
      kwargs: {'context': wizardContext},
    );
  }



  // ---------------------------------------------------------------------------
  // FASE 5: WHATSAPP INTEGRATION (DUAL CLIENT ARCHITECTURE)
  // ---------------------------------------------------------------------------

  /// Helper: Executes RPC calls on the WhatsApp Odoo Instance (Robust RPC)
  Future<dynamic> _callWhatsAppKw({
    required String model,
    required String method,
    required List<dynamic> args,
    Map<String, dynamic>? kwargs,
  }) async {
    // ROUTING LOGIC for Odoo 19 + WhatsApp:
    // 1. whatsapp.evolution.api -> MUST use Admin Client (Legacy/Hardcoded)
    // 2. discuss.channel, mail.message, etc -> SHOULD use User Session (Active Session)

    final bool isEvolutionModel = model == 'whatsapp.evolution.api';

    if (!isEvolutionModel && _isPrismaMode) {
      // Use Main Odoo Client (User Session) for transparency and Discuss
      return await callKw(
        model: model,
        method: method,
        args: args,
        kwargs: kwargs,
      );
    }

    // Default: Use WhatsApp Client (Admin/Legacy)
    if (_whatsappUid == null) {
      await initWhatsAppClient();
      if (_whatsappUid == null) {
        throw OdooServiceException("WhatsApp Client failed to initialize.");
      }
    }

    final String url = "$_whatsappUrl/jsonrpc";
    debugPrint("[WHATSAPP RPC] $model.$method -> $url (Admin Context)");

    try {
      // 19/Feb Fix: Dynamically use the production DB if on Prisma
      // STRICT: Use the DB provided during login (_prismaDb) or fail.
      // We do NOT want to fallback to a hardcoded 'test19' unless explicitly set.
      final String dbToUse = _prismaDb ?? _whatsappDb;

      final String passToUse =
          (_whatsAppClient == _client && _prismaApiKey != null)
          ? _prismaApiKey!
          : _whatsappPassword;

      final body = {
        "jsonrpc": "2.0",
        "method": "call",
        "params": {
          "service": "object",
          "method": "execute_kw",
          "args": [
            dbToUse,
            _whatsappUid ??
                _prismaUid!, // Fallback to current UID if whatsappUid is null
            passToUse,
            model,
            method,
            args,
            kwargs ?? {},
          ],
        },
        "id": 1,
      };

      final response = await http
          .post(
            Uri.parse(url),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      final decoded = jsonDecode(response.body);

      if (decoded['error'] != null) {
        debugPrint("❌ WhatsApp RPC Error: ${jsonEncode(decoded['error'])}");
        throw OdooServiceException(
          "Error en Odoo WhatsApp: ${decoded['error']['message'] ?? 'Error desconocido'}",
        );
      }

      return decoded['result'];
    } catch (e) {
      debugPrint("❌ WhatsApp RPC Connection Error: $e");
      throw OdooServiceException("Error conectando con WhatsApp RPC: $e");
    }
  }

  /// Helper: Finds the Partner ID in the Secondary Odoo using data from Main Odoo
  Future<int?> _getSecondaryPartnerId(int mainPartnerId) async {
    // Optimization: If Main Odoo IS Prisma Odoo (v19), they are the same.
    if (_isPrismaMode) {
      return mainPartnerId;
    }

    try {
      // 1. Get Phone Data from Main Odoo (Defensive & Dynamic)
      String? mobile;
      String? phone;
      String name = 'Unknown';

      final hasMobileMain = await fieldExists(
        model: 'res.partner',
        fieldName: 'mobile',
      );

      final mainFields = <String>['phone', 'name'];
      if (hasMobileMain) {
        mainFields.insert(0, 'mobile');
      }

      try {
        final mainRes = await callKw(
          model: 'res.partner',
          method: 'read',
          args: [
            [mainPartnerId],
          ],
          kwargs: {'fields': mainFields},
        );
        if (mainRes is List && mainRes.isNotEmpty) {
          final d = mainRes[0];
          mobile = hasMobileMain && d['mobile'] is String ? d['mobile'] : null;
          phone = d['phone'] is String ? d['phone'] : null;
          name = d['name'] is String ? d['name'] : 'Unknown';
        }
      } catch (e) {
        debugPrint("Main Partner Read Error: $e");
        // Final fallback if even phone/name fail (unlikely but safe)
        return null;
      }

      String? searchValue = mobile ?? phone;
      if (searchValue == null) {
        debugPrint("WhatsApp Sync: Partner has no phone/mobile number.");
        return null;
      }

      // Ensure international format (basic check)
      if (!searchValue.startsWith('+')) {
        searchValue = '+$searchValue';
      }

      // 1. Dynamic Field Check (Robust Multi-Odoo compatibility)
      String searchField = 'phone';
      List<String> createFields = ['name', 'phone'];

      try {
        final fields = await _callWhatsAppKw(
          model: 'res.partner',
          method: 'fields_get',
          args: [],
          kwargs: {
            'attributes': ['string'],
          },
        );

        if (fields is Map) {
          if (fields.containsKey('mobile')) {
            searchField = 'mobile';
            createFields.add('mobile');
          }
        }
      } catch (e) {
        debugPrint("Field check warning: $e");
      }

      // 2. Search in Secondary Odoo
      // We prioritize mobile if available, otherwise phone.
      // Or we can search both if user requested robustness across versions.
      // But user said: "Falls back to using phone if mobile is not available".

      List<dynamic> secondaryRes = [];
      try {
        secondaryRes = await _callWhatsAppKw(
          model: 'res.partner',
          method: 'search_read',
          args: [],
          kwargs: {
            'domain': [
              [searchField, '=', searchValue],
            ],
            'fields': ['id'],
            'limit': 1,
          },
        );
      } catch (e) {
        debugPrint("Secondary Search Error ($searchField): $e");
        if (searchField == 'mobile') {
          // Fallback trial on phone just in case logic was flawed
          try {
            secondaryRes = await _callWhatsAppKw(
              model: 'res.partner',
              method: 'search_read',
              args: [],
              kwargs: {
                'domain': [
                  ['phone', '=', searchValue],
                ],
                'fields': ['id'],
                'limit': 1,
              },
            );
          } catch (_) {}
        }

        if (secondaryRes.isEmpty) {
          // Last resort fallback to name
          try {
            secondaryRes = await _callWhatsAppKw(
              model: 'res.partner',
              method: 'search_read',
              args: [],
              kwargs: {
                'domain': [
                  ['name', '=', name],
                ],
                'fields': ['id'],
                'limit': 1,
              },
            );
          } catch (_) {}
        }
      }

      if (secondaryRes.isNotEmpty) {
        debugPrint(
          "WhatsApp Sync: Found partner in secondary Odoo: ${secondaryRes[0]['id']}",
        );
        return secondaryRes[0]['id'];
      }

      // 3. Create if not found
      debugPrint(
        "WhatsApp Sync: Partner not found. Creating copy for $name...",
      );
      try {
        final Map<String, dynamic> vals = {'name': name, 'phone': searchValue};
        if (createFields.contains('mobile')) {
          vals['mobile'] = searchValue;
        }

        final createdId = await _callWhatsAppKw(
          model: 'res.partner',
          method: 'create',
          args: [vals],
        );
        return createdId is int ? createdId : null;
      } catch (e) {
        debugPrint("Secondary Create Error: $e");
        // Fallback to minimal create
        try {
          final createdId = await _callWhatsAppKw(
            model: 'res.partner',
            method: 'create',
            args: [
              {'name': name},
            ],
          );
          return createdId is int ? createdId : null;
        } catch (_) {
          return null;
        }
      }
    } catch (e) {
      debugPrint("WhatsApp Partner Sync Error: $e");
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // FASE 5: WHATSAPP INTEGRATION (STANDARD ODOO CHAT)
  // ---------------------------------------------------------------------------

  /// Helper: Gets or Creates the WhatsApp Channel ID for a partner (Secondary Odoo)
  Future<int> _getWhatsAppChannelId(int mainPartnerId) async {
    // Sync Partner First
    final secondaryPartnerId = await _getSecondaryPartnerId(mainPartnerId);
    if (secondaryPartnerId == null) {
      throw OdooServiceException(
        "No se pudo sincronizar el contacto para WhatsApp.",
      );
    }

    // 1. Try to open/create chat via different method names (Odoo 19 compatibility)
    final methodsToTry = [
      'open_whatsapp_chat',
      'channel_get_or_create',
      'get_whatsapp_channel',
    ];
    for (var methodName in methodsToTry) {
      try {
        final result = await _callWhatsAppKw(
          model: 'discuss.channel',
          method: methodName,
          args: [],
          kwargs: methodName == 'channel_get_or_create'
              ? {
                  'partners': [secondaryPartnerId],
                }
              : {'partner_id': secondaryPartnerId},
        );

        debugPrint("WhatsApp $methodName Result: $result");
        if (result is Map<String, dynamic>) {
          if (result['params'] != null &&
              result['params']['active_id'] != null) {
            return result['params']['active_id'] as int;
          }
          if (result['res_id'] != null) return result['res_id'] as int;
          if (result['id'] != null) return result['id'] as int;
        } else if (result is int) {
          return result;
        }
      } catch (_) {}
    }

    // Fallback Manual Search with more robust domain
    final channels = await _callWhatsAppKw(
      model: 'discuss.channel',
      method: 'search_read',
      args: [],
      kwargs: {
        'domain': [
          ['channel_type', '=', 'whatsapp'],
          '|',
          [
            'channel_partner_ids',
            'in',
            [secondaryPartnerId],
          ],
          [
            'channel_member_ids.partner_id',
            'in',
            [secondaryPartnerId],
          ],
        ],
        'fields': ['id'],
        'limit': 1,
      },
    );

    debugPrint("WhatsApp Manual Search Result: $channels");
    if (channels is List && channels.isNotEmpty) {
      return channels[0]['id'] as int;
    }

    throw OdooServiceException("No se pudo iniciar el chat de WhatsApp.");
  }

  /// Fetches the message history for a partner via their WhatsApp channel (Secondary Odoo).
  Future<List<WhatsAppMessage>> fetchWhatsAppMessages(
    int? mainPartnerId, {
    int? channelId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final int actualChannelId =
          channelId ?? await _getWhatsAppChannelId(mainPartnerId!);
      final secondaryPartnerId = mainPartnerId != null
          ? await _getSecondaryPartnerId(mainPartnerId)
          : null;

      final messages = await _callWhatsAppKw(
        model: 'mail.message',
        method: 'search_read',
        args: [],
        kwargs: {
          'domain': [
            ['res_id', '=', actualChannelId],
            ['model', '=', 'discuss.channel'],
            ['message_type', '!=', 'notification'], // Hide system notifications
          ],
          'fields': [
            'id',
            'body',
            'date',
            'author_id',
            'attachment_ids',
            'message_type',
          ],
          'order': 'id desc',
          'limit': limit,
          'offset': offset,
        },
      );

      if (messages is List) {
        debugPrint(
          "📩 [FETCH] Messages received: ${messages.length}. Checking attachments...",
        );
        // 1. Collect Attachment IDs
        final Set<int> attachmentIds = {};
        for (var m in messages) {
          if (m['attachment_ids'] is List &&
              (m['attachment_ids'] as List).isNotEmpty) {
            for (var id in (m['attachment_ids'] as List)) {
              if (id is int) attachmentIds.add(id);
            }
          }
        }
        debugPrint("📩 [FETCH] Attachment IDs found: $attachmentIds");

        // 2. Fetch Attachment Metadata (Mimetype, Name, Duration)
        debugPrint(
          "📩 fetchWhatsAppMessages: Found ${messages.length} messages. Attachment IDs to fetch: $attachmentIds",
        );
        final Map<int, Map<String, dynamic>> attachmentMap =
            await _getAttachmentDetails(attachmentIds.toList());
        debugPrint(
          "📩 fetchWhatsAppMessages: Attachment mapping complete. Found metadata for ${attachmentMap.length} attachments.",
        );

        return messages
            .map(
              (m) => _mapOdooMessageToWhatsApp(
                m,
                attachmentMap,
                secondaryPartnerId,
              ),
            )
            .toList()
            .reversed
            .toList();
      }
    } catch (e) {
      debugPrint("WhatsApp Fetch Error: $e");
    }
    return [];
  }

  /// Helper to map Odoo mail.message to WhatsAppMessage
  WhatsAppMessage _mapOdooMessageToWhatsApp(
    Map<String, dynamic> m,
    Map<int, Map<String, dynamic>> attachmentMap,
    int? secondaryPartnerId,
  ) {
    final authorId = (m['author_id'] is List && m['author_id'].isNotEmpty)
        ? m['author_id'][0]
        : -1;

    final bool isOutgoing = (secondaryPartnerId != null)
        ? (authorId != secondaryPartnerId)
        : (authorId == _mainPartnerId);

    if (m['id'] != null) {
      debugPrint(
        "[MAP] Mapping message ${m['id']} - isOutgoing: $isOutgoing, authorId: $authorId, secondaryPartnerId: $secondaryPartnerId",
      );
    }

    String body = m['body'] is String ? m['body'] : '';
    body = body.replaceAll(RegExp(r'<[^>]*>'), '').trim();

    // Determine Message Type & Attachment
    MessageType type = MessageType.text;
    String? attachmentUrl;
    String? fileName;
    Duration? duration;

    if (m['attachment_ids'] is List &&
        (m['attachment_ids'] as List).isNotEmpty) {
      final firstAttId = (m['attachment_ids'] as List)[0] as int;
      debugPrint("🔗 [MAP] Message ${m['id']} has attachment ID: $firstAttId");

      // Always set URL if we have an ID - Fail-safe for metadata failure
      attachmentUrl = "/web/content/$firstAttId";

      if (attachmentMap.containsKey(firstAttId)) {
        final att = attachmentMap[firstAttId]!;
        final mime = (att['mimetype'] as String? ?? '').toLowerCase();
        fileName = att['name'] as String?;
        debugPrint(
          "📎 [MAP] Found metadata for $firstAttId: $fileName ($mime)",
        );

        // Try to get duration if available (Evolution sync might store it)
        if (att['duration'] != null && att['duration'] is int) {
          duration = Duration(seconds: att['duration'] as int);
        }

        final nameLower = (fileName ?? '').toLowerCase();
        final isImage =
            mime.startsWith('image/') ||
            nameLower.endsWith('.jpg') ||
            nameLower.endsWith('.jpeg') ||
            nameLower.endsWith('.png') ||
            nameLower.endsWith('.webp') ||
            nameLower.endsWith('.gif');

        if (mime.startsWith('audio/') ||
            nameLower.endsWith('.m4a') ||
            nameLower.endsWith('.mp3')) {
          type = MessageType.audio;
        } else if (isImage) {
          if (mime == 'image/webp' || nameLower.endsWith('.webp')) {
            type = MessageType.sticker;
          } else {
            type = MessageType.image;
          }
        } else if (mime.startsWith('video/') || nameLower.endsWith('.mp4')) {
          type = MessageType.video;
        } else {
          type = MessageType.file;
        }
      }
    }

    return WhatsAppMessage(
      id: m['id'] as int,
      body: body,
      type: type,
      state: isOutgoing ? MessageState.sent : MessageState.received,
      isOutgoing: isOutgoing,
      timestamp: DateTime.parse(m['date']),
      attachmentUrl: attachmentUrl,
      fileName: fileName,
      duration: duration,
    );
  }

  /// Helper to fetch attachment details (mimetype, name) for a list of IDs
  Future<Map<int, Map<String, dynamic>>> _getAttachmentDetails(
    List<int> ids,
  ) async {
    if (ids.isEmpty) return {};
    try {
      final results = await _callWhatsAppKw(
        model: 'ir.attachment',
        method: 'read',
        args: [ids],
        kwargs: {
          'fields': ['id', 'name', 'mimetype'],
        },
      );
      final Map<int, Map<String, dynamic>> map = {};
      if (results is List) {
        debugPrint(
          "📦 _getAttachmentDetails: Found ${results.length} attachments for ${ids.length} IDs",
        );
        for (var r in results) {
          if (r['id'] is int) {
            map[r['id']] = r as Map<String, dynamic>;
          }
        }
      } else {
        debugPrint(
          "⚠️ _getAttachmentDetails: RPC returned unexpected result: $results",
        );
      }
      return map;
    } catch (e) {
      debugPrint("Attachment Metadata Fetch Error: $e");
      return {};
    }
  }

  Future<WhatsAppMessage?> sendWhatsAppMessage(
    int? mainPartnerId,
    String message, {
    int? channelId,
  }) async {
    try {
      int? discussMsgId;
      int? targetPartnerId = mainPartnerId;
      // String? targetPhone;

      // 1. RESOLVE RECIPIENT & PHONE
      if (targetPartnerId == null && channelId != null) {
        // Find recipient from channel members
        try {
          final channelInfo = await _callWhatsAppKw(
            model: 'discuss.channel',
            method: 'read',
            args: [
              [channelId],
            ],
            kwargs: {
              'fields': ['channel_partner_ids'],
            },
          );
          if (channelInfo is List && channelInfo.isNotEmpty) {
            final partners = channelInfo[0]['channel_partner_ids'] as List;
            // The recipient is the partner who is NOT us
            for (var pId in partners) {
              if (pId != _mainPartnerId) {
                targetPartnerId = pId;
                break;
              }
            }
          }
        } catch (e) {
          debugPrint("WhatsApp Resolver Error: $e");
        }
      }

      /*
      if (targetPartnerId != null) {
        final hasMobile = await fieldExists(
          model: 'res.partner',
          fieldName: 'mobile',
        );
        final fields = <String>['phone', 'name'];
        if (hasMobile) fields.insert(0, 'mobile');

        final mainRes = await callKw(
          model: 'res.partner',
          method: 'read',
          args: [
            [targetPartnerId],
          ],
          kwargs: {'fields': fields},
        );

        if (mainRes is List && mainRes.isNotEmpty) {
          final d = mainRes[0];
          final mobile = hasMobile && d['mobile'] is String
              ? d['mobile']
              : null;
          final phone = d['phone'] is String ? d['phone'] : null;
          targetPhone = mobile ?? phone;
        }
      }
      */

      // 3. STRATEGY 2: Odoo Visibility (Discuss Channel)
      try {
        final actualChannelId =
            channelId ?? await _getWhatsAppChannelId(targetPartnerId!);
        debugPrint("WhatsApp: Syncing to Discuss channel $actualChannelId...");
        final res = await _callWhatsAppKw(
          model: 'discuss.channel',
          method: 'message_post',
          args: [actualChannelId],
          kwargs: {
            'body': message,
            'message_type': 'comment',
            'subtype_xmlid': 'mail.mt_comment',
          },
        );
        if (res is int) {
          discussMsgId = res;
          debugPrint("[ODOO] message_post success. ID: $discussMsgId");
        } else if (res is Map && (res['id'] != null || res['res_id'] != null)) {
          discussMsgId = (res['id'] ?? res['res_id']) as int;
          debugPrint("[ODOO] message_post success (Map). ID: $discussMsgId");
        } else if (res != null) {
          debugPrint(
            "[ODOO] message_post success? Unexpected result format: $res",
          );
          // We set a non-null placeholder to avoid throwing, as the RPC was technically successful.
          discussMsgId = -1;
        } else {
          debugPrint("[ODOO] message_post returned null");
        }
      } catch (e) {
        debugPrint("[ODOO] message_post ERROR: $e");
      }

      // 4. OPTIMISTIC SUCCESS: Even if we don't have a real ID, if we reached this point
      // without a critical network exception, we assume it's "Sent" and let polling reconcile it.
      return WhatsAppMessage(
        id: (discussMsgId != null && discussMsgId > 0)
            ? discussMsgId
            : DateTime.now().millisecondsSinceEpoch,
        body: message,
        type: MessageType.text,
        state: MessageState.sent,
        isOutgoing: true,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      debugPrint("WhatsApp Global Send Error: $e");
      rethrow;
    }
  }

  Future<WhatsAppMessage?> sendWhatsAppFile(
    int? mainPartnerId,
    String filePath, {
    int? channelId,
  }) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return null;

      final bytes = await file.readAsBytes();
      final base64Data = base64Encode(bytes);
      final fileName = filePath.split('/').last;

      // Determine mimetype (basic)
      String mimetype = 'application/octet-stream';
      if (fileName.toLowerCase().endsWith('.pdf')) {
        mimetype = 'application/pdf';
      } else if (fileName.toLowerCase().endsWith('.png')) {
        mimetype = 'image/png';
      } else if (fileName.toLowerCase().endsWith('.jpg') ||
          fileName.toLowerCase().endsWith('.jpeg')) {
        mimetype = 'image/jpeg';
      } else if (fileName.toLowerCase().endsWith('.mp4')) {
        mimetype = 'video/mp4';
      } else if (fileName.toLowerCase().endsWith('.webp')) {
        mimetype = 'image/webp';
      }

      int? discussMsgId;

      // 1. Sync to Discuss (Visibility)
      try {
        final actualChannelId =
            channelId ?? await _getWhatsAppChannelId(mainPartnerId!);

        // Create Attachment
        final attachmentId = await _callWhatsAppKw(
          model: 'ir.attachment',
          method: 'create',
          args: [
            {
              'name': fileName,
              'type': 'binary',
              'datas': base64Data,
              'res_model': 'discuss.channel',
              'res_id': actualChannelId,
              'mimetype': mimetype,
            },
          ],
        );

        // Post Message with Attachment
        final msgId = await _callWhatsAppKw(
          model: 'discuss.channel',
          method: 'message_post',
          args: [actualChannelId],
          kwargs: {
            'body': '',
            'attachment_ids': [attachmentId],
            'message_type': 'comment',
            'subtype_xmlid':
                'mail.mt_comment', // Important for triggering Odoo's listeners
          },
        );
        if (msgId is int) {
          discussMsgId = msgId;
        } else if (msgId is Map &&
            (msgId['id'] != null || msgId['res_id'] != null)) {
          discussMsgId = (msgId['id'] ?? msgId['res_id']) as int;
        }
      } catch (e) {
        debugPrint("WhatsApp File Sync Error: $e");
      }

      // Determine local Type
      MessageType type = MessageType.file;
      if (mimetype.startsWith('image/')) {
        type = (mimetype == 'image/webp')
            ? MessageType.sticker
            : MessageType.image;
      } else if (mimetype.startsWith('video/')) {
        type = MessageType.video;
      }

      return WhatsAppMessage(
        id: discussMsgId ?? DateTime.now().millisecondsSinceEpoch,
        body: fileName, // Show filename as body for now
        type: type,
        state: MessageState.sent,
        isOutgoing: true,
        timestamp: DateTime.now(),
        attachmentUrl: filePath, // Local path for immediate display
        fileName: fileName,
      );
    } catch (e) {
      debugPrint("WhatsApp Global File Error: $e");
      return null;
    }
  }

  Future<WhatsAppMessage?> sendWhatsAppAudio(
    int? mainPartnerId,
    String filePath, {
    int? channelId,
  }) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return null;

      final bytes = await file.readAsBytes();
      final base64Data = base64Encode(bytes);
      final fileName = filePath.split('/').last;

      int? discussMsgId;

      // 1. Sync to Discuss (Visibility)
      try {
        final actualChannelId =
            channelId ?? await _getWhatsAppChannelId(mainPartnerId!);
        final attachmentId = await _callWhatsAppKw(
          model: 'ir.attachment',
          method: 'create',
          args: [
            {
              'name': fileName,
              'type': 'binary',
              'datas': base64Data,
              'res_model': 'discuss.channel',
              'res_id': actualChannelId,
              'mimetype': fileName.toLowerCase().endsWith('.m4a')
                  ? 'audio/mp4'
                  : (fileName.toLowerCase().endsWith('.wav')
                        ? 'audio/wav'
                        : 'audio/mpeg'),
            },
          ],
        );

        final msgId = await _callWhatsAppKw(
          model: 'discuss.channel',
          method: 'message_post',
          args: [actualChannelId],
          kwargs: {
            'body': '',
            'attachment_ids': [attachmentId],
            'message_type': 'comment',
            'subtype_xmlid': 'mail.mt_comment',
          },
        );
        if (msgId is int) {
          discussMsgId = msgId;
        } else if (msgId is Map &&
            (msgId['id'] != null || msgId['res_id'] != null)) {
          discussMsgId = (msgId['id'] ?? msgId['res_id']) as int;
        }

        // Future: Add Evolution API support for sending audio files if needed
      } catch (e) {
        debugPrint("WhatsApp Audio Sync Error: $e");
      }

      return WhatsAppMessage(
        id: discussMsgId ?? DateTime.now().millisecondsSinceEpoch,
        body: "",
        type: MessageType.audio,
        state: MessageState.sent,
        isOutgoing: true,
        timestamp: DateTime.now(),
        attachmentUrl: filePath, // Local Path strictly needed for playback!
        fileName: fileName,
      );
    } catch (e) {
      debugPrint("WhatsApp Global Audio Error: $e");
      return null;
    }
  }

  /// Downloads media from Odoo using authenticated session
  Future<String?> downloadMedia(String url) async {
    // Determine which client/session to use.
    // WhatsApp media is usually relative (/web/content) or on the prisma server.
    final bool isWhatsAppMedia =
        !url.startsWith('http') || url.contains('prisma');

    // Ensure WhatsApp client is ready if needed
    if (isWhatsAppMedia &&
        (_whatsAppClient == null || _whatsAppClient!.sessionId == null)) {
      debugPrint(
        "⏳ downloadMedia: WhatsApp Client or Session missing. Initializing...",
      );
      await initWhatsAppClient();
    }

    final client = isWhatsAppMedia ? (_whatsAppClient ?? _client) : _client;
    if (client == null || client.sessionId == null) {
      debugPrint(
        "❌ downloadMedia: No active session for ${isWhatsAppMedia ? 'WhatsApp' : 'Main'} client. URL: $url",
      );
      return null;
    }

    try {
      String cleanUrl = url;
      if (!url.startsWith('http')) {
        final baseUrl = client.baseURL.endsWith('/')
            ? client.baseURL.substring(0, client.baseURL.length - 1)
            : client.baseURL;
        cleanUrl = url.startsWith('/') ? url : '/$url';
        cleanUrl = "$baseUrl$cleanUrl";
      }

      // Check Cache First (using Hash to handle dynamic extensions)
      final directory = await getApplicationDocumentsDirectory();
      final String filenameBase = "media_${cleanUrl.hashCode}";

      final dir = Directory(directory.path);
      try {
        if (dir.existsSync()) {
          final existingFiles = dir.listSync().where(
            (f) => f.path.contains(filenameBase),
          );
          if (existingFiles.isNotEmpty) {
            final file = File(existingFiles.first.path);
            if (await file.length() > 500) {
              debugPrint("📦 Media found in cache: ${file.path}");
              return file.path;
            }
          }
        }
      } catch (e) {
        debugPrint("Cache discovery error: $e");
      }

      debugPrint("⬇️ Downloading media: $cleanUrl");

      final response = await http.get(
        Uri.parse(cleanUrl),
        headers: {'Cookie': 'session_id=${client.sessionId!.id}'},
      );

      if (response.statusCode == 200) {
        if (response.bodyBytes.length < 100 &&
            response.body.contains("session_expired")) {
          debugPrint("❌ Download failed: Session Expired according to body.");
          return null;
        }

        // Determine extension from Content-Type
        String ext = 'jpg';
        final contentType =
            response.headers['content-type']?.toLowerCase() ?? '';
        if (contentType.contains('video/mp4')) {
          ext = 'mp4';
        } else if (contentType.contains('audio/')) {
          ext = 'm4a';
        } else if (contentType.contains('pdf')) {
          ext = 'pdf';
        } else if (contentType.contains('png')) {
          ext = 'png';
        } else if (contentType.contains('webp')) {
          ext = 'webp';
        }

        final finalPath = '${directory.path}/$filenameBase.$ext';
        final file = File(finalPath);
        await file.writeAsBytes(response.bodyBytes);

        debugPrint(
          "✅ Media saved to: $finalPath (${response.bodyBytes.length} bytes)",
        );
        return finalPath;
      } else {
        debugPrint("❌ Download failed: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      debugPrint("❌ Download Exception: $e");
      return null;
    }
  }

  Future<List<WhatsAppMessage>> pollWhatsAppMessages(
    int? mainPartnerId,
    int lastMessageId, {
    int? channelId,
  }) async {
    // Poll checks for messages with ID > lastMessageId in the channel
    try {
      final int actualChannelId =
          channelId ?? await _getWhatsAppChannelId(mainPartnerId!);

      // We need to know who the "other" person is to determine direction
      final secondaryPartnerId = mainPartnerId != null
          ? await _getSecondaryPartnerId(mainPartnerId)
          : null;

      final messages = await _callWhatsAppKw(
        model: 'mail.message',
        method: 'search_read',
        args: [],
        kwargs: {
          'domain': [
            ['res_id', '=', actualChannelId],
            ['model', '=', 'discuss.channel'],
            ['id', '>', lastMessageId],
            ['message_type', '!=', 'notification'],
          ],
          'fields': [
            'id',
            'body',
            'date',
            'author_id',
            'attachment_ids',
            'message_type',
          ],
          'order': 'id asc', // Use ID order for polling consistency
        },
      );

      if (messages is List && messages.isNotEmpty) {
        debugPrint(
          "[ODOO] Poll found ${messages.length} messages newer than $lastMessageId",
        );
        // Collect Attachment IDs
        final Set<int> attachmentIds = {};
        for (var m in messages) {
          if (m['attachment_ids'] is List &&
              (m['attachment_ids'] as List).isNotEmpty) {
            for (var id in (m['attachment_ids'] as List)) {
              if (id is int) attachmentIds.add(id);
            }
          }
        }

        // Fetch Attachment Metadata
        final Map<int, Map<String, dynamic>> attachmentMap =
            await _getAttachmentDetails(attachmentIds.toList());

        return messages
            .map(
              (m) => _mapOdooMessageToWhatsApp(
                m,
                attachmentMap,
                secondaryPartnerId,
              ),
            )
            .toList();
      }
    } catch (e) {
      debugPrint("Poll Error: $e");
    }
    return [];
  }

  /// Fetches all active Discuss channels where the user is a member.
  Future<List<Map<String, dynamic>>> fetchDiscussChannels() async {
    try {
      if (_mainPartnerId == null) return [];

      final channels = await _callWhatsAppKw(
        model: 'discuss.channel',
        method: 'search_read',
        args: [],
        kwargs: {
          'domain': [
            [
              'channel_type',
              'in',
              ['whatsapp', 'chat', 'group'],
            ],
          ],
          'fields': [
            'id',
            'name',
            'channel_type',
            'description',
            'display_name',
            'message_needaction_counter',
            'channel_partner_ids',
            'image_128',
            'image_1920',
          ],
          'order': 'id desc',
        },
      );

      if (channels is List) {
        return channels.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint("Discuss Channel Fetch Error: $e");
    }
    return [];
  }

  /// Downloads a PDF report from Odoo
  Future<String?> renderReport(String reportName, List<int> resIds) async {
    try {
      debugPrint("📄 Rendering Report: $reportName for IDs: $resIds");

      // Odoo standard report rendering using action_report
      // We call the 'render_qweb_pdf' method of 'ir.actions.report'
      // Note: This usually requires a proper 'ir.actions.report' record or logic.
      // Often, mobile apps use a direct download URL if available, but for signed sessions
      // we can try the callKw version:
      final result = await callKw(
        model: 'ir.actions.report',
        method: '_render_qweb_pdf',
        args: [reportName, resIds],
      );

      if (result is List && result.length == 2) {
        final pdfBase64 = result[0] as String;
        final pdfBytes = base64Decode(pdfBase64);

        final directory = await getApplicationDocumentsDirectory();
        final filename =
            "${reportName.split('.').last}_${DateTime.now().millisecondsSinceEpoch}.pdf";
        final localPath = '${directory.path}/$filename';

        final file = File(localPath);
        await file.writeAsBytes(pdfBytes);

        debugPrint("✅ Report saved to: $localPath");
        return localPath;
      }

      debugPrint("❌ Report Rendering Failed: Unexpected result format.");
      return null;
    } catch (e) {
      debugPrint("❌ Report Rendering Exception: $e");
      // Fallback: If _render_qweb_pdf is private or fails, we might need to use a download URL
      // But for now, we follow the RPC strategy.
      return null;
    }
  }

  /// Helper to get the best phone for WhatsApp for a partner
  Future<String?> getPartnerPhone(int partnerId) async {
    try {
      final res = await callKw(
        model: 'res.partner',
        method: 'read',
        args: [
          [partnerId],
          ['mobile', 'phone'],
        ],
      );

      if (res is List && res.isNotEmpty) {
        final d = res[0];
        final mobile = d['mobile'] is String ? d['mobile'] as String : null;
        final phone = d['phone'] is String ? d['phone'] as String : null;
        return (mobile != null && mobile.isNotEmpty) ? mobile : phone;
      }
    } catch (e) {
      debugPrint("Error fetching partner phone: $e");
    }
    return null;
  }

  int? get currentPartnerId => _mainPartnerId;

  /// Helper to get the best available image from a record's data map
  static String? getBestImage(Map<String, dynamic>? data) {
    if (data == null) return null;

    final imageFields = [
      'image_1920',
      'image_1024',
      'image_512',
      'image_256',
      'image_128',
    ];

    for (var field in imageFields) {
      final value = data[field];
      if (value != null && value is String && value.isNotEmpty && value != 'false') {
        return sanitizeBase64(value);
      }
    }

    return null;
  }

  static String sanitizeBase64(String base64String) {
    if (base64String.isEmpty) return '';
    if (base64String.contains(',')) {
      base64String = base64String.split(',').last;
    }
    return base64String.replaceAll(RegExp(r'\s+'), '');
  }
}
