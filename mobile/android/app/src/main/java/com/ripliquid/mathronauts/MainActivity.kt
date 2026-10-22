package com.ripliquid.mathronauts

import android.app.Activity
import android.app.AlertDialog
import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.WindowInsets
import android.widget.*
import com.ripliquid.mathronauts.core.*

class MainActivity : Activity() {
    private var game = GameSession()
    private var playing = false
    private var paused = false
    private var busy = false
    private lateinit var field: GameView
    private lateinit var title: TextView
    private lateinit var stats: TextView
    private lateinit var question: TextView
    private lateinit var status: TextView
    private lateinit var launch: Button
    private lateinit var pauseButton: Button
    private lateinit var menuButton: Button
    private lateinit var answerRow: LinearLayout
    private lateinit var settingsSummary: TextView
    private lateinit var settingsButton: Button
    private lateinit var learningButton: Button
    private lateinit var reviewButton: Button
    private var selectedSettings = SessionSettings()
    private var learningStats = LearningStats()
    private val answers = mutableListOf<Button>()
    private val preferences by lazy { getSharedPreferences("mathronauts", MODE_PRIVATE) }
    private val statisticsStore by lazy { StatisticsStore(preferences) }

    @Suppress("DEPRECATION")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val saved = savedInstanceState?.getSerializable("game") as? GameSnapshot
        selectedSettings = SessionSettings(
            Difficulty.entries.getOrElse(preferences.getInt("difficulty", 1)) { Difficulty.NORMAL },
            GameMode.entries.getOrElse(preferences.getInt("mode", 0)) { GameMode.ARCADE },
            preferences.getInt("practiceStage", 0).coerceIn(0, 4))
        learningStats = statisticsStore.load()
        game = GameSession(saved = saved)
        playing = savedInstanceState?.getBoolean("playing") ?: false
        paused = playing
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.rgb(8, 13, 32))
            setPadding(dp(16), dp(16), dp(16), dp(16))
        }
        root.setOnApplyWindowInsetsListener { view, insets ->
            val safe = if (android.os.Build.VERSION.SDK_INT >= 30) {
                val bounds = insets.getInsets(WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout())
                intArrayOf(bounds.left, bounds.top, bounds.right, bounds.bottom)
            } else intArrayOf(insets.systemWindowInsetLeft, insets.systemWindowInsetTop,
                insets.systemWindowInsetRight, insets.systemWindowInsetBottom)
            view.setPadding(dp(16) + safe[0], dp(8) + safe[1],
                dp(16) + safe[2], dp(8) + safe[3])
            insets
        }
        fun label(size: Float) = TextView(this).apply {
            textSize = size; setTextColor(Color.WHITE); gravity = Gravity.CENTER
            root.addView(this, LinearLayout.LayoutParams(-1, -2))
        }
        title = label(26f)
        stats = label(16f)
        settingsSummary = label(16f)
        question = label(28f).apply { id = R.id.question }
        field = GameView(this)
        root.addView(field, LinearLayout.LayoutParams(-1, 0, 1f))
        status = label(15f).apply {
            id = R.id.status
            accessibilityLiveRegion = View.ACCESSIBILITY_LIVE_REGION_POLITE
        }
        answerRow = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        repeat(4) { index ->
            val button = Button(this).apply {
                textSize = 18f; minimumWidth = 0; minWidth = 0
                setOnClickListener { field.fire(game.question.choices[index]) }
            }
            answers.add(button)
            answerRow.addView(button, LinearLayout.LayoutParams(0, dp(52), 1f))
        }
        root.addView(answerRow)
        launch = Button(this).apply { setOnClickListener { startGame() } }
        root.addView(launch, LinearLayout.LayoutParams(-1, dp(54)))
        settingsButton = Button(this).apply { text = "Mission settings"; setOnClickListener { showSettings() } }
        learningButton = Button(this).apply { text = "Learning statistics"; setOnClickListener { showStatistics() } }
        reviewButton = Button(this).apply { text = "Review answers"; setOnClickListener { showReview() } }
        root.addView(settingsButton)
        root.addView(learningButton)
        root.addView(reviewButton)
        val controls = LinearLayout(this)
        pauseButton = Button(this).apply {
            setOnClickListener { paused = !paused; refresh() }
        }
        menuButton = Button(this).apply {
            text = "Main menu"
            setOnClickListener { playing = false; field.pause(true); refresh() }
        }
        controls.addView(pauseButton, LinearLayout.LayoutParams(0, dp(50), 1f))
        controls.addView(menuButton, LinearLayout.LayoutParams(0, dp(50), 1f))
        root.addView(controls)
        label(12f).text = "Drag left to move · Tap a meteor or an answer to fire"
        field.onAnswer = { answer, id ->
            val correct = answer == game.question.answer
            val previousStage = game.stage
            val operation = game.question.operation
            if (game.resolve(answer, id)) {
                learningStats = learningStats.record(operation, correct, game.streak, game.isPractice && game.isOver)
                statisticsStore.save(learningStats)
                status.text = if (correct) {
                    if (previousStage != game.stage) "Stage cleared! ${game.stageTitle}" else "Correct! +10"
                } else if (game.isPractice) "Keep practicing. Review the solution in your results."
                else "Wrong answer. One life lost."
                refresh()
            }
        }
        field.onExpired = { id ->
            if (game.expire(id)) {
                status.text = "Wave reached the defense line. One life lost."
                refresh()
            }
        }
        field.onBusyChanged = { busy = it; refreshAnswers() }
        setContentView(root)
        field.sync(game)
        if (savedInstanceState != null) {
            field.restorePositions(savedInstanceState.getFloat("waveX", 340f),
                savedInstanceState.getFloat("shipY", 325f))
        }
        status.text = if (playing) "Mission paused. Tap Resume to continue." else
            "Solve arithmetic problems to protect the mothership."
        refresh()
    }

    private fun startGame() {
        game = GameSession(settings = selectedSettings); playing = true; paused = false; busy = false
        field.reset()
        status.text = "Protect the mothership!"
        refresh()
    }

    private fun refresh() {
        val difficulty = if (playing) game.settings.difficulty else selectedSettings.difficulty
        val highKey = "highScore_${difficulty.name}"
        val previous = preferences.getInt(highKey,
            if (difficulty == Difficulty.NORMAL) preferences.getInt("highScore", 0) else 0)
        val high = if (playing && !game.isPractice) maxOf(previous, game.score) else previous
        if (high > previous) preferences.edit().putInt(highKey, high).apply()
        title.text = when { !playing -> "MATHRONAUTS"; game.isOver && game.isPractice -> "Practice complete"
            game.isOver -> "Mission over"; else -> game.stageTitle }
        stats.text = when {
            !playing -> "${difficulty.title} arcade best: $high"
            game.isPractice -> "Question ${minOf(game.attempts + 1, 10)}/10 · ${difficulty.title} · Untimed"
            else -> "Score ${game.score} · Lives ${game.lives} · ${difficulty.title}"
        }
        settingsSummary.visibility = if (!playing) View.VISIBLE else View.GONE
        settingsSummary.text = "${selectedSettings.mode.title} · ${difficulty.title}" +
            if (selectedSettings.mode == GameMode.PRACTICE) " · ${stageName(selectedSettings.practiceStage)}" else ""
        settingsButton.visibility = if (!playing) View.VISIBLE else View.GONE
        learningButton.visibility = if (!playing || game.isOver) View.VISIBLE else View.GONE
        reviewButton.visibility = if (playing && game.isOver) View.VISIBLE else View.GONE
        question.text = if (playing && !game.isOver) game.question.text else ""
        question.tag = game.question.id
        question.visibility = if (playing && !game.isOver) View.VISIBLE else View.GONE
        field.visibility = if (playing && !game.isOver) View.VISIBLE else View.GONE
        answerRow.visibility = field.visibility
        launch.visibility = if (!playing || game.isOver) View.VISIBLE else View.GONE
        launch.text = if (playing && game.isOver) "Play again" else
            if (selectedSettings.mode == GameMode.PRACTICE) "Start practice" else "Launch mission"
        pauseButton.visibility = if (playing && !game.isOver) View.VISIBLE else View.GONE
        pauseButton.text = if (paused) "Resume" else "Pause"
        menuButton.visibility = if (playing) View.VISIBLE else View.GONE
        if (game.isOver && playing) status.text = "${game.correctAnswers}/${game.attempts} correct · ${game.accuracy}% accuracy\n" +
            "Score ${game.score} · Best streak ${game.bestStreak}" +
            if (game.missed > 0) " · Missed waves ${game.missed}" else ""
        if (!playing) status.text = "Solve arithmetic problems to protect the mothership."
        field.sync(game)
        field.pause(!playing || paused || game.isOver)
        refreshAnswers()
    }

    private fun stageName(stage: Int) = if (stage == 4) "Mixed operations" else Operation.entries[stage].title

    private fun showSettings() {
        val panel = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(dp(20), dp(8), dp(20), dp(8)) }
        fun selector(label: String, values: List<String>, selected: Int): Spinner {
            panel.addView(TextView(this).apply { text = label; textSize = 16f })
            return Spinner(this).apply {
                contentDescription = label
                adapter = ArrayAdapter(this@MainActivity, android.R.layout.simple_spinner_dropdown_item, values)
                setSelection(selected); panel.addView(this)
            }
        }
        val mode = selector("Mode", GameMode.entries.map { it.title }, selectedSettings.mode.ordinal)
        val difficulty = selector("Difficulty", Difficulty.entries.map { it.title }, selectedSettings.difficulty.ordinal)
        val operation = selector("Practice operation", (0..4).map { stageName(it) }, selectedSettings.practiceStage)
        panel.addView(TextView(this).apply {
            text = "Easy: smaller numbers, slower meteors. Hard: larger numbers, faster meteors.\nPractice: 10 questions, no timer or life loss."
        })
        AlertDialog.Builder(this).setTitle("Mission settings").setView(panel)
            .setNegativeButton("Cancel", null).setPositiveButton("Save") { _, _ ->
                selectedSettings = SessionSettings(Difficulty.entries[difficulty.selectedItemPosition],
                    GameMode.entries[mode.selectedItemPosition], operation.selectedItemPosition)
                preferences.edit().putInt("difficulty", selectedSettings.difficulty.ordinal)
                    .putInt("mode", selectedSettings.mode.ordinal).putInt("practiceStage", selectedSettings.practiceStage).apply()
                refresh()
            }.show()
    }

    private fun showReview() {
        val text = if (game.mistakes.isEmpty()) "No incorrect answers to review." else
            game.mistakes.joinToString("\n\n") { "${it.question}\nYour answer: ${it.submitted} · Correct: ${it.correct}" }
        val content = TextView(this).apply { this.text = text; textSize = 18f; setPadding(dp(20), dp(12), dp(20), dp(12)) }
        AlertDialog.Builder(this).setTitle("Answer review").setView(ScrollView(this).apply { addView(content) })
            .setPositiveButton("Done", null).show()
    }

    private fun showStatistics() {
        val panel = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(dp(20), dp(12), dp(20), dp(12)) }
        panel.addView(TextView(this).apply {
            text = "${learningStats.correct}/${learningStats.attempts} correct · ${learningStats.accuracy}% accuracy\n" +
                "Best streak ${learningStats.bestStreak} · Practice rounds ${learningStats.practiceRounds}\nStored only on this device."
            textSize = 17f
        })
        for (operation in Operation.entries) {
            val progress = learningStats.operations[operation] ?: OperationProgress()
            panel.addView(TextView(this).apply {
                text = "${operation.title}: ${progress.correct}/${progress.attempts} (${progress.accuracy}%)"
                textSize = 16f; setPadding(0, dp(14), 0, 0)
            })
            panel.addView(ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
                max = 100; this.progress = progress.accuracy
                contentDescription = "${operation.title} accuracy ${progress.accuracy} percent"
            })
        }
        AlertDialog.Builder(this).setTitle("Learning statistics").setView(ScrollView(this).apply { addView(panel) })
            .setPositiveButton("Done", null).setNeutralButton("Reset statistics") { _, _ ->
                AlertDialog.Builder(this).setTitle("Reset learning statistics?")
                    .setMessage("This clears accuracy and streak records on this device. Arcade best scores stay saved.")
                    .setNegativeButton("Cancel", null).setPositiveButton("Reset") { _, _ ->
                        learningStats = LearningStats(); statisticsStore.save(learningStats)
                    }.show()
            }.show()
    }

    private fun refreshAnswers() {
        answers.forEachIndexed { index, button ->
            val answer = game.question.choices[index]
            button.text = answer.toString()
            button.contentDescription = "Fire at answer $answer"
            button.isEnabled = playing && !paused && !game.isOver && !busy && answer in game.availableAnswers
        }
    }

    override fun onPause() {
        super.onPause()
        if (playing) { paused = true; refresh() }
    }

    override fun onSaveInstanceState(outState: Bundle) {
        outState.putSerializable("game", game.snapshot())
        outState.putBoolean("playing", playing)
        outState.putFloat("waveX", field.waveX)
        outState.putFloat("shipY", field.shipY)
        super.onSaveInstanceState(outState)
    }

    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()
}
