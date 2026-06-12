import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';


class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'APOD',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B1020),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const ApodHomePage(),
    );
  }
}

class ApodHomePage extends StatefulWidget {
  const ApodHomePage({super.key});

  @override
  State<ApodHomePage> createState() => _ApodHomePageState();
}

class _ApodHomePageState extends State<ApodHomePage> {
  static const String _apiKey = String.fromEnvironment(
    'API_KEY',
    defaultValue: '',
  );
  static const String _savedApodsKey = 'saved_apods';
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  ApodData? _apod;
  bool _isLoading = true;
  String? _error;
  DateTime _selectedDate = DateTime.now();
  bool _useHd = true;
  List<ApodData> _savedApods = <ApodData>[];

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  Future<void> _initializePage() async {
    await _loadSavedApods();
    await _loadApod();
  }

  Future<void> _loadSavedApods() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> rawApods =
        prefs.getStringList(_savedApodsKey) ?? <String>[];
    final List<ApodData> parsedApods = rawApods
        .map((rawApod) {
          try {
            final dynamic decoded = jsonDecode(rawApod);
            if (decoded is Map<String, dynamic>) {
              return ApodData.fromJson(decoded);
            }
            if (decoded is Map) {
              return ApodData.fromJson(Map<String, dynamic>.from(decoded));
            }
            return null;
          } catch (_) {
            return null;
          }
        })
        .whereType<ApodData>()
        .toList();

    parsedApods.sort((a, b) => b.date.compareTo(a.date));

    if (!mounted) return;
    setState(() {
      _savedApods = parsedApods;
    });
  }

  Future<void> _persistSavedApods() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> serializedApods = _savedApods
        .map((savedApod) => jsonEncode(savedApod.toJson()))
        .toList();
    await prefs.setStringList(_savedApodsKey, serializedApods);
  }

  bool get _isCurrentDaySaved {
    final String? apodDate = _apod?.date;
    if (apodDate == null || apodDate.isEmpty) return false;
    return _savedApods.any((savedApod) => savedApod.date == apodDate);
  }

  Future<void> _toggleSaveCurrentDay() async {
    if (_apod == null) return;

    final ApodData currentApod = _apod!;
    final bool alreadySaved =
        _savedApods.any((savedApod) => savedApod.date == currentApod.date);

    setState(() {
      if (alreadySaved) {
        _savedApods.removeWhere(
          (savedApod) => savedApod.date == currentApod.date,
        );
      } else {
        _savedApods.removeWhere(
          (savedApod) => savedApod.date == currentApod.date,
        );
        _savedApods.insert(0, currentApod);
        _savedApods.sort((a, b) => b.date.compareTo(a.date));
      }
    });

    await _persistSavedApods();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          alreadySaved
              ? 'Removed ${currentApod.date} from saved days.'
              : 'Saved ${currentApod.date}.',
        ),
      ),
    );
  }

  Future<void> _openSavedApod(ApodData savedApod) async {
    final DateTime? parsedDate = DateTime.tryParse(savedApod.date);
    if (parsedDate == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open this saved day due to an invalid date.'),
        ),
      );
      return;
    }
    await _loadApod(parsedDate);
  }

  Future<void> _openSavedApodsScreen() async {
    final ApodData? selectedApod = await Navigator.push<ApodData>(
      context,
      MaterialPageRoute(
        builder: (_) => SavedApodsPage(
          savedApods: _savedApods,
          currentApodDate: _apod?.date,
        ),
      ),
    );

    if (selectedApod == null) return;
    await _openSavedApod(selectedApod);
  }

  Future<void> _loadApod([DateTime? date]) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final DateTime targetDate = date ?? _selectedDate;
    final String formattedDate = _dateFormat.format(targetDate);
    final Uri uri = Uri.parse(
      'https://api.nasa.gov/planetary/apod?api_key=$_apiKey&date=$formattedDate',
    );

    try {
      final http.Response response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }

      final Map<String, dynamic> json =
          jsonDecode(response.body) as Map<String, dynamic>;
      final ApodData apod = ApodData.fromJson(json);

      if (!mounted) return;
      setState(() {
        _apod = apod;
        _selectedDate = targetDate;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load APOD: $error';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1995, 6, 16),
      lastDate: now,
    );

    if (picked != null) {
      await _loadApod(picked);
    }
  }

  Future<void> _loadRandomApod() async {
    final DateTime firstApodDate = DateTime(1995, 6, 16);
    final DateTime today = DateTime.now();
    final int availableDays = today.difference(firstApodDate).inDays;
    final int randomOffset = Random().nextInt(availableDays + 1);
    final DateTime randomDate = firstApodDate.add(
      Duration(days: randomOffset),
    );
    await _loadApod(randomDate);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('APOD'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadRandomApod,
            tooltip: 'Random day',
            icon: const Icon(Icons.casino),
          ),
          IconButton(
            onPressed: _openSavedApodsScreen,
            tooltip: 'Saved APODs',
            icon: const Icon(Icons.bookmarks),
          ),
          IconButton(
            onPressed: _isLoading ? null : _loadApod,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _loadApod)
              : _apod == null
                  ? const Center(child: Text('No data available.'))
                  : _ApodDetailView(
                      apod: _apod!,
                      selectedDate: _selectedDate,
                      onPickDate: _pickDate,
                      useHd: _useHd,
                      isSaved: _isCurrentDaySaved,
                      onToggleSave: _toggleSaveCurrentDay,
                      onToggleHd: (value) {
                        setState(() {
                          _useHd = value;
                        });
                      },
                    ),
    );
  }
}

class _ApodDetailView extends StatelessWidget {
  const _ApodDetailView({
    required this.apod,
    required this.selectedDate,
    required this.onPickDate,
    required this.useHd,
    required this.isSaved,
    required this.onToggleSave,
    required this.onToggleHd,
  });

  final ApodData apod;
  final DateTime selectedDate;
  final Future<void> Function() onPickDate;
  final bool useHd;
  final bool isSaved;
  final Future<void> Function() onToggleSave;
  final ValueChanged<bool> onToggleHd;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String imageUrl = apod.imageUrl(useHd);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth >= 900;
        final Widget media = apod.mediaType == 'image'
            ? _ImagePanel(url: imageUrl, title: apod.title)
            : _VideoPanel(url: apod.url);

        final Widget details = _DetailsPanel(
          apod: apod,
          selectedDate: selectedDate,
          onPickDate: onPickDate,
          useHd: useHd,
          isSaved: isSaved,
          onToggleSave: onToggleSave,
          onToggleHd: onToggleHd,
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: media),
              const SizedBox(width: 24),
              Expanded(child: details),
            ],
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                apod.title,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              media,
              const SizedBox(height: 16),
              details,
            ],
          ),
        );
      },
    );
  }
}

class _ImagePanel extends StatelessWidget {
  const _ImagePanel({
    required this.url,
    required this.title,
  });

  final String url;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 16,
      ),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              opaque: false,
              pageBuilder: (_, __, ___) {
                return _FullscreenImageViewer(
                  imageUrl: url,
                  heroTag: url,
                );
              },
            ),
          );
        },
        child: Hero(
          tag: url,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                url,
                fit: BoxFit.cover,
                webHtmlElementStrategy:
                    WebHtmlElementStrategy.prefer,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) {
                    return child;
                  }

                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Text(
                      'Could not load image.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FullscreenImageViewer extends StatefulWidget {
  const _FullscreenImageViewer({
    required this.imageUrl,
    required this.heroTag,
  });

  final String imageUrl;
  final String heroTag;

  @override
  State<_FullscreenImageViewer> createState() =>
      _FullscreenImageViewerState();
}

class _FullscreenImageViewerState
    extends State<_FullscreenImageViewer> {
  final TransformationController _transformationController =
      TransformationController();

  TapDownDetails? _doubleTapDetails;

  void _handleDoubleTap() {
    if (_transformationController.value != Matrix4.identity()) {
      _transformationController.value = Matrix4.identity();
    } else {
      final position = _doubleTapDetails!.localPosition;

      _transformationController.value = Matrix4.identity()
        ..translate(-position.dx * 2, -position.dy * 2)
        ..scale(3.0);
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: GestureDetector(
              onDoubleTapDown: (details) {
                _doubleTapDetails = details;
              },
              onDoubleTap: _handleDoubleTap,
              child: InteractiveViewer(
                transformationController:
                    _transformationController,
                minScale: 1,
                maxScale: 5,
                child: Hero(
                  tag: widget.heroTag,
                  child: Image.network(
                    widget.imageUrl,
                    fit: BoxFit.contain,
                    webHtmlElementStrategy:
                        WebHtmlElementStrategy.prefer,
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            top: 20,
            right: 20,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 32,
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoPanel extends StatefulWidget {
  const _VideoPanel({required this.url});

  final String url;

  @override
  State<_VideoPanel> createState() => _VideoPanelState();
}


class _VideoPanelState extends State<_VideoPanel> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();

    final videoId = YoutubePlayerController.convertUrlToId(widget.url);

    _controller = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
      ),
    );

    _controller.loadVideoById(videoId: videoId ?? '');
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF141B35),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text(
          //   'This APOD entry is a video.',
          //   style: Theme.of(context).textTheme.titleMedium,
          // ),

          const SizedBox(height: 16),

          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: YoutubePlayer(
                controller: _controller,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsPanel extends StatelessWidget {
  const _DetailsPanel({
    required this.apod,
    required this.selectedDate,
    required this.onPickDate,
    required this.useHd,
    required this.isSaved,
    required this.onToggleSave,
    required this.onToggleHd,
  });

  final ApodData apod;
  final DateTime selectedDate;
  final Future<void> Function() onPickDate;
  final bool useHd;
  final bool isSaved;
  final Future<void> Function() onToggleSave;
  final ValueChanged<bool> onToggleHd;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  apod.title,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: onPickDate,
                icon: const Icon(Icons.calendar_month),
                label: Text(DateFormat('MMM d, yyyy').format(selectedDate)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Chip(
                label: Text(apod.mediaType.toUpperCase()),
              ),
              const SizedBox(width: 8),
              if (apod.copyright != null)
                Chip(
                  label: Text('(c) ${apod.copyright}'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onToggleSave,
            icon: Icon(isSaved ? Icons.bookmark_remove : Icons.bookmark_add),
            label: Text(isSaved ? 'Unsave day' : 'Save day'),
          ),
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            value: useHd,
            onChanged: apod.hdUrl == null ? null : onToggleHd,
            title: const Text('Use HD image when available'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          Text(
            apod.explanation,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

class SavedApodsPage extends StatelessWidget {
  const SavedApodsPage({
    super.key,
    required this.savedApods,
    required this.currentApodDate,
  });

  final List<ApodData> savedApods;
  final String? currentApodDate;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved APODs'),
      ),
      body: savedApods.isEmpty
          ? Center(
              child: Text(
                'No saved days yet.',
                style: theme.textTheme.bodyLarge,
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: savedApods.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final ApodData savedApod = savedApods[index];
                final DateTime? savedDate = DateTime.tryParse(savedApod.date);
                final bool isCurrentDay = savedApod.date == currentApodDate;

                return Card(
                  elevation: 0,
                  color: isCurrentDay
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest.withOpacity(
                          0.35,
                        ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    onTap: () => Navigator.pop(context, savedApod),
                    title: Text(
                      savedApod.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      savedDate == null
                          ? savedApod.date
                          : DateFormat('MMM d, yyyy').format(savedDate),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios),
                  ),
                );
              },
            ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class ApodData {
  const ApodData({
    required this.title,
    required this.explanation,
    required this.url,
    required this.mediaType,
    required this.date,
    this.hdUrl,
    this.copyright,
  });

  final String title;
  final String explanation;
  final String url;
  final String mediaType;
  final String date;
  final String? hdUrl;
  final String? copyright;

  factory ApodData.fromJson(Map<String, dynamic> json) {
    return ApodData(
      title: json['title'] as String? ?? 'Untitled',
      explanation: json['explanation'] as String? ?? 'No explanation available.',
      url: json['url'] as String? ?? '',
      mediaType: json['media_type'] as String? ?? 'image',
      date: json['date'] as String? ?? '',
      hdUrl: json['hdurl'] as String?,
      copyright: json['copyright'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'explanation': explanation,
      'url': url,
      'media_type': mediaType,
      'date': date,
      'hdurl': hdUrl,
      'copyright': copyright,
    };
  }

  String imageUrl(bool useHd) {
    if (!useHd) return url;
    return hdUrl ?? url;
  }
}