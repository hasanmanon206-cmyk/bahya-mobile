import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

const shopName = "قهوة البلة";
const defaultHttpPort = 8081;
const defaultWsPort = 8082;

class AppState extends ChangeNotifier {
  String mode = "CLIENT"; // HUB | CLIENT
  String host = "";
  int httpPort = defaultHttpPort;
  int wsPort = defaultWsPort;

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    mode = sp.getString("mode") ?? "CLIENT";
    host = sp.getString("host") ?? "";
    httpPort = sp.getInt("httpPort") ?? defaultHttpPort;
    wsPort = sp.getInt("wsPort") ?? defaultWsPort;
    notifyListeners();
  }

  Future<void> save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString("mode", mode);
    await sp.setString("host", host);
    await sp.setInt("httpPort", httpPort);
    await sp.setInt("wsPort", wsPort);
  }

  String qrPayload(String ip) {
    return jsonEncode({
      "app": "bahya",
      "shop": shopName,
      "host": ip,
      "http": httpPort,
      "ws": wsPort,
      "v": 1
    });
  }

  String hubBaseUrl() => "http://$host:$httpPort";
}

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..load(),
      child: const BahyaApp(),
    ),
  );
}

class BahyaApp extends StatelessWidget {
  const BahyaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: shopName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D6EFD)),
        scaffoldBackgroundColor: const Color(0xFFF7F7FB),
        useMaterial3: true,
      ),
      home: const ModeScreen(),
    );
  }
}

class ModeScreen extends StatelessWidget {
  const ModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text("قهوة البلة | Bahya"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Card(
              title: "اختيار وضع الجهاز",
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _ChipBtn(
                    label: "هذا الجهاز هو الرئيسي (Hub)",
                    active: s.mode == "HUB",
                    color: Colors.blue,
                    onTap: () async {
                      s.mode = "HUB";
                      await s.save();
                      s.notifyListeners();
                    },
                  ),
                  _ChipBtn(
                    label: "هذا الجهاز عميل (موظف/زبون)",
                    active: s.mode == "CLIENT",
                    color: Colors.green,
                    onTap: () async {
                      s.mode = "CLIENT";
                      await s.save();
                      s.notifyListeners();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (s.mode == "HUB") ...[
              _Card(
                title: "QR للاتصال (الموظفين/الزبائن يمسحوه)",
                child: FutureBuilder<String>(
                  future: _getLocalIPv4(),
                  builder: (ctx, snap) {
                    final ip = snap.data ?? "0.0.0.0";
                    final payload = s.qrPayload(ip);
                    return Column(
                      children: [
                        QrImageView(data: payload, size: 220),
                        const SizedBox(height: 10),
                        Text("IP: $ip  | HTTP:${s.httpPort}  WS:${s.wsPort}",
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        const Text("لاحقاً سنشغّل Hub Server داخل التطبيق (الخطوة التالية)."),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              _Card(
                title: "دخول إلى الشاشات",
                child: Column(
                  children: [
                    _NavBtn("شاشة المحاسب", () => _go(context, const CashierScreen())),
                    _NavBtn("شاشة الجارسون", () => _go(context, const WaiterScreen())),
                    _NavBtn("شاشة المكنة", () => _go(context, const BaristaScreen())),
                    _NavBtn("شاشة العرض (HOT)", () => _go(context, const HotDisplayScreen())),
                    _NavBtn("شاشة الزبون", () => _go(context, const CustomerScreen())),
                  ],
                ),
              ),
            ] else ...[
              _Card(
                title: "الاتصال بالـ Hub عبر QR",
                child: Column(
                  children: [
                    _NavBtn("مسح QR الآن", () => _go(context, const ScanQrScreen())),
                    const SizedBox(height: 8),
                    Text(
                      s.host.isEmpty ? "غير متصل بعد" : "Hub: ${s.hubBaseUrl()}",
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _Card(
                title: "شاشات العميل",
                child: Column(
                  children: [
                    _NavBtn("شاشة المحاسب", () => _go(context, const CashierScreen())),
                    _NavBtn("شاشة الجارسون", () => _go(context, const WaiterScreen())),
                    _NavBtn("شاشة الزبون", () => _go(context, const CustomerScreen())),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ScanQrScreen extends StatelessWidget {
  const ScanQrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text("مسح QR للاتصال")),
      body: MobileScanner(
        onDetect: (cap) async {
          final v = cap.barcodes.firstOrNull?.rawValue;
          if (v == null) return;
          try {
            final j = jsonDecode(v);
            if (j["app"] != "bahya") return;
            s.host = (j["host"] ?? "").toString();
            s.httpPort = int.tryParse("${j["http"]}") ?? defaultHttpPort;
            s.wsPort = int.tryParse("${j["ws"]}") ?? defaultWsPort;
            await s.save();
            s.notifyListeners();
            if (context.mounted) Navigator.pop(context);
          } catch (_) {}
        },
      ),
    );
  }
}

class CashierScreen extends StatelessWidget {
  const CashierScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return _SimpleScreen(
      title: "المحاسب (ERP) — قريباً UI كامل حسب رسوماتك",
      lines: const [
        "• أقسام/أصناف/منتجات (Grid)",
        "• 7 سلال أفقية",
        "• Inbox الزبون بالمنتصف + قبول/رفض",
        "• باركود: إضافة للسلة + إضافة منتج جديد",
      ],
    );
  }
}

class WaiterScreen extends StatelessWidget {
  const WaiterScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return _SimpleScreen(
      title: "الجارسون",
      lines: const [
        "• طاولات + إرسال طلب",
        "• خيار باركود لإضافة منتج بسرعة",
      ],
    );
  }
}

class BaristaScreen extends StatelessWidget {
  const BaristaScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return _SimpleScreen(
      title: "المكنة (HOT فقط)",
      lines: const ["• يستقبل الطلبات الساخنة بعد القبول/الدفع"],
    );
  }
}

class HotDisplayScreen extends StatelessWidget {
  const HotDisplayScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return _SimpleScreen(
      title: "شاشة العرض (HOT)",
      lines: const ["• تعرض الطلبات الساخنة من الـ Hub"],
    );
  }
}

class CustomerScreen extends StatelessWidget {
  const CustomerScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return _SimpleScreen(
      title: "الزبون",
      lines: const [
        "• سلة واحدة",
        "• مودال السكر: (سادة/قليل/وسط/عصملي/حلوة) + تكرار سطر",
        "• متابعة الحالة: انتظار/مقبول/قيد التحضير/جاهز",
      ],
    );
  }
}

class _SimpleScreen extends StatelessWidget {
  final String title;
  final List<String> lines;
  const _SimpleScreen({required this.title, required this.lines});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: _Card(
          title: "ملاحظة",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final l in lines) Text(l, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 12),
              const Text("تم تطوير وإنشاء هذا التطبيق بواسطة أبو هاني",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0x220D6EFD)),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(blurRadius: 12, spreadRadius: -8, offset: Offset(0, 6))],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ChipBtn extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _ChipBtn({required this.label, required this.active, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(.15) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? color : Colors.black12),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _NavBtn(this.label, this.onTap);
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}

void _go(BuildContext context, Widget w) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => w));
}

Future<String> _getLocalIPv4() async {
  try {
    for (final i in await NetworkInterface.list()) {
      for (final a in i.addresses) {
        if (a.type == InternetAddressType.IPv4 && !a.isLoopback) return a.address;
      }
    }
  } catch (_) {}
  return "0.0.0.0";
}
