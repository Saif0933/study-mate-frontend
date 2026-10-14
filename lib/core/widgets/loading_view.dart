import 'package:flutter/material.dart';

/// Accessible loading indicator with message support and semantics.
class LoadingView extends StatelessWidget {
  final String? message;
  final double size;

  const LoadingView({super.key, this.message, this.size = 36.0});

  @override
  Widget build(BuildContext context) {
    final semanticMessage = message ?? 'Loading, please wait';

    return Semantics(
      label: semanticMessage,
      liveRegion: true,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: const CircularProgressIndicator(strokeWidth: 3),
              ),
              if (message != null) ...[
                const SizedBox(height: 16),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
