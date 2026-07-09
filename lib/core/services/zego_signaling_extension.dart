import 'dart:convert';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';
import 'package:zego_plugin_adapter/zego_plugin_adapter.dart';

extension ZegoUIKitSignalingPluginExtension on ZegoUIKitSignalingPlugin {
  Future<void> sendCustomCommand({
    required String inviterID,
    required List<String> inviteeIDs,
    required String customCommand,
  }) async {
    final zim = ZIM.getInstance();
    if (zim == null) {
      throw Exception('ZIM is not initialized.');
    }

    for (final inviteeID in inviteeIDs) {
      final pushConfig = ZIMPushConfig()
        ..title = 'New Message'
        ..content = 'New Encrypted Message'
        ..payload = customCommand
        ..resourcesID = 'vybin_call_resource';

      await zim.sendMessage(
        ZIMCommandMessage(message: utf8.encode(customCommand)),
        inviteeID,
        ZIMConversationType.peer,
        ZIMMessageSendConfig()..pushConfig = pushConfig,
      );
    }
  }

  void setupPeerToRoomCommandBridge() {
    eventCenter.passThroughEvent.onReceivePeerMessage = (zim, messageList, fromUserID) {
      for (final msg in messageList) {
        if (msg is ZIMCommandMessage) {
          final inRoomMsg = ZegoSignalingPluginInRoomCommandMessage(
            message: msg.message,
            senderUserID: fromUserID,
            orderKey: msg.orderKey,
            timestamp: msg.timestamp,
          );
          
          eventCenter.inRoomCommandMessageReceived.add(
            ZegoSignalingPluginInRoomCommandMessageReceivedEvent(
              messages: [inRoomMsg],
              roomID: '',
            ),
          );
        }
      }
    };
  }
}
