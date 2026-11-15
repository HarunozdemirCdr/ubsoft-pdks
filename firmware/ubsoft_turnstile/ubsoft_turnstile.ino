// ============================================================================
// UBSoft ESP32 Turnstile Controller — Endüstriyel Kesintisiz Sürüm v2.3.3
//
// 1. Resetsiz Elektrik Başlatma: BOD (Brownout) donanım kilitlenmesi engellendi.
// 2. Sonsuz İnternet Arama: İnternet gidince ASLA portal açmaz; modem gelene kadar arar.
// 3. WPA2 Kurulum Portalı: YALNIZCA BOOT butonuna 5 saniye basılırsa açılır.
// 4. Güvenli Eşleştirme: Kartta Tenant ID sorulmaz; eşleştirme web panelden yapılır.
// 5. TTL 10sn Komut Güvenliği: Eski komutlar asla işletilmez.
// ============================================================================

#define ENABLE_USER_AUTH
#define ENABLE_DATABASE
#include <Arduino.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <WebServer.h>
#include <DNSServer.h>
#include <Preferences.h>
#include <FirebaseClient.h>
#include <ArduinoJson.h>
#include <driver/gpio.h>
#include <esp_timer.h>
#include <time.h>
#include "soc/soc.h"
#include "soc/rtc_cntl_reg.h"
#include "trusted_roots.h"

// ───────────────────── DONANIM VE GÜVENLİ PİNLER ─────────────────────
static constexpr int PINS[8] = {26, 27, 25, 32, 33, 18, 19, 23};
static constexpr int BOOT_BTN = 0;
static constexpr int STATUS_LED = 2;

static constexpr char AP_SSID[] = "UBSoft-Turnike-Setup";
static constexpr char AP_PASS[] = "Ubs123456";

static constexpr char API_KEY[] = "AIzaSyD3fYz9iQ7RKUpJ37sG9pAnUXy1MY0hL24";
static constexpr char DB_URL[] = "https://ubsoft-pdks-turnstile.europe-west1.firebasedatabase.app";
static constexpr char REGISTER_URL[] = "https://europe-west1-ubsoft-pdks.cloudfunctions.net/registerTurnstileDevice";

Preferences prefs;
String deviceId, secret, tenantId, sessionId, ssid, password, base;
WiFiClientSecure net, streamNet;
AsyncClientClass client(net), streamClient(streamNet);
FirebaseApp firebase;
RealtimeDatabase database;
UserAuth *userAuth = nullptr;

bool initialized = false, streaming = false;
uint32_t lastStreamAt = 0, lastWifiCheck = 0, lastRegistration = 0;
bool connectionReported = false;
uint64_t lastSeq[8] = {};
esp_timer_handle_t timers[8];
volatile bool active[8] = {};
volatile uint32_t stoppedAt[8] = {};

struct Pending {
  String id, session;
  uint64_t sequence = 0;
  int relay = 0;
  int64_t expires = 0;
  bool used = false;
};
Pending pending[16];

WebServer server(80);
DNSServer dnsServer;
bool inConfigPortal = false;

String randomHex(size_t bytes) {
  String s; s.reserve(bytes * 2);
  for (size_t i = 0; i < bytes; i++) {
    char b[3]; snprintf(b, sizeof(b), "%02x", (unsigned)(esp_random() & 255));
    s += b;
  }
  return s;
}

bool safeId(const String &s) {
  if (s.isEmpty() || s.length() > 80) return false;
  for (char c : s) if (!isalnum(c) && c != '_' && c != '-') return false;
  return true;
}

int64_t nowMs() {
  struct timeval tv; gettimeofday(&tv, nullptr);
  return (int64_t)tv.tv_sec * 1000 + tv.tv_usec / 1000;
}

void off(void *arg) {
  int i = (int)(intptr_t)arg;
  gpio_set_level((gpio_num_t)PINS[i], 0);
  stoppedAt[i] = millis();
  active[i] = false;
}

void quietResult(AsyncResult &r) {
  if (r.isError()) Serial.printf("Firebase hata kodu: %d\n", r.error().code());
}

void ack(const Pending &p, const char *status) {
  JsonDocument d;
  d["status"] = status; d["relay"] = p.relay;
  d["sequence"] = p.sequence; d["sessionId"] = p.session;
  String json; serializeJson(d, json);
  database.set<object_t>(client, base + "/acks/" + p.id, object_t(json), quietResult, "ack");
}

void publishStatus(const String &requestId) {
  JsonDocument d;
  d["sessionId"] = sessionId; d["lastSeen"][".sv"] = "timestamp";
  d["firmware"] = "2.3.3"; d["mode"] = "on_demand";
  if (!requestId.isEmpty()) d["requestId"] = requestId;
  String json; serializeJson(d, json);
  database.set<object_t>(client, base + "/status", object_t(json), quietResult, "statusReply");
}

void offer(JsonObjectConst c) {
  if (c["kind"] == "probe") {
    String reqId = c["requestId"].as<String>();
    Serial.println("[DURUM] Panelden baglanti kontrol istegi (probe) alindi -> Yanitlandi!");
    publishStatus(reqId);
    return;
  }

  if (c["trigger"] != true || c["pulseMs"] != 1000) return;
  Pending p;
  p.id = c["eventId"].as<String>();
  p.session = c["sessionId"].as<String>();
  p.relay = c["relay"] | 0;
  p.sequence = c["sequence"] | uint64_t(0);
  p.expires = c["expiresAt"] | int64_t(0);

  if (!safeId(p.id) || p.relay < 1 || p.relay > 8 || !p.sequence) return;
  if (p.session != sessionId) return;
  if (p.sequence <= lastSeq[p.relay - 1]) return;

  if (nowMs() >= p.expires) {
    Serial.printf("Zaman asimi: Role=%d komut suresi dolmus.\n", p.relay);
    ack(p, "expired");
    return;
  }

  for (auto &q : pending) if (q.used && q.id == p.id) return;
  for (auto &q : pending) if (!q.used) { q = p; q.used = true; return; }
  ack(p, "rejected");
}

void streamResult(AsyncResult &r) {
  if (r.isError() || !r.available()) return;
  auto &value = r.to<RealtimeDatabaseResult>();
  if (!value.isStream() || value.event() == "keep-alive") return;
  lastStreamAt = millis();

  String payload = value.data();
  JsonDocument d;
  if (deserializeJson(d, payload)) return;

  if (tenantId.isEmpty()) {
    if (d["bound"] == true) {
      String tid = d["tenantId"].as<String>();
      if (safeId(tid) && prefs.putString("tenant", tid) > 0) {
        Serial.printf("\n[ESLESTI] Kart basariyla '%s' yurduna atandi! Kart baslatiliyor...\n", tid.c_str());
        delay(500);
        ESP.restart();
      }
    }
    return;
  }

  if (d.is<JsonObjectConst>()) {
    JsonObjectConst obj = d.as<JsonObjectConst>();
    if (obj["eventId"].is<const char *>() || obj["kind"].is<const char *>()) { offer(obj); return; }
    for (JsonPairConst entry : obj) {
      if (entry.value().is<JsonObjectConst>()) offer(entry.value().as<JsonObjectConst>());
    }
  }
}

void performFactoryReset() {
  Serial.println("\n[SIFIRLAMA] Tum NVS hafizasi siliniyor (Fabrika Ayarlari)...");
  prefs.clear();
  delay(500);
  Serial.println("[SIFIRLAMA] Kart yeniden baslatiliyor.");
  ESP.restart();
}

void startCaptivePortal() {
  inConfigPortal = true;
  WiFi.disconnect();
  WiFi.mode(WIFI_AP);
  WiFi.softAP(AP_SSID, AP_PASS);
  dnsServer.start(53, "*", WiFi.softAPIP());

  Serial.println("\n========================================");
  Serial.println(">>> KURULUM (CAPTIVE PORTAL) MODU AKTIF <<<");
  Serial.printf("Wi-Fi Agi : %s\n", AP_SSID);
  Serial.printf("Sifre     : %s\n", AP_PASS);
  Serial.printf("Portal IP : http://%s\n", WiFi.softAPIP().toString().c_str());
  Serial.printf("Kart ID   : %s\n", deviceId.c_str());
  Serial.println("========================================");

  server.on("/", HTTP_GET, []() {
    int n = WiFi.scanNetworks();
    String options = "";
    for (int i = 0; i < n; ++i) {
      options += "<option value='" + WiFi.SSID(i) + "'>" + WiFi.SSID(i) + " (" + String(WiFi.RSSI(i)) + " dBm)</option>";
    }
    String html = R"rawliteral(
      <!DOCTYPE html><html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>
      <title>UBSoft Kurulum</title>
      <style>
        *{box-sizing:border-box;margin:0;padding:0;}
        body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;background:#F8FAFC;color:#0F172A;min-height:100vh;display:flex;align-items:center;justify-content:center;padding:20px;}
        .card{background:#FFFFFF;width:100%;max-width:380px;padding:28px 24px;border-radius:20px;box-shadow:0 10px 30px -10px rgba(15,23,42,0.08);border:1px solid #E2E8F0;}
        .brand{display:flex;align-items:center;gap:10px;margin-bottom:24px;}
        .logo{width:36px;height:36px;background:#2563EB;border-radius:10px;display:flex;align-items:center;justify-content:center;color:#fff;font-weight:700;font-size:18px;}
        .title{font-size:18px;font-weight:700;color:#0F172A;line-height:1.2;}
        .subtitle{font-size:12px;color:#64748B;font-weight:500;}
        .dev-box{background:#F1F5F9;border:1px solid #E2E8F0;border-radius:14px;padding:12px 14px;margin-bottom:20px;}
        .dev-head{display:flex;align-items:center;justify-content:space-between;margin-bottom:6px;}
        .dev-tag{font-size:11px;font-weight:700;letter-spacing:0.5px;color:#64748B;}
        .dev-id{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:13px;font-weight:600;color:#1E293B;word-break:break-all;}
        .cp-btn{background:#2563EB;color:#FFFFFF;border:none;padding:5px 12px;border-radius:9999px;font-size:11px;font-weight:600;cursor:pointer;transition:all 0.15s;}
        .cp-btn.copied{background:#10B981;}
        .field{margin-bottom:16px;}
        label{display:block;font-size:13px;font-weight:600;color:#334155;margin-bottom:6px;}
        input{width:100%;height:44px;padding:0 14px;border:1px solid #CBD5E1;border-radius:12px;font-size:14px;color:#0F172A;background:#FFFFFF;outline:none;transition:border-color 0.15s,box-shadow 0.15s;}
        input:focus{border-color:#2563EB;box-shadow:0 0 0 3px rgba(37,99,235,0.12);}
        .toggle-row{display:flex;align-items:center;gap:6px;margin-top:6px;font-size:12px;color:#64748B;cursor:pointer;}
        .toggle-row input{width:auto;height:auto;}
        .submit-btn{width:100%;height:46px;background:#2563EB;color:#FFFFFF;border:none;border-radius:9999px;font-size:15px;font-weight:600;cursor:pointer;margin-top:8px;box-shadow:0 4px 12px rgba(37,99,235,0.25);transition:opacity 0.15s;}
        .submit-btn:active{opacity:0.85;}
        .reset-link{display:block;text-align:center;font-size:12px;color:#94A3B8;margin-top:20px;text-decoration:none;transition:color 0.15s;}
        .reset-link:hover{color:#EF4444;}
      </style></head><body>
      <div class='card'>
        <div class='brand'>
          <div class='logo'>U</div>
          <div>
            <div class='title'>UBSoft Turnike</div>
            <div class='subtitle'>Cihaz Kurulumu</div>
          </div>
        </div>
        <div class='dev-box'>
          <div class='dev-head'>
            <span class='dev-tag'>KART KİMLİĞİ</span>
            <button type='button' id='cpBtn' class='cp-btn' onclick='copyId()'>Kopyala</button>
          </div>
          <div class='dev-id' id='devId'>)rawliteral" + deviceId + R"rawliteral(</div>
        </div>
        <form action='/save' method='POST'>
          <div class='field'>
            <label>Wi-Fi Ağı</label>
            <input type='text' name='s' list='netList' placeholder='Ağ seçin veya yazın' required>
            <datalist id='netList'>)rawliteral" + options + R"rawliteral(</datalist>
          </div>
          <div class='field'>
            <label>Wi-Fi Şifresi</label>
            <input type='password' id='pass' name='p' placeholder='Şifre' required>
            <label class='toggle-row'><input type='checkbox' onclick='togglePass()'> Şifreyi göster</label>
          </div>
          <button type='submit' class='submit-btn'>Kaydet ve Bağlan</button>
        </form>
        <a class='reset-link' href='/reset' onclick='return confirm("Kart fabrika ayarlarına sıfırlansın mı?")'>Kartı Sıfırla</a>
      </div>
      <script>
        function copyId(){
          var id=document.getElementById('devId').innerText.trim();
          var ta=document.createElement('textarea');
          ta.value=id;ta.setAttribute('readonly','');ta.style.position='fixed';ta.style.top='-9999px';
          document.body.appendChild(ta);ta.select();ta.setSelectionRange(0,99999);
          var ok=false;try{ok=document.execCommand('copy');}catch(e){}
          document.body.removeChild(ta);
          if(!ok&&navigator.clipboard){navigator.clipboard.writeText(id).catch(function(){});}
          var b=document.getElementById('cpBtn');
          b.innerText='✓ Kopyalandı';b.classList.add('copied');
          setTimeout(function(){b.innerText='Kopyala';b.classList.remove('copied');},2000);
        }
        function togglePass(){
          var p=document.getElementById('pass');p.type=(p.type==='password')?'text':'password';
        }
      </script></body></html>
    )rawliteral";
    server.send(200, "text/html", html);
  });

  server.on("/save", HTTP_POST, []() {
    String s = server.arg("s"); s.trim();
    String p = server.arg("p"); p.trim();
    if (s.length() > 0) {
      prefs.putString("ssid", s);
      prefs.putString("wifi", p);
      server.send(200, "text/html", "<html><body style='font-family:sans-serif;text-align:center;padding:40px;background:#F9FAFB;'><h3>Bilgiler Kaydedildi!</h3><p>Kart yurdun Wi-Fi agina baglaniyor... Sayfayi kapatabilirsiniz.</p></body></html>");
      delay(1000);
      Serial.println("\n[PORTAL] Wi-Fi bilgileri kaydedildi, kart yeniden baslatiliyor...");
      ESP.restart();
    } else {
      server.send(400, "text/plain", "Gecersiz Wi-Fi bilgisi.");
    }
  });

  server.on("/reset", HTTP_GET, []() {
    server.send(200, "text/html", "<html><body style='font-family:sans-serif;text-align:center;padding:40px;'><h3>Kart Sifirlandi!</h3><p>Yeniden baslatiliyor...</p></body></html>");
    delay(1000);
    performFactoryReset();
  });

  server.onNotFound([]() {
    server.sendHeader("Location", "/", true);
    server.send(302, "text/plain", "");
  });

  server.begin();
}

void setup() {
  WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0); // Donanımsal Brownout Reset Engellendi
  Serial.begin(115200);
  pinMode(BOOT_BTN, INPUT_PULLUP);
  pinMode(STATUS_LED, OUTPUT);
  digitalWrite(STATUS_LED, LOW);

  for (int i = 0; i < 8; i++) {
    digitalWrite(PINS[i], LOW);
    pinMode(PINS[i], OUTPUT);
    esp_timer_create_args_t args = {};
    args.callback = off;
    args.arg = (void *)(intptr_t)i;
    args.name = "relayOff";
    esp_timer_create(&args, &timers[i]);
  }

  prefs.begin("ubturnstile", false);
  deviceId = prefs.getString("id", "");
  secret = prefs.getString("secret", "");

  if (deviceId.isEmpty() || secret.isEmpty()) {
    deviceId = randomHex(16);
    secret = randomHex(32);
    prefs.putString("id", deviceId);
    prefs.putString("secret", secret);
  }

  tenantId = prefs.getString("tenant", "");
  sessionId = randomHex(16);
  ssid = prefs.getString("ssid", "");
  password = prefs.getString("wifi", "");

  Serial.println("\n==================================");
  Serial.println("UBSoft Turnike Denetleyicisi v2.3.3");
  Serial.println("Kart ID   : " + deviceId);
  Serial.println("Yurt ID   : " + tenantId);
  Serial.println("==================================");

  // Sadece ilk kurulumda veya kart sıfırsa portal açılır
  if (ssid.isEmpty()) {
    startCaptivePortal();
    return;
  }

  // Normal çalışma: İnternet olmasa da portal AÇILMAZ; sonsuza kadar arar
  Serial.println("Wi-Fi baglantisi baslatiliyor: " + ssid);
  WiFi.disconnect(true);
  delay(100);
  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  WiFi.begin(ssid.c_str(), password.c_str());

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 16) {
    delay(500);
    Serial.print(".");
    digitalWrite(STATUS_LED, !digitalRead(STATUS_LED));
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWi-Fi BAGLANDI! IP: " + WiFi.localIP().toString());
    digitalWrite(STATUS_LED, HIGH);
    configTime(0, 0, "time.google.com", "pool.ntp.org");
    net.setCACert(GOOGLE_ROOTS);
    streamNet.setCACert(GOOGLE_ROOTS);
  } else {
    Serial.println("\n[BEKLEMEDE] Wi-Fi henuz hazir degil (Modem aciliyor olabilir).");
    Serial.println("Kart arka planda agi aramaya devam edecek. (Portal ACILMAZ).");
  }
}

void loop() {
  static String serialCmd;
  while (Serial.available()) {
    char c = Serial.read();
    if (c == '\n' || c == '\r') {
      serialCmd.trim();
      serialCmd.toUpperCase();
      if (serialCmd == "FACTORY_RESET" || serialCmd == "RESET") {
        performFactoryReset();
      } else if (serialCmd == "PORTAL") {
        startCaptivePortal();
      } else if (serialCmd == "ID") {
        Serial.println("Kart ID: " + deviceId);
      }
      serialCmd = "";
    } else if (serialCmd.length() < 32) {
      serialCmd += c;
    }
  }

  // 1) YALNIZCA VE YALNIZCA BOOT BUTONUNA 5 SANİYE BASILIRSA PORTAL AÇILIR
  static uint32_t btnPressTime = 0;
  if (digitalRead(BOOT_BTN) == LOW) {
    if (btnPressTime == 0) btnPressTime = millis();
    else if (millis() - btnPressTime > 5000 && !inConfigPortal) {
      Serial.println("\n[BUTON] BOOT dugmesine 5 sn basildi -> Web Kurulum Modu Aciliyor!");
      startCaptivePortal();
    }
  } else {
    btnPressTime = 0;
  }

  if (inConfigPortal) {
    dnsServer.processNextRequest();
    server.handleClient();
    digitalWrite(STATUS_LED, (millis() / 250) % 2);
    return;
  }

  // 2) KESİNTİ WATCHDOG'U: İNTERNET 2 SAAT/GÜN SONRA GELSE BİLE KENDİLİĞİNDEN BAĞLANIR (ASLA PORTAL AÇMAZ!)
  if (WiFi.status() != WL_CONNECTED) {
    digitalWrite(STATUS_LED, LOW);
    if (millis() - lastWifiCheck > 5000) {
      lastWifiCheck = millis();
      Serial.println("Wi-Fi bekleniyor... (" + ssid + ")");
      WiFi.reconnect();
    }
    delay(10);
    return;
  }

  digitalWrite(STATUS_LED, HIGH);

  static bool timeConfigured = false;
  if (!timeConfigured) {
    timeConfigured = true;
    configTime(0, 0, "time.google.com", "pool.ntp.org");
    net.setCACert(GOOGLE_ROOTS);
    streamNet.setCACert(GOOGLE_ROOTS);
  }

  if (nowMs() < 1735689600000LL) { delay(10); return; }

  // 3) CLOUD FUNCTIONS BULUT KAYDI (Gecikmesiz, Anında)
  if (!prefs.getBool("registered", false)) {
    if (lastRegistration == 0 || millis() - lastRegistration > 10000) {
      lastRegistration = millis();
      Serial.println("[BULUT] Cihaz Cloud Functions'a kaydettiriliyor...");
      WiFiClientSecure tls; tls.setCACert(GOOGLE_ROOTS); HTTPClient http;
      if (http.begin(tls, REGISTER_URL)) {
        http.setTimeout(10000); http.addHeader("Content-Type", "application/json");
        JsonDocument d; d["deviceId"] = deviceId; d["deviceSecret"] = secret; d["hardwareId"] = WiFi.macAddress();
        String b; serializeJson(d, b);
        int code = http.POST(b);
        String resp = http.getString();
        http.end();
        Serial.printf("[BULUT] Kayit Yaniti: HTTP %d (%s)\n", code, resp.c_str());
        if (code == 200) {
          prefs.putBool("registered", true);
          Serial.println("[BULUT] Cihaz basariyla kaydoldu! Artik web panelden eslestirilebilir.");
        }
      }
    }
    return;
  }

  // 4) FIREBASE BAĞLANTISI VE AKIŞ
  if (!initialized) {
    String email = deviceId + "@turnstile.invalid";
    userAuth = new UserAuth(API_KEY, email, secret, 3000);
    initializeApp(client, firebase, getAuth(*userAuth), quietResult, "auth");
    firebase.getApp<RealtimeDatabase>(database);
    database.url(DB_URL);
    initialized = true;
  }

  firebase.loop();
  if (!firebase.ready()) return;

  if (!connectionReported) {
    connectionReported = true;
    Serial.printf("Firebase Baglandi. UTC_ms=%lld RAM=%u\n", (long long)nowMs(), ESP.getFreeHeap());
    if (tenantId.isEmpty()) {
      Serial.println("\n****************************************************************");
      Serial.println(">>> TEBRIKLER! KART INTERNETE VE BULUTA BAGLANDI <<<");
      Serial.println("KART KIMLIGI : " + deviceId);
      Serial.println("DURUM        : Yurt Eslemesi Bekleniyor");
      Serial.println("YAPILACAK    : https://ubsoft-pdks.web.app adresine mudire olarak girin,");
      Serial.println("               'Turnike Karti' sekmesine bu Kart Kimligini yapistirip");
      Serial.println("               'Bu yurda bagla' butonuna tiklayin.");
      Serial.println("****************************************************************\n");
    }
  }

  if (!streaming) {
    base = "/turnstiles/" + tenantId + "/" + deviceId;
    database.get(streamClient, tenantId.isEmpty() ? "/bindings/" + deviceId : base + "/control/commands", streamResult, true, "stream");
    streaming = true;
    if (!tenantId.isEmpty()) {
      Serial.println("[BULUT] Cihaz durumu yayinlaniyor (Cevrimici)...");
      publishStatus("");
    }
  }

  if (tenantId.isEmpty()) return;

  // 5) RÖLE TETİKLEME (Sıralı ve Güvenli 1000ms Darbe)
  for (int i = 0; i < 8; i++) {
    if (active[i] || uint32_t(millis() - stoppedAt[i]) < 200) continue;
    Pending *next = nullptr;
    for (auto &p : pending) if (p.used && p.relay == i + 1 && (!next || p.sequence < next->sequence)) next = &p;
    if (!next) continue;
    Pending p = *next;
    next->used = false;

    if (p.sequence <= lastSeq[i]) continue;
    if (nowMs() >= p.expires) { ack(p, "expired"); continue; }

    lastSeq[i] = p.sequence;
    active[i] = true;
    if (esp_timer_start_once(timers[i], 1000000) != ESP_OK) {
      active[i] = false; ack(p, "rejected"); continue;
    }
    gpio_set_level((gpio_num_t)PINS[i], 1);
    Serial.printf("ROLE TETIKLENDI: Role=%d (GPIO %d) Sure=1000ms\n", i + 1, PINS[i]);
    ack(p, "pulse_started");
  }

  delay(2);
}