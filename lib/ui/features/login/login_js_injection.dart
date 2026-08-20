class LoginJsInjectionBuilder {
  const LoginJsInjectionBuilder({
    required this.autoLoginUsernameLiteral,
    required this.autoLoginPasswordLiteral,
    required this.allowAutoLogin,
    required this.usernameHistoryJsonLiteral,
  });

  final String autoLoginUsernameLiteral;
  final String autoLoginPasswordLiteral;
  final bool allowAutoLogin;
  final String usernameHistoryJsonLiteral;

  String build() {
    return '''
(function() {
  var AUTO_LOGIN_USER = $autoLoginUsernameLiteral;
  var AUTO_LOGIN_PASS = $autoLoginPasswordLiteral;
  var ALLOW_AUTO_LOGIN = $allowAutoLogin;
  var USERNAME_HISTORY = $usernameHistoryJsonLiteral || [];

  // fnOS shows a terminal "系统异常，请联系管理员修复系统" alert after its
  // vite:preloadError handler reloads the page 3 times. In WKWebView,
  // HTTP/3 (QUIC) races on lazy chunk imports can be killed by local
  // proxy/tunnel network extensions before the TCP fallback completes,
  // which trips that reload loop even though the page recovers. The
  // alert only blocks the recovered page, so suppress it; fnOS's own
  // reload counter still terminates the loop on the recovered page.
  if (!window.__flynarwhal_alert_guarded) {
    window.__flynarwhal_alert_guarded = true;
    var originalAlert = window.alert ? window.alert.bind(window) : null;
    window.alert = function(message) {
      if (String(message).indexOf('系统异常，请联系管理员修复系统') !== -1) return;
      if (originalAlert) originalAlert(message);
    };
  }

  function callNative(method, params) {
    var serializedParams = params || '';
    try {
      if (window.flutter_inappwebview && typeof window.flutter_inappwebview.callHandler === 'function') {
        window.flutter_inappwebview.callHandler(method, serializedParams);
        return;
      }
      if (window.kmpJsBridge && typeof window.kmpJsBridge.callNative === 'function') {
        window.kmpJsBridge.callNative(method, serializedParams);
        return;
      }
    } catch (error) {}
    try {
      window.location.hash = 'flynarwhal_bridge?method=' + encodeURIComponent(method) + '&params=' + encodeURIComponent(serializedParams);
    } catch (error) {}
  }

  function getUsernameInput() {
    return document.querySelector('#username') || document.querySelector('input[name="username"]');
  }

  function getPasswordInput() {
    return document.querySelector('#password') || document.querySelector('input[name="password"]') || document.querySelector('input[type="password"]');
  }

  function triggerInput(input, value) {
    if (!input) return false;
    try {
      var nativeSetter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
      nativeSetter.call(input, value);
    } catch (error) {
      input.value = value;
    }
    input.dispatchEvent(new Event('input', { bubbles: true }));
    input.dispatchEvent(new Event('change', { bubbles: true }));
    return true;
  }

  function getRememberPasswordInput() {
    return document.getElementById('remember-password');
  }

  function captureLogin() {
    var usernameInput = getUsernameInput();
    var passwordInput = getPasswordInput();
    var rememberPasswordInput = getRememberPasswordInput();
    callNative('CaptureLoginInfo', JSON.stringify({
      username: usernameInput ? usernameInput.value || '' : '',
      password: passwordInput ? passwordInput.value || '' : '',
      rememberPassword: !!(rememberPasswordInput && rememberPasswordInput.checked)
    }));
  }

  function bindCapture(element, eventName) {
    if (!element) return;
    var bindingKey = '__flynarwhal_' + eventName + '_bound';
    if (element[bindingKey]) return;
    element[bindingKey] = true;
    element.addEventListener(eventName, captureLogin);
  }

  function ensureRememberPasswordCheckbox() {
    var existingInput = getRememberPasswordInput();
    if (existingInput) return existingInput;

    var originalCheckbox = document.getElementById('stay');
    var originalField = originalCheckbox ? originalCheckbox.closest('.semi-form-field') : null;
    var insertionContainer = originalField ? originalField.parentElement : null;
    if (!insertionContainer) {
      var forgotPasswordElement = Array.prototype.find.call(document.querySelectorAll('div'), function(element) {
        return (element.innerText || '').trim() === '忘记密码？';
      });
      insertionContainer = forgotPasswordElement ? forgotPasswordElement.parentElement : null;
    }
    if (!insertionContainer) return null;
    if (originalField) originalField.remove();

    var wrapper = document.createElement('div');
    wrapper.id = 'remember-password-wrapper';
    wrapper.style.cssText = 'display:inline-flex;align-items:center;gap:6px;cursor:pointer;user-select:none;';
    var input = document.createElement('input');
    input.type = 'checkbox';
    input.id = 'remember-password';
    input.style.display = 'none';
    var box = document.createElement('span');
    box.style.cssText = 'width:18px;height:18px;border:1px solid rgba(255,255,255,.6);border-radius:4px;display:inline-flex;align-items:center;justify-content:center;box-sizing:border-box;';
    var checkmark = document.createElement('span');
    checkmark.textContent = '✓';
    checkmark.style.cssText = 'display:none;color:#fff;font-size:14px;font-weight:bold;';
    box.appendChild(checkmark);
    var label = document.createElement('span');
    label.textContent = '记住密码';
    label.style.cssText = 'font-size:16px;line-height:22px;color:#fff;';

    function renderRememberPassword() {
      box.style.background = input.checked ? 'rgba(58,123,255,1)' : 'transparent';
      checkmark.style.display = input.checked ? 'block' : 'none';
    }
    function setRememberPasswordChecked(checked) {
      input.checked = !!checked;
      input.dispatchEvent(new Event('input', { bubbles: true }));
      input.dispatchEvent(new Event('change', { bubbles: true }));
      renderRememberPassword();
    }
    wrapper.addEventListener('click', function(event) {
      event.preventDefault();
      setRememberPasswordChecked(!input.checked);
    });
    input.addEventListener('change', renderRememberPassword);
    wrapper.appendChild(input);
    wrapper.appendChild(box);
    wrapper.appendChild(label);
    insertionContainer.insertBefore(wrapper, insertionContainer.firstChild);
    window.__setRememberPasswordChecked = setRememberPasswordChecked;
    renderRememberPassword();
    return input;
  }

  function bindLoginCapture() {
    var usernameInput = getUsernameInput();
    var passwordInput = getPasswordInput();
    var rememberPasswordInput = getRememberPasswordInput();
    var submitButton = document.querySelector('button[type="submit"]');
    bindCapture(usernameInput, 'change');
    bindCapture(passwordInput, 'change');
    bindCapture(rememberPasswordInput, 'change');
    bindCapture(submitButton, 'click');
    bindCapture(submitButton ? submitButton.closest('form') : document.querySelector('form'), 'submit');
  }

  function injectUsernameHistory() {
    var usernameInput = getUsernameInput();
    if (!usernameInput || !Array.isArray(USERNAME_HISTORY) || USERNAME_HISTORY.length === 0) return;
    var dataList = document.getElementById('flynarwhal-usernames');
    if (!dataList) {
      dataList = document.createElement('datalist');
      dataList.id = 'flynarwhal-usernames';
      document.body.appendChild(dataList);
    }
    dataList.innerHTML = '';
    USERNAME_HISTORY.forEach(function(username) {
      var option = document.createElement('option');
      option.value = username;
      dataList.appendChild(option);
    });
    usernameInput.setAttribute('list', dataList.id);
  }

  function autoFillAndSubmit() {
    var usernameInput = getUsernameInput();
    var passwordInput = getPasswordInput();
    if (!usernameInput) return false;
    if (AUTO_LOGIN_USER) triggerInput(usernameInput, AUTO_LOGIN_USER);
    if (!ALLOW_AUTO_LOGIN || !AUTO_LOGIN_USER || !AUTO_LOGIN_PASS || !passwordInput) return false;
    triggerInput(passwordInput, AUTO_LOGIN_PASS);
    if (typeof window.__setRememberPasswordChecked === 'function') {
      window.__setRememberPasswordChecked(true);
    }
    if (window.__flynarwhal_auto_submit_done) return true;
    window.__flynarwhal_auto_submit_done = true;
    setTimeout(function() {
      captureLogin();
      var submitButton = document.querySelector('button[type="submit"]');
      if (submitButton && !submitButton.disabled) submitButton.click();
    }, 500);
    return true;
  }

  function autoAuthorizeIfNeeded() {
    if (!ALLOW_AUTO_LOGIN || window.location.href.indexOf('/signin') === -1 || window.__flynarwhal_auto_authorize_done) return;
    setTimeout(function() {
      var authorizationButton = Array.prototype.find.call(document.querySelectorAll('button'), function(button) {
        return !button.disabled && (button.innerText || '').indexOf('授权') !== -1;
      });
      if (authorizationButton) {
        window.__flynarwhal_auto_authorize_done = true;
        authorizationButton.click();
      }
    }, 1000);
  }

  function sendNetworkLog(payload) {
    callNative('LogNetwork', JSON.stringify(payload));
  }

  function hookFetch() {
    if (!window.fetch || window.__flynarwhal_fetch_hooked) return;
    window.__flynarwhal_fetch_hooked = true;
    var originalFetch = window.fetch;
    window.fetch = function() {
      var request = arguments[0];
      var requestUrl = typeof request === 'string' ? request : (request && request.url) || '';
      return originalFetch.apply(this, arguments).then(function(response) {
        if (requestUrl.indexOf('/sac/rpcproxy/v1/new-user-guide/status') !== -1) {
          sendNetworkLog({ type: 'Fetch', url: requestUrl, cookie: document.cookie || '', pageUrl: window.location.href || '' });
        }
        if (requestUrl.indexOf('/oauthapi/authorize') === -1 && requestUrl.indexOf('/v/api/v1/sys/config') === -1) return response;
        response.clone().text().then(function(body) {
          var payload = { type: 'Fetch', url: requestUrl, status: response.status, body: body, cookie: document.cookie || '', pageUrl: window.location.href || '' };
          try { payload.code = String(JSON.parse(body).data.code || ''); } catch (error) {}
          sendNetworkLog(payload);
        });
        return response;
      });
    };
  }

  function hookXhr() {
    if (window.__flynarwhal_xhr_hooked) return;
    window.__flynarwhal_xhr_hooked = true;
    var originalOpen = XMLHttpRequest.prototype.open;
    var originalSend = XMLHttpRequest.prototype.send;
    XMLHttpRequest.prototype.open = function(method, url) {
      this.__flynarwhal_url = url;
      return originalOpen.apply(this, arguments);
    };
    XMLHttpRequest.prototype.send = function() {
      var request = this;
      request.addEventListener('readystatechange', function() {
        if (request.readyState !== 4) return;
        var requestUrl = request.responseURL || request.__flynarwhal_url || '';
        if (requestUrl.indexOf('/oauthapi/authorize') === -1 && requestUrl.indexOf('/v/api/v1/sys/config') === -1) return;
        var payload = { type: 'XHR', url: requestUrl, status: request.status, body: request.responseText || '', cookie: document.cookie || '', pageUrl: window.location.href || '' };
        try { payload.code = String(JSON.parse(payload.body).data.code || ''); } catch (error) {}
        sendNetworkLog(payload);
      });
      return originalSend.apply(this, arguments);
    };
  }

  function injectLoginPage() {
    hookFetch();
    hookXhr();
    if (window.location.href.indexOf('/login') !== -1) {
      ensureRememberPasswordCheckbox();
      bindLoginCapture();
      injectUsernameHistory();
      autoFillAndSubmit();
    }
    autoAuthorizeIfNeeded();
  }

  injectLoginPage();
  if (!window.__flynarwhal_injection_interval) {
    window.__flynarwhal_injection_interval = setInterval(injectLoginPage, 500);
  }
})();
''';
  }
}
