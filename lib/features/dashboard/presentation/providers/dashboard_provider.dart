import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardState {
  final int selectedIndex;
  final bool isSidebarExpanded;

  DashboardState({
    this.selectedIndex = 0,
    this.isSidebarExpanded = true,
  });

  DashboardState copyWith({
    int? selectedIndex,
    bool? isSidebarExpanded,
  }) {
    return DashboardState(
      selectedIndex: selectedIndex ?? this.selectedIndex,
      isSidebarExpanded: isSidebarExpanded ?? this.isSidebarExpanded,
    );
  }
}

class DashboardNotifier extends Notifier<DashboardState> {
  @override
  DashboardState build() {
    return DashboardState();
  }

  void setIndex(int index) {
    state = state.copyWith(selectedIndex: index);
  }

  void toggleSidebar() {
    state = state.copyWith(isSidebarExpanded: !state.isSidebarExpanded);
  }
}

final dashboardProvider = NotifierProvider<DashboardNotifier, DashboardState>(() {
  return DashboardNotifier();
});
