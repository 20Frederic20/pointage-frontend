import 'package:flutter/widgets.dart';

enum WindowSize { compact, medium, expanded }

/// Points de rupture communs à tous les écrans.
/// Utiliser [of] pour la fenêtre (navigation), [fromWidth] avec un `LayoutBuilder`
/// pour la place réellement disponible (contenu).
abstract final class Breakpoints {
  static const medium = 600.0;
  static const expanded = 1024.0;

  static WindowSize fromWidth(double width) => width >= expanded
      ? WindowSize.expanded
      : width >= medium
          ? WindowSize.medium
          : WindowSize.compact;

  static WindowSize of(BuildContext context) => fromWidth(MediaQuery.sizeOf(context).width);
}
