// 匯入非同步操作所需的庫 (例如 Stream, Future)
import 'dart:async';
// 匯入用於平台判斷的 I/O 庫 (例如判斷 Android 或 iOS)
import 'dart:io';

// 匯入 Flutter UI 框架的核心庫
import 'package:flutter/material.dart';
// 匯入處理 BLE (藍牙低功耗) 操作的套件
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
// 匯入用於請求和檢查權限的套件
import 'package:permission_handler/permission_handler.dart';
// 匯入狀態管理套件 Provider
import 'package:provider/provider.dart';

// 匯入同專案內用於控制已連接裝置的頁面 (目標頁面名為 HomePage，推測原檔名是 ble_control_page.dart)
//import 'ble_control_page.dart'; // 假定此檔案內定義了 HomePage 類別
import 'ble_data_page.dart';
import 'main.dart';

// 裝置連接頁面 - 作為一個 Stateful Widget
class ConnectPage extends StatefulWidget {
  const ConnectPage({super.key});

  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

// 裝置連接頁面的狀態類別
class _ConnectPageState extends State<ConnectPage> {
  // 用於儲存掃描到的藍牙裝置列表
  List<DiscoveredDevice> discoverdDevices = [];
  // 儲存藍牙掃描的訂閱流，以便隨時停止或取消
  StreamSubscription<DiscoveredDevice>? scanSubscription;
  // 追蹤當前是否正在掃描的狀態旗標
  bool isScanning = false;
  
  // 新增：用於自動停止掃描的計時器
  Timer? _scanTimer;

  List<String> selectedDeviceID = [];



  // 狀態初始化時調用
  @override
  void initState() {
    super.initState();
    // 進入頁面時，首先檢查並請求藍牙所需權限
    checkAndRequestBluetoothPermissions();
  }

  // 頁面銷毀時調用，用於資源清理
  @override
  void dispose() {
    // 確保在銷毀前停止所有正在進行的掃描
    stopScan();
    // 取消連接訂閱，釋放資源 (雖然在 connectToDevice 中連接成功後會導航走，但清理是好習慣)
    // 新增：取消計時器，防止在頁面銷毀後還執行
    _scanTimer?.cancel();

    

    super.dispose();
  }

  // 🚀 檢查和請求藍牙權限
  Future<bool> checkAndRequestBluetoothPermissions() async {
    // 判斷是否為 Android 平台
    if (Platform.isAndroid) {
      // 請求 BLUETOOTH_SCAN 權限 (Android 12+)
      final bluetoothScanStatus = await Permission.bluetoothScan.request();
      // 請求 BLUETOOTH_CONNECT 權限 (Android 12+)
      final bluetoothConnectStatus = await Permission.bluetoothConnect
          .request();
      // 請求 LOCATION 權限 (Android 11 及以下版本掃描 BLE 需要)
      final locationStatus = await Permission.location.request();

      // 如果任一關鍵權限未被授予，返回 false
      if (bluetoothScanStatus != PermissionStatus.granted ||
          bluetoothConnectStatus != PermissionStatus.granted ||
          locationStatus != PermissionStatus.granted) {
        return false; // 權限未授予
      }
      // 判斷是否為 iOS 平台
    } else if (Platform.isIOS) {
      // 請求 BLUETOOTH 權限
      final bluetoothStatus = await Permission.bluetooth.request();

      // 如果權限未被授予，返回 false
      if (bluetoothStatus != PermissionStatus.granted) {
        return false; // 權限未授予
      }
    }
    return true; // 所有權限已授予
  }

  // 📡 開始掃描 BLE 裝置的函數
  Future<void> scanBleDevices() async {
    // 停止任何先前的掃描訂閱
    await scanSubscription?.cancel();
    scanSubscription = null;

    // 更新 UI 狀態：清空裝置列表並設定正在掃描的旗標為 true
    setState(() {
      discoverdDevices.clear();
      isScanning = true;
    });

    // 啟動藍牙掃描
    scanSubscription = BleGlobal.ble
        // scanForDevices 啟動掃描流
        .scanForDevices(withServices: [], scanMode: ScanMode.lowLatency)
        .listen(
          // 處理掃描到的每個裝置
          (device) {
            // 檢查裝置 ID 是否已存在於列表中，避免重複添加
            if (discoverdDevices.every((d) => d.id != device.id)) {
              // 更新 UI 狀態：將新裝置加入列表
              if (device.name.isNotEmpty) {
                setState(() => discoverdDevices.add(device));
              }
            } else {
              // 如果裝置已存在，更新其 RSSI 值
              setState(() {
                final index = discoverdDevices.indexWhere((d) => d.id == device.id);
                if (index != -1) {
                  discoverdDevices[index] = device;
                }
              });
            }
          },
          // 掃描完成時的回調 (通常不會發生，除非手動停止)
          onDone: () {},
          // 掃描過程中發生錯誤時的回調
          onError: (error) {
            // 停止掃描並處理錯誤
            print('Scan error: $error');
            stopScan();
          },
        );

    // 2. 啟動一個 10 秒的計時器，時間到就停止掃描
    _scanTimer = Timer(const Duration(seconds: 10), () {
      print("Scan stopped automatically after 10 seconds.");
      stopScan();
    });
  }

  // 停止藍牙掃描的函數
  Future<void> stopScan() async {
    // 取消掃描訂閱流
    await scanSubscription?.cancel();
    scanSubscription = null;
    // 3. 取消計時器，因為掃描已經被手動停止了
    _scanTimer?.cancel();
    // 更新 UI 狀態，確保 isScanning 被設為 false
    if (mounted) {
      // 檢查 widget 是否還在樹中
      setState(() {
        isScanning = false;
      });
    }
  }

  // 控制掃描流程的主函數 (處理重啟掃描的邏輯)
  Future<void> startScan() async {
    // 如果當前正在掃描
    //if (isScanning) {
      print("Restarting scan...");
      // 先停止當前的掃描
      await stopScan();
      // 延遲 1 秒，確保 BLE 晶片有時間重設狀態
      await Future.delayed(const Duration(seconds: 1));
    //}
    // 呼叫實際的掃描函數
    scanBleDevices();
  }
  /*
  void disconnectFromDevice() async {
    // 取消連接訂閱，終止連接
    await connection?.cancel();
    print('Disconnected from device');
    connection = null;
  }
  // 🔗 連接到特定 BLE 裝置的函數
  void connectToDevice(MyBleDevice device) async {
    // 啟動連接流程
    connection = BleGlobal.ble
        // connectToDevice 返回一個連接狀態的 Stream
        .connectToDevice(id: device.macId)
        .listen(
          // 處理連接狀態的更新
          (connectionState) {
            print(
              'Device: ${device.name}, State: ${connectionState.connectionState}',
            );

            // 如果連接狀態變為 'connected' (已連接)
            if (connectionState.connectionState ==
                DeviceConnectionState.connected) {
              // 導航到下一個頁面 (HomePage/ble_control_page)
              print('connected to ${device.name}');
            }
          },
          // 連接錯誤處理
          onError: (e) {
            print('Connection error: $e');
          },
        );
  }
  */


  // 🔨 構建 UI 介面
  @override
  Widget build(BuildContext context) {

    var mainAppState=context.read <MyAppState>();
    var bleAppState=context.read <BleAppState>();

    return Scaffold(
      // 1. 將 floatingActionButton 指向一個 Row Widget
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.center, // 讓按鈕靠右對齊
        children: [
          // --- 第一個按鈕 (Scan) ---
          SizedBox(
            width: 80,
            height: 80,
            child: FloatingActionButton(
              heroTag: 'scan_button', // 2. 給予獨立的 heroTag
              onPressed: () {
                startScan();
              },
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bluetooth_audio_rounded, size: 32),
                  SizedBox(height: 4),
                  Text('Scan', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16), // 3. 在按鈕之間增加間距
          // --- 第二個按鈕 (connect) ---
          SizedBox(
            width: 80,
            height: 80,
            child: FloatingActionButton(
              heroTag: 'connect_button', // 2. 給予獨立的 heroTag
              onPressed: () {
                mainAppState.changePage(AppTab.PAGE_BLE_DATA);
                stopScan();
                for(var device in BleGlobal.devices){
                  device.connect();                
                }
              },
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.connected_tv, size: 32),
                  SizedBox(height: 4),
                  Text('Connect', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
      // 設定浮動按鈕的位置：底部中央
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      // 頁面主體：使用 ListView.builder 構建可滾動的裝置列表
      body: SingleChildScrollView (
        child: Column(
          children: [
        
            //注意:在for(device in devices)中直接remove device會導致錯誤,
            //必須使用倒序迴圈或複製另一份list來操作,才不會造成index錯誤
            //for (var device in BleGlobal.devices)            
            for (int i=BleGlobal.devices.length-1;i>=0;i--)
              ListTile(
                // 裝置名稱，如果名稱為空則顯示 'Unknown'
                title: Text(BleGlobal.devices[i].name.isNotEmpty ? BleGlobal.devices[i].name : "Unknown"),
                // 裝置 ID (通常是 MAC 地址或 UUID)
                subtitle: Text('MAC:${BleGlobal.devices[i].macId}\t\t state: ${BleGlobal.devices[i].isConnected ? "Connected" : "Disconnected"}'),
        
                tileColor: Colors.pink.shade100,
                    
                onTap: () {
                  setState(() { 
                    BleGlobal.devices[i].removeFormList();              
                  });
                },
              ),
        
            for (var device in discoverdDevices)
              if(BleGlobal.devices.every((d) => d.macId != device.id))
                ListTile(
                  // 裝置名稱，如果名稱為空則顯示 'Unknown'
                  title: Text(device.name.isNotEmpty ? device.name : "Unknown"),
                  // 裝置 ID (通常是 MAC 地址或 UUID)
                  subtitle: Text('MAC:${device.id}\t\tRSSI: ${device.rssi} dBm'),
        
                  tileColor: Colors.white,
                  onTap: () {
                    setState(() {                    
                        BleGlobal.devices.add(
                          MyBleDevice(macId: device.id, name: device.name, ble: BleGlobal.ble, devices: BleGlobal.devices, bleState: bleAppState),
                        );
                      }
                    );
                  },
                ),
          ],
        ),
      ),
      /*
      ListView.builder(
        // 列表項目的數量等於掃描到的裝置數量
        itemCount: devices.length,
        itemBuilder: ((context, index) {
          final device = devices[index];
          // 列表項：顯示裝置名稱和 ID
          return ListTile(
            // 裝置名稱，如果名稱為空則顯示 'Unknown'
            title: Text(device.name.isNotEmpty ? device.name : "Unknown"),
            // 裝置 ID (通常是 MAC 地址或 UUID)
            subtitle: Text('MAC:${device.id}\t\tRSSI: ${device.rssi} dBm'),
            
            tileColor: BleGlobal.devices.any((d) => d.macId == device.id)
                ? Colors.pink.shade100
                : Colors.white,
            onTap: () {
              setState(() {
                if (BleGlobal.devices.any((d) => d.macId == device.id)) {
                  
                  BleGlobal.devices.removeWhere((d) => d.macId == device.id);
                } 
                else {                  
                  BleGlobal.devices.add(
                      MyBleDevice(macId: device.id, name: device.name));
                  
                }
              });
            },

          );
        }),
      ),
      */
    );
  }
}
