package com.example.pareto_lingo

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class ParetoHomeWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val streak = widgetData.getInt("pl_streak", 0)
            val reminderEnabled = widgetData.getBoolean("pl_reminder_enabled", false)
            val reminderHour = widgetData.getInt("pl_reminder_hour", 20)
            val reminderMinute = widgetData.getInt("pl_reminder_minute", 0)
            val languageFlag = widgetData.getString("pl_language_flag", "🇫🇷") ?: "🇫🇷"

            val reminderText = if (reminderEnabled) {
                val hour = reminderHour.toString().padStart(2, '0')
                val minute = reminderMinute.toString().padStart(2, '0')
                "Reminder: $hour:$minute"
            } else {
                "Reminder is off"
            }

            val views = RemoteViews(context.packageName, R.layout.pareto_home_widget)
            views.setTextViewText(R.id.widgetFlag, languageFlag)
            views.setTextViewText(R.id.widgetStreak, "$streak day streak")
            views.setTextViewText(R.id.widgetReminder, reminderText)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
