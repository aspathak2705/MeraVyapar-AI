import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../domain/communication_action_model.dart';
import '../data/local_action_repository.dart';

class ReminderDraftScreen extends StatefulWidget {
  final LocalActionRepository actionRepository;
  final String promiseId;
  final String authToken;
  final VoidCallback? onBack;

  const ReminderDraftScreen({
    super.key,
    required this.actionRepository,
    required this.promiseId,
    required this.authToken,
    this.onBack,
  });

  @override
  State<ReminderDraftScreen> createState() => _ReminderDraftScreenState();
}

class _ReminderDraftScreenState extends State<ReminderDraftScreen> {
  final _contentController = TextEditingController();
  CommunicationAction? _action;
  bool _isLoading = true;
  bool _isSaving = false;
  final String _channel = 'WHATSAPP';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrCreateDraft();
  }

  Future<void> _loadOrCreateDraft() async {
    try {
      final action = await widget.actionRepository.draftPaymentReminder(
        promiseId: widget.promiseId,
        channel: _channel,
        merchantId: widget.authToken,
      );
      setState(() {
        _action = action;
        _contentController.text = action.finalContent ?? action.draftContent;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveDraft() async {
    if (_action == null) return;
    setState(() {
      _isSaving = true;
    });

    try {
      final updated = await widget.actionRepository.updateDraft(
        actionId: _action!.id,
        finalContent: _contentController.text,
        merchantId: widget.authToken,
      );
      setState(() {
        _action = updated;
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Draft updated & marked ready for review!')),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isSaving = false;
      });
    }
  }

  Future<void> _confirmAction() async {
    if (_action == null) return;
    setState(() {
      _isSaving = true;
    });

    try {
      final confirmed = await widget.actionRepository.confirmAction(
        actionId: _action!.id,
        merchantId: widget.authToken,
      );
      setState(() {
        _action = confirmed;
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action explicitly confirmed by merchant!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.reminderDraftTitle ?? 'Payment Reminder Draft'),
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: l10n?.back ?? 'Back',
                onPressed: widget.onBack,
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${l10n?.state ?? 'Status'}: ${_action?.status.toDisplayString()}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Edit Reminder Text:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _contentController,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Enter custom reminder message...',
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _saveDraft,
                        child: const Text('Save & Mark Ready for Review'),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        onPressed: _isSaving ? null : _confirmAction,
                        child: const Text('Explicitly Confirm Action'),
                      ),
                    ],
                  ),
                ),
    );
  }
}
