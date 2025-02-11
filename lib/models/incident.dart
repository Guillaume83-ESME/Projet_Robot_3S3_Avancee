class Incident {
  final int id;
  final String description;
  final String time;
  String? note; // Ajout du champ note

  Incident({required this.id, required this.description, required this.time, this.note});

  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description,
    'time': time,
    'note': note, // Inclure note dans la sérialisation
  };

  factory Incident.fromJson(Map<String, dynamic> json) => Incident(
    id: json['id'],
    description: json['description'],
    time: json['time'],
    note: json['note'], // Inclure note dans la désérialisation
  );
}
