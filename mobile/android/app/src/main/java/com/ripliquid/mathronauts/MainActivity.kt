package com.ripliquid.mathronauts

import android.app.Activity
import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.WindowInsets
import android.widget.*
import com.ripliquid.mathronauts.core.GameSession
import com.ripliquid.mathronauts.core.GameSnapshot

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
    private val answers = mutableListOf<Button>()
    private val preferences by lazy { getSharedPreferences("mathronauts", MODE_PRIVATE) }

    @Suppress("DEPRECATION")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val saved = savedInstanceState?.getSerializable("game") as? GameSnapshot
        game = GameSession(saved = saved)
        playing = savedInstanceState?.getBoolean("playing") ?: false
        paused = playing
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setBackgroundColor(Color.rgb(8, 13, 32))
            setPadding(dp(16), dp(16), dp(16), dp(16))
        }
        root.setOnApplyWindowInsetsListener { view, insets ->
            val safe = if (android.os.Build.VERSION.SDK_INT >= 30) {
                insets.getInsets(WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout())
            } else null
            val top = safe?.top ?: insets.systemWindowInsetTop
            val bottom = safe?.bottom ?: insets.systemWindowInsetBottom
            view.setPadding(dp(16) + (safe?.left ?: 0), dp(8) + top,
                dp(16) + (safe?.right ?: 0), dp(8) + bottom)
            insets
        }
        fun label(size: Float) = TextView(this).apply {
            textSize = size; setTextColor(Color.WHITE); gravity = Gravity.CENTER
            root.addView(this, LinearLayout.LayoutParams(-1, -2))
        }
        title = label(26f)
        stats = label(16f)
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
            if (game.resolve(answer, id)) {
                status.text = if (correct) {
                    if (previousStage != game.stage) "Stage cleared! ${game.stageTitle}" else "Correct! +10"
                } else "Wrong answer. One life lost."
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
        game = GameSession(); playing = true; paused = false; busy = false
        field.reset()
        status.text = "Protect the mothership!"
        refresh()
    }

    private fun refresh() {
        val high = maxOf(preferences.getInt("highScore", 0), game.score)
        if (high > preferences.getInt("highScore", 0)) preferences.edit().putInt("highScore", high).apply()
        title.text = when { !playing -> "MATHRONAUTS"; game.isOver -> "Mission over"; else -> game.stageTitle }
        stats.text = if (playing) "Score ${game.score}   Lives ${game.lives}   Best $high" else "Best score: $high"
        question.text = if (playing && !game.isOver) game.question.text else ""
        question.visibility = if (playing && !game.isOver) View.VISIBLE else View.GONE
        field.visibility = if (playing && !game.isOver) View.VISIBLE else View.GONE
        answerRow.visibility = field.visibility
        launch.visibility = if (!playing || game.isOver) View.VISIBLE else View.GONE
        launch.text = if (playing && game.isOver) "Play again" else "Launch mission"
        pauseButton.visibility = if (playing && !game.isOver) View.VISIBLE else View.GONE
        pauseButton.text = if (paused) "Resume" else "Pause"
        menuButton.visibility = if (playing) View.VISIBLE else View.GONE
        if (game.isOver && playing) status.text = "Final score: ${game.score}. Launch another mission!"
        field.sync(game)
        field.pause(!playing || paused || game.isOver)
        refreshAnswers()
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
