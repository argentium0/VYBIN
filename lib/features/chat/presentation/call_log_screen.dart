import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:vybin/features/chat/data/chat_repository.dart';
import 'package:vybin/shared/models/user_model.dart';
import 'package:vybin/shared/theme/vybin_theme.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CallLogScreen extends StatelessWidget {
  const CallLogScreen({super.key});

  String _formatCallLogTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inDays == 0 && now.day == dateTime.day) {
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } else if (diff.inDays == 1 || (diff.inDays == 0 && now.day != dateTime.day)) {
      return 'Yesterday';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (myUid.isEmpty) {
      return const Center(
        child: Text('User not authenticated'),
      );
    }

    final chatRepository = context.read<ChatRepository>();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('call_logs')
          .where('participantUids', arrayContains: myUid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: VybinTheme.whatsappGreen),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: VybinTheme.errorColor),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'No call logs yet.',
              style: TextStyle(color: VybinTheme.secondaryText, fontSize: 16),
            ),
          );
        }

        // Sort descending by timestamp manually to avoid Firestore composite index requirement.
        final sortedDocs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs);
        sortedDocs.sort((a, b) {
          final aTimeVal = a.data()['timestamp'];
          final bTimeVal = b.data()['timestamp'];
          
          DateTime parseTime(dynamic val) {
            if (val == null) return DateTime.now();
            if (val is Timestamp) return val.toDate();
            if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
            return DateTime.now();
          }

          final aTime = parseTime(aTimeVal);
          final bTime = parseTime(bTimeVal);
          return bTime.compareTo(aTime);
        });

        return ListView.separated(
          itemCount: sortedDocs.length,
          separatorBuilder: (context, index) => const Divider(
            height: 1,
            thickness: 0.5,
            indent: 72,
            endIndent: 16,
            color: Colors.white10,
          ),
          itemBuilder: (context, index) {
            final data = sortedDocs[index].data();
            final callerId = data['callerId'] as String? ?? '';
            final receiverId = data['receiverId'] as String? ?? '';
            final status = data['status'] as String? ?? 'missed';
            final timestampVal = data['timestamp'];

            DateTime parseTime(dynamic val) {
              if (val == null) return DateTime.now();
              if (val is Timestamp) return val.toDate();
              if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
              return DateTime.now();
            }
            final timestamp = parseTime(timestampVal);

            final isOutgoing = callerId == myUid;
            final otherUid = isOutgoing ? receiverId : callerId;

            return StreamBuilder<UserModel?>(
              stream: chatRepository.getUserStream(otherUid, myUid),
              builder: (context, userSnapshot) {
                final user = userSnapshot.data;
                final displayName = user?.displayName ?? otherUid;
                final livePhotoUrl = user?.profilePhotoUrl;

                final cleanName = displayName.startsWith('@')
                    ? displayName.substring(1)
                    : displayName;
                final initials = cleanName.length >= 2
                    ? cleanName.substring(0, 2).toUpperCase()
                    : cleanName.toUpperCase();

                // Subtitle details
                IconData callIcon;
                Color callColor;
                String subtitleText;

                if (status == 'completed') {
                  callIcon = isOutgoing ? Icons.call_made : Icons.call_received;
                  callColor = Colors.green;
                  subtitleText = isOutgoing ? 'Outgoing' : 'Incoming';
                } else {
                  callIcon = isOutgoing ? Icons.call_made : Icons.call_missed;
                  callColor = Colors.red;
                  subtitleText = status == 'declined'
                      ? (isOutgoing ? 'Declined by recipient' : 'Declined')
                      : (isOutgoing ? 'Unanswered' : 'Missed');
                }

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: VybinTheme.whatsappTeal,
                    backgroundImage:
                        (livePhotoUrl != null && livePhotoUrl.isNotEmpty)
                            ? NetworkImage(livePhotoUrl)
                            : null,
                    child: (livePhotoUrl == null || livePhotoUrl.isEmpty)
                        ? Text(
                            initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          )
                        : null,
                  ),
                  title: Text(
                    displayName,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Row(
                      children: [
                        Icon(
                          callIcon,
                          color: callColor,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$subtitleText • ${_formatCallLogTime(timestamp)}',
                          style: const TextStyle(
                            color: VybinTheme.secondaryText,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.phone,
                      color: VybinTheme.whatsappGreen,
                    ),
                    onPressed: () async {
                      try {
                        await ZegoUIKitPrebuiltCallInvitationService().send(
                          invitees: [
                            ZegoCallUser(otherUid, displayName),
                          ],
                          isVideoCall: false,
                          resourceID: 'vybin_call_resource',
                        );
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to initiate call: $e'),
                            ),
                          );
                        }
                      }
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
