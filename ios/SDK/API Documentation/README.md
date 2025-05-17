# iOS SDK Integration Package Usage Guide — Summary

## What the integration package is for
The bundle provides a **native Objective‑C API** that lets your iOS app communicate directly with the vendor’s thermal printers, enabling printing without any additional middleware.

## How to evaluate the SDK quickly
1. Open the supplied **SDK Demo** project in Xcode.  
2. Build & run it on an iPhone.  
3. Use the demo to confirm connectivity and printing.

## Where to find the detailed docs
* **Offline:** `iOS 端 SDK 接口说明文档 V3.2.8` is included in the package.  
* **Online:**  
  * The same interface manual  
  * “**iOS 打印机蓝牙相关注意事项**” (Bluetooth caveats)  
  * “**精臣打印机 SDK – 内容排版在线文档**” (layout tutorial)  
  * “**基于精臣 PC 端云打印快速排版**” (cloud‑print layout guide)

## Minimum system requirement
* **iOS 9.0 or higher**

## Steps a developer should take
1. Study the demo code to see the correct API calls.  
2. Read the interface manual for parameter details.  
3. **Before coding,** read the Bluetooth‑specific notes to avoid pairing or throughput pitfalls.  
4. If you need custom label layout, consult the layout docs.  
5. Contact the vendor’s tech‑support team if you encounter problems.

## Typography/legal note
Fonts embedded in the demo are **only for learning and testing** the SDK. They are **not licensed for production**; purchase proper licenses if you want to ship them, and notify the vendor of any copyright issue.

---

### In short
The document explains how to evaluate and integrate an Objective‑C iOS SDK that drives the vendor’s printers, lists the required OS version, points to the full API reference and layout tutorials, and warns about Bluetooth quirks and font licensing.
