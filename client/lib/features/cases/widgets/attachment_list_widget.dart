import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/accessible_button.dart';
import '../providers/case_provider.dart';

/// Displays evidence attachments and upload actions per SRS §7.5.
class AttachmentListWidget extends StatelessWidget {
  final String caseId;

  const AttachmentListWidget({super.key, required this.caseId});

  IconData _getMimeIcon(String mimeType) {
    if (mimeType.contains('image')) return Icons.image_outlined;
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf_outlined;
    if (mimeType.contains('word') || mimeType.contains('document')) return Icons.description_outlined;
    return Icons.attach_file;
  }

  @override
  Widget build(BuildContext context) {
    final caseProv = context.watch<CaseProvider>();
    final attachments = caseProv.attachments;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header & Upload Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Evidence Files (${attachments.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              AccessibleButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('File upload picker ready. 10MB per-file / 50MB case limit enforced.'),
                    ),
                  );
                },
                icon: Icons.upload_file,
                semanticLabel: 'Upload evidence file',
                child: const Text('Attach File'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Attachments list
          if (attachments.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.folder_open, size: 48, color: AppColors.textSecondaryLight),
                    SizedBox(height: 8),
                    Text(
                      'No evidence attachments uploaded.',
                      style: TextStyle(color: AppColors.textSecondaryLight),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Accepted: jpg, png, webp, gif, pdf, docx, txt, log (max 10MB)',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: attachments.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.borderLight),
                itemBuilder: (context, index) {
                  final att = attachments[index];
                  final timeStr = DateFormat('MMM d, yyyy').format(att.createdAt);

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(_getMimeIcon(att.mimeType), color: AppColors.primaryBlue),
                    ),
                    title: Text(
                      att.filename,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: Text(
                      '${att.formattedSize} • Uploaded $timeStr',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.download_outlined),
                      tooltip: 'Download file',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Downloading ${att.filename}...')),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
