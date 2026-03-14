import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eduserveapp/core/constants/app_config.dart';

class UpdateConfigService {
  UpdateConfigService._();

  static final UpdateConfigService instance = UpdateConfigService._();

  final CollectionReference<Map<String, dynamic>> _collection =
      FirebaseFirestore.instance.collection(AppConfig.updateCollection);

  Future<String?> getLatestVersion() async {
    final snapshot = await _collection.doc(AppConfig.updateDocument).get();
    return snapshot.data()?[AppConfig.updateVersionField] as String?;
  }

  Future<void> ensureDefaultConfig({required String currentVersion}) async {
    final docRef = _collection.doc(AppConfig.updateDocument);
    final snapshot = await docRef.get();

    if (snapshot.exists) {
      return;
    }

    await docRef.set(<String, dynamic>{
      AppConfig.updateVersionField: currentVersion,
      AppConfig.updateMinSupportedField: currentVersion,
      AppConfig.updateUpdatedAtField: FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateLatestVersion({
    required String latestVersion,
    String? minSupportedVersion,
  }) async {
    await _collection.doc(AppConfig.updateDocument).set(
      <String, dynamic>{
        AppConfig.updateVersionField: latestVersion,
        AppConfig.updateMinSupportedField: minSupportedVersion ?? latestVersion,
        AppConfig.updateUpdatedAtField: FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
