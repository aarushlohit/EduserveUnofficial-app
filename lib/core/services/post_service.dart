import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eduserveapp/core/constants/app_config.dart';

class PostService {
  PostService._();

  static final PostService instance = PostService._();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _postsCol =>
      _firestore.collection(AppConfig.postsCollection);

  Future<void> createPost({
    required String title,
    required String description,
    required String createdBy,
    String? imageUrl,
    String? link,
    bool isDraft = false,
  }) async {
    await _postsCol.add(<String, dynamic>{
      'title': title,
      'description': description,
      'imageUrl': imageUrl ?? '',
      'link': link ?? '',
      'isDraft': isDraft,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': createdBy,
    });

    await _enforceMaxPosts();
  }

  Future<void> updatePost({
    required String docId,
    required String title,
    required String description,
    String? imageUrl,
    String? link,
    bool? isDraft,
  }) async {
    await _postsCol.doc(docId).update(<String, dynamic>{
      'title': title,
      'description': description,
      'imageUrl': imageUrl ?? '',
      'link': link ?? '',
      if (isDraft != null) 'isDraft': isDraft,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (isDraft == false) {
      await _enforceMaxPosts();
    }
  }

  Future<void> deletePost(String docId) async {
    await _postsCol.doc(docId).delete();
  }

  Future<List<Map<String, dynamic>>> fetchLatestPosts({int limit = 20}) async {
    final snap = await _postsCol
        .orderBy('createdAt', descending: true)
        .where('isDraft', isEqualTo: false)
        .limit(limit)
        .get();
    return snap.docs.map((d) => d.data()).toList(growable: false);
  }

  Future<void> _enforceMaxPosts() async {
    const maxPosts = 7;
    final snap = await _postsCol
      .orderBy('createdAt', descending: false)
      .where('isDraft', isEqualTo: false)
      .limit(20)
      .get();

    if (snap.docs.length <= maxPosts) {
      return;
    }

    final toDelete = snap.docs.take(snap.docs.length - maxPosts);
    final batch = _firestore.batch();
    for (final doc in toDelete) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
