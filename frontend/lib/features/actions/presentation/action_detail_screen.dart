import 'package:flutter/material.dart';
import '../domain/communication_action_model.dart';
import '../domain/communication_audit_event_model.dart';
import '../data/action_repository.dart';

class ActionDetailScreen extends StatefulWidget {
  final ActionRepository actionRepository;
  final String actionId;
  final String authToken;

  const ActionDetailScreen({
    Key? key,
    required this.actionRepository,
    required this.actionId,
    required this.authToken,
  }) : super(key: key);

  @override
  State<ActionDetailScreen> createState() => _ActionDetailScreenState();
}

class _ActionDetailScreenState extends State<ActionDetailScreen> {
  late Future<CommunicationAction> _actionFuture;
  late Future<List<CommunicationAuditEvent>> _auditFuture;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _actionFuture = widget.actionRepository.fetchActions(authToken: widget.authToken).then(
            (list) => list.firstWhere((a) => a.id == widget.actionId),
          );
      _auditFuture = widget.actionRepository.fetchAuditTrail(
        actionId: widget.actionId,
        authToken: widget.authToken,
      );
    });
  }

  Future<void> _confirmAction() async {
    setState(() => _isProcessing = true);
    try {
      await widget.actionRepository.confirmAction(
        actionId: widget.actionId,
        authToken: widget.authToken,
      );
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _dispatchAction() async {
    setState(() => _isProcessing = true);
    try {
      await widget.actionRepository.dispatchAction(
        actionId: widget.actionId,
        authToken: widget.authToken,
      );
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _cancelAction() async {
    setState(() => _isProcessing = true);
    try {
      await widget.actionRepository.cancelAction(
        actionId: widget.actionId,
        authToken: widget.authToken,
      );
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Action Details & Audit'),
      ),
      body: FutureBuilder<CommunicationAction>(
        future: _actionFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final action = snapshot.data!;
          final canConfirm = action.status == ActionStatus.draft || action.status == ActionStatus.readyForReview;
          final canDispatch = action.status == ActionStatus.confirmedByMerchant;
          final canCancel = canConfirm || canDispatch;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Channel: ${action.channel.toServerString()}'),
                        Text('Status: ${action.status.toDisplayString()}'),
                        if (action.deliveryMode != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Chip(
                                label: Text(
                                  action.deliveryMode == 'SIMULATED' ? 'DEMO / SIMULATED' : 'PRODUCTION',
                                  style: TextStyle(
                                    color: action.deliveryMode == 'SIMULATED' ? Colors.orange.shade900 : Colors.green.shade900,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                backgroundColor: action.deliveryMode == 'SIMULATED' ? Colors.orange.shade100 : Colors.green.shade100,
                              ),
                              if (action.providerName != null) ...[
                                const SizedBox(width: 8),
                                Text('Provider: ${action.providerName}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ],
                          ),
                          if (action.deliveryMode == 'SIMULATED')
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.amber.shade300),
                              ),
                              child: const Text(
                                'Note: External delivery was simulated. No real message was sent.',
                                style: TextStyle(fontSize: 12, color: Colors.black87),
                              ),
                            ),
                        ],
                        if (action.errorCode != null)
                          Text('Error Code: ${action.errorCode}', style: const TextStyle(color: Colors.red)),
                        if (action.errorMessage != null)
                          Text('Error Message: ${action.errorMessage}', style: const TextStyle(color: Colors.red)),
                        const Divider(),
                        const Text('Message Body:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(action.finalContent ?? action.draftContent),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (canConfirm)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isProcessing ? null : _confirmAction,
                          child: const Text('Confirm Action'),
                        ),
                      ),
                    if (canDispatch)
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                          onPressed: _isProcessing ? null : _dispatchAction,
                          child: const Text('Dispatch Message'),
                        ),
                      ),
                    if (canCancel) ...[
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: _isProcessing ? null : _cancelAction,
                        child: const Text('Cancel'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                Text('Audit Log', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                FutureBuilder<List<CommunicationAuditEvent>>(
                  future: _auditFuture,
                  builder: (context, auditSnapshot) {
                    if (auditSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final events = auditSnapshot.data ?? [];
                    if (events.isEmpty) {
                      return const Text('No audit events logged.');
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: events.length,
                      itemBuilder: (context, idx) {
                        final evt = events[idx];
                        return ListTile(
                          dense: true,
                          title: Text('${evt.eventType} -> ${evt.newStatus}'),
                          subtitle: Text('Actor: ${evt.actorType} | ${evt.occurredAt.toLocal()}'),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
