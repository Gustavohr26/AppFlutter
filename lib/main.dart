import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sensors_plus/sensors_plus.dart';

final notificacoes = FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o plugin de notificações antes de abrir o app
  await notificacoes.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: HomeScreen(),
  ));
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? caminhoFoto;
  Position? posicao;
  AccelerometerEvent? acel;
  StreamSubscription<AccelerometerEvent>? assinatura;

  // 4) Acelerômetro: X, Y e Z em tempo real
  @override
  void initState() {
    super.initState();
    assinatura = accelerometerEventStream(
      samplingPeriod: SensorInterval.normalInterval,
    ).listen((evento) => setState(() => acel = evento));
  }

  @override
  void dispose() {
    assinatura?.cancel(); // encerra o stream ao fechar a tela
    super.dispose();
  }

  void aviso(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  // 1) Câmera: capturar e exibir foto
  Future<void> tirarFoto() async {
    try {
      final foto = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 50,
      );
      if (foto != null) setState(() => caminhoFoto = foto.path);
    } catch (e) {
      aviso('Erro ao fotografar: $e');
    }
  }

  // 2) GPS: latitude e longitude
  Future<void> obterLocalizacao() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      aviso('Ative o GPS do celular.');
      return;
    }
    var permissao = await Geolocator.checkPermission();
    if (permissao == LocationPermission.denied) {
      permissao = await Geolocator.requestPermission();
    }
    if (permissao == LocationPermission.denied ||
        permissao == LocationPermission.deniedForever) {
      aviso('Permissão de localização negada.');
      return;
    }
    try {
      final p = await Geolocator.getCurrentPosition();
      setState(() => posicao = p);
    } catch (e) {
      aviso('Erro ao obter localização: $e');
    }
  }

  // 3) Notificação local
  Future<void> enviarNotificacao() async {
    await notificacoes
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await notificacoes.show(
      1,
      'Lembrete de estudo',
      'Sua atividade começa às 19h.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'lembretes',
          'Lembretes',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  Widget cartao(String titulo, List<Widget> filhos) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titulo,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...filhos,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meu Smartphone Inteligente')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          cartao('📷 Câmera', [
            ElevatedButton(onPressed: tirarFoto, child: const Text('Tirar foto')),
            if (caminhoFoto != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Image.file(File(caminhoFoto!),
                    width: 250, height: 250, fit: BoxFit.cover),
              ),
          ]),
          cartao('📍 Localização', [
            ElevatedButton(
                onPressed: obterLocalizacao, child: const Text('Obter localização')),
            if (posicao != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Latitude: ${posicao!.latitude.toStringAsFixed(5)}\n'
                  'Longitude: ${posicao!.longitude.toStringAsFixed(5)}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
          ]),
          cartao('🔔 Notificação', [
            ElevatedButton(
                onPressed: enviarNotificacao,
                child: const Text('Enviar notificação')),
          ]),
          cartao('📱 Acelerômetro', [
            Text(
              'X: ${acel?.x.toStringAsFixed(2) ?? '-'}\n'
              'Y: ${acel?.y.toStringAsFixed(2) ?? '-'}\n'
              'Z: ${acel?.z.toStringAsFixed(2) ?? '-'}',
              style: const TextStyle(fontSize: 16),
            ),
          ]),
        ],
      ),
    );
  }
}
