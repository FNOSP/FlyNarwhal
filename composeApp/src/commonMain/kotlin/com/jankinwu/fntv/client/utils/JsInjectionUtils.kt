package com.jankinwu.fntv.client.utils

fun getJsInjectionScript(
    autoLoginUsername: String?,
    autoLoginPassword: String?,
    allowAutoLogin: Boolean,
    usernameHistoryJs: String
): String {
    return """
        (function() {
            console.log("Injecting Network Interceptor...");
            
            var AUTO_LOGIN_USER = "${autoLoginUsername ?: ""}";
            var AUTO_LOGIN_PASS = "${autoLoginPassword ?: ""}";
            var ALLOW_AUTO_LOGIN = ${allowAutoLogin};
            var USERNAME_HISTORY = $usernameHistoryJs;
            
            function callNative(method, params) {
                try {
                    if (window.kmpJsBridge && typeof window.kmpJsBridge.callNative === 'function') {
                        window.kmpJsBridge.callNative(method, params);
                    }
                } catch (e) {}
            }

            function logToNative(payload) {
                try {
                    payload = payload || {};
                    payload.cookie = document.cookie;
                    callNative("LogNetwork", JSON.stringify(payload));
                } catch (e) {}
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

                         callNative("CaptureLoginInfo", JSON.stringify({
                             username: u,
                             password: p,
                             rememberPassword: r
                         }));
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
                            try {
                                var json = JSON.parse(self.responseText || "{}");
                                var code = json && json.data ? json.data.code : null;
                                if (code) {
                                    logToNative({ type: "Response", url: self._url, code: String(code) });
                                } else {
                                    logToNative({ type: "Response", url: self._url, body: self.responseText || "" });
                                }
                            } catch (e) {
                                logToNative({ type: "Response", url: self._url, body: self.responseText || "" });
                            }
                        }
                    }
                    if (originalOnReadyStateChange) {
                        originalOnReadyStateChange.apply(this, arguments);
                    }
                }
                
                if (this._url && this._url.indexOf("/sac/rpcproxy/v1/new-user-guide/status") !== -1) {
                    logToNative({ type: "XHR", url: this._url, headers: (this._headers || {}) });
                }
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
                
                if (url && url.indexOf("/sac/rpcproxy/v1/new-user-guide/status") !== -1) {
                    logToNative({ type: "XHR", url: url, headers: headers });
                }
                
                return originalFetch.apply(this, arguments).then(function(response) {
                    if (url && url.indexOf("/oauthapi/authorize") !== -1) {
                        var clone = response.clone();
                        clone.text().then(function(text) {
                             try {
                                 var json = JSON.parse(text || "{}");
                                 var code = json && json.data ? json.data.code : null;
                                 if (code) {
                                     logToNative({ type: "Response", url: url, code: String(code) });
                                 } else {
                                     logToNative({ type: "Response", url: url, body: text || "" });
                                 }
                             } catch (e) {
                                 logToNative({ type: "Response", url: url, body: text || "" });
                             }
                        });
                    }
                    return response;
                });
            };

            function fetchSysConfigOnce() {
                try {
                    if (window.__flynarwhal_sys_config_requested) return;
                    if (window.location.href.indexOf('/login') !== -1) return;
                    window.__flynarwhal_sys_config_requested = true;
                    fetch('/v/api/v1/sys/config', { credentials: 'include' })
                        .then(function(r) { return r.text(); })
                        .then(function(text) {
                            logToNative({
                                type: "SysConfig",
                                url: "/v/api/v1/sys/config",
                                body: text || "",
                                pageUrl: String(window.location.href || "")
                            });
                        })
                        .catch(function() {
                            window.__flynarwhal_sys_config_requested = false;
                        });
                } catch (e) {
                    window.__flynarwhal_sys_config_requested = false;
                }
            }

            setTimeout(fetchSysConfigOnce, 800);
            console.log("Network Interceptor Injected Successfully.");
        })();
    """.trimIndent()
}
