import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../state/app_controller.dart';
import '../services/webrtc_service.dart';
import 'pairing_flow.dart';
import 'shared_ui.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});

  final AppController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return DreamyBackdrop(
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  Expanded(
                    child: IndexedStack(
                      index: _currentIndex,
                      children: [
                        HomeTab(controller: widget.controller),
                        QueueTab(controller: widget.controller),
                        AddSongsTab(controller: widget.controller),
                        SpaceTab(controller: widget.controller),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_currentIndex != 0) // Miniplayer only on other tabs
                    MiniPlayerBar(controller: widget.controller, onTap: () {
                      setState(() {
                        _currentIndex = 0;
                      });
                    }),
                  const SizedBox(height: 12),
                  // Sleek Bottom Navigation Bar
                  GlassPanel(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    borderRadius: BorderRadius.circular(20),
                    child: NavigationBar(
                      selectedIndex: _currentIndex,
                      onDestinationSelected: (value) {
                        setState(() {
                          _currentIndex = value;
                        });
                      },
                      destinations: const [
                        NavigationDestination(
                          icon: Icon(Icons.play_circle_outline_rounded),
                          selectedIcon: Icon(Icons.play_circle_filled_rounded),
                          label: 'Playing',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.format_list_bulleted_rounded),
                          selectedIcon: Icon(Icons.queue_music_rounded),
                          label: 'Queue',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.add_circle_outline_rounded),
                          selectedIcon: Icon(Icons.add_circle_rounded),
                          label: 'Add Songs',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.blur_on_rounded),
                          selectedIcon: Icon(Icons.blur_circular_rounded),
                          label: 'Space',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ==========================================
// 1. HOME TAB (NOW PLAYING SCREEN)
// ==========================================
class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final song = controller.currentSong;
    final theme = Theme.of(context);

    // Unified connection/presence status chip
    final isPaired = controller.isPaired;
    final partnerOnline = controller.partnerOnline;
    final webrtcState = controller.webRTCState;
    final isStreaming = controller.isStreaming;

    Color stateColor;
    String stateLabel;
    if (!isPaired) {
      stateColor = Colors.grey;
      stateLabel = 'Solo Mode';
    } else if (partnerOnline) {
      if (webrtcState == WebRTCConnState.connected) {
        stateColor = const Color(0xFF4CAF50);
        stateLabel = 'Partner Here ✦';
      } else if (webrtcState == WebRTCConnState.connecting) {
        stateColor = Colors.amber;
        stateLabel = 'Syncing...';
      } else {
        stateColor = Colors.amber;
        stateLabel = 'Partner Here';
      }
    } else {
      stateColor = Colors.amber;
      stateLabel = 'Waiting for Partner';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Constrain artwork: at most 42% of available height or 300dp
        final artworkDim = min(
          min(constraints.maxWidth - 48.0, constraints.maxHeight * 0.42),
          300.0,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar: App name + connection chip
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'music_listen',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: !isPaired
                      ? () {
                          // Tapping the chip in solo mode navigates to Space tab
                          // The AppShell handles tab switching via its own state,
                          // so we just show a hint snackbar.
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Go to the Space tab to invite a partner ❤'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: stateColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: stateColor.withValues(alpha: 0.3), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(color: stateColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            stateLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: stateColor.darken(),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Album Artwork — size-constrained to prevent overflow
            Center(
              child: SizedBox(
                width: artworkDim,
                height: artworkDim,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                          color: Colors.black.withValues(alpha: 0.06),
                        ),
                      ],
                    ),
                    child: GlassPanel(
                      padding: EdgeInsets.zero,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(seconds: 2),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: controller.isPlaying
                                    ? [const Color(0xFFFBE9EC), const Color(0xFFE0F2F1)]
                                    : [const Color(0xFFFAF8F5), const Color(0xFFE8EAF6)],
                              ),
                            ),
                          ),
                          Opacity(
                            opacity: 0.15,
                            child: Icon(
                              Icons.album_rounded,
                              size: artworkDim * 0.6,
                              color: Colors.black,
                            ),
                          ),
                          if (controller.isBuffering || (song != null && !song.isOwner(controller.deviceIdLabel) && isStreaming))
                            Container(
                              color: Colors.white.withValues(alpha: 0.5),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CircularProgressIndicator(strokeWidth: 3),
                                    const SizedBox(height: 12),
                                    Text(
                                      controller.streamStatus.isNotEmpty ? controller.streamStatus : 'Syncing room...',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      textAlign: TextAlign.center,
                                    ),
                                    if (controller.streamProgress > 0 && controller.streamProgress < 1) ...[
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: 120,
                                        child: LinearProgressIndicator(
                                          value: controller.streamProgress,
                                          minHeight: 4,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                      Text(
                                        '${(controller.streamProgress * 100).round()}%',
                                        style: const TextStyle(fontSize: 10, color: Colors.black54),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            )
                          else if (song == null)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.music_off_outlined, size: artworkDim * 0.3, color: Colors.black26),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Playback queue is empty',
                                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54, fontSize: 13),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Track info + controls (only when a song is loaded)
            if (song != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Text(
                      song.title,
                      style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      song.artist,
                      style: theme.textTheme.titleSmall?.copyWith(color: Colors.black54, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    TinyPill(
                      label: song.isOwner(controller.deviceIdLabel) ? 'Added by You' : 'Added by Partner',
                      icon: Icons.person_pin_rounded,
                      tint: song.isOwner(controller.deviceIdLabel)
                          ? theme.colorScheme.primary.withValues(alpha: 0.08)
                          : theme.colorScheme.secondary.withValues(alpha: 0.08),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Progress slider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    Slider(
                      value: controller.progressFraction,
                      onChanged: controller.isBuffering ? null : controller.seekToFraction,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(formatDuration(controller.elapsed), style: const TextStyle(fontSize: 12)),
                          Text(formatDuration(song.duration), style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Transport controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 28,
                    onPressed: controller.isBuffering ? null : controller.previousTrack,
                    icon: const Icon(Icons.skip_previous_rounded),
                  ),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: controller.isBuffering ? null : controller.togglePlayPause,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        controller.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 34,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    iconSize: 28,
                    onPressed: controller.isBuffering ? null : () => controller.nextTrack(),
                    icon: const Icon(Icons.skip_next_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ] else ...[
              Expanded(
                child: Center(
                  child: EmptyStateCard(
                    title: 'Nothing playing',
                    body: isPaired
                        ? 'Go to "Add Songs" to queue tracks for you and your partner.'
                        : 'Go to "Add Songs" to start listening solo, or open the Space tab to invite a partner.',
                    icon: Icons.queue_music_rounded,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ==========================================
// 2. QUEUE TAB (SHARED PLAYBACK QUEUE)
// ==========================================
class QueueTab extends StatelessWidget {
  const QueueTab({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final queue = controller.queue;
    final currentIndex = controller.playbackSession?.currentIndex ?? 0;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Shared Queue',
          subtitle: 'Reorder or modify the room soundtrack in real-time.',
        ),
        const SizedBox(height: 18),
        Expanded(
          child: queue.isEmpty
              ? Center(
                  child: EmptyStateCard(
                    title: 'Your queue is empty',
                    body: 'Browse files on your phone in the "Add Songs" tab to start playing.',
                    icon: Icons.queue_music_rounded,
                  ),
                )
              : ReorderableListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: queue.length,
                  onReorder: controller.reorderQueue,
                  itemBuilder: (context, index) {
                    final song = queue[index];
                    final isCurrent = index == currentIndex;

                    return KeyedSubtree(
                      key: ValueKey(song.id),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? theme.colorScheme.primary.withOpacity(0.08)
                                : Colors.white.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isCurrent
                                  ? theme.colorScheme.primary.withOpacity(0.2)
                                  : Colors.white.withOpacity(0.4),
                              width: 1,
                            ),
                          ),
                          child: ListTile(
                            leading: Icon(
                              isCurrent ? Icons.graphic_eq_rounded : Icons.drag_handle_rounded,
                              color: isCurrent ? theme.colorScheme.primary : Colors.black26,
                            ),
                            title: Text(
                              song.title,
                              style: TextStyle(
                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              '${song.artist} • ${formatDuration(song.duration)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TinyPill(
                                  label: song.isOwner(controller.deviceIdLabel) ? 'You' : 'Partner',
                                  tint: song.isOwner(controller.deviceIdLabel)
                                      ? theme.colorScheme.primary.withOpacity(0.1)
                                      : theme.colorScheme.secondary.withOpacity(0.1),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                                  onPressed: () => controller.removeSongFromQueue(index),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ==========================================
// 3. ADD SONGS TAB (POLISHED LOCAL PICKER)
// ==========================================
class AddSongsTab extends StatefulWidget {
  const AddSongsTab({super.key, required this.controller});

  final AppController controller;

  @override
  State<AddSongsTab> createState() => _AddSongsTabState();
}

class _AddSongsTabState extends State<AddSongsTab> {
  String _searchQuery = '';
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localSongs = widget.controller.localSongs;
    final theme = Theme.of(context);

    // Fast search filter
    final filteredSongs = localSongs.where((song) {
      final query = _searchQuery.toLowerCase();
      return song.title.toLowerCase().contains(query) ||
          song.artist.toLowerCase().contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Local Library',
          subtitle: 'Tap "+" to instantly add files to the shared queue.',
          action: FilledButton.icon(
            onPressed: widget.controller.isImporting
                ? null
                : () => importSongsWithFeedback(context, widget.controller),
            icon: Icon(
              widget.controller.isImporting ? Icons.hourglass_top_rounded : Icons.file_open_rounded,
              size: 16,
            ),
            label: Text(widget.controller.isImporting ? 'Importing...' : 'Import Files'),
          ),
        ),
        const SizedBox(height: 18),

        // Search Bar input
        TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          decoration: InputDecoration(
            hintText: 'Search title or artist...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
          ),
        ),
        const SizedBox(height: 18),

        // Songs list
        Expanded(
          child: localSongs.isEmpty
              ? Center(
                  child: EmptyStateCard(
                    title: 'No audio files imported',
                    body: 'Tap "Import Files" to select audio tracks from your phone\'s local storage.',
                    icon: Icons.audio_file_outlined,
                    action: FilledButton.icon(
                      onPressed: widget.controller.isImporting
                          ? null
                          : () => importSongsWithFeedback(context, widget.controller),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Select Audio Files'),
                    ),
                  ),
                )
              : filteredSongs.isEmpty
                  ? const Center(
                      child: Text(
                        'No matching songs found.',
                        style: TextStyle(color: Colors.black45),
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: filteredSongs.length,
                      itemBuilder: (context, index) {
                        final song = filteredSongs[index];

                        return Padding(
                          key: ValueKey(song.id),
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.35),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.4),
                                width: 1,
                              ),
                            ),
                            child: ListTile(
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.music_note_rounded,
                                  color: theme.colorScheme.primary.withOpacity(0.8),
                                ),
                              ),
                              title: Text(
                                song.title,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                song.artist,
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    formatDuration(song.duration),
                                    style: const TextStyle(fontSize: 12, color: Colors.black45),
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline_rounded),
                                    color: theme.colorScheme.primary,
                                    onPressed: () {
                                      widget.controller.addSongToQueue(song);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('"${song.title}" queued!'),
                                          duration: const Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// ==========================================
// 4. SPACE TAB — LOBBY + PAIRING + ROOM STATS
// ==========================================
class SpaceTab extends StatefulWidget {
  const SpaceTab({super.key, required this.controller});

  final AppController controller;

  @override
  State<SpaceTab> createState() => _SpaceTabState();
}

class _SpaceTabState extends State<SpaceTab> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final theme = Theme.of(context);
    final isPaired = controller.isPaired;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: isPaired ? 'Room Lobby' : 'Shared Space',
          subtitle: isPaired
              ? 'Your private listening room is active.'
              : 'Invite a partner or join their room to listen together.',
        ),
        const SizedBox(height: 20),
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            children: [
              // ── Lobby presence cards ──
              if (isPaired) ..._buildLobbyCards(context, controller, theme),

              // ── Not paired: show pairing UI ──
              if (!isPaired) ..._buildPairingCards(context, controller, theme),

              // ── Connected room stats ──
              if (isPaired) ..._buildRoomStats(context, controller, theme),

              // ── Danger zone ──
              if (isPaired) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => showResetPairingDialog(context, controller),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Leave Room'),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildLobbyCards(BuildContext context, AppController controller, ThemeData theme) {
    final partnerOnline = controller.partnerOnline;
    return [
      // Your device card
      GlassPanel(
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.smartphone_rounded, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('You', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  Text(
                    controller.deviceIdLabel.length > 20
                        ? '${controller.deviceIdLabel.substring(0, 20)}...'
                        : controller.deviceIdLabel,
                    style: const TextStyle(fontSize: 12, color: Colors.black45),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('In Room', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF388E3C))),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      // Partner card
      GlassPanel(
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: partnerOnline
                    ? theme.colorScheme.secondary.withValues(alpha: 0.15)
                    : Colors.grey.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                partnerOnline ? Icons.person_rounded : Icons.person_outline_rounded,
                color: partnerOnline ? theme.colorScheme.secondary : Colors.grey,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    partnerOnline ? 'Partner' : 'Waiting for Partner...',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: partnerOnline ? Colors.black87 : Colors.black45,
                    ),
                  ),
                  Text(
                    partnerOnline
                        ? (controller.partnerDeviceId ?? 'Connected')
                        : 'Share the room code so they can join',
                    style: const TextStyle(fontSize: 12, color: Colors.black45),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (partnerOnline)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('In Room', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF388E3C))),
              )
            else
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Waiting', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.orange)),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      // Room ID chip
      GlassPanel(
        child: Row(
          children: [
            Icon(Icons.meeting_room_outlined, color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Room ID', style: TextStyle(fontSize: 11, color: Colors.black45, fontWeight: FontWeight.w600)),
                  Text(
                    controller.pairIdLabel,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: controller.pairIdLabel));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Room ID copied!'), duration: Duration(seconds: 1)),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
    ];
  }

  List<Widget> _buildPairingCards(BuildContext context, AppController controller, ThemeData theme) {
    return [
      // Generate code card
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
                      Text('Create a Room', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Generate a code, share it, then both enter.',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () {
                    controller.generatePairingCode();
                  },
                  icon: const Icon(Icons.bolt, size: 18),
                  label: const Text('Generate'),
                ),
              ],
            ),
            if (controller.generatedPairCode != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.12)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.key, size: 14, color: Colors.black54),
                        const SizedBox(width: 6),
                        Text(
                          () {
                            try { return PairingToken.decode(controller.generatedPairCode!).pairId; } catch (_) { return controller.generatedPairCode!; }
                          }(),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 2.0),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: controller.generatedPairCode!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Code copied!'), duration: Duration(seconds: 1)),
                              );
                            },
                            icon: const Icon(Icons.copy, size: 14),
                            label: const Text('Copy Code'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => controller.connectForever(controller.generatedPairCode!),
                            icon: const Icon(Icons.favorite_rounded, size: 14),
                            label: const Text('Enter Room'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      // Join code card
      GlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Join a Room', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Enter the code your partner sent you.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'e.g. SOFT-4821',
                prefixIcon: Icon(Icons.key_rounded, color: theme.colorScheme.primary.withValues(alpha: 0.6)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  if (_codeController.text.trim().isNotEmpty) {
                    controller.connectForever(_codeController.text);
                  }
                },
                icon: const Icon(Icons.favorite_rounded, size: 16),
                label: const Text('Enter Music Space'),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
    ];
  }

  List<Widget> _buildRoomStats(BuildContext context, AppController controller, ThemeData theme) {
    final webrtcState = controller.webRTCState;
    return [
      GlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Connection Details', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            _buildStatRow('WebRTC P2P', webrtcState.name.toUpperCase(),
                valueColor: webrtcState == WebRTCConnState.connected ? const Color(0xFF4CAF50) : Colors.grey),
            _buildStatRow('Supabase', controller.activeSupabaseUrl != null ? 'Configured' : 'Not set',
                valueColor: controller.activeSupabaseUrl != null ? const Color(0xFF4CAF50) : Colors.redAccent),
          ],
        ),
      ),
      const SizedBox(height: 12),
      GlassPanel(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Supabase Backend', style: theme.textTheme.titleSmall),
            IconButton(
              onPressed: () => showEditBackendCredentialsDialog(context, controller),
              icon: const Icon(Icons.edit_rounded, size: 18),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
    ];
  }

  void showEditBackendCredentialsDialog(BuildContext context, AppController controller) {
    final urlCtrl = TextEditingController(text: controller.ownerSupabaseUrl);
    final keyCtrl = TextEditingController(text: controller.ownerSupabaseAnonKey);
    final formKey = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Backend Config', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: urlCtrl,
                decoration: const InputDecoration(labelText: 'Supabase URL'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: keyCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Anon Key'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              await controller.updateCredentials(urlCtrl.text.trim(), keyCtrl.text.trim());
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Backend updated!')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black54, fontSize: 13)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: valueColor ?? Colors.black87, fontSize: 13)),
        ],
      ),
    );
  }
}

// ==========================================
// COMPONENT: MINI PLAYER BAR
// ==========================================
class MiniPlayerBar extends StatelessWidget {
  const MiniPlayerBar({super.key, required this.controller, required this.onTap});

  final AppController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final song = controller.currentSong;
    if (song == null) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            blurRadius: 20,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(0.03),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: onTap,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.music_note_rounded,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        song.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        song.artist,
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_previous_rounded),
                  onPressed: controller.isBuffering ? null : controller.previousTrack,
                ),
                IconButton(
                  icon: Icon(controller.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                  color: theme.colorScheme.primary,
                  onPressed: controller.isBuffering ? null : controller.togglePlayPause,
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next_rounded),
                  onPressed: controller.isBuffering ? null : () => controller.nextTrack(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// UTILITY FUNCTIONS
// ==========================================
String formatDuration(Duration duration) {
  if (duration.inSeconds <= 0) return '00:00';
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

Future<void> importSongsWithFeedback(BuildContext context, AppController controller) async {
  final count = await controller.importLocalSongs();
  if (!context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  if (count == 0) {
    messenger.showSnackBar(
      const SnackBar(content: Text('No new audio files were added.')),
    );
  } else {
    messenger.showSnackBar(
      SnackBar(content: Text('Imported $count new local songs.')),
    );
  }
}

Future<void> showResetPairingDialog(BuildContext context, AppController controller) async {
  final check = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Reset Connection?'),
        content: const Text(
          'This will unlink this device from the shared space. Your imported local songs will remain in library storage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Disconnect'),
          ),
        ],
      );
    },
  );

  if (check == true) {
    await controller.resetPairing();
  }
}

// Extends Color class with darken helper for text tints
extension ColorDarken on Color {
  Color darken([double amount = .15]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}
