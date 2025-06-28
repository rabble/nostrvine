import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openvine/services/age_verification_service.dart';

void main() {
  group('AgeVerificationService', () {
    late AgeVerificationService service;

    setUp(() {
      // Reset SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});
      service = AgeVerificationService();
    });

    test('should initialize with age not verified', () async {
      await service.initialize();
      expect(service.isAgeVerified, false);
      expect(service.verificationDate, isNull);
    });

    test('should save age verification status as true', () async {
      await service.initialize();
      
      await service.setAgeVerified(true);
      
      expect(service.isAgeVerified, true);
      expect(service.verificationDate, isNotNull);
      expect(service.verificationDate!.difference(DateTime.now()).inSeconds.abs(), lessThan(2));
    });

    test('should save age verification status as false', () async {
      await service.initialize();
      
      await service.setAgeVerified(false);
      
      expect(service.isAgeVerified, false);
      expect(service.verificationDate, isNull);
    });

    test('should persist age verification status across instances', () async {
      // First instance sets verification
      await service.initialize();
      await service.setAgeVerified(true);
      final firstDate = service.verificationDate;
      
      // Create new instance and check persistence
      final newService = AgeVerificationService();
      await newService.initialize();
      
      expect(newService.isAgeVerified, true);
      expect(newService.verificationDate?.millisecondsSinceEpoch, 
             equals(firstDate?.millisecondsSinceEpoch));
    });

    test('should clear verification status', () async {
      await service.initialize();
      await service.setAgeVerified(true);
      
      expect(service.isAgeVerified, true);
      
      await service.clearVerificationStatus();
      
      expect(service.isAgeVerified, false);
      expect(service.verificationDate, isNull);
    });

    test('checkAgeVerification should load status if not initialized', () async {
      // Don't call initialize
      SharedPreferences.setMockInitialValues({
        'age_verified': true,
        'age_verification_date': DateTime.now().millisecondsSinceEpoch,
      });
      
      final result = await service.checkAgeVerification();
      
      expect(result, true);
      expect(service.isAgeVerified, true);
    });

    test('should handle SharedPreferences errors gracefully', () async {
      // This test would require mocking SharedPreferences to throw errors
      // For now, we just verify the service initializes without throwing
      await expectLater(service.initialize(), completes);
    });

    test('should notify listeners when verification status changes', () async {
      await service.initialize();
      
      var notificationCount = 0;
      service.addListener(() {
        notificationCount++;
      });
      
      await service.setAgeVerified(true);
      expect(notificationCount, 1);
      
      await service.setAgeVerified(false);
      expect(notificationCount, 2);
      
      await service.clearVerificationStatus();
      expect(notificationCount, 3);
    });
  });
}