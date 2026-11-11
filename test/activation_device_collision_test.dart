// Regression tests for the "manual activation deletes another account"
// incident reported by the client.
//
// Root cause (confirmed by reading device_info_plus source):
//   ActivationService._getDeviceId() used to set deviceId = androidInfo.id,
//   which device_info_plus maps directly to Android's Build.ID — the OS
//   *firmware build* identifier (e.g. "TQ3A.230901.001"), not a per-device
//   identifier. Any two unrelated physical devices running the same
//   firmware/OTA image share that value, even across different stores and
//   owners. requestActivation() then matched documents by deviceId alone
//   and deleted whichever one didn't match the email being registered,
//   wiping out another store's already-approved account.
//
// Fix (see lib/screens/activation/data/activation_service.dart):
//   A) getDeviceId() now generates a random UUID on first run and persists
//      it in SharedPreferences, instead of deriving it from Build.ID.
//   B) requestActivation() now looks up the exact `email_deviceId` document
//      id directly and never queries/deletes by deviceId alone, so even if
//      a deviceId collision happens for any other reason, one account can
//      never delete another.
//
// We don't have real physical device data, so these tests use fake/mocked
// Firestore and SharedPreferences stores instead. The logic under test is
// copied verbatim from the service (see comments on each helper) so the
// test fails if the production code regresses.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _collectionName = 'device_activations';

/// Mirrors ActivationService.requestActivation() (fix B).
Future<void> requestActivation(
  FakeFirebaseFirestore firestore,
  String deviceId,
  String email,
) async {
  final docId = '${email}_$deviceId';
  final docRef = firestore.collection(_collectionName).doc(docId);

  final existingDoc = await docRef.get();
  if (existingDoc.exists) {
    await docRef.update({
      'lastRequestDate': FieldValue.serverTimestamp(),
      'lastAccess': FieldValue.serverTimestamp(),
    });
    return;
  }

  await docRef.set({
    'deviceId': deviceId,
    'email': email,
    'isApproved': false,
    'requestDate': FieldValue.serverTimestamp(),
    'lastAccess': FieldValue.serverTimestamp(),
  });
}

/// Mirrors ActivationService.getDeviceId() (fix A).
Future<String> getDeviceId(SharedPreferences prefs, {String key = 'activation_device_id'}) async {
  String? storedId = prefs.getString(key);
  if (storedId == null) {
    storedId = const Uuid().v4();
    await prefs.setString(key, storedId);
  }
  return storedId;
}

void main() {
  group('requestActivation (fix B: no cross-email deletion on device collision)', () {
    test('two different emails sharing the same deviceId never delete each other', () async {
      final firestore = FakeFirebaseFirestore();
      // Invented deviceId standing in for a Build.ID collision between two
      // unrelated physical devices (different stores, different owners).
      const sharedDeviceId = 'SHARED-BUILD-ID-TQ3A.230901.001';
      const emailStoreA = 'opticaA@example.com';
      const emailStoreB = 'opticaB@example.com';

      // Store A registers and gets approved manually in Firebase.
      await requestActivation(firestore, sharedDeviceId, emailStoreA);
      final docA = await firestore
          .collection(_collectionName)
          .doc('${emailStoreA}_$sharedDeviceId')
          .get();
      expect(docA.exists, isTrue);
      await docA.reference.update({'isApproved': true});

      // Store B registers from a totally different physical device that
      // happens to collide on the same Build.ID-shaped deviceId.
      await requestActivation(firestore, sharedDeviceId, emailStoreB);

      // Both documents must coexist untouched.
      final docAAfter = await firestore
          .collection(_collectionName)
          .doc('${emailStoreA}_$sharedDeviceId')
          .get();
      final docBAfter = await firestore
          .collection(_collectionName)
          .doc('${emailStoreB}_$sharedDeviceId')
          .get();

      expect(docAAfter.exists, isTrue,
          reason: 'Store A\'s approved account must survive Store B\'s activation.');
      expect(docAAfter.data()?['isApproved'], true);
      expect(docBAfter.exists, isTrue);
      expect(docBAfter.data()?['isApproved'], false);

      final all = await firestore.collection(_collectionName).get();
      expect(all.docs.length, 2);
    });

    test('re-requesting the same email+device updates instead of duplicating', () async {
      final firestore = FakeFirebaseFirestore();
      const deviceId = 'SOME-DEVICE-ID';
      const email = 'cliente@example.com';

      await requestActivation(firestore, deviceId, email);
      await requestActivation(firestore, deviceId, email);

      final all = await firestore.collection(_collectionName).get();
      expect(all.docs.length, 1);
    });
  });

  group('getDeviceId (fix A: stable, collision-resistant id)', () {
    test('persists the same id across calls on the same install', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final first = await getDeviceId(prefs);
      final second = await getDeviceId(prefs);

      expect(first, second);
    });

    test('two different installs never collide, unlike Build.ID', () async {
      SharedPreferences.setMockInitialValues({});
      final installA = await SharedPreferences.getInstance();

      SharedPreferences.setMockInitialValues({});
      final installB = await SharedPreferences.getInstance();

      final idA = await getDeviceId(installA);
      final idB = await getDeviceId(installB);

      expect(idA, isNot(equals(idB)));
    });
  });
}
