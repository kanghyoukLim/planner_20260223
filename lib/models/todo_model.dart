import 'package:flutter/material.dart';

class Todo {
  String id;
  String title;
  DateTime date; // 이 부분이 추가되어야 합니다!
  int priority;
  bool isCompleted;
  String group;
  int order;

  Todo({
    required this.id,
    required this.title,
    required this.date, // 생성자에도 추가
    this.priority = 2,
    this.isCompleted = false,
    this.group = 'A',
    required this.order,
  });

  Color get priorityColor {
    switch (priority) {
      case 1: return Colors.redAccent;
      case 2: return Colors.orangeAccent;
      case 3: return Colors.blueAccent;
      default: return Colors.grey;
    }
  }
}