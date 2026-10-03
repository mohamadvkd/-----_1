import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

void main() => runApp(const QuranApp());

class QuranApp extends StatelessWidget {
  const QuranApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'القرآن الكريم',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        fontFamily: 'Amiri',
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AudioPlayer _player = AudioPlayer();
  List<dynamic> _reciters = [];
  List<dynamic> _ayahs = [];
  dynamic _selectedReciter;
  bool _loading = false;
  String _status = 'اختر قارئاً وسورة';

  // أسماء السور بالعربية (للاستخدام في قائمة الاختيار)
  final List<String> _surahNames = const [
    'الفاتحة', 'البقرة', 'آل عمران', 'النساء', 'المائدة', 'الأنعام',
    'الأعراف', 'الأنفال', 'التوبة', 'يونس', 'هود', 'يوسف', 'الرعد',
    'إبراهيم', 'الحجر', 'النحل', 'الإسراء', 'الكهف', 'مريم', 'طه',
    'الأنبياء', 'الحج', 'المؤمنون', 'النور', 'الفرقان', 'الشعراء',
    'النمل', 'القصص', 'العنكبوت', 'الروم', 'لقمان', 'السجدة',
    'الأحزاب', 'سبأ', 'فاطر', 'يس', 'الصافات', 'ص', 'الزمر', 'غافر',
    'فصلت', 'الشورى', 'الزخرف', 'الدخان', 'الجاثية', 'الأحقاف',
    'محمد', 'الفتح', 'الحجرات', 'ق', 'الذاريات', 'الطور', 'النجم',
    'القمر', 'الرحمن', 'الواقعة', 'الحديد', 'المجادلة', 'الحشر',
    'الممتحنة', 'الصف', 'الجمعة', 'المنافقون', 'التغابن', 'الطلاق',
    'التحريم', 'الملك', 'القلم', 'الحاقة', 'المعارج', 'نوح', 'الجن',
    'المزمل', 'المدثر', 'القيامة', 'الإنسان', 'المرسلات', 'النبأ',
    'النازعات', 'عبس', 'التكوير', 'الإنفطار', 'المطففين', 'الإنشقاق',
    'البروج', 'الطارق', 'الأعلى', 'الغاشية', 'الفجر', 'البلد',
    'الشمس', 'الليل', 'الضحى', 'الشرح', 'التين', 'العلق', 'القدر',
    'البينة', 'الزلزلة', 'العاديات', 'القارعة', 'التكاثر', 'العصر',
    'الهمزة', 'الفيل', 'قريش', 'الماعون', 'الكوثر', 'الكافرون',
    'النصر', 'المسد', 'الإخلاص', 'الفلق', 'الناس',
  ];

  @override
  void initState() {
    super.initState();
    _loadReciters();
  }

  // ✅ جلب قائمة القراء من mp3quran
  Future<void> _loadReciters() async {
    try {
      final res = await http.get(
        Uri.parse('https://mp3quran.net/api/v3/reciters?language=ar'),
      );
      if (res.statusCode != 200) {
        setState(() => _status = 'فشل تحميل القراء: HTTP ${res.statusCode}');
        return;
      }
      final data = json.decode(res.body);
      setState(() {
        _reciters = data['reciters'] ?? [];
        _status = 'تم تحميل ${_reciters.length} قارئ';
      });
    } catch (e) {
      setState(() => _status = 'فشل تحميل القراء: $e');
    }
  }

  // ✅ جلب نص السورة من Quranpedia
  Future<void> _loadSurah(int surahNumber) async {
    setState(() {
      _loading = true;
      _ayahs = [];
      _status = 'جاري تحميل النص...';
    });

    try {
      final res = await http.get(
        Uri.parse('https://api.quranpedia.net/v1/mushafs/1/$surahNumber'),
      );

      if (res.statusCode != 200) {
        setState(() {
          _loading = false;
          _status = 'خطأ HTTP: ${res.statusCode}';
        });
        return;
      }

      final data = json.decode(res.body);

      // الاستجابة قد تكون مصفوفة مباشرة أو داخل مفتاح 'ayahs'
      final List<dynamic> ayahs =
          data is List ? data : (data['ayahs'] ?? []);

      setState(() {
        _ayahs = ayahs;
        _loading = false;
        _status = 'تم التحميل (${ayahs.length} آية)';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _status = 'فشل تحميل النص: $e';
      });
    }
  }

  // ✅ تشغيل الصوت من mp3quran
  Future<void> _playAudio(int surahNumber) async {
    if (_selectedReciter == null) {
      setState(() => _status = 'الرجاء اختيار قارئ أولاً');
      return;
    }

    // استخراج رابط الخادم من بيانات القارئ
    String? server;
    final moshaf = _selectedReciter['moshaf'];
    if (moshaf is List && moshaf.isNotEmpty) {
      server = moshaf[0]['server'];
    } else if (moshaf is Map) {
      server = moshaf['server'];
    }

    if (server == null) {
      setState(() => _status = 'لا يوجد رابط صوت لهذا القارئ');
      return;
    }

    final number = surahNumber.toString().padLeft(3, '0');
    final url = '$server$number.mp3';

    try {
      setState(() => _status = 'جاري التشغيل...');
      await _player.setUrl(url);
      _player.play();
      setState(() => _status = '▶ يعمل: سورة $surahNumber');
    } catch (e) {
      setState(() => _status = 'فشل الصوت: $e');
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('القرآن الكريم'),
        actions: [
          if (_reciters.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: DropdownButton<dynamic>(
                value: _selectedReciter,
                hint: const Text('اختر قارئاً'),
                underline: const SizedBox(),
                items: _reciters.map<DropdownMenuItem<dynamic>>((r) {
                  return DropdownMenuItem(
                    value: r,
                    child: Text(
                      r['name'] ?? '',
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedReciter = v),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // شريط الحالة
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: Colors.green.shade50,
            child: Text(
              _status,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),

          // منطقة العرض
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _ayahs.isEmpty
                    ? const Center(
                        child: Text('اختر سورة من الزر العائم'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _ayahs.length,
                        itemBuilder: (context, i) {
                          final a = _ayahs[i];
                          final text = a['text']?.toString() ?? '';
                          final number = a['number']?.toString() ?? '${i + 1}';
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    text,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      height: 1.8,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '﴿ $number ﴾',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showSurahPicker,
        child: const Icon(Icons.menu_book),
      ),
    );
  }

  // قائمة اختيار السورة
  void _showSurahPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: ListView.builder(
          itemCount: 114,
          itemBuilder: (context, i) {
            final n = i + 1;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green.shade100,
                child: Text(
                  '$n',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              title: Text('سورة ${_surahNames[i]}'),
              onTap: () {
                Navigator.pop(context);
                _loadSurah(n);
                _playAudio(n);
              },
            );
          },
        ),
      ),
    );
  }
}