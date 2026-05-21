import 'package:flutter/foundation.dart';

@immutable
class Diner {
  final String id;
  final String name;
  const Diner({required this.id, required this.name});

  Diner copyWith({String? name}) => Diner(id: id, name: name ?? this.name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Diner && other.id == id);
  @override
  int get hashCode => id.hashCode;
}

@immutable
class ReceiptItem {
  final String id;
  final String name;
  final double price;
  final int quantity;
  const ReceiptItem({
    required this.id,
    required this.name,
    required this.price,
    this.quantity = 1,
  });

  factory ReceiptItem.fromJson(String id, Map<String, dynamic> json) {
    return ReceiptItem(
      id: id,
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? json['name'] as String
          : 'Item',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    );
  }
}

@immutable
class ReceiptCharges {
  final double? tax;
  final double? service;
  const ReceiptCharges({this.tax, this.service});

  factory ReceiptCharges.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ReceiptCharges();
    return ReceiptCharges(
      tax: (json['tax'] as num?)?.toDouble(),
      service: (json['service'] as num?)?.toDouble(),
    );
  }

  ReceiptCharges copyWith({double? tax, double? service, bool clearTax = false, bool clearService = false}) {
    return ReceiptCharges(
      tax: clearTax ? null : (tax ?? this.tax),
      service: clearService ? null : (service ?? this.service),
    );
  }
}

@immutable
class ExtractedReceipt {
  final List<ReceiptItem> items;
  final ReceiptCharges charges;
  final double? subtotal;
  final double? total;
  final String? currency;

  const ExtractedReceipt({
    required this.items,
    required this.charges,
    this.subtotal,
    this.total,
    this.currency,
  });

  factory ExtractedReceipt.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List?) ?? const [];
    final items = <ReceiptItem>[];
    for (var i = 0; i < rawItems.length; i++) {
      items.add(ReceiptItem.fromJson(
        'item_$i',
        Map<String, dynamic>.from(rawItems[i] as Map),
      ));
    }
    return ExtractedReceipt(
      items: items,
      charges: ReceiptCharges.fromJson(
        json['charges'] == null
            ? null
            : Map<String, dynamic>.from(json['charges'] as Map),
      ),
      subtotal: (json['subtotal'] as num?)?.toDouble(),
      total: (json['total'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
    );
  }
}

@immutable
class DinerTotal {
  final Diner diner;
  final int subtotalCents;
  final int taxShareCents;
  final int serviceShareCents;
  final int grandTotalCents;
  const DinerTotal({
    required this.diner,
    required this.subtotalCents,
    required this.taxShareCents,
    required this.serviceShareCents,
    required this.grandTotalCents,
  });

  double get subtotal => subtotalCents / 100;
  double get taxShare => taxShareCents / 100;
  double get serviceShare => serviceShareCents / 100;
  double get grandTotal => grandTotalCents / 100;
}

@immutable
class BillTotals {
  final List<DinerTotal> perDiner;
  final int billGrandTotalCents;
  final int roundingResidualCents; // billGrandTotal - sum(perDiner.grandTotal)
  const BillTotals({
    required this.perDiner,
    required this.billGrandTotalCents,
    required this.roundingResidualCents,
  });

  double get billGrandTotal => billGrandTotalCents / 100;
  double get roundingResidual => roundingResidualCents / 100;
}
