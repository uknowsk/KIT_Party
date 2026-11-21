import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../ui/theme.dart';
import 'push.dart';
import 'release.dart';
import 'updater.dart';

/// 앱을 열거나 다시 볼 때, 그리고 업데이트 알림을 눌렀을 때
/// 새 버전이 있으면 업데이트 창을 띄워요.
class UpdateWatcher extends StatefulWidget {
  const UpdateWatcher({super.key, required this.enabled, required this.push, required this.child});

  /// false면 아무것도 안 해요 (테스트·체험 모드).
  final bool enabled;

  /// 푸시 알림도 받을지 (Firebase가 켜져 있을 때).
  final bool push;

  final Widget child;

  static UpdateWatcherState? of(BuildContext context) => context.findAncestorStateOfType<UpdateWatcherState>();

  @override
  State<UpdateWatcher> createState() => UpdateWatcherState();
}

class UpdateWatcherState extends State<UpdateWatcher> {
  AppLifecycleListener? _life;
  bool _busy = false;
  String? _dismissed;
  DateTime _lastCheck = DateTime(2000);

  bool get enabled => widget.enabled;

  @override
  void initState() {
    super.initState();
    if (!widget.enabled) return;
    // 첫 화면(로고)이 지나간 다음에 확인해요.
    Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      check();
      if (widget.push) UpdatePush.init(() => check(force: true));
    });
    _life = AppLifecycleListener(onResume: () {
      if (DateTime.now().difference(_lastCheck) > const Duration(minutes: 30)) check();
    });
  }

  @override
  void dispose() {
    _life?.dispose();
    super.dispose();
  }

  /// [force]: "나중에"를 눌렀던 버전이라도 다시 보여줘요 (알림을 눌렀을 때).
  /// [manual]: 설정에서 직접 눌렀을 때. 최신이면 "최신이에요"라고 알려줘요.
  Future<void> check({bool force = false, bool manual = false}) async {
    if (_busy) return;
    _busy = true;
    _lastCheck = DateTime.now();
    try {
      final rel = await Updater.newer();
      if (!mounted) return;
      if (rel == null) {
        if (manual) {
          ScaffoldMessenger.maybeOf(context)
              ?.showSnackBar(const SnackBar(content: Text('이미 최신 버전이에요 👍')));
        }
        return;
      }
      if (!force && !manual && _dismissed == rel.version) return;
      final current = await Updater.currentVersion();
      if (!mounted) return;
      final later = await showUpdateDialog(context, rel, current: current);
      if (later) _dismissed = rel.version;
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 업데이트 창. "나중에"를 누르면 true.
Future<bool> showUpdateDialog(
  BuildContext context,
  ReleaseInfo rel, {
  required String current,
  Future<File> Function(ReleaseInfo, void Function(double))? download,
  Future<void> Function(File)? install,
}) async {
  final r = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => UpdateDialog(
      release: rel,
      current: current,
      download: download ?? Updater.download,
      install: install ?? Updater.install,
    ),
  );
  return r ?? true;
}

enum _Step { ask, downloading, installing, failed }

class UpdateDialog extends StatefulWidget {
  const UpdateDialog({
    super.key,
    required this.release,
    required this.current,
    required this.download,
    required this.install,
  });

  final ReleaseInfo release;
  final String current;
  final Future<File> Function(ReleaseInfo, void Function(double)) download;
  final Future<void> Function(File) install;

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  var _step = _Step.ask;
  double? _progress;
  File? _file;

  Future<void> _go() async {
    setState(() {
      _step = _Step.downloading;
      _progress = null;
    });
    try {
      _file ??= await widget.download(widget.release, (p) {
        if (mounted) setState(() => _progress = p);
      });
      if (!mounted) return;
      setState(() => _step = _Step.installing);
      await widget.install(_file!);
    } catch (_) {
      if (mounted) setState(() => _step = _Step.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final notes = widget.release.notes.take(6).toList();

    final body = switch (_step) {
      _Step.ask || _Step.failed => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('지금 v${widget.current} → 새 버전 v${widget.release.version}',
                style: tt.bodyMedium!.copyWith(color: AppColors.gray)),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('바뀐 내용', style: tt.titleSmall),
              const SizedBox(height: 6),
              for (final n in notes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('•  '),
                    Expanded(child: Text(n, style: tt.bodyMedium)),
                  ]),
                ),
            ],
            if (_step == _Step.failed) ...[
              const SizedBox(height: 12),
              Text('앗, 내려받다가 끊겼어요. 인터넷을 확인하고 다시 눌러주세요.',
                  style: tt.bodySmall!.copyWith(color: AppColors.red)),
            ],
          ],
        ),
      _Step.downloading => Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: _progress, minHeight: 6),
          ),
          const SizedBox(height: 10),
          Text(_progress == null ? '내려받는 중…' : '내려받는 중… ${(_progress! * 100).round()}%', style: tt.bodyMedium),
        ]),
      _Step.installing => Text('설치 화면이 열렸어요.\n아래 [설치]를 눌러주면 끝! 🙌\n\n'
          '처음이면 "이 출처 허용"을 한 번 켜야 할 수 있어요.', style: tt.bodyMedium),
    };

    final actions = switch (_step) {
      _Step.ask || _Step.failed => [
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('나중에')),
          FilledButton(
            onPressed: _go,
            child: Text(_step == _Step.failed ? '다시 시도' : '지금 업데이트'),
          ),
        ],
      _Step.downloading => <Widget>[],
      _Step.installing => [
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('닫기')),
          FilledButton(onPressed: _go, child: const Text('설치 화면 다시 열기')),
        ],
    };

    return AlertDialog(
      icon: const Icon(Icons.system_update_rounded, color: AppColors.blue, size: 34),
      title: const Text('새 버전이 나왔어요 🎉'),
      content: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: SingleChildScrollView(child: body),
      ),
      actions: actions,
    );
  }
}
