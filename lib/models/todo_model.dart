import 'package:flutter/material.dart';

class Todo {
  String id;
  String title;
  DateTime date;
  int priority;
  bool isCompleted;
  String group;
  int order;

  Todo({
    required this.id,
    required this.title,
    required this.date,
    this.priority = 2,
    this.isCompleted = false,
    this.group = 'A',
    required this.order,
  });

  // DB에 저장하기 위해 Map 형태로 변환
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'date': date.toIso8601String(), // 날짜는 문자열로 저장
      'priority': priority,
      'isCompleted': isCompleted ? 1 : 0, // DB에는 0, 1로 저장
      'groupName': group, // 'group'은 SQL 예약어일 수 있어 groupName으로 변경
      'orderNum': order,
    };
  }

  // DB에서 가져온 데이터를 다시 객체로 변환
  factory Todo.fromMap(Map<String, dynamic> map) {
    return Todo(
      id: map['id'],
      title: map['title'],
      date: DateTime.parse(map['date']),
      priority: map['priority'],
      isCompleted: map['isCompleted'] == 1,
      group: map['groupName'],
      order: map['orderNum'],
    );
  }

  Color get priorityColor {
    switch (priority) {
      case 1: return Colors.redAccent;
      case 2: return Colors.orangeAccent;
      case 3: return Colors.blueAccent;
      default: return Colors.grey;
    }
  }
}