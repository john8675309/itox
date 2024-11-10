import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:itox/tox/db_bindings.dart';

final secureStorage = FlutterSecureStorage();
final DatabaseHelper _dbHelper = DatabaseHelper();
// A stream controller to notify the UI about new messages
final _newMessageNotifier = StreamController<Map<String, dynamic>>.broadcast();

/// Expose the stream so the UI can listen for new messages
Stream<Map<String, dynamic>> get newMessageStream => _newMessageNotifier.stream;
// Constants
const int TOX_CONNECTION_NONE = 0; // Offline
const int TOX_CONNECTION_TCP = 1; // Online (via TCP)
const int TOX_CONNECTION_UDP = 2; // Online (via UDP)
const int TOX_SAVEDATA_TYPE_SECRET_KEY = 2;

const int TOX_USER_STATUS_NONE = 0; // Online
const int TOX_USER_STATUS_AWAY = 1; // Away
const int TOX_USER_STATUS_BUSY = 2; // Busy

const int TOX_ERR_FRIEND_QUERY_OK = 0;
const int TOX_ERR_FRIEND_QUERY_FRIEND_NOT_FOUND = 1;
const int TOX_ERR_FRIEND_QUERY_NULL = 2;

//Define a Friend
class Friend {
  final String toxId;
  final int friendNumber; // Assigned by Tox
  String alias;
  String status;

  Friend({
    required this.toxId,
    required this.friendNumber,
    required this.alias,
    this.status = 'Offline',
  });

  // Convert Friend to JSON
  Map<String, dynamic> toJson() {
    return {
      'toxId': toxId,
      'friendNumber': friendNumber,
      'alias': alias,
      'status': status,
    };
  }

  // Create Friend from JSON
  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      toxId: json['toxId'],
      friendNumber: json['friendNumber'],
      alias: json['alias'],
      status: json['status'],
    );
  }

  @override
  String toString() {
    return 'Friend Number: $friendNumber, Alias: $alias, Status: $status, ToxID: $toxId';
  }
}

/// Load the Tox library
final DynamicLibrary toxLib = DynamicLibrary.open(
    '/home/john/Documents/c-toxcore/build/libtoxcore.so.2.19.0');

/// Define the Tox struct with a placeholder field
base class Tox extends Struct {
  @Uint8()
  external int placeholder;
}

/// Typedefs for native and Dart functions

// Tox Initialization
typedef ToxOptionsNewNative = Pointer<Void> Function();
typedef ToxOptionsNewDart = Pointer<Void> Function();
final toxOptionsNew = toxLib
    .lookupFunction<ToxOptionsNewNative, ToxOptionsNewDart>('tox_options_new');

typedef ToxNewNative = Pointer<Tox> Function(Pointer<Void>, Pointer<Int32>);
typedef ToxNewDart = Pointer<Tox> Function(Pointer<Void>, Pointer<Int32>);
final toxNew = toxLib.lookupFunction<ToxNewNative, ToxNewDart>('tox_new');

typedef ToxOptionsSetKeyNative = Void Function(Pointer<Void>, Pointer<Uint8>);
typedef ToxOptionsSetKey = void Function(Pointer<Void>, Pointer<Uint8>);
final toxOptionsNewDart =
    toxLib.lookupFunction<ToxOptionsNewNative, ToxOptionsNewDart>(
  'tox_options_new',
);

final toxNewDart = toxLib.lookupFunction<ToxNewNative, ToxNewDart>(
  'tox_new',
);
// Add Friend
typedef ToxFriendAddNative = Int32 Function(
    Pointer<Tox>, Pointer<Uint8>, Pointer<Uint8>, Uint64, Pointer<Int32>);
typedef ToxFriendAdd = int Function(
    Pointer<Tox>, Pointer<Uint8>, Pointer<Uint8>, int, Pointer<Int32>);
final toxFriendAdd = toxLib.lookupFunction<ToxFriendAddNative, ToxFriendAdd>(
  'tox_friend_add',
);

// Send Message
typedef ToxFriendSendMessageNative = Int32 Function(
    Pointer<Tox>, Uint32, Int32, Pointer<Uint8>, Uint64, Pointer<Int32>);
typedef ToxFriendSendMessage = int Function(
    Pointer<Tox>, int, int, Pointer<Uint8>, int, Pointer<Int32>);
final toxFriendSendMessage =
    toxLib.lookupFunction<ToxFriendSendMessageNative, ToxFriendSendMessage>(
  'tox_friend_send_message',
);

// Self Get Address
typedef ToxSelfGetAddressNative = Void Function(Pointer<Tox>, Pointer<Uint8>);
typedef ToxSelfGetAddress = void Function(Pointer<Tox>, Pointer<Uint8>);
final toxSelfGetAddress =
    toxLib.lookupFunction<ToxSelfGetAddressNative, ToxSelfGetAddress>(
  'tox_self_get_address',
);

// Bootstrap
typedef ToxBootstrapNative = Int32 Function(
    Pointer<Tox>, Pointer<Utf8>, Uint16, Pointer<Uint8>, Pointer<Int32>);
typedef ToxBootstrap = int Function(
    Pointer<Tox>, Pointer<Utf8>, int, Pointer<Uint8>, Pointer<Int32>);
final toxBootstrap =
    toxLib.lookupFunction<ToxBootstrapNative, ToxBootstrap>('tox_bootstrap');

// Friend Message Callback
typedef FriendMessageCallbackNative = Void Function(
    Pointer<Tox>,
    Uint32, // Tox_Friend_Number is uint32_t
    Uint32, // Tox_Message_Type is likely an enum, treated as uint32_t
    Pointer<Uint8>, // const uint8_t message[]
    Uint64, // size_t length
    Pointer<Void> // void *user_data
    );
typedef FriendMessageCallback = void Function(
    Pointer<Tox>,
    int, // friend_number
    int, // message_type
    Pointer<Uint8>, // message
    int, // length
    Pointer<Void> // user_data
    );
typedef ToxCallbackFriendMessageNative = Void Function(
    Pointer<Tox>, Pointer<NativeFunction<FriendMessageCallbackNative>>);
typedef ToxCallbackFriendMessage = void Function(
    Pointer<Tox>, Pointer<NativeFunction<FriendMessageCallbackNative>>);
final toxCallbackFriendMessage = toxLib
    .lookupFunction<ToxCallbackFriendMessageNative, ToxCallbackFriendMessage>(
  'tox_callback_friend_message',
);

// Save the Key
typedef ToxOptionsSetSavedataDataNative = Void Function(
    Pointer<Void>, Pointer<Uint8>, IntPtr);
typedef ToxOptionsSetSavedataData = void Function(
    Pointer<Void>, Pointer<Uint8>, int);

final toxOptionsSetSavedataData = toxLib
    .lookupFunction<ToxOptionsSetSavedataDataNative, ToxOptionsSetSavedataData>(
  'tox_options_set_savedata_data',
);

typedef ToxOptionsSetSavedataTypeNative = Void Function(Pointer<Void>, Int32);
typedef ToxOptionsSetSavedataType = void Function(Pointer<Void>, int);

final toxOptionsSetSavedataType = toxLib
    .lookupFunction<ToxOptionsSetSavedataTypeNative, ToxOptionsSetSavedataType>(
  'tox_options_set_savedata_type',
);

// Secret Key
typedef ToxSelfGetSecretKeyNative = Void Function(Pointer<Tox>, Pointer<Uint8>);
typedef ToxSelfGetSecretKey = void Function(Pointer<Tox>, Pointer<Uint8>);

final toxSelfGetSecretKey =
    toxLib.lookupFunction<ToxSelfGetSecretKeyNative, ToxSelfGetSecretKey>(
        'tox_self_get_secret_key');

typedef ToxNewFromPrivateKeyNative = Pointer<Tox> Function(
    Pointer<Uint8>, Pointer<Int32>);
typedef ToxNewFromPrivateKey = Pointer<Tox> Function(
    Pointer<Uint8>, Pointer<Int32>);

final toxNewFromPrivateKey =
    toxLib.lookupFunction<ToxNewFromPrivateKeyNative, ToxNewFromPrivateKey>(
  'tox_new_from_private_key',
);

// Friend Connection Status
typedef ToxFriendGetConnectionStatusNative = Int32 Function(
  Pointer<Tox>, // tox instance
  Uint32, // friend_number
  Pointer<Int32>, // error pointer
);

typedef ToxFriendGetConnectionStatus = int Function(
  Pointer<Tox>, // tox instance
  int, // friend_number
  Pointer<Int32>, // error pointer
);

final toxFriendGetConnectionStatus = toxLib.lookupFunction<
    ToxFriendGetConnectionStatusNative,
    ToxFriendGetConnectionStatus>('tox_friend_get_connection_status');

// Friend Status
typedef ToxFriendGetStatusNative = Int32 Function(Pointer<Tox>, Uint32);
typedef ToxFriendGetStatus = int Function(Pointer<Tox>, int);

final toxFriendGetStatus =
    toxLib.lookupFunction<ToxFriendGetStatusNative, ToxFriendGetStatus>(
  'tox_friend_get_status',
);

typedef ToxFriendByPublicKeyNative = Uint32 Function(
    Pointer<Tox>, Pointer<Uint8>, Pointer<Int32>);
typedef ToxFriendByPublicKey = int Function(
    Pointer<Tox>, Pointer<Uint8>, Pointer<Int32>);

final toxFriendByPublicKey =
    toxLib.lookupFunction<ToxFriendByPublicKeyNative, ToxFriendByPublicKey>(
  'tox_friend_by_public_key',
);

typedef ToxSelfGetFriendListSizeNative = IntPtr Function(Pointer<Tox>);
typedef ToxSelfGetFriendListSize = int Function(Pointer<Tox>);

final toxSelfGetFriendListSize = toxLib.lookupFunction<
    ToxSelfGetFriendListSizeNative,
    ToxSelfGetFriendListSize>('tox_self_get_friend_list_size');

Pointer<Tox> createToxInstanceFromKey(Uint8List privateKey) {
  final privateKeyPointer = calloc<Uint8>(32);
  privateKeyPointer.asTypedList(32).setAll(0, privateKey);

  final errorPointer = calloc<Int32>();
  try {
    final tox = toxNewFromPrivateKey(privateKeyPointer, errorPointer);
    if (tox == nullptr) {
      throw Exception(
          'Failed to create Tox instance. Error code: ${errorPointer.value}');
    }
    return tox;
  } finally {
    calloc.free(privateKeyPointer);
    calloc.free(errorPointer);
  }
}

// Iterate
typedef ToxIterateNative = Void Function(Pointer<Tox>, Pointer<Void>);
typedef ToxIterate = void Function(Pointer<Tox>, Pointer<Void>);
final toxIterate =
    toxLib.lookupFunction<ToxIterateNative, ToxIterate>('tox_iterate');

typedef ToxSelfGetPublicKeyNative = Void Function(Pointer<Tox>, Pointer<Uint8>);
typedef ToxSelfGetPublicKey = void Function(Pointer<Tox>, Pointer<Uint8>);

final toxSelfGetPublicKey =
    toxLib.lookupFunction<ToxSelfGetPublicKeyNative, ToxSelfGetPublicKey>(
  'tox_self_get_public_key',
);

typedef ToxSelfGetFriendListNative = Void Function(
    Pointer<Tox>, Pointer<Uint32>);
typedef ToxSelfGetFriendList = void Function(Pointer<Tox>, Pointer<Uint32>);

// Add the lookup for tox_self_get_friend_list
final toxSelfGetFriendList =
    toxLib.lookupFunction<ToxSelfGetFriendListNative, ToxSelfGetFriendList>(
        'tox_self_get_friend_list');

Uint8List getPublicKey(Pointer<Tox> tox) {
  final publicKeyPointer = calloc<Uint8>(32); // Public key size is 32 bytes
  try {
    toxSelfGetPublicKey(tox, publicKeyPointer);
    return publicKeyPointer.asTypedList(32);
  } finally {
    calloc.free(publicKeyPointer);
  }
}

typedef ToxFriendExistsNative = Int32 Function(Pointer<Tox>, Uint32);
typedef ToxFriendExists = int Function(Pointer<Tox>, int);

final toxFriendExists =
    toxLib.lookupFunction<ToxFriendExistsNative, ToxFriendExists>(
        'tox_friend_exists');

/// Helper Functions
int findFriendNumber(Pointer<Tox> tox, Uint8List publicKey) {
  final publicKeyPointer = calloc<Uint8>(32);
  final errorPointer = calloc<Int32>();
  try {
    publicKeyPointer.asTypedList(32).setAll(0, publicKey);

    final result = toxFriendByPublicKey(tox, publicKeyPointer, errorPointer);

    if (result == 0xFFFFFFFF) {
      final errorCode = errorPointer.value;
      throw Exception('Friend not found. Error code: $errorCode');
    }

    return result;
  } finally {
    calloc.free(publicKeyPointer);
    calloc.free(errorPointer);
  }
}

Future<void> updateFriendAliasInJson(int friendNumber, String newAlias) async {
  final prefs = await SharedPreferences.getInstance();
  final savedFriendsJson = prefs.getString('friends');

  if (savedFriendsJson != null) {
    final List<dynamic> friendsList = jsonDecode(savedFriendsJson);

    // Find the friend and update the alias
    for (var friendJson in friendsList) {
      if (friendJson['friendNumber'] == friendNumber) {
        friendJson['alias'] = newAlias; // Update the alias
        break;
      }
    }

    // Save the updated JSON back to SharedPreferences
    prefs.setString('friends', jsonEncode(friendsList));
    print('Alias updated in JSON for friend $friendNumber');
  }
}

String getConnectionStatus(Pointer<Tox> tox, int friendNumber) {
  final errorPointer = calloc<Int32>(); // Allocate space for error parameter

  try {
    // Check if the friend exists
    final exists = toxFriendExists(tox, friendNumber);
    if (exists == 0) {
      print('Friend $friendNumber does not exist in Tox.');
      return 'Unknown';
    }

    // Get the connection status
    final connectionStatus =
        toxFriendGetConnectionStatus(tox, friendNumber, errorPointer);

    // Debug the error parameter
    final errorCode = errorPointer.value;
    if (errorCode != 0) {
      // Handle error codes here based on Tox documentation
      throw Exception(
          'tox_friend_get_connection_status failed with error code: $errorCode');
    }

    // Map connection status to human-readable string
    return {
          TOX_CONNECTION_NONE: 'Offline',
          TOX_CONNECTION_TCP: 'Online (TCP)',
          TOX_CONNECTION_UDP: 'Online (UDP)',
        }[connectionStatus] ??
        'Unknown';
  } catch (e) {
    print('Error checking connection status for friend $friendNumber: $e');
    return 'Unknown';
  } finally {
    calloc.free(errorPointer);
  }
}

void printFriendList(Pointer<Tox> tox) {
  // Get the number of friends
  final friendCount = toxSelfGetFriendListSize(tox);
  print('Friend Count: $friendCount');

  if (friendCount > 0) {
    final friendListPointer =
        calloc<Uint32>(friendCount); // Allocate for actual count
    try {
      // Fetch the friend list
      toxSelfGetFriendList(tox, friendListPointer);

      // Read the friend list into a Dart list
      final friendList = friendListPointer.asTypedList(friendCount);
      print('Current Tox Friend List: $friendList');
    } finally {
      calloc.free(friendListPointer);
    }
  } else {
    print('No friends found in the Tox instance.');
  }
}

Future<void> savePrivateKey(Uint8List privateKey) async {
  final prefs = await SharedPreferences.getInstance();
  prefs.setString('privateKey', base64Encode(privateKey));
}

// Load the private key
Future<Uint8List?> loadPrivateKey() async {
  final prefs = await SharedPreferences.getInstance();
  final privateKeyBase64 = prefs.getString('privateKey');
  return privateKeyBase64 != null ? base64Decode(privateKeyBase64) : null;
}

typedef ToxSelfSetStatusNative = Void Function(Pointer<Tox>, Int32);
typedef ToxSelfSetStatus = void Function(Pointer<Tox>, int);

final toxSelfSetStatus =
    toxLib.lookupFunction<ToxSelfSetStatusNative, ToxSelfSetStatus>(
  'tox_self_set_status',
);

/// Create a Tox instance
Future<Pointer<Tox>> createToxInstance() async {
  final options = toxOptionsNew();
  if (options == nullptr) {
    throw Exception('Failed to create Tox options');
  }

  final errorPointer = calloc<Int32>();
  try {
    final savedPrivateKey =
        await loadPrivateKey(); // Or loadPrivateKeySecurely()
    if (savedPrivateKey != null) {
      print('Using existing private key...');
      toxOptionsSetSavedataType(options, TOX_SAVEDATA_TYPE_SECRET_KEY);
      if (savedPrivateKey.length != 32) {
        throw Exception(
            'Invalid saved data length: ${savedPrivateKey.length}. Expected 32 bytes.');
      }
      final savedDataPointer = calloc<Uint8>(savedPrivateKey.length);
      final privateKeyPointer = calloc<Uint8>(32);
      privateKeyPointer.asTypedList(32).setAll(0, savedPrivateKey);
      toxOptionsSetSavedataData(options, savedDataPointer, 32);
      print("Options ${options} ${savedPrivateKey.length}");
      calloc.free(privateKeyPointer);
    } else {
      print('No private key found. Generating a new one.');
    }
    final instance = toxNew(options, errorPointer);
    final errorCode = errorPointer.value;
    if (instance == nullptr) {
      throw Exception('Failed to create Tox instance. Error code: $errorCode');
    }
    if (savedPrivateKey == null) {
      final newPrivateKey = getPrivateKey(instance);
      await savePrivateKey(newPrivateKey); // Or savePrivateKeySecurely()
      print('Generated and saved new private key.');
    }
    return instance;
  } finally {
    calloc.free(errorPointer);
  }
}

///Add Friend
int addFriend(Pointer<Tox> tox, String friendId, String message) {
  final friendIdBytes = Uint8List(38);
  try {
    // Parse friend ID into bytes
    for (int i = 0; i < 38; i++) {
      friendIdBytes[i] =
          int.parse(friendId.substring(i * 2, i * 2 + 2), radix: 16);
    }
  } catch (e) {
    throw Exception(
        'Invalid Tox ID format. Ensure it is a 76-character hexadecimal string.');
  }
  print(1);
  final friendIdPointer = calloc<Uint8>(38);
  final messagePointer = message.toNativeUtf8();
  final errorPointer = calloc<Int32>();
  print(2);
  try {
    // Copy friend ID to allocated memory
    friendIdPointer.asTypedList(38).setAll(0, friendIdBytes);

    // Add the friend
    final result = toxFriendAdd(
      tox,
      friendIdPointer,
      messagePointer.cast<Uint8>(),
      message.length,
      errorPointer,
    );

    print('Result from tox_friend_add: $result');
    print('Error code: ${errorPointer.value}');

    // Handle errors returned by tox_friend_add
    if (result == -1) {
      final errorCode = errorPointer.value;
      switch (errorCode) {
        case 1: // TOX_ERR_FRIEND_ADD_NULL
          throw Exception('Friend ID or message was null.');
        case 2: // TOX_ERR_FRIEND_ADD_TOO_LONG
          throw Exception('Message is too long.');
        case 3: // TOX_ERR_FRIEND_ADD_NO_MESSAGE
          throw Exception('No message was provided.');
        case 4: // TOX_ERR_FRIEND_ADD_OWN_KEY
          throw Exception('Cannot add yourself as a friend.');
        case 5: // TOX_ERR_FRIEND_ADD_ALREADY_SENT
          throw Exception('Friend request already sent.');
        case 6: // TOX_ERR_FRIEND_ADD_BAD_CHECKSUM
          throw Exception('Friend ID checksum is invalid.');
        case 7: // TOX_ERR_FRIEND_ADD_SET_NEW_NOSPAM
          throw Exception('Friend ID includes an incorrect nospam value.');
        case 8: // TOX_ERR_FRIEND_ADD_MALLOC
          throw Exception('Memory allocation failed.');
        default:
          throw Exception('Unknown error occurred: $errorCode');
      }
    }

    // Debug: Check the current friend list
    debugFriendList(tox);

    return result;
  } catch (e) {
    print('Error in addFriend: $e');
    rethrow; // Rethrow the exception to propagate it to the caller
  } finally {
    calloc.free(friendIdPointer);
    calloc.free(messagePointer);
    calloc.free(errorPointer);
  }
}

void debugFriendList(Pointer<Tox> tox) {
  // Get the size of the friend list
  final friendCount = toxSelfGetFriendListSize(tox);
  print('Friend Count: $friendCount');

  if (friendCount > 0) {
    final friendListPointer = calloc<Uint32>(friendCount);
    try {
      // Fetch the friend list
      toxSelfGetFriendList(tox, friendListPointer);

      // Read the friend list into a Dart list
      final friendList = friendListPointer.asTypedList(friendCount);
      print('Friend List: $friendList');
    } finally {
      calloc.free(friendListPointer);
    }
  } else {
    print('No friends found in the Tox instance.');
  }
}

/// Get Tox ID
String getToxID(Pointer<Tox> tox) {
  final addressPointer = calloc<Uint8>(76);
  try {
    toxSelfGetAddress(tox, addressPointer);
    final addressBytes = addressPointer.asTypedList(76);
    return addressBytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  } finally {
    calloc.free(addressPointer);
  }
}

/// Send a message
int sendMessage(Pointer<Tox> tox, int friendNumber, String message) {
  if (friendNumber < 0) {
    throw Exception('Invalid friend number: $friendNumber');
  }

  final messagePointer = message.toNativeUtf8();
  final errorPointer = calloc<Int32>();

  try {
    final result = toxFriendSendMessage(
      tox,
      friendNumber,
      0, // Message type (0 for normal text message)
      messagePointer.cast<Uint8>(),
      message.length,
      errorPointer,
    );

    // Handle result and error
    if (result == -1) {
      final errorCode = errorPointer.value;
      throw Exception('Failed to send message. Error code: $errorCode');
    }

    return result;
  } finally {
    calloc.free(messagePointer);
    calloc.free(errorPointer);
  }
}

/// Bootstrap the Tox network
void bootstrapToxNetwork(Pointer<Tox> tox) {
  const bootstrapNode = 'tox.hidemybits.com';
  const port = 443;
  const bootstrapKey =
      '5D57B95EE4A7F37BA031DAD0CBD9510A9C96FFE09C1CE24A9C33746F39817D6E';

  //const bootstrapNode = 'tox2.abilinski.com';
  //const port = 33445;
  //const bootstrapKey =
  //    '7A6098B590BDC73F9723FC59F82B3F9085A64D1B213AAF8E610FD351930D052D';

  final addressPointer = bootstrapNode.toNativeUtf8();
  final keyPointer = calloc<Uint8>(32);
  final errorPointer = calloc<Int32>();

  try {
    for (int i = 0; i < 32; i++) {
      keyPointer[i] =
          int.parse(bootstrapKey.substring(i * 2, i * 2 + 2), radix: 16);
    }

    final result =
        toxBootstrap(tox, addressPointer, port, keyPointer, errorPointer);

    if (result != 1) {
      final errorCode = errorPointer.value;
      throw Exception(
          'Failed to bootstrap the Tox network. Error code: $errorCode');
    }
    // ignore: avoid_print
    print('Bootstrap successful');
  } finally {
    calloc.free(addressPointer);
    calloc.free(keyPointer);
    calloc.free(errorPointer);
  }
}

/// Register the friend message callback
void registerMessageCallback(Pointer<Tox> tox) {
  final callbackPointer = Pointer.fromFunction<FriendMessageCallbackNative>(
    friendMessageCallback,
  );

  toxCallbackFriendMessage(tox, callbackPointer);
}

/// Friend message callback function
void friendMessageCallback(
  Pointer<Tox> tox,
  int friendNumber,
  int messageType,
  Pointer<Uint8> message,
  int length,
  Pointer<Void> userData,
) {
  print('Callback Invoked:');
  print('Friend Number: $friendNumber');
  print('Message Type: $messageType');
  print('Raw Length: $length');
  print('Message Pointer: $message');

  const int maxMessageLength = 1373; // Tox max message size

  // Validate the length
  if (length <= 0 || length > maxMessageLength) {
    print('Invalid message length: $length. Skipping message.');
    return;
  }

  try {
    // Decode the message as UTF-8
    final messageBytes = message.asTypedList(length);
    final messageText = utf8.decode(messageBytes);
    print('Message received from friend $friendNumber: $messageText');

    // Notify the database and UI
    final timestamp = DateTime.now().toIso8601String();
    _dbHelper.saveMessage(friendNumber, 'IN', messageText, timestamp);
    _newMessageNotifier
        .add({'friendNumber': friendNumber, 'content': messageText});
  } catch (e) {
    print('Error processing message: $e');
  }
}

Uint8List getPrivateKey(Pointer<Tox> tox) {
  // Allocate memory for the private key (32 bytes)
  final secretKeyPointer = calloc<Uint8>(32); // TOX_SECRET_KEY_SIZE = 32
  try {
    // Call the native function
    toxSelfGetSecretKey(tox, secretKeyPointer);

    // Convert the memory block to a Uint8List
    return secretKeyPointer.asTypedList(32);
  } finally {
    // Free the allocated memory
    calloc.free(secretKeyPointer);
  }
}

void runToxEventLoop(Pointer<Tox> tox, void Function() updateStatuses) async {
  while (true) {
    try {
      toxIterate(tox, nullptr); // Process events
      updateStatuses(); // Call the update function
    } catch (e) {
      print('Error in Tox event loop: $e');
    }

    await Future.delayed(const Duration(milliseconds: 50));
  }
}

Future<void> savePrivateKeySecurely(Uint8List privateKey) async {
  // Encode the private key as Base64
  final privateKeyString = base64Encode(privateKey);
  // Save the private key in secure storage
  await secureStorage.write(key: 'privateKey', value: privateKeyString);
}

Future<Uint8List?> loadPrivateKeySecurely() async {
  // Retrieve the private key from secure storage
  final privateKeyString = await secureStorage.read(key: 'privateKey');
  if (privateKeyString == null) return null;
  // Decode the Base64 string back into a Uint8List
  return base64Decode(privateKeyString);
}

void setStatusOnline(Pointer<Tox> tox) {
  toxSelfSetStatus(tox, TOX_USER_STATUS_NONE);
}

String extractToxID(String fullToxID) {
  // Assuming the Tox ID is the first 76 characters
  return fullToxID.substring(0, 76).toUpperCase();
}
