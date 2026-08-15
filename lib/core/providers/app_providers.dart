/// App Providers
///
/// Riverpod providers for app-wide state management.
/// Includes theme mode, locale, and app settings providers.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../constants/app_constants.dart';

/// Provider for the Hive settings box.
final settingsBoxProvider = Provider<Box>((ref) {
  return Hive.box(AppConstants.settingsBox);
});

/// State notifier for theme mode management.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final Box _settingsBox;

  ThemeModeNotifier(this._settingsBox)
      : super(_loadThemeMode(_settingsBox));

  /// Loads theme mode from Hive storage.
  static ThemeMode _loadThemeMode(Box box) {
    final value = box.get(AppConstants.themeModeKey, defaultValue: 'light');
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }

  /// Sets the theme mode and persists it.
  void setThemeMode(ThemeMode mode) {
    String value;
    switch (mode) {
      case ThemeMode.dark:
        value = 'dark';
        break;
      case ThemeMode.light:
        value = 'light';
        break;
      case ThemeMode.system:
        value = 'system';
        break;
    }
    _settingsBox.put(AppConstants.themeModeKey, value);
    state = mode;
  }

  /// Toggles between light and dark mode.
  void toggleTheme() {
    setThemeMode(
      state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }
}

/// Provider for theme mode state.
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final box = ref.watch(settingsBoxProvider);
  return ThemeModeNotifier(box);
});

/// State notifier for locale management.
class LocaleNotifier extends StateNotifier<Locale> {
  final Box _settingsBox;

  LocaleNotifier(this._settingsBox)
      : super(_loadLocale(_settingsBox));

  /// Loads locale from Hive storage.
  static Locale _loadLocale(Box box) {
    final value = box.get(AppConstants.localeKey, defaultValue: 'ar');
    return Locale(value);
  }

  /// Sets the locale and persists it.
  void setLocale(Locale locale) {
    _settingsBox.put(AppConstants.localeKey, locale.languageCode);
    state = locale;
  }

  /// Toggles between Arabic and English.
  void toggleLocale() {
    setLocale(
      state.languageCode == 'ar' ? const Locale('en') : const Locale('ar'),
    );
  }

  /// Returns true if the current locale is Arabic (RTL).
  bool get isArabic => state.languageCode == 'ar';
}

/// Provider for locale state.
final localeProvider =
    StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  final box = ref.watch(settingsBoxProvider);
  return LocaleNotifier(box);
});

/// State for company settings.
class CompanySettings {
  final String companyName;
  final String? companyLogoPath;
  final double taxPercentage;
  final String currency;
  final String currencySymbol;

  const CompanySettings({
    this.companyName = 'Marivio',
    this.companyLogoPath,
    this.taxPercentage = AppConstants.defaultTaxPercentage,
    this.currency = AppConstants.defaultCurrency,
    this.currencySymbol = AppConstants.defaultCurrencySymbol,
  });

  CompanySettings copyWith({
    String? companyName,
    String? companyLogoPath,
    double? taxPercentage,
    String? currency,
    String? currencySymbol,
  }) {
    return CompanySettings(
      companyName: companyName ?? this.companyName,
      companyLogoPath: companyLogoPath ?? this.companyLogoPath,
      taxPercentage: taxPercentage ?? this.taxPercentage,
      currency: currency ?? this.currency,
      currencySymbol: currencySymbol ?? this.currencySymbol,
    );
  }
}

/// State notifier for company settings.
class CompanySettingsNotifier extends StateNotifier<CompanySettings> {
  final Box _settingsBox;

  CompanySettingsNotifier(this._settingsBox)
      : super(_loadSettings(_settingsBox));

  /// Loads company settings from Hive storage.
  static CompanySettings _loadSettings(Box box) {
    return CompanySettings(
      companyName: box.get(AppConstants.companyNameKey, defaultValue: 'Marivio'),
      companyLogoPath: box.get(AppConstants.companyLogoKey),
      taxPercentage: box.get(
        AppConstants.taxPercentageKey,
        defaultValue: AppConstants.defaultTaxPercentage,
      ) as double,
      currency: box.get(
        AppConstants.currencyKey,
        defaultValue: AppConstants.defaultCurrency,
      ),
      currencySymbol: AppConstants.defaultCurrencySymbol,
    );
  }

  /// Updates company settings and persists them.
  void updateSettings(CompanySettings settings) {
    _settingsBox.put(AppConstants.companyNameKey, settings.companyName);
    if (settings.companyLogoPath != null) {
      _settingsBox.put(AppConstants.companyLogoKey, settings.companyLogoPath);
    }
    _settingsBox.put(AppConstants.taxPercentageKey, settings.taxPercentage);
    _settingsBox.put(AppConstants.currencyKey, settings.currency);
    state = settings;
  }
}

/// Provider for company settings.
final companySettingsProvider =
    StateNotifierProvider<CompanySettingsNotifier, CompanySettings>((ref) {
  final box = ref.watch(settingsBoxProvider);
  return CompanySettingsNotifier(box);
});