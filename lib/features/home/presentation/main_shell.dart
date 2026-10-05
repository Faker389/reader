import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/motion.dart';

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _destinations = [
  _Destination('Home', Icons.home_outlined, Icons.home_rounded),
  _Destination('Library', Icons.auto_stories_outlined, Icons.auto_stories_rounded),
  _Destination('Statistics', Icons.insights_outlined, Icons.insights_rounded),
  _Destination('Achievements', Icons.emoji_events_outlined, Icons.emoji_events_rounded),
  _Destination('Profile', Icons.person_outline_rounded, Icons.person_rounded),
];

/// App frame: a floating bottom bar on phones, a navigation rail on tablets.
class MainShell extends StatelessWidget {
  const MainShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  void _go(int index) => shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= LayoutConstants.tabletBreakpoint;
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: _go,
              labelType: NavigationRailLabelType.all,
              backgroundColor: context.colors.background,
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
            VerticalDivider(width: 0.5, thickness: 0.5, color: context.colors.border),
            Expanded(child: shell),
          ],
        ),
      );
    }
    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: _BottomBar(index: shell.currentIndex, onSelected: _go),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.index, required this.onSelected});

  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: LayoutConstants.bottomNavHeight,
              decoration: BoxDecoration(
                color: c.card.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: c.border.withValues(alpha: 0.6), width: 0.5),
              ),
              child: Row(
                children: [
                  for (var i = 0; i < _destinations.length; i++)
                    Expanded(
                      child: _NavItem(
                        destination: _destinations[i],
                        selected: i == index,
                        onTap: () => onSelected(i),
                      ),
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

class _NavItem extends StatelessWidget {
  const _NavItem({required this.destination, required this.selected, required this.onTap});

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 32,
        highlightShape: BoxShape.circle,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: context.motion(MotionConstants.medium),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(horizontal: selected ? 16 : 10, vertical: 5),
              decoration: BoxDecoration(
                color: selected ? c.accent.withValues(alpha: 0.18) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                selected ? destination.selectedIcon : destination.icon,
                size: 22,
                color: selected ? c.accent : c.muted,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              destination.label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: context.text.labelMedium?.copyWith(
                fontSize: 10.5,
                letterSpacing: 0,
                color: selected ? c.text : c.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom padding that keeps scrolled content clear of the floating bar.
double shellBottomInset(BuildContext context) {
  final wide = MediaQuery.sizeOf(context).width >= LayoutConstants.tabletBreakpoint;
  if (wide) return 24;
  return LayoutConstants.bottomNavHeight + MediaQuery.paddingOf(context).bottom + 28;
}
