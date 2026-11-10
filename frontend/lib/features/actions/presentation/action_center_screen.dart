import 'package:flutter/material.dart';
import '../domain/communication_action_model.dart';
import '../data/local_action_repository.dart';
import 'action_detail_screen.dart';

class ActionCenterScreen extends StatefulWidget {
  final LocalActionRepository actionRepository;
  final String authToken;
  final VoidCallback? onBack;

  const ActionCenterScreen({
    Key? key,
    required this.actionRepository,
    required this.authToken,
    this.onBack,
  }) : super(key: key);

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Merchant Action Center'),
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
                onPressed: widget.onBack,
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
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
            return const Center(
              child: Text('No communication actions created yet.'),
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
                  subtitle: Text('Status: ${action.status.toDisplayString()}\n${action.finalContent ?? action.draftContent}'),
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
