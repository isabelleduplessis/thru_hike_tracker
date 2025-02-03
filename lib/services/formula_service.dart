// lib/services/formula_service.dart
//import 'package:sqflite/sqflite.dart';
//import 'package:path/path.dart';
import 'package:thru_hike_tracker/models/formula.dart';  // Import the Formula class
import 'package:thru_hike_tracker/services/database_helper.dart';  // Import the DatabaseHelper class

class FormulaService {
  // Method to execute a predefined formula based on its query
  Future<double> executeFormula(int trailJournalId, Formula formula) async {
    final db = await DatabaseHelper.getDatabase();  // Accessing the public getDatabase method

  // Execute the query tied to this formula
    final result = await db.rawQuery(formula.query, [trailJournalId]);

  // Ensure that the result is cast to a double, or return 0 if it's null or empty
    if (result.isNotEmpty) {
      var total = result.first['total'];  // The result from the query
      return total is double ? total : 0.0;  // Ensure it is a double, or return 0 if it's not
    }

    return 0.0;  // Default to 0.0 if no result is found
  }

  // Predefined formula method to calculate "Miles Hiked NOBO"
  Future<double> getMilesHikedNOBO(int trailJournalId) async {
    final formula = Formula(
      name: 'Miles Hiked NOBO',
      description: 'Total miles hiked in the NOBO direction.',
      query: "SELECT SUM(distance) AS total FROM FullDataEntry WHERE trail_journal_id = ? AND direction = 'NOBO'",
    );
    return await executeFormula(trailJournalId, formula);
  }

  // Predefined formula method to calculate "Miles Hiked SOBO"
  Future<double> getMilesHikedSOBO(int trailJournalId) async {
    final formula = Formula(
      name: 'Miles Hiked SOBO',
      description: 'Total miles hiked in the SOBO direction.',
      query: "SELECT SUM(distance) AS total FROM FullDataEntry WHERE trail_journal_id = ? AND direction = 'SOBO'",
    );
    return await executeFormula(trailJournalId, formula);
  }

  // Add more predefined methods for other formulas...
}