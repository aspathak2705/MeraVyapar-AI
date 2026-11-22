import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../domain/communication_action_model.dart';
import '../data/local_action_repository.dart';
import 'action_detail_screen.dart';

class ActionCenterScreen extends StatefulWidget {
  final LocalActionRepository actionRepository;
  final String authToken;
  final VoidCallback? onBack;

  const ActionCenterScreen({
    super.key,
    required this.actionRepository,
    required this.authToken,
    this.onBack,
  });

  @override
  State<ActionCenterScreen> createState() => _ActionCenterScreenState();
}

class _ActionCenterScreenState extends State<ActionCenterScreen> {
  late Future<List<CommunicationAction>> _actionsFuture;

  @override
  void initState() {
    super.initState();
    _refreshActions();
  }

  void _refreshActions() {
    setState(() {
      _actionsFuture = widget.actionRepository.fetchActions(merchantId: widget.authToken);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.actionCenterTitle ?? 'Merchant Action Center'),
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: l10n?.back ?? 'Back',
                onPressed: widget.onBack,
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n?.runReconciliationPass ?? 'Refresh',
            onPressed: _refreshActions,
          ),
        ],
      ),
      body: FutureBuilder<List<CommunicationAction>>(
        future: _actionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading actions: ${snapshot.error}'),
            );
          }

          final actions = snapshot.data ?? [];
          if (actions.isEmpty) {
            return Center(
              child: Text(l10n?.noActionsPending ?? 'No communication actions created yet.'),
            );
          }

          return ListView.builder(
            itemCount: actions.length,
            itemBuilder: (context, index) {
              final action = actions[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text('${action.actionType.toServerString()} (${action.channel.toServerString()})'),
                  subtitle: Text('${l10n?.state ?? 'Status'}: ${action.status.toDisplayString()}\n${action.finalContent ?? action.draftContent}'),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ActionDetailScreen(
                          actionRepository: widget.actionRepository,
                          actionId: action.id,
                          authToken: widget.authToken,
                        ),
                      ),
                    );
                    _refreshActions();
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
