package com.kitparty.kit_party

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
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
    }
}
