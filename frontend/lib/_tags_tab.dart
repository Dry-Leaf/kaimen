import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '_backend_conn.dart' show Message, messageByTypeProvider;

import "_search_box.dart" show WithSuggestions;
import '_suggestions.dart' show Suggestion, SuggestionList;

const Map<int, String> catMap = {
  0: 'General',
  1: 'Artist',
  3: 'Copyright',
  4: 'Character',
  5: 'Meta',
};

class SelectedCategory extends Notifier<String> {
  @override
  String build() {
    final autosuggestMessage = ref.watch(
      messageByTypeProvider(Message.autosuggest),
    );

    return autosuggestMessage.maybeWhen(
      data: (msg) {
        if (msg == null) return "General";
        final parsed = (msg as List)
            .map((e) => Suggestion.fromJson(e))
            .toList();
        if (parsed.isEmpty) return "General";
        return catMap[parsed[0].category] ?? "General";
      },
      orElse: () => "General",
    );
  }

  void update(String newValue) {
    state = newValue;
  }
}

final selectedCategoryProvider = NotifierProvider<SelectedCategory, String>(
  SelectedCategory.new,
);

class TagCatMenu extends ConsumerWidget {
  const TagCatMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dropdownValue = ref.watch(selectedCategoryProvider);

    return DropdownButton<String>(
      value: dropdownValue,
      icon: const Icon(Icons.arrow_downward),
      onChanged: (String? value) {
        if (value != null) {
          ref.read(selectedCategoryProvider.notifier).update(value);
        }
      },
      items: catMap.values.map<DropdownMenuItem<String>>((var value) {
        return DropdownMenuItem<String>(value: value, child: Text(value));
      }).toList(),
    );
  }
}

class TagInputText extends Notifier<String> {
  @override
  String build() => "";

  void update(String newText) => state = newText;
}

final tagInputTextProvider = NotifierProvider<TagInputText, String>(
  TagInputText.new,
);

class TagsTab extends ConsumerStatefulWidget {
  const TagsTab({super.key});

  @override
  ConsumerState createState() => _TagsTabState();
}

class _TagsTabState extends ConsumerState with WithSuggestions {
  late final TextEditingController tagController;

  @override
  void initState() {
    super.initState();
    tagController = TextEditingController();

    initSuggestions(7);
    final initialText = ref.read(tagInputTextProvider);
    textController.text = initialText;

    textController.addListener(() {
      ref.read(tagInputTextProvider.notifier).update(textController.text);
    });
  }

  Widget createTextBox() {
    return OverlayPortal(
      controller: overlayController,
      overlayChildBuilder: (context) => UnconstrainedBox(
        child: CompositedTransformFollower(
          link: link,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, .5),
          child: ValueListenableBuilder<List<Suggestion>>(
            valueListenable: suggestions,
            builder: (context, currentSuggestions, _) {
              if (currentSuggestions.isEmpty) return const SizedBox.shrink();
              final double targetWidth = link.leaderSize?.width ?? 100.0;

              return SizedBox(
                width: targetWidth,
                height: suggestions.value.length * 27 + 2,
                child: SuggestionList(
                  suggestions,
                  textController,
                  textFieldFocusNode,
                  suggestionsFocusNode,
                  multi: false,
                ),
              );
            },
          ),
        ),
      ),
      child: CompositedTransformTarget(
        link: link,
        child: Focus(
          onFocusChange: (hasFocus) {
            if (hasFocus) {
              priorIndex = 0;
            }
          },
          onKeyEvent: handleKeyEvent,
          child: TextField(
            focusNode: textFieldFocusNode,
            controller: textController,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Ex: blue_sky',
            ),
            inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    final autosuggestMessage = ref.watch(
      messageByTypeProvider(Message.autosuggest),
    );

    autosuggestMessage.when(
      data: (msg) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (msg == null) {
            suggestions.value = [];
            return;
          }

          final parsed = (msg as List)
              .map((e) => Suggestion.fromJson(e))
              .toList();

          suggestions.value = parsed;
        });
      },
      loading: () {},
      error: (_, _) {},
    );

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 300, child: createTextBox()),
                SizedBox(width: 60),
                TagCatMenu(),
              ],
            ),
            SizedBox(height: 140),
          ],
        ),
      ),
      floatingActionButton: Wrap(
        spacing: 16,
        children: [
          FloatingActionButton(
            foregroundColor: colorScheme.onTertiaryContainer,
            backgroundColor: colorScheme.surface,
            onPressed: () {},
            tooltip: 'Delete Tag',
            child: const Icon(Icons.delete),
          ),
          FloatingActionButton(
            onPressed: () {},
            tooltip: 'Save Tag',
            child: const Icon(Icons.save),
          ),
        ],
      ),
    );
  }
}
