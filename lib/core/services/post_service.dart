import 'package:cloud_firestore/cloud_firestore.dart';

class PostService {
  PostService._();

  static final PostService instance = PostService._();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _postsCol =>
      _firestore.collection('hackathons');

  Future<void> createPost({
    required String title,
    required String description,
    required String createdBy,
    String? imageUrl,
    String? link,
    bool isDraft = false,
  }) async {
    try {
      await _postsCol.add(<String, dynamic>{
        'title': title,
        'description': description,
        'imageUrl': imageUrl ?? '',
        'link': link ?? '',
        'status': isDraft ? 'draft' : 'published',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'createdBy': createdBy,
      });

      await _enforceMaxPosts();
      // ignore: avoid_print
      print('[PostService] createPost success in hackathons');
    } catch (e, st) {
      // ignore: avoid_print
      print('[PostService] createPost failed: $e');
      // ignore: avoid_print
      print(st);
      rethrow;
    }
  }

  Future<void> updatePost({
    required String docId,
    required String title,
    required String description,
    String? imageUrl,
    String? link,
    required String status,
  }) async {
    try {
      await _postsCol.doc(docId).update(<String, dynamic>{
        'title': title,
        'description': description,
        'imageUrl': imageUrl ?? '',
        'link': link ?? '',
        'status': status,
        'updatedAt': Timestamp.now(),
      });
      // ignore: avoid_print
      print('[PostService] updatePost success: $docId');
    } catch (e, st) {
      // ignore: avoid_print
      print('[PostService] updatePost failed ($docId): $e');
      // ignore: avoid_print
      print(st);
      rethrow;
    }
  }

  Future<void> deletePost(String docId) async {
    try {
      await _postsCol.doc(docId).delete();
      // ignore: avoid_print
      print('[PostService] deletePost success: $docId');
    } catch (e, st) {
      // ignore: avoid_print
      print('[PostService] deletePost failed ($docId): $e');
      // ignore: avoid_print
      print(st);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchLatestPosts({int limit = 20}) async {
    final snap = await _postsCol
        .where('status', isEqualTo: 'published')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => d.data()).toList(growable: false);
  }

  Future<void> _enforceMaxPosts() async {
    const maxPosts = 20;
    final snap = await _postsCol.orderBy('createdAt', descending: false).get();

    if (snap.docs.length <= maxPosts) {
      return;
    }

    for (var i = 0; i < snap.docs.length - maxPosts; i++) {
      await snap.docs[i].reference.delete();
    }
  }
}
