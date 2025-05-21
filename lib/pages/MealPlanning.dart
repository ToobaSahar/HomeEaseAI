import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../pages/ai_recipe_agent.dart';

class RecipePromptScreen extends StatefulWidget {
  @override
  _RecipePromptScreenState createState() => _RecipePromptScreenState();
}

class _RecipePromptScreenState extends State<RecipePromptScreen> with TickerProviderStateMixin {
  final _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _healthController = TextEditingController();
  final TextEditingController _dietController = TextEditingController();
  String? selectedPlanId;
  String? _selectedCuisine;
  bool _isSpicy = false;
  String _selectedDiet = 'balanced'; // or 'keto', 'vegan', etc.
  final TextEditingController _maxCaloriesController = TextEditingController();
  final TextEditingController _minProteinController = TextEditingController();
  String _spiceLevel = 'Medium'; // Default value
  final _goalController = TextEditingController();
  final _mealsPerDayController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _dislikesController = TextEditingController();
  final _caloriesController = TextEditingController();
  bool _generating = false;

  final List<String> _cuisineOptions = [
    'Pakistani',
    'Chinese',
    'Italian',
    'Mexican',
    'Indian',
    'American',
    'Thai',
    'Japanese',
    'Mediterranean',
    'Other',
  ];


  late TabController _tabController;
  bool _loading = false;
  bool _checking = false;
  String? _response;
  String _dietResult = '';
  List<String> _fetchedRecipes = [];
  List<Map<String, dynamic>> _weeklyPlans = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _maxCaloriesController.text = '600';   // ✅ default max calories
    _minProteinController.text = '20';
    _fetchRecipesFromFirestore();
    _fetchWeeklyPlans();
  }

  Future<void> _generateRecipe() async {
    final basePrompt = _controller.text.trim();
    if (basePrompt.isEmpty) return;

    setState(() {
      _loading = true;
      _response = null;
    });

    try {
      final prefsPrompt = _buildPreferencePrompt();
      final fullPrompt = "$prefsPrompt\n\n$basePrompt";

      final recipe = await AIRecipeAgent.generateRecipe(fullPrompt);
      await AIRecipeAgent.saveRecipeToFirestore(recipe);

      final colors = [
        Colors.orange.shade50,
        Colors.blue.shade50,
        Colors.green.shade50,
        Colors.purple.shade50,
        Colors.teal.shade50,
        Colors.pink.shade50,
      ];
      final randomColor = (colors..shuffle()).first;

      _showRecipePopup(recipe, randomColor); // 👈 now with random color

      await Future.delayed(Duration(seconds: 1));
      await _fetchRecipesFromFirestore();
      setState(() => _controller.clear());
    } catch (e) {
      setState(() => _response = "Error: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  String _buildPreferencePrompt() {
    final spicy = _spiceLevel.toLowerCase();
    final diet = _selectedDiet;
    final maxCalories = int.tryParse(_maxCaloriesController.text);
    final minProtein = int.tryParse(_minProteinController.text);

    final buffer = StringBuffer(
        "Please generate a $spicy spice level, $diet-friendly recipe");

    if (maxCalories != null) buffer.write(" under $maxCalories calories");
    if (minProtein != null) buffer.write(
        " with at least $minProtein grams of protein");

    buffer.write(".");

    return buffer.toString();
  }

  Future<void> _fetchRecipesFromFirestore() async {
    setState(() {
      _loading = true;
      _fetchedRecipes = [];
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('mealPlans')
          .doc(user.uid)
          .collection('recipes')
          .orderBy('timestamp', descending: true)
          .get();

      final List<String> recipesList = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final title = data['title'] ?? 'Untitled Recipe';
        final ingredients = _asListOfStrings(data['ingredients']);
        final instructions = _asListOfStrings(data['instructions']);
        final nutritionsRaw = data['nutrition'] ?? {};

        final buffer = StringBuffer();
        buffer.writeln(title);
        buffer.writeln("\nIngredients:");
        for (var item in ingredients)
          buffer.writeln("- $item");
        buffer.writeln("\nInstructions:");
        for (int i = 0; i < instructions.length; i++) {
          buffer.writeln("${i + 1}. ${instructions[i]}");
        }

        buffer.writeln("\nNutrition Facts:");
        if (nutritionsRaw is Map) {
          nutritionsRaw.forEach((key, value) {
            buffer.writeln("$key: ${value.toString()}");
          });
        }

        recipesList.add(buffer.toString());
      }

      setState(() {
        _fetchedRecipes = recipesList;
        _response = recipesList.isEmpty ? "No recipes found." : null;
      });

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
            0.0, duration: Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    } catch (e) {
      setState(() => _response = "Error fetching recipes: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  List<String> _asListOfStrings(dynamic data) {
    if (data is List) return List<String>.from(data);
    if (data is String) return data.split('\n');
    return [];
  }

  Widget _buildRecipeTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: 'Enter your recipe prompt',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 12),

          // 🔽 Preferences added here
          DropdownButtonFormField<String>(
            value: _spiceLevel,
            decoration: InputDecoration(labelText: 'Spice Level'),
            items: ['Zero', 'Low', 'Medium', 'High']
                .map((level) => DropdownMenuItem(
              value: level,
              child: Text(level),
            ))
                .toList(),
            onChanged: (val) => setState(() => _spiceLevel = val!),
          ),

          DropdownButtonFormField<String>(
            value: _selectedDiet,
            decoration: InputDecoration(labelText: 'Diet Type'),
            items: ['balanced', 'keto', 'vegan', 'low carb', 'high protein']
                .map((diet) => DropdownMenuItem(
              value: diet,
              child: Text(diet),
            ))
                .toList(),
            onChanged: (val) => setState(() => _selectedDiet = val!),
          ),
          SizedBox(height: 10),

          TextField(
            controller: _maxCaloriesController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Max Calories',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 10),

          TextField(
            controller: _minProteinController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Min Protein (g)',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 12),

          ElevatedButton(
            onPressed: _loading ? null : _generateRecipe,
            child: Text('Generate Recipe'),
          ),
          SizedBox(height: 20),

          if (_loading) CircularProgressIndicator(),

          if (_response != null)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Text(
                _response!,
                style: TextStyle(color: Colors.red),
              ),
            ),
          SizedBox(height: 12),

          // 🔽 History Button added here
          ElevatedButton.icon(
            icon: Icon(Icons.history),
            label: Text('View History'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RecipeHistoryScreen(recipes: _fetchedRecipes),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showRecipePopup(Map<String, dynamic> recipeData, Color backgroundColor) {
    final title = recipeData['title'] ?? 'Untitled Recipe';
    final ingredients = _asListOfStrings(recipeData['ingredients']);
    final instructions = _asListOfStrings(recipeData['instructions']);
    final nutrition = recipeData['nutrition'] ?? {};

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 40.0),
                child: SingleChildScrollView(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 14.5,
                        color: Colors.grey.shade800,
                        height: 1.5,
                        fontFamily: 'serif',
                      ),
                      children: [
                        TextSpan(
                          text: '$title\n\n',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        TextSpan(
                          text: 'Ingredients:\n',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        ...ingredients.map((e) => TextSpan(text: '- $e\n')),
                        TextSpan(
                          text: '\nInstructions:\n',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        ...instructions.asMap().entries.map(
                              (e) => TextSpan(text: '${e.key + 1}. ${e.value}\n'),
                        ),
                        if (nutrition is Map && nutrition.isNotEmpty)
                          TextSpan(
                            text: '\nNutrition Facts:\n',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        if (nutrition is Map)
                          ...nutrition.entries.map(
                                (e) => TextSpan(text: '${e.key}: ${e.value}\n'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // Close button
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: Icon(Icons.close, color: Colors.redAccent),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _fetchWeeklyPlans() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('mealPlans')
        .doc(uid)
        .collection('weeklyPlans')
        .orderBy('createdAt', descending: true)
        .get();

    setState(() {
      _weeklyPlans = snapshot.docs.map((doc) =>
      {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    });
  }

  Widget _buildWeeklyPlansTab() {
    Future<void> _generatePlan() async {
      final goal = _goalController.text.trim();
      final mealsPerDay = _mealsPerDayController.text.trim();
      final allergies = _allergiesController.text
          .trim()
          .isEmpty ? "none" : _allergiesController.text.trim();
      final dislikes = _dislikesController.text
          .trim()
          .isEmpty ? "none" : _dislikesController.text.trim();
      final calories = _caloriesController.text
          .trim()
          .isEmpty ? "unspecified" : _caloriesController.text.trim();

      if (goal.isEmpty || mealsPerDay.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Please enter both goal and meals per day.")));
        return;
      }

      setState(() => _generating = true);

      try {
        await AIRecipeAgent.generateWeeklyPlan(
          goal: goal,
          mealsPerDay: int.tryParse(mealsPerDay) ?? 3,
          allergies: allergies,
          dislikes: dislikes,
          calories: calories,
          cuisine: _selectedCuisine ?? 'Any',
        );
        await _fetchWeeklyPlans();
      } catch (e) {
        print("Error generating plan: $e");
      } finally {
        setState(() => _generating = false);
      }
    }

    return StatefulBuilder(builder: (context, setLocalState) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _goalController,
                decoration: InputDecoration(
                    labelText: 'Diet goal', border: OutlineInputBorder())),
            SizedBox(height: 10),
            TextField(controller: _mealsPerDayController,
                decoration: InputDecoration(
                    labelText: 'Meals per day', border: OutlineInputBorder()),
                keyboardType: TextInputType.number),
            SizedBox(height: 10),
            TextField(controller: _allergiesController,
                decoration: InputDecoration(labelText: 'Allergies (optional)',
                    border: OutlineInputBorder())),
            SizedBox(height: 10),
            TextField(controller: _dislikesController,
                decoration: InputDecoration(labelText: 'Dislikes (optional)',
                    border: OutlineInputBorder())),
            SizedBox(height: 10),
            TextField(controller: _caloriesController,
                decoration: InputDecoration(
                    labelText: 'Calories per day (optional)',
                    border: OutlineInputBorder()),
                keyboardType: TextInputType.number),
            SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: _selectedCuisine,
              decoration: InputDecoration(
                labelText: 'Cuisine',
                border: OutlineInputBorder(),
              ),
              items: _cuisineOptions.map((cuisine) {
                return DropdownMenuItem<String>(
                  value: cuisine,
                  child: Text(cuisine),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCuisine = value;
                });
              },
            ),
            SizedBox(height: 15),

            ElevatedButton.icon(
              icon: Icon(Icons.auto_awesome),
              label: Text(
                  _generating ? 'Generating...' : 'Generate Weekly Plan'),
              onPressed: _generating ? null : _generatePlan,

            ),
            if (_generating) ...[
              SizedBox(height: 10),
              CircularProgressIndicator(),
            ],

            SizedBox(height: 20),
            Expanded(
              child: _weeklyPlans.isEmpty
                  ? Center(child: Text("No weekly plans found."))
                  : RefreshIndicator(
                onRefresh: _fetchWeeklyPlans,
                child: ListView.builder(
                  itemCount: _weeklyPlans.length,
                  itemBuilder: (context, index) {
                    final plan = _weeklyPlans[index];
                    final days = List<Map<String, dynamic>>.from(plan['days']);
                    final preview = days
                        .expand((day) => List<Map<String, dynamic>>.from(day['meals']))
                        .take(2)
                        .map((meal) => "- ${meal['name']}")
                        .join(", ") + '...';
                    final formatted = days.map((day) {
                      final meals = List<Map<String, dynamic>>.from(
                          day['meals']);
                      return "${day['day']}:\n" +
                          meals.map((
                              meal) => "- ${meal['name']}: ${meal['description']}")
                              .join("\n");
                    }).join("\n\n");

                    return Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 3,
                      color: Colors.green.shade50,
                      child: Column(
                        children: [
                          ExpansionTile(
                            title: Text(preview),
                            children: days.map((day) {
                              final meals = List<Map<String, dynamic>>.from(day['meals']);
                              return Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(day['day'],
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    ...meals.map((meal) => ListTile(
                                      title: Text(meal['name']),
                                      subtitle: Text(meal['description']),
                                    )),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: IconButton(
                              icon: Icon(
                                  Icons.arrow_forward_ios, color: Colors.green),
                              onPressed: () {
                                setState(() {
                                  // Store selected plan ID and prefill the diet controller
                                  selectedPlanId =
                                  plan['id']; // Ensure each plan includes 'id' when fetching
                                  _dietController.text = formatted;
                                  _tabController.index = 2;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildDietCheckerTab(String planId) {
    Future<void> _checkCompatibility() async {
      final health = _healthController.text.trim();
      final diet = _dietController.text.trim();

      if (health.isEmpty || diet.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please fill in both fields.")),
        );
        return;
      }

      setState(() {
        _checking = true;
        _dietResult = '';
      });

      try {
        final response = await AIRecipeAgent.checkDietCompatibility(
          healthConditions: health,
          currentDiet: diet,
          planId: planId, // ✅ Pass the required planId here
        );
        setState(() => _dietResult = response);
      } catch (e) {
        setState(() => _dietResult = "Error: $e");
      } finally {
        setState(() => _checking = false);
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _healthController,
            decoration: InputDecoration(labelText: 'Enter health conditions',
                border: OutlineInputBorder()),
          ),
          SizedBox(height: 10),
          TextField(
            controller: _dietController,
            decoration: InputDecoration(
                labelText: 'Current diet', border: OutlineInputBorder()),
            maxLines: 4,
          ),
          SizedBox(height: 15),
          ElevatedButton.icon(
            icon: Icon(Icons.health_and_safety),
            label: Text(_checking ? 'Checking...' : 'Check Compatibility'),
            onPressed: _checking ? null : _checkCompatibility,
          ),
          SizedBox(height: 20),
          if (_dietResult.isNotEmpty)
            Expanded(
              child: SingleChildScrollView(
                child: Text(_dietResult, style: TextStyle(fontSize: 16)),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    _dietController.dispose();
    _healthController.dispose();
    _maxCaloriesController.dispose();
    _minProteinController.dispose();
    _goalController.dispose();
    _mealsPerDayController.dispose();
    _allergiesController.dispose();
    _dislikesController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  Widget _buildSelectPlanPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(
          'Please select a weekly meal plan from the "Weekly Plans" tab to check diet compatibility.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AI Meal Planner'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Recipes'),
            Tab(text: 'Weekly Plans'),
            Tab(text: 'Diet Checker'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRecipeTab(),
          _buildWeeklyPlansTab(),
          selectedPlanId == null
              ? _buildSelectPlanPlaceholder()
              : _buildDietCheckerTab(selectedPlanId!),
        ],
      ),
    );
  }

}

class RecipeHistoryScreen extends StatelessWidget {
  final List<String> recipes;

  const RecipeHistoryScreen({Key? key, required this.recipes}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = [
      Colors.orange.shade50,
      Colors.blue.shade50,
      Colors.green.shade50,
      Colors.purple.shade50,
      Colors.teal.shade50,
      Colors.pink.shade50,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Recipe History'),
      ),
      body: recipes.isEmpty
          ? Center(child: Text("No recipes found."))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: recipes.length,
        itemBuilder: (context, index) {
          final recipe = recipes[index];
          return Card(
            color: colors[index % colors.length],
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 14.5,
                    color: Colors.grey.shade800,
                    height: 1.5,
                    fontFamily: 'serif',
                  ),
                  children: recipe.split('\n').map((line) {
                    final trimmed = line.trim();
                    if ([
                      "Ingredients:",
                      "Instructions:",
                      "Nutrition Facts:"
                    ].contains(trimmed)) {
                      return TextSpan(
                        text: '$trimmed\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      );
                    }
                    return TextSpan(text: '$trimmed\n');
                  }).toList(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
