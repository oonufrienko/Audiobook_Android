import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';

// ============================================
// КОЛЬОРИ ДОДАТКУ - ЗМІНЮЙТЕ ТУТ
// ============================================
class AppColors {
  // Фони
  static const Color backgroundDark = Color(0xFF1a1a2e);        // Темний фон
  static const Color backgroundMedium = Color(0xFF0f3460);      // Середній фон (картки)
  static const Color backgroundLight = Color(0xFF16213e);       // Світліший фон (AppBar)
  
  // Кнопки
  static const Color buttonGreen = Color(0xFF27ae60);           // Зелена (Додати)
  static const Color buttonRed = Color(0xFFe74c3c);             // Червона (Назад)
  static const Color buttonBlue = Color(0xFF00d9ff);            // Блакитна (Play/Pause)
  static const Color buttonBlueDark = Color(0xFF0099cc);        // Темно-блакитна (градієнт)
  static const Color buttonGray = Color(0xFF0f3460);            // Сіра (Розблокувати)
  
  // Текст
  static const Color textWhite = Colors.white;                  // Основний текст
  static const Color textWhite70 = Colors.white70;              // Вторинний текст
  static const Color textWhite60 = Colors.white60;              // Третинний текст
  static const Color textWhite54 = Colors.white54;              // Підказки
  static const Color textGray = Colors.white70;                 // Сірий текст
  
  // Прогрес і акценти
  static const Color progressBar = Color(0xFF00d9ff);           // Прогрес-бар
  static const Color progressBackground = Color(0xFF16213e);    // Фон прогрес-бара
  
  // Рамки
  static const Color border = Color(0xFF16213e);                // Рамки карток
}
// ============================================

void main() {
  runApp(const AudiobookApp());
}

class AudiobookApp extends StatelessWidget {
  const AudiobookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Аудіокниги',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: AppColors.backgroundDark,
      ),
      home: const LibraryScreen(),
    );
  }
}

// Модель аудіокниги
class Audiobook {
  final String title;
  final String author;
  final String filePath;
  Duration duration; // Non-final to allow updates
  Duration lastPosition;

  Audiobook({
    required this.title,
    required this.author,
    required this.filePath,
    required this.duration,
    this.lastPosition = Duration.zero,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'author': author,
        'filePath': filePath,
        'duration': duration.inMilliseconds,
        'lastPosition': lastPosition.inMilliseconds,
      };

  factory Audiobook.fromJson(Map<String, dynamic> json) => Audiobook(
        title: json['title'],
        author: json['author'],
        filePath: json['filePath'],
        duration: Duration(milliseconds: json['duration']),
        lastPosition: Duration(milliseconds: json['lastPosition'] ?? 0),
      );
}

// Екран бібліотеки
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<Audiobook> audiobooks = [];
  bool isEditMode = false;
  int tapCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAudiobooks();
  }

  // Завантаження збережених книг
  Future<void> _loadAudiobooks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? booksJson = prefs.getString('audiobooks');
    
    if (booksJson != null) {
      final List<dynamic> booksList = json.decode(booksJson);
      setState(() {
        audiobooks = booksList.map((book) => Audiobook.fromJson(book)).toList();
      });
    } else {
      setState(() {
        audiobooks = [
          Audiobook(
            title: 'Кобзар',
            author: 'Тарас Шевченко',
            filePath: 'demo',
            duration: const Duration(hours: 4, minutes: 23),
          ),
          Audiobook(
            title: 'Тіні забутих предків',
            author: 'Михайло Коцюбинський',
            filePath: 'demo',
            duration: const Duration(hours: 2, minutes: 15),
          ),
        ];
      });
    }
  }

  // Збереження книг
  Future<void> _saveAudiobooks() async {
    final prefs = await SharedPreferences.getInstance();
    final String booksJson = json.encode(audiobooks.map((book) => book.toJson()).toList());
    await prefs.setString('audiobooks', booksJson);
  }

  Future<void> _pickAudioFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;
        final title = fileName.replaceAll('.mp3', '').replaceAll('.m4a', '');
        
        setState(() {
          audiobooks.add(Audiobook(
            title: title,
            author: 'Невідомий автор',
            filePath: file.path,
            duration: Duration.zero,
          ));
        });

        await _saveAudiobooks();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Книгу "$title" додано!', style: const TextStyle(fontSize: 22)),
              backgroundColor: AppColors.buttonGreen,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Помилка: $e', style: const TextStyle(fontSize: 22)),
            backgroundColor: AppColors.buttonRed,
          ),
        );
      }
    }
  }

  Future<void> _deleteBook(int index) async {
    final title = audiobooks[index].title;
    setState(() {
      audiobooks.removeAt(index);
    });
    await _saveAudiobooks();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🗑️ Книгу "$title" видалено!', style: const TextStyle(fontSize: 22)),
          backgroundColor: AppColors.buttonRed,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _editBookTitle(BuildContext context, int index) async {
    final controller = TextEditingController(text: audiobooks[index].title);
    String? newTitle;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundMedium,
        title: const Text(
          'Редагувати назву',
          style: TextStyle(color: AppColors.textWhite, fontSize: 24),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: AppColors.textWhite, fontSize: 20),
          decoration: InputDecoration(
            hintText: 'Введіть нову назву',
            hintStyle: const TextStyle(color: AppColors.textWhite54),
            border: OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.progressBar),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'СКАСУВАТИ',
              style: TextStyle(color: AppColors.textWhite70, fontSize: 18),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final input = controller.text.trim();
              if (input.isNotEmpty) {
                newTitle = input;
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('❌ Назва не може бути порожньою!', style: TextStyle(fontSize: 22)),
                    backgroundColor: AppColors.buttonRed,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.buttonGreen,
            ),
            child: const Text(
              'ЗБЕРЕГТИ',
              style: TextStyle(color: AppColors.textWhite, fontSize: 18),
            ),
          ),
        ],
      ),
    );

    if (newTitle != null && mounted) {
      setState(() {
        audiobooks[index] = Audiobook(
          title: newTitle!,
          author: audiobooks[index].author,
          filePath: audiobooks[index].filePath,
          duration: audiobooks[index].duration,
          lastPosition: audiobooks[index].lastPosition,
        );
      });
      await _saveAudiobooks();
    }
  }

  void _handleLockTap() {
    setState(() {
      tapCount++;
      if (tapCount >= 3) {
        isEditMode = !isEditMode;
        tapCount = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text(
          '📚 АУДІОКНИГИ',
          style: TextStyle(
            fontSize: 38,
            fontWeight: FontWeight.bold,
            color: Colors.black,
            letterSpacing: 2,
          ),
        ),
        backgroundColor: const Color(0xFFFFEB3B),
        toolbarHeight: 90,
        centerTitle: true,
        elevation: 10,
        actions: [
          GestureDetector(
            onTap: _handleLockTap,
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    isEditMode ? Icons.lock_open : Icons.lock,
                    color: Colors.black,
                    size: 32,
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Icon(
                      Icons.add,
                      color: Colors.black,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: isEditMode
          ? FloatingActionButton(
              onPressed: _pickAudioFile,
              backgroundColor: Colors.transparent,
              elevation: 10,
              child: Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.buttonBlue, AppColors.buttonBlueDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.buttonBlue,
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add,
                  size: 40,
                  color: AppColors.textWhite,
                  weight: 800,
                ),
              ),
            )
          : null,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: audiobooks.isEmpty
            ? Container(
                color: Colors.white,
                child: const Center(
                  child: Text(
                    'Книг у бібліотеці немає',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              )
            : ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: audiobooks.length,
                itemBuilder: (context, index) {
                  final book = audiobooks[index];
                  return BookCard(
                    book: book,
                    isEditMode: isEditMode,
                    onTap: () async {
                      if (!isEditMode) {
                        final updatedBook = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PlayerScreen(book: book),
                          ),
                        );
                        if (updatedBook != null && updatedBook is Audiobook) {
                          setState(() {
                            audiobooks[index] = updatedBook;
                          });
                          await _saveAudiobooks();
                        }
                      }
                    },
                    onDelete: () => _deleteBook(index),
                    onEdit: () => _editBookTitle(context, index),
                  );
                },
              ),
      ),
    );
  }
}

// Картка книги
class BookCard extends StatelessWidget {
  final Audiobook book;
  final bool isEditMode;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const BookCard({
    super.key,
    required this.book,
    required this.isEditMode,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
  });

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '$hours ГОД $minutes ХВ';
  }

  @override
  Widget build(BuildContext context) {
    final hasProgress = book.lastPosition.inSeconds > 0;
    final progress = book.duration.inMilliseconds > 0
        ? book.lastPosition.inMilliseconds / book.duration.inMilliseconds
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      color: AppColors.backgroundMedium,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border, width: 3),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textWhite,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    book.author,
                    style: const TextStyle(
                      fontSize: 24,
                      color: AppColors.textWhite70,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (book.duration.inMinutes > 0)
                    Text(
                      '⏱️ ${_formatDuration(book.duration)}',
                      style: const TextStyle(
                        fontSize: 22,
                        color: AppColors.textWhite60,
                      ),
                    ),
                  if (hasProgress) ...[
                    const SizedBox(height: 15),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: AppColors.progressBackground,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.progressBar),
                        minHeight: 10,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '📍 Прогрес: ${(progress * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 20,
                        color: AppColors.progressBar,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
              if (isEditMode)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: AppColors.textWhite, size: 28),
                        onPressed: onEdit,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: AppColors.textWhite, size: 28),
                        onPressed: onDelete,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Екран програвача
class PlayerScreen extends StatefulWidget {
  final Audiobook book;

  const PlayerScreen({super.key, required this.book});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late AudioPlayer _audioPlayer;
  bool isPlaying = false;
  bool isCompleted = false;
  Duration currentPosition = Duration.zero;
  Duration totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    currentPosition = widget.book.lastPosition;
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      if (widget.book.filePath != 'demo') {
        await _audioPlayer.setFilePath(widget.book.filePath);
        
        // Відновлюємо позицію
        if (widget.book.lastPosition.inSeconds > 0) {
          await _audioPlayer.seek(widget.book.lastPosition);
        }
      }

      _audioPlayer.positionStream.listen((position) {
        if (mounted) {
          setState(() {
            currentPosition = position;
          });
        }
      });

      _audioPlayer.durationStream.listen((duration) {
        if (duration != null && mounted) {
          setState(() {
            totalDuration = duration;
            if (widget.book.duration.inSeconds == 0) {
              widget.book.duration = duration;
            }
          });
        }
      });

      _audioPlayer.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            isPlaying = state.playing;
            if (state.processingState == ProcessingState.completed) {
              isPlaying = false;
              isCompleted = true;
              currentPosition = totalDuration;
              widget.book.lastPosition = totalDuration;
            } else {
              isCompleted = false;
            }
          });
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Помилка: $e', style: const TextStyle(fontSize: 22)),
            backgroundColor: AppColors.buttonRed,
          ),
        );
      }
    }
  }

  Future<void> _togglePlayPause() async {
    try {
      if (isCompleted) {
        await _audioPlayer.seek(Duration.zero);
        await _audioPlayer.play();
        setState(() {
          isCompleted = false;
          isPlaying = true;
        });
      } else if (isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Помилка: $e', style: const TextStyle(fontSize: 22)),
            backgroundColor: AppColors.buttonRed,
          ),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  Future<void> _savePositionAndExit() async {
    if (_audioPlayer.processingState != ProcessingState.idle) {
      await _audioPlayer.pause();
      widget.book.lastPosition = currentPosition;
    }
    if (mounted) {
      Navigator.pop(context, widget.book);
    }
  }

  @override
  void dispose() {
    _savePositionAndExit();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _savePositionAndExit();
        return false;
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: AppBar(
          title: GestureDetector(
            onTap: _savePositionAndExit,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.arrow_back,
                  color: Colors.black,
                  size: 64,
                  weight: 2400,
                ),
                const SizedBox(width: 8),
                const Text(
                  'ДО БІБЛІОТЕКИ',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          backgroundColor: const Color(0xFFFFEB3B),
          toolbarHeight: 90,
          centerTitle: false,
          elevation: 10,
          automaticallyImplyLeading: false,
          leading: null,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(35),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundMedium,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: AppColors.border, width: 3),
                  ),
                  child: Column(
                    children: [
                      Text(
                        widget.book.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textWhite,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        widget.book.author,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 28,
                          color: AppColors.textWhite70,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 50),
                Container(
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundMedium,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: totalDuration.inMilliseconds > 0
                          ? currentPosition.inMilliseconds / totalDuration.inMilliseconds
                          : 0,
                      backgroundColor: Colors.transparent,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.progressBar),
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(currentPosition),
                        style: const TextStyle(
                          fontSize: 28,
                          color: AppColors.textWhite,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatDuration(totalDuration),
                        style: const TextStyle(
                          fontSize: 28,
                          color: AppColors.textWhite,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 60),
                GestureDetector(
                  onTap: _togglePlayPause,
                  child: Container(
                    width: 300,
                    height: 150,
                    decoration: BoxDecoration( // Removed 'const' here
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.buttonBlue,
                          AppColors.buttonBlueDark,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.buttonBlue,
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        isCompleted && !isPlaying ? Icons.replay : (isPlaying ? Icons.pause : Icons.play_arrow),
                        size: 90,
                        color: AppColors.textWhite,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}