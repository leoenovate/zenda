import 'package:flutter/material.dart';
import '../models/student.dart';
import '../models/message.dart';
import '../services/firebase_service.dart';
import '../widgets/chat/message_bubble.dart';
import '../widgets/chat/message_input.dart';
import 'package:intl/intl.dart';
import '../utils/responsive_builder.dart';

class ChatScreen extends StatefulWidget {
  final Student student;
  final MessageSender userType;
  final String userName;

  const ChatScreen({
    Key? key,
    required this.student,
    required this.userType,
    required this.userName,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  Stream<List<Message>>? _messagesStream;
  bool _isFirstLoad = true;
  
  @override
  void initState() {
    super.initState();
    _messagesStream = FirebaseService.getMessagesStream(widget.student.id!);
    
    // Mark messages as read when chat is opened
    _messagesStream?.listen((messages) {
      for (final message in messages) {
        if (!message.isRead && message.sender != widget.userType) {
          FirebaseService.markMessageAsRead(message.id);
        }
      }
      
      // Scroll to bottom on first load
      if (_isFirstLoad && messages.isNotEmpty) {
        _isFirstLoad = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: widget.student.period == 'Morning'
                  ? Colors.amber.shade800
                  : Colors.blue,
              radius: context.isMobile ? 14 : 16,
              child: Text(
                widget.student.name[0].toUpperCase(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: context.isMobile ? 12 : 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(width: context.spacingXs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.student.name,
                    style: TextStyle(
                      fontSize: context.isMobile ? 14 : 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.student.period,
                    style: TextStyle(
                      fontSize: context.isMobile ? 10 : 12,
                      color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              _showStudentInfo(context);
            },
            tooltip: 'Student Info',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<Message>>(
                stream: _messagesStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
  
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: context.screenPadding,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: context.isMobile ? 48 : 64,
                              color: Colors.red.shade300,
                            ),
                            SizedBox(height: context.spacingSm),
                            Text(
                              'Error loading messages',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            SizedBox(height: context.spacingXs),
                            Text(
                              '${snapshot.error}',
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }
  
                  final messages = snapshot.data ?? [];
                  if (messages.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: context.screenPadding,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: context.isMobile ? 48 : 64,
                              color: Colors.grey.shade400,
                            ),
                            SizedBox(height: context.spacingSm),
                            Text(
                              'No messages yet',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: context.isMobile ? 14 : 16,
                              ),
                            ),
                            SizedBox(height: context.spacingXs),
                            Text(
                              'Start the conversation!',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: context.isMobile ? 12 : 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
  
                  // Group messages by date
                  final Map<String, List<Message>> messagesByDate = {};
                  for (final message in messages) {
                    final dateStr = _getDateString(message.timestamp);
                    if (!messagesByDate.containsKey(dateStr)) {
                      messagesByDate[dateStr] = [];
                    }
                    messagesByDate[dateStr]!.add(message);
                  }
  
                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: EdgeInsets.symmetric(
                      vertical: context.spacingMd,
                      horizontal: context.isMobile ? 0 : context.spacingSm,
                    ),
                    itemCount: messagesByDate.keys.length,
                    itemBuilder: (context, dateIndex) {
                      final date = messagesByDate.keys.elementAt(dateIndex);
                      final dateMessages = messagesByDate[date]!;
  
                      return Column(
                        children: [
                          _buildDateDivider(date),
                          ...dateMessages.map((message) {
                            return MessageBubble(
                              message: message,
                              isCurrentUser: message.sender == widget.userType,
                            );
                          }).toList(),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            MessageInput(
              studentId: widget.student.id!,
              sender: widget.userType,
              senderName: widget.userName,
              onMessageSent: _scrollToBottom,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateDivider(String date) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: context.spacingSm),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.shade400)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.spacingXs),
            child: Text(
              date,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  String _getDateString(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Today';
    }
    
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return 'Yesterday';
    }
    
    if (now.difference(date).inDays < 7) {
      return DateFormat('EEEE').format(date); // Weekday name
    }
    
    return DateFormat('MMMM d, yyyy').format(date);
  }

  void _showStudentInfo(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(context.spacingMd),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: widget.student.period == 'Morning'
                          ? Colors.amber.shade800
                          : Colors.blue,
                      radius: 20,
                      child: Text(
                        widget.student.name[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: context.spacingSm),
                    Expanded(
                      child: Text(
                        widget.student.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.spacingMd),
                
                // Student info in responsive grid
                Wrap(
                  spacing: context.spacingMd,
                  runSpacing: context.spacingSm,
                  children: [
                    SizedBox(
                      width: isLandscape ? 180 : double.infinity,
                      child: _buildInfoItem('Registration', widget.student.registrationNumber ?? 'N/A'),
                    ),
                    SizedBox(
                      width: isLandscape ? 180 : double.infinity,
                      child: _buildInfoItem('Gender', widget.student.gender == 'M' ? 'Male' : 'Female'),
                    ),
                    SizedBox(
                      width: isLandscape ? 180 : double.infinity,
                      child: _buildInfoItem('Class', widget.student.period),
                    ),
                    SizedBox(
                      width: isLandscape ? 180 : double.infinity,
                      child: _buildInfoItem('Father\'s Name', widget.student.fatherName ?? 'N/A'),
                    ),
                    SizedBox(
                      width: isLandscape ? 180 : double.infinity,
                      child: _buildInfoItem('Father\'s Phone', widget.student.fatherPhone ?? 'N/A'),
                    ),
                    SizedBox(
                      width: isLandscape ? 180 : double.infinity,
                      child: _buildInfoItem('Mother\'s Name', widget.student.motherName ?? 'N/A'),
                    ),
                    SizedBox(
                      width: isLandscape ? 180 : double.infinity,
                      child: _buildInfoItem('Mother\'s Phone', widget.student.motherPhone ?? 'N/A'),
                    ),
                  ],
                ),
                SizedBox(height: context.spacingMd),
                
                // Close button
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }
} 