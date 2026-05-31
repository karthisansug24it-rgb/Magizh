import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLanguage {
  final String code;
  final String name;
  final String nativeName;
  final String region;

  const AppLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.region,
  });
}

const appLanguages = [
  AppLanguage(code: 'en', name: 'English', nativeName: 'English', region: 'Global'),
  AppLanguage(code: 'ta', name: 'Tamil', nativeName: 'தமிழ்', region: 'Tamil Nadu'),
];

final localeProvider = NotifierProvider<LocaleController, Locale?>(LocaleController.new);

class LocaleController extends Notifier<Locale?> {
  static const _storageKey = 'magizh_locale_code';
  bool _loaded = false;

  @override
  Locale? build() {
    if (!_loaded) {
      _loaded = true;
      Future.microtask(_restoreSavedLocale);
    }
    return null;
  }

  Future<void> _restoreSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_storageKey);
    if (code != null && AppStrings.supportedLanguageCodes.contains(code)) {
      state = Locale(code);
    }
  }

  Future<void> setLocale(String? code) async {
    final prefs = await SharedPreferences.getInstance();
    if (code == null) {
      state = null;
      await prefs.remove(_storageKey);
      return;
    }
    if (!AppStrings.supportedLanguageCodes.contains(code)) return;
    state = Locale(code);
    await prefs.setString(_storageKey, code);
  }
}

extension AppTranslations on BuildContext {
  String t(String key, {Map<String, Object> args = const {}}) {
    final locale = Localizations.maybeLocaleOf(this) ?? WidgetsBinding.instance.platformDispatcher.locale;
    return AppStrings.translate(locale.languageCode, key, args: args);
  }

  String productName(Map<String, dynamic> product) {
    return localizedProductValue(product, i18nColumn: 'name_i18n', fallbackColumn: 'name');
  }

  String productCategory(Map<String, dynamic> product) {
    return localizedProductValue(product, i18nColumn: 'category_i18n', fallbackColumn: 'category');
  }

  String localizedProductValue(
    Map<String, dynamic> row, {
    required String i18nColumn,
    required String fallbackColumn,
  }) {
    final locale = Localizations.maybeLocaleOf(this) ?? WidgetsBinding.instance.platformDispatcher.locale;
    final languageCode = AppStrings.supportedLanguageCodes.contains(locale.languageCode)
        ? locale.languageCode
        : AppStrings.fallbackLocale;
    final translated = AppStrings.mapValue(row[i18nColumn], languageCode) ??
        AppStrings.mapValue(row[i18nColumn], AppStrings.fallbackLocale);
    if (translated != null && translated.trim().isNotEmpty) {
      return translated.trim();
    }
    return (row[fallbackColumn] ?? '').toString();
  }
}

class AppStrings {
  static const fallbackLocale = 'en';
  static Set<String> get supportedLanguageCodes => appLanguages.map((language) => language.code).toSet();

  static String? mapValue(Object? value, String languageCode) {
    if (value is Map) {
      final translated = value[languageCode];
      return translated?.toString();
    }
    return null;
  }

  static String translate(String locale, String key, {Map<String, Object> args = const {}}) {
    var value = _strings[locale]?[key] ?? _strings[fallbackLocale]?[key] ?? key;
    for (final entry in args.entries) {
      value = value.replaceAll('{${entry.key}}', entry.value.toString());
    }
    return value;
  }

  static const Map<String, Map<String, String>> _strings = {
    'en': {
      'welcomeBack': 'WELCOME BACK!',
      'searchHint': 'Search freshly baked items...',
      'noProducts': 'No products found',
      'connectionError': 'Connection Error',
      'couldNotConnect': 'Could not connect to Supabase',
      'retryConnection': 'Retry Connection',
      'morningTitle': 'Morning Fresh Delights',
      'morningSubtitle': 'Hot coffee, fresh tea, healthy breakfast snacks, and warm pastries available now.',
      'morningTag': 'MORNING SNACKS',
      'eveningTitle': 'Evening Crispy Bites',
      'eveningSubtitle': 'Puffs, juice, cake, cutlets, samosas and evening chai ready from 4 PM.',
      'eveningTag': 'EVENING SNACKS',
      'home': 'Home',
      'inventory': 'Inventory',
      'expense': 'Expense',
      'analytics': 'Analytics',
      'settings': 'Settings',
      'language': 'Language',
      'all': 'All',
      'other': 'Other',
      'systemDefault': 'System default',
      'systemDefaultNative': 'Device language',
      'systemDefaultRegion': 'Android/iOS',
      'followDeviceLanguage': 'Follow device language',
      'appLanguage': 'App language',
      'languageSubtitle': 'Choose the language used across Magizh.',
      'selectedLanguage': 'Selected language',
      'instantApply': 'Applies instantly and stays saved on this device.',
      'regionalLanguages': 'Regional languages',
      'systemReady': 'Professional translation foundation',
      'systemReadySubtitle': 'All fixed UI labels use one centralized catalog.',
      'selected': 'Selected',
      'chooseLanguage': 'Choose language',
      'done': 'Done',
      'addProduct': 'Add Product',
      'editProduct': 'Edit Product',
      'productName': 'Product name',
      'productNameEnglish': 'Product name (English)',
      'productNameTamil': 'Product name (Tamil)',
      'price': 'Price',
      'category': 'Category',
      'categoryEnglish': 'Category (English)',
      'categoryTamil': 'Category (Tamil)',
      'stockQty': 'Stock Qty',
      'enterNewCategory': 'Enter new category name',
      'categoryHint': 'e.g. Pizza, Cake',
      'choosePhoto': 'Choose photo',
      'photoSelected': 'Photo selected',
      'changePhoto': 'Change photo',
      'newPhotoSelected': 'New photo selected',
      'addProductButton': 'Add product',
      'saveChanges': 'Save Changes',
      'validAddProduct': 'Enter valid name, price, category and choose a photo.',
      'validEditProduct': 'Enter valid name, price and category.',
      'tamilOptional': 'Tamil is optional. Empty Tamil fields fall back to English.',
      'addToCard': 'Add to Card',
      'createNew': 'Create New',
      'deleteProduct': 'Delete Product',
      'deleteProductConfirm': 'Are you sure you want to delete this product?',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'productUpdated': 'Product updated successfully!',
      'productDeleted': 'Product deleted',
      'soldOut': 'Sold out',
      'leftCount': '{count} left',
      'availableCount': '{count} available',
      'classic': 'Classic',
      'specialty': 'Specialty',
      'fresh': 'Fresh',
      'popular': 'Popular',
      'chilled': 'Chilled',
      'noTimeSlotProducts': 'No products found for this time slot',
      'selectedCount': 'Selected: {count}',
      'amount': 'Amount: ₹{amount}',
      'continue': 'Continue',
      'adjustInventory': 'Adjust quantities and upload',
      'searchProducts': 'Search products...',
      'saving': 'Saving...',
      'save': 'Save',
      'add': 'Add',
      'addProducts': 'Add Products',
      'restoreInventory': 'Pick snacks to restore in inventory',
      'noInactiveProducts': 'No inactive products found.',
      'saveToInventory': 'Save to Inventory',
      'notAvailable': 'N/A',
      'checkout': 'Checkout',
      'paymentMethod': 'Payment Method',
      'online': 'Online',
      'cash': 'Cash',
      'summary': 'Summary',
      'totalAmount': 'Total Amount',
      'cashReceived': 'Cash Received',
      'enterAmount': 'Enter amount',
      'balance': 'Balance',
      'short': 'Short',
      'confirmOrder': 'Confirm Order (₹{amount})',
      'orderSuccess': 'Order placed successfully!',
      'errorPlacingOrder': 'Error placing order: {error}',
      'errorSaving': 'Error saving: {error}',
      'fetchError': 'Fetch error: {error}',
      'failed': 'Failed: {error}',
      'updateFailed': 'Update failed: {error}',
      'deleteFailed': 'Delete failed: {error}',
      'unknown': 'Unknown',
      'analyticsTitle': 'Analytics & Tracker',
      'dailyOrdersThisMonth': 'Daily Orders (This Month)',
      'yearlyTrendThisYear': 'Yearly Trend (This Year)',
      'ordersByWeekday': 'Orders by Weekday (All Time)',
      'currentMonthSalary': 'Current Month Salary',
      'monthTracker': '{month} Tracker',
      'totalOrders': '{count} total orders',
      'growth': 'Growth',
      'searchByDate': 'Search by Date',
      'selectDate': 'Select Date',
      'orders': 'Orders',
      'revenue': 'Revenue',
      'ordersByDayFor': 'Orders by day for {period}',
      'dayNumber': 'Day {day}',
      'totalRevenueTrend': 'Total revenue trend per month for {year}',
      'busiestDays': 'Which days are the busiest?',
      'avg': 'AVG',
      'tryAgain': 'Try Again',
      'noOrdersFound': 'No orders found',
      'items': '{count} items',
      'date': 'Date: {date}',
      'offline': 'Offline',
    },
    'ta': {
      'welcomeBack': 'மீண்டும் வரவேற்கிறோம்!',
      'searchHint': 'புதிய பேக்கரி பொருட்களைத் தேடுங்கள்...',
      'noProducts': 'பொருட்கள் இல்லை',
      'connectionError': 'இணைப்பு பிழை',
      'couldNotConnect': 'Supabase இணைக்க முடியவில்லை',
      'retryConnection': 'மீண்டும் முயற்சி',
      'morningTitle': 'காலை புதிய சுவைகள்',
      'morningSubtitle': 'சூடான காபி, புதிய டீ, காலை ஸ்நாக்ஸ் மற்றும் பேஸ்ட்ரிகள் இப்போது கிடைக்கும்.',
      'morningTag': 'காலை ஸ்நாக்ஸ்',
      'eveningTitle': 'மாலை க்ரிஸ்பி பைட்ஸ்',
      'eveningSubtitle': 'பஃப்ஸ், ஜூஸ், கேக், கட்லெட், சமோசா மற்றும் மாலை டீ 4 மணிக்கு தயார்.',
      'eveningTag': 'மாலை ஸ்நாக்ஸ்',
      'home': 'முகப்பு',
      'inventory': 'ஸ்டாக்',
      'expense': 'செலவு',
      'analytics': 'அனலிட்டிக்ஸ்',
      'settings': 'அமைப்புகள்',
      'language': 'மொழி',
      'all': 'அனைத்தும்',
      'other': 'மற்றவை',
      'systemDefault': 'சிஸ்டம் இயல்பு',
      'systemDefaultNative': 'சாதன மொழி',
      'systemDefaultRegion': 'Android/iOS',
      'followDeviceLanguage': 'சாதன மொழியைப் பின்பற்று',
      'appLanguage': 'ஆப் மொழி',
      'languageSubtitle': 'மகிழ் முழுவதும் பயன்படுத்தும் மொழியைத் தேர்வு செய்யுங்கள்.',
      'selectedLanguage': 'தேர்ந்தெடுத்த மொழி',
      'instantApply': 'உடனே மாறும்; இந்த சாதனத்தில் சேமிக்கப்படும்.',
      'regionalLanguages': 'பிராந்திய மொழிகள்',
      'systemReady': 'தொழில்முறை மொழிபெயர்ப்பு அடித்தளம்',
      'systemReadySubtitle': 'அனைத்து நிலையான UI வார்த்தைகளும் ஒரே catalog-ல் உள்ளது.',
      'selected': 'தேர்வு செய்யப்பட்டது',
      'chooseLanguage': 'மொழி தேர்வு',
      'done': 'முடிந்தது',
      'addProduct': 'பொருள் சேர்க்க',
      'editProduct': 'பொருள் திருத்த',
      'productName': 'பொருள் பெயர்',
      'productNameEnglish': 'பொருள் பெயர் (English)',
      'productNameTamil': 'பொருள் பெயர் (தமிழ்)',
      'price': 'விலை',
      'category': 'வகை',
      'categoryEnglish': 'வகை (English)',
      'categoryTamil': 'வகை (தமிழ்)',
      'stockQty': 'ஸ்டாக் அளவு',
      'enterNewCategory': 'புதிய வகை பெயர்',
      'categoryHint': 'உதா. Pizza, Cake',
      'choosePhoto': 'புகைப்படம் தேர்வு',
      'photoSelected': 'புகைப்படம் தேர்ந்தது',
      'changePhoto': 'புகைப்படம் மாற்ற',
      'newPhotoSelected': 'புதிய புகைப்படம் தேர்ந்தது',
      'addProductButton': 'பொருள் சேர்க்க',
      'saveChanges': 'மாற்றங்களை சேமி',
      'validAddProduct': 'சரியான பெயர், விலை, வகை மற்றும் புகைப்படம் கொடுங்கள்.',
      'validEditProduct': 'சரியான பெயர், விலை மற்றும் வகை கொடுங்கள்.',
      'tamilOptional': 'தமிழ் விருப்பமானது. காலியாக இருந்தால் English காட்டப்படும்.',
      'addToCard': 'கார்டில் சேர்க்க',
      'createNew': 'புதியது உருவாக்கு',
      'deleteProduct': 'பொருள் நீக்கு',
      'deleteProductConfirm': 'இந்த பொருளை நீக்க வேண்டுமா?',
      'cancel': 'ரத்து',
      'delete': 'நீக்கு',
      'productUpdated': 'பொருள் வெற்றிகரமாக புதுப்பிக்கப்பட்டது!',
      'productDeleted': 'பொருள் நீக்கப்பட்டது',
      'soldOut': 'முடிந்தது',
      'leftCount': '{count} உள்ளது',
      'availableCount': '{count} கிடைக்கும்',
      'classic': 'கிளாசிக்',
      'specialty': 'ஸ்பெஷல்',
      'fresh': 'புதியது',
      'popular': 'பிரபலமானது',
      'chilled': 'குளிர்ந்தது',
      'noTimeSlotProducts': 'இந்த நேரத்திற்கு பொருட்கள் இல்லை',
      'selectedCount': 'தேர்வு: {count}',
      'amount': 'தொகை: ₹{amount}',
      'continue': 'தொடரவும்',
      'adjustInventory': 'அளவுகளை மாற்றி upload செய்யுங்கள்',
      'searchProducts': 'பொருட்களைத் தேடுங்கள்...',
      'saving': 'சேமிக்கிறது...',
      'save': 'சேமி',
      'add': 'சேர்',
      'addProducts': 'பொருட்கள் சேர்க்க',
      'restoreInventory': 'Inventory-க்கு மீட்டெடுக்க snacks தேர்வு செய்யுங்கள்',
      'noInactiveProducts': 'செயலற்ற பொருட்கள் இல்லை.',
      'saveToInventory': 'Inventory-க்கு சேமி',
      'notAvailable': 'இல்லை',
      'checkout': 'செக்க்அவுட்',
      'paymentMethod': 'கட்டண முறை',
      'online': 'ஆன்லைன்',
      'cash': 'பணம்',
      'summary': 'சுருக்கம்',
      'totalAmount': 'மொத்த தொகை',
      'cashReceived': 'பெற்ற பணம்',
      'enterAmount': 'தொகை உள்ளிடவும்',
      'balance': 'மீதம்',
      'short': 'குறைவு',
      'confirmOrder': 'ஆர்டர் உறுதி (₹{amount})',
      'orderSuccess': 'ஆர்டர் வெற்றிகரமாக முடிந்தது!',
      'errorPlacingOrder': 'ஆர்டர் செய்ய பிழை: {error}',
      'errorSaving': 'சேமிக்க பிழை: {error}',
      'fetchError': 'தரவை பெற பிழை: {error}',
      'failed': 'தோல்வி: {error}',
      'updateFailed': 'புதுப்பிக்க பிழை: {error}',
      'deleteFailed': 'நீக்க பிழை: {error}',
      'unknown': 'தெரியவில்லை',
      'analyticsTitle': 'அனலிட்டிக்ஸ் & டிராக்கர்',
      'dailyOrdersThisMonth': 'தினசரி ஆர்டர்கள் (இந்த மாதம்)',
      'yearlyTrendThisYear': 'வருட போக்கு (இந்த ஆண்டு)',
      'ordersByWeekday': 'வாரநாள் ஆர்டர்கள் (மொத்தம்)',
      'currentMonthSalary': 'இந்த மாத வருமானம்',
      'monthTracker': '{month} டிராக்கர்',
      'totalOrders': '{count} மொத்த ஆர்டர்கள்',
      'growth': 'வளர்ச்சி',
      'searchByDate': 'தேதியால் தேடு',
      'selectDate': 'தேதி தேர்வு',
      'orders': 'ஆர்டர்கள்',
      'revenue': 'வருமானம்',
      'ordersByDayFor': '{period} தின ஆர்டர்கள்',
      'dayNumber': 'நாள் {day}',
      'totalRevenueTrend': '{year} மாத வருமான போக்கு',
      'busiestDays': 'அதிக பிஸியான நாட்கள்?',
      'avg': 'சராசரி',
      'tryAgain': 'மீண்டும் முயற்சி',
      'noOrdersFound': 'ஆர்டர்கள் இல்லை',
      'items': '{count} பொருட்கள்',
      'date': 'தேதி: {date}',
      'offline': 'ஆஃப்லைன்',
    },
  };
}
