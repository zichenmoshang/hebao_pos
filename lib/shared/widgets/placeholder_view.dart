import 'package:flutter/material.dart';

/// 尚未实现页面的统一占位
class PlaceholderView extends StatelessWidget {
  const PlaceholderView({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          '$title · 建设中',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}
