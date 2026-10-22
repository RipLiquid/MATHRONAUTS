package com.ripliquid.mathronauts

import android.content.Context
import android.graphics.*
import android.view.MotionEvent
import android.view.View
import com.ripliquid.mathronauts.core.GameSession
import kotlin.math.min

/** Rendering and input only; scoring and arithmetic live in the core package. */
class GameView(context: Context) : View(context) {
    var onAnswer: (Int, Long) -> Unit = { _, _ -> }
    var onExpired: (Long) -> Unit = {}
    var onBusyChanged: (Boolean) -> Unit = {}
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private fun image(name: String) = context.assets.open(name).use { BitmapFactory.decodeStream(it) }
    private val background = image("space.png")
    private val ship = image("spaceship4.png")
    private val meteor = image("meteor1.png")
    private var game: GameSession? = null
    private var waveId = -1L
    var waveX = 340f; private set
    var shipY = 325f; private set
    private var lastFrame = 0L
    private var movingPointer = -1
    private var shot: Shot? = null
    private var frozen = true
    private data class Shot(val answer: Int, val id: Long, val startY: Float,
                            val targetX: Float, val targetY: Float, var time: Float = 0f)

    init {
        contentDescription = "Space battlefield. Drag in the left lane to move; tap a meteor to fire. Answer buttons are also available below."
        importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO
    }

    fun sync(session: GameSession) {
        game = session
        if (waveId != session.question.id) {
            waveId = session.question.id
            waveX = 340f
            shot = null
        }
        if (session.isOver) shot = null
        invalidate()
    }

    fun reset() {
        waveId = -1L; waveX = 340f; shipY = 325f
        shot = null; movingPointer = -1; lastFrame = 0
    }

    fun restorePositions(x: Float, y: Float) {
        waveX = x.coerceIn(110f, 340f); shipY = y.coerceIn(30f, 620f)
    }

    fun pause(value: Boolean) {
        frozen = value
        lastFrame = 0
        movingPointer = -1
        invalidate()
    }

    fun fire(answer: Int) {
        val session = game ?: return
        if (frozen || session.isOver || shot != null || answer !in session.availableAnswers) return
        val index = session.question.choices.indexOf(answer)
        shot = Shot(answer, session.question.id, shipY, waveX, 110f + index * 140f)
        onBusyChanged(true)
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val session = game ?: return
        val now = System.nanoTime()
        val delta = if (lastFrame == 0L) 0f else ((now - lastFrame) / 1_000_000_000f).coerceIn(0f, 0.0667f)
        lastFrame = now
        if (!frozen && !session.isOver) {
            val activeShot = shot
            if (activeShot != null) {
                activeShot.time += delta
                if (activeShot.time >= 0.3f) {
                    shot = null
                    onAnswer(activeShot.answer, activeShot.id)
                    onBusyChanged(false)
                }
            } else {
                if (!session.isPractice) {
                    waveX -= session.settings.difficulty.waveSpeed * delta
                    if (waveX <= 110f) onExpired(waveId)
                }
            }
        }
        val scale = min(width / 390f, height / 650f)
        canvas.save()
        canvas.translate((width - 390 * scale) / 2f, (height - 650 * scale) / 2f)
        canvas.scale(scale, scale)
        canvas.drawBitmap(background, null, RectF(0f, 0f, 390f, 650f), paint)
        paint.color = Color.CYAN; paint.alpha = 80
        canvas.drawRect(81f, 0f, 83f, 650f, paint)
        paint.alpha = 255
        canvas.drawBitmap(ship, null, RectF(24f, shipY - 24, 72f, shipY + 24), paint)
        session.question.choices.forEachIndexed { index, answer ->
            if (answer in session.availableAnswers) {
                val y = 110f + index * 140f
                canvas.drawBitmap(meteor, null, RectF(waveX - 31, y - 31, waveX + 31, y + 31), paint)
                paint.color = Color.WHITE; paint.textSize = 25f
                paint.typeface = Typeface.DEFAULT_BOLD; paint.textAlign = Paint.Align.CENTER
                paint.setShadowLayer(3f, 1f, 1f, Color.BLACK)
                canvas.drawText(answer.toString(), waveX, y + 8, paint)
                paint.clearShadowLayer()
            }
        }
        shot?.let {
            val progress = (it.time / 0.3f).coerceIn(0f, 1f)
            paint.color = Color.CYAN
            canvas.drawCircle(48 + (it.targetX - 48) * progress,
                it.startY + (it.targetY - it.startY) * progress, 5f, paint)
        }
        canvas.restore()
        if (!frozen && !session.isOver) postInvalidateOnAnimation()
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (frozen || game?.isOver != false) return false
        val scale = min(width / 390f, height / 650f)
        if (scale <= 0f) return false
        fun x(index: Int) = (event.getX(index) - (width - 390 * scale) / 2) / scale
        fun y(index: Int) = (event.getY(index) - (height - 650 * scale) / 2) / scale
        val index = event.actionIndex
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN, MotionEvent.ACTION_POINTER_DOWN -> {
                if (x(index) in 0f..85f && movingPointer == -1) {
                    movingPointer = event.getPointerId(index)
                    shipY = y(index).coerceIn(30f, 620f)
                } else if (shot == null && kotlin.math.abs(x(index) - waveX) <= 36f) {
                    val session = game ?: return true
                    session.question.choices.forEachIndexed { row, answer ->
                        if (kotlin.math.abs(y(index) - (110 + row * 140)) <= 36) fire(answer)
                    }
                }
                invalidate()
            }
            MotionEvent.ACTION_MOVE -> {
                val pointer = event.findPointerIndex(movingPointer)
                if (pointer >= 0) shipY = y(pointer).coerceIn(30f, 620f)
                invalidate()
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_POINTER_UP -> {
                if (event.getPointerId(index) == movingPointer) movingPointer = -1
                performClick()
            }
            MotionEvent.ACTION_CANCEL -> movingPointer = -1
        }
        return true
    }

    override fun performClick(): Boolean { super.performClick(); return true }
}
