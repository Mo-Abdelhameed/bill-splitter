class PersonTotal {
  PersonTotal({
    required this.personId,
    required this.itemSubtotal,
    required this.taxShare,
    required this.serviceShare,
    required this.finalTotal,
  });

  final String personId;
  final num itemSubtotal;
  final int? taxShare;
  final int? serviceShare;
  final int finalTotal;
}
