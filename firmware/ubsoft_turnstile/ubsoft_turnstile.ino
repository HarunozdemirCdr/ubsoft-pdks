// UBSoft ESP32-WROOM, 8 active-HIGH relays. Arduino ESP32 core 3.3.12.
#define ENABLE_USER_AUTH
#define ENABLE_DATABASE
#include <Arduino.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <Preferences.h>
#include <FirebaseClient.h>
#include <ArduinoJson.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLESecurity.h>
#include <driver/gpio.h>
#include <esp_timer.h>
#include <esp_bt.h>
#include <bootloader_random.h>
#include <time.h>
#include "trusted_roots.h"

static constexpr int PINS[8]={26,27,25,32,14,12,13,15};
static constexpr char API_KEY[]="AIzaSyD3fYz9iQ7RKUpJ37sG9pAnUXy1MY0hL24";
static constexpr char DB_URL[]="https://ubsoft-pdks-turnstile.europe-west1.firebasedatabase.app";
static constexpr char REGISTER_URL[]="https://europe-west1-ubsoft-pdks.cloudfunctions.net/registerTurnstileDevice";
static constexpr char SERVICE_UUID[]="87df1000-1677-4e78-99d1-224e0c852200";
static constexpr char ID_UUID[]="87df1001-1677-4e78-99d1-224e0c852200";
static constexpr char SSID_UUID[]="87df1002-1677-4e78-99d1-224e0c852200";
static constexpr char PASSWORD_UUID[]="87df1003-1677-4e78-99d1-224e0c852200";
static constexpr char SAVE_UUID[]="87df1004-1677-4e78-99d1-224e0c852200";
Preferences prefs;
String deviceId,secret,tenantId,sessionId,ssid,password,base;
WiFiClientSecure net,streamNet;
AsyncClientClass client(net),streamClient(streamNet);
FirebaseApp firebase;
RealtimeDatabase database;
UserAuth *userAuth=nullptr;
bool initialized=false,streaming=false,wasConnected=false;
uint32_t lastHeartbeat=0,lastRegistration=0,lastStreamAt=0;
bool connectionReported=false;
uint64_t lastSeq[8]={};
esp_timer_handle_t timers[8];
volatile bool active[8]={};
volatile uint32_t stoppedAt[8]={};
struct Pending {String id,session;uint64_t sequence=0;int relay=0;int64_t expires=0;bool used=false;};
Pending pending[16];
BLECharacteristic *ssidChar=nullptr,*passwordChar=nullptr;
volatile bool saveWifi=false;
String randomHex(size_t bytes){String s;s.reserve(bytes*2);for(size_t i=0;i<bytes;i++){char b[3];snprintf(b,sizeof(b),"%02x",(unsigned)(esp_random()&255));s+=b;}return s;}
bool safeId(const String &s){if(s.isEmpty()||s.length()>80)return false;for(char c:s)if(!isalnum(c)&&c!='_'&&c!='-')return false;return true;}
int64_t nowMs(){struct timeval tv;gettimeofday(&tv,nullptr);return(int64_t)tv.tv_sec*1000+tv.tv_usec/1000;}
void off(void *arg){int i=(int)(intptr_t)arg;gpio_set_level((gpio_num_t)PINS[i],0);stoppedAt[i]=millis();active[i]=false;}
void quietResult(AsyncResult &r){if(r.isError())Serial.printf("Firebase error %d (no credentials logged)\n",r.error().code());}
void ack(const Pending &p,const char *status){
  JsonDocument d;d["status"]=status;d["relay"]=p.relay;d["sequence"]=p.sequence;d["sessionId"]=p.session;
  String json;serializeJson(d,json);
  database.set<object_t>(client,base+"/acks/"+p.id,object_t(json),quietResult,"ack");
}
void offer(JsonObjectConst c){
  if(c["trigger"]!=true||c["pulseMs"]!=1000){Serial.println("Komut atlandi: tetik/darbe degeri uygun degil.");return;}
  Pending p;p.id=c["eventId"].as<String>();p.session=c["sessionId"].as<String>();p.relay=c["relay"]|0;p.sequence=c["sequence"]|uint64_t(0);p.expires=c["expiresAt"]|int64_t(0);
  Serial.printf("Komut alindi: role=%d sira=%llu kalan=%lld ms\n",p.relay,(unsigned long long)p.sequence,(long long)(p.expires-nowMs()));
  if(!safeId(p.id)||p.relay<1||p.relay>8||!p.sequence||p.sequence>9007199254740991ULL){Serial.println("Komut atlandi: kimlik/role/sira gecersiz.");return;}
  if(p.session!=sessionId){Serial.println("Komut atlandi: eski oturum.");return;}
  if(p.sequence<=lastSeq[p.relay-1]){Serial.println("Komut atlandi: daha once islendi.");return;}
  if(nowMs()>=p.expires){Serial.println("Komut atlandi: suresi doldu.");ack(p,"expired");return;}
  if(p.expires>nowMs()+11000){Serial.println("Komut atlandi: cihaz saati sunucu saatinden geri. STATUS ile kontrol edin.");return;}
  for(auto &q:pending)if(q.used&&q.id==p.id)return;
  for(auto &q:pending)if(!q.used){q=p;q.used=true;return;}
  ack(p,"rejected");
}
void streamResult(AsyncResult &r){
  if(r.isError()){Serial.printf("Stream error %d\n",r.error().code());return;}
  if(!r.available())return;
  auto &value=r.to<RealtimeDatabaseResult>();if(!value.isStream())return;
  if(value.event()=="keep-alive")return;
  lastStreamAt=millis();
  String payload=value.data();
  Serial.printf("Akis: olay=%s yol=%s boyut=%u RAM=%u\n",value.event().c_str(),value.dataPath().c_str(),(unsigned)payload.length(),ESP.getFreeHeap());
  JsonDocument d;const auto parseError=deserializeJson(d,payload);
  if(parseError){Serial.printf("Akis JSON hatasi: %s RAM=%u\n",parseError.c_str(),ESP.getFreeHeap());return;}
  if(tenantId.isEmpty()){
    if(d["bound"]==true){String tid=d["tenantId"].as<String>();if(safeId(tid)&&prefs.putString("tenant",tid)>0){Serial.println("Yurt atamasi kaydedildi. Yeniden baslatiliyor.");ESP.restart();}}
    return;
  }
  if(d["eventId"].is<String>())offer(d.as<JsonObjectConst>());
  else if(d.is<JsonObject>())for(JsonPairConst kv:d.as<JsonObjectConst>())if(kv.value().is<JsonObject>())offer(kv.value().as<JsonObjectConst>());
}
class SaveCallbacks:public BLECharacteristicCallbacks {void onWrite(BLECharacteristic *c)override{if(c->getValue()=="SAVE")saveWifi=true;}};
class ServerCallbacks:public BLEServerCallbacks{void onDisconnect(BLEServer*)override{BLEDevice::startAdvertising();}};
void setupBluetooth(){
  uint32_t pin=prefs.getUInt("blepin",0);if(!pin){pin=100000+esp_random()%900000;prefs.putUInt("blepin",pin);}
  Serial.printf("Bluetooth PIN: %06u\n",pin);
  BLEDevice::init(("UBSoft-"+deviceId.substring(0,8)).c_str());
  BLESecurity::setAuthenticationMode(true,true,true);
  BLESecurity::setCapability(ESP_IO_CAP_OUT);
  BLESecurity::setPassKey(true,pin);
  auto *server=BLEDevice::createServer();server->setCallbacks(new ServerCallbacks());
  auto *service=server->createService(SERVICE_UUID);
  auto *id=service->createCharacteristic(ID_UUID,BLECharacteristic::PROPERTY_READ);id->setValue(deviceId);id->setAccessPermissions(ESP_GATT_PERM_READ_ENC_MITM);
  ssidChar=service->createCharacteristic(SSID_UUID,BLECharacteristic::PROPERTY_WRITE);ssidChar->setAccessPermissions(ESP_GATT_PERM_WRITE_ENC_MITM);
  passwordChar=service->createCharacteristic(PASSWORD_UUID,BLECharacteristic::PROPERTY_WRITE);passwordChar->setAccessPermissions(ESP_GATT_PERM_WRITE_ENC_MITM);
  auto *save=service->createCharacteristic(SAVE_UUID,BLECharacteristic::PROPERTY_WRITE);save->setAccessPermissions(ESP_GATT_PERM_WRITE_ENC_MITM);save->setCallbacks(new SaveCallbacks());
  service->start();auto *ad=BLEDevice::getAdvertising();ad->addServiceUUID(SERVICE_UUID);ad->setScanResponse(true);ad->start();
  Serial.println("Bluetooth kurulum acik. SSID, parola ve SAVE gonderin.");
}
bool registerDevice(){
  WiFiClientSecure tls;tls.setCACert(GOOGLE_ROOTS);HTTPClient http;
  if(!http.begin(tls,REGISTER_URL))return false;http.setTimeout(12000);http.addHeader("Content-Type","application/json");
  JsonDocument d;d["deviceId"]=deviceId;d["deviceSecret"]=secret;d["hardwareId"]=WiFi.macAddress();String body;serializeJson(d,body);
  int code=http.POST(body);http.end();body="";if(code!=200){Serial.printf("Cihaz kaydi basarisiz: %d\n",code);return false;}
  return prefs.putBool("registered",true)>0;
}
void setup(){
  // Set every latch LOW before making any pin an output.
  for(int i=0;i<8;i++){digitalWrite(PINS[i],LOW);pinMode(PINS[i],OUTPUT);esp_timer_create_args_t args={};args.callback=off;args.arg=(void*)(intptr_t)i;args.name="relayOff";if(esp_timer_create(&args,&timers[i])!=ESP_OK)abort();}
  Serial.begin(115200);prefs.begin("ubturnstile",false);
  bootloader_random_enable();
  deviceId=prefs.getString("id","");secret=prefs.getString("secret","");
  if(deviceId.isEmpty()&&secret.isEmpty()){
    deviceId=randomHex(16);secret=randomHex(32);
    if(!prefs.putString("secret",secret)||!prefs.putString("id",deviceId))abort();
  }
  // Fail closed on a partially written identity; never silently replace it.
  if(deviceId.length()!=32||secret.length()!=64){Serial.println("NVS kimlik hatasi. Teknik destek gerekli.");return;}
  tenantId=prefs.getString("tenant","");sessionId=randomHex(16);
  if(!prefs.getUInt("blepin",0))prefs.putUInt("blepin",100000+esp_random()%900000);
  bootloader_random_disable();
  for(int i=0;i<8;i++){String key="seq"+String(i+1);lastSeq[i]=prefs.getULong64(key.c_str(),0);}
  Serial.println("Kart kimligi: "+deviceId);Serial.println("Yurt: "+tenantId);
  ssid=prefs.getString("ssid","");password=prefs.getString("wifi","");
  if(ssid.isEmpty()){setupBluetooth();return;}
  // Arduino reserves BLE/Classic memory when BLE headers are linked, even
  // on boots which do not start provisioning. Release it before two TLS
  // connections; WIFI_RESET reboots before enabling Bluetooth again.
  if(esp_bt_controller_get_status()==ESP_BT_CONTROLLER_STATUS_IDLE){
    const esp_err_t released=esp_bt_mem_release(ESP_BT_MODE_BTDM);
    Serial.printf("Bluetooth bellek serbest birakma: %d RAM=%u\n",(int)released,ESP.getFreeHeap());
  }
  WiFi.mode(WIFI_STA);WiFi.setAutoReconnect(true);WiFi.begin(ssid.c_str(),password.c_str());
  configTime(0,0,"time.google.com","pool.ntp.org");net.setCACert(GOOGLE_ROOTS);streamNet.setCACert(GOOGLE_ROOTS);
}
void loop(){
  static String serial;
  while(Serial.available()){char c=Serial.read();if(c=='\n'){serial.trim();if(serial=="WIFI_RESET"){prefs.remove("ssid");prefs.remove("wifi");ESP.restart();}if(serial=="ID")Serial.println(deviceId);if(serial=="STATUS"){Serial.printf("STATUS WiFi=%d Firebase=%d UTC_ms=%lld RAM=%u Son_akis_ms=%lu\n",(int)WiFi.status(),(int)(initialized&&firebase.ready()),(long long)nowMs(),ESP.getFreeHeap(),(unsigned long)lastStreamAt);for(int i=0;i<8;i++)Serial.printf("Role %d GPIO%d aktif=%d son_sira=%llu\n",i+1,PINS[i],(int)active[i],(unsigned long long)lastSeq[i]);}serial="";}else if(serial.length()<64)serial+=c;}
  if(saveWifi){saveWifi=false;String s=ssidChar->getValue(),p=passwordChar->getValue();if(s.length()>0&&s.length()<=32&&p.length()<=63){if(prefs.putString("wifi",p)>0&&prefs.putString("ssid",s)>0)ESP.restart();}}
  if(ssid.isEmpty()||deviceId.length()!=32||secret.length()!=64){delay(5);return;}
  bool connected=WiFi.status()==WL_CONNECTED;
  if(!connected){wasConnected=false;delay(5);return;}
  // Restart after a network loss: fresh session rejects buffered old commands.
  if(!wasConnected){if(initialized){ESP.restart();}wasConnected=true;}
  if(nowMs()<1735689600000LL){delay(5);return;}
  if(!prefs.getBool("registered",false)){
    if(lastRegistration&&millis()-lastRegistration<30000)return;lastRegistration=millis();if(!registerDevice())return;
  }
  if(!initialized){
    String email=deviceId+"@turnstile.invalid";userAuth=new UserAuth(API_KEY,email,secret,3000);
    initializeApp(client,firebase,getAuth(*userAuth),quietResult,"auth");firebase.getApp<RealtimeDatabase>(database);database.url(DB_URL);initialized=true;
  }
  firebase.loop();if(!firebase.ready())return;
  if(!connectionReported){connectionReported=true;Serial.printf("Firebase baglandi. Surum=2.2.2 UTC_ms=%lld RAM=%u\n",(long long)nowMs(),ESP.getFreeHeap());}
  if(!streaming){
    base="/turnstiles/"+tenantId+"/"+deviceId;
    database.get(streamClient,tenantId.isEmpty()?"/bindings/"+deviceId:base+"/control/commands",streamResult,true,"stream");streaming=true;Serial.println("Komut dinleme yolu: "+(tenantId.isEmpty()?"/bindings/"+deviceId:base+"/control/commands"));
  }
  if(tenantId.isEmpty())return;
  if(!lastHeartbeat||millis()-lastHeartbeat>=5000){
    lastHeartbeat=millis();JsonDocument d;d["sessionId"]=sessionId;d["lastSeen"][".sv"]="timestamp";d["firmware"]="2.2.2";String json;serializeJson(d,json);
    database.set<object_t>(client,base+"/status",object_t(json),quietResult,"heartbeat");
  }
  // Lowest sequence first per relay, with a short LOW gap between pulses.
  for(int i=0;i<8;i++){
    if(active[i]||uint32_t(millis()-stoppedAt[i])<200)continue;
    Pending *next=nullptr;for(auto &p:pending)if(p.used&&p.relay==i+1&&(!next||p.sequence<next->sequence))next=&p;
    if(!next)continue;Pending p=*next;next->used=false;
    if(p.sequence<=lastSeq[i])continue;
    if(nowMs()>=p.expires){ack(p,"expired");continue;}
    String key="seq"+String(i+1);
    if(prefs.putULong64(key.c_str(),p.sequence)!=sizeof(uint64_t)){ack(p,"persistence_failed");continue;}
    lastSeq[i]=p.sequence;active[i]=true;
    // Arm the independent cutoff before energizing; timer failure stays LOW.
    if(esp_timer_start_once(timers[i],1000000)!=ESP_OK){active[i]=false;ack(p,"rejected");continue;}
    gpio_set_level((gpio_num_t)PINS[i],1);Serial.printf("ROLE TETIKLENDI: role=%d GPIO=%d sure=1000ms\n",i+1,PINS[i]);ack(p,"pulse_started");
  }
  delay(1);
}
