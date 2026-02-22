import 'package:flutter/material.dart';
// 프로젝트명/파일명 순서입니다.
import 'package:planner_20260223/models/todo_model.dart';

void main() => runApp(MaterialApp(
  home: PlannerApp(),
  debugShowCheckedModeBanner: false,
));

class PlannerApp extends StatefulWidget {
  @override
  _PlannerAppState createState() => _PlannerAppState();
}

class _PlannerAppState extends State<PlannerApp> {
  List<Todo> myTasks = [];

  // [로직 1] 그룹 내 순번을 1, 2, 3... 빈틈없이 재정렬하는 함수
  void _reorderGroup(String groupName) {
    List<Todo> groupItems = myTasks.where((t) => t.group == groupName).toList();
    groupItems.sort((a, b) => a.order.compareTo(b.order));
    for (int i = 0; i < groupItems.length; i++) {
      groupItems[i].order = i + 1;
    }
  }

  // [수정된 로직] 클릭 시 위치는 고정하고 '숫자'만 순환 교환
  // [로직 수정] 클릭 시 숫자를 하나 낮춤 (순위 상승). 1번에서 클릭하면 최하위로.
  void _incrementOrder(Todo task) {
    setState(() {
      int currentOrder = task.order;
      int maxOrderInGroup = myTasks.where((t) => t.group == task.group).length;

      if (currentOrder <= 1) {
        // 현재 1번인데 클릭했다면 -> 가장 마지막 번호로 이동
        // 그리고 2번부터 마지막 번호였던 일정들은 모두 한 칸씩 위로(-1) 당겨짐
        for (var t in myTasks.where((t) => t.group == task.group)) {
          if (t == task) {
            t.order = maxOrderInGroup;
          } else {
            t.order--;
          }
        }
      } else {
        // 현재 번호보다 하나 앞선 번호(currentOrder - 1)를 가진 할 일을 찾아서 서로 교환
        var prevTask = myTasks.firstWhere(
                (t) => t.group == task.group && t.order == currentOrder - 1
        );
        prevTask.order = currentOrder; // 상대방은 내 번호로 내려감
        task.order = currentOrder - 1; // 나는 앞 번호로 올라감
      }
    });
  }

  // [로직 3] A/B 그룹 토글
  void _toggleGroup(Todo task) {
    setState(() {
      String oldGroup = task.group;
      task.group = (oldGroup == 'A') ? 'B' : 'A';

      // 새 그룹의 맨 마지막 순번 부여
      int newMaxOrder = myTasks.where((t) => t.group == task.group).length;
      task.order = newMaxOrder + 1;

      _reorderGroup(oldGroup);
      _reorderGroup(task.group);
    });
  }

  // [로직 4] 신규 일정 추가 다이얼로그 (자동 번호 부여 포함)
  void _showAddDialog() {
    final titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('새 일정 등록'),
        content: TextField(
          controller: titleController,
          decoration: InputDecoration(labelText: '할 일을 입력하세요'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('취소')),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isEmpty) return;

              setState(() {
                // A그룹의 현재 할 일 개수를 파악하여 다음 번호(order) 자동 부여
                int nextOrder = myTasks.where((t) => t.group == 'A').length + 1;

                myTasks.add(Todo(
                  id: DateTime.now().toString(),
                  title: titleController.text,
                  group: 'A', // 기본 그룹 A
                  order: nextOrder, // 자동 번호 부여
                  date: DateTime.now(),
                ));
              });
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
        title: Text('SIMPLOCK 스마트 플래너'),
        backgroundColor: Colors.indigo,
      ),
      body: Column(
        children: [
          // --- [헤더 영역 추가] ---
          Container(
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
          ),
          Divider(height: 1), // 헤더와 리스트 구분선

          // --- [리스트 영역] ---
          Expanded(
            child: ListView.builder(
              itemCount: myTasks.length,
              itemBuilder: (context, index) {
                final task = myTasks[index];
                return Container(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 중요도 (A/B)
                        _buildBox(
                          text: task.group,
                          color: task.group == 'A' ? Colors.indigo : Colors.blueGrey,
                          onTap: () => _toggleGroup(task),
                        ),
                        SizedBox(width: 5),
                        // 순위 (1, 2, 3...)
                        _buildBox(
                          text: '${task.order}',
                          color: Colors.white,
                          textColor: Colors.black,
                          hasBorder: true,
                          onTap: () => _incrementOrder(task),
                        ),
                      ],
                    ),
                    title: Text(
                      task.title,
                      style: TextStyle(
                        // fontWeight: task.order == 1 ? FontWeight.bold : FontWeight.normal, // 1등은 굵게 표시
                        decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                        color: task.isCompleted ? Colors.grey : Colors.black,
                      ),
                    ),
                    trailing: Checkbox(
                      value: task.isCompleted,
                      onChanged: (val) => setState(() => task.isCompleted = val!),
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
        child: Icon(Icons.add),
        backgroundColor: Colors.indigo,
      ),
    );
  }

  Widget _buildBox({required String text, required Color color, Color textColor = Colors.white, bool hasBorder = false, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38, height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
          border: hasBorder ? Border.all(color: Colors.black26) : null,
        ),
        child: Text(text, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}