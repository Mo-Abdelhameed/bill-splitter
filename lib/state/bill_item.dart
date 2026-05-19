/// One purchasable line on a receipt — a single unit of an item with its price.
///
/// Quantity is intentionally not modelled here: per STORY-002 AC-3, the
/// extraction step expands `pasta × 3 @ 50` into three independent `BillItem`
/// entries so each unit can be assigned to a person independently downstream.
class BillItem {
  final String name;
  final double price;

  const BillItem({required this.name, required this.price});

  BillItem copyWith({String? name, double? price}) =>
      BillItem(name: name ?? this.name, price: price ?? this.price);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BillItem && other.name == name && other.price == price;

  @override
  int get hashCode => Object.hash(name, price);

  @override
  String toString() => 'BillItem(name: $name, price: $price)';
}
