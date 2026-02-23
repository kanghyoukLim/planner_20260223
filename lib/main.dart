import 'package:flutter/material.dart';
// 프로젝트명/파일명 순서입니다.
import 'package:planner_20260223/models/todo_model.dart';
import 'package:planner_20260223/db_helper.dart';

void main() => runApp(MaterialApp(
  home: PlannerApp(),
  debugShowCheckedModeBanner: false,
));

class PlannerApp extends StatefulWidget {
  @override
  _PlannerAppState createState() => _PlannerAppState();
}

class _PlannerAppState extends State<PlannerApp> {
  final DBHelper _dbHelper = DBHelper();
  List<Todo> myTasks = [];
  DateTime _selectedDate = DateTime.now(); // 현재 선택된 날짜

  @override
  void initState() {
    super.initState();
    _refreshTasks(); // 앱 시작 시 DB에서 데이터 로드
  }

  void _deleteTask(Todo task) async {
    // 1. DB에서 데이터 삭제
    await _dbHelper.deleteTodo(task.id);

    // 2. 화면 갱신 (리스트에서 제거됨)
    _refreshTasks();

    // 3. 하단 알림 메시지 (선택 사항)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('일정이 삭제되었습니다.'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  // DB에서 현재 선택된 날짜의 데이터를 가져와 화면 갱신
  void _refreshTasks() async {
    // 1. DB에서 현재 날짜의 데이터를 등록순(id ASC)으로 가져옴
    final data = await _dbHelper.getTodosByDate(_selectedDate);

    // // 2. 그룹별 카운터로 번호 중복 및 누락 방지 (날짜 독립성 보장)
    // int countA = 0;
    // int countB = 0;
    //
    // for (var t in data) {
    //   if (t.group == 'A') {
    //     countA++;
    //     t.order = countA;
    //   } else {
    //     countB++;
    //     t.order = countB;
    //   }
    //   // 계산된 정확한 순번 변수를 DB에 업데이트
    //   await _dbHelper.updateTodo(t);
    // }

    setState(() {
      myTasks = data;
    });
  }

  // [로직] 클릭 시 숫자 내림 (순위 상승) 및 DB 업데이트
  void _incrementOrder(Todo task) async {
    // 1. 현재 날짜, 현재 그룹 내의 아이템들만 추출
    List<Todo> groupItems = myTasks.where((t) => t.group == task.group).toList();
    int currentOrder = task.order;
    int maxOrder = groupItems.length;

    if (currentOrder <= 1) {
      // 1번 클릭 시 해당 그룹의 마지막 순번으로 보내고 나머지는 하나씩 당김
      for (var t in groupItems) {
        if (t.id == task.id) {
          t.order = maxOrder;
        } else {
          t.order = t.order - 1;
        }
        await _dbHelper.updateTodo(t);
      }
    } else {
      // 2. 내 앞 순번(currentOrder - 1)을 가진 항목을 정확히 찾아 서로의 숫자만 교환
      try {
        var prevTask = groupItems.firstWhere((t) => t.order == currentOrder - 1);

        int temp = task.order;
        task.order = prevTask.order;
        prevTask.order = temp;

        await _dbHelper.updateTodo(task);
        await _dbHelper.updateTodo(prevTask);
      } catch (e) {
        print("교환 대상 찾기 실패: $e");
      }
    }

    // 3. 화면 갱신 (이제 _refreshTasks가 번호를 덮어쓰지 않으므로 바뀐 숫자가 보입니다)
    _refreshTasks();
  }
  //
  // // [로직] 그룹 변경 및 DB 업데이트
  // void _toggleGroup(Todo task) async {
  //   String oldGroup = task.group;
  //   task.group = (oldGroup == 'A') ? 'B' : 'A';
  //
  //   // 새 그룹의 마지막 번호 부여
  //   int newMaxOrder = myTasks.where((t) => t.group == task.group).length;
  //   task.order = newMaxOrder + 1;
  //
  //   await _dbHelper.updateTodo(task);
  //   _refreshTasks();
  // }

// [로직] 그룹 변경: 위치(ID)는 유지하고 그룹 변수와 순번만 바꿈
// [날짜 이동] 날짜 선택기 실행 및 독립성 유지
  void _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _refreshTasks(); // 날짜가 바뀌면 해당 날짜의 독립된 데이터를 불러옴
    }
  }

  // [로직] 그룹 변경: 양쪽 그룹의 순번 연쇄 업데이트 (날짜 독립성 포함)
  void _toggleGroup(Todo task) async {
    String oldGroup = task.group;
    String targetGroup = (oldGroup == 'A') ? 'B' : 'A';

    // 1. 그룹 변수 변경
    task.group = targetGroup;

    // 2. 나가는 그룹(oldGroup) 순서 재정렬 (빈자리 메우기)
    List<Todo> oldGroupItems = myTasks.where((t) => t.group == oldGroup && t.id != task.id).toList();
    for (int i = 0; i < oldGroupItems.length; i++) {
      oldGroupItems[i].order = i + 1;
      await _dbHelper.updateTodo(oldGroupItems[i]);
    }

    // 3. 들어가는 그룹(targetGroup) 순서 재정렬 (마지막에 추가)
    List<Todo> newGroupItems = myTasks.where((t) => t.group == targetGroup).toList();
    for (int i = 0; i < newGroupItems.length; i++) {
      newGroupItems[i].order = i + 1;
      await _dbHelper.updateTodo(newGroupItems[i]);
    }

    // 4. 모든 변경사항 반영 후 화면 갱신
    _refreshTasks();
  }


  // [추가] 새 일정 등록
  void _showAddDialog() {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('새 일정 등록'),
        content: TextField(controller: titleController, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('취소')),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isEmpty) return;
// [수정] 현재 선택된 날짜의 A그룹 개수만 파악
              int nextOrder = myTasks.where((t) =>
              t.group == 'A' &&
                  t.date.year == _selectedDate.year &&
                  t.date.month == _selectedDate.month &&
                  t.date.day == _selectedDate.day
              ).length + 1;

              await _dbHelper.insertTodo(Todo(
                id: DateTime.now().toString(),
                title: titleController.text,
                date: _selectedDate,
                group: 'A',
                order: nextOrder,
              ));
              _refreshTasks();
              Navigator.pop(ctx);
            },
            child: Text('등록'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => _selectDate(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day} ▼ "),
            ],
          ),
        ),
        backgroundColor: Colors.indigo,
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView.builder(
              itemCount: myTasks.length,
              itemBuilder: (context, index) {
                final task = myTasks[index];

                return Dismissible(
                  key: Key(task.id), // 각 일정의 고유 ID를 키로 사용합니다.
                  direction: DismissDirection.endToStart, // 오른쪽에서 왼쪽으로 밀 때만 작동합니다.
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: EdgeInsets.only(right: 20),
                    child: Icon(Icons.delete, color: Colors.white),
                  ),
                  // [추가] 삭제 전 확인 팝업창
                  confirmDismiss: (direction) async {
                    return await showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('삭제 확인'),
                        content: Text('이 일정을 삭제하시겠습니까?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false), // 취소
                            child: Text('취소'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true), // 삭제 확정
                            child: Text('삭제', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                  // [추가] 삭제 확정 시 실행될 로직
                  onDismissed: (direction) {
                    _deleteTask(task);
                  },
                  child: ListTile(
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildBox(
                            text: task.group,
                            color: task.group == 'A' ? Colors.indigo : Colors.grey,
                            onTap: () => _toggleGroup(task)
                        ),
                        SizedBox(width: 5),
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
                          fontWeight: FontWeight.normal,
                          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                          color: task.isCompleted ? Colors.grey : Colors.black,
                        )
                    ),
                    trailing: Checkbox(
                      value: task.isCompleted,
                      onChanged: (val) async {
                        task.isCompleted = val!;
                        await _dbHelper.updateTodo(task);
                        _refreshTasks();
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(onPressed: _showAddDialog, child: Icon(Icons.add), backgroundColor: Colors.indigo),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: Colors.grey[100],
      child: Row(
        children: [
          SizedBox(width: 38, child: Center(child: Text('중요도', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
          SizedBox(width: 5),
          SizedBox(width: 38, child: Center(child: Text('순위', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
          SizedBox(width: 15),
          Expanded(child: Text('할일', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          SizedBox(width: 40, child: Center(child: Text('체크', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
        ],
      ),
    );
  }

  Widget _buildBox({required String text, required Color color, Color textColor = Colors.white, bool hasBorder = false, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38, height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6), border: hasBorder ? Border.all(color: Colors.black26) : null),
        child: Text(text, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}