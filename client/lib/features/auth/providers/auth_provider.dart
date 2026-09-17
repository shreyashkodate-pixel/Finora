import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../shared/api_client.dart';
import '../../../shared/storage.dart';
import '../models/user_model.dart';

/// Manages authentication state, token rotation, and active session per SRS §3.3a & §3.6.
class AuthProvider extends ChangeNotifier {
  final ApiClient apiClient;
  final SessionStorage storage;

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isInitialized = false;

  AuthProvider({
    required this.apiClient,
    required this.storage,
  }) {
    apiClient.onTokenExpired = refreshToken;
  }

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isInitialized => _isInitialized;

  /// Restore existing session from secure storage on startup
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await storage.getAccessToken();
      final profile = await storage.getUserProfile();

      if (token != null && profile != null) {
        apiClient.setAccessToken(token);
        _currentUser = UserModel.fromJson(profile);
      }
    } catch (e) {
      debugPrint('Session restore failed: $e');
      await storage.clearSession();
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Sign in with Email and Password
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await apiClient.post(
        '/auth/login',
        body: {'email': email, 'password': password},
      );

      final accessToken = res['access_token'] as String;
      final refreshToken = res['refresh_token'] as String;
      final userJson = res['user'] as Map<String, dynamic>;

      await storage.setAccessToken(accessToken);
      await storage.setRefreshToken(refreshToken);
      await storage.setUserProfile(userJson);

      apiClient.setAccessToken(accessToken);
      _currentUser = UserModel.fromJson(userJson);
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected connection error occurred.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Register a new account
  Future<bool> register({
    required String email,
    required String password,
    required String role,
    String? site,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await apiClient.post(
        '/auth/register',
        body: {
          'email': email,
          'password': password,
          'role': role,
          'site': site,
        },
      );

      final accessToken = res['access_token'] as String;
      final refreshToken = res['refresh_token'] as String;
      final userJson = res['user'] as Map<String, dynamic>;

      await storage.setAccessToken(accessToken);
      await storage.setRefreshToken(refreshToken);
      await storage.setUserProfile(userJson);

      apiClient.setAccessToken(accessToken);
      _currentUser = UserModel.fromJson(userJson);
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Registration failed. Please check your details.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign in with Google OAuth authorization code and PKCE verifier
  Future<bool> loginWithGoogle({
    required String code,
    required String codeVerifier,
    required String redirectUri,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await apiClient.post(
        '/auth/google',
        body: {
          'code': code,
          'code_verifier': codeVerifier,
          'redirect_uri': redirectUri,
        },
      );

      final accessToken = res['access_token'] as String;
      final refreshToken = res['refresh_token'] as String;
      final userJson = res['user'] as Map<String, dynamic>;

      await storage.setAccessToken(accessToken);
      await storage.setRefreshToken(refreshToken);
      await storage.setUserProfile(userJson);

      apiClient.setAccessToken(accessToken);
      _currentUser = UserModel.fromJson(userJson);
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Transparently rotate refresh token on 401 Unauthorized
  Future<bool> refreshToken() async {
    final currentRefresh = await storage.getRefreshToken();
    if (currentRefresh == null) return false;

    try {
      final res = await apiClient.post(
        '/auth/refresh',
        body: {'refresh_token': currentRefresh},
      );

      final newAccessToken = res['access_token'] as String;
      final newRefreshToken = res['refresh_token'] as String;

      await storage.setAccessToken(newAccessToken);
      await storage.setRefreshToken(newRefreshToken);
      apiClient.setAccessToken(newAccessToken);
      return true;
    } catch (_) {
      await logout();
      return false;
    }
  }

  /// End current session and revoke tokens
  Future<void> logout() async {
    try {
      final refreshToken = await storage.getRefreshToken();
      if (refreshToken != null) {
        await apiClient.post('/auth/logout', body: {'refresh_token': refreshToken});
      }
    } catch (_) {}

    await storage.clearSession();
    apiClient.setAccessToken(null);
    _currentUser = null;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
