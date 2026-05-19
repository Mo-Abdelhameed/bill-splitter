import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:bill_split/services/gemini_extractor.dart';

void main() {
  group('ExtractionResult.fromJson (STORY-002 AC-3 parsing)', () {
    test(
        'STORY-002 AC-3: parses quantity-expanded items into separate BillItem entries',
        () {
      final json = jsonDecode('''
        {
          "items": [
            {"name": "pasta", "price": 50},
            {"name": "pasta", "price": 50},
            {"name": "pasta", "price": 50}
          ],
          "tax": 14.0,
          "service": 12.0
        }
      ''') as Map<String, dynamic>;

      final result = ExtractionResult.fromJson(json);

      expect(result.items.length, 3);
      for (final item in result.items) {
        expect(item.name, 'pasta');
        expect(item.price, 50.0);
      }
      expect(result.tax, 14.0);
      expect(result.service, 12.0);
    });

    test('STORY-002 AC-3: parses tax as null when absent from receipt', () {
      final json = jsonDecode('''
        {
          "items": [{"name": "x", "price": 10}],
          "tax": null,
          "service": 12.0
        }
      ''') as Map<String, dynamic>;

      final result = ExtractionResult.fromJson(json);
      expect(result.tax, isNull);
      expect(result.service, 12.0);
    });

    test('STORY-002 AC-3: parses service as null when absent from receipt', () {
      final json = jsonDecode('''
        {
          "items": [{"name": "x", "price": 10}],
          "tax": 14.0,
          "service": null
        }
      ''') as Map<String, dynamic>;

      final result = ExtractionResult.fromJson(json);
      expect(result.tax, 14.0);
      expect(result.service, isNull);
    });

    test('STORY-002 AC-3: throws ExtractionException(schema) on malformed JSON',
        () {
      // Missing required `items` field.
      final badJson = jsonDecode('{"tax": 1.0, "service": 2.0}')
          as Map<String, dynamic>;

      expect(
        () => ExtractionResult.fromJson(badJson),
        throwsA(isA<ExtractionException>().having(
          (e) => e.kind,
          'kind',
          ExtractionFailure.schema,
        )),
      );
    });

    test(
        'STORY-002 AC-3: items with non-numeric price fail schema validation',
        () {
      final badJson = jsonDecode('''
        {
          "items": [{"name": "x", "price": "not a number"}],
          "tax": null,
          "service": null
        }
      ''') as Map<String, dynamic>;

      expect(
        () => ExtractionResult.fromJson(badJson),
        throwsA(isA<ExtractionException>().having(
          (e) => e.kind,
          'kind',
          ExtractionFailure.schema,
        )),
      );
    });
  });
}
