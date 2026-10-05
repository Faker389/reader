import 'package:flutter/widgets.dart';

extension MotionContext on BuildContext {
  /// True when the user asked for reduced motion (system or in-app setting —
  /// the app folds its setting into [MediaQueryData.disableAnimations]).
  bool get reduceMotion => MediaQuery.maybeDisableAnimationsOf(this) ?? false;

  Duration motion(Duration duration) => reduceMotion ? Duration.zero : duration;
}
