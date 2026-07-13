package de.greenspoon.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Homescreen-Widget „Läuft bald ab".
 *
 * Die Daten (Titel + bis zu drei Item-Zeilen) schreibt die Flutter-Seite
 * über das home_widget-Plugin bei jeder Vorrats-Änderung. Ein Tap aufs
 * Widget öffnet die App.
 */
class GreenSpoonWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.greenspoon_widget).apply {
                setTextViewText(
                    R.id.widget_title,
                    widgetData.getString("widget_title", null) ?: "LÄUFT BALD AB"
                )
                setTextViewText(
                    R.id.widget_body,
                    widgetData.getString("widget_body", null) ?: "Alles frisch 🌿"
                )
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
