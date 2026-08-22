// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Family Tree';

  @override
  String get languageMenuTooltip => 'Language';

  @override
  String get localeEnglish => 'English';

  @override
  String get localeAmharic => 'Amharic';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get errorPrefix => 'Error';

  @override
  String get emptyFamilyMembers => 'No family members yet';

  @override
  String get addFirstPerson => 'Add First Person';

  @override
  String get layoutFocus => 'Focus';

  @override
  String get layoutTree => 'Tree';

  @override
  String get layoutRadial => 'Radial';

  @override
  String get layoutTimeline => 'Timeline';

  @override
  String get layoutList => 'List';

  @override
  String get viewDetails => 'View Details';

  @override
  String get edit => 'Edit';

  @override
  String get addChild => 'Add Child';

  @override
  String get focusOnSubtree => 'Focus on Subtree';

  @override
  String get delete => 'Delete';

  @override
  String get deletePersonTitle => 'Delete Person';

  @override
  String deletePersonMessage(String personName) {
    return 'Are you sure you want to delete $personName? This will also remove their relationships.';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get addPersonTitle => 'Add Person';

  @override
  String get editPersonTitle => 'Edit Person';

  @override
  String get defaultNameSection => 'Default Name';

  @override
  String get localizedAmharicNameSection => 'Amharic Name (Optional)';

  @override
  String get firstNameLabel => 'First Name';

  @override
  String get lastNameLabel => 'Last Name';

  @override
  String get firstNameRequiredError => 'First name is required.';

  @override
  String get genderLabel => 'Gender';

  @override
  String get male => 'Male';

  @override
  String get female => 'Female';

  @override
  String get birthDateLabel => 'Birth Date';

  @override
  String get deathDateLabel => 'Death Date';

  @override
  String get stillAliveLabel => 'Still alive';

  @override
  String get bioLabel => 'Bio';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get selectDate => 'Select date';

  @override
  String personSaveError(String error) {
    return 'Unable to save person: $error';
  }

  @override
  String get zoomIn => 'Zoom In';

  @override
  String get zoomOut => 'Zoom Out';

  @override
  String get fitAll => 'Fit All';

  @override
  String get resetView => 'Reset View';

  @override
  String get toggleMinimap => 'Toggle Minimap';

  @override
  String get generations => 'Generations';

  @override
  String get all => 'All';

  @override
  String get searchFamily => 'Search family...';

  @override
  String get backToFullTree => 'Back to Full Tree';

  @override
  String get stopTour => 'Stop Tour';

  @override
  String get startTour => 'Start Tour';

  @override
  String peopleCount(int count) {
    return '$count people';
  }

  @override
  String get noChildrenRecorded => 'No children recorded';

  @override
  String get back => 'Back';

  @override
  String get home => 'Home';

  @override
  String generationShort(int number) {
    return 'Gen $number';
  }

  @override
  String get overview => 'Overview';

  @override
  String get bornLabel => 'Born';

  @override
  String get diedLabel => 'Died';

  @override
  String get lifeEventsLabel => 'Life Events';

  @override
  String get presentLabel => 'Present';

  @override
  String get unknownYearLabel => '?';

  @override
  String get relationshipBiological => 'biological';

  @override
  String get relationshipMarriage => 'marriage';

  @override
  String get relationshipAdoption => 'adoption';

  @override
  String get relationshipStep => 'step';

  @override
  String get relationshipPartnership => 'partnership';
}
