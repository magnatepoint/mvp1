import 'package:flutter/material.dart';
import '../../../models/goals_models.dart';

const List<String> indianStates = [
  'IN-AP', 'IN-AR', 'IN-AS', 'IN-BR', 'IN-CT', 'IN-GA', 'IN-GJ', 'IN-HR',
  'IN-HP', 'IN-JK', 'IN-JH', 'IN-KA', 'IN-KL', 'IN-MP', 'IN-MH', 'IN-MN',
  'IN-ML', 'IN-MZ', 'IN-NL', 'IN-OR', 'IN-PB', 'IN-RJ', 'IN-SK', 'IN-TN',
  'IN-TG', 'IN-TR', 'IN-UP', 'IN-UT', 'IN-WB', 'IN-AN', 'IN-CH', 'IN-DH',
  'IN-DL', 'IN-LD', 'IN-PY',
];

class LifeContextStep extends StatefulWidget {
  final LifeContext? initialData;
  final Function(LifeContext) onSubmit;
  final VoidCallback? onSkip;

  const LifeContextStep({
    super.key,
    this.initialData,
    required this.onSubmit,
    this.onSkip,
  });

  @override
  State<LifeContextStep> createState() => _LifeContextStepState();
}

class _LifeContextStepState extends State<LifeContextStep> {
  final _formKey = GlobalKey<FormState>();
  late LifeContext _formData;
  final Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();
    _formData = LifeContext(
      ageBand: widget.initialData?.ageBand ?? '',
      dependentsSpouse: widget.initialData?.dependentsSpouse ?? false,
      dependentsChildrenCount: widget.initialData?.dependentsChildrenCount ?? 0,
      dependentsParentsCare: widget.initialData?.dependentsParentsCare ?? false,
      housing: widget.initialData?.housing ?? '',
      employment: widget.initialData?.employment ?? '',
      incomeRegularity: widget.initialData?.incomeRegularity ?? '',
      regionCode: widget.initialData?.regionCode ?? '',
      emergencyOptOut: widget.initialData?.emergencyOptOut ?? false,
    );
  }

  bool _validate() {
    _errors.clear();
    bool isValid = true;

    if (_formData.ageBand.isEmpty) {
      _errors['age_band'] = 'Age band is required';
      isValid = false;
    }
    if (_formData.housing.isEmpty) {
      _errors['housing'] = 'Housing status is required';
      isValid = false;
    }
    if (_formData.employment.isEmpty) {
      _errors['employment'] = 'Employment type is required';
      isValid = false;
    }
    if (_formData.incomeRegularity.isEmpty) {
      _errors['income_regularity'] = 'Income regularity is required';
      isValid = false;
    }
    if (_formData.regionCode.isEmpty) {
      _errors['region_code'] = 'Region is required';
      isValid = false;
    }

    setState(() {});
    return isValid;
  }

  void _handleSubmit() {
    if (_validate()) {
      widget.onSubmit(_formData);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tell Us About Yourself',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This helps us recommend the right goals for you.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            // Age Band
            DropdownButtonFormField<String>(
              value: _formData.ageBand.isEmpty ? null : _formData.ageBand,
              decoration: InputDecoration(
                labelText: 'Age Range *',
                errorText: _errors['age_band'],
                border: const OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: '18-24', child: Text('18-24')),
                DropdownMenuItem(value: '25-34', child: Text('25-34')),
                DropdownMenuItem(value: '35-44', child: Text('35-44')),
                DropdownMenuItem(value: '45-54', child: Text('45-54')),
                DropdownMenuItem(value: '55+', child: Text('55+')),
              ],
              onChanged: (value) {
                setState(() {
                  _formData = LifeContext(
                    ageBand: value ?? '',
                    dependentsSpouse: _formData.dependentsSpouse,
                    dependentsChildrenCount: _formData.dependentsChildrenCount,
                    dependentsParentsCare: _formData.dependentsParentsCare,
                    housing: _formData.housing,
                    employment: _formData.employment,
                    incomeRegularity: _formData.incomeRegularity,
                    regionCode: _formData.regionCode,
                    emergencyOptOut: _formData.emergencyOptOut,
                  );
                });
              },
            ),
            const SizedBox(height: 16),
            // Housing
            DropdownButtonFormField<String>(
              value: _formData.housing.isEmpty ? null : _formData.housing,
              decoration: InputDecoration(
                labelText: 'Housing Status *',
                errorText: _errors['housing'],
                border: const OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'rent', child: Text('Renting')),
                DropdownMenuItem(value: 'own_mortgage', child: Text('Own with Mortgage')),
                DropdownMenuItem(value: 'own_nomortgage', child: Text('Own without Mortgage')),
                DropdownMenuItem(value: 'living_with_parents', child: Text('Living with Parents')),
              ],
              onChanged: (value) {
                setState(() {
                  _formData = LifeContext(
                    ageBand: _formData.ageBand,
                    dependentsSpouse: _formData.dependentsSpouse,
                    dependentsChildrenCount: _formData.dependentsChildrenCount,
                    dependentsParentsCare: _formData.dependentsParentsCare,
                    housing: value ?? '',
                    employment: _formData.employment,
                    incomeRegularity: _formData.incomeRegularity,
                    regionCode: _formData.regionCode,
                    emergencyOptOut: _formData.emergencyOptOut,
                  );
                });
              },
            ),
            const SizedBox(height: 16),
            // Employment
            DropdownButtonFormField<String>(
              value: _formData.employment.isEmpty ? null : _formData.employment,
              decoration: InputDecoration(
                labelText: 'Employment Type *',
                errorText: _errors['employment'],
                border: const OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'salaried', child: Text('Salaried')),
                DropdownMenuItem(value: 'self_employed', child: Text('Self Employed')),
                DropdownMenuItem(value: 'student', child: Text('Student')),
                DropdownMenuItem(value: 'homemaker', child: Text('Homemaker')),
                DropdownMenuItem(value: 'retired', child: Text('Retired')),
              ],
              onChanged: (value) {
                setState(() {
                  _formData = LifeContext(
                    ageBand: _formData.ageBand,
                    dependentsSpouse: _formData.dependentsSpouse,
                    dependentsChildrenCount: _formData.dependentsChildrenCount,
                    dependentsParentsCare: _formData.dependentsParentsCare,
                    housing: _formData.housing,
                    employment: value ?? '',
                    incomeRegularity: _formData.incomeRegularity,
                    regionCode: _formData.regionCode,
                    emergencyOptOut: _formData.emergencyOptOut,
                  );
                });
              },
            ),
            const SizedBox(height: 16),
            // Income Regularity
            DropdownButtonFormField<String>(
              value: _formData.incomeRegularity.isEmpty ? null : _formData.incomeRegularity,
              decoration: InputDecoration(
                labelText: 'Income Stability *',
                errorText: _errors['income_regularity'],
                border: const OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'very_stable', child: Text('Very Stable')),
                DropdownMenuItem(value: 'stable', child: Text('Stable')),
                DropdownMenuItem(value: 'variable', child: Text('Variable')),
              ],
              onChanged: (value) {
                setState(() {
                  _formData = LifeContext(
                    ageBand: _formData.ageBand,
                    dependentsSpouse: _formData.dependentsSpouse,
                    dependentsChildrenCount: _formData.dependentsChildrenCount,
                    dependentsParentsCare: _formData.dependentsParentsCare,
                    housing: _formData.housing,
                    employment: _formData.employment,
                    incomeRegularity: value ?? '',
                    regionCode: _formData.regionCode,
                    emergencyOptOut: _formData.emergencyOptOut,
                  );
                });
              },
            ),
            const SizedBox(height: 16),
            // Region
            DropdownButtonFormField<String>(
              value: _formData.regionCode.isEmpty ? null : _formData.regionCode,
              decoration: InputDecoration(
                labelText: 'Region *',
                errorText: _errors['region_code'],
                border: const OutlineInputBorder(),
              ),
              items: indianStates.map((state) {
                return DropdownMenuItem(value: state, child: Text(state));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _formData = LifeContext(
                    ageBand: _formData.ageBand,
                    dependentsSpouse: _formData.dependentsSpouse,
                    dependentsChildrenCount: _formData.dependentsChildrenCount,
                    dependentsParentsCare: _formData.dependentsParentsCare,
                    housing: _formData.housing,
                    employment: _formData.employment,
                    incomeRegularity: _formData.incomeRegularity,
                    regionCode: value ?? '',
                    emergencyOptOut: _formData.emergencyOptOut,
                  );
                });
              },
            ),
            const SizedBox(height: 16),
            // Dependents - Spouse
            CheckboxListTile(
              title: const Text('I have a spouse/partner'),
              value: _formData.dependentsSpouse,
              onChanged: (value) {
                setState(() {
                  _formData = LifeContext(
                    ageBand: _formData.ageBand,
                    dependentsSpouse: value ?? false,
                    dependentsChildrenCount: _formData.dependentsChildrenCount,
                    dependentsParentsCare: _formData.dependentsParentsCare,
                    housing: _formData.housing,
                    employment: _formData.employment,
                    incomeRegularity: _formData.incomeRegularity,
                    regionCode: _formData.regionCode,
                    emergencyOptOut: _formData.emergencyOptOut,
                  );
                });
              },
            ),
            // Dependents - Children
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Number of Children',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              initialValue: _formData.dependentsChildrenCount.toString(),
              onChanged: (value) {
                setState(() {
                  _formData = LifeContext(
                    ageBand: _formData.ageBand,
                    dependentsSpouse: _formData.dependentsSpouse,
                    dependentsChildrenCount: int.tryParse(value) ?? 0,
                    dependentsParentsCare: _formData.dependentsParentsCare,
                    housing: _formData.housing,
                    employment: _formData.employment,
                    incomeRegularity: _formData.incomeRegularity,
                    regionCode: _formData.regionCode,
                    emergencyOptOut: _formData.emergencyOptOut,
                  );
                });
              },
            ),
            const SizedBox(height: 8),
            // Dependents - Parents
            CheckboxListTile(
              title: const Text('I care for my parents'),
              value: _formData.dependentsParentsCare,
              onChanged: (value) {
                setState(() {
                  _formData = LifeContext(
                    ageBand: _formData.ageBand,
                    dependentsSpouse: _formData.dependentsSpouse,
                    dependentsChildrenCount: _formData.dependentsChildrenCount,
                    dependentsParentsCare: value ?? false,
                    housing: _formData.housing,
                    employment: _formData.employment,
                    incomeRegularity: _formData.incomeRegularity,
                    regionCode: _formData.regionCode,
                    emergencyOptOut: _formData.emergencyOptOut,
                  );
                });
              },
            ),
            // Emergency Opt Out
            CheckboxListTile(
              title: const Text('Opt out of Emergency Fund goal'),
              value: _formData.emergencyOptOut,
              onChanged: (value) {
                setState(() {
                  _formData = LifeContext(
                    ageBand: _formData.ageBand,
                    dependentsSpouse: _formData.dependentsSpouse,
                    dependentsChildrenCount: _formData.dependentsChildrenCount,
                    dependentsParentsCare: _formData.dependentsParentsCare,
                    housing: _formData.housing,
                    employment: _formData.employment,
                    incomeRegularity: _formData.incomeRegularity,
                    regionCode: _formData.regionCode,
                    emergencyOptOut: value ?? false,
                  );
                });
              },
            ),
            const SizedBox(height: 24),
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (widget.onSkip != null)
                  TextButton(
                    onPressed: widget.onSkip,
                    child: const Text('Skip'),
                  )
                else
                  const SizedBox.shrink(),
                ElevatedButton(
                  onPressed: _handleSubmit,
                  child: const Text('Continue'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

