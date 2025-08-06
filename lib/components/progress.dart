import 'package:flutter/material.dart';

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
    return Container(
      height: height,
      width: width,
      padding: EdgeInsets.all(10),
      margin: EdgeInsets.symmetric(horizontal: 8.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (count != null)
            Text(
              count,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          if (mode != null)
            Text(
              mode,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          if (title != null)
            Text(
              title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          if (description != null) Text(description, style: TextStyle()),
          if (buttonText != null)
            ElevatedButton(onPressed: () {}, child: Text(buttonText)),
        ],
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
