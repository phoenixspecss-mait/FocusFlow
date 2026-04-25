import 'package:flutter/material.dart';
import 'package:FocusFlow/views/app_shell.dart';

// ─── Shimmer Animation Wrapper ───────────────────────────────────────────────

class _Shimmer extends StatefulWidget {
  final Widget child;
  const _Shimmer({required this.child});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _anim = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            FF.divider,
            FF.divider.withOpacity(0.45),
            FF.divider,
          ],
          stops: [
            (_anim.value - 0.4).clamp(0.0, 1.0),
            _anim.value.clamp(0.0, 1.0),
            (_anim.value + 0.4).clamp(0.0, 1.0),
          ],
        ).createShader(bounds),
        child: child!,
      ),
      child: widget.child,
    );
  }
}

// ─── Primitive Skeleton Box ───────────────────────────────────────────────────

class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: FF.divider,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ─── Progress View Skeleton ───────────────────────────────────────────────────

class ProgressViewSkeleton extends StatelessWidget {
  const ProgressViewSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          _skeletonCard(
            child: Row(
              children: [
                SkeletonBox(width: 44, height: 44, radius: 12),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 80, height: 10, radius: 6),
                    const SizedBox(height: 6),
                    SkeletonBox(width: 160, height: 18, radius: 8),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SkeletonBox(width: 30, height: 10, radius: 6),
                    const SizedBox(height: 6),
                    SkeletonBox(width: 60, height: 15, radius: 8),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _skeletonCard(
            child: Column(
              children: [
                SkeletonBox(width: 120, height: 10, radius: 6),
                const SizedBox(height: 24),
                Center(child: SkeletonBox(width: 200, height: 200, radius: 100)),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SkeletonBox(width: 50, height: 12, radius: 6),
                    const SizedBox(width: 22),
                    SkeletonBox(width: 60, height: 12, radius: 6),
                    const SizedBox(width: 22),
                    SkeletonBox(width: 40, height: 12, radius: 6),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _skeletonCard(child: _diffCardSkeleton())),
              const SizedBox(width: 10),
              Expanded(child: _skeletonCard(child: _diffCardSkeleton())),
              const SizedBox(width: 10),
              Expanded(child: _skeletonCard(child: _diffCardSkeleton())),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _skeletonCard(child: _chipSkeleton())),
              const SizedBox(width: 10),
              Expanded(child: _skeletonCard(child: _chipSkeleton())),
            ],
          ),
          const SizedBox(height: 14),
          _skeletonCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SkeletonBox(width: 140, height: 10, radius: 6),
                    SkeletonBox(width: 90, height: 10, radius: 6),
                  ],
                ),
                const SizedBox(height: 6),
                SkeletonBox(width: 80, height: 10, radius: 6),
                const SizedBox(height: 16),
                SkeletonBox(width: double.infinity, height: 95, radius: 10),
                const SizedBox(height: 14),
                SkeletonBox(width: 100, height: 10, radius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _diffCardSkeleton() => Column(
    children: [
      SkeletonBox(width: 32, height: 24, radius: 8),
      const SizedBox(height: 6),
      SkeletonBox(width: 40, height: 10, radius: 5),
    ],
  );

  Widget _chipSkeleton() => Row(
    children: [
      SkeletonBox(width: 20, height: 20, radius: 10),
      const SizedBox(width: 10),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 70, height: 9, radius: 5),
          const SizedBox(height: 4),
          SkeletonBox(width: 60, height: 13, radius: 6),
        ],
      ),
    ],
  );
}

// ─── Habits View Skeleton ─────────────────────────────────────────────────────

class HabitsViewSkeleton extends StatelessWidget {
  const HabitsViewSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            height: 6,
            decoration: BoxDecoration(
              color: FF.divider,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: 5,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, __) => _habitCardSkeleton(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _habitCardSkeleton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FF.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FF.divider),
      ),
      child: Row(
        children: [
          SkeletonBox(width: 44, height: 44, radius: 14),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 130, height: 14, radius: 7),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(7, (i) => Container(
                    margin: const EdgeInsets.only(right: 4),
                    child: SkeletonBox(width: 20, height: 20, radius: 6),
                  )),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SkeletonBox(width: 32, height: 32, radius: 10),
        ],
      ),
    );
  }
}

// ─── Profile View Skeleton ────────────────────────────────────────────────────

class ProfileViewSkeleton extends StatelessWidget {
  const ProfileViewSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          children: [
            Column(
              children: [
                SkeletonBox(width: 90, height: 90, radius: 45),
                const SizedBox(height: 14),
                SkeletonBox(width: 150, height: 20, radius: 10),
                const SizedBox(height: 8),
                SkeletonBox(width: 100, height: 12, radius: 6),
              ],
            ),
            const SizedBox(height: 24),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: List.generate(4, (_) => _skeletonCard(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SkeletonBox(width: 40, height: 24, radius: 8),
                    const SizedBox(height: 6),
                    SkeletonBox(width: 70, height: 11, radius: 6),
                  ],
                ),
              )),
            ),
            const SizedBox(height: 24),
            _sectionSkeleton(itemCount: 3),
            const SizedBox(height: 24),
            _sectionSkeleton(itemCount: 4),
          ],
        ),
      ),
    );
  }

  Widget _sectionSkeleton({required int itemCount}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonBox(width: 120, height: 14, radius: 7),
        const SizedBox(height: 12),
        ...List.generate(itemCount, (i) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: FF.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: FF.divider),
          ),
          child: Row(
            children: [
              SkeletonBox(width: 28, height: 28, radius: 8),
              const SizedBox(width: 12),
              SkeletonBox(width: 100 + (i * 20.0 % 60), height: 13, radius: 6),
              const Spacer(),
              SkeletonBox(width: 20, height: 20, radius: 5),
            ],
          ),
        )),
      ],
    );
  }
}

// ─── Feed View Skeleton ───────────────────────────────────────────────────────

class FeedViewSkeleton extends StatelessWidget {
  const FeedViewSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (_, i) => _feedCardSkeleton(i),
      ),
    );
  }

  Widget _feedCardSkeleton(int i) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FF.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FF.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonBox(width: 36, height: 36, radius: 18),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 110, height: 12, radius: 6),
                  const SizedBox(height: 5),
                  SkeletonBox(width: 70, height: 10, radius: 5),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SkeletonBox(width: double.infinity, height: 13, radius: 6),
          const SizedBox(height: 6),
          SkeletonBox(width: 220 + (i * 15.0 % 50), height: 13, radius: 6),
          if (i % 2 == 0) ...[
            const SizedBox(height: 6),
            SkeletonBox(width: 150, height: 13, radius: 6),
          ],
        ],
      ),
    );
  }
}

// ─── Tasks View Skeleton ──────────────────────────────────────────────────────

class TasksViewSkeleton extends StatelessWidget {
  const TasksViewSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _taskCardSkeleton(i),
      ),
    );
  }

  Widget _taskCardSkeleton(int i) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: FF.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FF.divider),
      ),
      child: Row(
        children: [
          SkeletonBox(width: 22, height: 22, radius: 11),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 160 + (i * 12.0 % 80), height: 14, radius: 7),
                const SizedBox(height: 6),
                SkeletonBox(width: 90, height: 10, radius: 5),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SkeletonBox(width: 60, height: 24, radius: 12),
        ],
      ),
    );
  }
}

// ─── Connected Accounts Skeleton ─────────────────────────────────────────────

class ConnectedAccountsSkeleton extends StatelessWidget {
  const ConnectedAccountsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (_, __) => _accountCardSkeleton(),
      ),
    );
  }

  Widget _accountCardSkeleton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FF.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FF.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonBox(width: 44, height: 44, radius: 12),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 80, height: 10, radius: 5),
                  const SizedBox(height: 6),
                  SkeletonBox(width: 130, height: 16, radius: 7),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SkeletonBox(width: double.infinity, height: 44, radius: 12),
        ],
      ),
    );
  }
}

// ─── Timer Settings Skeleton ──────────────────────────────────────────────────

class TimerSettingsSkeleton extends StatelessWidget {
  const TimerSettingsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: FF.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: FF.divider),
          ),
          child: Row(
            children: [
              SkeletonBox(width: 28, height: 28, radius: 8),
              const SizedBox(width: 14),
              Expanded(child: SkeletonBox(width: double.infinity, height: 14, radius: 7)),
              const SizedBox(width: 14),
              SkeletonBox(width: 60, height: 30, radius: 10),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Shared helper ────────────────────────────────────────────────────────────

Widget _skeletonCard({required Widget child, EdgeInsets? padding}) {
  return Container(
    padding: padding ?? const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: FF.card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: FF.divider),
    ),
    child: child,
  );
}