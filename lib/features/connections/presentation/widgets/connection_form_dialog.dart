import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/services.dart';

class _VehicleNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text.toUpperCase();
    text = text.replaceAll(RegExp(r'[^A-Z0-9-]'), '');

    if (oldValue.text.length > text.length) {
      if (oldValue.text.endsWith('-') && !text.endsWith('-')) {
         return TextEditingValue(
          text: text.substring(0, text.length - 1),
          selection: TextSelection.collapsed(offset: text.length - 1),
        );
      }
      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: newValue.selection.end),
      );
    }

    if (!text.contains('-')) {
      if (RegExp(r'^[A-Z]{3}$').hasMatch(text)) {
        text += '-';
      } 
      else if (RegExp(r'^[A-Z]{2}[0-9]$').hasMatch(text)) {
        text = '${text.substring(0, 2)}-${text.substring(2)}';
      }
      else if (RegExp(r'^[0-9]{3}$').hasMatch(text)) {
        text += '-';
      }
    }

    if (text.length > 8) text = text.substring(0, 8);
    
    if (text.contains('-')) {
      final parts = text.split('-');
      if (parts.length > 1 && parts[1].length > 4) {
        text = '${parts[0]}-${parts[1].substring(0, 4)}';
      }
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}


class ConnectionFormDialog extends StatefulWidget {
  final String type;
  final Map<String, dynamic>? initialData;
  final Future<void> Function(Map<String, dynamic>) onSubmit;

  const ConnectionFormDialog({
    super.key,
    required this.type,
    this.initialData,
    required this.onSubmit,
  });

  @override
  State<ConnectionFormDialog> createState() => _ConnectionFormDialogState();
}

class _ConnectionFormDialogState extends State<ConnectionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _ownerNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _threewheelerController;
  late TextEditingController _descriptionController;
  String _status = 'Active';

  List<Map<String, String>> _socialMedia = [];
  List<Map<String, String>> _bankDetails = [];
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    _nameController = TextEditingController(text: data?['name'] ?? data?['shopName'] ?? '');
    _ownerNameController = TextEditingController(text: data?['ownerName'] ?? '');
    _phoneController = TextEditingController(text: data?['whatsappNumber'] ?? '');
    _emailController = TextEditingController(text: data?['email'] ?? '');
    _addressController = TextEditingController(text: data?['address'] ?? '');
    _threewheelerController = TextEditingController(text: data?['threewheelerNumber'] ?? '');
    _descriptionController = TextEditingController(text: data?['description'] ?? '');
    _status = data?['status'] ?? 'Active';
    
    if (data?['socialMedia'] != null) {
      _socialMedia = List<Map<String, String>>.from(data!['socialMedia']);
    }
     if (data?['bankDetails'] != null) {
      _bankDetails = List<Map<String, String>>.from(data!['bankDetails']);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _threewheelerController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        String finalPhone = _phoneController.text;
        if (finalPhone.length == 9) finalPhone = '0$finalPhone';

        final Map<String, dynamic> formData = {
          'whatsappNumber': finalPhone,
          'address': _addressController.text,
          'email': _emailController.text,
          'description': _descriptionController.text,
          'status': _status,
        };

        if (widget.type == 'Customer') {
          formData['name'] = _nameController.text;
        } else if (widget.type == 'Supplier') {
          formData['shopName'] = _nameController.text;
          formData['ownerName'] = _ownerNameController.text;
          formData['socialMedia'] = _socialMedia;
          formData['bankDetails'] = _bankDetails;
        } else if (widget.type == 'Reseller') {
          formData['name'] = _nameController.text;
          formData['socialMedia'] = _socialMedia;
        } else if (widget.type == 'Affiliate') {
          formData['name'] = _nameController.text;
          formData['threewheelerNumber'] = _threewheelerController.text;
          formData['bankDetails'] = _bankDetails;
        }

        await widget.onSubmit(formData);
        
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 650,
        height: 800,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
               Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${widget.initialData == null ? 'New' : 'Edit'} ${widget.type}',
                      style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        _buildStatusDropdown(),
                        const SizedBox(height: 16),
                        
                        _buildTextField(widget.type == 'Supplier' ? 'Shop Name' : 'Full Name', _nameController, Icons.person, true),
                        const SizedBox(height: 16),
                        if (widget.type == 'Supplier') ...[
                           _buildTextField('Owner Name', _ownerNameController, Icons.person_outline, false),
                           const SizedBox(height: 16),
                        ],

                        Row(
                          children: [
                            Expanded(child: _buildTextField('WhatsApp Number', _phoneController, FontAwesomeIcons.whatsapp, true)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildTextField('Email Address', _emailController, Icons.email, false)),
                          ],
                        ),
                        const SizedBox(height: 16),

                        _buildTextField('Address', _addressController, Icons.location_on, widget.type != 'Customer'), 
                        const SizedBox(height: 16),
                        
                        if (widget.type == 'Affiliate') ...[
                          _buildTextField(
                            'Threewheeler Number', 
                            _threewheelerController, 
                            Icons.directions_car, 
                            true,
                            inputFormatters: [_VehicleNumberFormatter()],
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Vehicle number is required';
                              if (!value.contains('-')) return 'Invalid format (missing "-")';
                              
                              final parts = value.split('-');
                              if (parts.length != 2) return 'Invalid format';
                              
                              final prefix = parts[0];
                              final suffix = parts[1];
                              
                              if (prefix.length == 2 && int.tryParse(prefix) != null) return 'Cannot have 2 digits before dash';
                              if (prefix.length < 2 || prefix.length > 3) return 'Invalid prefix length';
                              if (suffix.length != 4) return 'Must have 4 digits after dash';
                              if (int.tryParse(suffix) == null) return 'Suffix must be digits';
                              
                              return null;
                            }
                          ),
                          const SizedBox(height: 16),
                        ],

                        if (widget.type == 'Supplier' || widget.type == 'Reseller') ...[
                          _buildSocialMediaSection(),
                          const SizedBox(height: 16),
                        ],
                        
                        if (widget.type == 'Supplier' || widget.type == 'Affiliate') ...[
                           _buildBankDetailsSection(),
                           const SizedBox(height: 16),
                        ],

                        _buildTextField('Description', _descriptionController, Icons.description, false, maxLines: 3),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text('Save ${widget.type}', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusDropdown() {
     return Row(
      children: [
        const Text('Status: ', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        DropdownButton<String>(
          value: _status,
          items: ['Active', 'Inactive', 'Blocked'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (val) => setState(() => _status = val!),
        ),
      ],
    );
  }
  
  Widget _buildSocialMediaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Social Media Links', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            TextButton.icon(
              onPressed: () => setState(() => _socialMedia.add({'platform': '', 'link': ''})),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add'),
            ),
          ],
        ),
        ..._socialMedia.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: item['platform'],
                    decoration: const InputDecoration(hintText: 'Platform (e.g., FB)', isDense: true, border: OutlineInputBorder()),
                    onChanged: (val) => item['platform'] = val,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    initialValue: item['link'],
                    decoration: const InputDecoration(hintText: 'Link', isDense: true, border: OutlineInputBorder()),
                    onChanged: (val) => item['link'] = val,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => setState(() => _socialMedia.removeAt(index)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildBankDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Bank Accounts', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            TextButton.icon(
              onPressed: () => setState(() => _bankDetails.add({'bankName': '', 'accountNumber': '', 'accountName': '', 'branch': ''})),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add'),
            ),
          ],
        ),
        ..._bankDetails.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: item['bankName'],
                        decoration: const InputDecoration(labelText: 'Bank Name', isDense: true),
                        onChanged: (val) => item['bankName'] = val,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: item['branch'],
                        decoration: const InputDecoration(labelText: 'Branch (Opt)', isDense: true),
                        validator: (val) {
                          if (val != null && val.isNotEmpty && !RegExp(r'^[a-zA-Z\s]+$').hasMatch(val)) return 'Alphabets only';
                          return null;
                        },
                        onChanged: (val) => item['branch'] = val,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                 Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: item['accountNumber'],
                        decoration: const InputDecoration(labelText: 'Account No.', isDense: true),
                        keyboardType: TextInputType.number,
                        validator: (val) {
                          if (val != null && val.isNotEmpty && !RegExp(r'^[0-9]+$').hasMatch(val)) return 'Digits only';
                          return null;
                        },
                         onChanged: (val) => item['accountNumber'] = val,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: item['accountName'],
                        decoration: const InputDecoration(labelText: 'Account Name', isDense: true),
                        validator: (val) {
                          if (val != null && val.isNotEmpty && !RegExp(r'^[a-zA-Z\s]+$').hasMatch(val)) return 'Alphabets only';
                          return null;
                        },
                        onChanged: (val) => item['accountName'] = val,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                       onPressed: () => setState(() => _bankDetails.removeAt(index)),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon,
    bool required, {
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label${required ? ' *' : ''}',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w500, color: Colors.grey[700]),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: label.contains('Number') || label.contains('Phone') ? TextInputType.number : TextInputType.text,
          inputFormatters: inputFormatters,
          textCapitalization: inputFormatters != null ? TextCapitalization.characters : TextCapitalization.none,
          validator: validator ?? (value) {
            if (required && (value == null || value.isEmpty)) {
              return '$label is required';
            }
            
            if (label == 'WhatsApp Number') {
               if (value != null && value.isNotEmpty) {
                 final isDigitsOnly = RegExp(r'^[0-9]+$').hasMatch(value);
                 if (!isDigitsOnly) return 'Only digits allowed';
                 
                 if (value.length == 10) {
                   if (!value.startsWith('0')) return '10-digit number must start with 0';
                 } else if (value.length == 9) {
                   if (value.startsWith('0')) return 'Invalid number (cannot start with 0 if 9 digits)';
                 } else {
                   return 'Number must be 9 or 10 digits';
                 }
               }
            }

            if (label == 'Email Address' && value != null && value.isNotEmpty) {
               final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
               if (!emailRegex.hasMatch(value)) return 'Enter a valid email';
            }
            
            return null;
          },
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18),
            hintText: label.contains('Threewheeler') ? 'XXX-0000' : 'Enter $label',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
            ),
            filled: true,
            fillColor: Colors.grey.withValues(alpha: 0.05),
          ),
        ),
      ],
    );
  }
}
