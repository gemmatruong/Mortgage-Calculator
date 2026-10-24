import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = await SharedPreferences.getInstance();
  final mortgage = Mortgage(preferences);

  runApp(
    ChangeNotifierProvider(
      create: (context) => mortgage,
      child: const MortgageApp(),
    ),
  );
}

class Mortgage extends ChangeNotifier {
  final SharedPreferences preferences;

  double amount;
  int years;
  double rate;

  Mortgage(this.preferences)
    : amount = preferences.getDouble('amount') ?? 100000,
      years = preferences.getInt('years') ?? 30,
      rate = preferences.getDouble('rate') ?? 0.035;

  Future<void> updateLoan(
    double newAmount,
    int newYears,
    double newRate,
  ) async {
    amount = newAmount;
    years = newYears;
    rate = newRate;

    await preferences.setDouble('amount', amount);
    await preferences.setInt('years', years);
    await preferences.setDouble('rate', rate);

    notifyListeners();
  }

  double monthlyPayment() {
    final numberOfPayments = years * 12;
    final monthlyRate = rate / 12;

    if (numberOfPayments == 0) return 0;
    if (monthlyRate == 0) return amount / numberOfPayments;

    final power = pow(1 + monthlyRate, numberOfPayments).toDouble();
    return amount * monthlyRate / (1 - (1 / power));
  }

  double totalPayment() => monthlyPayment() * years * 12;
}

class MortgageApp extends StatelessWidget {
  const MortgageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mortgage Calculator',
      home: const MortgageHomePage(),
    );
  }
}

class MortgageHomePage extends StatefulWidget {
  const MortgageHomePage({super.key});

  @override
  State<MortgageHomePage> createState() => _MortgageHomePageState();
}

class _MortgageHomePageState extends State<MortgageHomePage> {
  bool termsAccepted = false;

  String money(double value) => '\$${value.toStringAsFixed(2)}';

  void openModifyScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ModifyScreen()),
    );
  }

  Future<void> showTermsDialog(bool? value) async {
    if (value != true) {
      setState(() => termsAccepted = false);
      return;
    }

    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms and Conditions'),
        content: const Text('Do you agree to the terms and conditions?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Agree'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    setState(() => termsAccepted = accepted == true);
  }

  @override
  Widget build(BuildContext context) {
    final mortgage = context.watch<Mortgage>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mortgage Calculator'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mortgage Information',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 25),
            Text(
              'Amount: ${money(mortgage.amount)}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 15),
            Text(
              'Years: ${mortgage.years}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 15),
            Text(
              'Interest Rate: '
              '${(mortgage.rate * 100).toStringAsFixed(2)}%',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 15),
            Text(
              'Monthly Payment: ${money(mortgage.monthlyPayment())}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 15),
            Text(
              'Total Payment: ${money(mortgage.totalPayment())}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 10),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Terms and Conditions'),
              value: termsAccepted,
              onChanged: showTermsDialog,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: openModifyScreen,
                child: const Text('Modify'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ModifyScreen extends StatefulWidget {
  const ModifyScreen({super.key});

  @override
  State<ModifyScreen> createState() => _ModifyScreenState();
}

class _ModifyScreenState extends State<ModifyScreen> {
  late final TextEditingController amountController;
  late final TextEditingController yearsController;
  late double selectedRate;

  @override
  void initState() {
    super.initState();

    final mortgage = context.read<Mortgage>();
    amountController = TextEditingController(text: mortgage.amount.toString());
    yearsController = TextEditingController(text: mortgage.years.toString());
    selectedRate = mortgage.rate;
  }

  @override
  void dispose() {
    amountController.dispose();
    yearsController.dispose();
    super.dispose();
  }

  Future<void> saveChanges() async {
    final amount = double.tryParse(amountController.text);
    final years = int.tryParse(yearsController.text);

    if (amount == null || years == null || amount <= 0 || years <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid amount and number of years.'),
        ),
      );
      return;
    }

    await context.read<Mortgage>().updateLoan(amount, years, selectedRate);

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modify Mortgage'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: yearsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Number of Years',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Select Interest Rate',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: 53,
                itemBuilder: (context, index) {
                  final ratePercent = 2 + (index * 0.25);
                  final rateDecimal = ratePercent / 100;

                  return RadioListTile<double>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text('${ratePercent.toStringAsFixed(2)}%'),
                    value: rateDecimal,
                    groupValue: selectedRate,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => selectedRate = value);
                      }
                    },
                  );
                },
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: saveChanges,
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
