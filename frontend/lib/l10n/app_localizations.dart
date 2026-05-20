import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Bill Splitter'**
  String get appTitle;

  /// No description provided for @peopleScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Who\'s splitting?'**
  String get peopleScreenTitle;

  /// No description provided for @addPersonHint.
  ///
  /// In en, this message translates to:
  /// **'Add a name'**
  String get addPersonHint;

  /// No description provided for @addPersonButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addPersonButton;

  /// No description provided for @needAtLeastTwoPeople.
  ///
  /// In en, this message translates to:
  /// **'Add at least 2 people to continue.'**
  String get needAtLeastTwoPeople;

  /// No description provided for @nextButton.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextButton;

  /// No description provided for @backButton.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get backButton;

  /// No description provided for @uploadScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload bill'**
  String get uploadScreenTitle;

  /// No description provided for @uploadFromCamera.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get uploadFromCamera;

  /// No description provided for @uploadFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get uploadFromGallery;

  /// No description provided for @uploadOrEnterManually.
  ///
  /// In en, this message translates to:
  /// **'Enter items manually'**
  String get uploadOrEnterManually;

  /// No description provided for @itemsScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get itemsScreenTitle;

  /// No description provided for @addItemButton.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get addItemButton;

  /// No description provided for @itemNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get itemNameLabel;

  /// No description provided for @itemQuantityLabel.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get itemQuantityLabel;

  /// No description provided for @itemPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Unit price'**
  String get itemPriceLabel;

  /// No description provided for @taxLabel.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get taxLabel;

  /// No description provided for @serviceLabel.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get serviceLabel;

  /// No description provided for @assignScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Assign items'**
  String get assignScreenTitle;

  /// No description provided for @viewTotalsButton.
  ///
  /// In en, this message translates to:
  /// **'View totals'**
  String get viewTotalsButton;

  /// No description provided for @unassignedItemsBlocker.
  ///
  /// In en, this message translates to:
  /// **'Some items have no one assigned.'**
  String get unassignedItemsBlocker;

  /// No description provided for @totalsScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Per-person totals'**
  String get totalsScreenTitle;

  /// No description provided for @startNewBillButton.
  ///
  /// In en, this message translates to:
  /// **'Start new bill'**
  String get startNewBillButton;

  /// No description provided for @subtotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotalLabel;

  /// No description provided for @finalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get finalLabel;

  /// No description provided for @currencyEgp.
  ///
  /// In en, this message translates to:
  /// **'EGP'**
  String get currencyEgp;

  /// No description provided for @languageButton.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get languageButton;

  /// No description provided for @extractionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the receipt. Enter items manually.'**
  String get extractionFailed;

  /// No description provided for @extractionEmpty.
  ///
  /// In en, this message translates to:
  /// **'No items detected. Enter items manually.'**
  String get extractionEmpty;

  /// No description provided for @imageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'That image is too large. Try a smaller photo.'**
  String get imageTooLarge;

  /// No description provided for @invalidImage.
  ///
  /// In en, this message translates to:
  /// **'That doesn\'t look like a photo we can read.'**
  String get invalidImage;

  /// No description provided for @networkError.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server. Enter items manually.'**
  String get networkError;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
