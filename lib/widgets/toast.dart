import 'dart:collection';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/animation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

enum FLToastPosition {
  center,
  top,
  bottom
}

enum FLToastStyle {
  dark,
  lightBlur
}

class FLToastDefaults {
  const FLToastDefaults({
    this.showDuration = const Duration(milliseconds: 1500),
    this.darkColor = Colors.white,
    this.darkBackgroundColor = Colors.black87,
    this.lightColor = Colors.black12,
    this.position = FLToastPosition.center,
    this.style = FLToastStyle.dark,
    this.dismissOtherToast = true,
    this.hideWithTap = true,
    this.textDirection = TextDirection.ltr,
    this.topOffset = kToolbarHeight + 10,
    this.bottomOffset = 10,
  });

  final Duration showDuration;
  final Color darkColor; // include text & icon
  final Color darkBackgroundColor;
  final Color lightColor; // include text & icon
  final FLToastPosition position;
  final FLToastStyle style;
  final bool dismissOtherToast;
  final bool hideWithTap;
  final TextDirection textDirection;
  final double topOffset;
  final double bottomOffset;
}

class FLToastProvider extends StatefulWidget {
  FLToastProvider({
    Key key,
    this.defaults = const FLToastDefaults(),
    @required this.child
  }) : assert(defaults != null),
        assert(child != null),
        super(key: key);

  final FLToastDefaults defaults;
  final Widget child;

  @override
  State<FLToastProvider> createState() => _FLToastProviderState();
}

class _FLToastProviderState extends State<FLToastProvider> {
  @override
  void initState() {
    GestureBinding.instance.pointerRouter.addGlobalRoute(_handlePointerEvent);
    super.initState();
  }

  void _handlePointerEvent(PointerEvent event) {
    if (!widget.defaults.hideWithTap)
      return;

    if (!_toastManager.hasShowingToast())
      return;

    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _toastManager.dismissAllToast();
    }
  }

  @override
  void dispose() {
    _contextMap.remove(this);
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_handlePointerEvent);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Overlay overlay = Overlay(
      initialEntries: [
        OverlayEntry(
            builder: (BuildContext context) {
              _contextMap[this] = context;
              return widget.child;
            }
        )
      ],
    );

    Widget container = Directionality(
      textDirection: widget.defaults.textDirection,
      child: Stack(
        children: <Widget>[
          overlay,
          Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withOpacity(0.0),
                ),
              )
          )
        ],
      ),
    );

    return _FLToastDefaultsWidget(
        defaults: widget.defaults,
        child: container
    );
  }
}


class FLToast {
  static Function loading({ String text }) => FLToast.showLoading(text: text);
  static Function showLoading({ String text, FLToastPosition position, FLToastStyle style }) =>
      _showToast(text, position: position, style: style, type: _FLToastType.loading);

  static void text({ String text }) => FLToast.showText(text: text);
  static void showText({ String text, Duration showDuration, FLToastPosition position, FLToastStyle style }) =>
      _showToast(text, showDuration: showDuration, position: position, style: style, type: _FLToastType.text);

  static void success({ String text }) => FLToast.showSuccess(text: text);
  static void showSuccess({ String text, Duration showDuration, FLToastPosition position, FLToastStyle style }) =>
      _showToast(text, showDuration: showDuration, position: position, style: style, type: _FLToastType.success);

  static void error({ String text }) => FLToast.showError(text: text);
  static void showError({ String text, Duration showDuration, FLToastPosition position, FLToastStyle style }) =>
      _showToast(text, showDuration: showDuration, position: position, style: style, type: _FLToastType.error);

  static void info({ String text }) => FLToast.showInfo(text: text);
  static void showInfo({ String text, Duration showDuration, FLToastPosition position, FLToastStyle style }) =>
      _showToast(text, showDuration: showDuration, position: position, style: style, type: _FLToastType.info);
}

LinkedHashMap<_FLToastProviderState, BuildContext> _contextMap = LinkedHashMap();
final _toastManager = _FLToastManager._();
final EdgeInsetsGeometry _padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 13);
final _iconSize = 36.0;

enum _FLToastType {
  text,
  loading,
  success,
  error,
  info
}

Function _showToast(String text, { Duration showDuration, FLToastPosition position, FLToastStyle style, _FLToastType type }) {
  BuildContext context = _contextMap.values.first;
  OverlayEntry entry;
  FLToastDefaults defaults = _FLToastDefaultsWidget.of(context);

  position ??= defaults.position;
  style ??= defaults.style;
  Color color = defaults.darkColor;
  Color backgroundColor = defaults.darkBackgroundColor;
  double topOffset = defaults.topOffset;
  double bottomOffset = defaults.bottomOffset;
  showDuration ??= defaults.showDuration;
  if (type == _FLToastType.loading)
    showDuration = null;

  GlobalKey<_FLToastViewState> key = GlobalKey();

  _FLToastView toastView = _FLToastView(
    key: key,
    color: color,
    backgroundColor: backgroundColor,
    text: text,
    padding: _padding,
    showDuration: showDuration,
    slotWidget: _typeWidget(type, color),
    canBeAutoClear: type != _FLToastType.loading,
    position: position,
    topOffset: topOffset,
    bottomOffset: bottomOffset,
  );
  entry = OverlayEntry(builder: (BuildContext context) => toastView);

  if (defaults.dismissOtherToast == true) {
    _toastManager.dismissAllToast(immediately: true);
  }

  Overlay.of(context).insert(entry);
  _toastManager.addToast(_FLToastPack(key: key, entry: entry));
  SemanticsService.tooltip(text);

  return () {
    key.currentState._dismiss();
  };
}

class _FLToastPack {
  _FLToastPack({
    this.key,
    this.entry
  });

  final Key key;
  final OverlayEntry entry;
}

Widget _typeWidget(_FLToastType type, Color tintColor) {
  if (type == _FLToastType.loading)
  {
    return CircularProgressIndicator(
      strokeWidth: 3.0,
      valueColor: AlwaysStoppedAnimation(tintColor),
    );
  }
  else if (type == _FLToastType.success)
  {
    return Icon(
      Icons.check_circle_outline,
      size: _iconSize,
      color: tintColor,
    );
  }
  else if (type == _FLToastType.info)
  {
    return Icon(
      Icons.error_outline,
      size: _iconSize,
      color: tintColor,
    );
  }
  else if (type == _FLToastType.error)
  {
    return Icon(
      Icons.highlight_off,
      size: _iconSize,
      color: tintColor,
    );
  }
  return null;
}

class _FLToastManager {
  _FLToastManager._();

  Map<GlobalKey<_FLToastViewState>, _FLToastPack> _toastMap = Map();

  bool hasShowingToast() => _toastMap.length > 0;

  void dismissAllToast({ bool immediately = false }) {
    if (_toastMap.length == 0) {
      return;
    }

    _toastMap.forEach((key, pack) {
      if (key.currentState != null && key.currentState._showing) {
        _FLToastView toastView = key.currentWidget;
        if (toastView.canBeAutoClear) {
          key.currentState._dismiss(immediately: immediately);
        }
      }
    });
  }

  void addToast(_FLToastPack pack) {
    _toastMap[pack.key] = pack;
  }

  void removeToast(Key key) {
    if (!_toastMap.containsKey(key)) {
      return;
    }

    _toastMap.remove(key);
  }

  void removeEntry(Key key) {
    if (!_toastMap.containsKey(key)) {
      return;
    }

    _FLToastPack pack = _toastMap[key];
    pack.entry?.remove();
  }
}

class _FLToastDefaultsWidget extends InheritedWidget {
  const _FLToastDefaultsWidget({
    Key key,
    this.defaults,
    Widget child,
  }) : super(key: key, child: child);

  final FLToastDefaults defaults;

  @override
  bool updateShouldNotify(InheritedWidget oldWidget) {
    return true;
  }

  static FLToastDefaults of(BuildContext context) {
    _FLToastDefaultsWidget defaultsWidget = context.inheritFromWidgetOfExactType(_FLToastDefaultsWidget);
    return defaultsWidget.defaults;
  }
}

class _FLToastView extends StatefulWidget {
  _FLToastView({
    Key key,
    this.text,
    this.padding,
    this.slotWidget,
    this.color,
    this.backgroundColor,
    this.showDuration,
    this.canBeAutoClear = true,
    this.position,
    this.topOffset,
    this.bottomOffset
  }) : assert(slotWidget != null || text != null),
       super(key: key);

  final String text;
  final EdgeInsetsGeometry padding;
  final Widget slotWidget;
  final Color color;
  final Color backgroundColor;
  final Duration showDuration;
  final bool canBeAutoClear;
  final FLToastPosition position;
  final double topOffset;
  final double bottomOffset;

  @override
  State<_FLToastView> createState() => _FLToastViewState();
}

class _FLToastViewState extends State<_FLToastView> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // duration follow tooltip
  static const Duration _fadeInDuration = Duration(milliseconds: 150);
  static const Duration _fadeOutDuration = Duration(milliseconds: 75);
  static const Duration _waitDuration = Duration(milliseconds: 0);
  AnimationController _controller;
  Timer _showTimer;
  Timer _hideTimer;
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: _fadeInDuration,
      reverseDuration: _fadeOutDuration,
      vsync: this
    )
    ..addStatusListener(_handleStatusChanged);
    WidgetsBinding.instance.addObserver(this);
    _show();
  }

  void _handleStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      _dismiss(immediately: true);
    }
  }

  void _dismiss({ bool immediately = false }) {
    _showTimer?.cancel();
    _showTimer = null;
    if (immediately) {
      _toastManager.removeEntry(widget.key);
      _showing = false;
      return;
    }
    _controller.reverse();
  }

  void _show() {
    _hideTimer?.cancel();
    _hideTimer = null;
    _showTimer ??= Timer(_waitDuration, () {
      _showTimer?.cancel();
      _showTimer = null;
      _controller.forward();
      _showing = true;
      if (widget.showDuration != null) {
        _hideTimer = Timer(widget.showDuration, _dismiss);
      }
    });
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    setState(() {});
  }

  @override
  void deactivate() {
    if (_showing) {
      _dismiss(immediately: true);
    }
    _toastManager.removeToast(widget.key);
    super.deactivate();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _hideTimer = null;
    _showTimer?.cancel();
    _showTimer = null;
    _controller.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQueryData = MediaQueryData.fromWindow(ui.window);
    double marginTop = widget.topOffset + mediaQueryData.padding.top;
    double marginBottom = widget.bottomOffset + mediaQueryData.padding.bottom;
    MainAxisAlignment alignment = MainAxisAlignment.center;
    if (widget.position == FLToastPosition.top)
      alignment = MainAxisAlignment.start;
    else if (widget.position == FLToastPosition.bottom)
      alignment = MainAxisAlignment.end;

    List<Widget> children = <Widget>[];
    // add custom slot
    if (widget.slotWidget != null) {
      children.add(widget.slotWidget);
      if (widget.text != null) {
        children.add(SizedBox(height: 8.0));
      }
    }
    // add text
    if (widget.text != null) {
      children.add(Text(
          widget.text, style: TextStyle(color: widget.color, fontSize: 17)));
    }

    return AbsorbPointer(
      child: FadeTransition(
        opacity: _controller,
        child: Column(
          mainAxisAlignment: alignment,
          children: <Widget>[
            Container(
                margin: EdgeInsets.only(top: marginTop, bottom: marginBottom),
                decoration: BoxDecoration(
                    color: widget.backgroundColor.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(5.0)
                ),
                padding: widget.padding,
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: children
                )
            )
          ],
        ),
      ),
    );
  }
}