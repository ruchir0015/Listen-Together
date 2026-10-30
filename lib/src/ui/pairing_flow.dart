import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_controller.dart';
import 'shared_ui.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DreamyBackdrop(
      child: Center(
        child: GlassPanel(
          margin: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Preparing your shared space',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Connecting to Supabase and setting up peer connection...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  late final TextEditingController _codeController;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;

    return DreamyBackdrop(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth > 760 ? 600.0 : double.infinity;
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'music_listen',
                      style: theme.textTheme.displayMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Connect with your person',
                      style: theme.textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'A private, real-time synchronized listening room shared by exactly two devices. No accounts, no cloud database uploads.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.black.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TinyPill(label: 'Real-time playback', icon: Icons.sync),
                        TinyPill(label: 'WebRTC P2P stream', icon: Icons.wifi_tethering),
                        TinyPill(label: 'Zero servers storage', icon: Icons.cloud_off),
                      ],
                    ),
                    const SizedBox(height: 32),
                    GlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Create an invite',
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Generate a private code, share it with your partner, then enter the room.',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: () {
                                  final code = controller.generatePairingCode();
                                  _codeController.text = code;
                                },
                                icon: const Icon(Icons.bolt, size: 18),
                                label: const Text('Generate'),
                              ),
                            ],
                          ),
                          if (controller.generatedPairCode != null) ...[
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: theme.colorScheme.primary.withOpacity(0.12),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.key, size: 16, color: Colors.black54),
                                      const SizedBox(width: 8),
                                      Text(
                                        () {
                                          try {
                                            return PairingToken.decode(controller.generatedPairCode!).pairId;
                                          } catch (_) {
                                            return controller.generatedPairCode!;
                                          }
                                        }(),
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 2.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    alignment: WrapAlignment.spaceEvenly,
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () {
                                          Clipboard.setData(
                                            ClipboardData(
                                              text: controller.generatedPairCode!,
                                            ),
                                          );
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Code copied to clipboard!')),
                                          );
                                        },
                                        icon: const Icon(Icons.copy, size: 16),
                                        label: const Text('Copy Code'),
                                      ),
                                      TextButton.icon(
                                        onPressed: () {
                                          Clipboard.setData(
                                            ClipboardData(text: controller.inviteLink),
                                          );
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Invite link copied!')),
                                          );
                                        },
                                        icon: const Icon(Icons.link, size: 16),
                                        label: const Text('Copy Link'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // Host enter button — the code-generator also needs a way in
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      onPressed: () {
                                        widget.controller.connectForever(
                                          controller.generatedPairCode!,
                                        );
                                      },
                                      icon: const Icon(Icons.favorite_rounded, size: 18),
                                      label: const Text('Enter Music Space'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    GlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Join a space',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Enter the invite code from your partner to link devices.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 18),
                          TextField(
                            controller: _codeController,
                            textCapitalization: TextCapitalization.characters,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              hintText: 'e.g. SOFT-4821',
                              prefixIcon: Icon(
                                Icons.key_rounded,
                                color: theme.colorScheme.primary.withOpacity(0.6),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () {
                                widget.controller.connectForever(
                                  _codeController.text,
                                );
                              },
                              icon: const Icon(Icons.favorite_rounded, size: 18),
                              label: const Text("Enter Music Space"),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ConnectionSuccessScreen extends StatelessWidget {
  const ConnectionSuccessScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DreamyBackdrop(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: GlassPanel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBE9EC),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.12),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.favorite_rounded,
                      size: 40,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "You're Connected!",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Your music room is active. Any song added to the shared queue by either of you will stream and play in perfect synchronization.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.black.withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      TinyPill(
                        label: 'Room: ${controller.pairIdLabel}',
                        icon: Icons.meeting_room_outlined,
                      ),
                      TinyPill(
                        label: 'Device ID: ${controller.deviceIdLabel.substring(0, min(15, controller.deviceIdLabel.length))}',
                        icon: Icons.smartphone,
                        tint: const Color(0xFFE0F2F1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: controller.dismissCelebration,
                      child: const Text('Enter Shared Room'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: controller.resetPairing,
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Go back and pair again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
