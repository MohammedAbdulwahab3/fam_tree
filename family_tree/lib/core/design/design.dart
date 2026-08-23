/// The design system, in one import.
///
/// ```dart
/// import 'package:family_tree/core/design/design.dart';
/// ```
///
/// Everything a screen needs to look like the rest of the app: the tokens that
/// set its measurements, the type scale, and the components it is assembled
/// from. Colours come from `context.colors`, which this also exports.
library;

export 'package:family_tree/core/theme/app_colors.dart' show AppColors, ThemeColors;

export 'components/buttons.dart';
export 'components/feedback.dart';
export 'components/fields.dart';
export 'components/person_avatar.dart';
export 'components/scaffolds.dart';
export 'components/surfaces.dart';
export 'tokens.dart';
export 'typography.dart';
