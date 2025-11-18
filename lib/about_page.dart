// 匯入 Flutter UI 框架的核心庫
import 'package:flutter/material.dart';

// 引入 service 庫，用於讀取資產
import 'package:flutter/services.dart' show rootBundle;

class AboutPage extends StatefulWidget {
  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _fileContent = "正在載入文字...";
  final String _assetPath = 'LICENSE'; // 步驟一設定的路徑

  @override
  void initState() {
    super.initState();
    _loadAssetFile();
  }

  // 異步讀取文字檔內容的函數
  Future<void> _loadAssetFile() async {
    try {
      // 使用 rootBundle 載入指定路徑的文字檔
      final String content = await rootBundle.loadString(_assetPath);

      // 使用 setState 更新 UI
      setState(() {
        _fileContent = content;
      });
    } catch (e) {
      setState(() {
        _fileContent = "載入文字檔失敗: $e";
      });
      print('載入文字檔發生錯誤: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('About')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BLE Communication App',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('Version: 1.0.0', style: TextStyle(fontSize: 16)),
              SizedBox(height: 16),
              Text(
                'This app allows you to communicate with BLE devices, read and write data, and visualize the information in real-time.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              Text('$_fileContent', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}
