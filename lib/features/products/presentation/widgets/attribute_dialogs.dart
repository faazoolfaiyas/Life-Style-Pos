import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../data/models/attribute_models.dart';
import '../../data/services/attribute_service.dart';

// --- Base Dialog Helper ---
class _BaseAttributeDialog extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback onSave;

  const _BaseAttributeDialog({
    required this.title,
    required this.child,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            child,
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onSave,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Category Form ---
class CategoryFormDialog extends ConsumerStatefulWidget {
  final ProductCategory? initialData; // If null, create new
  const CategoryFormDialog({super.key, this.initialData});

  @override
  ConsumerState<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends ConsumerState<CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _colorCtrl;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialData?.name);
    _descCtrl = TextEditingController(text: widget.initialData?.description);
    _colorCtrl = TextEditingController(text: widget.initialData?.colorHex ?? '#6C63FF');
    _isActive = widget.initialData?.isActive ?? true;
  }

  @override
  Widget build(BuildContext context) {
    return _BaseAttributeDialog(
      title: widget.initialData == null ? 'New Category' : 'Edit Category',
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Category Name', hintText: 'e.g. Men'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Description (Optional)'),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                Color currentColor = _parseColor(_colorCtrl.text);
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Pick a color'),
                    content: SingleChildScrollView(
                      child: ColorPicker(
                        pickerColor: currentColor,
                        onColorChanged: (color) {
                           setState(() {
                             _colorCtrl.text = '#${color.toHexString(includeHashSign: false).toUpperCase()}';
                           });
                        },
                        enableAlpha: false,
                        labelTypes: const [],
                        paletteType: PaletteType.hsvWithHue,
                      ),
                    ),
                    actions: [
                      TextButton(
                        child: const Text('Done'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _parseColor(_colorCtrl.text),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _colorCtrl.text.isEmpty ? 'Pick a Color' : _colorCtrl.text,
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const Icon(Icons.colorize, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Active Status'),
              value: _isActive,
              onChanged: (val) => setState(() => _isActive = val),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.grey;
    try {
      String cleanHex = hex.replaceAll('#', '').replaceAll('0x', '');
      if (cleanHex.length == 6) {
        cleanHex = 'FF$cleanHex';
      }
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final service = ref.read(attributeServiceProvider);
    
    final category = ProductCategory(
      id: widget.initialData?.id,
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      colorHex: _colorCtrl.text.trim(),
      isActive: _isActive,
    );

    try {
      if (widget.initialData == null) {
        await service.addCategory(category);
      } else {
        await service.updateCategory(category.id!, category);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

// --- Size Form ---
class SizeFormDialog extends ConsumerStatefulWidget {
  final ProductSize? initialData;
  const SizeFormDialog({super.key, this.initialData});

  @override
  ConsumerState<SizeFormDialog> createState() => _SizeFormDialogState();
}

class _SizeFormDialogState extends ConsumerState<SizeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _codeCtrl;
  late TextEditingController _orderCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialData?.name);
    _codeCtrl = TextEditingController(text: widget.initialData?.code);
    _orderCtrl = TextEditingController(text: widget.initialData?.sortOrder.toString() ?? '0');
  }

  @override
  Widget build(BuildContext context) {
    return _BaseAttributeDialog(
      title: widget.initialData == null ? 'New Size' : 'Edit Size',
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Size Name', hintText: 'e.g. Small'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
             TextFormField(
              controller: _codeCtrl,
              decoration: const InputDecoration(labelText: 'Short Code', hintText: 'e.g. S'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _orderCtrl,
              decoration: const InputDecoration(labelText: 'Sort Order', hintText: 'e.g. 1'),
              keyboardType: TextInputType.number,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final service = ref.read(attributeServiceProvider);
    
    final size = ProductSize(
      id: widget.initialData?.id,
      name: _nameCtrl.text.trim(),
      code: _codeCtrl.text.trim(),
      sortOrder: int.tryParse(_orderCtrl.text) ?? 0,
    );

    try {
      if (widget.initialData == null) {
        await service.addSize(size);
      } else {
        await service.updateSize(size.id!, size);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

// --- Color Form ---
class ColorFormDialog extends ConsumerStatefulWidget {
  final ProductColor? initialData;
  const ColorFormDialog({super.key, this.initialData});

  @override
  ConsumerState<ColorFormDialog> createState() => _ColorFormDialogState();
}

class _ColorFormDialogState extends ConsumerState<ColorFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _hexCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialData?.name);
    _hexCtrl = TextEditingController(text: widget.initialData?.hexCode ?? '#000000');
  }

  @override
  Widget build(BuildContext context) {
    return _BaseAttributeDialog(
      title: widget.initialData == null ? 'New Color' : 'Edit Color',
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Color Name', hintText: 'e.g. Red'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                Color currentColor = _parseColor(_hexCtrl.text);
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Pick a color'),
                    content: SingleChildScrollView(
                      child: ColorPicker(
                        pickerColor: currentColor,
                        onColorChanged: (color) {
                           setState(() {
                             _hexCtrl.text = '#${color.toHexString(includeHashSign: false).toUpperCase()}';
                           });
                        },
                        enableAlpha: false,
                        labelTypes: const [],
                        paletteType: PaletteType.hsvWithHue,
                      ),
                    ),
                    actions: [
                      TextButton(
                        child: const Text('Done'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _parseColor(_hexCtrl.text),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _hexCtrl.text.isEmpty ? 'Pick a Color' : _hexCtrl.text,
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const Icon(Icons.colorize, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.grey;
    try {
      String cleanHex = hex.replaceAll('#', '').replaceAll('0x', '');
      if (cleanHex.length == 6) {
        cleanHex = 'FF$cleanHex';
      }
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final service = ref.read(attributeServiceProvider);
    
    final color = ProductColor(
      id: widget.initialData?.id,
      name: _nameCtrl.text.trim(),
      hexCode: _hexCtrl.text.trim(),
    );

    try {
      if (widget.initialData == null) {
        await service.addColor(color);
      } else {
        await service.updateColor(color.id!, color);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

// --- Design Form ---
class DesignFormDialog extends ConsumerStatefulWidget {
  final ProductDesign? initialData;
  const DesignFormDialog({super.key, this.initialData});

  @override
  ConsumerState<DesignFormDialog> createState() => _DesignFormDialogState();
}

class _DesignFormDialogState extends ConsumerState<DesignFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialData?.name);
  }

  @override
  Widget build(BuildContext context) {
    return _BaseAttributeDialog(
      title: widget.initialData == null ? 'New Design' : 'Edit Design',
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Design Name', hintText: 'e.g. Floral'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            // TODO: Image Uploader
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final service = ref.read(attributeServiceProvider);
    
    final design = ProductDesign(
      id: widget.initialData?.id,
      name: _nameCtrl.text.trim(),
    );

    try {
      if (widget.initialData == null) {
        await service.addDesign(design);
      } else {
        await service.updateDesign(design.id!, design);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
