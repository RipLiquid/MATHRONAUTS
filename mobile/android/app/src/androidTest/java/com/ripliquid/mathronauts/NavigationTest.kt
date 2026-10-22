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

@RunWith(AndroidJUnit4::class)
class NavigationTest {
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
