class StudyPlanModel {
  final String id;
  final String title;
  final DateTime? examDate;
  final int dailyMinutes;
  final String timezone;
  final Map<String, dynamic>? preferences;
  final String status; // ACTIVE, COMPLETED, ARCHIVED
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<StudyTaskModel> tasks;

  const StudyPlanModel({
    required this.id,
    required this.title,
    this.examDate,
    required this.dailyMinutes,
    this.timezone = 'Asia/Kolkata',
    this.preferences,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.tasks = const [],
  });

  int get completedTaskCount => tasks.where((t) => t.isCompleted).length;
  int get skippedTaskCount => tasks.where((t) => t.isSkipped).length;
  int get pendingTaskCount =>
      tasks.where((t) => !t.isCompleted && !t.isSkipped).length;

  double get completionProgress =>
      tasks.isEmpty ? 0.0 : completedTaskCount / tasks.length;

  bool get isCompleted =>
      status.toUpperCase() == 'COMPLETED' ||
      (tasks.isNotEmpty && completedTaskCount == tasks.length);

  /// Group tasks chronologically by scheduled date (date-only keys)
  Map<DateTime, List<StudyTaskModel>> get tasksGroupedByDate {
    final map = <DateTime, List<StudyTaskModel>>{};
    // Sort tasks by scheduled date then orderIndex
    final sorted = List<StudyTaskModel>.from(tasks)
      ..sort((a, b) {
        final dateComp = a.scheduledDate.compareTo(b.scheduledDate);
        if (dateComp != 0) return dateComp;
        return a.orderIndex.compareTo(b.orderIndex);
      });

    for (final task in sorted) {
      final dateKey = DateTime(
        task.scheduledDate.year,
        task.scheduledDate.month,
        task.scheduledDate.day,
      );
      map.putIfAbsent(dateKey, () => []).add(task);
    }
    return map;
  }

  StudyPlanModel copyWith({
    String? id,
    String? title,
    DateTime? examDate,
    int? dailyMinutes,
    String? timezone,
    Map<String, dynamic>? preferences,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<StudyTaskModel>? tasks,
  }) {
    return StudyPlanModel(
      id: id ?? this.id,
      title: title ?? this.title,
      examDate: examDate ?? this.examDate,
      dailyMinutes: dailyMinutes ?? this.dailyMinutes,
      timezone: timezone ?? this.timezone,
      preferences: preferences ?? this.preferences,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tasks: tasks ?? this.tasks,
    );
  }

  factory StudyPlanModel.fromJson(Map<String, dynamic> json) {
    final tasksRaw = json['tasks'];
    final taskList = <StudyTaskModel>[];
    if (tasksRaw is List) {
      for (final t in tasksRaw) {
        if (t is Map<String, dynamic>) {
          taskList.add(StudyTaskModel.fromJson(t));
        }
      }
    }

    DateTime? parsedExamDate;
    if (json['examDate'] != null) {
      parsedExamDate = StudyTaskModel.parseDateSafe(json['examDate']);
    }

    return StudyPlanModel(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? 'Study Plan',
      examDate: parsedExamDate,
      dailyMinutes: (json['dailyMinutes'] as int?) ?? 60,
      timezone: (json['timezone'] as String?) ?? 'Asia/Kolkata',
      preferences: json['preferences'] as Map<String, dynamic>?,
      status: (json['status'] as String?) ?? 'ACTIVE',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
      tasks: taskList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      if (examDate != null) 'examDate': examDate!.toIso8601String(),
      'dailyMinutes': dailyMinutes,
      'timezone': timezone,
      if (preferences != null) 'preferences': preferences,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      'tasks': tasks.map((t) => t.toJson()).toList(),
    };
  }
}

class StudyTaskModel {
  final String id;
  final String planId;
  final String title;
  final String? description;
  final String? topic;
  final DateTime scheduledDate;
  final int durationMinutes;
  final String status; // TODO, IN_PROGRESS, COMPLETED, SKIPPED
  final int orderIndex;
  final DateTime? completedAt;

  const StudyTaskModel({
    required this.id,
    required this.planId,
    required this.title,
    this.description,
    this.topic,
    required this.scheduledDate,
    required this.durationMinutes,
    required this.status,
    this.orderIndex = 0,
    this.completedAt,
  });

  bool get isCompleted => status.toUpperCase() == 'COMPLETED';
  bool get isSkipped => status.toUpperCase() == 'SKIPPED';
  bool get isInProgress => status.toUpperCase() == 'IN_PROGRESS';
  bool get isTodo => status.toUpperCase() == 'TODO';

  String get statusLabel {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return 'Completed';
      case 'SKIPPED':
        return 'Skipped';
      case 'IN_PROGRESS':
        return 'In Progress';
      case 'TODO':
      default:
        return 'To Do';
    }
  }

  /// Timezone-safe date parser that avoids day-shifting across timezones
  static DateTime parseDateSafe(dynamic raw) {
    if (raw == null) return DateTime.now();
    if (raw is DateTime) return DateTime(raw.year, raw.month, raw.day);
    final str = raw.toString().trim();
    try {
      final datePart = str.split('T').first;
      final parts = datePart.split('-');
      if (parts.length == 3) {
        final year = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final day = int.tryParse(parts[2]);
        if (year != null && month != null && day != null) {
          return DateTime(year, month, day);
        }
      }
      final parsed = DateTime.parse(str);
      return DateTime(parsed.year, parsed.month, parsed.day);
    } catch (_) {
      return DateTime.now();
    }
  }

  StudyTaskModel copyWith({
    String? id,
    String? planId,
    String? title,
    String? description,
    String? topic,
    DateTime? scheduledDate,
    int? durationMinutes,
    String? status,
    int? orderIndex,
    DateTime? completedAt,
  }) {
    return StudyTaskModel(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      title: title ?? this.title,
      description: description ?? this.description,
      topic: topic ?? this.topic,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      status: status ?? this.status,
      orderIndex: orderIndex ?? this.orderIndex,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  factory StudyTaskModel.fromJson(Map<String, dynamic> json) {
    return StudyTaskModel(
      id: json['id'] as String,
      planId: (json['planId'] ?? '') as String,
      title: (json['title'] as String?) ?? 'Study Task',
      description: json['description'] as String?,
      topic: json['topic'] as String?,
      scheduledDate: parseDateSafe(json['scheduledDate']),
      durationMinutes: (json['durationMinutes'] as int?) ?? 30,
      status: (json['status'] as String?) ?? 'TODO',
      orderIndex: (json['orderIndex'] as int?) ?? 0,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'planId': planId,
      'title': title,
      if (description != null) 'description': description,
      if (topic != null) 'topic': topic,
      'scheduledDate':
          '${scheduledDate.year.toString().padLeft(4, '0')}-${scheduledDate.month.toString().padLeft(2, '0')}-${scheduledDate.day.toString().padLeft(2, '0')}',
      'durationMinutes': durationMinutes,
      'status': status,
      'orderIndex': orderIndex,
      if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
    };
  }
}
