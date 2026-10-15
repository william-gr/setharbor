package com.william.treino

import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import android.net.Uri
import android.util.AtomicFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.io.InputStream
import java.nio.ByteBuffer
import java.nio.charset.StandardCharsets
import javax.net.ssl.HttpsURLConnection
import java.net.URL
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private lateinit var channel: MethodChannel
    private val io = Executors.newSingleThreadExecutor()
    private val network = Executors.newSingleThreadExecutor()
    private var ready = false
    private var pendingLink: String? = null
    private var documentResult: MethodChannel.Result? = null
    private var documentLimit = 0
    private var exportText: String? = null
    private val stateFile get() = AtomicFile(File(filesDir, "training-flutter.json"))

    override fun onCreate(savedInstanceState: Bundle?) {
        pendingLink = savedInstanceState?.getString("pendingLink") ?: intent?.dataString
        super.onCreate(savedInstanceState)
    }
    override fun onSaveInstanceState(out: Bundle) {
        out.putString("pendingLink", pendingLink)
        super.onSaveInstanceState(out)
    }
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, "com.william.treino/platform")
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "testEnvironment" -> result.success(packageName.endsWith(".e2e") && android.os.Build.HARDWARE in listOf("ranchu", "goldfish"))
                    "readState" -> {
                        val file = stateFile
                        if (!file.baseFile.exists() && !File(file.baseFile.path + ".bak").exists()) result.success(null)
                        else result.success(file.openRead().use { readText(it, 50 * 1024 * 1024) })
                    }
                    "readLegacy" -> result.success(JSONObject(getSharedPreferences("training", MODE_PRIVATE).all).toString())
                    "writeState" -> {
                        val text = call.arguments as String
                        io.execute {
                            val file = stateFile
                            var output: java.io.FileOutputStream? = null
                            try {
                                output = file.startWrite()
                                output.write(text.toByteArray(StandardCharsets.UTF_8))
                                output.fd.sync()
                                file.finishWrite(output)
                                runOnUiThread { result.success(null) }
                            } catch (e: Exception) {
                                if (output != null) file.failWrite(output)
                                runOnUiThread { result.error("storage", "Falha ao gravar. Seu treino continua aberto.", null) }
                            }
                        }
                    }
                    "initialLink" -> { ready = true; result.success(pendingLink); pendingLink = null; intent.data = null }
                    "pickDocument", "exportDocument" -> {
                        if (documentResult != null) throw IllegalStateException("Seletor já aberto")
                        documentResult = result
                        val exporting = call.method == "exportDocument"
                        exportText = if (exporting) call.arguments as String else null
                        documentLimit = if (exporting) 0 else (call.arguments as Number).toInt()
                        val picker = Intent(if (exporting) Intent.ACTION_CREATE_DOCUMENT else Intent.ACTION_OPEN_DOCUMENT)
                        picker.type = "application/json"; picker.addCategory(Intent.CATEGORY_OPENABLE)
                        if (exporting) picker.putExtra(Intent.EXTRA_TITLE, "meu-treino-backup.json")
                        try { startActivityForResult(picker, 42) } catch (e: Exception) { documentResult = null; exportText = null; throw e }
                    }
                    "share" -> {
                        val share = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, call.arguments as String)
                        startActivity(Intent.createChooser(share, "Planejar com ChatGPT")); result.success(null)
                    }
                    "openUrl" -> { startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(call.arguments as String))); result.success(null) }
                    "linkSettings" -> {
                        startActivity(Intent(if (android.os.Build.VERSION.SDK_INT >= 31) Settings.ACTION_APP_OPEN_BY_DEFAULT_SETTINGS else Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
                        result.success(null)
                    }
                    "fetchPlan" -> {
                        val address = call.arguments as String
                        network.execute {
                            try {
                                val uri = java.net.URI(address)
                                require(uri.scheme == "https" && uri.host != null && uri.userInfo == null)
                                val connection = URL(address).openConnection() as HttpsURLConnection
                                connection.connectTimeout = 10000; connection.readTimeout = 10000; connection.instanceFollowRedirects = false
                                val text = try { require(connection.responseCode == 200); connection.inputStream.use { readText(it, 1024 * 1024) } } finally { connection.disconnect() }
                                runOnUiThread { result.success(text) }
                            } catch (e: Exception) { runOnUiThread { result.error("network", "Não foi possível buscar a ficha. O treino offline continua disponível.", null) } }
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) { result.error("platform", e.message, null) }
        }
    }
    override fun onDestroy() {
        io.shutdown(); network.shutdown()
        super.onDestroy()
    }
    private fun readText(input: InputStream, limit: Int): String {
        val bytes = java.io.ByteArrayOutputStream()
        val buffer = ByteArray(8192)
        while (true) {
            val size = input.read(buffer); if (size == -1) break
            require(bytes.size() + size <= limit) { "Arquivo muito grande" }
            bytes.write(buffer, 0, size)
        }
        return StandardCharsets.UTF_8.newDecoder().decode(ByteBuffer.wrap(bytes.toByteArray())).toString()
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action == Intent.ACTION_VIEW) {
            pendingLink = intent.dataString
            if (ready) { channel.invokeMethod("link", pendingLink); pendingLink = null; intent.data = null }
        }
    }
    @Deprecated("Android document contract")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 42) return
        val result = documentResult ?: return
        documentResult = null
        val text = exportText; exportText = null
        if (resultCode != RESULT_OK || data?.data == null) { result.success(if (text == null) null else false); return }
        try {
            if (text == null) result.success(contentResolver.openInputStream(data.data!!)?.use { readText(it, documentLimit) } ?: error("Documento indisponível"))
            else {
                (contentResolver.openOutputStream(data.data!!, "wt") ?: error("Documento indisponível")).use { it.write(text.toByteArray(StandardCharsets.UTF_8)) }
                result.success(true)
            }
        } catch (e: Exception) { result.error("document", e.message, null) }
    }
}
