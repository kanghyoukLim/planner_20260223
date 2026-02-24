import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:planner_20260223/models/todo_model.dart';
import 'package:planner_20260223/db_helper.dart';

void main() => runApp(const MaterialApp(
  home: PlannerApp(),
  debugShowCheckedModeBanner: false,
));

class PlannerApp extends StatefulWidget {
  const PlannerApp({super.key});

  @override
  _PlannerAppState createState() => _PlannerAppState();
}

class _PlannerAppState extends State<PlannerApp> {
  final DBHelper _dbHelper = DBHelper();
  List<Todo> myTasks = [];
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  Map<String, int> _monthlyScores = {};

  @override
  void initState() {
    super.initState();
    _refreshTasks();
  }

  // 월간 점수 로드
  void _loadMonthlyScores() async {
    final scores = await _dbHelper.getMonthlyScores(_focusedDay);
    setState(() {
      _monthlyScores = scores;
    });
  }

  // 데이터 새로고침
  void _refreshTasks() async {
    final data = await _dbHelper.getTodosByDate(_selectedDate);
    setState(() {
      myTasks = data;
    });
    _loadMonthlyScores();
  }

  // 점수 계산 (A그룹 기준)
  int _calculateScore(List<Todo> tasks) {
    final aGroupTasks = tasks.where((t) => t.group == 'A').toList();
    if (aGroupTasks.isEmpty) return 0;
    final completedCount = aGroupTasks.where((t) => t.isCompleted).length;
    return ((completedCount / aGroupTasks.length) * 100).toInt();
  }

  // [로직] 순서 교체 (위치 고정, 변수만 변경)
  void _incrementOrder(Todo task) async {
    List<Todo> groupItems = myTasks.where((t) => t.group == task.group).toList();
    int currentOrder = task.order;
    int maxOrder = groupItems.length;

    if (currentOrder <= 1) {
      for (var t in groupItems) {
        t.order = (t.id == task.id) ? maxOrder : t.order - 1;
        await _dbHelper.updateTodo(t);
      }
    } else {
      try {
        var prevTask = groupItems.firstWhere((t) => t.order == currentOrder - 1);
        int temp = task.order;
        task.order = prevTask.order;
        prevTask.order = temp;
        await _dbHelper.updateTodo(task);
        await _dbHelper.updateTodo(prevTask);
      } catch (e) {
        debugPrint("교환 대상 없음");
      }
    }
    _refreshTasks();
  }

  // [로직] 그룹 변경 (연쇄 정렬 포함)
  void _toggleGroup(Todo task) async {
    String oldGroup = task.group;
    String targetGroup = (oldGroup == 'A') ? 'B' : 'A';
    task.group = targetGroup;

    List<Todo> oldGroupItems = myTasks.where((t) => t.group == oldGroup && t.id != task.id).toList();
    oldGroupItems.sort((a, b) => a.order.compareTo(b.order));
    for (int i = 0; i < oldGroupItems.length; i++) {
      oldGroupItems[i].order = i + 1;
      await _dbHelper.updateTodo(oldGroupItems[i]);
    }

    List<Todo> targetGroupItems = myTasks.where((t) => t.group == targetGroup && t.id != task.id).toList();
    task.order = targetGroupItems.length + 1;
    await _dbHelper.updateTodo(task);

    _refreshTasks();
  }

  void _deleteTask(Todo task) async {
    await _dbHelper.deleteTodo(task.id);
    _refreshTasks();
  }

  void _showAddDialog() {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('새 일정 등록'),
        content: TextField(controller: titleController, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isEmpty) return;
              int nextOrder = myTasks.where((t) => t.group == 'A').length + 1;
              await _dbHelper.insertTodo(Todo(
                id: DateTime.now().toString(),
                title: titleController.text,
                date: _selectedDate,
                group: 'A',
                order: nextOrder,
              ));
              if (!mounted) return;
              _refreshTasks();
              Navigator.pop(ctx);
            },
            child: const Text('등록'),
          ),
        ],
      ),
    );
  }

  // 날짜 선택 팝업창 띄우기 함수
  Future<void> _selectDatePopup(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate, // 현재 선택된 날짜가 기본값
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      // 한국어 설정을 원하시면 아래와 같이 구성할 수 있습니다.
      helpText: '날짜 선택',
      cancelText: '취소',
      confirmText: '확인',
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _focusedDay = picked; // TableCalendar가 해당 날짜의 주로 이동하도록 설정
      });
      _refreshTasks(); // 리스트 및 점수 갱신
    }
  }


  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.indigo),
            SizedBox(width: 10),
            Text('사용 가이드', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _helpRow(Icons.touch_app, '날짜 클릭', '상단 날짜를 눌러 먼 날짜로 이동하세요.'),
            _helpRow(Icons.star, '중요도 A/B', 'A그룹만 오늘의 점수에 반영됩니다.'),
            _helpRow(Icons.swap_vert, '순위 변경', '숫자를 눌러 목록 순서를 바꿉니다.'),
            _helpRow(Icons.check_circle, '성취도 점수', 'A를 완료하면 달력에 점수가 표시됩니다.'),
            const SizedBox(height: 15),
            const Text('💡 팁: 일정을 왼쪽으로 밀면 삭제됩니다.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('확인', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  // 도움말 항목 한 줄을 만드는 보조 위젯
  Widget _helpRow(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.indigo),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(desc, style: const TextStyle(fontSize: 13, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // [수정] 날짜 텍스트를 클릭 가능하도록 GestureDetector로 감싸기
            GestureDetector(
              onTap: () => _selectDatePopup(context),
              child: Row(
                children: [
                  Text("${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}"),
                  const Icon(Icons.arrow_drop_down, size: 24), // 클릭 가능하다는 화살표 표시
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
              child: Text(
                "${_calculateScore(myTasks)}점",
                style: const TextStyle(fontSize: 22, color: Colors.yellowAccent, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white),
            onPressed: _showHelpDialog,
          ),
        ],
        backgroundColor: Colors.indigo,
      ),



      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime(2020),
            lastDay: DateTime(2030),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
            calendarFormat: CalendarFormat.week, // 주간 모드
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDate = selectedDay;
                _focusedDay = focusedDay;
              });
              _refreshTasks();
            },

            calendarStyle: CalendarStyle(
              // 1. 셀 내부의 텍스트 위치를 위로 올리기 위해 패딩 조정
              cellPadding: const EdgeInsets.only(bottom: 15), // 아래쪽 여백을 주어 텍스트를 위로 밈
              // 1. 선택된 날짜 스타일 (둥근 사각형)
              selectedDecoration: BoxDecoration(
                color: Colors.indigo, // 강조 색상
                shape: BoxShape.rectangle, // 원에서 사각형으로 변경
                borderRadius: BorderRadius.circular(8.0), // 테두리를 둥글게 (숫자를 키울수록 더 둥글어짐)
              ),

              // 2. 오늘 날짜 스타일 (테두리만 있는 둥근 사각형 혹은 연한 색상)
              todayDecoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.3),
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(8.0),
              ),

              // 3. 날짜 텍스트 스타일 조절
              selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              todayTextStyle: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold),

              // 4. 간격 조정 (사각형이 점수를 포함할 만큼 넉넉하게 보이기 위함)
              cellMargin: const EdgeInsets.all(3.0),
            ),

            calendarBuilders: CalendarBuilders(
              // bottomEventsBuilder 대신 markerBuilder 사용
              markerBuilder: (context, day, events) {
                String dateKey = "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
                int? score = _monthlyScores[dateKey];

                if (score != null && score > 0) {
                  return Positioned(
                    bottom: 8,
                    child: Text(
                      '$score',
                      style: const TextStyle(fontSize: 12, color: Colors.yellow, fontWeight: FontWeight.bold),
                    ),
                  );
                }
                return null;
              },
            ),
            headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
          ),
          _buildHeader(),
          Expanded(
            child: ListView.builder(
              itemCount: myTasks.length,
              itemBuilder: (context, index) {
                final task = myTasks[index];
                return Dismissible(
                  key: Key(task.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) => _deleteTask(task),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildBox(
                            text: task.group,
                            color: task.group == 'A' ? Colors.indigo : Colors.grey,
                            onTap: () => _toggleGroup(task)
                        ),
                        const SizedBox(width: 8),
                        _buildBox(
                            text: '${task.order}',
                            color: Colors.white,
                            textColor: Colors.black,
                            hasBorder: true,
                            onTap: () => _incrementOrder(task)
                        ),
                      ],
                    ),
                    title: Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 18,
                          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                          color: task.isCompleted ? Colors.grey : Colors.black,
                        )
                    ),
                    trailing: SizedBox(
                      width: 50,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Transform.scale(
                          scale: 1.3,
                          child: Checkbox(
                            value: task.isCompleted,
                            onChanged: (val) async {
                              task.isCompleted = val!;
                              await _dbHelper.updateTodo(task);
                              _refreshTasks();
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
      color: Colors.grey[100],
      child: const Row(
        children: [
          SizedBox(width: 40, child: Center(child: Text('중요도', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)))),
          SizedBox(width: 8),
          SizedBox(width: 40, child: Center(child: Text('순위', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)))),
          SizedBox(width: 32),
          Expanded(child: Text('할 일', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
          SizedBox(width: 50, child: Center(child: Text('체크', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)))),
        ],
      ),
    );
  }

  Widget _buildBox({required String text, required Color color, Color textColor = Colors.white, bool hasBorder = false, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: hasBorder ? Border.all(color: Colors.black26) : null
        ),
        child: Text(text, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
    );
  }
}
