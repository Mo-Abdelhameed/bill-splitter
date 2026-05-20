/// One purchasable line on a receipt — a single unit of an item with its price.
///
/// `id` is empty on wire results (the backend doesn't supply one). It becomes
/// a UUID when ExtractionScreen commits the item to BillState. Equality is
/// intentionally name+price only, so wire-shape and committed-shape compare
/// the same in tests.
class BillItem {
  final String id;
  final String name;
  final double price;

  const BillItem({this.id = '', required this.name, required this.price});

  BillItem copyWith({String? id, String? name, double? price}) => BillItem(
        id: id ?? this.id,
        name: name ?? this.name,
        price: price ?? this.price,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BillItem && other.name == name && other.price == price;

  @override
  int get hashCode => Object.hash(name, price);

  @override
  String toString() => 'BillItem(id: $id, name: $name, price: $price)';
}
