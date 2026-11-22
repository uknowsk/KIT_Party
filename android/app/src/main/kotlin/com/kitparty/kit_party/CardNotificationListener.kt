package com.kitparty.kit_party

import android.app.Notification
import android.content.Context
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject

/**
 * 카드 앱·카카오 알림톡 등에서 오는 "결제 승인" 알림을 폰 안에만 모아둬요.
 * 총무가 설정에서 '알림 접근'을 켰을 때만 동작해요. 서버로 보내지 않아요.
 */
class CardNotificationListener : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.packageName == packageName) return
        val extras = sbn.notification?.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val body = (extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
            ?: extras.getCharSequence(Notification.EXTRA_TEXT))?.toString() ?: ""
        val text = "$title\n$body".trim()
        if (!looksLikeCharge(text)) return
        save(this, JSONObject().apply {
            put("text", text)
            put("date", sbn.postTime)
            put("pkg", sbn.packageName)
        })
    }

    companion object {
        private const val PREFS = "card_noti"
        private const val KEY = "items"
        private const val MAX = 400
        private const val KEEP_MS = 120L * 24 * 60 * 60 * 1000 // 120일

        private val amount = Regex("""\d[\d,]*\s*원""")
        private val action = Regex("승인|결제|취소|일시불|할부")

        fun looksLikeCharge(text: String) = amount.containsMatchIn(text) && action.containsMatchIn(text)

        @Synchronized
        fun save(ctx: Context, item: JSONObject) {
            val list = load(ctx)
            // 같은 알림이 고쳐 올라오면 한 번만
            for (i in 0 until list.length()) {
                val o = list.getJSONObject(i)
                if (o.optString("text") == item.optString("text") &&
                    Math.abs(o.optLong("date") - item.optLong("date")) < 5 * 60 * 1000) return
            }
            val now = System.currentTimeMillis()
            val kept = JSONArray()
            for (i in 0 until list.length()) {
                val o = list.getJSONObject(i)
                if (now - o.optLong("date") < KEEP_MS) kept.put(o)
            }
            kept.put(item)
            val start = maxOf(0, kept.length() - MAX)
            val out = JSONArray()
            for (i in start until kept.length()) out.put(kept.get(i))
            ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, out.toString()).apply()
        }

        fun load(ctx: Context): JSONArray = try {
            JSONArray(ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, "[]"))
        } catch (e: Exception) {
            JSONArray()
        }
    }
}
