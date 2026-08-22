// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Amharic (`am`).
class AppLocalizationsAm extends AppLocalizations {
  AppLocalizationsAm([String locale = 'am']) : super(locale);

  @override
  String get appTitle => 'የቤተሰብ ዛፍ';

  @override
  String get languageMenuTooltip => 'ቋንቋ';

  @override
  String get localeEnglish => 'English';

  @override
  String get localeAmharic => 'አማርኛ';

  @override
  String get themeDark => 'ጨለማ';

  @override
  String get themeLight => 'ብርሃን';

  @override
  String get errorPrefix => 'ስህተት';

  @override
  String get emptyFamilyMembers => 'እስካሁን ድረስ ምንም የቤተሰብ አባል የለም';

  @override
  String get addFirstPerson => 'የመጀመሪያውን ሰው ጨምር';

  @override
  String get layoutFocus => 'ትኩረት';

  @override
  String get layoutTree => 'ዛፍ';

  @override
  String get layoutRadial => 'ክብ';

  @override
  String get layoutTimeline => 'የጊዜ መስመር';

  @override
  String get layoutList => 'ዝርዝር';

  @override
  String get viewDetails => 'ዝርዝር አሳይ';

  @override
  String get edit => 'አርትዕ';

  @override
  String get addChild => 'ልጅ ጨምር';

  @override
  String get focusOnSubtree => 'በዚህ ቅርንጫፍ ላይ ትኩረት አድርግ';

  @override
  String get delete => 'ሰርዝ';

  @override
  String get deletePersonTitle => 'ሰው ሰርዝ';

  @override
  String deletePersonMessage(String personName) {
    return '$personName እንዲሰረዝ እርግጠኛ ነህ? ይህ ከእሱ ጋር ያሉ ግንኙነቶችንም ያስወግዳል።';
  }

  @override
  String get cancel => 'ይቅር';

  @override
  String get addPersonTitle => 'ሰው ጨምር';

  @override
  String get editPersonTitle => 'ሰው አርትዕ';

  @override
  String get defaultNameSection => 'መደበኛ ስም';

  @override
  String get localizedAmharicNameSection => 'የአማርኛ ስም (አማራጭ)';

  @override
  String get firstNameLabel => 'የመጀመሪያ ስም';

  @override
  String get lastNameLabel => 'የአባት/ቤተሰብ ስም';

  @override
  String get firstNameRequiredError => 'የመጀመሪያ ስም ያስፈልጋል።';

  @override
  String get genderLabel => 'ፆታ';

  @override
  String get male => 'ወንድ';

  @override
  String get female => 'ሴት';

  @override
  String get birthDateLabel => 'የትውልድ ቀን';

  @override
  String get deathDateLabel => 'የሞት ቀን';

  @override
  String get stillAliveLabel => 'በሕይወት ነው';

  @override
  String get bioLabel => 'አጭር መግለጫ';

  @override
  String get saveChanges => 'ለውጦችን አስቀምጥ';

  @override
  String get selectDate => 'ቀን ምረጥ';

  @override
  String personSaveError(String error) {
    return 'ሰውን ማስቀመጥ አልተቻለም: $error';
  }

  @override
  String get zoomIn => 'አሳድግ';

  @override
  String get zoomOut => 'አሳንስ';

  @override
  String get fitAll => 'ሁሉንም አስተካክል';

  @override
  String get resetView => 'እይታን ዳግም አስጀምር';

  @override
  String get toggleMinimap => 'ትንሽ ካርታን አሳይ/ደብቅ';

  @override
  String get generations => 'ትውልዶች';

  @override
  String get all => 'ሁሉም';

  @override
  String get searchFamily => 'ቤተሰቡን ፈልግ...';

  @override
  String get backToFullTree => 'ወደ ሙሉ ዛፉ ተመለስ';

  @override
  String get stopTour => 'ጉብኝትን አቁም';

  @override
  String get startTour => 'ጉብኝትን ጀምር';

  @override
  String peopleCount(int count) {
    return '$count ሰዎች';
  }

  @override
  String get noChildrenRecorded => 'ልጆች አልተመዘገቡም';

  @override
  String get back => 'ተመለስ';

  @override
  String get home => 'መነሻ';

  @override
  String generationShort(int number) {
    return 'ት $number';
  }

  @override
  String get overview => 'አጠቃላይ እይታ';

  @override
  String get bornLabel => 'ተወለደ';

  @override
  String get diedLabel => 'ሞተ';

  @override
  String get lifeEventsLabel => 'የሕይወት ክስተቶች';

  @override
  String get presentLabel => 'እስካሁን';

  @override
  String get unknownYearLabel => '?';

  @override
  String get relationshipBiological => 'የደም';

  @override
  String get relationshipMarriage => 'ጋብቻ';

  @override
  String get relationshipAdoption => 'ጉዲፈቻ';

  @override
  String get relationshipStep => 'የእንጀራ';

  @override
  String get relationshipPartnership => 'አጋርነት';
}
