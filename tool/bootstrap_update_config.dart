import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eduserveapp/core/constants/app_config.dart';
import 'package:eduserveapp/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await FirebaseFirestore.instance
      .collection(AppConfig.updateCollection)
      .doc(AppConfig.updateDocument)
      .set(
    <String, dynamic>{
      AppConfig.updateVersionField: '1.0.0',
      AppConfig.updateMinSupportedField: '1.0.0',
      AppConfig.updateUpdatedAtField: FieldValue.serverTimestamp(),
    },
    SetOptions(merge: true),
  );
}
