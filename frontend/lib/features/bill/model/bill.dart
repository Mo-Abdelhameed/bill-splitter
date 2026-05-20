import 'assignment.dart';
import 'item.dart';
import 'person.dart';

enum BillStep { people, upload, items, assign, totals }

class Bill {
  Bill({
    this.people = const [],
    this.items = const [],
    this.taxAmount,
    this.serviceAmount,
    this.assignments = const {},
    this.step = BillStep.people,
  });

  final List<Person> people;
  final List<Item> items;
  final num? taxAmount;
  final num? serviceAmount;
  final Map<String, Assignment> assignments;
  final BillStep step;

  bool get peopleLocked => step.index >= BillStep.assign.index;
  bool get itemsEditable => step == BillStep.items;

  Bill copyWith({
    List<Person>? people,
    List<Item>? items,
    Object? taxAmount = _unset,
    Object? serviceAmount = _unset,
    Map<String, Assignment>? assignments,
    BillStep? step,
  }) {
    return Bill(
      people: people ?? this.people,
      items: items ?? this.items,
      taxAmount: identical(taxAmount, _unset) ? this.taxAmount : taxAmount as num?,
      serviceAmount:
          identical(serviceAmount, _unset) ? this.serviceAmount : serviceAmount as num?,
      assignments: assignments ?? this.assignments,
      step: step ?? this.step,
    );
  }
}

const Object _unset = Object();
