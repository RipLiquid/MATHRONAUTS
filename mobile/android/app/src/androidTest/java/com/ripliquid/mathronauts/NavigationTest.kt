package com.ripliquid.mathronauts

import androidx.test.core.app.ActivityScenario
import androidx.test.espresso.Espresso.onView
import androidx.test.espresso.action.ViewActions.click
import androidx.test.espresso.assertion.ViewAssertions.matches
import androidx.test.espresso.matcher.ViewMatchers.*
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Test
import org.junit.runner.RunWith
import androidx.test.platform.app.InstrumentationRegistry
import android.graphics.Bitmap
import java.io.File
import androidx.test.espresso.Espresso.onData
import org.hamcrest.Matchers.equalTo
import org.hamcrest.Matchers.containsString
import org.junit.Before
import org.junit.Assert.*
import android.content.Context
import android.os.SystemClock
import android.view.View
import android.widget.TextView


@RunWith(AndroidJUnit4::class)
class NavigationTest {
    @Before fun clearLocalProgress() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        context.getSharedPreferences("mathronauts", Context.MODE_PRIVATE).edit().clear().commit()
    }

    @Test fun practiceFinishesAndStatisticsSurviveRelaunch() {
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            onView(withText("Mission settings")).perform(click())
            onView(withContentDescription("Mode")).perform(click())
            onData(equalTo("Practice")).perform(click())
            onView(withContentDescription("Difficulty")).perform(click())
            onData(equalTo("Easy")).perform(click())
            onView(withText("Save")).perform(click())
            onView(withText("Start practice")).perform(click())
            screenshot("practice")
            repeat(10) {
                var id = 0L
                var answer = 0
                scenario.onActivity { activity ->
                    val question = activity.findViewById<TextView>(R.id.question)
                    id = question.tag as Long
                    val operands = question.text.toString().substringBefore(" =").split(" + ")
                    answer = operands[0].toInt() + operands[1].toInt()
                }
                onView(withContentDescription("Fire at answer $answer")).perform(click())
                val deadline = SystemClock.uptimeMillis() + 5000
                var resolved = false
                while (!resolved && SystemClock.uptimeMillis() < deadline) {
                    scenario.onActivity { activity ->
                        val question = activity.findViewById<TextView>(R.id.question)
                        resolved = question.tag != id || question.visibility == View.GONE
                    }
                    if (!resolved) SystemClock.sleep(25)
                }
                assertTrue("Shot did not resolve", resolved)
            }
            onView(withText("Practice complete")).check(matches(isDisplayed()))
            onView(withId(R.id.status)).check(matches(withText(containsString("100% accuracy"))))
            screenshot("results")
        }
        ActivityScenario.launch(MainActivity::class.java).use {
            onView(withText("Learning statistics")).perform(click())
            onView(withText(containsString("Practice rounds 1"))).check(matches(isDisplayed()))
            screenshot("statistics")
        }
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val preferences = context.getSharedPreferences("mathronauts", Context.MODE_PRIVATE)
        assertEquals(10, StatisticsStore(preferences).load().attempts)
        assertEquals(100, StatisticsStore(preferences).load().accuracy)
        preferences.edit().putString("learningStats.v1", "corrupt").commit()
        assertEquals(0, StatisticsStore(preferences).load().attempts)
    }

    @Test fun launchPauseRestoreResumeAndReturnToMenu() {
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            onView(withText("Launch mission")).perform(click())
            onView(withId(R.id.question)).check(matches(isDisplayed()))
            screenshot("game")
            onView(withText("Pause")).perform(click())
            onView(withText("Resume")).check(matches(isDisplayed()))
            scenario.recreate()
            onView(withText("Resume")).perform(click())
            onView(withText("Pause")).check(matches(isDisplayed()))
            onView(withText("Main menu")).perform(click())
            onView(withText("Launch mission")).check(matches(isDisplayed()))
            screenshot("menu")
        }
    }

    private fun screenshot(name: String) {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val folder = File(instrumentation.targetContext.getExternalFilesDir(null), "screenshots")
        check(folder.mkdirs() || folder.isDirectory)
        val bitmap = checkNotNull(instrumentation.uiAutomation.takeScreenshot())
        File(folder, "$name.png").outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
        bitmap.recycle()
    }
}
