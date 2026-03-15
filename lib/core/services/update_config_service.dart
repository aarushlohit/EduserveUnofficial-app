import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eduserveapp/core/constants/app_config.dart';

class UpdateConfigService {
  UpdateConfigService._();

  static final UpdateConfigService instance = UpdateConfigService._();

  final CollectionReference<Map<String, dynamic>> _collection =
      FirebaseFirestore.instance.collection(AppConfig.updateCollection);

  Future<UpdateConfig?> getConfig() async {
    final snapshot = await _collection.doc(AppConfig.updateDocument).get();
    final data = snapshot.data();
    if (data == null) {
      return null;
    }

    return UpdateConfig(
      latestVersion: (data[AppConfig.updateVersionField] as String?)?.trim(),
      minSupportedVersion:
          (data[AppConfig.updateMinSupportedField] as String?)?.trim(),
      apkUrl: (data[AppConfig.updateApkUrlField] as String?)?.trim(),
    );
  }

  Future<String?> getLatestVersion() async {
    final config = await getConfig();
    return config?.latestVersion;
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
      AppConfig.updateApkUrlField: '',
      AppConfig.updateUpdatedAtField: FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateLatestVersion({
    required String latestVersion,
    String? minSupportedVersion,
    String? apkUrl,
  }) async {
    await _collection.doc(AppConfig.updateDocument).set(
      <String, dynamic>{
        AppConfig.updateVersionField: latestVersion,
        AppConfig.updateMinSupportedField:
            minSupportedVersion ?? latestVersion,
        if (apkUrl != null) AppConfig.updateApkUrlField: apkUrl,
        AppConfig.updateUpdatedAtField: FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}

class UpdateConfig {
  const UpdateConfig({
    required this.latestVersion,
    required this.minSupportedVersion,
    required this.apkUrl,
  });

  final String? latestVersion;
  final String? minSupportedVersion;
  final String? apkUrl;
}
