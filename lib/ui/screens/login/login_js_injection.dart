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

  // Build JS payload for login autofill and bridge capture
  String build() {
    return '''
(function() {
  var AUTO_LOGIN_USER = $autoLoginUsernameLiteral;
  var AUTO_LOGIN_PASS = $autoLoginPasswordLiteral;
  var ALLOW_AUTO_LOGIN = $allowAutoLogin;
  var USERNAME_HISTORY = $usernameHistoryJsonLiteral || [];
  function callNative(method, params) {
    try {
      if (window.kmpJsBridge && typeof window.kmpJsBridge.callNative === 'function') {
        window.kmpJsBridge.callNative(method, params || '');
        return;
      }
    } catch (e) {}
    try {
      var url = '#flynarwhal_bridge?method=' + encodeURIComponent(method) + '&params=' + encodeURIComponent(params || '');
      window.location.hash = url;
      window.history.replaceState('', document.title, window.location.pathname + window.location.search);
    } catch (e) {}
  }
  // Find login inputs by common selectors
  function queryInput(selectorList) {
    for (var i = 0; i < selectorList.length; i++) {
      var input = document.querySelector(selectorList[i]);
      if (input) return input;
    }
    return null;
  }
  function getUsernameInput() {
    return queryInput(['input#username','input[name="username"]','input[name="account"]','input[type="email"]','input[type="text"]']);
  }
  function getPasswordInput() {
    return queryInput(['input#password','input[name="password"]','input[type="password"]']);
  }
  function getRememberCheckbox() {
    return queryInput(['input#remember-password','input[name*="remember"]','input[type="checkbox"]']);
  }
  // Apply input value and fire events
  function setInputValue(input, value) {
    if (!input) return;
    input.focus();
    input.value = value;
    input.dispatchEvent(new Event('input', { bubbles: true }));
    input.dispatchEvent(new Event('change', { bubbles: true }));
  }
  function ensureRememberChecked() {
    var checkbox = getRememberCheckbox();
    if (checkbox && !checkbox.checked) {
      checkbox.checked = true;
      checkbox.dispatchEvent(new Event('input', { bubbles: true }));
      checkbox.dispatchEvent(new Event('change', { bubbles: true }));
    }
  }
  // Capture login payload for native side
  function captureLogin() {
    var usernameInput = getUsernameInput();
    var passwordInput = getPasswordInput();
    var checkbox = getRememberCheckbox();
    var payload = {
      username: usernameInput ? usernameInput.value || '' : '',
      password: passwordInput ? passwordInput.value || '' : '',
      rememberPassword: checkbox ? checkbox.checked === true : false
    };
    callNative('CaptureLoginInfo', JSON.stringify(payload));
  }
  function bindSubmit() {
    var form = document.querySelector('form');
    if (!form) return;
    if (form.__flynarwhalBound) return;
    form.__flynarwhalBound = true;
    form.addEventListener('submit', function() { captureLogin(); });
  }
  // Inject username history into datalist
  function injectUsernameHistory() {
    if (!Array.isArray(USERNAME_HISTORY) || USERNAME_HISTORY.length === 0) return;
    var input = getUsernameInput();
    if (!input) return;
    var dataListId = 'flynarwhal_usernames';
    var existing = document.getElementById(dataListId);
    if (!existing) {
      existing = document.createElement('datalist');
      existing.id = dataListId;
      document.body.appendChild(existing);
    }
    existing.innerHTML = '';
    USERNAME_HISTORY.forEach(function(name) {
      var option = document.createElement('option');
      option.value = name;
      existing.appendChild(option);
    });
    input.setAttribute('list', dataListId);
  }
  // Autofill and optionally submit form
  function autoFill() {
    var user = AUTO_LOGIN_USER;
    var pass = AUTO_LOGIN_PASS;
    if (user && user.length > 0) {
      setInputValue(getUsernameInput(), user);
    }
    if (pass && pass.length > 0) {
      setInputValue(getPasswordInput(), pass);
    }
    if (ALLOW_AUTO_LOGIN && user && user.length > 0 && pass && pass.length > 0) {
      ensureRememberChecked();
      var form = document.querySelector('form');
      if (form) {
        form.submit();
      }
    }
  }
  function injectUI() {
    if (window.location.href.indexOf('/login') === -1) return;
    ensureRememberPasswordCheckbox();
    bindSubmit();
    injectUsernameHistory();
    if (!window.__flynarwhal_autofill_done) {
      window.__flynarwhal_autofill_done = true;
      setTimeout(autoFill, 400);
    }
    var usernameInput = getUsernameInput();
    if (usernameInput && !usernameInput.__flynarwhalBound) {
      usernameInput.__flynarwhalBound = true;
      usernameInput.addEventListener('change', function() { captureLogin(); });
    }
    var passwordInput = getPasswordInput();
    if (passwordInput && !passwordInput.__flynarwhalBound) {
      passwordInput.__flynarwhalBound = true;
      passwordInput.addEventListener('change', function() { captureLogin(); });
    }
    var checkbox = getRememberCheckbox();
    if (checkbox && !checkbox.__flynarwhalBound) {
      checkbox.__flynarwhalBound = true;
      checkbox.addEventListener('change', function() { captureLogin(); });
    }
  }
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
      for (var j = 0; j < allDivs.length; j++) {
        if (allDivs[j].innerText === '忘记密码？') {
          leftContainer = allDivs[j].parentElement;
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
      input.dispatchEvent(new Event('input', { bubbles: true }));
      input.dispatchEvent(new Event('change', { bubbles: true }));
      renderRemember();
    });
    wrapper.appendChild(input);
    wrapper.appendChild(box);
    wrapper.appendChild(label);
    leftContainer.insertBefore(wrapper, leftContainer.firstChild);
    window.__setRememberPasswordChecked = function(checked) {
      input.checked = !!checked;
      input.dispatchEvent(new Event('input', { bubbles: true }));
      input.dispatchEvent(new Event('change', { bubbles: true }));
      renderRemember();
    };
    renderRemember();
  }
  function hookFetch() {
    if (!window.fetch) return;
    var originalFetch = window.fetch;
    window.fetch = function() {
      var input = arguments[0];
      var init = arguments[1];
      var url = input;
      if (typeof input === 'object' && input.url) {
        url = input.url;
      }
      return originalFetch.apply(this, arguments).then(function(response) {
        try {
          if (url && url.indexOf('/sac/rpcproxy/v1/new-user-guide/status') !== -1) {
            var payload = {
              type: 'Fetch',
              url: url,
              headers: {},
              cookie: document.cookie || '',
              pageUrl: window.location.href || ''
            };
            if (init && init.headers) {
              var h = init.headers;
              if (h instanceof Headers) {
                h.forEach(function(value, key) { payload.headers[key] = value; });
              } else {
                for (var key in h) {
                  if (h.hasOwnProperty(key)) payload.headers[key] = h[key];
                }
              }
            }
            callNative('LogNetwork', JSON.stringify(payload));
          }
          if (url && url.indexOf('/oauthapi/authorize') !== -1) {
            var cloned = response.clone();
            cloned.text().then(function(body) {
              var payload = {
                type: 'Fetch',
                url: url,
                status: response.status,
                headers: {},
                body: body,
                cookie: document.cookie || '',
                pageUrl: window.location.href || ''
              };
              response.headers.forEach(function(value, key) { payload.headers[key] = value; });
              try {
                var json = JSON.parse(body || '{}');
                if (json && json.data && json.data.code) {
                  payload.code = String(json.data.code);
                }
              } catch (e) {}
              callNative('LogNetwork', JSON.stringify(payload));
            });
          }
        } catch (e) {}
        return response;
      });
    };
  }
  function hookXhr() {
    var originalOpen = XMLHttpRequest.prototype.open;
    var originalSend = XMLHttpRequest.prototype.send;
    XMLHttpRequest.prototype.open = function(method, url) {
      this.__flynarwhalUrl = url;
      return originalOpen.apply(this, arguments);
    };
    XMLHttpRequest.prototype.send = function() {
      var xhr = this;
      var onReady = function() {
        if (xhr.readyState === 4) {
          var url = xhr.responseURL || xhr.__flynarwhalUrl || '';
          if (url.indexOf('/oauthapi/authorize') !== -1) {
            var payload = {
              type: 'XHR',
              url: url,
              status: xhr.status,
              headers: xhr.getAllResponseHeaders(),
              body: xhr.responseText,
              cookie: document.cookie || '',
              pageUrl: window.location.href || ''
            };
            try {
              var json = JSON.parse(xhr.responseText || '{}');
              if (json && json.data && json.data.code) {
                payload.code = String(json.data.code);
              }
            } catch (e) {}
            callNative('LogNetwork', JSON.stringify(payload));
          }
          if (url.indexOf('/v/api/v1/sys/config') !== -1) {
            var configPayload = {
              type: 'XHR',
              url: url,
              status: xhr.status,
              headers: xhr.getAllResponseHeaders(),
              body: xhr.responseText,
              cookie: document.cookie || '',
              pageUrl: window.location.href || ''
            };
            callNative('LogNetwork', JSON.stringify(configPayload));
          }
        }
      };
      if (!xhr.__flynarwhalBound) {
        xhr.__flynarwhalBound = true;
        xhr.addEventListener('readystatechange', onReady);
      }
      var openUrl = xhr.__flynarwhalUrl || '';
      if (openUrl.indexOf('/sac/rpcproxy/v1/new-user-guide/status') !== -1) {
        var statusPayload = {
          type: 'XHR',
          url: openUrl,
          headers: xhr.__flynarwhalHeaders || {},
          cookie: document.cookie || '',
          pageUrl: window.location.href || ''
        };
        callNative('LogNetwork', JSON.stringify(statusPayload));
      }
      return originalSend.apply(this, arguments);
    };
    var originalSetRequestHeader = XMLHttpRequest.prototype.setRequestHeader;
    XMLHttpRequest.prototype.setRequestHeader = function(header, value) {
      if (!this.__flynarwhalHeaders) this.__flynarwhalHeaders = {};
      this.__flynarwhalHeaders[header] = value;
      return originalSetRequestHeader.apply(this, arguments);
    };
  }
  function fetchSysConfigOnce() {
    try {
      if (window.__flynarwhal_sys_config_requested) return;
      if (window.location.href.indexOf('/login') !== -1) return;
      window.__flynarwhal_sys_config_requested = true;
      fetch('/v/api/v1/sys/config', { credentials: 'include' })
        .then(function(r) { return r.text(); })
        .then(function(text) {
          var payload = {
            type: 'SysConfig',
            url: '/v/api/v1/sys/config',
            body: text || '',
            cookie: document.cookie || '',
            pageUrl: window.location.href || ''
          };
          callNative('LogNetwork', JSON.stringify(payload));
        })
        .catch(function() {
          window.__flynarwhal_sys_config_requested = false;
        });
    } catch (e) {
      window.__flynarwhal_sys_config_requested = false;
    }
  }
  function autoAuthorizeIfNeeded() {
    if (!ALLOW_AUTO_LOGIN) return;
    if (window.location.href.indexOf('/signin') === -1) return;
    if (window.__flynarwhal_auto_auth_done) return;
    window.__flynarwhal_auto_auth_done = true;
    setTimeout(function() {
      var btns = document.querySelectorAll('button');
      for (var i = 0; i < btns.length; i++) {
        if ((btns[i].innerText || '').indexOf('授权') !== -1) {
          btns[i].click();
          break;
        }
      }
    }, 800);
  }
  hookFetch();
  hookXhr();
  injectUI();
  setInterval(injectUI, 500);
  setTimeout(fetchSysConfigOnce, 800);
  autoAuthorizeIfNeeded();
})();
''';
  }
}
