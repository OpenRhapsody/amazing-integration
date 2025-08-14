package com.example.amazingintegration

import android.annotation.SuppressLint
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.View.GONE
import android.view.View.VISIBLE
import android.webkit.*
import android.widget.ProgressBar
import android.widget.Toast
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import java.net.URISyntaxException
import java.util.Timer
import java.util.TimerTask

class AmazingWebviewActivity : AppCompatActivity() {
    private lateinit var webView: WebView
    private lateinit var progressBar: ProgressBar
    private val url: String = "https://quest.adrop.io/app"

    private var fileChooserCallback: ValueCallback<Array<Uri>>? = null
    private var timer: Timer? = null

    private var isPageFinished = false
    private var isPageReceivedError = false

    private val isPageLoaded: Boolean
        get() = isPageFinished || isPageReceivedError

    private val sdkVersion: String
        get() = "1.3.20"

    private val appVersion: String
        get() = "1.0.0"

    private val fileChooserLauncher =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
            val data = result.data
            val uris = if (result.resultCode == Activity.RESULT_OK && data != null) {
                data.data?.let { arrayOf(it) }
            } else {
                null
            }
            fileChooserCallback?.onReceiveValue(uris)
            fileChooserCallback = null
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContentView(R.layout.activity_amazing_webview)

        webView = findViewById(R.id.webview)
        progressBar = findViewById(R.id.progress)

        ViewCompat.setOnApplyWindowInsetsListener(findViewById(R.id.container)) { v, insets ->
            val systemBars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            v.setPadding(0, systemBars.top, 0, systemBars.bottom)
            insets
        }

        setup()
    }

    @SuppressLint("SetJavaScriptEnabled", "JavascriptInterface")
    private fun setup() {
        webView.apply {
            settings.apply {
                javaScriptEnabled = true
                mediaPlaybackRequiresUserGesture = false
                domStorageEnabled = true
                allowFileAccess = true
                allowContentAccess = true
                textZoom = 100

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    webView.settings.forceDark = WebSettings.FORCE_DARK_OFF
                }
            }

            webViewClient = object : WebViewClient() {
                override fun shouldOverrideUrlLoading(
                    view: WebView?,
                    request: WebResourceRequest?,
                ): Boolean {
                    val host = request?.url?.host ?: return false
                    val isAdropHost = Regex("""^([a-zA-Z0-9-]+\.)*adrop\.io$""").matches(host)
                    if (isAdropHost) return false

                    return handleUrl(request.url.toString())
                }

                @Deprecated("Deprecated in Java")
                @Suppress("DEPRECATION")
                override fun shouldOverrideUrlLoading(view: WebView, url: String): Boolean {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
                        return handleUrl(url)
                    }
                    return super.shouldOverrideUrlLoading(view, url)
                }

                override fun onPageFinished(view: WebView?, url: String?) {
                    super.onPageFinished(view, url)

                    view?.evaluateJavascript("console.log = function() {};", null)
                    view?.evaluateJavascript("console.error = function() {};", null)
                    view?.evaluateJavascript("console.warn = function() {};", null)

                    if (isPageLoaded) return
                    isPageFinished = true

                    evaluateJavascript(
                        """
                            (function () {
                        window.bridge = {
                            _promises: {},
                            callHandler: function(name, sig, payload) {
                                return new Promise((resolver, reject) => {
                                    const requestId = "req_" + Date.now()
                                    window.bridge._promises[requestId] = { resolver, reject }
                                    
                                    window.Android.callHandler(requestId, sig)
                                })
                            },
                            _receiveResult: function(requestId, result) {
                                if (window.bridge._promises[requestId]) {
                                    window.bridge._promises[requestId].resolver(result)
                                    delete window.bridge._promises[requestId]
                                }
                            }
                        };})()
        """.trimIndent(), null
                    )

                    showWebView()
                }

                override fun onReceivedError(view: WebView?, request: WebResourceRequest?, error: WebResourceError?) {
                    super.onReceivedError(view, request, error)

                    if (isPageLoaded) return
                    isPageReceivedError = true
                }
            }
            webChromeClient = createWebChromeClient()
            addJavascriptInterface(this@AmazingWebviewActivity, "Android")
            setBackgroundColor(Color.WHITE)
            loadUrl(this@AmazingWebviewActivity.url)

        }
    }

    private fun handleUrl(url: String): Boolean {
        if (!URLUtil.isNetworkUrl(url) && !URLUtil.isJavaScriptUrl(url)) {
            val uri = try {
                Uri.parse(url)
            } catch (e: Exception) {
                return false
            }

            return when (uri.scheme) {
                "intent" -> {
                    startSchemeIntent(url)
                }

                else -> {
                    return try {
                        startActivity(Intent(Intent.ACTION_VIEW, uri))
                        true
                    } catch (e: Exception) {
                        false
                    }
                }
            }
        } else {
            openExternalUrl(this, url)
            return true
        }
    }

    private fun openExternalUrl(context: Context, url: String) {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }

    private fun startSchemeIntent(url: String): Boolean {
        val schemeIntent: Intent = try {
            Intent.parseUri(url, Intent.URI_INTENT_SCHEME)
        } catch (e: URISyntaxException) {
            return false
        }
        try {
            startActivity(schemeIntent)
            return true
        } catch (e: ActivityNotFoundException) {
            val packageName = schemeIntent.getPackage()

            if (!packageName.isNullOrBlank()) {
                startActivity(
                    Intent(
                        Intent.ACTION_VIEW,
                        Uri.parse("market://details?id=$packageName")
                    )
                )
                return true
            }
        }
        return false
    }

    private fun createWebChromeClient(): WebChromeClient {
        return object : WebChromeClient() {

            override fun onShowFileChooser(webView: WebView?, filePathCallback: ValueCallback<Array<Uri>>?, fileChooserParams: FileChooserParams?): Boolean {
                fileChooserCallback?.onReceiveValue(null)
                fileChooserCallback = filePathCallback

                try {
                    fileChooserParams?.createIntent()?.let {
                        fileChooserLauncher.launch(it)
                    }
                } catch (e: ActivityNotFoundException) {
                    fileChooserCallback = null
                    return false
                }
                return true
            }
        }
    }

    private fun showWebView() {
        progressBar.visibility = GONE
        webView.visibility = VISIBLE
    }

    private fun startPageLoadTimer() {
        if (isPageLoaded) return

        stopPageLoadTimer()

        timer = Timer()
        timer?.schedule(object : TimerTask() {
            override fun run() {
                if (isPageFinished) return

                runOnUiThread {
                    Toast.makeText(this@AmazingWebviewActivity, R.string.quest_loading_failed, Toast.LENGTH_SHORT).show()
                }
                close()
            }
        }, 5_000)

    }

    private fun stopPageLoadTimer() {
        timer?.cancel()
        timer = null
    }

    override fun onResume() {
        super.onResume()
        startPageLoadTimer()
    }

    override fun onStop() {
        super.onStop()
        stopPageLoadTimer()
    }

    @JavascriptInterface
    fun close() {
        finish()
    }

    @JavascriptInterface
    fun callHandler(requestId: String, sig: String) {
        when (sig) {
            "getAppVersion" -> {
                val version = "android/${sdkVersion}/${appVersion}"
                val jsCode = java.lang.String.format("window.bridge._receiveResult('%s', '%s')", requestId, version)
                webView.post {
                    try {
                        webView.evaluateJavascript(jsCode, null)
                    } catch (e: Exception) {
                    }
                }
            }
        }
    }

    @Deprecated("")
    @Suppress("DEPRECATION")
    override fun onBackPressed() {
        if (webView.canGoBack()) {
            webView.goBack()
        } else {
            super.onBackPressed()
        }
    }
}