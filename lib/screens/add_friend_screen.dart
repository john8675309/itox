import 'dart:convert';
import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:itox/libtox_bindings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddFriendScreen extends StatefulWidget {
  final Pointer<Tox> toxInstance;
  final Map<int, Friend> friends; // Shared friend list

  const AddFriendScreen({
    super.key,
    required this.toxInstance,
    required this.friends,
  });

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final TextEditingController friendIdController = TextEditingController();

  void addToxFriend() async {
    final friendId = friendIdController.text.trim();
    const friendMessage = "Hello from iTox!";

    // Validate Tox ID
    if (friendId.length != 76 ||
        !RegExp(r'^[0-9a-fA-F]{76}$').hasMatch(friendId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Invalid Tox ID. Please enter a valid 76-character hexadecimal string.',
          ),
        ),
      );
      return;
    }

    try {
      // Add friend using Tox
      final result = addFriend(widget.toxInstance, friendId, friendMessage);

      if (result >= 0) {
        // Add to the friends map
        widget.friends[result] = Friend(
          toxId: friendId,
          friendNumber: result,
          alias: 'New Friend', // Default alias
        );

        // Save updated friends list
        await saveFriends();

        // Notify user of success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend added successfully!')),
        );

        // Clear input field
        friendIdController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add friend')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding friend: $e')),
      );
      print(e);
    }
  }

  Future<void> saveFriends() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      // Convert the friends map to a list of JSON objects
      final friendList =
          widget.friends.values.map((friend) => friend.toJson()).toList();

      // Encode the list as a JSON string and save
      await prefs.setString('friends', jsonEncode(friendList));
      print('Friends saved successfully.');
    } catch (e) {
      print('Error saving friends: $e');
    }
  }

  String extractToxID(String? fullToxID) {
    const int validLength = 76; // Assume Tox ID is 76 characters
    return (fullToxID?.length ?? 0) >= validLength
        ? fullToxID!.substring(0, validLength)
        : fullToxID ?? 'Unknown Tox ID';
  }

  @override
  Widget build(BuildContext context) {
    final String myToxID = extractToxID(getToxID(widget.toxInstance));

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: friendIdController,
              decoration: const InputDecoration(labelText: 'Friend ID'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => addToxFriend(),
              child: const Text('Add Friend'),
            ),
            const SizedBox(height: 32),
            Center(
              child: Column(
                children: [
                  const Text(
                    'Your Tox ID',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  QrImageView(
                    data: myToxID,
                    version: QrVersions.auto,
                    size: 240,
                    gapless: false,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    myToxID,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    friendIdController.dispose(); // Dispose the controller
    super.dispose();
  }
}
