import 'package:flutter/material.dart';
import 'package:error_boundary/error_boundary.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Error Boundary Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error Boundary Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            title: 'Basic Error Boundary',
            child: ErrorBoundary(
              child: const BuggyCounter(),
            ),
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Custom Fallback',
            child: ErrorBoundary(
              fallback: (error, retry) => Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.warning, color: Colors.red, size: 48),
                      const SizedBox(height: 8),
                      Text(
                        'Oops! ${error.message}',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: retry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              ),
              child: const BuggyCounter(),
            ),
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'With Console Reporter',
            child: ErrorBoundary(
              reporters: [ConsoleReporter()],
              onError: (error, stack) {
                debugPrint('Error caught: $error');
              },
              child: const BuggyCounter(),
            ),
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Extension Syntax',
            child: const BuggyCounter().withErrorBoundary(
              fallback: (error, retry) => Center(
                child: TextButton(
                  onPressed: retry,
                  child: const Text('Error! Tap to retry'),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Auto-Retry (3 attempts)',
            child: ErrorBoundary(
              recovery: const RecoveryStrategy.retry(
                maxAttempts: 3,
                delay: Duration(seconds: 1),
              ),
              child: const BuggyCounter(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

/// A counter widget that throws an error when count reaches 3.
class BuggyCounter extends StatefulWidget {
  const BuggyCounter({super.key});

  @override
  State<BuggyCounter> createState() => _BuggyCounterState();
}

class _BuggyCounterState extends State<BuggyCounter> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    if (_count >= 3) {
      throw Exception('Counter exploded at $_count!');
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Count: $_count',
              style: const TextStyle(fontSize: 18),
            ),
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _count--),
                  icon: const Icon(Icons.remove),
                ),
                IconButton(
                  onPressed: () => setState(() => _count++),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
