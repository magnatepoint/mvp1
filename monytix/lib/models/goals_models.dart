/// Data models for Goals Questionnaire

class LifeContext {
  final String ageBand;
  final bool dependentsSpouse;
  final int dependentsChildrenCount;
  final bool dependentsParentsCare;
  final String housing;
  final String employment;
  final String incomeRegularity;
  final String regionCode;
  final bool emergencyOptOut;

  LifeContext({
    required this.ageBand,
    this.dependentsSpouse = false,
    this.dependentsChildrenCount = 0,
    this.dependentsParentsCare = false,
    required this.housing,
    required this.employment,
    required this.incomeRegularity,
    required this.regionCode,
    this.emergencyOptOut = false,
  });

  factory LifeContext.fromJson(Map<String, dynamic> json) {
    return LifeContext(
      ageBand: json['age_band'] ?? '',
      dependentsSpouse: json['dependents_spouse'] ?? false,
      dependentsChildrenCount: json['dependents_children_count'] ?? 0,
      dependentsParentsCare: json['dependents_parents_care'] ?? false,
      housing: json['housing'] ?? '',
      employment: json['employment'] ?? '',
      incomeRegularity: json['income_regularity'] ?? '',
      regionCode: json['region_code'] ?? '',
      emergencyOptOut: json['emergency_opt_out'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'age_band': ageBand,
      'dependents_spouse': dependentsSpouse,
      'dependents_children_count': dependentsChildrenCount,
      'dependents_parents_care': dependentsParentsCare,
      'housing': housing,
      'employment': employment,
      'income_regularity': incomeRegularity,
      'region_code': regionCode,
      'emergency_opt_out': emergencyOptOut,
    };
  }
}

class GoalCatalogItem {
  final String goalCategory;
  final String goalName;
  final String defaultHorizon;
  final String policyLinkedTxnType;
  final bool isMandatoryFlag;
  final String? suggestedMinAmountFormula;
  final int displayOrder;

  GoalCatalogItem({
    required this.goalCategory,
    required this.goalName,
    required this.defaultHorizon,
    required this.policyLinkedTxnType,
    required this.isMandatoryFlag,
    this.suggestedMinAmountFormula,
    required this.displayOrder,
  });

  factory GoalCatalogItem.fromJson(Map<String, dynamic> json) {
    return GoalCatalogItem(
      goalCategory: json['goal_category'] ?? '',
      goalName: json['goal_name'] ?? '',
      defaultHorizon: json['default_horizon'] ?? '',
      policyLinkedTxnType: json['policy_linked_txn_type'] ?? '',
      isMandatoryFlag: json['is_mandatory_flag'] ?? false,
      suggestedMinAmountFormula: json['suggested_min_amount_formula'],
      displayOrder: json['display_order'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'goal_category': goalCategory,
      'goal_name': goalName,
      'default_horizon': defaultHorizon,
      'policy_linked_txn_type': policyLinkedTxnType,
      'is_mandatory_flag': isMandatoryFlag,
      'suggested_min_amount_formula': suggestedMinAmountFormula,
      'display_order': displayOrder,
    };
  }

  String get key => '$goalCategory:$goalName';
}

class SelectedGoal {
  final String goalCategory;
  final String goalName;
  final double estimatedCost;
  final DateTime? targetDate;
  final double currentSavings;
  final int importance;
  final String? notes;

  SelectedGoal({
    required this.goalCategory,
    required this.goalName,
    required this.estimatedCost,
    this.targetDate,
    this.currentSavings = 0.0,
    this.importance = 3,
    this.notes,
  });

  SelectedGoal copyWith({
    String? goalCategory,
    String? goalName,
    double? estimatedCost,
    DateTime? targetDate,
    double? currentSavings,
    int? importance,
    String? notes,
  }) {
    return SelectedGoal(
      goalCategory: goalCategory ?? this.goalCategory,
      goalName: goalName ?? this.goalName,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      targetDate: targetDate ?? this.targetDate,
      currentSavings: currentSavings ?? this.currentSavings,
      importance: importance ?? this.importance,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'goal_category': goalCategory,
      'goal_name': goalName,
      'estimated_cost': estimatedCost,
      'target_date': targetDate?.toIso8601String().split('T')[0],
      'current_savings': currentSavings,
      'importance': importance,
      'notes': notes,
    };
  }
}

