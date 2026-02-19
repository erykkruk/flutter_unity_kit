import 'package:flutter/material.dart';

/// Default placeholder widget shown while Unity is loading.
///
/// Provides a customizable loading experience with a progress indicator
/// and optional message text.
///
/// Example:
/// ```dart
/// UnityView(
///   placeholder: const UnityPlaceholder(
///     message: 'Preparing 3D view...',
///     backgroundColor: Colors.black,
///   ),
/// )
/// ```
class UnityPlaceholder extends StatelessWidget {
  /// Creates a new [UnityPlaceholder].
  const UnityPlaceholder({
    super.key,
    this.message = 'Loading Unity...',
    this.backgroundColor,
    this.indicatorColor,
    this.textStyle,
    this.builder,
  });

  /// Text message displayed below the progress indicator.
  final String message;

  /// Background color of the placeholder.
  final Color? backgroundColor;

  /// Color of the progress indicator.
  final Color? indicatorColor;

  /// Style for the message text.
  final TextStyle? textStyle;

  /// Custom builder that replaces the default layout.
  ///
  /// When provided, [message], [indicatorColor], and [textStyle] are ignored.
  final WidgetBuilder? builder;

  @override
  Widget build(BuildContext context) {
    final bgColor =
        backgroundColor ?? Theme.of(context).scaffoldBackgroundColor;

    if (builder != null) {
      return Container(
        color: bgColor,
        child: builder!(context),
      );
    }

    return Container(
      color: bgColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: indicatorColor,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: textStyle ?? Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
