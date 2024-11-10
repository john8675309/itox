import 'dart:ffi';
import 'package:flutter/material.dart';
import 'package:itox/libtox_bindings.dart';
import 'package:itox/screens/chat_screen.dart';

class HomeScreen extends StatelessWidget {
  final Map<int, Friend> friends; // Friend list
  final Pointer<Tox> toxInstance;

  const HomeScreen(
      {super.key, required this.friends, required this.toxInstance});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: friends.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, color: Colors.grey),
      itemBuilder: (context, index) {
        final friendNumber = friends.keys.elementAt(index);
        final friend = friends[friendNumber];

        return ListTile(
          title: Text(
            friend?.alias.isNotEmpty == true
                ? friend!.alias
                : 'Friend $friendNumber',
          ),
          subtitle: Text('Status: ${friend?.status ?? "Unknown"}'),
          leading: const Icon(Icons.person),
          trailing:
              const Icon(Icons.arrow_forward_ios, size: 16), // Right arrow
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ChatScreen(toxInstance: toxInstance, friend: friend),
              ),
            );
          },
        );
      },
    );
  }
}
