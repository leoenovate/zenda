import 'package:flutter/material.dart';
import '../models/student.dart';
import '../models/message.dart';
import '../services/firebase_service.dart';
import 'chat_screen.dart';
import '../utils/responsive_builder.dart';

class ChatListScreen extends StatefulWidget {
  final List<Student> students;
  final MessageSender userType;
  final String userName;

  const ChatListScreen({
    Key? key,
    required this.students,
    required this.userType,
    required this.userName,
  }) : super(key: key);

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<Student> filteredStudents = [];
  Map<String, int> unreadMessages = {};
  
  // Animation controllers for staggered animations
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    filteredStudents = List.from(widget.students);
    _searchController.addListener(_filterStudents);
    
    // Animation setup
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    _animationController.forward();
    
    // Listen for unread messages
    FirebaseService.getAllUnreadMessages(widget.userType).listen((counts) {
      setState(() {
        unreadMessages = counts;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _filterStudents() {
    setState(() {
      final query = _searchController.text.toLowerCase();
      if (query.isEmpty) {
        filteredStudents = List.from(widget.students);
      } else {
        filteredStudents = widget.students
            .where((student) =>
                student.name.toLowerCase().contains(query) ||
                (student.registrationNumber?.toLowerCase().contains(query) ?? false) ||
                (student.fatherName?.toLowerCase().contains(query) ?? false) ||
                (student.motherName?.toLowerCase().contains(query) ?? false))
            .toList();
      }
    });
  }

  void _openChat(Student student) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          student: student,
          userType: widget.userType,
          userName: widget.userName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(context),
            tooltip: 'Help',
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Search bar with responsive padding
            Padding(
              padding: EdgeInsets.all(context.spacingMd),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: context.isMobile ? 'Search...' : 'Search students...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
            
            // Student list
            Expanded(
              child: filteredStudents.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: context.isMobile ? 48 : 64,
                            color: Colors.grey.shade400,
                          ),
                          SizedBox(height: context.spacingMd),
                          Text(
                            'No students found',
                            style: TextStyle(
                              fontSize: context.isMobile ? 14 : 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(
                        vertical: context.spacingSm,
                      ),
                      itemCount: filteredStudents.length,
                      itemBuilder: (context, index) {
                        final student = filteredStudents[index];
                        final unreadCount = unreadMessages[student.id] ?? 0;
                        
                        // Create staggered animation for each list item
                        final itemAnimation = Tween<Offset>(
                          begin: const Offset(0, 0.3),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: _animationController,
                            curve: Interval(
                              0.1 + (index * 0.05).clamp(0.0, 0.6),
                              0.6 + (index * 0.05).clamp(0.0, 0.6),
                              curve: Curves.easeOutQuint,
                            ),
                          ),
                        );
                        
                        return SlideTransition(
                          position: itemAnimation,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: context.spacingSm, 
                              vertical: context.isMobile ? 2 : 4
                            ),
                            child: Card(
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: InkWell(
                                onTap: () => _openChat(student),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: context.isMobile ? 8 : 12,
                                    horizontal: context.spacingSm,
                                  ),
                                  child: Row(
                                    children: [
                                      // Avatar
                                      CircleAvatar(
                                        backgroundColor: student.period == 'Morning'
                                            ? Colors.amber.shade800
                                            : Colors.blue,
                                        radius: context.isMobile ? 20 : 24,
                                        child: Text(
                                          student.name[0].toUpperCase(),
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: context.isMobile ? 14 : 16,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: context.spacingMd),
                                      
                                      // Student info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              student.name,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: context.isMobile ? 14 : 16,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            SizedBox(height: context.spacingXs),
                                            Text(
                                              student.fatherName != null
                                                  ? 'Parent: ${student.fatherName}'
                                                  : 'Class: ${student.period}',
                                              style: TextStyle(
                                                fontSize: context.isMobile ? 12 : 14,
                                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      // Unread indicator
                                      if (unreadCount > 0)
                                        Container(
                                          padding: EdgeInsets.all(context.isMobile ? 6 : 8),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            unreadCount.toString(),
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: context.isMobile ? 10 : 12,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: EdgeInsets.all(context.spacingMd),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Message Center Help',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              SizedBox(height: context.spacingMd),
              
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: context.isDesktop ? 600 : double.infinity),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHelpItem(
                      Icons.search,
                      'Search',
                      'Use the search box to find students by name or registration number.',
                    ),
                    _buildHelpItem(
                      Icons.circle,
                      'Unread Messages',
                      'Red badge shows number of unread messages from that student\'s parents.',
                    ),
                    _buildHelpItem(
                      Icons.chat,
                      'Start Conversation',
                      'Tap on a student to view and send messages to their parents.',
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: context.spacingMd),
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
    );
  }
  
  Widget _buildHelpItem(IconData icon, String title, String description) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacingMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          SizedBox(width: context.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: context.spacingXs),
                Text(description),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 