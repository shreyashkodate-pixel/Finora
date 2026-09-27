import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/dimensions.dart';
import '../../../shared/theme/typography.dart';
import '../../../shared/widgets/custom_buttons.dart';
import '../providers/case_provider.dart';

/// Displays evidence attachments and upload actions per SRS §7.5 & Stitch Screen 4.
class AttachmentListWidget extends StatelessWidget {
  final String caseId;

  const AttachmentListWidget({super.key, required this.caseId});

  IconData _getMimeIcon(String mimeType) {
    if (mimeType.contains('image')) return Icons.image_outlined;
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf_outlined;
    if (mimeType.contains('word') || mimeType.contains('document')) return Icons.description_outlined;
    if (mimeType.contains('text') || mimeType.contains('log')) return Icons.article_outlined;
    return Icons.attach_file;
  }

  @override
  Widget build(BuildContext context) {
    final caseProv = context.watch<CaseProvider>();
    final attachments = caseProv.attachments;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header & Upload Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.attach_file_rounded, size: 18, color: AppColors.primaryBlue),
                  const SizedBox(width: 8),
                  Text(
                    'Evidence Files (${attachments.length})',
                    style: AppTypography.headlineSm.copyWith(fontSize: 15),
                  ),
                ],
              ),
              CustomButtons.secondary(
                text: 'Attach File',
                icon: Icons.upload_file,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('File upload ready. Enforcing 10MB file limit / 50MB case total.'),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceSm),
          Text(
            'Accepted: .jpg, .png, .webp, .pdf, .docx, .txt, .log (max 10MB per file)',
            style: AppTypography.bodySm.copyWith(fontSize: 11, color: AppColors.textSecondaryLight),
          ),
          const Divider(height: 24, color: AppColors.borderLight),

          // Attachments list or empty state
          if (attachments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.backgroundLight,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                      ),
                      child: const Icon(Icons.folder_open, size: 24, color: AppColors.textSecondaryLight),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No evidence attachments uploaded yet',
                      style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Provide logs or screenshots to assist engineers with rapid diagnosis.',
                      style: AppTypography.bodySm.copyWith(fontSize: 12, color: AppColors.textSecondaryLight),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: attachments.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.borderLight),
              itemBuilder: (context, index) {
                final att = attachments[index];
                final timeStr = DateFormat('MMM d, yyyy').format(att.createdAt.toLocal());

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                    ),
                    child: Icon(_getMimeIcon(att.mimeType), size: 18, color: AppColors.primaryBlue),
                  ),
                  title: Text(
                    att.filename,
                    style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${att.formattedSize} • Uploaded $timeStr',
                    style: AppTypography.bodySm.copyWith(fontSize: 11, color: AppColors.textSecondaryLight),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.download_outlined, size: 18, color: AppColors.primaryBlue),
                    tooltip: 'Download evidence file',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Downloading ${att.filename}...')),
                      );
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
