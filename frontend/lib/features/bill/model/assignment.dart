class Assignment {
  Assignment({
    required this.itemId,
    required this.personIds,
    this.weights,
  })  : assert(personIds.isNotEmpty, 'personIds must be non-empty when set'),
        assert(
          weights == null ||
              (weights.keys.toSet().containsAll(personIds) &&
                  personIds.containsAll(weights.keys) &&
                  weights.values.every((w) => w > 0)),
          'weights keys must equal personIds and all values > 0',
        );

  final String itemId;
  final Set<String> personIds;
  final Map<String, num>? weights;

  bool get isEqualSplit => weights == null;

  Assignment copyWith({Set<String>? personIds, Map<String, num>? weights}) {
    return Assignment(
      itemId: itemId,
      personIds: personIds ?? this.personIds,
      weights: weights,
    );
  }
}
