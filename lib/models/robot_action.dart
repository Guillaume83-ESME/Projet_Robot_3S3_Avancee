class RobotAction {
  final int id;
  final String description;
  final String time;
  String? note;

  RobotAction({
    required this.id,
    required this.description,
    required this.time,
    this.note,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description,
    'time': time,
    'note': note,
  };

  factory RobotAction.fromJson(Map<String, dynamic> json) => RobotAction(
    id: json['id'],
    description: json['description'],
    time: json['time'],
    note: json['note'],
  );
}
