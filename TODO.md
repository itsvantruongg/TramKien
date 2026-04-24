# Performance Optimization TODO

## Plan Overview
- Keep UI & animations exactly as-is
- Optimize rebuild scope, algorithmic complexity, and isolate heavy work

## Steps

### Step 1: `lib/screens/main_shell.dart` — Isolate nav bar, reduce blur cost
- [x] Extract bottom nav into `_BottomNavGlass` StatefulWidget with `ValueNotifier<double>` drag
- [x] Wrap nav bar in `RepaintBoundary` + reduce `sigmaX/Y` 18→10
- [x] Remove dead code `screens` list in `build()`
- [x] Keep Stack body animation unchanged

### Step 2: `lib/screens/schedule_screen.dart` — O(1) calendar lookup
- [ ] Precompute `Map<String, ({bool hasClass, bool hasExam})>` in `_MonthViewState`
- [ ] Only recompute when `lichHoc`/`lichThi` identity changes
- [ ] `_MonthGrid` does O(1) map lookup per day instead of O(n) filter

### Step 3: `lib/screens/grades_screen.dart` — Local drag state
- [ ] Extract `_ScaleToggle` drag overlay into own `StatefulWidget` with `ValueNotifier`
- [ ] Wrap `_GpaLineChart` in `RepaintBoundary`
- [ ] Reduce `AnimatedNumber` usage to hero/summary only

### Step 4: Providers — Stop cascade rebuilds
- [ ] `app_provider.dart`: Remove `addListener` on sub-providers, expose them directly
- [ ] Screens: Use `context.watch<SubProvider>()` or `Selector` instead of `watch<AppProvider>()`
- [ ] `grade_provider.dart`: Batch DB queries, use `compute()` for `_diemByKy` build

### Step 5: `lib/screens/finance_screen.dart` — Precompute grouped list
- [ ] Build grouped `Map<String, List>` in `didUpdateWidget`/memoize, not in `build()`

### Step 6: `lib/widgets/shared_widgets.dart` — Skeleton ticker optimize
- [ ] Reduce `SkeletonBox` animation duration 1200ms → 800ms
- [ ] Use single shared ticker if multiple skeletons visible

### Step 7: `lib/services/local_notification_service.dart` — Background scheduling
- [ ] Move `scheduleClasses` loop into `compute()` isolate

---

