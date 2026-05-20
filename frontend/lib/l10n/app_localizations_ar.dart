// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'تقسيم الفاتورة';

  @override
  String get peopleScreenTitle => 'مين بيقسموا الفاتورة؟';

  @override
  String get addPersonHint => 'أضف اسم';

  @override
  String get addPersonButton => 'إضافة';

  @override
  String get needAtLeastTwoPeople => 'أضف على الأقل شخصين للمتابعة.';

  @override
  String get nextButton => 'التالي';

  @override
  String get backButton => 'رجوع';

  @override
  String get uploadScreenTitle => 'ارفع الفاتورة';

  @override
  String get uploadFromCamera => 'التقط صورة';

  @override
  String get uploadFromGallery => 'اختر من المعرض';

  @override
  String get uploadOrEnterManually => 'أدخل الأصناف يدويًا';

  @override
  String get itemsScreenTitle => 'الأصناف';

  @override
  String get addItemButton => 'أضف صنف';

  @override
  String get itemNameLabel => 'الاسم';

  @override
  String get itemQuantityLabel => 'الكمية';

  @override
  String get itemPriceLabel => 'سعر الوحدة';

  @override
  String get taxLabel => 'ضريبة';

  @override
  String get serviceLabel => 'خدمة';

  @override
  String get assignScreenTitle => 'تعيين الأصناف';

  @override
  String get viewTotalsButton => 'عرض الإجمالي';

  @override
  String get unassignedItemsBlocker => 'بعض الأصناف غير معينة لأحد.';

  @override
  String get totalsScreenTitle => 'إجمالي كل شخص';

  @override
  String get startNewBillButton => 'ابدأ فاتورة جديدة';

  @override
  String get subtotalLabel => 'المجموع الفرعي';

  @override
  String get finalLabel => 'الإجمالي';

  @override
  String get currencyEgp => 'ج.م';

  @override
  String get languageButton => 'English';

  @override
  String get extractionFailed => 'تعذر قراءة الفاتورة. أدخل الأصناف يدويًا.';

  @override
  String get extractionEmpty => 'لم يتم اكتشاف أصناف. أدخل الأصناف يدويًا.';

  @override
  String get imageTooLarge => 'الصورة كبيرة جدًا. جرّب صورة أصغر.';

  @override
  String get invalidImage => 'لا يمكن قراءة هذه الصورة.';

  @override
  String get networkError => 'تعذر الاتصال بالخادم. أدخل الأصناف يدويًا.';
}
