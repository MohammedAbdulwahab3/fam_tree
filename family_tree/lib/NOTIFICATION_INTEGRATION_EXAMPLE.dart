// Example of how to integrate NotificationService into your main.dart
// This code should be added to your existing main.dart file

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/main.dart';
import 'data/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Initialize Notification Service
  final notificationService = NotificationService();
  await notificationService.initialize();
  
  // Set up notification tap handler for deep linking
  notificationService.onNotificationTap = (data) {
    // Navigate to the appropriate screen based on notification data
    // Example: if (data['entityType'] == 'post') { /* navigate to post */ }
    print('Notification tapped: $data');
  };
  
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

// Example: Add notification icon to your app bar
// AppBar(
//   title: Text('Family Tree'),
//   actions: [
//     Consumer(
//       builder: (context, ref, child) {
//         final unreadCount = ref.watch(unreadCountProvider);
//         return unreadCount.when(
//           data: (count) => IconButton(
//             icon: NotificationBadge(
//               count: count,
//               child: Icon(Icons.notifications),
//             ),
//             onPressed: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder: (_) => NotificationsScreen(),
//                 ),
//               );
//             },
//           ),
//           loading: () => IconButton(
//             icon: Icon(Icons.notifications),
//             onPressed: () {},
//           ),
//           error: (_, __) => IconButton(
//             icon: Icon(Icons.notifications),
//             onPressed: () {},
//           ),
//         );
//       },
//     ),
//   ],
// ),
