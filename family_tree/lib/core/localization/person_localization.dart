import 'package:flutter/material.dart';

import 'package:family_tree/core/localization/app_localizations_x.dart';
import 'package:family_tree/data/models/person.dart';

extension PersonLocalizationX on Person {
  String localizedFullName(BuildContext context) {
    return fullNameForLocaleTag(context.localeTag);
  }

  String localizedShortName(BuildContext context) {
    return shortNameForLocaleTag(context.localeTag);
  }

  String localizedInitials(BuildContext context) {
    return initialsForLocaleTag(context.localeTag).toUpperCase();
  }

  String localizedLifespan(BuildContext context) {
    if (birthDate == null && deathDate == null) {
      return '';
    }

    final l10n = context.l10n;
    final birth =
        birthDate != null ? birthDate!.year.toString() : l10n.unknownYearLabel;
    final death =
        deathDate != null ? deathDate!.year.toString() : l10n.presentLabel;
    return '$birth - $death';
  }
}

String localizeGender(BuildContext context, String gender) {
  final l10n = context.l10n;
  switch (gender.toLowerCase()) {
    case 'female':
      return l10n.female;
    case 'male':
      return l10n.male;
    default:
      return gender;
  }
}

String localizeRelationshipType(BuildContext context, RelationshipType type) {
  final l10n = context.l10n;
  switch (type) {
    case RelationshipType.biological:
      return l10n.relationshipBiological;
    case RelationshipType.marriage:
      return l10n.relationshipMarriage;
    case RelationshipType.adoption:
      return l10n.relationshipAdoption;
    case RelationshipType.step:
      return l10n.relationshipStep;
    case RelationshipType.partnership:
      return l10n.relationshipPartnership;
  }
}
