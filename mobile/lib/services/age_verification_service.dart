// ABOUTME: Service for managing age verification status across app sessions
// ABOUTME: Stores verification status using SharedPreferences for persistence

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AgeVerificationService extends ChangeNotifier {
  static const String _ageVerifiedKey = 'age_verified';
  static const String _verificationDateKey = 'age_verification_date';
  
  bool? _isAgeVerified;
  DateTime? _verificationDate;
  
  bool get isAgeVerified => _isAgeVerified ?? false;
  DateTime? get verificationDate => _verificationDate;
  
  Future<void> initialize() async {
    await _loadVerificationStatus();
  }
  
  Future<void> _loadVerificationStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isAgeVerified = prefs.getBool(_ageVerifiedKey);
      
      final dateMillis = prefs.getInt(_verificationDateKey);
      if (dateMillis != null) {
        _verificationDate = DateTime.fromMillisecondsSinceEpoch(dateMillis);
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading age verification status: $e');
    }
  }
  
  Future<void> setAgeVerified(bool verified) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setBool(_ageVerifiedKey, verified);
      
      if (verified) {
        final now = DateTime.now();
        await prefs.setInt(_verificationDateKey, now.millisecondsSinceEpoch);
        _verificationDate = now;
      } else {
        await prefs.remove(_verificationDateKey);
        _verificationDate = null;
      }
      
      _isAgeVerified = verified;
      notifyListeners();
      
      debugPrint('Age verification status updated: $verified');
    } catch (e) {
      debugPrint('Error saving age verification status: $e');
      rethrow;
    }
  }
  
  Future<bool> checkAgeVerification() async {
    if (_isAgeVerified == null) {
      await _loadVerificationStatus();
    }
    return isAgeVerified;
  }
  
  Future<void> clearVerificationStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_ageVerifiedKey);
      await prefs.remove(_verificationDateKey);
      
      _isAgeVerified = null;
      _verificationDate = null;
      notifyListeners();
      
      debugPrint('Age verification status cleared');
    } catch (e) {
      debugPrint('Error clearing age verification status: $e');
    }
  }
}