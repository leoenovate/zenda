import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/message.dart';
import '../../utils/responsive_builder.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isCurrentUser;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isCurrentUser,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final timeFormatter = DateFormat.Hm();
    final messageTime = timeFormatter.format(message.timestamp);
    final bubbleColor = isCurrentUser 
        ? Theme.of(context).colorScheme.primary 
        : Theme.of(context).colorScheme.surface;
    final textColor = isCurrentUser 
        ? Theme.of(context).colorScheme.onPrimary 
        : Theme.of(context).colorScheme.onSurface;
    
    // Adjust bubble width based on screen size
    final screenWidth = MediaQuery.of(context).size.width;
    final maxBubbleWidth = context.isMobile 
        ? screenWidth * 0.75 
        : context.isTablet 
            ? screenWidth * 0.6 
            : screenWidth * 0.45;

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: context.isMobile ? 3 : 4, 
        horizontal: context.spacingSm
      ),
      child: Row(
        mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar for other user's messages
          if (!isCurrentUser) ...[
            CircleAvatar(
              radius: context.isMobile ? 14 : 16,
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              child: Text(
                message.senderName?.isNotEmpty == true 
                    ? message.senderName![0].toUpperCase() 
                    : (message.sender == MessageSender.school ? 'S' : 'P'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: context.isMobile ? 10 : 12,
                ),
              ),
            ),
            SizedBox(width: context.spacingXs),
          ],
          
          // Message content
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: context.isMobile ? 12 : 16, 
                vertical: context.isMobile ? 8 : 10
              ),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isCurrentUser ? const Radius.circular(16) : const Radius.circular(4),
                  bottomRight: isCurrentUser ? const Radius.circular(4) : const Radius.circular(16),
                ),
                border: !isCurrentUser
                    ? Border.all(
                        color: Theme.of(context).dividerColor.withOpacity(0.1),
                      )
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Attachment image if present
                  if (message.attachmentUrl != null && message.attachmentUrl!.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        message.attachmentUrl!,
                        fit: BoxFit.cover,
                        width: context.isMobile ? 150 : 200,
                        height: context.isMobile ? 112 : 150,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return SizedBox(
                            width: context.isMobile ? 150 : 200,
                            height: context.isMobile ? 112 : 150,
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / 
                                      loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, _, __) => Container(
                          width: context.isMobile ? 150 : 200,
                          height: context.isMobile ? 75 : 100,
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: context.spacingXs),
                  ],
                  
                  // Message text
                  Text(
                    message.content,
                    style: TextStyle(
                      color: textColor,
                      fontSize: context.isMobile ? 14 : 15,
                    ),
                  ),
                  
                  // Message timestamp
                  Padding(
                    padding: EdgeInsets.only(top: context.spacingXs),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          messageTime,
                          style: TextStyle(
                            color: textColor.withOpacity(0.7),
                            fontSize: context.isMobile ? 10 : 11,
                          ),
                        ),
                        SizedBox(width: context.isMobile ? 3 : 4),
                        if (isCurrentUser)
                          Icon(
                            message.isRead ? Icons.done_all : Icons.done,
                            size: context.isMobile ? 12 : 14,
                            color: message.isRead
                                ? Colors.lightBlue
                                : textColor.withOpacity(0.7),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Avatar for current user's messages
          if (isCurrentUser) ...[
            SizedBox(width: context.spacingXs),
            CircleAvatar(
              radius: context.isMobile ? 14 : 16,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                message.senderName?.isNotEmpty == true 
                    ? message.senderName![0].toUpperCase() 
                    : (message.sender == MessageSender.school ? 'S' : 'P'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: context.isMobile ? 10 : 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
} 