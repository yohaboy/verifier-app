import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../providers/app_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _trxController = TextEditingController();
  final _accountController = TextEditingController();

  void _verify() async {
    if (_trxController.text.isEmpty) return;
    final result = await context.read<AppProvider>().verifyTrx(_trxController.text);
    if (!mounted) return;

    if (result != null && result['success']) {
      _showResultDialog(true, result['data']);
    } else {
      _showResultDialog(false, result?['message'] ?? 'Verification failed');
    }
  }

  void _showResultDialog(bool success, dynamic data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(success ? Icons.check_circle : Icons.error, 
                 color: success ? Colors.green : Colors.red),
            const SizedBox(width: 10),
            Text(success ? 'Verified' : 'Failed'),
          ],
        ),
        content: success 
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Transaction Details:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _infoRow('Amount', '${data['transaction']?['amount'] ?? 'N/A'} ETB'),
                _infoRow('Payer', data['transaction']?['senderAccount']?.toString() ?? 'Anonymous'),
                _infoRow('Date', data['transaction']?['createdAt']?.toString().split('T')[0] ?? 'N/A'),
              ],
            )
          : Text(data.toString()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          )
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _scan() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Scan QR Code'),
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          body: Stack(
            children: [
              MobileScanner(
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty) {
                    Navigator.of(context).pop(barcodes.first.rawValue);
                  }
                },
              ),
              Center(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result != null) {
      _trxController.text = result;
      _verify();
    }
  }

  void _addAccount() async {
    if (_accountController.text.isEmpty) return;
    final provider = context.read<AppProvider>();
    final success = await provider.addCbeAccount(_accountController.text);
    
    if (!mounted) return;
    if (success) {
      _accountController.clear();
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Failed to add account'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Account'),
        content: const Text('Remove this CBE account from your dashboard?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<AppProvider>().deleteCbeAccount(id);
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: provider.logout,
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'Welcome back,',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            Text(
              provider.userName ?? 'Manager',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            _buildVerifyCard(provider),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('CBE Accounts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                if (provider.cbeAccounts.isEmpty)
                  IconButton.filledTonal(
                    onPressed: _showAddAccountDialog,
                    icon: const Icon(Icons.add),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (provider.cbeAccounts.isEmpty)
              _buildEmptyState()
            else
              ...provider.cbeAccounts.map((acc) => _buildAccountCard(acc)),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildVerifyCard(AppProvider provider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF673AB7), Color(0xFF9575CD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF673AB7).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_user, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('QUICK VERIFY', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _trxController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter Transaction ID',
              hintStyle: const TextStyle(color: Colors.white60),
              fillColor: Colors.white.withOpacity(0.1),
              filled: true,
              suffixIcon: IconButton(
                onPressed: _scan,
                icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: provider.isLoading ? null : _verify,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF673AB7),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('VERIFY NOW', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(dynamic acc) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.purple[50], borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.account_balance, color: Colors.purple),
        ),
        title: Text(acc['accountNumber'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(acc['holderName'] ?? 'CBE Account', style: TextStyle(color: Colors.grey[600])),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          onPressed: () => _confirmDelete(acc['id']),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(Icons.account_balance_wallet_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('No CBE accounts added', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          const Text('Add an account to start verifying', style: TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }

  void _showAddAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Add Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your CBE account number to receive transaction notifications.', style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 24),
            TextField(
              controller: _accountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Account Number', hintText: '1000...'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(onPressed: _addAccount, child: const Text('ADD ACCOUNT')),
        ],
      ),
    );
  }
}
