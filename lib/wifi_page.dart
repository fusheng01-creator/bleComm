import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:network_info_plus/network_info_plus.dart';

class WifiAppState extends ChangeNotifier {
  Socket? socket;
  bool isConnected = false;
  String log = '';
  String wifiIP = '';
  String wifiGatewayIP = '';

  void refreshUI() {
    notifyListeners();
  }
}

// 建立 TCP 連線範例
void connectToTcpServer(WifiAppState appState, String host, int port) async {
  try {
    appState.socket = await Socket.connect(
      host,
      port,
      timeout: Duration(seconds: 5),
    );
    print('已連線到 $host:$port');
    appState.log = '已連線到 $host:$port\n';
    appState.isConnected = true;
    appState.refreshUI();

    // 接收數據
    appState.socket!.listen(
      (List<int> data) {
        print('接收到數據: ${String.fromCharCodes(data)}');
        appState.log += String.fromCharCodes(data);
        appState.refreshUI();
      },
      onDone: () {
        print('連線關閉');
        appState.socket!.destroy();
        appState.isConnected = false;
      },
      onError: (error) {
        print('連線錯誤: $error');
        appState.socket!.destroy();
        appState.isConnected = false;
      },
    );
  } catch (e) {
    print('無法連線: $e');
  }
}

void disconnectFromTcpServer(WifiAppState appState) {
  if (appState.socket != null) {
    appState.socket!.destroy();
    appState.isConnected = false;
    print('已斷開連線');
  } else {
    print('沒有可斷開的連線');
  }
  appState.log = '已斷開連線\n';
  appState.refreshUI();
}

void sendDataToTcpServer(WifiAppState appState, String data) {
  if (appState.socket != null && appState.isConnected) {
    appState.socket!.write(data);
    print('已傳送數據: $data');
  } else {
    print('未連線到伺服器，無法傳送數據');
  }
}

class NetworkInfoFetcher {
  final NetworkInfo _networkInfo = NetworkInfo();

  Future<String> getWifiInfo(var appState) async {
    String result = '';
    String? wifiIP;
    String? wifiGatewayIP;

    try {
      // 1. 獲取設備的本地 IP (自己的 IP)
      wifiIP = await _networkInfo.getWifiIP();
      appState.wifiIP = wifiIP;

      // 2. 獲取 Wi-Fi 預設閘道器 IP (Gateway IP)
      wifiGatewayIP = await _networkInfo.getWifiGatewayIP();
      appState.wifiGatewayIP = wifiGatewayIP;
    } catch (e) {
      result = '獲取網路資訊時發生錯誤: $e';
      // 平台特定的錯誤處理，例如權限被拒絕等
    }

    result += '--- 網路資訊 ---\n';
    result += '設備本地 IP (自己的 IP): $wifiIP\n';
    result += 'Wi-Fi 閘道器 IP (Gateway IP): $wifiGatewayIP\n';
    result += '----------------';

    return result;
  }
}

class WifiPage extends StatefulWidget {
  @override
  State<WifiPage> createState() => _WifiPageState();
}

class _WifiPageState extends State<WifiPage> {
  String wifiInfo = '點擊按鈕以獲取網路資訊'; // 1. 將 wifiInfo 移至 State 中
  final TextEditingController TCPDataController =
      TextEditingController(text: 'AP_name: myAP, PassWord: 123456'); // 用於捕捉使用者輸入
  final TextEditingController MQTTSubTopicController =
      TextEditingController(text: '/devicesID/9527/voltage'); // 用於捕捉使用者輸入
  final TextEditingController MQTTPubTopicController =
      TextEditingController(text: '/devicesID/9527/FW'); // 用於捕捉使用者輸入
  final TextEditingController MQTTMessageController =
      TextEditingController(text: 'start to update FW'); // 用於捕捉使用者輸入

  @override
  Widget build(BuildContext context) {
    var wifiAppSate = context.watch<WifiAppState>(); // 監聽 WifiAppState 的變化

    return Column(
      children: [
        const Center(child: Text('WiFi Data Page')),
        const SizedBox(height: 20),
        ElevatedButton(
          child: const Text('獲取 WiFi 網路資訊'),
          onPressed: () async {
            // 2. 使用 setState 更新 UI
            final info = await NetworkInfoFetcher().getWifiInfo(wifiAppSate);
            setState(() {
              wifiInfo = info;
            });
          },
        ),

        SizedBox(width: 20),
        SizedBox(
          height: 100,
          child: TextField(
            controller: TextEditingController(text: wifiInfo),
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
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              child: const Text('連接TCP server'),
              onPressed: () {
                connectToTcpServer(wifiAppSate, wifiAppSate.wifiGatewayIP, 377);

                wifiAppSate.refreshUI();
              },
            ),
            SizedBox(
              width: 200,
              height: 50,
              child: TextField(
                controller: TextEditingController(
                  text: wifiAppSate.wifiGatewayIP,
                ),
                readOnly: true,
              ),
            ),
            ElevatedButton(
              child: const Text('斷開 TCP server'),
              onPressed: () {
                disconnectFromTcpServer(wifiAppSate);

                wifiAppSate.refreshUI();
              },
            ),
          ],
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [Text('TCP 接收data :')],
        ),

        SizedBox(
          height: 100,
          child: TextField(
            controller: TextEditingController(text: wifiAppSate.log),
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

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              child: const Text('傳送 TCP data : '),
              onPressed: () {
                sendDataToTcpServer(
                  wifiAppSate,
                  TCPDataController.text,
                );
                wifiAppSate.refreshUI();
              },
            ),
            SizedBox(
              width: 300,
              height: 50,
              child: TextField(
                controller: TextEditingController(
                  text: 'AP_name: myAP, PassWord: 123456',
                ),
                readOnly: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              child: const Text('連接 MQTT server : '),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("connect to server successfully"),
                  ),
                );
                wifiAppSate.refreshUI();
              },
            ),
            SizedBox(
              width: 200,
              height: 50,
              child: TextField(
                controller: TextEditingController(text: '10.128.128.81'),
                readOnly: true,
              ),
            ),
            ElevatedButton(
              child: const Text('斷開 MQTT server : '),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("disconnect from server")),
                );
                wifiAppSate.refreshUI();
              },
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              child: const Text('訂閱 MQTT topic: '),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("subscribe to topic successfully"),
                  ),
                );
                wifiAppSate.refreshUI();
              },
            ),
            SizedBox(
              width: 300,
              height: 50,
              child: TextField(
                controller: TextEditingController(
                  text: '/devicesID/9527/voltage',
                ),
                readOnly: false,
              ),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('電壓值 :'),
            SizedBox(
              width: 100,
              height: 50,
              child: TextField(
                textAlign: TextAlign.center,
                controller: TextEditingController(text: '??? V'),
                readOnly: true,
              ),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              child: const Text('發佈 MQTT message: '),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("subscribe to topic successfully"),
                  ),
                );
                wifiAppSate.refreshUI();
              },
            ),
            SizedBox(
              width: 160,
              height: 50,
              child: TextField(
                controller: TextEditingController(text: '/devicesID/9527/FW'),
                readOnly: false,
              ),
            ),
            const SizedBox(width: 20, height: 50),
            SizedBox(
              width: 150,
              height: 50,
              child: TextField(
                controller: TextEditingController(text: 'start to update FW'),
                readOnly: false,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
