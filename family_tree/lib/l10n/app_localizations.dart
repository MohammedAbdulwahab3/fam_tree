import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_am.dart';
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
    Locale('am'),
    Locale('en')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Family Tree'**
  String get appTitle;

  /// No description provided for @languageMenuTooltip.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageMenuTooltip;

  /// No description provided for @localeEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get localeEnglish;

  /// No description provided for @localeAmharic.
  ///
  /// In en, this message translates to:
  /// **'Amharic'**
  String get localeAmharic;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @errorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get errorPrefix;

  /// No description provided for @emptyFamilyMembers.
  ///
  /// In en, this message translates to:
  /// **'No family members yet'**
  String get emptyFamilyMembers;

  /// No description provided for @addFirstPerson.
  ///
  /// In en, this message translates to:
  /// **'Add First Person'**
  String get addFirstPerson;

  /// No description provided for @layoutFocus.
  ///
  /// In en, this message translates to:
  /// **'Focus'**
  String get layoutFocus;

  /// No description provided for @layoutTree.
  ///
  /// In en, this message translates to:
  /// **'Tree'**
  String get layoutTree;

  /// No description provided for @layoutRadial.
  ///
  /// In en, this message translates to:
  /// **'Radial'**
  String get layoutRadial;

  /// No description provided for @layoutTimeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get layoutTimeline;

  /// No description provided for @layoutList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get layoutList;

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get viewDetails;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @addChild.
  ///
  /// In en, this message translates to:
  /// **'Add Child'**
  String get addChild;

  /// No description provided for @focusOnSubtree.
  ///
  /// In en, this message translates to:
  /// **'Focus on Subtree'**
  String get focusOnSubtree;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deletePersonTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Person'**
  String get deletePersonTitle;

  /// No description provided for @deletePersonMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {personName}? This will also remove their relationships.'**
  String deletePersonMessage(String personName);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @addPersonTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Person'**
  String get addPersonTitle;

  /// No description provided for @editPersonTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Person'**
  String get editPersonTitle;

  /// No description provided for @defaultNameSection.
  ///
  /// In en, this message translates to:
  /// **'Default Name'**
  String get defaultNameSection;

  /// No description provided for @localizedAmharicNameSection.
  ///
  /// In en, this message translates to:
  /// **'Amharic Name (Optional)'**
  String get localizedAmharicNameSection;

  /// No description provided for @firstNameLabel.
  ///
  /// In en, this message translates to:
  /// **'First Name'**
  String get firstNameLabel;

  /// No description provided for @lastNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Last Name'**
  String get lastNameLabel;

  /// No description provided for @firstNameRequiredError.
  ///
  /// In en, this message translates to:
  /// **'First name is required.'**
  String get firstNameRequiredError;

  /// No description provided for @genderLabel.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get genderLabel;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @birthDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Birth Date'**
  String get birthDateLabel;

  /// No description provided for @deathDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Death Date'**
  String get deathDateLabel;

  /// No description provided for @stillAliveLabel.
  ///
  /// In en, this message translates to:
  /// **'Still alive'**
  String get stillAliveLabel;

  /// No description provided for @bioLabel.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get bioLabel;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get selectDate;

  /// No description provided for @personSaveError.
  ///
  /// In en, this message translates to:
  /// **'Unable to save person: {error}'**
  String personSaveError(String error);

  /// No description provided for @zoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom In'**
  String get zoomIn;

  /// No description provided for @zoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom Out'**
  String get zoomOut;

  /// No description provided for @fitAll.
  ///
  /// In en, this message translates to:
  /// **'Fit All'**
  String get fitAll;

  /// No description provided for @resetView.
  ///
  /// In en, this message translates to:
  /// **'Reset View'**
  String get resetView;

  /// No description provided for @toggleMinimap.
  ///
  /// In en, this message translates to:
  /// **'Toggle Minimap'**
  String get toggleMinimap;

  /// No description provided for @generations.
  ///
  /// In en, this message translates to:
  /// **'Generations'**
  String get generations;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @searchFamily.
  ///
  /// In en, this message translates to:
  /// **'Search family...'**
  String get searchFamily;

  /// No description provided for @backToFullTree.
  ///
  /// In en, this message translates to:
  /// **'Back to Full Tree'**
  String get backToFullTree;

  /// No description provided for @stopTour.
  ///
  /// In en, this message translates to:
  /// **'Stop Tour'**
  String get stopTour;

  /// No description provided for @startTour.
  ///
  /// In en, this message translates to:
  /// **'Start Tour'**
  String get startTour;

  /// No description provided for @peopleCount.
  ///
  /// In en, this message translates to:
  /// **'{count} people'**
  String peopleCount(int count);

  /// No description provided for @noChildrenRecorded.
  ///
  /// In en, this message translates to:
  /// **'No children recorded'**
  String get noChildrenRecorded;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @generationShort.
  ///
  /// In en, this message translates to:
  /// **'Gen {number}'**
  String generationShort(int number);

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @bornLabel.
  ///
  /// In en, this message translates to:
  /// **'Born'**
  String get bornLabel;

  /// No description provided for @diedLabel.
  ///
  /// In en, this message translates to:
  /// **'Died'**
  String get diedLabel;

  /// No description provided for @lifeEventsLabel.
  ///
  /// In en, this message translates to:
  /// **'Life Events'**
  String get lifeEventsLabel;

  /// No description provided for @presentLabel.
  ///
  /// In en, this message translates to:
  /// **'Present'**
  String get presentLabel;

  /// No description provided for @unknownYearLabel.
  ///
  /// In en, this message translates to:
  /// **'?'**
  String get unknownYearLabel;

  /// No description provided for @relationshipBiological.
  ///
  /// In en, this message translates to:
  /// **'biological'**
  String get relationshipBiological;

  /// No description provided for @relationshipMarriage.
  ///
  /// In en, this message translates to:
  /// **'marriage'**
  String get relationshipMarriage;

  /// No description provided for @relationshipAdoption.
  ///
  /// In en, this message translates to:
  /// **'adoption'**
  String get relationshipAdoption;

  /// No description provided for @relationshipStep.
  ///
  /// In en, this message translates to:
  /// **'step'**
  String get relationshipStep;

  /// No description provided for @relationshipPartnership.
  ///
  /// In en, this message translates to:
  /// **'partnership'**
  String get relationshipPartnership;
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
      <String>['am', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'am':
      return AppLocalizationsAm();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
