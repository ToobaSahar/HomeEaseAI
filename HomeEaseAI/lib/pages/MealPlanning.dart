import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf/pdf.dart';
import 'package:permission_handler/permission_handler.dart';
import '../pages/ai_recipe_agent.dart';
import 'package:pdf/widgets.dart' as pw;

class RecipePromptScreen extends StatefulWidget {
  @override
  _RecipePromptScreenState createState() => _RecipePromptScreenState();
}

class _RecipePromptScreenState extends State<RecipePromptScreen> with TickerProviderStateMixin {
  final _controller = TextEditingController();
  bool _showHistoryView = false;

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
  TextEditingController myController = TextEditingController()..text = '15000';
  bool _generating = false;

  final List<String> _cuisineOptions = [
    'Pakistani',
    'Chinese',
    'Italian',
    'Mexican',
    'Indian',
    'American',
    'Thai',
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
      padding: const EdgeInsets.fromLTRB(16, 5, 16, 16),
      child: _showHistoryView
          ? _buildHistoryContent()
          : _buildRecipeForm(), // your existing recipe form widget
    );
  }

  Widget _buildRecipeForm() {
    return SingleChildScrollView( // Add this to allow upward scroll if needed
    child: Column(

    children: [
      TextField(
        controller: _controller,
        cursorColor: Color(0xFFF46638), // 👈 black cursor
        style: TextStyle(
          color: Color(0xFFF46638), // 👈 black text
          fontFamily: 'FunnelDisplay',
        ),
        decoration: InputDecoration(
          hintText: 'Get the recipe you want  ', // 👈 use hint instead of label
          hintStyle: TextStyle(
            color: Color(0xFFF46638),
            fontFamily: 'FunnelDisplay',
          ),
          floatingLabelBehavior: FloatingLabelBehavior.never, // 👈 disables floating effect
          filled: true,
          fillColor: Colors.white, // optional: give white background if needed
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(
              color: Color(0xFFFFD6B0), // light peachish orange
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(
              color:  Color(0xFFFFD6B0), // vibrant orange when focused
              width: 2,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),

      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Spice level:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              fontFamily: 'FunnelDisplay',
              color: Color(0xFFF46638),
            ),
          ),
          SizedBox(
            width: 190, // Controls width of field and popup
            child: Theme(
              data: Theme.of(context).copyWith(
                cardTheme: CardTheme(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 4,
                  margin: EdgeInsets.zero,
                ),
              ),
              child: Container(
                padding: EdgeInsets.fromLTRB(12, 8, 12, 2), // ⬅️ more top padding, less bottom

                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isDense: true,
                    isExpanded: true,
                    value: _spiceLevel,
                    icon: Icon(Icons.arrow_drop_down, color: Color(0xFFFFD6B0)),
                    onChanged: (val) => setState(() => _spiceLevel = val!),
                    dropdownColor: Colors.white,
                    style: TextStyle(color: Color(0xFFF46638), fontSize: 14, fontFamily: 'FunnelDisplay'),
                    items: ['Zero', 'Low', 'Medium', 'High'].map((level) {
                      return DropdownMenuItem(
                        value: level,
                        child: Container(
                          height: 32, // 👈 Smaller height
                          alignment: Alignment.centerLeft,
                          child: Text(
                            level,
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),


      SizedBox(height: 12),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Diet type:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              fontFamily: 'FunnelDisplay',
              color: Color(0xFFF46638),
            ),
          ),
          SizedBox(
            width: 190, // Controls field and popup width
            child: Theme(
              data: Theme.of(context).copyWith(
                cardTheme: CardTheme(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 4,
                  margin: EdgeInsets.zero,
                ),
              ),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isDense: true,
                    isExpanded: true,
                    value: _selectedDiet,
                    icon: Icon(Icons.arrow_drop_down, color: Color(0xFFFFD6B0)),
                    onChanged: (val) => setState(() => _selectedDiet = val!),
                    dropdownColor: Colors.white,
                    style: TextStyle(
                      color: Color(0xFFF46638),
                      fontSize: 14,
                      fontFamily: 'FunnelDisplay',
                    ),
                    items: ['balanced', 'keto', 'vegan', 'low carb', 'high protein'].map((diet) {
                      return DropdownMenuItem(
                        value: diet,
                        child: Container(
                          height: 32, // 👈 Reduce popup item height
                          alignment: Alignment.centerLeft,
                          child: Text(
                            diet,
                            style: TextStyle(fontSize: 13), // 👈 Smaller font
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),


      SizedBox(height: 10),

      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Max Calories:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              fontFamily: 'FunnelDisplay',
              color: Color(0xFFF46638),
            ),
          ),
          SizedBox(
            width: 150,
            child: Theme(
              data: Theme.of(context).copyWith(
                textSelectionTheme: TextSelectionThemeData(
                  cursorColor: Color(0xFFFFD6B0),
                  selectionColor: Color(0x33FFD6B0), // translucent highlight
                  selectionHandleColor: Color(0xFFFFD6B0),
                ),
              ),
              child: TextField(
                controller: _maxCaloriesController,
                keyboardType: TextInputType.number,
                cursorColor: Color(0xFFFFD6B0),
                style: TextStyle(
                  color: Color(0xFFF46638),
                  fontFamily: 'FunnelDisplay',
                ),
                decoration: InputDecoration(
                  hintText: 'Max Calories',
                  hintStyle: TextStyle(
                    color: Color(0xFFF46638),
                    fontFamily: 'FunnelDisplay',
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(
                      color: Color(0xFFFFD6B0),
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(
                      color: Color(0xFFFFD6B0),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),

        ],
      ),
      SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Min Proteins:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              fontFamily: 'FunnelDisplay',
              color: Color(0xFFF46638),
            ),
          ),
          SizedBox(
            width: 150,
            child: Theme(
              data: Theme.of(context).copyWith(
                textSelectionTheme: TextSelectionThemeData(
                  cursorColor: Color(0xFFFFD6B0),
                  selectionColor: Color(0x33FFD6B0),
                  selectionHandleColor: Color(0xFFFFD6B0),
                ),
              ),
              child: TextField(
                controller: _minProteinController,
                keyboardType: TextInputType.number,
                cursorColor: Color(0xFFFFD6B0),
                style: TextStyle(
                  color: Color(0xFFF46638),
                  fontFamily: 'FunnelDisplay',
                ),
                decoration: InputDecoration(
                  hintText: 'Min Protein (g)',
                  hintStyle: TextStyle(
                    color: Color(0xFFF46638),
                    fontFamily: 'FunnelDisplay',
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(
                      color: Color(0xFFFFD6B0),
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(
                      color: Color(0xFFFFD6B0),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),

        ],
      ),


      SizedBox(height: 12),

      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFFFFD6B0), // Set button color
          foregroundColor: Color(0xFFF46638), // Optional text color (for Generate Recipe)
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: _loading ? null : _generateRecipe,
        child: Text(
          'Generate Recipe',
          style: TextStyle(
            fontFamily: 'FunnelDisplay',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),


      if (_loading) CircularProgressIndicator(),

          if (_response != null)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Text(
                _response!,
                style: TextStyle(color: Colors.red),
              ),
            ),

      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFFFFD6B0), // Background color
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(
          Icons.history,
          color: Color(0xFFF46638), // Icon color
        ),
        label: Text(
          'View History',
          style: TextStyle(
            color: Color(0xFFF46638), // Text color
            fontFamily: 'FunnelDisplay',
            fontWeight: FontWeight.w600,
          ),
        ),
        onPressed: _loading
            ? null
            : () async {
          await _generateRecipe();
          setState(() => _showHistoryView = true); // 👈 show history
        },

      ),


    ],
      ),
    );

  }

  Widget _buildHistoryContent() {
    final colors = [
      Colors.orange.shade50,
      Colors.blue.shade50,
      Colors.green.shade50,
      Colors.purple.shade50,
      Colors.teal.shade50,
      Colors.pink.shade50,
    ];

    return _fetchedRecipes.isEmpty
        ? Center(
      child: Text(
        "No recipes found.",
        style: TextStyle(fontFamily: 'FunnelDisplay'),
      ),
    )
        : Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 5),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFFFD6B0),
              foregroundColor: Color(0xFFF46638),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: Icon(Icons.arrow_back),
            label: Text(
              'Go Back',
              style: TextStyle(
                fontFamily: 'FunnelDisplay',
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () => setState(() => _showHistoryView = false),
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _fetchedRecipes.length,
            itemBuilder: (context, index) {
              final recipe = _fetchedRecipes[index];
              final lines = recipe.split('\n').where((line) => line.trim().isNotEmpty).toList();

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
                    textAlign: TextAlign.start,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 14.5,
                        color: Colors.grey.shade800,
                        height: 1.5,
                        fontFamily: 'FunnelDisplay',
                      ),
                      children: lines.asMap().entries.map((entry) {
                        final i = entry.key;
                        final line = entry.value.trim();

                        // First line is the title → make it bold and centered
                        if (i == 0) {
                          return WidgetSpan(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Center(
                                child: Text(
                                  line,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'FunnelDisplay',
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        // Bold section headers
                        if (["Ingredients:", "Instructions:", "Nutrition Facts:"].contains(line)) {
                          return TextSpan(
                            text: '$line\n',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontFamily: 'FunnelDisplay',
                            ),
                          );
                        }

                        return TextSpan(text: '$line\n');
                      }).toList(),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 14.5,
                              color: Colors.grey.shade800,
                              height: 1.5,
                              fontFamily: 'FunnelDisplay',
                            ),
                            children: [
                              TextSpan(
                                text: '$title\n\n',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  fontFamily: 'FunnelDisplay',
                                ),
                              ),
                              TextSpan(
                                text: 'Ingredients:\n',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'FunnelDisplay',
                                ),
                              ),
                              ...ingredients.map((e) => TextSpan(text: '- $e\n')),
                              TextSpan(
                                text: '\nInstructions:\n',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'FunnelDisplay',
                                ),
                              ),
                              ...instructions.asMap().entries.map(
                                    (e) => TextSpan(text: '${e.key + 1}. ${e.value}\n'),
                              ),
                              if (nutrition is Map && nutrition.isNotEmpty)
                                TextSpan(
                                  text: '\nNutrition Facts:\n',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'FunnelDisplay',
                                  ),
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
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: Icon(Icons.download, color: Colors.white),
                      label: Text(
                        'Export Recipe',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'FunnelDisplay',
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFF46638),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _exportRecipeAsPdf(title, ingredients, instructions, nutrition);
                      },
                    ),
                  ],
                ),
              ),
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


  Future<void> _exportRecipeAsPdf(
      String title,
      List<String> ingredients,
      List<String> instructions,
      Map<String, dynamic> nutrition,
      ) async {
    if (!await Permission.storage.request().isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Storage permission denied.")),
      );
      return;
    }

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.orange700,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Ingredients:',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
          ),
          ...ingredients.map((e) => pw.Bullet(text: e)),

          pw.SizedBox(height: 10),
          pw.Text(
            'Instructions:',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
          ),
          ...instructions.asMap().entries.map((e) => pw.Paragraph(
            text: "${e.key + 1}. ${e.value}",
            style: pw.TextStyle(fontSize: 12),
          )),

          if (nutrition.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text(
              'Nutrition Facts:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
            ),
            ...nutrition.entries.map(
                  (entry) => pw.Text('${entry.key}: ${entry.value}'),
            ),
          ],
        ],
      ),
    );

    try {
      final dir = Directory('/storage/emulated/0/Download');
      if (!dir.existsSync()) dir.createSync(recursive: true);

      final safeTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final path = '${dir.path}/${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      final file = File(path);
      await file.writeAsBytes(await pdf.save());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Recipe exported to $path")),
      );

      await OpenFile.open(path);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to export recipe: $e")),
      );
    }
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

  Widget _styledTextField(TextEditingController controller, String hint, {bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      cursorColor: Color(0xFFFFD6B0),
      style: TextStyle(
        color: Color(0xFFF46638),
        fontFamily: 'FunnelDisplay',
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Color(0xFFF46638),
          fontFamily: 'FunnelDisplay',
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(
            color: Color(0xFFFFD6B0),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(
            color: Color(0xFFFFD6B0),
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyPlansTab() {
    Future<void> _generatePlan() async {
      final goal = _goalController.text.trim();
      final mealsPerDay = _mealsPerDayController.text.trim();
      final allergies = _allergiesController.text.trim().isEmpty ? "none" : _allergiesController.text.trim();
      final dislikes = _dislikesController.text.trim().isEmpty ? "none" : _dislikesController.text.trim();
      final calories = _caloriesController.text.trim().isEmpty ? "unspecified" : _caloriesController.text.trim();

      if (goal.isEmpty || mealsPerDay.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Please enter both goal and meals per day."),
        ));
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), // Moved content upward
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                // Form Fields Scrollable
                Column(
                  children: [
                    _styledTextField(_goalController, 'Your diet goal'),
                    SizedBox(height: 10),
                    _styledTextField(_mealsPerDayController, 'Meals per day', isNumber: true),
                    SizedBox(height: 10),
                    _styledTextField(_allergiesController, 'Allergies (optional)'),
                    SizedBox(height: 10),
                    _styledTextField(_dislikesController, 'Dislikes (optional)'),
                    SizedBox(height: 10),
                    _styledTextField(_caloriesController, 'Calories per day (optional)', isNumber: true),
                    SizedBox(height: 15),
                    _styledTextField(_caloriesController, 'target calorues', isNumber: true, ),
                    SizedBox(height: 15),


             TextField(
        controller: myController,
        onChanged: (text) {
          print ("calories");
          },

    ),


    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          'Cuisine: ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'FunnelDisplay',
                            color: Color(0xFFF46638),
                          ),
                        ),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCuisine,
                            icon: Icon(Icons.arrow_drop_down, color: Color(0xFFFFD6B0)),
                            dropdownColor: Colors.white,
                            style: TextStyle(
                              color: Color(0xFFF46638),
                              fontSize: 14,
                              fontFamily: 'FunnelDisplay',
                            ),
                            itemHeight: kMinInteractiveDimension, // Ensures minimum item height (default is 48.0)
                            onChanged: (value) {
                              setState(() {
                                _selectedCuisine = value!;
                              });
                            },
                            items: _cuisineOptions.map((cuisine) {
                              return DropdownMenuItem<String>(
                                value: cuisine,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4), // 👈 Reduce vertical padding
                                  child: Text(
                                    cuisine,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.1, // 👈 Slightly tighter line height
                                      fontFamily: 'FunnelDisplay',
                                      color: Color(0xFFF46638),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 20),

                    ElevatedButton.icon(
                      icon: Icon(Icons.auto_awesome),
                      label: Text(_generating ? 'Generating...' : 'Generate Weekly Plan'),
                      onPressed: _generating ? null : _generatePlan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFFFD6B0),
                        foregroundColor: Color(0xFFF46638),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    if (_generating) ...[
                      SizedBox(height: 10),
                      CircularProgressIndicator(),
                    ],
                    SizedBox(height: 20),
                  ],
                ),


                // Weekly Plans List (non-scrollable part of ListView)
                if (_weeklyPlans.isEmpty)
                  Center(child: Text("No weekly plans found."))
                else
                  ..._weeklyPlans.map((plan) {
                    final days = List<Map<String, dynamic>>.from(plan['days']);
                    final preview = days
                        .expand((day) => List<Map<String, dynamic>>.from(day['meals']))
                        .take(2)
                        .map((meal) => "- ${meal['name']}")
                        .join(", ") + '...';

                    final formatted = days.map((day) {
                      final meals = List<Map<String, dynamic>>.from(day['meals']);
                      return "${day['day']}:\n" +
                          meals.map((meal) => "- ${meal['name']}: ${meal['description']}").join("\n");
                    }).join("\n\n");

                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 3,
                      color: Color(0xFFFFD6B0),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          iconColor: Color(0xFFF46638),
                          collapsedIconColor: Color(0xFFF46638),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.expand_more, size: 20, color: Color(0xFFF46638)), // ↓ Down arrow
                              SizedBox(width: 8),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(),
                                icon: Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFFF46638)), // → Forward arrow
                                onPressed: () {
                                  setState(() {
                                    selectedPlanId = plan['id'];
                                    _dietController.text = formatted;
                                    _tabController.index = 2;
                                  });
                                },
                              ),
                            ],
                          ),
                          title: Text(
                            preview,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                              fontFamily: 'FunnelDisplay',
                              color: Color(0xFFF46638),
                            ),
                          ),
                          children: days.map((day) {
                            final meals = List<Map<String, dynamic>>.from(day['meals']);
                            return Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    day['day'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      fontFamily: 'FunnelDisplay',
                                      color: Color(0xFFF46638),
                                    ),
                                  ),
                                  ...meals.map((meal) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      meal['name'],
                                      style: TextStyle(
                                        fontFamily: 'FunnelDisplay',
                                        fontWeight: FontWeight.bold, // ✅ Make meal name bold
                                        color: Color(0xFFF46638),
                                      ),
                                    ),

                                    subtitle: Text(
                                      meal['description'],
                                      style: TextStyle(
                                        fontFamily: 'FunnelDisplay',
                                        color: Color(0xFFF46638),
                                      ),
                                    ),
                                  )),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  }),


              ],
            ),
          ),
        ],
      ),
    );
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
          planId: planId,
        );
        setState(() => _dietResult = response);
      } catch (e) {
        setState(() => _dietResult = "Error: $e");
      } finally {
        setState(() => _checking = false);
      }
    }

    final borderStyle = OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide(color: Color(0xFFFFD6B0), width: 1.5),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Theme(
        data: Theme.of(context).copyWith(
          // 🔸 Cursor and selection handle color
          textSelectionTheme: TextSelectionThemeData(
            cursorColor: Color(0xFFFFD6B0),
            selectionColor: Color(0xFFFFD6B0).withOpacity(0.4),
            selectionHandleColor: Color(0xFFFFD6B0),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
            TextField(
            controller: _healthController,
            cursorColor: Color(0xFFFFD6B0),
            style: TextStyle( // 🔸 Add this to match the entered text color
              fontFamily: 'FunnelDisplay',
              color: Color(0xFFF46638),
            ),
            decoration: InputDecoration(
              hintText: 'Enter health conditions',
              hintStyle: TextStyle(
                fontFamily: 'FunnelDisplay',
                color: Color(0xFFF46638),
              ),
              border: borderStyle,
              enabledBorder: borderStyle,
              focusedBorder: borderStyle,
            ),
          ),

              SizedBox(height: 10),
              TextField(
                controller: _dietController,
                cursorColor: Color(0xFFFFD6B0),
                style: TextStyle(
                  fontFamily: 'FunnelDisplay',
                  color: Color(0xFFF46638),
                ),
                decoration: InputDecoration(
                  hintText: 'Current diet',
                  hintStyle: TextStyle(
                    fontFamily: 'FunnelDisplay',
                    color: Color(0xFFF46638),
                  ),
                  border: borderStyle,
                  enabledBorder: borderStyle,
                  focusedBorder: borderStyle,
                ),
                maxLines: 4,
              ),
              SizedBox(height: 15),
              ElevatedButton.icon(
                icon: Icon(Icons.health_and_safety, color: Color(0xFFF46638)),
                label: Text(
                  _checking ? 'Checking...' : 'Check Compatibility',
                  style: TextStyle(
                    fontFamily: 'FunnelDisplay',
                    color: Color(0xFFF46638),
                  ),
                ),
                onPressed: _checking ? null : _checkCompatibility,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFFD6B0), // 🔸 Base color
                  foregroundColor: Color(0xFFF46638), // 🔸 Text/icon color
                  elevation: 2,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
              SizedBox(height: 20),
              if (_dietResult.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _dietResult,
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'FunnelDisplay',
                      color: Color(0xFFF46638),
                    ),
                  ),
                ),
            ],
          ),
        ),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.smart_toy, // 🤖 AI-looking icon
              size: 64,
              color: Color(0xFFF46638), // AI theme color
            ),
            const SizedBox(height: 16), // spacing between icon and text
            Text(
              'Please select a weekly meal plan from the "Weekly Plans" tab to check diet compatibility.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'FunnelDisplay',
                color: Color(0xFFF46638),
              ),
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ✅ Full-screen background image using Container + BoxDecoration
          Stack(
            children: [
              // Full background image
              Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/lilas-yohane-14jmOnCcZkU-unsplash.webp'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              // Peach overlay: top half solid peach, bottom half fades to transparent
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFF46638),
                      Color(0xFFF46638),
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.3, 1.0],
                  ),
                ),
              ),
            ],
          ),



          // Foreground container
          Padding(
            padding: const EdgeInsets.only(top: 30), // ✅ shift container up
            child: Center(
              child: Container(


              width: MediaQuery.of(context).size.width * 0.80,
              height: MediaQuery.of(context).size.height * 0.74,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Scaffold(
                  backgroundColor: Colors.transparent, // 👈 Important to keep background transparent
                  appBar: AppBar(
                    backgroundColor: Colors.white,
                    toolbarHeight: 56,
                    titleSpacing: 0,
                    leading: Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                          icon: Icon(Icons.arrow_back, size: 24, color: Color(0xFFF46638)), // ✅ arrow color updated
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                    title: Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'AI Meal Planner',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                          color: Color(0xFFF46638), // ✅ title color
                          fontFamily: 'FunnelDisplay', // ✅ custom font
                        ),
                      ),
                    ),
                    bottom: PreferredSize(
                      preferredSize: Size.fromHeight(32), // 🔽 Reduced height
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4), // 🔽 Less vertical margin
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2), // 🔽 Less padding
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Transform.translate(
                          offset: Offset(-6, 0),
                          child: TabBar(
                            controller: _tabController,
                            isScrollable: false,
                            labelPadding: EdgeInsets.symmetric(horizontal: 0),
                            indicator: BoxDecoration(
                              color: Color(0xFFF46638),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            labelColor: Colors.white,
                            unselectedLabelColor:  Color(0xFFF46638),
                            labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, fontFamily: 'FunnelDisplay',),
                            indicatorColor: Colors.transparent,
                            unselectedLabelStyle: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              fontFamily: 'FunnelDisplay', // ✅ Custom font for inactive tabs too
                            ),
                            overlayColor: MaterialStateProperty.all(Colors.transparent),
                            dividerColor: Colors.transparent,
                            tabs: [
                              Tab(child: Padding(padding: EdgeInsets.symmetric(horizontal: 15), child: Text('Recipes'))),
                              Tab(child: Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Weekly Plans'))),
                              Tab(child: Padding(padding: EdgeInsets.symmetric(horizontal: 9), child: Text('Diet Checker'))),
                            ],
                          ),
                        ),
                      ),
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
                ),
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }

}


