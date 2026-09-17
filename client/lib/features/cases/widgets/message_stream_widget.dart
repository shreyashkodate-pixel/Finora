import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../shared/theme/colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/case_model.dart';
import '../providers/case_provider.dart';

/// Message Thread Stream with requester-visible and internal-only note segregation per SRS §4.1 & §7.6.
class MessageStreamWidget extends StatefulWidget {
  final String caseId;

  const MessageStreamWidget({super.key, required this.caseId});

  @override
  State<MessageStreamWidget> createState() => _MessageStreamWidgetState();
}

class _MessageStreamWidgetState extends State<MessageStreamWidget> {
  final _textController = TextEditingController();
  String _selectedVisibility = 'requester_visible';

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final caseProv = context.read<CaseProvider>();
    final success = await caseProv.addMessage(
      caseId: widget.caseId,
      body: text,
      visibility: _selectedVisibility,
    );
    if (success && mounted) {
      _textController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final caseProv = context.watch<CaseProvider>();
    final auth = context.watch<AuthProvider>();
    final messages = caseProv.messages;
    final isStaff = auth.currentUser?.isStaff ?? false;

    return Column(
      children: [
        // Message list
        Expanded(
          child: messages.isEmpty
              ? const Center(
                  child: Text(
                    'No messages yet. Start the conversation below.',
                    style: TextStyle(color: AppColors.textSecondaryLight),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    return _buildMessageItem(msg, auth.currentUser?.id);
                  },
                ),
        ),

        const Divider(height: 1, color: AppColors.borderLight),

        // Input & Controls
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Theme.of(context).cardTheme.color,
          child: Column(
            children: [
              // Staff visibility toggle (Requester Visible vs Internal Note)
              if (isStaff) ...[
                Row(
                  children: [
                    const Text('Visibility: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ChoiceChip(
                      label: const Text('Public Reply', style: TextStyle(fontSize: 12)),
                      selected: _selectedVisibility == 'requester_visible',
                      onSelected: (val) {
                        if (val) setState(() => _selectedVisibility = 'requester_visible');
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      avatar: const Icon(Icons.lock_outline, size: 14),
                      label: const Text('Internal Note', style: TextStyle(fontSize: 12)),
                      selected: _selectedVisibility == 'internal_only',
                      selectedColor: Colors.amber.withValues(alpha: 0.2),
                      onSelected: (val) {
                        if (val) setState(() => _selectedVisibility = 'internal_only');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // Message Input Box
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      maxLines: 4,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: _selectedVisibility == 'internal_only'
                            ? 'Add internal note (hidden from requester)...'
                            : 'Type your message to the requester...',
                        fillColor: _selectedVisibility == 'internal_only'
                            ? Colors.amber.withValues(alpha: 0.05)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: caseProv.isActionLoading ? null : _sendMessage,
                    icon: caseProv.isActionLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send),
                    tooltip: 'Send message',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageItem(MessageModel msg, String? currentUserId) {
    final isMe = msg.authorId == currentUserId;
    final isInternal = msg.isInternalOnly;
    final timeStr = DateFormat('MMM d, h:mm a').format(msg.createdAt.toLocal());

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Header info
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isInternal) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.amber, width: 0.8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock, size: 10, color: Colors.amber),
                      SizedBox(width: 4),
                      Text(
                        'INTERNAL NOTE',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (msg.aiGenerated) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.aiAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'AI DRAFTED',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.aiAccent),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                timeStr,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Message bubble
          Container(
            constraints: const BoxConstraints(maxWidth: 560),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isInternal
                  ? Colors.amber.withValues(alpha: 0.08)
                  : isMe
                      ? AppColors.primaryBlue.withValues(alpha: 0.08)
                      : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isInternal
                    ? Colors.amber.withValues(alpha: 0.4)
                    : AppColors.borderLight,
              ),
            ),
            child: SelectableText(
              msg.body,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
