enum ChargeKind { tax, service }

class Charge {
  Charge({required this.kind, required this.amount}) : assert(amount >= 0);
  final ChargeKind kind;
  final num amount;
}
