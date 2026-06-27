import 'package:flutter/material.dart' hide MenuItem;
import 'dart:io';

import 'package:window_manager/window_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '_backend_conn.dart' show Message, connProvider;

import '_search_page.dart' show SearchPage;
import '_settings_page.dart' show SettingsPage;
import '_edit_page.dart' show TagEditPage;

import 'package:tray_manager/tray_manager.dart';
import 'package:fvp/fvp.dart' as fvp;

Future<void> setupTray(ProviderContainer container) async {
  final iconPath = Platform.isWindows
      ? 'assets/kaimen.ico'
      : 'assets/kaimen.png';

  await trayManager.setIcon(iconPath);
  if (!Platform.isLinux) {
    await trayManager.setToolTip('Kaimen');
  }
  Menu menu = Menu(
    items: [
      MenuItem(key: 'show_results', label: 'Open Search Results'),
      MenuItem.separator(),
      MenuItem(key: 'open_window', label: 'Open Window'),
      MenuItem.separator(),
      MenuItem(key: 'exit_app', label: 'Exit App'),
    ],
  );
  await trayManager.setContextMenu(menu);
  trayManager.addListener(MyTrayListener(container));
}

class MyTrayListener extends TrayListener {
  final ProviderContainer container;

  MyTrayListener(this.container);

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
  }

  @override
  void onTrayIconRightMouseDown() {
    // 1. Force the app to take focus from the taskbar/shell
    windowManager.focus().then((_) {
      // 2. Now show the menu
      trayManager.popUpContextMenu();
    });
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show_results') {
      final connAsync = container.read(connProvider);

      connAsync.whenData((c) {
        c.send(Message.openresults, '');
      });
    } else if (menuItem.key == 'open_window') {
      windowManager.show();
    } else if (menuItem.key == 'exit_app') {
      final connAsync = container.read(connProvider);

      connAsync.whenData((c) {
        c.send(Message.kill, '');
      });
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();
  await windowManager.setPreventClose(true);

  fvp.registerWith();

  final container = ProviderContainer();
  container.listen(connProvider, (_, __) {});

  await setupTray(container);

  WindowOptions windowOptions = WindowOptions(
    size: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {});

  runApp(ProviderScope(child: const UI()));
}

class UI extends StatefulWidget {
  const UI({super.key});

  @override
  State<UI> createState() => _UIState();
}

class _UIState extends State<UI> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    windowManager.hide();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        Widget page;
        switch (settings.name) {
          case '/':
            page = const SearchPage(title: 'Search Page');
            break;
          case '/settings':
            page = SettingsPage();
            break;
          case '/tagedit':
            page = TagEditPage();
            break;
          default:
            return null;
        }

        return PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          //transitionDuration: Duration.zero,
          //reverseTransitionDuration: Duration.zero,
        );
      },
    );
  }
}
