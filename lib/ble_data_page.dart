// 匯入非同步操作所需的庫 (例如 Stream, Future)
import 'dart:async';
// 匯入用於平台判斷的 I/O 庫 (例如判斷 Android 或 iOS)
//import 'dart:io';

// 匯入 Flutter UI 框架的核心庫
import 'package:flutter/material.dart';
// 匯入處理 BLE (藍牙低功耗) 操作的套件
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
// 匯入狀態管理套件 Provider
import 'package:provider/provider.dart';

import 'main.dart';

// 全域的 BLE 實例，方便在不同頁面中使用
class BleGlobal {
  // 實例化 flutter_reactive_ble 物件，用於所有 BLE 操作
  static FlutterReactiveBle ble = FlutterReactiveBle();
  static List<MyBleDevice> devices = [];
}

class BleAppState extends ChangeNotifier {
  void refreshBleUI() {
    notifyListeners();
  }
}

class MyBleDevice {
  //本device的macId和name和連接訂閱
  final String macId;
  final String name;
  //連接訂閱
  StreamSubscription<ConnectionStateUpdate>? connection;
  StreamSubscription<List<int>>? dataSubscription;

  // 假設 characteristicUuid 和 serviceUuid 已知
  final serviceUuid = Uuid.parse("0000ffe0-0000-1000-8000-00805f9b34fb");
  final characteristicUuid = Uuid.parse("0000ffe1-0000-1000-8000-00805f9b34fb");

  //外部傳入的 ble 物件和設備列表
  final FlutterReactiveBle ble; // 1. 改為 final 且 non-nullable
  List<MyBleDevice>? devices;
  BleAppState? bleState;

  //device其他狀態

  bool isConnected = false;
  String log = '';

  ScrollController scrollController = ScrollController();

  MyBleDevice({
    required this.macId,
    required this.name,
    required this.ble,
    required List<MyBleDevice> this.devices,
    required BleAppState this.bleState,
  });

  void connect() async {
    if (isConnected) {
      writeLog('Already connected to $name+\n');
      return;
    }

    //ble.clearGattCache(macId); // 常會exception,暫時註解
    
    // 🎯 關鍵步驟：訂閱連接狀態變更的 Stream
    connection = ble
        // connectToDevice 返回一個連接狀態的 Stream
        .connectToDevice(id: macId)
        .listen(
          // 處理連接狀態的更新
          (connectionState) {
            writeLog(
              'Device: $name, State: ${connectionState.connectionState}',
            );

            // 如果連接狀態變為 'connected' (已連接)
            if (connectionState.connectionState ==
                DeviceConnectionState.connected) {
              // 導航到下一個頁面 (HomePage/ble_control_page)
              writeLog('connected to $name');

              isConnected = true;

              if (isConnected) {
                // 🎯 關鍵步驟：取消舊的訂閱，避免資源洩漏
                dataSubscription?.cancel();

                // 呼叫 subscribeToCharacteristic 函式並訂閱 Stream
                dataSubscription = ble.subscribeToCharacteristic(
                      QualifiedCharacteristic(
                        characteristicId: characteristicUuid,
                        serviceId: serviceUuid,
                        deviceId: macId,
                      ),
                    )
                    .listen(
                      (data) {
                        // 收到通知數據時的回調

                        // 將 List<int> 轉換為 Hex String 以方便顯示
                        String hexString = data
                            .map((b) => b.toRadixString(16).padLeft(2, '0'))
                            .join(' ');

                        writeLog('notified from $name:$hexString');
                      },
                      onError: (dynamic error) {
                        // 處理訂閱錯誤 (例如連線中斷)
                        writeLog('通知訂閱錯誤: $error');
                        dataSubscription = null;
                        // 在錯誤發生時，可能需要執行重連或通知 UI
                      },
                      onDone: () {
                        // Stream 完成 (通常發生在連線中斷)
                        writeLog('通知訂閱完成 (連線可能斷開)');
                        dataSubscription = null;
                      },
                    );
              }
            } else if (connectionState.connectionState ==
                DeviceConnectionState.disconnected) {
              writeLog('disconnected from $name');
              isConnected = false;
            }
          },
          // 連接錯誤處理
          onError: (e) {
            writeLog('Connection error: $e');
            isConnected = false;
          },
        );
  }

  void disConnect() async {
    // 🎯 關鍵步驟：取消訂閱以斷開連接
    if (isConnected == true) {
      try {
        dataSubscription?.cancel();
        
      } catch (e) {
        writeLog('error: $e');
      }
    }
    await connection?.cancel();
    writeLog('disconnected from $name');
    isConnected = false;
  }

  void writeLog(String newLog) {
    log += '$newLog\n';
    // 自動滾動到最底部
    try {
      //WidgetsBinding.instance.addPostFrameCallback((_) {
        //移動游標的方式無效...
        //textController.selection = TextSelection.fromPosition(
        //  TextPosition(offset: log.length),
        //);
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      //});
    } catch (e) {}

    bleState?.refreshBleUI();
  }

  void removeFormList() {
    // 🎯 關鍵步驟：移除device時，確保訂閱被取消
    disConnect();

    print('Removing device $name from list');
    // 從設備列表中移除當前設備
    devices?.removeWhere((d) => d.macId == macId);
  }

  Future<void> writeCharacteristicWithoutResponse(List<int> values) async {
    if (isConnected) {
      await ble.writeCharacteristicWithoutResponse(
        QualifiedCharacteristic(
          characteristicId: characteristicUuid,
          serviceId: serviceUuid,
          deviceId: macId,
        ),
        value: values,
      );
      String hexValues = values
          .map((e) => e.toRadixString(16).padLeft(2, '0'))
          .join(' ');
      writeLog('Write to $name: $hexValues');
    }
  }
}

class BleDataPage extends StatefulWidget {
  const BleDataPage({super.key});

  @override
  State<BleDataPage> createState() => _BleDataPageState();
}

class _BleDataPageState extends State<BleDataPage> {
  final FlutterReactiveBle ble = FlutterReactiveBle();

  @override
  Widget build(BuildContext context) {
    var bleState = context.watch<BleAppState>();
    final TextEditingController controller =
        TextEditingController(); // 用於捕捉使用者輸入
    ScrollController scrollController = ScrollController();

    return Scaffold(
      // 2. 使用 SingleChildScrollView 讓內容超出螢幕時可以滾動
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: SizedBox(
                height: 40.0,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          hintText: "Enter hex (e.g. 01 02 FF)",
                        ),
                      ),
                    ),

                    ElevatedButton(
                      child: const Text("Send to All"),
                      onPressed: () async {
                        final input = controller.text.trim();
                        // 1. 將輸入字串 (例如 "01 02 FF") 拆分為列表
                        // 2. 將每個元素從 16 進制 (radix: 16) 轉換為整數 (byte)

                        var values = null;
                        try {
                          values = input
                              .split(RegExp(r'\s+')) // 依據空格或多個空格分割
                              .map((e) => int.parse(e, radix: 16)) // 解析 16 進制
                              .toList();
                        } catch (e) {};

                        showConfirmationDialog(context);


                        for (MyBleDevice device in BleGlobal.devices) {
                          if (device.isConnected) {
                            try {
                              await device.writeCharacteristicWithoutResponse(
                                values,
                              );

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Write successful"),
                                ),
                              );
                            } catch (e) {
                              // 寫入失敗處理

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Write failed: $e")),
                              );
                            }
                          }
                        }
                      },
                    ),
                  ],
                ), // 頂部間距
              ),
            ),
            //使用 for 迴圈動態建立多個 Widget
            for (int i = 0; i < BleGlobal.devices.length; i++) // 增加到 ? 個來展示滾動效果
              Padding(
                // 調整 padding 讓每個 item 之間都有間隔
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
                child: SizedBox(
                  height: 150, // 稍微降低高度以便觀察
                  child: TextField(
                    //利用索引 i 讓每個 TextField 的內容不同
                    controller: TextEditingController(
                      text: BleGlobal.devices[i].log,
                    ),
                    scrollController: BleGlobal.devices[i].scrollController,
                    readOnly: true,
                    maxLines: null,
                    expands: true,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.all(12.0),
                      fillColor: Colors.grey[200],
                      filled: true,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> showConfirmationDialog(BuildContext context) async {
  return showDialog<void>(
    context: context,
    // 使用者點擊對話框外不會關閉它 (強制互動)
    barrierDismissible: false, 
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('重要確認'),
        content: const SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Text('您確定要永久刪除此項目嗎？'),
              Text('此操作無法撤銷。'),
            ],
          ),
        ),
        actions: <Widget>[
          // 取消按鈕
          TextButton(
            child: const Text('取消'),
            onPressed: () {
              Navigator.of(context).pop(); // 關閉對話框
              print('用戶取消了操作');
            },
          ),
          // 確定/刪除按鈕
          TextButton(
            child: const Text('刪除', style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.of(context).pop(); // 關閉對話框
              print('用戶確認刪除！');
              // 執行刪除操作
            },
          ),
        ],
      );
    },
  );
}


