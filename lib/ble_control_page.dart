import 'dart:async'; // 處理 Stream 和 Future
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart'; // 藍牙核心套件

// BLE 裝置控制頁面 (StatelessWidget)
class HomePage extends StatefulWidget {
  // 必須傳入的參數：
  final FlutterReactiveBle ble; // 藍牙實例，用於執行操作
  final String deviceId; // 已連接的裝置 ID
  final StreamSubscription<ConnectionStateUpdate> connection; // 連接狀態的訂閱流

  const HomePage({
    super.key,
    required this.ble,
    required this.deviceId,
    required this.connection,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // 狀態：儲存發現到的服務列表 (可為 null)
  List<Service>? services;
  // 狀態：追蹤服務是否正在載入
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    // 頁面啟動時，立即開始發現服務
    getServices();
  }
  
  // 頁面銷毀時，取消連接訂閱，進行資源清理
  @override
  void dispose() {
    widget.connection.cancel(); // 斷開連接並清理 Stream
    super.dispose();
  }

  // 🚀 發現已連接裝置的所有服務和特性
  Future<void> getServices() async {
    try {
      // 呼叫 discoverServices 來獲取服務列表
    //final serviceList = await widget.ble.discoverServices(widget.deviceId);
      // 1. 🚀 呼叫 discoverAllServices 啟動服務發現程序。
    //    我們必須等待它完成，以確保服務被發現。
    await widget.ble.discoverAllServices(widget.deviceId);

    // 2. ✅ 呼叫 getDiscoverServices 取得已發現的服務列表。
    //    這個方法是同步/快速的，因為它只是從套件的內部快取中獲取結果。
    final serviceList = await widget.ble.getDiscoveredServices(widget.deviceId);
      
      // 更新 UI 狀態：顯示服務列表並關閉載入指示器
      setState(() {
        services = serviceList;
        isLoading = false;
      });
    } catch (e) {
      // 處理服務發現失敗的錯誤，並停止載入
       setState(() {
        isLoading = false;
      });
      // 這裡可以加入 SnackBar 提示錯誤
    }
  }

  // 📝 彈出寫入數據的對話框
  void showWritePopup({
    required BuildContext context,
    required FlutterReactiveBle ble,
    required String deviceId,
    required Uuid serviceId,
    required Uuid characteristicId,
  }) {
    final TextEditingController controller = TextEditingController(); // 用於捕捉使用者輸入

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Write to Characteristic"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Enter hex (e.g. 01 02 FF)"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              final input = controller.text.trim();
              // 1. 將輸入字串 (例如 "01 02 FF") 拆分為列表
              // 2. 將每個元素從 16 進制 (radix: 16) 轉換為整數 (byte)
              final values = input
                  .split(RegExp(r'\s+')) // 依據空格或多個空格分割
                  .map((e) => int.parse(e, radix: 16)) // 解析 16 進制
                  .toList();
              
              try {
                // 執行無回應寫入操作 (通常用於不需要伺服器確認的快速寫入)
                await ble.writeCharacteristicWithoutResponse(
                  QualifiedCharacteristic( // 定位到特定的特性
                    deviceId: deviceId,
                    serviceId: serviceId,
                    characteristicId: characteristicId,
                  ),
                  value: values, // 寫入的 byte 列表
                );
                Navigator.pop(context); // 關閉彈窗
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Write successful")),
                );
              } catch (e) {
                // 寫入失敗處理
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Write failed: $e")),
                );
              }
            },
            child: const Text("Write"),
          ),
        ],
      ),
    );
  }

  // 🔨 構建 UI 介面
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // 頂部導航欄
        backgroundColor: Theme.of(context).colorScheme.secondary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('BLE Scanner', style: TextStyle(color: Colors.white)),
      ),
      // 頁面主體根據狀態顯示不同內容
      body: isLoading
          ? const Center(child: CircularProgressIndicator()) // 載入中
          : services!.isEmpty // services 已經載入，但列表為空
          ? const Center(child: Text("No services found")) // 未發現服務
          : ListView.builder( // 顯示服務列表
        itemCount: services?.length ?? 0,
        itemBuilder: (context, index) {
          final service = services![index];

          // 使用 ExpansionTile 顯示服務，點擊可展開特性列表
          return ExpansionTile(
            title: Text("Service: ${service.id.toString()}"),
            children: service.characteristics.map((char) {
              // 判斷特性是否可讀
              final canRead = char.isReadable;
              // 判斷特性是否可寫 (包含有無回應寫入)
              final canWrite = char.isWritableWithResponse || char.isWritableWithoutResponse;

              return ListTile(
                title: Text("Char: ${char.id}"),
                subtitle: Text("Read: $canRead | Write: $canWrite"),
                onTap: () async {
                  if (canWrite) {
                    // 點擊可寫入特性，彈出寫入視窗
                    showWritePopup(
                      context: context,
                      ble: widget.ble,
                      deviceId: widget.deviceId,
                      serviceId: service.id,
                      characteristicId: char.id,
                    );
                  } else if (canRead) {
                    // 點擊可讀取特性，執行讀取操作
                    try {
                      final result = await widget.ble.readCharacteristic(
                        QualifiedCharacteristic(
                          deviceId: widget.deviceId,
                          serviceId: service.id,
                          characteristicId: char.id,
                        ),
                      );
                      
                      // 轉換結果為 Hex 字串 (例如: 01 0a ff)
                      final hex = result
                          .map((e) => e.toRadixString(16).padLeft(2, '0'))
                          .join(' ')
                          .toUpperCase();
                      
                      // 轉換結果為 ASCII 字串
                      final stringValue = String.fromCharCodes(result);

                      // 顯示讀取結果
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Read Value hex: $hex , String : $stringValue")),
                      );
                    } catch (e) {
                      // 讀取失敗處理
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Read failed: $e")),
                      );
                    }
                  }
                },
              );
            }).toList(),
          );
        },
      ),
      // 側邊欄：用於斷開連接
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // 側邊欄標題/頭部
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary,
              ),
              child: const Column(
                children: [
                  Icon(Icons.manage_accounts, size: 64, color: Colors.white),
                  Text(
                    "Menu",
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                ],
              ),
            ),
            // 斷開連接按鈕
            ListTile(
              leading: const Icon(Icons.bluetooth_disabled),
              title: const Text('Disconnect'),
              onTap: () {
                widget.connection.cancel(); // 停止連接訂閱 (觸發斷開)
                Navigator.of(context).pop(); // 關閉側邊欄
                Navigator.of(context).pop(); // 返回上一個頁面 (ConnectPage)
              },
            ),
          ],
        ),
      ),
    );
  }
}