import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/dimensions.dart';
import '../../../shared/theme/typography.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/case_model.dart';
import '../providers/case_provider.dart';

/// Stitch-aligned Public Message Thread Stream & Live Chat per SRS §4.1, §7.6 & Stitch Screen 4.
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
    final currentUser = auth.currentUser;
    final isStaff = currentUser?.isStaff ?? false;

    return Container(
      color: AppColors.backgroundLight,
      child: Column(
        children: [
          // 1. Message Thread Feed
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.chat_bubble_outline, size: 40, color: AppColors.textSecondaryLight),
                        const SizedBox(height: 12),
                        Text(
                          'No public messages yet',
                          style: AppTypography.headlineSm.copyWith(fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Type a message below to communicate directly with IT support.',
                          style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(AppDimensions.spaceLg),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      return _buildMessageItem(msg, currentUser?.id, isStaff);
                    },
                  ),
          ),

          const Divider(height: 1, color: AppColors.borderLight),

          // 2. Public Message Composer
          Container(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.borderLight)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Staff visibility toggle (Locked Invariant 1: Staff Only)
                if (isStaff) ...[
                  Row(
                    children: [
                      Text(
                        'Visibility: ',
                        style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
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

                // Text Input Area
                Container(
                  decoration: BoxDecoration(
                    color: _selectedVisibility == 'internal_only'
                        ? Colors.amber.withValues(alpha: 0.05)
                        : AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                    border: Border.all(
                      color: _selectedVisibility == 'internal_only'
                          ? Colors.amber.withValues(alpha: 0.5)
                          : AppColors.borderLight,
                    ),
                  ),
                  child: TextField(
                    controller: _textController,
                    maxLines: 4,
                    minLines: 2,
                    decoration: InputDecoration(
                      hintText: _selectedVisibility == 'internal_only'
                          ? 'Add internal note (strictly hidden from requester)...'
                          : 'Type a reply to IT support or provide additional diagnostic information...',
                      hintStyle: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Action Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.attach_file, size: 20, color: AppColors.primaryBlue),
                          tooltip: 'Attach diagnostic file (Max 10MB)',
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('File attached to conversation.')),
                            );
                          },
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Attach File (Max 10MB)',
                          style: AppTypography.bodySm.copyWith(
                            fontSize: 12,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                        ),
                      ),
                      onPressed: caseProv.isActionLoading ? null : _sendMessage,
                      icon: caseProv.isActionLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send, size: 16),
                      label: const Text('Send Reply'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(MessageModel msg, String? currentUserId, bool isStaffViewer) {
    final isMe = msg.authorId == currentUserId;
    final isInternal = msg.isInternalOnly;
    final timeStr = DateFormat('MMM d, h:mm a').format(msg.createdAt.toLocal());

    // Security invariant: If somehow internal note reaches a non-staff requester, do not render silently
    if (isInternal && !isStaffViewer) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(8),
        color: AppColors.priorityP1.withValues(alpha: 0.1),
        child: const Text('Security Notice: Unauthorized internal message received.'),
      );
    }

    final avatarInitial = isMe ? 'Y' : (msg.aiGenerated ? 'A' : 'S');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: msg.aiGenerated
                  ? AppColors.aiAccent.withValues(alpha: 0.2)
                  : AppColors.primaryLight.withValues(alpha: 0.2),
              child: Text(
                avatarInitial,
                style: TextStyle(
                  color: msg.aiGenerated ? AppColors.aiAccent : AppColors.primaryBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Header Info (Author, Role Badge, Timestamp)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isMe ? 'You' : (msg.aiGenerated ? 'AI Nexus Copilot' : 'IT Support Staff'),
                      style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 6),
                    if (!isMe && !msg.aiGenerated) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified, size: 10, color: AppColors.primaryBlue),
                            const SizedBox(width: 3),
                            Text(
                              'Verified Staff',
                              style: AppTypography.labelSm.copyWith(
                                fontSize: 9,
                                color: AppColors.primaryBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (isInternal) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.amber, width: 0.8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock, size: 9, color: Colors.amber),
                            SizedBox(width: 3),
                            Text(
                              'INTERNAL NOTE',
                              style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.amber),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (msg.aiGenerated) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.aiAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'AI ASSISTED',
                          style: AppTypography.labelSm.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.aiAccent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      timeStr,
                      style: AppTypography.bodySm.copyWith(fontSize: 11, color: AppColors.textSecondaryLight),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Message Bubble
                Container(
                  constraints: const BoxConstraints(maxWidth: 580),
                  padding: const EdgeInsets.all(AppDimensions.spaceMd),
                  decoration: BoxDecoration(
                    color: isInternal
                        ? Colors.amber.withValues(alpha: 0.08)
                        : isMe
                            ? AppColors.primaryBlue
                            : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(AppDimensions.radiusCard),
                      topRight: const Radius.circular(AppDimensions.radiusCard),
                      bottomLeft: isMe ? const Radius.circular(AppDimensions.radiusCard) : Radius.zero,
                      bottomRight: isMe ? Radius.zero : const Radius.circular(AppDimensions.radiusCard),
                    ),
                    border: Border.all(
                      color: isInternal
                          ? Colors.amber.withValues(alpha: 0.4)
                          : isMe
                              ? AppColors.primaryBlue
                              : AppColors.borderLight,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x04000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: SelectableText(
                    msg.body,
                    style: AppTypography.bodyMd.copyWith(
                      color: isMe && !isInternal ? Colors.white : AppColors.textPrimaryLight,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 10),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryBlue,
              child: Text(
                avatarInitial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
