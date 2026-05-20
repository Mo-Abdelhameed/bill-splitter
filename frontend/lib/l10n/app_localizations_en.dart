// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Bill Splitter';

  @override
  String get peopleScreenTitle => 'Who\'s splitting?';

  @override
  String get addPersonHint => 'Add a name';

  @override
  String get addPersonButton => 'Add';

  @override
  String get needAtLeastTwoPeople => 'Add at least 2 people to continue.';

  @override
  String get nextButton => 'Next';

  @override
  String get backButton => 'Back';

  @override
  String get uploadScreenTitle => 'Upload bill';

  @override
  String get uploadFromCamera => 'Take a photo';

  @override
  String get uploadFromGallery => 'Choose from gallery';

  @override
  String get uploadOrEnterManually => 'Enter items manually';

  @override
  String get itemsScreenTitle => 'Items';

  @override
  String get addItemButton => 'Add item';

  @override
  String get itemNameLabel => 'Name';

  @override
  String get itemQuantityLabel => 'Qty';

  @override
  String get itemPriceLabel => 'Unit price';

  @override
  String get taxLabel => 'Tax';

  @override
  String get serviceLabel => 'Service';

  @override
  String get assignScreenTitle => 'Assign items';

  @override
  String get viewTotalsButton => 'View totals';

  @override
  String get unassignedItemsBlocker => 'Some items have no one assigned.';

  @override
  String get totalsScreenTitle => 'Per-person totals';

  @override
  String get startNewBillButton => 'Start new bill';

  @override
  String get subtotalLabel => 'Subtotal';

  @override
  String get finalLabel => 'Total';

  @override
  String get currencyEgp => 'EGP';

  @override
  String get languageButton => 'العربية';

  @override
  String get extractionFailed =>
      'Could not read the receipt. Enter items manually.';

  @override
  String get extractionEmpty => 'No items detected. Enter items manually.';

  @override
  String get imageTooLarge => 'That image is too large. Try a smaller photo.';

  @override
  String get invalidImage => 'That doesn\'t look like a photo we can read.';

  @override
  String get networkError =>
      'Could not reach the server. Enter items manually.';
}
