import 'package:uuid/uuid.dart';

enum ItemSource { extracted, manual }

class Item {
  Item({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.source,
  })  : assert(quantity >= 1, 'quantity must be >= 1'),
        assert(unitPrice >= 0, 'unitPrice must be >= 0');

  factory Item.create({
    required String name,
    required int quantity,
    required num unitPrice,
    ItemSource source = ItemSource.manual,
  }) {
    return Item(
      id: const Uuid().v4(),
      name: name,
      quantity: quantity,
      unitPrice: unitPrice,
      source: source,
    );
  }

  final String id;
  final String name;
  final int quantity;
  final num unitPrice;
  final ItemSource source;

  num get lineTotal => quantity * unitPrice;

  Item copyWith({String? name, int? quantity, num? unitPrice}) {
    return Item(
      id: id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      source: source,
    );
  }

  @override
  bool operator ==(Object other) => other is Item && other.id == id;
  @override
  int get hashCode => id.hashCode;
}
