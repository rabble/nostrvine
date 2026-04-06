import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/live_chat/live_chat_bloc.dart';

class LiveChatPanel extends StatefulWidget {
  const LiveChatPanel({
    super.key,
  });

  @override
  State<LiveChatPanel> createState() => _LiveChatPanelState();
}

class _LiveChatPanelState extends State<LiveChatPanel> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: VineTheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chat',
            style: VineTheme.titleLargeFont(),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: BlocBuilder<LiveChatBloc, LiveChatState>(
              builder: (context, state) {
                if (state.status == LiveChatStatus.loading) {
                  return const Center(
                    child: CircularProgressIndicator(color: VineTheme.primary),
                  );
                }

                if (state.messages.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet. Break the silence.',
                      style: VineTheme.bodyMediumFont(
                        color: VineTheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: state.messages.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final message = state.messages[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: VineTheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message.pubkey,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: VineTheme.labelLargeFont(
                              color: VineTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            message.content,
                            style: VineTheme.bodyMediumFont(),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: VineTheme.bodyMediumFont(),
                  decoration: InputDecoration(
                    hintText: 'Say something',
                    hintStyle: VineTheme.bodyMediumFont(
                      color: VineTheme.onSurfaceVariant,
                    ),
                    filled: true,
                    fillColor: VineTheme.surfaceContainer,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              BlocBuilder<LiveChatBloc, LiveChatState>(
                builder: (context, state) {
                  return DivineButton(
                    label: 'Send',
                    onPressed: state.isSending
                        ? null
                        : () {
                            context.read<LiveChatBloc>().add(
                              LiveChatMessageSendRequested(_controller.text),
                            );
                            _controller.clear();
                          },
                    isLoading: state.isSending,
                    size: DivineButtonSize.small,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
