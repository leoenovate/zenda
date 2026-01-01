import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageSender {
  school,
  parent,
}

class Message {
  final String id;
  final String studentId;
  final String content;
  final DateTime timestamp;
  final MessageSender sender;
  final bool isRead;
  final String? senderName;
  final String? attachmentUrl;

  const Message({
    required this.id,
    required this.studentId,
    required this.content,
    required this.timestamp,
    required this.sender,
    this.isRead = false,
    this.senderName,
    this.attachmentUrl,
  });

  // Create message from Firestore document
  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      sender: data['sender'] == 'school' ? MessageSender.school : MessageSender.parent,
      isRead: data['isRead'] ?? false,
      senderName: data['senderName'],
      attachmentUrl: data['attachmentUrl'],
    );
  }

  // Convert message to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'sender': sender == MessageSender.school ? 'school' : 'parent',
      'isRead': isRead,
      'senderName': senderName,
      'attachmentUrl': attachmentUrl,
    };
  }

  // Create a copy of this message with modified fields
  Message copyWith({
    String? id,
    String? studentId,
    String? content,
    DateTime? timestamp,
    MessageSender? sender,
    bool? isRead,
    String? senderName,
    String? attachmentUrl,
  }) {
    return Message(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      sender: sender ?? this.sender,
      isRead: isRead ?? this.isRead,
      senderName: senderName ?? this.senderName,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
    );
  }
} 