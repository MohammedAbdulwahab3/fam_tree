import 'package:flutter/material.dart';
import 'package:family_tree/core/theme/app_theme.dart';

/// Context panel showing person details
class ContextPanel extends StatelessWidget {
  final String personName;
  final List<String> photos;
  final String? bio;
  final VoidCallback onClose;
  final VoidCallback? onEdit;

  const ContextPanel({
    Key? key,
    required this.personName,
    this.photos = const [],
    this.bio,
    required this.onClose,
    this.onEdit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 350,
      decoration: BoxDecoration(
        gradient: AppTheme.surfaceGradient,
        boxShadow: AppTheme.shadowLg,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    personName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                ),
                if (onEdit != null)
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white),
                    onPressed: onEdit,
                  ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: onClose,
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Photos section
                  if (photos.isNotEmpty) ...[
                    Text(
                      'Photos',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: photos.length,
                        itemBuilder: (context, index) {
                          return Container(
                            width: 120,
                            margin: const EdgeInsets.only(
                                right: AppTheme.spaceSm),
                            decoration: BoxDecoration(
                              color: AppTheme.cardDark,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMd),
                              image: DecorationImage(
                                image: NetworkImage(photos[index]),
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceLg),
                  ],

                  // Biography
                  if (bio != null && bio!.isNotEmpty) ...[
                    Text(
                      'Biography',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                    Text(
                      bio!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],

                  // Placeholder for life events
                  const SizedBox(height: AppTheme.spaceLg),
                  Text(
                    'Life Events',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppTheme.spaceSm),
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spaceMd),
                    decoration: BoxDecoration(
                      color: AppTheme.cardDark.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Text(
                      'No life events yet',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
