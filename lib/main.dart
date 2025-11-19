import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'ble_connect_page.dart';
import 'ble_data_page.dart';
import 'about_page.dart';
import 'ble_beacon_page.dart';

void main() {
  runApp(const MyApp());
}

enum AppTab { 
  PAGE_GENERATOR, 
  PAGE_FAVORITES,
  PAGE_BLE_DATA,
  PAGE_BLE_SCAN,
  PAGE_BLE_BEACON,
  PAGE_ABOUT,
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => MyAppState()),
        ChangeNotifierProvider(create: (context) => BleAppState()),

      ],
      child: MaterialApp(
        title: 'bleComm',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromARGB(199, 255, 0, 4),
            primary: Colors.red,
          ),
        ),
        home: MyHomePage(),
      ),
    );
  }

}

class MyAppState extends ChangeNotifier {
  
  AppTab pageSelectedIndex = AppTab.PAGE_ABOUT;
  String appBarName = 'bleComm';

  var current = WordPair.random();

  // ↓ Add this.

  void changePage(AppTab tab) {
    // Implement page change logic if needed
    pageSelectedIndex = tab;

    appBarName= 'bleComm -> ${tab.toString()}';

    notifyListeners();
  }

  void getNext() {
    current = WordPair.random();
    notifyListeners();
  }

  var favorites = <WordPair>[];
  void toggleFavorite() {
    if (favorites.contains(current)) {
      favorites.remove(current);
    } else {
      favorites.add(current);
    }
    notifyListeners();
  }

  // 新增：將導航欄的 open 狀態放在 App State 中
  bool open = false;
  void toggleNav() {
    open = !open;
    notifyListeners();
  }
}

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  

  

  @override
  void dispose() {

    //關閉頁面時，移除所有 BLE 裝置以釋放資源
    for(int i=BleGlobal.devices.length-1;i>=0;i--){
      BleGlobal.devices[i].removeFormList();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    var appState = context.watch<MyAppState>();
    var selectedIndex = appState.pageSelectedIndex;
    var appBarName = appState.appBarName;

    Widget page;
    switch (selectedIndex) {
      case AppTab.PAGE_GENERATOR:
        page = GeneratorPage();
        break;
      case AppTab.PAGE_BLE_DATA:
        page = BleDataPage();
        break;
      case AppTab.PAGE_FAVORITES:
        page = FavoritesPage();
        break;
      case AppTab.PAGE_BLE_SCAN:
        page = ConnectPage();
        break;
      case AppTab.PAGE_ABOUT:
        page = AboutPage();
        break;
      case AppTab.PAGE_BLE_BEACON:
        page = BeaconPage();
        break;
      
    }

    // ...
    return Scaffold(
      appBar: AppBar(
        title: Text(appBarName),
      ),
      body: page,
      drawer: NavigationDrawer(
        //新增：導航欄
        children: [
          DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary,
              ),
              child: const Column(
                children: [
                  Icon(Icons.manage_accounts, size: 64, color: Colors.white),
                  Text(
                    "bleComm Menu",
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                ],
              ),
            ),
          ListTile(
            title: Text('About'),
            leading: Icon(Icons.home),
            selected: selectedIndex == AppTab.PAGE_ABOUT,
            onTap: () {
              setState(() {
                appState.changePage(AppTab.PAGE_ABOUT);
                
              });
              Navigator.pop(context); // 關閉抽屜
            },
          ),
          ListTile(
            title: Text('BLE Data'),
            leading: Icon(Icons.data_thresholding_outlined),
            selected: selectedIndex == AppTab.PAGE_BLE_DATA,
            onTap: () {
              setState(() {
                appState.changePage(AppTab.PAGE_BLE_DATA);
                
              });
              Navigator.pop(context); // 關閉抽屜
            },
          ),
          ListTile(
            title: Text('BLE Scan'),
            leading: Icon(Icons.bluetooth),
            selected: selectedIndex == AppTab.PAGE_BLE_SCAN,
            onTap: () {
              setState(() {
                appState.changePage(AppTab.PAGE_BLE_SCAN);
                
              });
              Navigator.pop(context); // 關閉抽屜
            },
          ),
          ListTile(
            title: Text('BLE Beacon'),
            leading: Icon(Icons.light_mode_outlined),
            selected: selectedIndex == AppTab.PAGE_BLE_BEACON,
            onTap: () {
              setState(() {
                appState.changePage(AppTab.PAGE_BLE_BEACON);
                
              });
              Navigator.pop(context); // 關閉抽屜
            },
          ),
        ],
      ),
    );
  }
}
// ...

class FavoritesPage extends StatelessWidget {
  // 💡 函數：顯示一個 SnackBar 訊息

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    if (appState.favorites.isEmpty) {
      return Center(child: Text('No favorites yet.'));
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: 200,
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'You have '
                  '${appState.favorites.length} favorites:',
                ),
              ),
              for (var pair in appState.favorites)
                ListTile(
                  leading: Icon(Icons.favorite),
                  title: Text(pair.first + " " + pair.second),
                  onTap: () {
                    showSnackbar(
                      context,
                      'YAY: You tapped on ${pair.asLowerCase},index=${appState.favorites.indexOf(pair)}',
                    );                    
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class GeneratorPage extends StatelessWidget {
  const GeneratorPage({super.key});

  @override
  Widget build(BuildContext context) {
    //每个 widget 均定义了一个 build() 方法，每当 widget 的环境发生变化时，系统都会自动调用该方法，以便 widget 始终保持最新状态。
    var appState = context
        .watch<MyAppState>(); //MyHomePage 使用 watch 方法跟踪对应用当前状态的更改
    var pair = appState.current;

    IconData icon;
    if (appState.favorites.contains(pair)) {
      icon = Icons.favorite;
    } else {
      icon = Icons.favorite_border;
    }

    return Center(
      //每个 build 方法都必须返回一个 widget 或（更常见的）嵌套 widget 树。在本例中，顶层 widget 是 Scaffold。您不会在此 Codelab 中使用 Scaffold，但它是一个有用的 widget。在绝大多数真实的 Flutter 应用中都可以找到该 widget。
      child: Column(
        //Column 是 Flutter 中最基础的布局 widget 之一。它接受任意数量的子项并将这些子项从上到下放在一列中。默认情况下，该列会以可视化形式将其子项置于顶部。您很快就会对其进行更改，使该列居中
        mainAxisAlignment: MainAxisAlignment.center, //置中
        children: [
          const Text('A random idea or not:'),
          BigCard(
            pair: pair,
          ), //第二个 Text widget 接受 appState，并访问该类的唯一成员 current（这是一个 WordPair）。WordPair 提供了一些有用的 getter，例如 asPascalCase 或 asSnakeCase。此处，我们使用了 asLowerCase。但如果您希望选择其他选项，您现在可以对其进行更改。

          const SizedBox(height: 10),

          // ↓ Add this.
          Row(
            //mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,

            children: [
              ElevatedButton.icon(
                onPressed: () {
                  //print('button pressed!');
                  appState.toggleFavorite();
                },
                icon: Icon(icon),
                label: const Text("Like"),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  //print('button pressed!');
                  appState.getNext();
                  //appState.toggleNav();
                },
                child: const Text('Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class BigCard extends StatelessWidget {
  const BigCard({super.key, required this.pair});

  final WordPair pair;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.displayMedium!.copyWith(
      color: theme.colorScheme.onPrimary,
    );

    return Card(
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Text(pair.asLowerCase, style: style),
      ),
    );
  }
}

// ✅ 正確做法：獨立函數，將 BuildContext 作為參數傳入
void showSnackbar(BuildContext context, String message) {
  // 獨立函數中無法使用 mounted，但由於 context 是從 build 函數傳入的，通常是安全的。
  // 如果您需要確保安全，可以將此邏輯保留在 State 類別中，或在呼叫處確保 context 有效。

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 2),
      action: SnackBarAction(label: 'OK', onPressed: () {}),
    ),
  );
}
