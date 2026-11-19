import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../utils/responsive.dart';
import '../utils/validators.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.initialValue,
    this.label,
    this.hint,
    this.helper,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.prefixIcon,
    this.suffix,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.textInputAction,
    this.autofillHints,
    this.focusNode,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
  });

  final TextEditingController? controller;
  final String? initialValue;
  final String? label;
  final String? hint;
  final String? helper;
  final FieldValidator? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final FocusNode? focusNode;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      focusNode: focusNode,
      enabled: enabled,
      readOnly: readOnly,
      autofocus: autofocus,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: obscureText ? 1 : maxLines,
      minLines: minLines,
      maxLength: maxLength,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        counterText: '',
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 20),
        suffixIcon: suffix,
      ),
    );
  }
}

/// Rounded search box with a clear button.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hint = 'Search',
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
        ),
      ),
    );
  }
}

class SelectOption<T> {
  const SelectOption(this.value, this.label, {this.subtitle});

  final T value;
  final String label;
  final String? subtitle;
}

class _Pick<T> {
  const _Pick(this.value);

  final T? value;
}

/// Dropdown replacement that opens a searchable picker. The parent owns the
/// selected [value] and rebuilds with the new one in [onChanged].
class AppSelectField<T> extends StatelessWidget {
  const AppSelectField({
    super.key,
    required this.label,
    required this.options,
    this.value,
    this.onChanged,
    this.validator,
    this.hint,
    this.allowClear = true,
    this.enabled = true,
  });

  final String label;
  final List<SelectOption<T>> options;
  final T? value;
  final ValueChanged<T?>? onChanged;
  final String? Function(T?)? validator;
  final String? hint;
  final bool allowClear;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final interactive = enabled && onChanged != null;
    SelectOption<T>? selected;
    for (final option in options) {
      if (option.value == value) {
        selected = option;
        break;
      }
    }
    final selectedLabel = selected?.label;

    return FormField<T>(
      key: ValueKey<Object?>(value),
      initialValue: value,
      validator: validator,
      builder: (state) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: interactive
            ? () async {
                final pick = await _openPicker<T>(
                  context,
                  title: label,
                  options: options,
                  selected: value,
                  allowClear: allowClear,
                );
                if (pick != null) onChanged!(pick.value);
              }
            : null,
        child: InputDecorator(
          isEmpty: selectedLabel == null,
          isFocused: false,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            errorText: state.errorText,
            enabled: interactive,
            suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
          child: Text(
            selectedLabel ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

Future<_Pick<T>?> _openPicker<T>(
  BuildContext context, {
  required String title,
  required List<SelectOption<T>> options,
  required T? selected,
  required bool allowClear,
}) {
  Widget body(BuildContext pickerContext) => _PickerBody<T>(
    title: title,
    options: options,
    selected: selected,
    allowClear: allowClear,
  );

  if (context.isMobile) {
    return showModalBottomSheet<_Pick<T>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) =>
          FractionallySizedBox(heightFactor: 0.85, child: body(sheetContext)),
    );
  }
  return showDialog<_Pick<T>>(
    context: context,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 580),
        child: body(dialogContext),
      ),
    ),
  );
}

class _PickerBody<T> extends StatefulWidget {
  const _PickerBody({
    required this.title,
    required this.options,
    required this.selected,
    required this.allowClear,
  });

  final String title;
  final List<SelectOption<T>> options;
  final T? selected;
  final bool allowClear;

  @override
  State<_PickerBody<T>> createState() => _PickerBodyState<T>();
}

class _PickerBodyState<T> extends State<_PickerBody<T>> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final showSearch = widget.options.length > 7;
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? widget.options
        : widget.options
              .where(
                (o) =>
                    o.label.toLowerCase().contains(query) ||
                    (o.subtitle ?? '').toLowerCase().contains(query),
              )
              .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: context.text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        if (showSearch)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: AppSearchField(
              controller: _search,
              hint: 'Search',
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
        if (widget.allowClear && widget.selected != null)
          ListTile(
            leading: Icon(Icons.highlight_off, color: colors.mutedText),
            title: Text(
              'Clear selection',
              style: TextStyle(color: colors.mutedText),
            ),
            onTap: () => Navigator.of(context).pop(_Pick<T>(null)),
          ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No matches',
                    style: TextStyle(color: colors.mutedText),
                  ),
                )
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final option = filtered[index];
                    final isSelected = option.value == widget.selected;
                    return ListTile(
                      title: Text(
                        option.label,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      subtitle: option.subtitle == null
                          ? null
                          : Text(option.subtitle!),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle,
                              color: context.scheme.primary,
                            )
                          : null,
                      onTap: () =>
                          Navigator.of(context).pop(_Pick<T>(option.value)),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class AppDateField extends StatelessWidget {
  const AppDateField({
    super.key,
    required this.label,
    this.value,
    this.onChanged,
    this.validator,
    this.firstDate,
    this.lastDate,
    this.allowClear = true,
    this.enabled = true,
    this.withTime = false,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?>? onChanged;
  final String? Function(DateTime?)? validator;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool allowClear;
  final bool enabled;
  final bool withTime;

  Future<void> _pick(BuildContext context) async {
    final first = firstDate ?? DateTime(1950);
    final last = lastDate ?? DateTime(2100);
    var initial = value ?? DateTime.now();
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (date == null || !context.mounted) return;

    if (!withTime) {
      onChanged?.call(DateTime(date.year, date.month, date.day));
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value ?? DateTime.now()),
    );
    if (time == null) return;
    onChanged?.call(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    final interactive = enabled && onChanged != null;
    return FormField<DateTime>(
      key: ValueKey<int?>(value?.millisecondsSinceEpoch),
      initialValue: value,
      validator: validator,
      builder: (state) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: interactive ? () => _pick(context) : null,
        child: InputDecorator(
          isEmpty: value == null,
          isFocused: false,
          decoration: InputDecoration(
            labelText: label,
            errorText: state.errorText,
            enabled: interactive,
            suffixIcon: value != null && allowClear && interactive
                ? IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => onChanged?.call(null),
                  )
                : const Icon(Icons.calendar_today_outlined, size: 20),
          ),
          child: Text(
            value == null
                ? ''
                : (withTime ? Fmt.dateTime(value) : Fmt.date(value)),
          ),
        ),
      ),
    );
  }
}
