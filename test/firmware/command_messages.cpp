#include <ArduinoJson.h>
#include <cassert>
#include <cstring>
#include <iostream>
#include <string>
#include <vector>
// VISITOR_INSERTION_POINT
static std::vector<int> relays;
static int probes=0;
void capture(JsonObjectConst message){
  if(message["kind"]=="probe")probes++;
  else relays.push_back(message["relay"]|0);
}
void check(const char *json){
  JsonDocument doc;
  assert(!deserializeJson(doc,json));
  visitCommandMessages(doc.as<JsonVariantConst>(),capture);
}
int main(){
  // The 210-byte structure observed on the physical board: RTDB wraps each
  // command in its event key. The old const-to-mutable test drops this packet.
  const char *packet=R"json({"sampleEvent1234567890":{"eventId":"sampleEvent1234567890","expiresAt":1793568744511,"issuedAt":1793568737748,"pulseMs":1000,"relay":6,"sequence":1,"sessionId":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","trigger":true}})json";
  assert(std::strlen(packet)==210);
  JsonDocument proof;assert(!deserializeJson(proof,packet));
  for(JsonPairConst pair:proof.as<JsonObjectConst>()){
    assert(!pair.value().is<JsonObject>());
    assert(pair.value().is<JsonObjectConst>());
  }
  check(packet);assert((relays==std::vector<int>{6}));
  check(R"({"eventId":"single","relay":8})");assert((relays==std::vector<int>{6,8}));
  check(R"({"first":{"eventId":"first","relay":1},"second":{"eventId":"second","relay":7}})");
  assert((relays==std::vector<int>{6,8,1,7}));
  check(R"({"_probe_request":{"kind":"probe","requestId":"request"}})");assert(probes==1);
  check(R"({"kind":"probe","requestId":"direct"})");assert(probes==2);
  check("null");check("false");check("[]");check("{}");check(R"({"deleted":null})");
  assert(relays.size()==4&&probes==2);
  std::cout<<"PASS: exact 210-byte packet, direct/batch commands, probes, empty/deleted data; original const-cast defect reproduced.\n";
}
