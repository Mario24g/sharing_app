import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PortInput extends StatefulWidget {
  final int defaultValue;
  final int minValue = 1024;
  final int maxValue = 65535;
  final ValueChanged<int>? onChanged;

  const PortInput({super.key, required this.defaultValue, this.onChanged});

  @override
  State<PortInput> createState() => _PortInputState();
}

class _PortInputState extends State<PortInput> {
  late TextEditingController _controller;
  bool _isValid = true;
  int? _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.defaultValue;
    _controller = TextEditingController(text: widget.defaultValue.toInt().toString());
    _controller.addListener(_onTextChanged);
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
        _currentValue = null;
      });
      return;
    }

    final int? value = int.tryParse(text);

    if (value == null) {
      setState(() {
        _isValid = false;
        _currentValue = null;
      });
      return;
    }

    final bool isInRange = value >= widget.minValue && value <= widget.maxValue;

    setState(() {
      _isValid = isInRange;
      _currentValue = value;
    });

    if (isInRange && widget.onChanged != null) {
      widget.onChanged!(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: _controller,
          keyboardType: TextInputType.numberWithOptions(),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            border: OutlineInputBorder(borderSide: BorderSide(color: _isValid ? Colors.grey : Colors.red, width: _isValid ? 1.0 : 2.0)),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _isValid ? Colors.grey : Colors.red, width: _isValid ? 1.0 : 2.0)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _isValid ? Theme.of(context).primaryColor : Colors.red, width: 2.0)),
            errorBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 2.0)),
            focusedErrorBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 2.0)),
            suffixIcon: !_isValid ? const Icon(Icons.error, color: Colors.red) : null,
          ),
          style: TextStyle(color: _isValid ? null : Colors.red),
        ),
        if (!_isValid)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 12.0),
            child: Text('Value must be between ${widget.minValue} and ${widget.maxValue}', style: const TextStyle(color: Colors.red, fontSize: 12.0)),
          ),
      ],
    );
  }
}
