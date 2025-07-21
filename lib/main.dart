import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:task_02/page_1.dart';
import 'package:task_02/page_2.dart';
import 'package:task_02/page_3.dart';
import 'package:task_02/page_4.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final NotificationService notificationService = NotificationService();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await notificationService.initialize();
  runApp(const MyApp());
}

class NotificationService {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> _configureLocalTimezone() async {
    tz.initializeTimeZones();
    final String timeZoneName = await FlutterNativeTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));
  }

  Future<void> initialize() async {
    await _configureLocalTimezone();

    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required Duration delay,
  }) async {
    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.now(tz.local).add(delay),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'channel_id',
          'channel_name',
          channelDescription: 'channel_description',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> getPendingNotificationRequests() async {
    debugPrint("Getting pending requests...");
    final List<PendingNotificationRequest> pendingRequests = await _flutterLocalNotificationsPlugin
        .pendingNotificationRequests();
    debugPrint("Pending requests: ${pendingRequests.length}");
  }
}

@pragma('vm:entry-point')
void onDidReceiveNotificationResponse(NotificationResponse response) {
  debugPrint("Notification tapped.");
  notificationService.getPendingNotificationRequests();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Coding challenge 02',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const ChallengeHomePage(),
    );
  }
}

class ChallengeHomePage extends StatelessWidget {
  const ChallengeHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Coding challenge 02')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Placeholder text.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              _ScenarioButton(
                title: 'Scenario 1',
                subtitle: 'Scenario 1 subtitle',
                icon: Icons.sync,
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const Page1()));
                },
              ),
              const SizedBox(height: 16),
              _ScenarioButton(
                title: 'Scenario 2',
                subtitle: 'Scenario 2 subtitle',
                icon: Icons.cloud_sync,
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const Page2()));
                },
              ),
              const SizedBox(height: 16),
              _ScenarioButton(
                title: 'Scenario 3',
                subtitle: 'Scenario 3 subtitle',
                icon: Icons.upload_file,
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const Page3()));
                },
              ),
              const SizedBox(height: 16),
              _ScenarioButton(
                title: 'Scenario 4',
                subtitle: 'Scenario 4 subtitle',
                icon: Icons.error,
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DataProcessingScreen()));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScenarioButton extends StatelessWidget {
  const _ScenarioButton({required this.title, required this.subtitle, required this.icon, required this.onPressed});

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 32, color: Theme.of(context).primaryColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
