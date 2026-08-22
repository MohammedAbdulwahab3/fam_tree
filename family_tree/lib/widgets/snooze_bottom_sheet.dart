import 'package:flutter/material.dart';

class SnoozeBottomSheet extends StatelessWidget {
  final Function(int minutes) onSnooze;

  const SnoozeBottomSheet({
    super.key,
    required this.onSnooze,
  });

  @override
  Widget build(BuildContext context) {
    final snoozeOptions = [
      {'label': '15 minutes', 'minutes': 15, 'icon': Icons.alarm},
      {'label': '1 hour', 'minutes': 60, 'icon': Icons.alarm},
      {'label': '3 hours', 'minutes': 180, 'icon': Icons.alarm},
      {'label': '1 day', 'minutes': 1440, 'icon': Icons.calendar_today},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Snooze Reminder',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Choose when to be reminded again:',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ...snoozeOptions.map((option) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Icon(
                  option['icon'] as IconData,
                  color: Colors.blue,
                ),
                title: Text(option['label'] as String),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onSnooze(option['minutes'] as int);
                },
              ),
            );
          }),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> show(
    BuildContext context,
    Function(int minutes) onSnooze,
  ) async {
    return showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SnoozeBottomSheet(onSnooze: onSnooze),
    );
  }
}
