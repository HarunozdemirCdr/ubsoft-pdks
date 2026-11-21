# UBSoft Turnstile ESP32 Firmware

Bu klasörde turnike kartı için iki ayrı bağlantı sürümü bulunur:

1. **`ubsoft_turnstile/` (Wi-Fi Sürümü — v2.3.3)**
   - ESP32 Wi-Fi + Captive Portal üzerinden kablosuz bağlantı.
   - Röle 1–8: `26, 27, 25, 32, 33, 18, 19, 23`
   - Durum LED'i: `GPIO 2`, BOOT Butonu: `GPIO 0`

2. **`ubsoft_turnstile_ethernet/` (W5500 Ethernet Sürümü — v2.4.0-eth)**
   - Wi-Fi tamamen devre dışı, dahili `ETH.h` + `NetworkClientSecure` ile W5500 (HanRun HR911105A) kablolu Ethernet.
   - W5500 SPI Pinleri: `SCK=18`, `MISO=19`, `MOSI=23`, `CS=5`, `RST=17`, `INT=bağlı değil (-1)`
   - Röle 1–8: `27, 26, 25, 32, 14, 12, 13, 15`
   - Harici Büyük Durum LED'i: `GPIO 4`, BOOT Butonu: `GPIO 0`
