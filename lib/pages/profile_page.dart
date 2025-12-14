import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../app.dart';
import '../db/post.dart';
import '../db/comment.dart';
import '../utils/time_formatter.dart';

class ProfilePage extends StatefulWidget {
  static const routeName = '/profile';
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int? userId;
  Map<String, dynamic>? user;
  List<PostModel> posts = [];
  final _commentCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  Future<void> loadData() async {
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    userId = args != null ? args['userId'] as int? : null;
    if (userId == null) return;
    final db = App.db;
    final u = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (u.isNotEmpty) user = u.first;
    final rows = await db.query(
      'posts',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'createdAt DESC',
    );
    setState(() {
      posts = rows.map((r) => PostModel.fromMap(r)).toList();
    });
  }

  Future<List<CommentModel>> getCommentsForPost(int postId) async {
    final db = App.db;
    final rows = await db.query(
      'comments',
      where: 'postId = ?',
      whereArgs: [postId],
      orderBy: 'createdAt ASC',
    );
    return rows.map((r) => CommentModel.fromMap(r)).toList();
  }

  Future<void> addComment(int postId) async {
    if (userId == null) return;
    final content = _commentCtrl.text.trim();
    if (content.isEmpty) return;
    final db = App.db;
    await db.insert('comments', {
      'postId': postId,
      'userId': userId,
      'content': content,
      'createdAt': DateTime.now().toIso8601String(),
    });
    _commentCtrl.clear();
    await loadData();
  }

  Future<String> _saveImageLocally(File file) async {
    final dir = await getApplicationDocumentsDirectory();
    final filename =
        '${DateTime.now().millisecondsSinceEpoch}${p.extension(file.path)}';
    final newPath = p.join(dir.path, filename);
    final newFile = await file.copy(newPath);
    return newFile.path;
  }

  Future<void> _pickProfileImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;
    final savedPath = await _saveImageLocally(File(picked.path));
    final db = App.db;
    await db.update(
      'users',
      {'profilePhoto': savedPath},
      where: 'id = ?',
      whereArgs: [userId],
    );
    await loadData();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => loadData());
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayName =
        user != null ? user!['displayName'] as String : 'Profile';
    final photoPath = user?['profilePhoto'] as String?;
    return Scaffold(
      appBar: AppBar(
        title: Text(displayName),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade600, Colors.purple.shade600],
            ),
          ),
        ),
      ),
      body:
          userId == null
              ? const Center(child: Text('No user'))
              : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.blue.shade50, Colors.white],
                  ),
                ),
                child: RefreshIndicator(
                  onRefresh: loadData,
                  color: Colors.blue.shade600,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.shade200,
                                        blurRadius: 15,
                                        spreadRadius: 3,
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 60,
                                    backgroundColor: Colors.blue.shade100,
                                    backgroundImage:
                                        (photoPath != null &&
                                                photoPath.isNotEmpty)
                                            ? FileImage(File(photoPath))
                                            : null,
                                    child:
                                        (photoPath == null || photoPath.isEmpty)
                                            ? Icon(
                                              Icons.person,
                                              size: 60,
                                              color: Colors.blue.shade600,
                                            )
                                            : null,
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: _pickProfileImage,
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.blue.shade600,
                                            Colors.purple.shade600,
                                          ],
                                        ),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.2,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              user?['displayName'] ?? '',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.email_outlined,
                                    size: 16,
                                    color: Colors.blue.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    user?['email'] ?? '',
                                    style: TextStyle(
                                      color: Colors.blue.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Icon(
                            Icons.grid_on,
                            color: Colors.grey.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Your Posts (${posts.length})',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...posts.map(
                        (p) => Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.description,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  formatTimeAgo(p.createdAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                if (p.photo != null && p.photo!.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(
                                      File(p.photo!),
                                      width: double.infinity,
                                      height: 250,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                Divider(color: Colors.grey.shade200),
                                const SizedBox(height: 12),
                                FutureBuilder<List<CommentModel>>(
                                  future: getCommentsForPost(p.id!),
                                  builder: (context, snap) {
                                    final comments = snap.data ?? [];
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.comment_outlined,
                                              size: 16,
                                              color: Colors.grey.shade600,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Comments (${comments.length})',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        if (comments.isEmpty)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                            child: Text(
                                              'No comments yet',
                                              style: TextStyle(
                                                color: Colors.grey.shade500,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ...comments.map(
                                          (c) => Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Icon(
                                                  Icons.person,
                                                  size: 16,
                                                  color: Colors.grey.shade600,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    c.content,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade50,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: TextField(
                                                  controller: _commentCtrl,
                                                  decoration: InputDecoration(
                                                    hintText:
                                                        'Write a comment...',
                                                    hintStyle: TextStyle(
                                                      color:
                                                          Colors.grey.shade400,
                                                    ),
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                      borderSide:
                                                          BorderSide.none,
                                                    ),
                                                    contentPadding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 16,
                                                          vertical: 12,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                margin: const EdgeInsets.only(
                                                  right: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      Colors.blue.shade600,
                                                      Colors.purple.shade600,
                                                    ],
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: IconButton(
                                                  icon: const Icon(
                                                    Icons.send,
                                                    color: Colors.white,
                                                    size: 20,
                                                  ),
                                                  onPressed:
                                                      () => addComment(p.id!),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
