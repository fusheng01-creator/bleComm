// 匯入非同步操作所需的庫 (例如 Stream, Future)
import 'dart:async';
// 匯入用於平台判斷的 I/O 庫 (例如判斷 Android 或 iOS)
import 'dart:io';

// 匯入 Flutter UI 框架的核心庫
import 'package:flutter/material.dart';


import 'package:dchs_flutter_beacon/dchs_flutter_beacon.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class BeaconPage extends StatefulWidget {
  @override
  State<BeaconPage> createState() => _BeaconPageState();
}

class _BeaconPageState extends State<BeaconPage> {
  // 核心 Stream 訂閱
  StreamSubscription<MonitoringResult>? _streamMonitoring;
  StreamSubscription<RangingResult>? _streamRanging;
  String beaconStatus = '';

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  int isBeaconAlive = 0;
  int notiyShowCount = 0;

  // 狀態初始化時調用
  @override
  void initState() {
    super.initState();

    beacon_init();

    initializeNotifications();
    requestPermissions();
  }

  Future<void> beacon_init() async {
    try {
      // if you want to manage manual checking about the required permissions
      await flutterBeacon.initializeScanning;

      // or if you want to include automatic checking permission
      await flutterBeacon.initializeAndCheckScanning;
    } catch (e) {
      // library failed to initialize, check code and message
    }
  }

  void initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher'); // 替換為您的啟動圖示

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(); // iOS 設置

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      // onDidReceiveNotificationResponse: ... (處理點擊通知後的邏輯)
    );
  }

  // 首次運行時，請求權限 (iOS/Android 13+)
  Future<void> requestPermissions() async {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> showLockScreenNotification(String title, String body) async {
    // 1. Android 通知通道細節
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'high_importance_channel', // 必須是唯一的 Channel ID
          '高優先級通知',
          channelDescription: '用於緊急或待機畫面顯示的通知',
          importance: Importance.max, // << 關鍵：設置為最高優先級
          priority: Priority.high, // << 關鍵：設置為高優先級
          ticker: 'ticker',

          // 設置鎖定畫面可見性 (可選，但推薦)
          visibility: NotificationVisibility.public,
        );

    // 2. iOS/Darwin 平台設置 (相對簡單，因為行為主要依賴於系統權限)
    const DarwinNotificationDetails darwinPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true, // 確保在鎖定畫面顯示警報
          presentSound: true,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: darwinPlatformChannelSpecifics,
    );

    // 3. 顯示通知
    await flutterLocalNotificationsPlugin.show(
      notiyShowCount++, 
      title,
      body,
      platformChannelSpecifics,
      payload: 'item x',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.center, // 讓按鈕靠右對齊
        children: [
          // --- 第3個按鈕 (connect) ---
          SizedBox(
            width: 80,
            height: 80,
            child: FloatingActionButton(
              heroTag: '3_button', // 2. 給予獨立的 heroTag
              onPressed: () {
                final regions = <Region>[];

                beaconStatus = '';

                if (Platform.isIOS) {
                  // iOS platform, at least set identifier and proximityUUID for region scanning
                  regions.add(
                    Region(
                      identifier: 'Apple Airlocate',
                      proximityUUID: 'E2C56DB5-DFFB-48D2-B060-D0F5A71096E0',
                    ),
                  );
                } else {
                  // Android platform, it can ranging out of beacon that filter all of Proximity UUID
                  regions.add(
                    Region(
                      identifier: 'SolteamBLE01',
                      proximityUUID: '74278BDA-B644-4520-8F0C-720EAF059935',
                    ),
                  );
                }

                // to start monitoring beacons
                //_streamMonitoring = flutterBeacon.monitoring(regions).listen(
                _streamRanging = flutterBeacon.ranging(regions).listen((
                  result,
                ) {
                  //(RangingResult result) {
                  // result contains a region, event type and event state

                  if (result.beacons.isNotEmpty) {
                    isBeaconAlive += 1;
                    if(isBeaconAlive > 2)
                      isBeaconAlive = 2;
                    
                    if (isBeaconAlive==0) 
                    {
                    

                      showLockScreenNotification(
                        '你己進入Solteam 9F範圍',
                        '歡迎使用Solteam BLE Beacon服務',
                      );

                      setState(() {
                        beaconStatus +=
                            //'Monitoring Result: ${result.region}, ${result.monitoringEventType}, ${result.monitoringState}\n';
                            'Monitoring Result: ${result.region}, ${result.beacons}}\n';
                      });
                    }
                  }
                  else {
                    isBeaconAlive -= 1;
                    if(isBeaconAlive < -2)
                      isBeaconAlive = -2;

                    if (isBeaconAlive==0) 
                    {

                      showLockScreenNotification(
                        '你己離開Solteam 9F範圍',
                        'Bye Bye~',
                      );

                      setState(() {
                        beaconStatus +=
                            //'Monitoring Result: ${result.region}, ${result.monitoringEventType}, ${result.monitoringState}\n';
                            'No Beacon in Range\n';
                      });
                    }
                  }

                  
                });
              },
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.connected_tv, size: 32),
                  SizedBox(height: 4),
                  Text('beacon scan', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16), // 3. 在按鈕之間增加間距
          // --- 第4個按鈕 (connect) ---
          SizedBox(
            width: 80,
            height: 80,
            child: FloatingActionButton(
              heroTag: '4_button', // 2. 給予獨立的 heroTag
              onPressed: () {
                // to stop monitoring beacons
                _streamMonitoring?.cancel();
                _streamRanging?.cancel();
                print('Stop beacon monitoring');
              },
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.connected_tv, size: 32),
                  SizedBox(height: 4),
                  Text('beacon stop', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
      // 設定浮動按鈕的位置：底部中央
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 顯示beacon 掃描到的裝置資訊
            SizedBox(
              height: 150,
              child: TextField(
                controller: TextEditingController(text: beaconStatus),
                readOnly: true,
                maxLines: null,
                expands: true,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(),

                  contentPadding: const EdgeInsets.all(12.0),
                  fillColor: Colors.grey[200],
                  filled: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
