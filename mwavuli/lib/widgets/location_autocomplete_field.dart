import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme.dart';
import '../core/location/location_service.dart';
import '../core/location/nominatim_geocode.dart';

/// Location text field with OpenStreetMap (Nominatim) suggestions in a dropdown.
class LocationAutocompleteField extends ConsumerStatefulWidget {
  const LocationAutocompleteField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.locating = false,
    this.hintText = 'City or region (optional)',
    this.showClearButton = false,
    this.onUseCurrentLocation,
    this.onPlaceSelected,
    this.decoration,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool locating;
  final String hintText;
  final bool showClearButton;
  final VoidCallback? onUseCurrentLocation;
  final ValueChanged<PlaceSuggestion>? onPlaceSelected;
  final InputDecoration? decoration;

  @override
  ConsumerState<LocationAutocompleteField> createState() =>
      _LocationAutocompleteFieldState();
}

class _LocationAutocompleteFieldState
    extends ConsumerState<LocationAutocompleteField> {
  final _focusNode = FocusNode();
  final _panelKey = GlobalKey();
  Timer? _debounce;
  int _searchGeneration = 0;
  List<PlaceSuggestion> _suggestions = const [];
  bool _searching = false;
  bool _searchFailed = false;
  bool _suppressSearch = false;

  bool get _showPanel {
    if (!_focusNode.hasFocus) return false;
    if (widget.controller.text.trim().isEmpty) return false;
    return _searching || _searchFailed || _suggestions.isNotEmpty;
  }

  Widget _buildSuggestionsPanel(BuildContext context) {
    final earth = context.earth;
    return Material(
      key: _panelKey,
      elevation: 6,
      shadowColor: Colors.black26,
      color: Palette.cream50,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 220),
        child: _searching && _suggestions.isEmpty && !_searchFailed
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            : _searchFailed
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Could not reach place search.\nCheck your internet connection.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: earth.ink3),
                    ),
                  )
                : _suggestions.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'No places found.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: earth.ink3),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: _suggestions.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: earth.line),
                        itemBuilder: (context, index) {
                          final item = _suggestions[index];
                          return InkWell(
                            onTap: () => _select(item),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.place_outlined,
                                    size: 18,
                                    color: Palette.green700,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.label,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Palette.ink,
                                          ),
                                        ),
                                        if (item.subtitle != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            item.subtitle!,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: earth.ink3,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      setState(() {
        _suggestions = const [];
        _searching = false;
      });
      return;
    }
    _scheduleSearch();
  }

  void _onTextChanged() {
    if (_suppressSearch) {
      _suppressSearch = false;
      setState(() {
        _suggestions = const [];
        _searching = false;
      });
      return;
    }
    if (widget.showClearButton) setState(() {});
    if (!_focusNode.hasFocus) return;
    _scheduleSearch();
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _runSearch);
  }

  Future<void> _runSearch() async {
    if (!mounted || !_focusNode.hasFocus) return;

    final query = widget.controller.text.trim();
    if (query.isEmpty) {
      setState(() {
        _suggestions = const [];
        _searching = false;
        _searchFailed = false;
      });
      return;
    }

    final generation = ++_searchGeneration;
    setState(() {
      _searching = true;
      _searchFailed = false;
    });

    try {
      final geocode = ref.read(nominatimGeocodeProvider);
      final results = await geocode.searchPlaces(query);
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _suggestions = results;
        _searching = false;
        _searchFailed = false;
      });
      if (results.isNotEmpty) _scrollPanelIntoView();
    } catch (_) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _suggestions = const [];
        _searching = false;
        _searchFailed = true;
      });
    }
  }

  void _scrollPanelIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _panelKey.currentContext;
      if (ctx == null || !mounted) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.05,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _select(PlaceSuggestion suggestion) {
    _suppressSearch = true;
    widget.controller.text = suggestion.label;
    widget.controller.selection = TextSelection.collapsed(
      offset: suggestion.label.length,
    );
    setState(() {
      _suggestions = const [];
      _searching = false;
    });
    _focusNode.unfocus();
    widget.onPlaceSelected?.call(suggestion);
  }

  InputDecoration _buildDecoration(BuildContext context) {
    if (widget.decoration != null) return widget.decoration!;
    final earth = context.earth;
    return InputDecoration(
      hintText: widget.hintText,
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 14, right: 10),
        child: Icon(Icons.place_outlined, size: 20, color: Palette.green700),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      suffixIcon: widget.onUseCurrentLocation == null
          ? null
          : IconButton(
              tooltip: 'Use my location',
              onPressed: (!widget.enabled || widget.locating)
                  ? null
                  : widget.onUseCurrentLocation,
              icon: widget.locating
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: earth.ink3,
                      ),
                    )
                  : Icon(
                      Icons.my_location,
                      size: 20,
                      color: Palette.green700,
                    ),
            ),
    );
  }

  Widget? _clearSuffix() {
    if (!widget.showClearButton || widget.controller.text.isEmpty) {
      return null;
    }
    return IconButton(
      icon: const Icon(Icons.clear_rounded, size: 18),
      onPressed: () {
        widget.controller.clear();
        setState(() {
          _suggestions = const [];
          _searching = false;
        });
      },
    );
  }

  InputDecoration _effectiveDecoration(BuildContext context) {
    final base = _buildDecoration(context);
    if (!widget.showClearButton) return base;
    return base.copyWith(suffixIcon: _clearSuffix());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) {
            if (_suggestions.length == 1) _select(_suggestions.first);
          },
          style: const TextStyle(fontSize: 15, color: Palette.ink),
          decoration: _effectiveDecoration(context),
        ),
        if (_showPanel) ...[
          const SizedBox(height: 6),
          _buildSuggestionsPanel(context),
        ],
      ],
    );
  }
}
