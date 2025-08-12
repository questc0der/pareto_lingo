import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:flutter/material.dart';
import 'package:neubrutalism_ui/neubrutalism_ui.dart';
import 'package:pareto_lingo/models/flashcard_model.dart';

class FlashCardReviewScreen extends StatefulWidget {
  final int dailyLimit;
  const FlashCardReviewScreen({super.key, this.dailyLimit = 10});

  @override
  _FlashCardReviewScreenState createState() => _FlashCardReviewScreenState();
}

class _FlashCardReviewScreenState extends State<FlashCardReviewScreen> {
  late Box<Flashcard> box;
  late List<Flashcard> queue;
  List<Flashcard> sessionRepeats = [];
  int currentIndex = 0;
  bool showAnswer = false;

  @override
  void initState() {
    super.initState();
    box = Hive.box('flashcards');
    _prepareQueue();
  }

  void _prepareQueue() {
    final all = box.values.toList();
    final now = DateTime.now();

    queue =
        all
            .where((c) => !c.dueDate.isAfter(now))
            .take(widget.dailyLimit)
            .toList();

    currentIndex = 0;
    showAnswer = false;
    setState(() {});
  }

  void _rateCard(int quality) {
    final card = queue[currentIndex];
    card.updateReview(quality);

    if (quality < 5) {
      sessionRepeats.add(card);
    }

    if (currentIndex < queue.length - 1) {
      setState(() {
        currentIndex++;
        showAnswer = false;
      });
    } else {
      if (sessionRepeats.isNotEmpty) {
        queue = sessionRepeats;
        sessionRepeats = [];
        currentIndex = 0;
        showAnswer = false;
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Repeating cards rated other than Easy.')),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Review session complete!')));
        context.go('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (queue.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('Flashcards')),
        body: Center(child: Text('No cards due now.')),
      );
    }

    final card = queue[currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text('Flashcards (${currentIndex + 1}/${queue.length})'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: NeuCard(
                cardColor: Colors.white,
                borderRadius: BorderRadius.circular(24),
                child: Center(
                  child: Text(
                    showAnswer ? card.meaning : card.word,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Circular',
                    ),
                  ),
                ),
              ),
            ),
            if (!showAnswer)
              Padding(
                padding: const EdgeInsets.all(18.0),
                child: NeuTextButton(
                  borderRadius: BorderRadius.circular(8),
                  buttonColor: Color(0xFF7dF9FF),
                  enableAnimation: true,
                  onPressed: () => setState(() => showAnswer = true),
                  text: Text(
                    'Show Answer',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            if (showAnswer)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        NeuTextButton(
                          borderRadius: BorderRadius.circular(8),
                          enableAnimation: false,
                          onPressed: () => _rateCard(0),
                          buttonColor: Colors.red,
                          text: Text(
                            'Again',
                            style: TextStyle(
                              fontFamily: 'Circular',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        NeuTextButton(
                          enableAnimation: false,
                          buttonColor: Colors.orange,
                          borderRadius: BorderRadius.circular(8),
                          onPressed: () => _rateCard(2),
                          text: Text(
                            'Hard',
                            style: TextStyle(
                              fontFamily: 'Circular',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        NeuTextButton(
                          enableAnimation: false,
                          borderRadius: BorderRadius.circular(8),
                          buttonColor: Colors.blue,
                          onPressed: () => _rateCard(3),
                          text: Text(
                            'Medium',
                            style: TextStyle(
                              fontFamily: 'Circular',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        NeuTextButton(
                          enableAnimation: false,
                          buttonColor: Colors.green,
                          onPressed: () => _rateCard(5),
                          borderRadius: BorderRadius.circular(8),
                          text: Text(
                            'Easy',
                            style: TextStyle(
                              fontFamily: 'Circular',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
