import 'dart:async';
import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:itox/libtox_bindings.dart';
import 'package:itox/tox/db_bindings.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter_emoji/flutter_emoji.dart';

class ChatScreen extends StatefulWidget {
  final Friend? friend;
  final Pointer<Tox> toxInstance;

  const ChatScreen(
      {super.key, required this.friend, required this.toxInstance});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, String>> _messages =
      []; // Stores messages with sender info
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late StreamSubscription _messageSubscription;

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty || widget.friend == null) return;

    final timestamp = DateTime.now().toIso8601String();

    // Save the message to the database
    await _dbHelper.saveMessage(
      widget.friend!.friendNumber,
      'OUT',
      message,
      timestamp,
    );
    sendMessage(widget.toxInstance, widget.friend!.friendNumber, message);
    // Update the UI
    final isAtBottom = _scrollController.offset >=
        _scrollController.position.maxScrollExtent - 50;
    setState(() {
      _messages.add({'sender': 'me', 'content': message});
    });
    if (isAtBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }
    _messageController.clear();
  }

  void _sendFile() {
    setState(() {
      _messages.add({
        'sender': 'me',
        'content': '[File Sent]'
      }); // Placeholder for file logic
    });
  }

  @override
  void dispose() {
    _messageSubscription.cancel(); // Clean up the subscription
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadMessages();

    // Listen for new messages
    _messageSubscription = newMessageStream.listen((newMessage) {
      if (newMessage['friendNumber'] == widget.friend?.friendNumber) {
        final isAtBottom = _scrollController.offset >=
            _scrollController.position.maxScrollExtent - 50;
        setState(() {
          _messages.add({'sender': 'friend', 'content': newMessage['content']});
        });
        print("*************${isAtBottom}");
        // Scroll to the bottom when a new message is received
        //if (isAtBottom) {
        print("Is At Bottom");
        //WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isAtBottom) {
          Future.delayed(const Duration(milliseconds: 1000), () {
            print("*************Checking ScrollController...");
            if (_scrollController.hasClients) {
              print("ScrollController has clients");
              print("Current offset: ${_scrollController.offset}");
              print(
                  "Max scroll extent: ${_scrollController.position.maxScrollExtent}");
              _scrollController
                  .jumpTo(_scrollController.position.maxScrollExtent);
              print("Jumped to bottom");
            } else {
              print("ScrollController does not have clients");
            }
          });
        }
        //});
        //}
      }
    });
  }

  /*Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || widget.friend == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    await _loadMessages(append: true);

    setState(() {
      _isLoadingMore = false;
    });
  }*/

  Future<void> _loadMessages() async {
    if (widget.friend == null) return;

    print('Loading all messages for friend: ${widget.friend!.friendNumber}');

    try {
      final messages =
          await _dbHelper.fetchAllMessages(widget.friend!.friendNumber);

      print('Fetched ${messages.length} messages.');

      setState(() {
        _messages.clear(); // Clear the existing messages in case of a reload
        _messages.addAll(messages.map((msg) => {
              'sender': msg['direction'] == 'IN' ? 'friend' : 'me',
              'content': msg['content'] as String,
            }));
      });

      // Add a small delay to ensure the ListView is fully rendered
      WidgetsBinding.instance.addPostFrameCallback((_) {
        //Future.delayed(const Duration(milliseconds: 10), () {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
        //});
      });
    } catch (e) {
      print('Error loading messages: $e');
    }
  }

  Widget _buildMessageBubble(Map<String, String> message) {
    final isMe = message['sender'] == 'me';
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue : Colors.grey[300],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(12),
          ),
        ),
        child: Text(
          message['content'] ?? '',
          style: TextStyle(color: isMe ? Colors.white : Colors.black),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => _showRenameDialog(context),
          child: Text(
            widget.friend?.alias.isNotEmpty == true
                ? widget.friend!.alias
                : 'Chat',
            style: const TextStyle(decoration: TextDecoration.underline),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller:
                  _scrollController, // Ensure the controller is assigned
              reverse: false, // Newest messages at the bottom
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message =
                    _messages[index]; // Adjust the index handling for reverse
                return _buildMessageBubble(message);
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  onPressed: _sendFile,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _sendMessage(_messageController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final TextEditingController _renameController = TextEditingController(
      text: widget.friend?.alias ?? '',
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Rename Chat'),
          content: TextField(
            controller: _renameController,
            decoration: const InputDecoration(hintText: 'Enter new chat name'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog without saving
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _renameChat(_renameController.text);
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _renameChat(String newName) {
    if (widget.friend != null) {
      setState(() {
        widget.friend!.alias = newName; // Update the name in memory
      });

      // Update the name in the JSON
      updateFriendAliasInJson(widget.friend!.friendNumber, newName);
    }
  }
}
