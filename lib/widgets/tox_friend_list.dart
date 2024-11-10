import 'package:flutter/material.dart';

class ToxFriendList extends StatelessWidget {
  final List<Map<String, String>> friends;

  ToxFriendList({required this.friends});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: friends.length,
      itemBuilder: (context, index) {
        final friend = friends[index];
        return ListTile(
          title: Text(friend['alias'] ?? 'Unknown Friend'),
          subtitle: Text(friend['status'] ?? 'Unknown Status'),
          onTap: () {
            // Navigate to chat screen or perform an action
          },
        );
      },
    );
  }
}
