package com.ripliquid.mathronauts

import android.content.SharedPreferences
import com.ripliquid.mathronauts.core.*
import org.json.JSONObject

class StatisticsStore(private val preferences: SharedPreferences) {
    fun load(): LearningStats = try {
        val json = JSONObject(preferences.getString("learningStats.v1", "{}") ?: "{}")
        val operations = Operation.entries.associateWith { operation ->
            val record = json.optJSONObject(operation.name) ?: JSONObject()
            OperationProgress(record.optInt("attempts"), record.optInt("correct"))
        }
        LearningStats(operations, json.optInt("bestStreak"), json.optInt("practiceRounds"))
    } catch (_: Exception) { LearningStats() }

    fun save(stats: LearningStats) {
        val json = JSONObject().put("bestStreak", stats.bestStreak).put("practiceRounds", stats.practiceRounds)
        stats.operations.forEach { (operation, progress) ->
            json.put(operation.name, JSONObject().put("attempts", progress.attempts).put("correct", progress.correct))
        }
        preferences.edit().putString("learningStats.v1", json.toString()).apply()
    }
}
