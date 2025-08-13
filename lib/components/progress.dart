import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:neubrutalism_ui/neubrutalism_ui.dart';

class Progress extends StatelessWidget {
  const Progress({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(6),
      children: [
        Row(
          children: [
            Expanded(child: _buildStudiedCard(context)),
            SizedBox(width: 7),
            Expanded(child: _buildRemainingCard(context)),
          ],
        ),
        SizedBox(height: 16),
        _flashCardSection(context),
        SizedBox(height: 16),
        _speakingSection(context),
        SizedBox(height: 16),
        _rulesSection(context),
      ],
    );
  }

  Widget _buildCard(
    BuildContext context, {
    String? count,
    String? mode,
    double? height,
    double? width,
    String? title,
    String? description,
    String? buttonText,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: NeuContainer(
        height: height,
        width: width,
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (count != null)
                Text(
                  count,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Circular',
                  ),
                ),
              if (mode != null)
                Text(
                  mode,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Circular',
                  ),
                ),
              if (title != null)
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Circular',
                  ),
                ),
              if (description != null)
                Text(description, style: TextStyle(fontFamily: 'Circular')),
              if (buttonText != null)
                NeuTextButton(
                  borderRadius: BorderRadius.circular(8),
                  buttonColor: Color(0xFF7DF9FF),
                  buttonHeight: 40,
                  buttonWidth: 80,
                  onPressed: () {
                    if (buttonText == "Start") {
                      context.go('/flashcard');
                    } else if (buttonText == "Speak") {
                      context.go('/speak');
                    }
                  },
                  enableAnimation: true,
                  text: Text(
                    buttonText,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      fontFamily: 'Circular',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudiedCard(BuildContext context) {
    return _buildCard(
      context,
      count: "0",
      mode: "Studied",
      height: MediaQuery.of(context).size.width / 2.5,
    );
  }

  Widget _buildRemainingCard(BuildContext context) {
    return _buildCard(
      context,
      count: "1000",
      mode: "Remaining",
      height: MediaQuery.of(context).size.width / 2.5,
    );
  }

  Widget _flashCardSection(BuildContext context) {
    return _buildCard(
      context,
      title: "Flashcards",
      buttonText: "Start",
      description:
          "This is the description for the 100 commonly used french words",
      height: MediaQuery.of(context).size.height / 5,
    );
  }

  Widget _speakingSection(BuildContext context) {
    return _buildCard(
      context,
      mode: "Speaking",
      buttonText: "Speak",
      description:
          "This is the description for the 100 commonly used french words",
      height: MediaQuery.of(context).size.height / 5,
    );
  }

  Widget _rulesSection(BuildContext context) {
    return _buildCard(
      context,
      mode: "Grammar Rules",
      buttonText: "Study",
      description:
          "This is the description for the 100 commonly used french words",
      height: MediaQuery.of(context).size.height / 5,
    );
  }
}
