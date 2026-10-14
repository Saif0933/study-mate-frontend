import 'package:flutter/material.dart';
import '../../features/documents/screens/document_list_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/quizzes/screens/quiz_list_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/study_plans/screens/study_plan_screen.dart';
import '../../features/tutor/screens/conversations_screen.dart';

/// Responsive App Shell providing unified navigation across all core features.
/// Implements Android back-button interception (navigating back to Home tab before exiting)
/// and adapts between a bottom NavigationBar on mobile and a NavigationRail on wide displays.
class AppShell extends StatefulWidget {
  final int initialTab;

  const AppShell({super.key, this.initialTab = 0});

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  late int _currentTabIndex;

  @override
  void initState() {
    super.initState();
    _currentTabIndex = widget.initialTab.clamp(0, 5);
  }

  void switchTab(int index) {
    if (index >= 0 && index < 6) {
      setState(() {
        _currentTabIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      HomeScreen(onTabSelected: switchTab),
      const ConversationsScreen(),
      const DocumentListScreen(),
      const QuizListScreen(),
      const StudyPlanScreen(),
      const SettingsScreen(),
    ];

    final isWide = MediaQuery.of(context).size.width >= 720;

    // PopScope ensures pressing the Android back button when on any tab other than Home
    // switches back to the Home tab rather than abruptly closing the app.
    return PopScope(
      canPop: _currentTabIndex == 0,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        if (_currentTabIndex != 0) {
          setState(() {
            _currentTabIndex = 0;
          });
        }
      },
      child: isWide
          ? Scaffold(
              body: Row(
                children: [
                  NavigationRail(
                    selectedIndex: _currentTabIndex,
                    onDestinationSelected: switchTab,
                    labelType: NavigationRailLabelType.all,
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Icon(
                        Icons.auto_stories_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 32,
                      ),
                    ),
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home_rounded),
                        label: Text('Home'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.psychology_outlined),
                        selectedIcon: Icon(Icons.psychology_rounded),
                        label: Text('AI Tutor'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.menu_book_outlined),
                        selectedIcon: Icon(Icons.menu_book_rounded),
                        label: Text('Docs'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.quiz_outlined),
                        selectedIcon: Icon(Icons.quiz_rounded),
                        label: Text('Quiz'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.calendar_today_outlined),
                        selectedIcon: Icon(Icons.calendar_today_rounded),
                        label: Text('Planner'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.settings_outlined),
                        selectedIcon: Icon(Icons.settings_rounded),
                        label: Text('Settings'),
                      ),
                    ],
                  ),
                  const VerticalDivider(thickness: 1, width: 1),
                  Expanded(
                    child: IndexedStack(
                      index: _currentTabIndex,
                      children: tabs,
                    ),
                  ),
                ],
              ),
            )
          : Scaffold(
              body: IndexedStack(index: _currentTabIndex, children: tabs),
              bottomNavigationBar: NavigationBar(
                selectedIndex: _currentTabIndex,
                onDestinationSelected: switchTab,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.psychology_outlined),
                    selectedIcon: Icon(Icons.psychology_rounded),
                    label: 'AI Tutor',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.menu_book_outlined),
                    selectedIcon: Icon(Icons.menu_book_rounded),
                    label: 'Docs',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.quiz_outlined),
                    selectedIcon: Icon(Icons.quiz_rounded),
                    label: 'Quiz',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.calendar_today_outlined),
                    selectedIcon: Icon(Icons.calendar_today_rounded),
                    label: 'Planner',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings_rounded),
                    label: 'Settings',
                  ),
                ],
              ),
            ),
    );
  }
}
