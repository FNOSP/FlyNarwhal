package com.jankinwu.fntv.client.ui.screen

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowLeft
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import co.touchlab.kermit.Logger
import com.jankinwu.fntv.client.data.constants.Colors
import com.jankinwu.fntv.client.data.model.LoginHistory
import com.jankinwu.fntv.client.data.model.request.AuthRequest
import com.jankinwu.fntv.client.data.network.impl.FnOfficialApiImpl
import com.jankinwu.fntv.client.data.store.AccountDataCache
import com.jankinwu.fntv.client.manager.PreferencesManager
import com.jankinwu.fntv.client.manager.LoginStateManager
import com.jankinwu.fntv.client.ui.component.common.ToastHost
import com.jankinwu.fntv.client.ui.component.common.ToastType
import com.jankinwu.fntv.client.ui.component.common.rememberToastManager
import com.jankinwu.fntv.client.ui.providable.LocalWebViewInitError
import com.jankinwu.fntv.client.ui.providable.LocalWebViewInitialized
import com.jankinwu.fntv.client.ui.providable.LocalWebViewRestartRequired
import com.multiplatform.webview.cookie.Cookie
import com.multiplatform.webview.jsbridge.IJsMessageHandler
import com.multiplatform.webview.jsbridge.JsMessage
import com.multiplatform.webview.jsbridge.rememberWebViewJsBridge
import com.multiplatform.webview.web.LoadingState
import com.multiplatform.webview.web.WebView
import com.multiplatform.webview.web.WebViewNavigator
import com.multiplatform.webview.web.rememberWebViewNavigator
import com.multiplatform.webview.web.rememberWebViewState
import dev.chrisbanes.haze.hazeEffect
import dev.chrisbanes.haze.hazeSource
import dev.chrisbanes.haze.materials.ExperimentalHazeMaterialsApi
import dev.chrisbanes.haze.materials.FluentMaterials
import dev.chrisbanes.haze.rememberHazeState
import fntv_client_multiplatform.composeapp.generated.resources.Res
import fntv_client_multiplatform.composeapp.generated.resources.login_background
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.channels.consumeEach
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.jetbrains.compose.resources.painterResource

private val logger = Logger.withTag("FnConnectWebViewScreen")

@OptIn(ExperimentalHazeMaterialsApi::class, ExperimentalMaterial3Api::class)
@Composable
fun FnConnectWebViewScreen(
    modifier: Modifier = Modifier,
    initialUrl: String,
    fnId: String,
    onBack: () -> Unit,
    onLoginSuccess: (LoginHistory) -> Unit,
    autoLoginUsername: String? = null,
    autoLoginPassword: String? = null,
    allowAutoLogin: Boolean = false,
    draggableArea: @Composable (content: @Composable () -> Unit) -> Unit = { it() }
) {
    val toastManager = rememberToastManager()
    val hazeState = rememberHazeState()
    val scope = rememberCoroutineScope()
    val fnOfficialApi = remember { FnOfficialApiImpl() }

    val webViewInitialized = LocalWebViewInitialized.current
    val webViewRestartRequired = LocalWebViewRestartRequired.current
    val webViewInitError = LocalWebViewInitError.current
    var baseUrl by remember { mutableStateOf("") }
    var addressBarValue by remember(initialUrl) { mutableStateOf(initialUrl) }
    var currentUrl by remember(initialUrl) { mutableStateOf(initialUrl) }
    val webViewState = rememberWebViewState(currentUrl)
    val navigator = rememberWebViewNavigator()
    val jsBridge = rememberWebViewJsBridge(navigator)
    val messageChannel = remember { Channel<String>(Channel.UNLIMITED) }
    
    var capturedUsername by remember { mutableStateOf("") }
    var capturedPassword by remember { mutableStateOf("") }
    var capturedRememberMe by remember { mutableStateOf(false) }

    LaunchedEffect(jsBridge) {
        jsBridge.register(NetworkLogHandler { params ->
            messageChannel.trySend(params)
        })
        jsBridge.register(CaptureLoginInfoHandler { username, password, rememberMe ->
            capturedUsername = username
            capturedPassword = password
            capturedRememberMe = rememberMe
            logger.i("Captured login info: user=$username, remember=$rememberMe")
        })
    }

    LaunchedEffect(Unit) {
        var isAuthRequested = false
        var isSysConfigInFlight = false
        var isSysConfigLoaded = false
        messageChannel.consumeEach { params ->
            logger.i("Intercepted: $params")
            try {
                val json = Json.parseToJsonElement(params).jsonObject
                val type = json["type"]?.jsonPrimitive?.contentOrNull
                val url = json["url"]?.jsonPrimitive?.contentOrNull ?: ""

                if (type == "XHR" && url.contains("/sac/rpcproxy/v1/new-user-guide/status")) {
                    val cookie = json["cookie"]?.jsonPrimitive?.contentOrNull
                    logger.i("fnos cookie: $cookie")
                    if (!cookie.isNullOrBlank()) {
                        AccountDataCache.mergeCookieString(cookie)
                        if (baseUrl.contains("5ddd.com")) {
                            // 使用 FN Connect 外网访问必加此 Cookie 不然访问不了
                            AccountDataCache.insertCookie("mode" to "relay")
                        }
                        if (!isSysConfigLoaded && !isSysConfigInFlight) {
                            isSysConfigInFlight = true
                            launch {
                                try {
                                    val config = fnOfficialApi.getSysConfig()
                                    logger.i("Got sys config: $config")
                                    val oauth = config.nasOauth
                                    if (oauth.url.isNotBlank() && oauth.url != "://") {
                                        baseUrl = oauth.url
                                    }
                                    val appId = oauth.appId
                                    val redirectUri = "$baseUrl/v/oauth/result"
                                    val targetUrl = "$baseUrl/signin?client_id=$appId&redirect_uri=$redirectUri"

                                    logger.i("Navigating to OAuth: $targetUrl")
                                    val domain = baseUrl.substringAfter("://").substringBefore(":").substringBefore("/")
                                    cookie.split(";").forEach {
                                        val parts = it.trim().split("=", limit = 2)
                                        if (parts.size == 2) {
                                            val cookieObj = Cookie(
                                                name = parts[0],
                                                value = parts[1],
                                                domain = domain
                                            )
                                            webViewState.cookieManager.setCookie(baseUrl, cookieObj)
                                        }
                                    }
                                    isSysConfigLoaded = true
                                    navigator.loadUrl(targetUrl)
                                } catch (e: Exception) {
                                    isSysConfigInFlight = false
                                    logger.e("Failed to get sys config", e)
                                    toastManager.showToast("获取系统配置失败: ${e.message}", ToastType.Failed)
                                }
                            }
                        }
                    }
                } else if (type == "Response" && url.contains("/oauthapi/authorize")) {
                    if (!isAuthRequested) {
                        val body = json["body"]?.jsonPrimitive?.contentOrNull
                        if (!body.isNullOrBlank()) {
                            try {
                                val bodyJson = Json.parseToJsonElement(body).jsonObject
                                val data = bodyJson["data"]?.jsonObject
                                val code = data?.get("code")?.jsonPrimitive?.contentOrNull
                                if (code != null) {
                                    isAuthRequested = true
                                    launch {
                                        try {
                                            val response = fnOfficialApi.auth(AuthRequest("Trim-NAS", code))
                                            val token = response.token
                                            if (token.isNotBlank()) {
                                                AccountDataCache.authorization = token
                                                AccountDataCache.insertCookie("Trim-MC-token" to token)
                                                logger.i("cookie: ${AccountDataCache.cookieState}")
                                                LoginStateManager.updateLoginStatus(true)
                                                toastManager.showToast("登录成功", ToastType.Success)
                                                
                                                val normalizedUsername = capturedUsername.trim()
                                                    .ifBlank { autoLoginUsername?.trim().orEmpty() }
                                                    .ifBlank { "Unknown" }
                                                val shouldRemember = capturedRememberMe && capturedPassword.isNotBlank()
                                                PreferencesManager.getInstance().addLoginUsernameHistory(normalizedUsername)
                                                logger.i("Remember me: $capturedRememberMe")
                                                val history = LoginHistory(
                                                    host = "",
                                                    port = 0,
                                                    username = normalizedUsername,
                                                    password = if (shouldRemember) capturedPassword else null,
                                                    isHttps = baseUrl.startsWith("https"),
                                                    rememberMe = shouldRemember,
                                                    isFnConnect = true,
                                                    fnConnectUrl = baseUrl,
                                                    fnId = fnId.trim()
                                                )
                                                onLoginSuccess(history)
                                            } else {
                                                isAuthRequested = false
                                                toastManager.showToast("登录失败: Token 为空", ToastType.Failed)
                                            }
                                        } catch (e: Exception) {
                                            isAuthRequested = false
                                            logger.e("OAuth result failed", e)
                                            toastManager.showToast("登录失败: ${e.message}", ToastType.Failed)
                                        }
                                    }
                                }
                            } catch (e: Exception) {
                                logger.e("Failed to parse OAuth response", e)
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                logger.e("Handler error", e)
            }
        }
    }

    LaunchedEffect(webViewState.lastLoadedUrl) {
        webViewState.lastLoadedUrl?.let { url ->
            if (url.isNotBlank()) {
                addressBarValue = url
                logger.i("Loaded url: $url")
                if (url.contains("/login")) {
                    baseUrl = url.substringBefore("/login")
                    AccountDataCache.updateFnOfficialBaseUrlFromUrl(baseUrl)
                    logger.i("Base url: $baseUrl")
                }
            }
        }
    }

    // 注入 JS 拦截器以监听 XHR 和 Fetch 请求并打印请求头
    LaunchedEffect(webViewState.loadingState) {
        if (webViewState.loadingState is LoadingState.Finished) {
            val usernameHistoryJs = PreferencesManager.getInstance()
                .loadLoginUsernameHistory()
                .joinToString(prefix = "[", postfix = "]") { username ->
                    "\"" + username.replace("\\", "\\\\").replace("\"", "\\\"") + "\""
                }
            val jsScript = """
                (function() {
                    console.log("Injecting Network Interceptor...");
                    
                    var AUTO_LOGIN_USER = "${autoLoginUsername ?: ""}";
                    var AUTO_LOGIN_PASS = "${autoLoginPassword ?: ""}";
                    var ALLOW_AUTO_LOGIN = ${allowAutoLogin};
                    var USERNAME_HISTORY = $usernameHistoryJs;
                    
                    function logToNative(type, url, method, headers, body) {
                        if (window.kmpJsBridge) {
                            window.kmpJsBridge.callNative("LogNetwork", JSON.stringify({
                                type: type,
                                url: url,
                                method: method,
                                headers: headers,
                                cookie: document.cookie,
                                body: body
                            }));
                        }
                    }
                    
                    function triggerInput(input, value) {
                        var nativeInputValueSetter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value").set;
                        nativeInputValueSetter.call(input, value);
                        input.dispatchEvent(new Event('input', { bubbles: true }));
                    }

                    function injectUI() {
                        if (window.location.href.indexOf('/login') !== -1) {
                             function ensureRememberPasswordCheckbox() {
                                 var staySpan = document.getElementById('stay');
                                 if (!staySpan) {
                                     var allDivs = document.querySelectorAll('div');
                                     for (var i = 0; i < allDivs.length; i++) {
                                         if (allDivs[i].innerText === '保持登录') {
                                             staySpan = allDivs[i].closest('.semi-checkbox');
                                             break;
                                         }
                                     }
                                 }
                                 var stayField = staySpan ? staySpan.closest('.semi-form-field') : null;
                                 var leftContainer = stayField ? stayField.parentElement : null;
                                 if (!leftContainer) {
                                     var allDivs = document.querySelectorAll('div');
                                     for (var i = 0; i < allDivs.length; i++) {
                                         if (allDivs[i].innerText === '忘记密码？') {
                                             leftContainer = allDivs[i].parentElement;
                                             break;
                                         }
                                     }
                                 }

                                 if (stayField) {
                                     stayField.remove();
                                 }

                                 if (!leftContainer || document.getElementById('remember-password-wrapper')) return;

                                 var wrapper = document.createElement('div');
                                 wrapper.id = 'remember-password-wrapper';
                                 wrapper.style.display = 'inline-flex';
                                 wrapper.style.alignItems = 'center';
                                 wrapper.style.cursor = 'pointer';
                                 wrapper.style.gap = '6px';
                                 wrapper.style.userSelect = 'none';

                                 var input = document.createElement('input');
                                 input.type = 'checkbox';
                                 input.id = 'remember-password';
                                 input.style.display = 'none';

                                 var box = document.createElement('span');
                                 box.style.width = '18px';
                                 box.style.height = '18px';
                                 box.style.border = '1px solid rgba(255,255,255,0.6)';
                                 box.style.borderRadius = '4px';
                                 box.style.display = 'inline-flex';
                                 box.style.alignItems = 'center';
                                 box.style.justifyContent = 'center';
                                 box.style.boxSizing = 'border-box';

                                 var svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
                                 svg.setAttribute('viewBox', '0 0 24 24');
                                 svg.setAttribute('width', '14');
                                 svg.setAttribute('height', '14');
                                 svg.style.display = 'none';
                                 var path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
                                 path.setAttribute('d', 'M20 6L9 17l-5-5');
                                 path.setAttribute('fill', 'none');
                                 path.setAttribute('stroke', '#ffffff');
                                 path.setAttribute('stroke-width', '3');
                                 path.setAttribute('stroke-linecap', 'round');
                                 path.setAttribute('stroke-linejoin', 'round');
                                 svg.appendChild(path);
                                 box.appendChild(svg);

                                 var label = document.createElement('div');
                                 label.innerText = '记住密码';
                                 label.style.fontSize = '16px';
                                 label.style.lineHeight = '22px';
                                 label.style.color = '#ffffff';

                                 function renderRemember() {
                                     if (input.checked) {
                                         box.style.background = 'rgba(58,123,255,1)';
                                         svg.style.display = 'block';
                                     } else {
                                         box.style.background = 'transparent';
                                         svg.style.display = 'none';
                                     }
                                 }

                                 wrapper.addEventListener('click', function(e) {
                                     e.preventDefault();
                                     input.checked = !input.checked;
                                     renderRemember();
                                 });

                                 wrapper.appendChild(input);
                                 wrapper.appendChild(box);
                                 wrapper.appendChild(label);
                                 leftContainer.insertBefore(wrapper, leftContainer.firstChild);

                                 window.__setRememberPasswordChecked = function(checked) {
                                     input.checked = !!checked;
                                     renderRemember();
                                 };

                                 renderRemember();
                             }

                             function ensureUsernameHistoryDropdown() {
                                 var input = document.getElementById('username');
                                 if (!input || input.getAttribute('data-username-history') === '1') return;
                                 input.setAttribute('data-username-history', '1');

                                 var dropdown = document.createElement('div');
                                 dropdown.id = 'username-history-dropdown';
                                 dropdown.style.position = 'fixed';
                                 dropdown.style.zIndex = '999999';
                                 dropdown.style.display = 'none';
                                 dropdown.style.maxHeight = '200px';
                                 dropdown.style.overflowY = 'auto';
                                 dropdown.style.boxSizing = 'border-box';
                                 dropdown.style.background = 'rgba(242,243,245,0.98)';
                                 dropdown.style.border = '1px solid rgba(0,0,0,0.10)';
                                 dropdown.style.borderRadius = '8px';
                                 dropdown.style.boxShadow = '0 10px 30px rgba(0,0,0,0.18)';
                                 dropdown.style.padding = '6px';

                                 function position() {
                                     var r = input.getBoundingClientRect();
                                     dropdown.style.left = r.left + 'px';
                                     dropdown.style.top = (r.bottom + 6) + 'px';
                                     dropdown.style.width = r.width + 'px';
                                 }

                                 function render(filterText) {
                                     dropdown.innerHTML = '';
                                     var list = USERNAME_HISTORY || [];
                                     var q = (filterText || '').trim().toLowerCase();
                                     if (q) {
                                         list = list.filter(function(u) {
                                             return (u || '').toLowerCase().indexOf(q) !== -1;
                                         });
                                     }
                                     if (!list.length) {
                                         var empty = document.createElement('div');
                                         empty.innerText = '无历史用户名';
                                         empty.style.padding = '10px 10px';
                                         empty.style.color = 'rgba(0,0,0,0.45)';
                                         empty.style.fontSize = '14px';
                                         dropdown.appendChild(empty);
                                         return;
                                     }
                                     for (var i = 0; i < list.length; i++) {
                                         (function(name) {
                                             var item = document.createElement('div');
                                             item.innerText = name;
                                             item.style.padding = '10px 10px';
                                             item.style.borderRadius = '6px';
                                             item.style.color = '#1A1D26';
                                             item.style.fontSize = '14px';
                                             item.style.cursor = 'pointer';
                                             item.addEventListener('mouseenter', function() {
                                                 item.style.background = 'rgba(0,0,0,0.06)';
                                             });
                                             item.addEventListener('mouseleave', function() {
                                                 item.style.background = 'transparent';
                                             });
                                             item.addEventListener('mousedown', function(e) {
                                                 e.preventDefault();
                                                 triggerInput(input, name);
                                                 dropdown.style.display = 'none';
                                             });
                                             dropdown.appendChild(item);
                                         })(list[i]);
                                     }
                                 }

                                 function show() {
                                     position();
                                     render(input.value);
                                     dropdown.style.display = 'block';
                                 }

                                 function hide() {
                                     dropdown.style.display = 'none';
                                 }

                                 input.addEventListener('focus', show);
                                 input.addEventListener('click', show);
                                 input.addEventListener('input', function() {
                                     if (dropdown.style.display !== 'none') render(input.value);
                                 });
                                 input.addEventListener('blur', function() {
                                     setTimeout(hide, 150);
                                 });

                                 document.addEventListener('mousedown', function(e) {
                                     if (e.target !== input && !dropdown.contains(e.target)) hide();
                                 });

                                 window.addEventListener('resize', function() {
                                     if (dropdown.style.display !== 'none') position();
                                 });
                                 window.addEventListener('scroll', function() {
                                     if (dropdown.style.display !== 'none') position();
                                 }, true);

                                 document.body.appendChild(dropdown);
                                 setTimeout(function() {
                                     if (document.activeElement === input) show();
                                 }, 0);
                             }

                             ensureRememberPasswordCheckbox();
                             ensureUsernameHistoryDropdown();
                             
                             function captureAndSend() {
                                 var u = document.getElementById('username') ? document.getElementById('username').value : "";
                                 var p = document.getElementById('password') ? document.getElementById('password').value : "";
                                 var r = document.getElementById('remember-password') ? document.getElementById('remember-password').checked : false;
                                 
                                 if (window.kmpJsBridge) {
                                     window.kmpJsBridge.callNative("CaptureLoginInfo", JSON.stringify({
                                         username: u,
                                         password: p,
                                         rememberMe: r
                                     }));
                                 }
                             }

                             var loginBtn = document.querySelector('button[type="submit"]');
                             if (loginBtn && !loginBtn.getAttribute('data-intercepted')) {
                                 loginBtn.setAttribute('data-intercepted', 'true');
                                 loginBtn.addEventListener('click', captureAndSend);
                                 
                                 var form = loginBtn.closest('form');
                                 if (form) {
                                     form.addEventListener('submit', captureAndSend);
                                 }
                             }
                             
                             // 同时也监听输入变化，防止某些情况下点击或提交没捕获到最新的
                             var uInp = document.getElementById('username');
                             var pInp = document.getElementById('password');
                             var rInp = document.getElementById('remember-password');
                             if (uInp && !uInp.getAttribute('data-monitored')) {
                                 uInp.setAttribute('data-monitored', 'true');
                                 uInp.addEventListener('change', captureAndSend);
                             }
                             if (pInp && !pInp.getAttribute('data-monitored')) {
                                 pInp.setAttribute('data-monitored', 'true');
                                 pInp.addEventListener('change', captureAndSend);
                             }
                             if (rInp && !rInp.getAttribute('data-monitored')) {
                                 rInp.setAttribute('data-monitored', 'true');
                                 rInp.addEventListener('change', captureAndSend);
                             }
                        }
                    }

                    injectUI();
                    // 每500ms尝试注入一次，确保动态渲染也能捕获
                    setInterval(injectUI, 500);

                    if (window.location.href.indexOf('/login') !== -1) {
                         if (AUTO_LOGIN_USER) {
                             setTimeout(function() {
                                  var uInput = document.getElementById('username');
                                  var pInput = document.getElementById('password');
                                  if (uInput) {
                                      triggerInput(uInput, AUTO_LOGIN_USER);
                                      
                                      if (ALLOW_AUTO_LOGIN && AUTO_LOGIN_PASS && pInput) {
                                          triggerInput(pInput, AUTO_LOGIN_PASS);
                                          
                                          if (window.__setRememberPasswordChecked) {
                                              window.__setRememberPasswordChecked(true);
                                          } else {
                                              var rememberInput = document.getElementById('remember-password');
                                              if (rememberInput) rememberInput.checked = true;
                                          }
                                          
                                          setTimeout(function() {
                                              var btn = document.querySelector('button[type="submit"]');
                                              if (btn) btn.click();
                                          }, 500);
                                      }
                                  }
                             }, 1000);
                          }
                     }
                     
                     if (ALLOW_AUTO_LOGIN && window.location.href.indexOf('/signin') !== -1) {
                         setTimeout(function() {
                             var btns = document.querySelectorAll('button');
                             for (var i = 0; i < btns.length; i++) {
                                 if (btns[i].innerText.indexOf('授权') !== -1) {
                                     btns[i].click();
                                     break;
                                 }
                             }
                         }, 1000);
                     }
 
                     // Hook XMLHttpRequest
                    var originalOpen = XMLHttpRequest.prototype.open;
                    XMLHttpRequest.prototype.open = function(method, url) {
                        this._method = method;
                        this._url = url;
                        this._headers = {};
                        // console.log("[Intercepted XHR] " + method + " " + url);
                        return originalOpen.apply(this, arguments);
                    };
                    
                    var originalSetRequestHeader = XMLHttpRequest.prototype.setRequestHeader;
                    XMLHttpRequest.prototype.setRequestHeader = function(header, value) {
                        this._headers[header] = value;
                        // console.log("[Intercepted XHR Header] " + this._url + " : " + header + " = " + value);
                        return originalSetRequestHeader.apply(this, arguments);
                    };

                    var originalSend = XMLHttpRequest.prototype.send;
                    XMLHttpRequest.prototype.send = function(body) {
                        var self = this;
                        var originalOnReadyStateChange = self.onreadystatechange;
                        self.onreadystatechange = function() {
                            if (self.readyState === 4) {
                                if (self._url && self._url.indexOf("/oauthapi/authorize") !== -1) {
                                    logToNative("Response", self._url, self._method, {}, self.responseText);
                                }
                            }
                            if (originalOnReadyStateChange) {
                                originalOnReadyStateChange.apply(this, arguments);
                            }
                        }
                        
                        logToNative("XHR", this._url, this._method, this._headers, null);
                        return originalSend.apply(this, arguments);
                    };

                    // Hook Fetch
                    var originalFetch = window.fetch;
                    window.fetch = function(input, init) {
                        var url = input;
                        if (typeof input === 'object' && input.url) {
                            url = input.url;
                        }
                        var method = (init && init.method) ? init.method : 'GET';
                        
                        var headers = {};
                        if (init && init.headers) {
                            var h = init.headers;
                            if (h instanceof Headers) {
                                h.forEach(function(value, key) {
                                    headers[key] = value;
                                });
                            } else {
                                for (var key in h) {
                                    if (h.hasOwnProperty(key)) {
                                        headers[key] = h[key];
                                    }
                                }
                            }
                        }
                        
                        logToNative("Fetch", url, method, headers, null);
                        return originalFetch.apply(this, arguments).then(function(response) {
                            if (url && url.indexOf("/oauthapi/authorize") !== -1) {
                                var clone = response.clone();
                                clone.text().then(function(text) {
                                     logToNative("Response", url, method, {}, text);
                                });
                            }
                            return response;
                        });
                    };
                    console.log("Network Interceptor Injected Successfully.");
                })();
            """.trimIndent()
            navigator.evaluateJavaScript(jsScript)
        }
    }

    Box(modifier = modifier.fillMaxSize()) {
        Image(
            painterResource(Res.drawable.login_background),
            contentDescription = "Login background",
            contentScale = ContentScale.Crop,
            modifier = Modifier
                .fillMaxSize()
                .hazeSource(state = hazeState)
        )



        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color(0xFF14171A).copy(alpha = 0.6f)),
            contentAlignment = Alignment.Center
        ) {
            Surface(
                color = Color.Transparent,
                shape = RoundedCornerShape(0.dp),
                modifier = Modifier
                    .fillMaxSize()
                    .hazeEffect(
                        state = hazeState,
                        style = FluentMaterials.acrylicDefault(true)
                    )
            ) {
                // Window Draggable Area
                draggableArea {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(48.dp)
                            .align(Alignment.TopCenter)
                    )
                }
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(top = 48.dp, end = 12.dp)
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
//                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        IconButton(
                            onClick = onBack,
                            modifier = Modifier.pointerHoverIcon(PointerIcon.Hand)
                        ) {
                            Icon(
                                imageVector = Icons.AutoMirrored.Filled.ArrowLeft,
                                contentDescription = "Back",
                                tint = Colors.TextSecondaryColor
                            )
                        }

                        BasicTextField(
                            value = addressBarValue,
                            onValueChange = { addressBarValue = it },
                            modifier = Modifier
                                .height(30.dp)
                                .weight(1f),
                            singleLine = true,
                            textStyle = LocalTextStyle.current.copy(
                                fontSize = 14.sp,
                                color = Colors.TextSecondaryColor
                            ),
                            cursorBrush = SolidColor(Colors.AccentColorDefault),
                            keyboardOptions = KeyboardOptions(
                                keyboardType = KeyboardType.Uri,
                                imeAction = ImeAction.Go
                            ),
//                            keyboardActions = KeyboardActions(
//                                onGo = {
//                                    val target = normalizeFnConnectUrl(addressBarValue, isHttps)
//                                    if (target.isNotBlank()) {
//                                        currentUrl = target
//                                        addressBarValue = target
//                                    } else {
//                                        toastManager.showToast("请输入有效地址", ToastType.Info)
//                                    }
//                                }
//                            ),
                            decorationBox = { innerTextField ->
                                OutlinedTextFieldDefaults.DecorationBox(
                                    value = addressBarValue,
                                    innerTextField = innerTextField,
                                    enabled = true,
                                    singleLine = true,
                                    visualTransformation = VisualTransformation.None,
                                    interactionSource = remember { MutableInteractionSource() },
                                    placeholder = {
                                        Text(
                                            "请输入地址",
                                            fontSize = 14.sp,
                                            color = Color.White.copy(alpha = 0.6f)
                                        )
                                    },
                                    colors = getTextFieldColors(),
                                    container = {
                                        OutlinedTextFieldDefaults.ContainerBox(
                                            enabled = true,
                                            isError = false,
                                            interactionSource = remember { MutableInteractionSource() },
                                            colors = getTextFieldColors(),
                                            shape = RoundedCornerShape(8.dp),
                                            focusedBorderThickness = 1.dp,
                                            unfocusedBorderThickness = 1.dp
                                        )
                                    },
                                    contentPadding = PaddingValues(horizontal = 12.dp, vertical = 0.dp)
                                )
                            }
                        )
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .weight(1f)
                            .clip(RoundedCornerShape(12.dp))
                            .background(Color.White)
                    ) {
                        when {
                            webViewInitialized -> {
                                WebView(
                                    state = webViewState,
                                    modifier = Modifier.fillMaxSize(),
                                    navigator = navigator,
                                    webViewJsBridge = jsBridge
                                )
                            }

                            webViewRestartRequired -> {
                                Text(
                                    text = "WebView 初始化完成，但需要重启应用后生效。",
                                    color = Color.Black,
                                    modifier = Modifier.align(Alignment.Center)
                                )
                            }

                            webViewInitError != null -> {
                                Text(
                                    text = "WebView 初始化失败：${webViewInitError.message ?: "未知错误"}",
                                    color = Color.Black,
                                    modifier = Modifier.align(Alignment.Center)
                                )
                            }

                            else -> {
                                Text(
                                    text = "WebView 初始化中，请稍候…",
                                    color = Color.Black,
                                    modifier = Modifier.align(Alignment.Center)
                                )
                            }
                        }
                    }
                }
            }
        }

        ToastHost(
            toastManager = toastManager,
            modifier = Modifier.fillMaxSize()
        )
    }
}

@Composable
private fun getTextFieldColors() = OutlinedTextFieldDefaults.colors(
    focusedBorderColor = Colors.AccentColorDefault,
    unfocusedBorderColor = Color.White.copy(alpha = 0.35f),
    focusedLabelColor = Colors.AccentColorDefault,
    unfocusedLabelColor = Color.White.copy(alpha = 0.6f),
    cursorColor = Colors.AccentColorDefault,
    focusedTextColor = Colors.TextSecondaryColor,
    unfocusedTextColor = Colors.TextSecondaryColor
)

internal fun normalizeFnConnectUrl(value: String, isHttps: Boolean): String {
    // Normalize FN Connect host and ensure HTTPS is always used.
    val trimmed = value.trim()
    if (trimmed.isBlank()) return ""

    if (trimmed.startsWith("https://") || trimmed.startsWith("http://")) {
        return trimmed
    }

    val host = trimmed.substringBefore("/")
    val path = trimmed.removePrefix(host)
    val normalizedHost = if (host.contains('.')) host else "$host.5ddd.com"
    val protocolPrefix = if (normalizedHost.contains("5ddd.com")) {
        "https://"
    } else {
        if (isHttps) "https://" else "http://"
    }
    return "$protocolPrefix$normalizedHost$path"
}

class NetworkLogHandler(private val onMessage: (String) -> Unit) : IJsMessageHandler {
    override fun methodName(): String = "LogNetwork"

    override fun handle(message: JsMessage, navigator: WebViewNavigator?, callback: (String) -> Unit) {
        onMessage(message.params)
        callback("OK")
    }
}

class CaptureLoginInfoHandler(private val onCapture: (String, String, Boolean) -> Unit) : IJsMessageHandler {
    override fun methodName(): String = "CaptureLoginInfo"

    override fun handle(message: JsMessage, navigator: WebViewNavigator?, callback: (String) -> Unit) {
        try {
            val json = Json.parseToJsonElement(message.params).jsonObject
            val username = json["username"]?.jsonPrimitive?.contentOrNull ?: ""
            val password = json["password"]?.jsonPrimitive?.contentOrNull ?: ""
            val rememberMe = json["rememberMe"]?.jsonPrimitive?.booleanOrNull ?: false
            onCapture(username, password, rememberMe)
        } catch (e: Exception) {
            e.printStackTrace()
        }
        callback("OK")
    }
}

