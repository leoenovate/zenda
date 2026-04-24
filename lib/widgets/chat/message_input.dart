import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/firebase_service.dart';
import '../../models/message.dart';
import '../../utils/responsive_builder.dart';

class MessageInput extends StatefulWidget {
  final String studentId;
  final MessageSender sender;
  final String senderName;
  final Function()? onMessageSent;

  const MessageInput({
    Key? key,
    required this.studentId,
    required this.sender,
    required this.senderName,
    this.onMessageSent,
  }) : super(key: key);

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = false;
  bool _isUploadingAttachment = false;
  String? _attachmentPath;
  String? _attachmentUrl;
  Uint8List? _attachmentBytes;
  
  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        // Add a small delay to ensure the keyboard is fully visible
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            widget.onMessageSent?.call();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_isUploadingAttachment) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for the attachment to finish uploading')),
      );
      return;
    }
    final message = _controller.text.trim();
    if (message.isEmpty && _attachmentUrl == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      await FirebaseService.sendMessage(
        studentId: widget.studentId,
        content: message,
        sender: widget.sender,
        senderName: widget.senderName,
        attachmentUrl: _attachmentUrl,
      );
      
      _controller.clear();
      setState(() {
        _attachmentPath = null;
        _attachmentUrl = null;
        _attachmentBytes = null;
      });
      
      if (widget.onMessageSent != null) {
        widget.onMessageSent!();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (picked == null) return;

      setState(() {
        _isUploadingAttachment = true;
        _attachmentPath = picked.name;
        _attachmentUrl = null;
      });

      Uint8List bytes;
      if (kIsWeb) {
        bytes = await picked.readAsBytes();
      } else {
        bytes = await File(picked.path).readAsBytes();
      }

      final ext = picked.name.contains('.')
          ? picked.name.substring(picked.name.lastIndexOf('.') + 1).toLowerCase()
          : 'jpg';
      final storagePath =
          'chat_attachments/${widget.studentId}/${DateTime.now().millisecondsSinceEpoch}.$ext';

      final ref = FirebaseStorage.instance.ref(storagePath);
      final metadata = SettableMetadata(
        contentType: 'image/${ext == 'jpg' ? 'jpeg' : ext}',
      );
      await ref.putData(bytes, metadata);
      final url = await ref.getDownloadURL();

      if (!mounted) return;
      setState(() {
        _attachmentBytes = bytes;
        _attachmentUrl = url;
        _isUploadingAttachment = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploadingAttachment = false;
        _attachmentPath = null;
        _attachmentUrl = null;
        _attachmentBytes = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to attach image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeAttachment() {
    setState(() {
      _attachmentPath = null;
      _attachmentUrl = null;
      _attachmentBytes = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacingSm, 
        vertical: context.isMobile ? 8.0 : 12.0
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -1),
            blurRadius: 8,
            color: Colors.black.withOpacity(0.1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Attachment preview
          if (_attachmentPath != null) ...[
            Stack(
              children: [
                Container(
                  height: context.isMobile ? 80 : 100,
                  width: double.infinity,
                  margin: EdgeInsets.only(bottom: context.spacingSm),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(8),
                    image: _attachmentBytes != null
                        ? DecorationImage(
                            image: MemoryImage(_attachmentBytes!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _attachmentBytes == null
                      ? Center(
                          child: Icon(
                            Icons.image,
                            size: context.isMobile ? 32 : 40,
                            color: Colors.grey,
                          ),
                        )
                      : null,
                ),
                if (_isUploadingAttachment)
                  Positioned.fill(
                    child: Container(
                      margin: EdgeInsets.only(bottom: context.spacingSm),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: _isUploadingAttachment ? null : _removeAttachment,
                    child: Container(
                      padding: EdgeInsets.all(context.isMobile ? 3 : 4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: context.isMobile ? 14 : 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          
          // Message input row with responsive layout
          LayoutBuilder(
            builder: (context, constraints) {
              final bool isCompactWidth = constraints.maxWidth < 320;
              
              return Row(
                children: [
                  // Attachment button
                  if (!isCompactWidth || isLandscape)
                    IconButton(
                      icon: Icon(
                        Icons.attach_file, 
                        size: context.isMobile ? 22 : 24
                      ),
                      onPressed: _isLoading ? null : _pickImage,
                      color: Theme.of(context).colorScheme.primary,
                      padding: EdgeInsets.all(context.isMobile ? 8 : 12),
                      constraints: BoxConstraints(
                        minWidth: context.isMobile ? 32 : 40, 
                        minHeight: context.isMobile ? 32 : 40
                      ),
                      tooltip: 'Attach file',
                    ),
                  
                  // Text field
                  Expanded(
                    child: Container(
                      constraints: BoxConstraints(
                        maxHeight: isLandscape ? 100 : 120,
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        decoration: InputDecoration(
                          hintText: context.isMobile && isCompactWidth 
                              ? 'Message...' 
                              : 'Type a message...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: context.isMobile ? 12 : 16,
                            vertical: context.isMobile ? 8 : 10,
                          ),
                          // Show attachment button inside input for small screens
                          prefixIcon: isCompactWidth && !isLandscape
                              ? IconButton(
                                  icon: const Icon(Icons.attach_file, size: 20),
                                  onPressed: _isLoading ? null : _pickImage,
                                  color: Theme.of(context).colorScheme.primary,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 32, 
                                    minHeight: 32
                                  ),
                                )
                              : null,
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        minLines: 1,
                        maxLines: isLandscape ? 3 : 5,
                        enabled: !_isLoading,
                        style: TextStyle(fontSize: context.isMobile ? 14 : 16),
                      ),
                    ),
                  ),
                  
                  // Send button
                  IconButton(
                    icon: _isLoading
                        ? SizedBox(
                            width: context.isMobile ? 20 : 24,
                            height: context.isMobile ? 20 : 24,
                            child: const CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            Icons.send, 
                            size: context.isMobile ? 22 : 24
                          ),
                    onPressed: _isLoading ? null : _sendMessage,
                    color: Theme.of(context).colorScheme.primary,
                    padding: EdgeInsets.all(context.isMobile ? 8 : 12),
                    constraints: BoxConstraints(
                      minWidth: context.isMobile ? 32 : 40, 
                      minHeight: context.isMobile ? 32 : 40
                    ),
                    tooltip: 'Send message',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
} 
