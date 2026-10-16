import 'package:flutter/material.dart';

import 'features/metronome/metronome_engine.dart';
import 'features/metronome/metronome_page.dart';
import 'features/tuner/pitch_engine.dart';
import 'features/tuner/tuner_page.dart';

class GuitarToolsApp extends StatelessWidget {
  const GuitarToolsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '吉他工具',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D4F),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D4F),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  final PitchEngine _pitch = PitchEngine();
  final MetronomeEngine _metro = MetronomeEngine();

  bool get _tunerVisible => _index == 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _metro.init();
    _syncMic();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pitch.dispose();
    _metro.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncMic();
    } else {
      _pitch.stop();
    }
  }

  void _syncMic() {
    if (_tunerVisible) {
      _pitch.start();
    } else {
      _pitch.stop();
    }
  }

  Future<void> _onTabChanged(int i) async {
    if (i == _index) return;
    if (i == 0) {
      await _metro.stop();
      if (!mounted) return;
      setState(() => _index = i);
      await _pitch.start();
    } else {
      await _pitch.stop();
      if (!mounted) return;
      setState(() => _index = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          TunerPage(engine: _pitch),
          MetronomePage(engine: _metro),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onTabChanged,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.music_note_outlined),
            selectedIcon: Icon(Icons.music_note),
            label: '调音器',
          ),
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer),
            label: '节拍器',
          ),
        ],
      ),
    );
  }
}
