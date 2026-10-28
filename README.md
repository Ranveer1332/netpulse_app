<div align="center">

# ⚡ NetPulse

**High-precision network diagnostics, real-time bandwidth benchmarking, and statistical latency telemetry.**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.12+-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Platforms](https://img.shields.io/badge/Platforms-Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Web-blueviolet)](#platform-support)
[![State](https://img.shields.io/badge/State-Provider-68B984)](https://pub.dev/packages/provider)
[![Storage](https://img.shields.io/badge/Storage-Hive%20(Local--First)-E55934)](https://pub.dev/packages/hive_flutter)
[![License](https://img.shields.io/badge/License-MIT-black.svg)](LICENSE)

<br/>

<p align="center">
  <img src="assets/splash.jpg" alt="NetPulse Banner" width="700" style="border-radius: 12px; box-shadow: 0 8px 30px rgba(0,0,0,0.12);"/>
</p>

</div>

---

## 📑 Table of Contents

- [Overview](#-overview)
- [Key Features](#-key-features)
- [Architecture & Tech Deep Dive](#-architecture--tech-deep-dive)
  - [1. Multi-Stream Bandwidth Saturation](#1-multi-stream-bandwidth-saturation)
  - [2. Sub-Millisecond Latency & RFC 3550 Jitter](#2-sub-millisecond-latency--rfc-3550-jitter)
  - [3. Hop-by-Hop Topology Fault Isolation](#3-hop-by-hop-topology-fault-isolation)
  - [4. Statistical Anomaly Detection Engine](#4-statistical-anomaly-detection-engine)
- [App Showcase](#-app-showcase)
- [Project Structure](#-project-structure)
- [Tech Stack & Libraries](#-tech-stack--libraries)
- [Getting Started](#-getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation & Setup](#installation--setup)
  - [Running the App](#running-the-app)
- [Platform Specifics & Permissions](#-platform-specifics--permissions)
- [License](#-license)

---

## 🌐 Overview

**NetPulse** is a modern, privacy-first network diagnostic and throughput benchmarking suite built with Flutter. Rather than relying on opaque third-party black-box speed tests, NetPulse implements transparent, low-level networking techniques directly on-device:

- **True Bandwidth Saturation**: Multi-socket parallel HTTP stream benchmarking for download and streaming chunked upload.
- **Transport-Layer Latency**: Raw TCP three-way handshake ($SYN \to SYN\text{-}ACK \to ACK$) round-trip timing that bypasses application-layer HTTP overhead.
- **Root-Cause Fault Isolation**: Multi-hop topology probing that pinpoints whether network slowdowns originate at your **Device**, your **Local Wi-Fi Gateway/Router**, or upstream **External WAN/DNS**.
- **Proactive Telemetry**: Statistical rolling Z-score anomaly detection to identify latency degradation relative to your historical baseline.
- **100% Local & Private**: Stored locally with Hive key-value boxes. No background telemetry trackers, no external cloud dependencies, and instant offline access.

---

## 🚀 Key Features

| Feature | Description |
| :--- | :--- |
| **⚡ Multi-Stream Speed Test** | Saturates available network pipe with up to 6 parallel connections, measuring accurate download & upload speeds with live gauge feedback. |
| **⏱️ Low-Level Latency & Jitter** | Measures TCP RTT against public DNS (8.8.8.8:53) and computes standard RFC 3550 VoIP-grade jitter over consecutive samples. |
| **🔍 3-Hop Fault Isolation** | Classifies network health across **Hop 0 (Device)**, **Hop 1 (LAN Gateway/Router)**, and **Hop 2 (WAN/Internet)**, providing actionable human-readable verdicts. |
| **📉 Rolling Z-Score Anomaly Engine** | Evaluates current latency against a rolling window ($W = 20$) baseline ($\mu, \sigma$) to surface latency spikes ($Z > 2.0$). |
| **📊 Time-Series Historical Charts** | Interactive charting powered by `fl_chart` with dynamic auto-scaling axes, Day vs. Week toggles, and summary statistics (peak, average, min latency). |
| **📤 Data Portability (CSV)** | One-click export of stored test telemetry into standard CSV format with native OS share sheet integration (`share_plus`). |
| **⚙️ Diagnostics Automation** | Configurable background auto-refresh diagnostics cycle (1m, 5m, 15m, 60m). |
| **🎨 Neo-Brutalist UI** | High-contrast, tactile design system with `JetBrains Mono` typography, responsive speed gauge animations, and clean status indicators. |

---

## 🔬 Architecture & Tech Deep Dive

### 1. Multi-Stream Bandwidth Saturation

Consumer bandwidth cannot be accurately measured with a single sequential HTTP request due to TCP slow start and window scaling limits. 

NetPulse opens **6 parallel HTTP streaming connections** against distributed high-capacity CDN mirrors:
- Each stream maintains an isolated byte counter to eliminate shared mutable state or race conditions.
- Throughput is calculated using aggregate received bits over elapsed duration:
  $$\text{Mbps} = \frac{\sum_{i=1}^{N} \text{Bytes}_i \times 8}{\Delta t \times 10^6}$$
- Upload speed measures the active upload stream duration via chunked POST payloads to avoid conflating upload throughput with server response download time.

### 2. Sub-Millisecond Latency & RFC 3550 Jitter

Standard HTTP ping methods include DNS lookups, TLS negotiations, and HTTP header parsing overhead. 

NetPulse measures network Round-Trip Time (RTT) using **transport-layer TCP socket handshakes**:
- Connects directly to Google Public DNS (`8.8.8.8:53`), which is globally distributed with Anycast routing and rarely blocked by corporate firewalls.
- Times the duration of the TCP three-way handshake ($SYN \to SYN\text{-}ACK$).
- Computes **Jitter** according to the **RFC 3550** standard (the mean absolute deviation of consecutive latency readings):
  $$J = \frac{1}{N - 1} \sum_{i=1}^{N - 1} |\text{RTT}_{i+1} - \text{RTT}_i|$$

### 3. Hop-by-Hop Topology Fault Isolation

When an internet connection feels sluggish, users rarely know where the failure point lies. NetPulse runs a multi-tier diagnostic pipeline:

```mermaid
flowchart LR
    A[📱 Hop 0: Device] -->|Interface Check| B[📶 Hop 1: Router / LAN]
    B -->|Gateway IP Ping| C[🌍 Hop 2: External WAN / DNS]
    C -->|Packet Loss & DNS Time| D[📋 Diagnostic Verdict]

    style A fill:#ffffff,stroke:#000000,stroke-width:2px,color:#000000
    style B fill:#ffffff,stroke:#000000,stroke-width:2px,color:#000000
    style C fill:#ffffff,stroke:#000000,stroke-width:2px,color:#000000
    style D fill:#FFC107,stroke:#000000,stroke-width:2px,color:#000000
```

1. **Hop 0 (Device)**: Verifies host network stack integrity.
2. **Hop 1 (Router / LAN)**: Discovers the default Wi-Fi gateway IP via `network_info_plus` and probes the local access point.
3. **Hop 2 (External WAN / DNS)**: Executes DNS resolution tests and multi-sample ping routines to detect packet drop percentages.
4. **Adaptive Topology Mode**: Automatically switches between **Full 3-Hop** (for Wi-Fi / Ethernet) and **WAN-Only** mode (for Cellular connections where the gateway is cellular carrier infrastructure).

### 4. Statistical Anomaly Detection Engine

NetPulse implements an on-device anomaly detection algorithm using rolling standard score (Z-Score):

$$Z = \frac{|x - \mu|}{\sigma}$$

Where:
- $x$: Current latency measurement (ms).
- $\mu$: Rolling mean of the preceding $W = 20$ readings.
- $\sigma$: Rolling standard deviation of the window.

If $Z > 2.0$, NetPulse flags an anomaly and generates a plain-language explanation (e.g., *“Latency spiked well above your normal range (avg: 24 ms, yours: 89 ms)”*).

---

## 📱 App Showcase

| Dashboard Screen | Diagnose Screen | History Screen |
| :---: | :---: | :---: |
| Real-time speedometer gauge, current status card, anomaly alert banner, and recent throughput sparkline. | 3-hop topology status nodes, packet loss %, jitter ms, DNS resolution speed, and diagnosis verdict. | Dynamic time-series telemetry charts (`fl_chart`), Day/Week views, and historical session logs. |

---

## 📂 Project Structure

```text
netpulse_app/
├── lib/
│   ├── main.dart                  # App bootstrap, splash preservation, Provider setup
│   ├── theme.dart                 # Neo-Brutalist color palette & JetBrains Mono text theme
│   ├── models/
│   │   └── test_record.dart       # TestRecord data model & Hive Map serializer
│   ├── services/
│   │   ├── anomaly_service.dart   # Rolling window mean, stddev, and Z-score calculation
│   │   ├── connectivity_service.dart # Real-time Wi-Fi / Mobile network watcher
│   │   ├── diagnosis_service.dart # Hop-by-hop topology probe & packet loss calculator
│   │   ├── history_service.dart   # Hive local storage CRUD operations
│   │   ├── latency_service.dart   # TCP handshake RTT timer & RFC 3550 jitter sampler
│   │   └── speed_test_service.dart# Multi-stream parallel download & upload engine
│   ├── state/
│   │   └── app_state.dart         # Global reactive state manager (ChangeNotifier)
│   ├── screens/
│   │   ├── dashboard_screen.dart  # Speed gauge, live metrics, and anomaly insight banner
│   │   ├── diagnose_screen.dart   # 3-Hop topology visualization & diagnostic runner
│   │   ├── history_screen.dart    # Interactive historical charts & telemetry records
│   │   └── settings_screen.dart   # Auto-refresh interval, CSV export, and data management
│   └── widgets/
│       ├── cards.dart             # High-contrast bordered container & card components
│       └── speed_gauge.dart       # Custom-painted dynamic speedometer gauge
├── assets/
│   ├── icon.jpg                   # Application icon asset
│   └── splash.jpg                 # Custom splash branding screen
├── pubspec.yaml                   # Dependencies and Flutter configuration
└── README.md                      # Project documentation
```

---

## 🛠️ Tech Stack & Libraries

| Library | Version | Purpose |
| :--- | :--- | :--- |
| [`provider`](https://pub.dev/packages/provider) | `^6.1.2` | Clean reactive state management and screen rebuild separation |
| [`hive_flutter`](https://pub.dev/packages/hive_flutter) | `^1.1.0` | Ultra-fast, lightweight embedded key-value database for offline records |
| [`fl_chart`](https://pub.dev/packages/fl_chart) | `^1.2.0` | Hardware-accelerated dynamic time-series charts with auto-scaling bounds |
| [`google_fonts`](https://pub.dev/packages/google_fonts) | `^8.2.1` | JetBrains Mono typographic styling for high-legibility telemetry |
| [`connectivity_plus`](https://pub.dev/packages/connectivity_plus) | `^6.1.4` | System connectivity type detection (Wi-Fi, Cellular, Ethernet) |
| [`network_info_plus`](https://pub.dev/packages/network_info_plus) | `^6.1.1` | Wi-Fi SSID and local gateway IP resolution |
| [`share_plus`](https://pub.dev/packages/share_plus) | `^10.0.0` | Native OS file and share sheet integration for CSV export |
| [`http`](https://pub.dev/packages/http) | `^1.4.0` | Low-overhead HTTP client used for chunked streaming speed tests |

---

## 🏁 Getting Started

### Prerequisites

Ensure you have installed:
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>= 3.12.0`)
- [Dart SDK](https://dart.dev/get-started) (`>= 3.12.2`)
- Xcode (for iOS / macOS builds)
- Android Studio / Android SDK (for Android builds)

### Installation & Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/Ranveer1332/netpulse_app.git
   cd netpulse_app
   ```

2. **Install Flutter dependencies**:
   ```bash
   flutter pub get
   ```

3. **Verify environment**:
   ```bash
   flutter doctor
   ```

### Running the App

Run on your connected device, emulator, or desktop:

```bash
# Auto-detect target device
flutter run

# Run specifically on macOS Desktop
flutter run -d macos

# Run on Android
flutter run -d android

# Run on iOS Simulator / Device
flutter run -d ios

# Run on Web (Chrome)
flutter run -d chrome
```

---

## 🛡️ Platform Specifics & Permissions

### Android
NetPulse requires the following permissions declared in `android/app/src/main/AndroidManifest.xml`:
- `android.permission.INTERNET`: Required to execute latency and throughput tests.
- `android.permission.ACCESS_NETWORK_STATE`: Monitors active network interfaces.
- `android.permission.ACCESS_WIFI_STATE`: Resolves Wi-Fi gateway IP addresses for local router diagnosis.

### macOS & iOS
- **macOS App Sandbox**: Configured with `com.apple.security.network.client` and `com.apple.security.network.server` in `DebugProfile.entitlements` and `Release.entitlements` to allow low-level socket connections and local network probing.
- **Location Permission (Wi-Fi SSID)**: On newer Android and iOS versions, accessing the Wi-Fi SSID requires system Location permissions. If location access is not granted, NetPulse gracefully falls back to showing `Connected Wi-Fi` without interrupting diagnostics.

---

## 📄 License

This project is open-source and available under the [MIT License](LICENSE).

---

<div align="center">
  <sub>Built with ❤️ using Flutter and Dart. Authored by <a href="https://github.com/Ranveer1332">Ranveer1332</a>.</sub>
</div>

