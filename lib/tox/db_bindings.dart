import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'messages.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        db.execute('''
          CREATE TABLE messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            friend_id INTEGER,
            direction TEXT,
            content BLOB,
            timestamp TEXT
          )
        ''');
      },
    );
  }

  Future<List<Map<String, dynamic>>> fetchAllMessages(int friendId) async {
    final db = await database;
    return await db.query(
      'messages',
      where: 'friend_id = ?',
      whereArgs: [friendId],
      orderBy: 'timestamp ASC', // Fetch messages in chronological order
    );
  }

  Future<int> saveMessage(
      int friendId, String direction, String content, String timestamp) async {
    final db = await database;
    return await db.insert('messages', {
      'friend_id': friendId,
      'direction': direction,
      'content': content,
      'timestamp': timestamp,
    });
  }

  Future<List<Map<String, dynamic>>> fetchMessages(int friendId) async {
    final db = await database;
    return await db.query(
      'messages',
      where: 'friend_id = ?',
      whereArgs: [friendId],
      orderBy: 'timestamp ASC',
    );
  }
}
