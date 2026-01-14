package com.example.apk.goals

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.apk.ui.theme.Charcoal
import com.example.apk.ui.theme.Gold

/**
 * Simplified multi-step questionnaire flow for creating goals
 */
@Composable
fun GoalsQuestionnaireFlow(
    viewModel: GoalsViewModel,
    onComplete: () -> Unit,
    onCancel: (() -> Unit)?
) {
    val currentStep by viewModel.currentStep.collectAsState()
    val selectedGoals by viewModel.selectedGoals.collectAsState()
    val catalog by viewModel.catalog.collectAsState()
    val lifeContext by viewModel.lifeContext.collectAsState()
    val isSubmitting by viewModel.isSubmitting.collectAsState()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Charcoal)
    ) {
        // Step Indicator
        StepIndicator(currentStep = currentStep)

        // Step Content
        Box(modifier = Modifier.weight(1f)) {
            when (currentStep) {
                1 -> LifeContextStep(viewModel, lifeContext)
                2 -> GoalSelectionStep(viewModel, catalog, selectedGoals)
                3 -> GoalDetailsStep(viewModel, selectedGoals)
                4 -> ReviewStep(viewModel, lifeContext, selectedGoals, isSubmitting, onComplete)
            }
        }

        // Navigation Buttons
        NavigationButtons(
            currentStep = currentStep,
            canGoNext = when (currentStep) {
                1 -> lifeContext != null
                2 -> selectedGoals.isNotEmpty()
                3 -> true
                4 -> false
                else -> false
            },
            onPrevious = { viewModel.previousStep() },
            onNext = { viewModel.nextStep() },
            onCancel = onCancel
        )
    }
}

@Composable
fun StepIndicator(currentStep: Int) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically
    ) {
        for (step in 1..4) {
            androidx.compose.foundation.Canvas(
                modifier = Modifier.size(12.dp)
            ) {
                drawCircle(
                    color = if (step <= currentStep) Gold else Color.Gray.copy(alpha = 0.3f)
                )
            }
            
            if (step < 4) {
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(2.dp)
                        .background(if (step < currentStep) Gold else Color.Gray.copy(alpha = 0.3f))
                )
            }
        }
    }
}

@Composable
fun LifeContextStep(viewModel: GoalsViewModel, lifeContext: LifeContext?) {
    // Simplified life context - just create a basic one
    var ageBand by remember { mutableStateOf(lifeContext?.ageBand ?: "30-40") }
    var hasSpouse by remember { mutableStateOf(lifeContext?.dependentsSpouse ?: false) }
    var childrenCount by remember { mutableStateOf((lifeContext?.dependentsChildrenCount ?: 0).toString()) }

    LaunchedEffect(ageBand, hasSpouse, childrenCount) {
        val context = LifeContext(
            ageBand = ageBand,
            dependentsSpouse = hasSpouse,
            dependentsChildrenCount = childrenCount.toIntOrNull() ?: 0,
            dependentsParentsCare = false,
            housing = "owned",
            employment = "salaried",
            incomeRegularity = "regular",
            regionCode = "IN-DL",
            emergencyOptOut = false
        )
        viewModel.updateLifeContext(context)
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(24.dp)
    ) {
        Text(
            text = "Life Context",
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )
        
        Text(
            text = "Tell us about yourself to personalize goal recommendations.",
            fontSize = 16.sp,
            color = Color.Gray
        )

        // Age Band
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("Age Range", color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Medium)
            
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf("18-25", "26-35", "36-45", "46-55", "55+").forEach { age ->
                    FilterChip(
                        selected = ageBand == age,
                        onClick = { ageBand = age },
                        label = { Text(age) },
                        colors = FilterChipDefaults.filterChipColors(
                            selectedContainerColor = Gold,
                            selectedLabelColor = Color.Black
                        )
                    )
                }
            }
        }

        // Spouse
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text("Married/Partner", color = Color.White, fontSize = 16.sp)
            Switch(
                checked = hasSpouse,
                onCheckedChange = { hasSpouse = it },
                colors = SwitchDefaults.colors(
                    checkedThumbColor = Gold,
                    checkedTrackColor = Gold.copy(alpha = 0.5f)
                )
            )
        }

        // Children
        OutlinedTextField(
            value = childrenCount,
            onValueChange = { if (it.isEmpty() || it.toIntOrNull() != null) childrenCount = it },
            label = { Text("Number of Children") },
            modifier = Modifier.fillMaxWidth(),
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = Gold,
                focusedLabelColor = Gold,
                unfocusedTextColor = Color.White,
                focusedTextColor = Color.White
            )
        )
    }
}

@Composable
fun GoalSelectionStep(viewModel: GoalsViewModel, catalog: List<GoalCatalogItem>, selectedGoals: List<SelectedGoal>) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(
            text = "Select Goals",
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )
        
        Text(
            text = "Choose the financial goals you want to track.",
            fontSize = 16.sp,
            color = Color.Gray
        )

        catalog.take(10).forEach { goal ->
            val isSelected = selectedGoals.any { it.goalName == goal.goalName }
            
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(
                    containerColor = if (isSelected) Gold.copy(alpha = 0.2f) else Color.DarkGray
                ),
                onClick = {
                    if (isSelected) {
                        val index = selectedGoals.indexOfFirst { it.goalName == goal.goalName }
                        if (index >= 0) viewModel.removeSelectedGoal(index)
                    } else {
                        viewModel.addSelectedGoal(goal)
                    }
                }
            ) {
                Row(
                    modifier = Modifier.padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = goal.goalName,
                            color = Color.White,
                            fontWeight = FontWeight.Medium,
                            fontSize = 16.sp
                        )
                        Text(
                            text = goal.goalCategory,
                            color = Color.Gray,
                            fontSize = 14.sp
                        )
                    }
                    
                    if (isSelected) {
                        Icon(
                            imageVector = Icons.Default.CheckCircle,
                            contentDescription = "Selected",
                            tint = Gold
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun GoalDetailsStep(viewModel: GoalsViewModel, selectedGoals: List<SelectedGoal>) {
    val currentGoalIndex by viewModel.currentGoalIndex.collectAsState()
    
    if (selectedGoals.isEmpty()) {
        Text("No goals selected", color = Color.White, modifier = Modifier.padding(20.dp))
        return
    }

    val currentGoal = selectedGoals.getOrNull(currentGoalIndex) ?: return
    
    var amount by remember(currentGoalIndex) { mutableStateOf(currentGoal.estimatedCost.toString()) }
    var savings by remember(currentGoalIndex) { mutableStateOf(currentGoal.currentSavings.toString()) }

    LaunchedEffect(amount, savings) {
        val updatedGoal = currentGoal.copy(
            estimatedCost = amount.toDoubleOrNull() ?: 0.0,
            currentSavings = savings.toDoubleOrNull() ?: 0.0
        )
        viewModel.updateSelectedGoal(currentGoalIndex, updatedGoal)
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(24.dp)
    ) {
        Text(
            text = "Goal Details",
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )

        Text(
            text = "Goal ${currentGoalIndex + 1} of ${selectedGoals.size}: ${currentGoal.goalName}",
            fontSize = 16.sp,
            color = Gold,
            fontWeight = FontWeight.Medium
        )

        OutlinedTextField(
            value = amount,
            onValueChange = { if (it.isEmpty() || it.toDoubleOrNull() != null) amount = it },
            label = { Text("Target Amount (₹)") },
            modifier = Modifier.fillMaxWidth(),
            prefix = { Text("₹") },
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = Gold,
                focusedLabelColor = Gold,
                unfocusedTextColor = Color.White,
                focusedTextColor = Color.White
            )
        )

        OutlinedTextField(
            value = savings,
            onValueChange = { if (it.isEmpty() || it.toDoubleOrNull() != null) savings = it },
            label = { Text("Current Savings (₹)") },
            modifier = Modifier.fillMaxWidth(),
            prefix = { Text("₹") },
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = Gold,
                focusedLabelColor = Gold,
                unfocusedTextColor = Color.White,
                focusedTextColor = Color.White
            )
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            if (currentGoalIndex > 0) {
                OutlinedButton(
                    onClick = { viewModel.previousGoal() },
                    modifier = Modifier.weight(1f)
                ) {
                    Text("Previous Goal")
                }
            }
            if (currentGoalIndex < selectedGoals.size - 1) {
                Button(
                    onClick = { viewModel.nextGoal() },
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Gold,
                        contentColor = Color.Black
                    )
                ) {
                    Text("Next Goal")
                }
            }
        }
    }
}

@Composable
fun ReviewStep(
    viewModel: GoalsViewModel,
    lifeContext: LifeContext?,
    selectedGoals: List<SelectedGoal>,
    isSubmitting: Boolean,
    onComplete: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(
            text = "Review & Submit",
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )

        Text(
            text = "Review your goals before submitting:",
            fontSize = 16.sp,
            color = Color.Gray
        )

        selectedGoals.forEach { goal ->
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(containerColor = Color.DarkGray)
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        text = goal.goalName,
                        color = Color.White,
                        fontWeight = FontWeight.Bold,
                        fontSize = 18.sp
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text("Target: ₹${String.format("%,.0f", goal.estimatedCost)}", color = Color.Gray)
                    Text("Current: ₹${String.format("%,.0f", goal.currentSavings)}", color = Color.Gray)
                }
            }
        }

        Button(
            onClick = {
                if (lifeContext != null) {
                    viewModel.submitGoals(lifeContext)
                    onComplete()
                }
            },
            modifier = Modifier.fillMaxWidth(),
            enabled = !isSubmitting && lifeContext != null,
            colors = ButtonDefaults.buttonColors(
                containerColor = Gold,
                contentColor = Color.Black
            )
        ) {
            if (isSubmitting) {
                CircularProgressIndicator(modifier = Modifier.size(20.dp), color = Color.Black)
            } else {
                Text("Submit Goals")
            }
        }
    }
}

@Composable
fun NavigationButtons(
    currentStep: Int,
    canGoNext: Boolean,
    onPrevious: () -> Unit,
    onNext: () -> Unit,
    onCancel: (() -> Unit)?
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(20.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        if (currentStep > 1) {
            OutlinedButton(
                onClick = onPrevious,
                modifier = Modifier.weight(1f)
            ) {
                Text("Previous")
            }
        } else if (onCancel != null) {
            OutlinedButton(
                onClick = onCancel,
                modifier = Modifier.weight(1f)
            ) {
                Text("Cancel")
            }
        }

        if (currentStep < 4) {
            Button(
                onClick = onNext,
                enabled = canGoNext,
                modifier = Modifier.weight(1f),
                colors = ButtonDefaults.buttonColors(
                    containerColor = Gold,
                    contentColor = Color.Black
                )
            ) {
                Text("Next")
            }
        }
    }
}
