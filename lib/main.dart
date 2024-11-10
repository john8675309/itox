import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'libtox_bindings.dart';
import 'screens/home_screen.dart';
import 'screens/add_friend_screen.dart';
import 'screens/settings_screen.dart';
import 'package:itox/tox/db_bindings.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    // Initialize database factory for desktop platforms
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const ToxApp());
}

class ToxApp extends StatelessWidget {
  const ToxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tox Messenger',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  late Future<void> _initToxFuture; // Store the initialization Future
  late Pointer<Tox> toxInstance;
  String? myToxID;
  Map<int, Friend> friends = {};

  @override
  void initState() {
    super.initState();
    _initToxFuture = initTox(); // Assign the initialization Future
  }

  Future<void> initTox() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      //prefs.remove("friends");
      print('Initializing Tox...');
      toxInstance = await createToxInstance();
      print('Tox instance initialized: $toxInstance');

      myToxID = extractToxID(getToxID(toxInstance));
      print('Your Tox ID: $myToxID');

      bootstrapToxNetwork(toxInstance);
      registerMessageCallback(toxInstance);
      loadFriends(prefs);

      runToxEventLoop(toxInstance, updateStatuses);
      setStatusOnline(toxInstance);
      printFriendList(toxInstance);
    } catch (e) {
      print('Error initializing Tox: $e');
      if (mounted) {
        Future.delayed(Duration.zero, () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to initialize Tox: $e')),
          );
        });
      }
    }
  }

  void updateStatuses() {
    setState(() {
      for (final entry in friends.entries) {
        final friendNumber = entry.key;
        final status = getConnectionStatus(toxInstance, friendNumber);
        friends[friendNumber]?.status = status;
      }
    });
  }

  void loadFriends(SharedPreferences prefs) {
    final savedFriendsJson = prefs.getString('friends');
    if (savedFriendsJson != null) {
      try {
        final savedFriendsList = jsonDecode(savedFriendsJson) as List<dynamic>;
        for (var json in savedFriendsList) {
          final friend = Friend.fromJson(json);
          friends[friend.friendNumber] = friend;
          print('Loaded Friend: ${friend.toJson()}');
        }
        print('Friends Loaded: $friends');
      } catch (e) {
        print('Error parsing saved friends: $e');
      }
    } else {
      print('No saved friends found.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initToxFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        } else {
          final List<Widget> _pages = [
            HomeScreen(toxInstance: toxInstance, friends: friends),
            AddFriendScreen(toxInstance: toxInstance, friends: friends),
            SettingsScreen(),
          ];
          final titles = ['Chats', 'Add Friend', 'Settings'];

          return Scaffold(
            appBar: AppBar(
              title: Text(titles[_currentIndex]),
            ),
            body: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              children: _pages,
            ),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
                _pageController.jumpToPage(index);
              },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.chat),
                  label: 'Chats',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_add),
                  label: 'Add Friend',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          );
        }
      },
    );
  }
}
