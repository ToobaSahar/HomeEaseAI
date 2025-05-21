/*import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'MealPlanning.dart';
import 'ai_recipe_agent.dart';

class RecipeInputScreen extends StatefulWidget {
  @override
  _RecipeInputScreenState createState() => _RecipeInputScreenState();
}

class _RecipeInputScreenState extends State<RecipeInputScreen> {
  final TextEditingController _ingredientsController = TextEditingController();
  String selectedMealType = 'Dinner';
  String selectedDiet = 'None';
  bool isLoading = false;

  final mealTypes = ['Breakfast', 'Lunch', 'Dinner'];
  final diets = ['None', 'Vegan', 'Gluten-Free', 'Keto'];

  void generateRecipe() async {
    setState(() => isLoading = true);
    final ingredients = _ingredientsController.text.trim().split(',');
    final recipeId = const Uuid().v4();

    final recipe = await RecipeService.generateAndStoreRecipe(
      recipeId: recipeId,
      ingredients: ingredients,
      mealType: selectedMealType,
      dietaryPreference: selectedDiet,
    );

    setState(() => isLoading = false);

    if (recipe != null) {
      Navigator.pushNamed(
        context,
        '/mealPlanning',
        arguments: {'recipeId': recipeId},
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to generate recipe')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recipe Generator')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _ingredientsController,
              decoration: const InputDecoration(
                labelText: 'Ingredients (comma-separated)',
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField(
              value: selectedMealType,
              items: mealTypes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (value) => setState(() => selectedMealType = value as String),
              decoration: const InputDecoration(labelText: 'Meal Type'),
            ),
            DropdownButtonFormField(
              value: selectedDiet,
              items: diets.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
              onChanged: (value) => setState(() => selectedDiet = value as String),
              decoration: const InputDecoration(labelText: 'Dietary Preference'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isLoading ? null : generateRecipe,
              child: isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Generate Recipe'),
            ),
          ],
        ),
      ),
    );
  }
}
*/