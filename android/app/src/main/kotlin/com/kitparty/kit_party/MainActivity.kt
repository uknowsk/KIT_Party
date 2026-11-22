package com.kitparty.kit_party

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var smsResult: MethodChannel.Result? = null
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createUpdateChannel()
    }

    /// "앱 업데이트" 알림 채널. 뱃지(아이콘 점)를 켜둬요.
    private fun createUpdateChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel("updates", "앱 업데이트", NotificationManager.IMPORTANCE_DEFAULT).apply {
            description = "새 버전이 나오면 알려드려요"
            setShowBadge(true)
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kit_party/update").setMethodCallHandler { call, result ->
            when (call.method) {
                // 설치 파일을 내려받을 폴더
                "updatesDir" -> {
                    val dir = File(cacheDir, "updates")
                    dir.mkdirs()
                    // 예전에 받아둔 설치 파일은 지워요.
                    dir.listFiles()?.forEach { it.delete() }
                    result.success(dir.absolutePath)
                }
                // 안드로이드 설치 화면 열기
                "install" -> {
                    try {
                        val file = File(call.argument<String>("path")!!)
                        val uri = FileProvider.getUriForFile(this, "$packageName.updates", file)
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("install_failed", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        // 카드 결제 문자·알림 읽기 (총무 폰에서만, 켜둔 경우에만)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kit_party/cards").setMethodCallHandler { call, result ->
            when (call.method) {
                "smsGranted" -> result.success(smsGranted())
                "requestSms" -> {
                    if (smsGranted()) {
                        result.success(true)
                    } else {
                        smsResult?.success(false)
                        smsResult = result
                        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.READ_SMS), SMS_REQ)
                    }
                }
                "readSms" -> {
                    if (!smsGranted()) {
                        result.success(emptyList<Map<String, Any>>())
                    } else {
                        val from = (call.argument<Number>("from") ?: 0).toLong()
                        val to = (call.argument<Number>("to") ?: Long.MAX_VALUE).toLong()
                        result.success(readSms(from, to))
                    }
                }
                "notiEnabled" -> result.success(
                    NotificationManagerCompat.getEnabledListenerPackages(this).contains(packageName)
                )
                "openNotiSettings" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                    } catch (e: Exception) {
                        startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
                    }
                    result.success(null)
                }
                "openAppSettings" -> {
                    startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
                    result.success(null)
                }
                "readNoti" -> {
                    val list = CardNotificationListener.load(this)
                    val out = ArrayList<Map<String, Any>>()
                    for (i in 0 until list.length()) {
                        val o = list.getJSONObject(i)
                        out.add(mapOf("text" to o.optString("text"), "date" to o.optLong("date"), "pkg" to o.optString("pkg")))
                    }
                    result.success(out)
                }
                "getPref" -> result.success(
                    getSharedPreferences("card_prefs", MODE_PRIVATE).getString(call.argument<String>("key"), null)
                )
                "setPref" -> {
                    getSharedPreferences("card_prefs", MODE_PRIVATE).edit()
                        .putString(call.argument<String>("key"), call.argument<String>("value")).apply()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun smsGranted() =
        ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED

    /** 받은 문자 중 카드 결제처럼 보이는 것만 골라와요. */
    private fun readSms(from: Long, to: Long): List<Map<String, Any>> {
        val out = ArrayList<Map<String, Any>>()
        val cursor = contentResolver.query(
            Uri.parse("content://sms/inbox"),
            arrayOf("address", "body", "date"),
            "date >= ? AND date <= ?",
            arrayOf(from.toString(), to.toString()),
            "date DESC"
        ) ?: return out
        try {
            while (cursor.moveToNext() && out.size < 2000) {
                val body = cursor.getString(1)
                if (body != null && CardNotificationListener.looksLikeCharge(body)) {
                    out.add(mapOf("address" to (cursor.getString(0) ?: ""), "body" to body, "date" to cursor.getLong(2)))
                }
            }
        } finally {
            cursor.close()
        }
        return out
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == SMS_REQ) {
            smsResult?.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
            smsResult = null
        }
    }

    companion object {
        private const val SMS_REQ = 4101
    }
}
