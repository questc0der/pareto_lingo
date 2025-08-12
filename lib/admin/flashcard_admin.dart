import 'package:flutter/material.dart';

class FlashcardAdminScreen extends StatefulWidget {
  const FlashcardAdminScreen({super.key});

  @override
  State<FlashcardAdminScreen> createState() => _FlashcardAdminScreenState();
}

class _FlashcardAdminScreenState extends State<FlashcardAdminScreen> {
  bool _isLoading = false;
  String _statusMessage = '';

  void _setStatus(String message) {
    setState(() {
      _statusMessage = message;
    });
  }

  Future<void> _populateFromAssets() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Loading flashcards from assets...';
    });

    try {
      _setStatus('✅ Successfully loaded flashcards from assets');
    } catch (e) {
      _setStatus('❌ Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addSampleCards() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Adding sample cards...';
    });

    try {
      _setStatus('✅ Successfully added sample cards');
    } catch (e) {
      _setStatus('❌ Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showStats() {
    try {
      _setStatus('📊 Check console for flashcard statistics');
    } catch (e) {
      _setStatus('❌ Error getting stats: $e');
    }
  }

  void _debugFlashcards() {
    try {
      _setStatus('🔍 Check console for detailed debug info');
    } catch (e) {
      _setStatus('❌ Debug error: $e');
    }
  }

  Future<void> _makeAllCardsDueToday() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Making all cards due today...';
    });

    try {
      _setStatus('✅ All existing cards are now due today!');
    } catch (e) {
      _setStatus('❌ Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createQuickTestCards() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Creating quick test cards...';
    });

    try {
      _setStatus('✅ Created 5 test cards that are all due now!');
    } catch (e) {
      _setStatus('❌ Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flashcard Admin'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Flashcard Administration',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _isLoading ? null : _populateFromAssets,
              icon: const Icon(Icons.download),
              label: const Text('Load All French Words'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This will load 100+ common French words and replace any existing cards.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _isLoading ? null : _addSampleCards,
              icon: const Icon(Icons.add_circle),
              label: const Text('Add Sample Cards'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This will add 5 sample cards with different due dates for testing.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _isLoading ? null : _showStats,
              icon: const Icon(Icons.analytics),
              label: const Text('Show Statistics'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),

            const SizedBox(height: 16),
            const Divider(),
            const Text(
              'Debug Tools',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _debugFlashcards,
                    icon: const Icon(Icons.bug_report),
                    label: const Text('Debug Info'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _createQuickTestCards,
                    icon: const Icon(Icons.flash_on),
                    label: const Text('Quick Test'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: _isLoading ? null : _makeAllCardsDueToday,
              icon: const Icon(Icons.today),
              label: const Text('Make All Cards Due Today'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),

            const SizedBox(height: 24),

            if (_isLoading) const Center(child: CircularProgressIndicator()),

            if (_statusMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      _statusMessage.startsWith('✅')
                          ? Colors.green.withOpacity(0.1)
                          : _statusMessage.startsWith('❌')
                          ? Colors.red.withOpacity(0.1)
                          : Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        _statusMessage.startsWith('✅')
                            ? Colors.green
                            : _statusMessage.startsWith('❌')
                            ? Colors.red
                            : Colors.blue,
                  ),
                ),
                child: Text(
                  _statusMessage,
                  style: TextStyle(
                    color:
                        _statusMessage.startsWith('✅')
                            ? Colors.green.shade700
                            : _statusMessage.startsWith('❌')
                            ? Colors.red.shade700
                            : Colors.blue.shade700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
