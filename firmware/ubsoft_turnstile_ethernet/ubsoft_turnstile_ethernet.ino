// ============================================================================
// UBSoft ESP32 Turnstile Controller — Dahili ESP32 W5500 Ethernet Sürümü v2.4.0-eth
//
// 1. Wi-Fi Tamamen Devre Dışı: Yalnızca W5500 (HanRun HR911105A) Kablolu Ethernet.
// 2. ESP32 Core 3.x Dahili ETH.h + NetworkClientSecure (mbedTLS):
//    - Harici Ethernet.h / ESP_SSLClient (BearSSL) kullanmaz -> eski kod gibi hızla derlenir.
// 3. Otomatik Modem Bağlantısı (DHCP) + Kablo Kopma/Takılma Kurtarma.
// 4. Donanım Pinleri: 8 Röle {27,26,25,32,14,12,13,15}, LED GPIO 4, W5500 RST GPIO 17.
// ============================================================================

#define ENABLE_USER_AUTH
#define ENABLE_DATABASE

#include <Arduino.h>
#include <ETH.h>
#include <NetworkClientSecure.h>
#include <HTTPClient.h>
#include <FirebaseClient.h>
#include <ArduinoJson.h>
#include <Preferences.h>
#include <driver/gpio.h>
#include <esp_timer.h>
#include <time.h>
#include "soc/soc.h"
#include "soc/rtc_cntl_reg.h"
#include "trusted_roots.h"

// ───────────────────── DONANIM VE GÜVENLİ PİNLER ─────────────────────
// W5500 (HanRun HR911105A) SPI Pinleri
static constexpr int ETH_SCK_PIN  = 18;
static constexpr int ETH_MISO_PIN = 19;
static constexpr int ETH_MOSI_PIN = 23;
static constexpr int ETH_CS_PIN   = 5;
static constexpr int ETH_RST_PIN  = 17; // GPIO 4 LED olduğu için W5500 RST pini GPIO 17'ye taşındı
static constexpr int ETH_IRQ_PIN  = -1; // INT pini bağlı değil (polling modu)

// 8 Röle Pinleri (Donanım PCB pin haritasına göre)
static constexpr int PINS[8] = {27, 26, 25, 32, 14, 12, 13, 15};
#define RELAY_ON_LEVEL  1
#define RELAY_OFF_LEVEL 0

static constexpr int BOOT_BTN   = 0;
static constexpr int STATUS_LED = 4; // Harici büyük durum LED'i (GPIO 4)

// ───────────────────── FIREBASE / BULUT AYARLARI ─────────────────────
static constexpr char API_KEY[]      = "AIzaSyD3fYz9iQ7RKUpJ37sG9pAnUXy1MY0hL24";
static constexpr char DB_URL[]       = "https://ubsoft-pdks-turnstile.europe-west1.firebasedatabase.app";
static constexpr char REGISTER_URL[] = "https://europe-west1-ubsoft-pdks.cloudfunctions.net/registerTurnstileDevice";

// ───────────────────── AĞ VE FİREBASE NESNELERİ ─────────────────────
Preferences prefs;
String deviceId, secret, tenantId, sessionId, base;

NetworkClientSecure net, streamNet;
AsyncClientClass client(net), streamClient(streamNet);
FirebaseApp firebase;
RealtimeDatabase database;
UserAuth *userAuth = nullptr;

volatile bool ethGotIp = false;
bool timeConfigured = false;
bool initialized = false;
bool streaming = false;
bool connectionReported = false;

uint32_t lastEthWaitLog = 0;
uint32_t lastRegistration = 0;
uint32_t lastStreamAt = 0;

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

// ───────────────────── ETHERNET OLAY YÖNETİCİSİ ─────────────────────
void onEthEvent(arduino_event_id_t event, arduino_event_info_t info) {
  switch (event) {
    case ARDUINO_EVENT_ETH_START:
      Serial.println("[ETH] W5500 baslatildi.");
      ETH.setHostname("ubsoft-turnstile");
      break;
    case ARDUINO_EVENT_ETH_CONNECTED:
      Serial.println("[ETH] Kablo baglandi (Link UP), modemden IP bekleniyor...");
      break;
    case ARDUINO_EVENT_ETH_GOT_IP:
      Serial.print("[ETH] IP Alindi: ");
      Serial.println(ETH.localIP());
      ethGotIp = true;
      break;
    case ARDUINO_EVENT_ETH_LOST_IP:
      Serial.println("[ETH UYARI] IP kaybedildi.");
      ethGotIp = false;
      streaming = false;
      connectionReported = false;
      break;
    case ARDUINO_EVENT_ETH_DISCONNECTED:
      Serial.println("[ETH UYARI] Ethernet kablosu cikarildi!");
      ethGotIp = false;
      streaming = false;
      connectionReported = false;
      break;
    case ARDUINO_EVENT_ETH_STOP:
      ethGotIp = false;
      streaming = false;
      connectionReported = false;
      break;
    default:
      break;
  }
}

// ───────────────────── YARDIMCI FONKSİYONLAR ─────────────────────
String randomHex(size_t bytes) {
  String s; s.reserve(bytes * 2);
  for (size_t i = 0; i < bytes; i++) {
    char b[3];
    snprintf(b, sizeof(b), "%02x", (unsigned)(esp_random() & 255));
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
  struct timeval tv;
  gettimeofday(&tv, nullptr);
  return (int64_t)tv.tv_sec * 1000LL + tv.tv_usec / 1000LL;
}

void off(void *arg) {
  int i = (int)(intptr_t)arg;
  gpio_set_level((gpio_num_t)PINS[i], RELAY_OFF_LEVEL);
  stoppedAt[i] = millis();
  active[i] = false;
}

void quietResult(AsyncResult &r) {
  if (r.isError()) {
    Serial.printf("[FIREBASE HATA] %s (kod: %d)\n", r.error().message().c_str(), r.error().code());
  }
}

void ack(const Pending &p, const char *status) {
  JsonDocument d;
  d["status"] = status;
  d["relay"] = p.relay;
  d["sequence"] = p.sequence;
  d["sessionId"] = p.session;
  String json;
  serializeJson(d, json);
  database.set<object_t>(client, base + "/acks/" + p.id, object_t(json), quietResult, "ack");
}

void publishStatus(const String &requestId) {
  JsonDocument d;
  d["sessionId"] = sessionId;
  d["lastSeen"][".sv"] = "timestamp";
  d["firmware"] = "2.4.0-eth";
  d["mode"] = "on_demand";
  if (!requestId.isEmpty()) d["requestId"] = requestId;
  String json;
  serializeJson(d, json);
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
    Serial.printf("[ZAMAN ASIMI] Role=%d komut suresi dolmus.\n", p.relay);
    ack(p, "expired");
    return;
  }

  for (auto &q : pending) if (q.used && q.id == p.id) return;
  for (auto &q : pending) if (!q.used) { q = p; q.used = true; return; }
  ack(p, "rejected");
}

void streamResult(AsyncResult &r) {
  if (r.isError()) {
    Serial.printf("[STREAM HATA] %s (kod: %d)\n", r.error().message().c_str(), r.error().code());
    return;
  }
  if (!r.available()) return;

  auto &value = r.to<RealtimeDatabaseResult>();
  if (!value.isStream()) return;
  lastStreamAt = millis();
  if (value.event() == "keep-alive") return;

  String payload = value.data();
  JsonDocument d;
  if (deserializeJson(d, payload)) return;

  if (tenantId.isEmpty()) {
    if (d["bound"] == true) {
      String tid = d["tenantId"].as<String>();
      if (safeId(tid) && prefs.putString("tenant", tid) > 0) {
        Serial.printf("\n[ESLESTI] Kart basariyla '%s' yurduna atandi! Kart yeniden baslatiliyor...\n", tid.c_str());
        delay(500);
        ESP.restart();
      }
    }
    return;
  }

  if (d.is<JsonObjectConst>()) {
    JsonObjectConst obj = d.as<JsonObjectConst>();
    if (obj["eventId"].is<const char *>() || obj["kind"].is<const char *>()) {
      offer(obj);
      return;
    }
    for (JsonPairConst entry : obj) {
      if (entry.value().is<JsonObjectConst>()) {
        offer(entry.value().as<JsonObjectConst>());
      }
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

// ───────────────────── SETUP ─────────────────────
void setup() {
  WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0);
  Serial.begin(115200);
  delay(300);

  pinMode(BOOT_BTN, INPUT_PULLUP);
  pinMode(STATUS_LED, OUTPUT);
  digitalWrite(STATUS_LED, LOW);

  for (int i = 0; i < 8; i++) {
    digitalWrite(PINS[i], RELAY_OFF_LEVEL);
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

  Serial.println("\n================================================");
  Serial.println("UBSoft Turnike Denetleyicisi v2.4.0 (W5500 ETH)");
  Serial.println("Kart ID : " + deviceId);
  Serial.println("Yurt ID : " + (tenantId.isEmpty() ? String("(Henuz eslenmedi)") : tenantId));
  Serial.println("================================================");

  Network.onEvent(onEthEvent);
  if (!ETH.begin(ETH_PHY_W5500, 1, ETH_CS_PIN, ETH_IRQ_PIN, ETH_RST_PIN,
                 SPI2_HOST, ETH_SCK_PIN, ETH_MISO_PIN, ETH_MOSI_PIN)) {
    Serial.println("[ETH HATA] W5500 baslatilamadi! Pinleri (18,19,23,5,17) kontrol edin.");
  }
}

// ───────────────────── LOOP ─────────────────────
void loop() {
  // Seri Port komutları
  static String serialCmd;
  while (Serial.available()) {
    char c = Serial.read();
    if (c == '\n' || c == '\r') {
      serialCmd.trim();
      serialCmd.toUpperCase();
      if (serialCmd == "FACTORY_RESET" || serialCmd == "RESET") {
        performFactoryReset();
      } else if (serialCmd == "ID") {
        Serial.println("Kart ID: " + deviceId);
      } else if (serialCmd == "STATUS") {
        Serial.printf("ETH=%d Link=%d IP=%s Time=%lld Reg=%d Init=%d Stream=%d Tenant=%s\n",
                      ethGotIp, ETH.linkUp(), ETH.localIP().toString().c_str(),
                      (long long)nowMs(), prefs.getBool("registered", false),
                      initialized, streaming, tenantId.c_str());
      }
      serialCmd = "";
    } else if (serialCmd.length() < 32) {
      serialCmd += c;
    }
  }

  // BOOT butonuna 5 sn basılı tutulursa fabrika ayarlarına sıfırla
  static uint32_t btnPressTime = 0;
  if (digitalRead(BOOT_BTN) == LOW) {
    if (btnPressTime == 0) btnPressTime = millis();
    else if (millis() - btnPressTime > 5000) {
      Serial.println("\n[BUTON] BOOT dugmesine 5 sn basildi -> Fabrika Ayarlarina Sifirlaniyor!");
      performFactoryReset();
    }
  } else {
    btnPressTime = 0;
  }

  // 1) ETHERNET BAĞLANTI BEKLEME (Wi-Fi yok, kablo gelene kadar bekler)
  if (!ethGotIp || !ETH.hasIP()) {
    digitalWrite(STATUS_LED, LOW);
    if (millis() - lastEthWaitLog > 5000) {
      lastEthWaitLog = millis();
      Serial.println("[ETH] Ethernet baglantisi / modemden IP bekleniyor...");
    }
    delay(10);
    return;
  }

  digitalWrite(STATUS_LED, HIGH);

  // 2) ZAMAN SENKRONİZASYONU (Dahili lwIP SNTP)
  if (!timeConfigured) {
    timeConfigured = true;
    configTime(0, 0, "time.google.com", "pool.ntp.org");
    net.setCACert(GOOGLE_ROOTS);
    streamNet.setCACert(GOOGLE_ROOTS);
  }

  if (nowMs() < 1735689600000LL) {
    delay(10);
    return;
  }

  // 3) CLOUD FUNCTIONS BULUT KAYDI
  if (!prefs.getBool("registered", false)) {
    if (lastRegistration == 0 || millis() - lastRegistration > 10000) {
      lastRegistration = millis();
      Serial.println("[BULUT] Cihaz Ethernet uzerinden Cloud Functions'a kaydettiriliyor...");
      NetworkClientSecure tls;
      tls.setCACert(GOOGLE_ROOTS);
      HTTPClient http;
      if (http.begin(tls, REGISTER_URL)) {
        http.setTimeout(10000);
        http.addHeader("Content-Type", "application/json");
        JsonDocument d;
        d["deviceId"] = deviceId;
        d["deviceSecret"] = secret;
        d["hardwareId"] = ETH.macAddress();
        String b;
        serializeJson(d, b);
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
    Serial.printf("[FIREBASE] Baglandi! IP=%s UTC_ms=%lld RAM=%u\n",
                  ETH.localIP().toString().c_str(), (long long)nowMs(), ESP.getFreeHeap());
    if (tenantId.isEmpty()) {
      Serial.println("\n****************************************************************");
      Serial.println(">>> TEBRIKLER! KART ETHERNET ILE BULUTA BAGLANDI <<<");
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
    lastStreamAt = millis();
    if (!tenantId.isEmpty()) {
      Serial.println("[BULUT] Cihaz durumu yayinlaniyor (Cevrimici - Ethernet)...");
      publishStatus("");
    }
  }

  // 120 sn içinde keep-alive/veri gelmezse stream'i tazele
  if (streaming && millis() - lastStreamAt > 120000UL) {
    Serial.println("[STREAM UYARI] Zaman asimi, stream yenileniyor...");
    streamNet.stop();
    streaming = false;
  }

  if (tenantId.isEmpty()) return;

  // 5) RÖLE TETİKLEME (Sıralı ve Güvenli 1000ms Darbe)
  for (int i = 0; i < 8; i++) {
    if (active[i] || uint32_t(millis() - stoppedAt[i]) < 200) continue;
    Pending *next = nullptr;
    for (auto &p : pending) {
      if (p.used && p.relay == i + 1 && (!next || p.sequence < next->sequence)) next = &p;
    }
    if (!next) continue;

    Pending p = *next;
    next->used = false;

    if (p.sequence <= lastSeq[i]) continue;
    if (nowMs() >= p.expires) { ack(p, "expired"); continue; }

    lastSeq[i] = p.sequence;
    active[i] = true;
    if (esp_timer_start_once(timers[i], 1000000) != ESP_OK) {
      active[i] = false;
      ack(p, "rejected");
      continue;
    }
    gpio_set_level((gpio_num_t)PINS[i], RELAY_ON_LEVEL);
    Serial.printf("ROLE TETIKLENDI: Role=%d (GPIO %d) Sure=1000ms\n", i + 1, PINS[i]);
    ack(p, "pulse_started");
  }

  delay(2);
}
