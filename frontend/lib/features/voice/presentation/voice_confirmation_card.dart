import 'package:flutter/material.dart';
import '../domain/voice_models.dart';

class VoiceConfirmationCard extends StatelessWidget {
  final VoiceCandidateActionModel candidate;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final bool isProcessing;

  const VoiceConfirmationCard({
    super.key,
    required this.candidate,
    required this.onConfirm,
    required this.onCancel,
    this.isProcessing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFFDE047), width: 1.5),
      ),
      color: const Color(0xFFFEFCE8),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF08A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.security,
                    color: Color(0xFF854D0E),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Voice Mutation Proposal',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF713F12),
                        ),
                      ),
                      Text(
                        'Requires your explicit confirmation',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFA16207),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Action', 'Draft & Send Payment Reminder'),
            const SizedBox(height: 8),
            _buildDetailRow('Customer', candidate.counterpartyName),
            const SizedBox(height: 8),
            _buildDetailRow('Amount', '₹${candidate.amount}'),
            const SizedBox(height: 8),
            _buildDetailRow('Channel', candidate.channel.toUpperCase()),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isProcessing ? null : onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF713F12),
                      side: const BorderSide(color: Color(0xFFCA8A04)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isProcessing ? null : onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF15803D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: isProcessing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Confirm Action'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF854D0E),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF451A03),
          ),
        ),
      ],
    );
  }
}
