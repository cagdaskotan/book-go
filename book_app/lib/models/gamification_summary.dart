class GamificationSummary {
  const GamificationSummary({
    required this.dailyPageGoal,
    required this.todayPages,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalPages,
    required this.finishedBooks,
    required this.activeDays,
    required this.xp,
    required this.level,
    required this.levelProgress,
    required this.week,
  });

  final int dailyPageGoal;
  final int todayPages;
  final int currentStreak;
  final int longestStreak;
  final int totalPages;
  final int finishedBooks;
  final int activeDays;
  final int xp;
  final int level;
  final int levelProgress;
  final List<ReadingDay> week;

  double get dailyProgress => (todayPages / dailyPageGoal).clamp(0.0, 1.0);
  double get levelProgressRatio => (levelProgress / 500).clamp(0.0, 1.0);
  int get remainingPages =>
      (dailyPageGoal - todayPages).clamp(0, dailyPageGoal);
  bool get dailyGoalMet => todayPages >= dailyPageGoal;

  factory GamificationSummary.fromJson(Map<String, dynamic> json) {
    int value(dynamic raw) {
      if (raw is num) return raw.toInt();
      return int.tryParse('$raw') ?? 0;
    }

    final rawWeek = json['week'];
    return GamificationSummary(
      dailyPageGoal: value(json['daily_page_goal']).clamp(1, 500),
      todayPages: value(json['today_pages']),
      currentStreak: value(json['current_streak']),
      longestStreak: value(json['longest_streak']),
      totalPages: value(json['total_pages']),
      finishedBooks: value(json['finished_books']),
      activeDays: value(json['active_days']),
      xp: value(json['xp']),
      level: value(json['level']).clamp(1, 9999),
      levelProgress: value(json['level_progress']),
      week: rawWeek is List
          ? rawWeek
                .whereType<Map<String, dynamic>>()
                .map(ReadingDay.fromJson)
                .toList()
          : const [],
    );
  }
}

class ReadingDay {
  const ReadingDay({
    required this.date,
    required this.pagesRead,
    required this.goalMet,
    required this.isToday,
  });

  final String date;
  final int pagesRead;
  final bool goalMet;
  final bool isToday;

  factory ReadingDay.fromJson(Map<String, dynamic> json) {
    bool boolean(dynamic raw) =>
        raw == true || raw == 1 || raw.toString().toLowerCase() == 'true';
    int integer(dynamic raw) =>
        raw is num ? raw.toInt() : int.tryParse('$raw') ?? 0;

    return ReadingDay(
      date: json['date']?.toString() ?? '',
      pagesRead: integer(json['pages_read']),
      goalMet: boolean(json['goal_met']),
      isToday: boolean(json['is_today']),
    );
  }
}
