import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class PortInput extends StatefulWidget {
  final int defaultValue;
  final int minValue = 1024;
  final int maxValue = 65535;
  final ValueChanged<int>? onChanged;
  final String? statusMessage;
  final PortStatus status;

  const PortInput({super.key, required this.defaultValue, required this.onChanged, required this.statusMessage, this.status = PortStatus.none});

  @override
  State<PortInput> createState() => _PortInputState();
}

class _PortInputState extends State<PortInput> {
  late TextEditingController _controller;
  bool _isValid = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.defaultValue.toInt().toString());
    _controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(PortInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.defaultValue != widget.defaultValue) {
      _controller.text = widget.defaultValue.toString();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final String text = _controller.text;

    if (text.isEmpty) {
      setState(() {
        _isValid = false;
      });
      return;
    }

    final int? value = int.tryParse(text);

    if (value == null) {
      setState(() {
        _isValid = false;
      });
      return;
    }

    final bool isInRange = value >= widget.minValue && value <= widget.maxValue;

    setState(() {
      _isValid = isInRange;
    });

    if (isInRange && widget.onChanged != null) {
      widget.onChanged!(value);
    }
  }

  Color _getBorderColor() {
    if (!_isValid) return Colors.red;

    switch (widget.status) {
      case PortStatus.checking:
        return Colors.orange;
      case PortStatus.valid:
        return Colors.blue;
      case PortStatus.saved:
        return Colors.green;
      case PortStatus.error:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget? _getSuffixIcon() {
    if (!_isValid) {
      return const Icon(Icons.error, color: Colors.red);
    }

    switch (widget.status) {
      case PortStatus.checking:
        return const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2));
      case PortStatus.saved:
        return const Icon(Icons.check_circle, color: Colors.green);
      case PortStatus.error:
        return const Icon(Icons.error, color: Colors.red);
      default:
        return null;
    }
  }

  String? _getStatusMessage(BuildContext context) {
    if (!_isValid) {
      return AppLocalizations.of(context)!.portsValuesBetween(widget.minValue, widget.maxValue);
    }
    return widget.statusMessage;
  }

  Color _getStatusColor() {
    if (!_isValid) return Colors.red;

    switch (widget.status) {
      case PortStatus.saved:
        return Colors.green;
      case PortStatus.error:
        return Colors.red;
      case PortStatus.checking:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? statusMessage = _getStatusMessage(context);
    final Color borderColor = _getBorderColor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: _controller,
          keyboardType: TextInputType.numberWithOptions(),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            border: OutlineInputBorder(borderSide: BorderSide(color: borderColor, width: 1.0)),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor, width: 1.0)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor, width: 2.0)),
            errorBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 2.0)),
            focusedErrorBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 2.0)),
            suffixIcon: _getSuffixIcon(),
          ),
          style: TextStyle(color: _isValid ? null : Colors.red),
        ),
        if (statusMessage != null)
          Padding(padding: const EdgeInsets.only(top: 8.0, left: 12.0), child: Text(statusMessage, style: TextStyle(color: _getStatusColor(), fontSize: 12.0))),
      ],
    );
  }
}

enum PortStatus { none, checking, valid, invalid, saved, error }
