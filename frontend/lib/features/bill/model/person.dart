import 'package:uuid/uuid.dart';

class Person {
  Person({required this.id, required this.name});

  factory Person.create(String name) =>
      Person(id: const Uuid().v4(), name: name.trim());

  final String id;
  final String name;

  Person copyWith({String? name}) => Person(id: id, name: name ?? this.name);

  @override
  bool operator ==(Object other) => other is Person && other.id == id;
  @override
  int get hashCode => id.hashCode;
}
