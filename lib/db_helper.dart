import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:planner_20260223/models/todo_model.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  static Database? _database;

  DBHelper._internal();
  factory DBHelper() => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'planner_v1.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute('''
          CREATE TABLE todos(
            id TEXT PRIMARY KEY,
            title TEXT,
            date TEXT,
            priority INTEGER,
            isCompleted INTEGER,
            groupName TEXT,
            orderNum INTEGER
          )
        ''');
      },
    );
  }

  // 데이터 저장
  Future<void> insertTodo(Todo todo) async {
    final db = await database;
    await db.insert('todos', todo.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // 데이터 조회 (날짜별 & 등록 순서(id) 고정)
  Future<List<Todo>> getTodosByDate(DateTime date) async {
    final db = await database;
    String dateStr = date.toIso8601String().split('T')[0];

    final List<Map<String, dynamic>> maps = await db.query(
      'todos',
      where: "date LIKE ?",
      whereArgs: ["$dateStr%"],
      orderBy: "id ASC", // 리스트의 줄 위치를 고정하는 핵심 로직
    );

    return List.generate(maps.length, (i) => Todo.fromMap(maps[i]));
  }

  // 데이터 수정
  Future<void> updateTodo(Todo todo) async {
    final db = await database;
    await db.update('todos', todo.toMap(), where: 'id = ?', whereArgs: [todo.id]);
  }

  // 데이터 삭제
  Future<void> deleteTodo(String id) async {
    final db = await database;
    await db.delete('todos', where: 'id = ?', whereArgs: [id]);
  }
}