class Command {
  final int id;
  final String action;
  final String time;
  String? note;

  Command({
    required this.id,
    required this.action,
    required this.time,
    this.note,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'action': action,
    'time': time,
    'note': note,
  };

  factory Command.fromJson(Map<String, dynamic> json) => Command(
    id: json['id'],
    action: json['action'],
    time: json['time'],
    note: json['note'],
  );
}
