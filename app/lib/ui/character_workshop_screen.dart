import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../game/components/player_component.dart';
import '../platform/character_workshop_api.dart';

class CharacterWorkshopScreen extends StatefulWidget {
  const CharacterWorkshopScreen({super.key});

  @override
  State<CharacterWorkshopScreen> createState() =>
      _CharacterWorkshopScreenState();
}

class _CharacterWorkshopScreenState extends State<CharacterWorkshopScreen> {
  static const _parts = [
    {
      'name': 'head',
      'role': 'head',
      'x': 13,
      'y': 1,
      'width': 6,
      'height': 6,
      'color': '#F2C078',
    },
    {
      'name': 'torso',
      'role': 'torso',
      'x': 11,
      'y': 9,
      'width': 10,
      'height': 7,
      'color': '#3366FF',
    },
    {
      'name': 'arm_left',
      'role': 'arm_left',
      'x': 8,
      'y': 10,
      'width': 2,
      'height': 6,
      'color': '#F2C078',
    },
    {
      'name': 'arm_right',
      'role': 'arm_right',
      'x': 22,
      'y': 10,
      'width': 2,
      'height': 6,
      'color': '#F2C078',
    },
    {
      'name': 'leg_left',
      'role': 'leg_left',
      'x': 11,
      'y': 18,
      'width': 3,
      'height': 14,
      'color': '#30384A',
    },
    {
      'name': 'leg_right',
      'role': 'leg_right',
      'x': 18,
      'y': 18,
      'width': 3,
      'height': 14,
      'color': '#30384A',
    },
  ];

  final _api = CharacterWorkshopApi();
  final _name = TextEditingController(text: 'New character');
  final _subject = TextEditingController();
  String _heightClass = 'average';
  final _view = TextEditingController(
    text: 'side view, facing right, full body, centered on a plain background',
  );
  final _head = TextEditingController();
  final _hairstyle = TextEditingController();
  bool _hasBeard = false;
  bool _hasHelmet = false;
  final _upperBody = TextEditingController();
  final _lowerBody = TextEditingController();
  final _leftHand = TextEditingController(text: 'empty');
  final _rightHand = TextEditingController(text: 'empty');
  final _palette = TextEditingController();
  final _styleTags = TextEditingController(text: '2D pixel');
  final _positive = TextEditingController();
  final _negative = TextEditingController(
    text: 'text, watermark, blurry, extra limbs, duplicate character',
  );
  final _characterLora = TextEditingController();
  final _seed = TextEditingController();
  final _rig = TextEditingController(
    text: const JsonEncoder.withIndent('  ').convert(_parts),
  );

  List<Map<String, dynamic>> _projects = [];
  Map<String, dynamic>? _project;
  String? _promptId;
  String _jobStatus = 'idle';
  Map<String, dynamic>? _jobProgress;
  String _comfyStatus = 'checking';
  String? _error;
  String? _publishNote;
  bool _busy = false;
  bool _polling = false;
  bool _playing = false;
  int _frame = 0;
  int _imageRevision = 0;
  Timer? _pollTimer;
  Timer? _playTimer;

  String? get _projectId => _project?['id'] as String?;
  bool get _approved => _project?['approved_image'] != null;
  bool get _hasAnimation => _project?['animation'] != null;
  double? get _jobProgressFraction {
    final value = _jobProgress?['fraction'];
    return value is num ? value.toDouble().clamp(0, 1).toDouble() : null;
  }

  String? get _jobProgressLabel {
    final step = _jobProgress?['step'];
    final total = _jobProgress?['total'];
    if (step is num && total is num) {
      return 'Sampling ${step.toInt()}/${total.toInt()}';
    }
    final node = _jobProgress?['node_id'];
    return node is String ? 'Running ComfyUI node $node' : null;
  }

  String get _qualitySummary {
    final animation = _project?['animation'];
    if (animation is! Map) return 'Quality report unavailable';
    final quality = animation['quality'];
    if (quality is! Map) return 'Quality report unavailable';
    final checks = quality['checks'];
    if (checks is! Map) return 'Quality report unavailable';
    final passed = checks.values.where((value) => value == true).length;
    return '$passed/${checks.length} quality checks passed';
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _playTimer?.cancel();
    _api.close();
    _name.dispose();
    _subject.dispose();
    _view.dispose();
    _head.dispose();
    _hairstyle.dispose();
    _upperBody.dispose();
    _lowerBody.dispose();
    _leftHand.dispose();
    _rightHand.dispose();
    _palette.dispose();
    _styleTags.dispose();
    _positive.dispose();
    _negative.dispose();
    _characterLora.dispose();
    _seed.dispose();
    _rig.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final results = await Future.wait([_api.health(), _api.listProjects()]);
      if (!mounted) return;
      setState(() {
        _comfyStatus =
            (results.first as Map<String, dynamic>)['comfyui'] as String? ??
            'offline';
        _projects = results.last as List<Map<String, dynamic>>;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  void _newProject() {
    _pollTimer?.cancel();
    _playTimer?.cancel();
    setState(() {
      _project = null;
      _promptId = null;
      _jobStatus = 'idle';
      _jobProgress = null;
      _frame = 0;
      _name.text = 'New character';
      _subject.clear();
      _heightClass = 'average';
      _view.text =
          'side view, facing right, full body, centered on a plain background';
      _head.clear();
      _hairstyle.clear();
      _hasBeard = false;
      _hasHelmet = false;
      _upperBody.clear();
      _lowerBody.clear();
      _leftHand.text = 'empty';
      _rightHand.text = 'empty';
      _palette.clear();
      _styleTags.text = '2D pixel';
      _positive.clear();
      _negative.text =
          'text, watermark, blurry, extra limbs, duplicate character';
      _characterLora.clear();
      _seed.clear();
      _rig.text = const JsonEncoder.withIndent('  ').convert(_parts);
      _error = null;
    });
  }

  void _selectProject(Map<String, dynamic> value) {
    _pollTimer?.cancel();
    _playTimer?.cancel();
    final candidates = (value['candidates'] as List? ?? const [])
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
    final latest = candidates.isEmpty ? null : candidates.last;
    setState(() {
      _project = value;
      _name.text = value['name'] as String? ?? '';
      _subject.text = value['subject'] as String? ?? '';
      _heightClass = value['height_class'] as String? ?? 'average';
      _view.text =
          value['view'] as String? ??
          'side view, facing right, full body, centered on a plain background';
      _head.text = value['head'] as String? ?? '';
      _hairstyle.text = value['hairstyle'] as String? ?? '';
      _hasBeard = value['has_beard'] as bool? ?? false;
      _hasHelmet = value['has_helmet'] as bool? ?? false;
      _upperBody.text = value['upper_body'] as String? ?? '';
      _lowerBody.text = value['lower_body'] as String? ?? '';
      _leftHand.text = value['left_hand'] as String? ?? 'empty';
      final legacyHeldItem = (value['held_item'] as String? ?? '').trim();
      _rightHand.text =
          value['right_hand'] as String? ??
          (legacyHeldItem.isNotEmpty ? legacyHeldItem : 'empty');
      _palette.text = value['palette'] as String? ?? '';
      final savedStyleTags = (value['style_tags'] as String? ?? '').trim();
      _styleTags.text = savedStyleTags.isEmpty ? '2D pixel' : savedStyleTags;
      _positive.text = value['positive_prompt'] as String? ?? '';
      _negative.text = value['negative_prompt'] as String? ?? '';
      _characterLora.text = value['character_lora'] as String? ?? '';
      _seed.text = '${value['seed'] ?? ''}';
      _rig.text = const JsonEncoder.withIndent('  ')
          .convert(value['parts'] ?? _parts);
      _promptId = latest?['prompt_id'] as String?;
      _jobStatus = latest?['status'] as String? ?? 'idle';
      _jobProgress = null;
      _frame = 0;
      _imageRevision++;
      _error = null;
    });
    if (_promptId != null && _jobStatus != 'completed') _startPolling();
  }

  List<Map<String, dynamic>> _readParts() => (jsonDecode(_rig.text) as List)
      .map((part) => Map<String, dynamic>.from(part as Map))
      .toList();

  Map<String, dynamic> _payload() {
    final data = <String, dynamic>{
      'name': _name.text.trim(),
      'subject': _subject.text.trim(),
      'height_class': _heightClass,
      'background': 'transparent',
      'view': _view.text.trim(),
      'head': _head.text.trim(),
      'hairstyle': _hairstyle.text.trim(),
      'has_beard': _hasBeard,
      'has_helmet': _hasHelmet,
      'upper_body': _upperBody.text.trim(),
      'lower_body': _lowerBody.text.trim(),
      'left_hand': _leftHand.text.trim(),
      'right_hand': _rightHand.text.trim(),
      'palette': _palette.text.trim(),
      'style_tags': _styleTags.text.trim(),
      'positive_prompt': _positive.text.trim(),
      'negative_prompt': _negative.text.trim(),
      'character_lora': _characterLora.text.trim(),
      'parts': _readParts(),
    };
    final seed = int.tryParse(_seed.text.trim());
    if (seed != null) data['seed'] = seed;
    return data;
  }

  Future<Map<String, dynamic>> _saveProject() async {
    final payload = _payload();
    final wasNewProject = _projectId == null;
    _project = wasNewProject
        ? await _api.createProject(payload)
        : await _api.updateProject(_projectId!, payload);
    _seed.text = '${_project!['seed']}';
    if (wasNewProject) {
      // The server picks rig geometry from height_class on creation; the
      // locally-edited placeholder rig must not overwrite it on the next save.
      _rig.text = const JsonEncoder.withIndent('  ')
          .convert(_project!['parts']);
    }
    await _refresh();
    return _project!;
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _generate() => _run(() async {
    final project = await _saveProject();
    final result = await _api.generate(project['id'] as String);
    _promptId = result['prompt_id'] as String;
    _jobStatus = 'queued';
    _jobProgress = null;
    _imageRevision++;
    _startPolling();
  });

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollJob());
    _pollJob();
  }

  Future<void> _pollJob() async {
    if (_polling || _projectId == null || _promptId == null) return;
    _polling = true;
    try {
      final job = await _api.job(_projectId!, _promptId!);
      if (!mounted) return;
      setState(() {
        _jobStatus = job['status'] as String? ?? 'running';
        final progress = job['progress'];
        _jobProgress = progress is Map
            ? Map<String, dynamic>.from(progress)
            : null;
        if (_jobStatus == 'completed') _imageRevision++;
        if (_jobStatus == 'error') {
          _error = '${job['error'] ?? 'ComfyUI job failed'}';
        }
      });
      if (_jobStatus == 'completed' || _jobStatus == 'error') {
        _pollTimer?.cancel();
        await _refresh();
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      _polling = false;
    }
  }

  Future<void> _approve() async {
    if (_projectId == null || _promptId == null) return;
    await _run(() async {
      _project = await _api.approve(_projectId!, _promptId!);
      _imageRevision++;
      await _refresh();
    });
  }

  Future<void> _animate() async {
    if (_projectId == null) return;
    await _run(() async {
      await _saveProject();
      final animation = await _api.animate(_projectId!, _readParts());
      _project = {..._project!, 'animation': animation};
      _frame = 0;
      _imageRevision++;
      await _refresh();
    });
  }

  Future<void> _publish() async {
    if (_projectId == null) return;
    await _run(() async {
      final result = await _api.publish(_projectId!);
      final live = await _activatePublishedSheet(
        result['character_id'] as String?,
      );
      setState(() {
        final target = result['sheet_asset'];
        _publishNote = live
            ? 'Copied to $target and activated for this session. '
                  'It is also registered in pubspec.yaml for future builds.'
            : 'Copied to $target. Restart the game to load it from assets.';
      });
    });
  }

  /// Loads the published sheet straight into the running game so the character
  /// is playable before the rebuild a new bundled asset folder would need.
  Future<bool> _activatePublishedSheet(String? characterId) async {
    if (_projectId == null) return false;
    try {
      final response = await http.get(
        _api.animationGameSheetUri(_projectId!, _imageRevision),
      );
      if (response.statusCode != 200) return false;
      final codec = await ui.instantiateImageCodec(response.bodyBytes);
      final frame = await codec.getNextFrame();
      PlayerComponent.runtimeSheetImage = frame.image;
      PlayerComponent.runtimeSheetLabel = characterId;
      return true;
    } catch (_) {
      return false;
    }
  }

  void _togglePlayback() {
    if (_playing) {
      _playTimer?.cancel();
      setState(() => _playing = false);
    } else {
      setState(() => _playing = true);
      _playTimer = Timer.periodic(const Duration(milliseconds: 140), (_) {
        if (mounted) setState(() => _frame = (_frame + 1) % 13);
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF10131A),
    appBar: AppBar(
      title: const Text('Character Workshop'),
      backgroundColor: const Color(0xFF10131A),
      actions: [
        Icon(
          Icons.circle,
          size: 9,
          color: _comfyStatus == 'online'
              ? const Color(0xFF54D6C8)
              : Colors.orange,
        ),
        const SizedBox(width: 7),
        Center(
          child: Text(
            'ComfyUI $_comfyStatus',
            style: const TextStyle(fontSize: 12),
          ),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: Column(
      children: [
        SizedBox(
          height: 58,
          child: Row(
            children: [
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _newProject,
                icon: const Icon(Icons.add),
                label: const Text('New'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _projects
                      .map(
                        (project) => Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 3,
                            vertical: 8,
                          ),
                          child: ChoiceChip(
                            label: Text('${project['name']}'),
                            selected: project['id'] == _projectId,
                            onSelected: (_) => _selectProject(project),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              final form = _formPanel();
              final preview = _previewPanel();
              return wide
                  ? Row(
                      children: [
                        Expanded(flex: 3, child: form),
                        const VerticalDivider(width: 1),
                        Expanded(flex: 2, child: preview),
                      ],
                    )
                  : ListView(children: [form, const Divider(), preview]);
            },
          ),
        ),
        if (_busy) const LinearProgressIndicator(minHeight: 2),
      ],
    ),
  );

  Widget _formPanel() => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      if (_error != null) _message(_error!, error: true),
      if (_comfyStatus != 'online')
        _message('Start ComfyUI before generating a concept.'),
      const Text(
        'Character brief',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 12),
      _field(_name, 'Project name'),
      _field(_subject, 'Subject (short summary)'),
      const Padding(
        padding: EdgeInsets.only(bottom: 4),
        child: Text(
          'Height / build',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'short', label: Text('Short (dwarf)')),
            ButtonSegment(value: 'average', label: Text('Average (human)')),
            ButtonSegment(value: 'tall', label: Text('Tall (elf)')),
          ],
          selected: {_heightClass},
          onSelectionChanged: (selection) =>
              setState(() => _heightClass = selection.first),
        ),
      ),
      const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: Color(0xFF54D6C8),
              size: 18,
            ),
            SizedBox(width: 8),
            Text(
              'Background: transparent (fixed)',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
      _field(_view, 'View / orientation'),
      _field(_head, 'Head (face shape, eyes, other headwear)'),
      _field(_hairstyle, 'Hairstyle', hint: 'e.g. short cropped hair, bald'),
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Expanded(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Beard'),
                value: _hasBeard,
                onChanged: (value) => setState(() => _hasBeard = value),
              ),
            ),
            Expanded(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Helmet'),
                value: _hasHelmet,
                onChanged: (value) => setState(() => _hasHelmet = value),
              ),
            ),
          ],
        ),
      ),
      _field(_upperBody, 'Upper body (torso, arms, armor)'),
      _field(_lowerBody, 'Lower body (legs, pants, boots)'),
      _field(
        _leftHand,
        'Character left hand (item or empty)',
        hint: 'This means the character\'s own left hand, not image-left',
      ),
      _field(
        _rightHand,
        'Character right hand (item or empty)',
        hint: 'This means the character\'s own right hand, not image-right',
      ),
      _field(_palette, 'Color palette'),
      _field(_styleTags, 'Style tags'),
      _field(
        _positive,
        'Extra notes (optional)',
        maxLines: 3,
        hint: 'Anything not covered above',
      ),
      _field(_negative, 'Negative prompt', maxLines: 2),
      _field(
        _characterLora,
        'Character LoRA filename (optional)',
        hint:
            'A trained SD 1.5 LoRA in ComfyUI/models/loras; blank disables it',
      ),
      _field(
        _seed,
        'Seed (blank assigns one)',
        keyboardType: TextInputType.number,
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => _run(() async {
                    await _saveProject();
                  }),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save project'),
          ),
          FilledButton.icon(
            onPressed: _busy || _comfyStatus != 'online' ? null : _generate,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Generate concept'),
          ),
        ],
      ),
      const SizedBox(height: 24),
      const Text(
        'Aseprite rig',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 4),
      const Text(
        'Edit the exact pose rectangles. ControlNet renders each pose in one batch, then the original alpha masks preserve the silhouette.',
        style: TextStyle(color: Colors.white60, fontSize: 12),
      ),
      const SizedBox(height: 10),
      _field(_rig, 'Parts JSON', maxLines: 12, monospace: true),
      const SizedBox(height: 10),
      FilledButton.tonalIcon(
        onPressed: _busy || !_approved ? null : _animate,
        icon: const Icon(Icons.animation),
        label: const Text('Render 13-frame animation'),
      ),
      const SizedBox(height: 10),
      FilledButton.tonalIcon(
        onPressed: _busy || !_hasAnimation ? null : _publish,
        icon: const Icon(Icons.publish),
        label: const Text('Publish to game'),
      ),
      if (_publishNote != null) ...[
        const SizedBox(height: 6),
        Text(
          _publishNote!,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ],
    ],
  );

  Widget _previewPanel() => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      const Text(
        'Concept review',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 4),
      Text(
        _promptId == null
            ? 'Generate a concept to review.'
            : 'Job: $_jobStatus',
        style: const TextStyle(color: Colors.white60),
      ),
      if (_promptId != null &&
          _jobStatus == 'completed' &&
          _projectId != null) ...[
        const SizedBox(height: 12),
        Image.network(
          _api
              .candidateImageUri(_projectId!, _promptId!, _imageRevision)
              .toString(),
          height: 320,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stack) => _message(
            'Candidate image could not be loaded: $error',
            error: true,
          ),
        ),
        OutlinedButton.icon(
          onPressed: _busy ? null : _approve,
          icon: const Icon(Icons.verified_outlined),
          label: const Text('Approve candidate'),
        ),
      ] else if (_jobStatus == 'queued' || _jobStatus == 'running')
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              LinearProgressIndicator(value: _jobProgressFraction),
              const SizedBox(height: 8),
              Text(
                _jobProgressLabel ?? 'Waiting for ComfyUI…',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ),
      if (_approved && _projectId != null) ...[
        const SizedBox(height: 16),
        const Text(
          'Approved reference',
          style: TextStyle(color: Color(0xFF54D6C8)),
        ),
        const SizedBox(height: 8),
        Image.network(
          _api.approvedImageUri(_projectId!, _imageRevision).toString(),
          height: 180,
          fit: BoxFit.contain,
        ),
      ],
      if (_hasAnimation && _projectId != null) ...[
        const Divider(height: 28),
        Row(
          children: [
            const Expanded(
              child: Text(
                '13-frame playback',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton.filledTonal(
              tooltip: _playing ? 'Pause' : 'Play',
              onPressed: _togglePlayback,
              icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
            ),
            Text('${_frame + 1}/13'),
          ],
        ),
        Slider(
          min: 0,
          max: 12,
          divisions: 12,
          value: _frame.toDouble(),
          onChanged: (value) => setState(() {
            _frame = value.round();
            _playing = false;
            _playTimer?.cancel();
          }),
        ),
        _FramePreview(
          url: _api.animationSheetUri(_projectId!, _imageRevision).toString(),
          frame: _frame,
        ),
        ExpansionTile(
          leading: const Icon(Icons.grid_view_outlined),
          title: const Text('Quality contact sheet'),
          children: [
            Image.network(
              _api
                  .animationContactSheetUri(_projectId!, _imageRevision)
                  .toString(),
              height: 320,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) => _message(
                'Contact sheet could not be loaded: $error',
                error: true,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _qualitySummary,
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    ],
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    String? hint,
    TextInputType? keyboardType,
    bool monospace = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(
        fontFamily: monospace ? 'monospace' : null,
        fontSize: monospace ? 12 : 14,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFF171B25),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    ),
  );

  Widget _message(String text, {bool error = false}) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: error ? const Color(0xFF472529) : const Color(0xFF332B1C),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: error ? const Color(0xFFFF8A80) : const Color(0xFFFFD180),
      ),
    ),
  );
}

class _FramePreview extends StatelessWidget {
  const _FramePreview({required this.url, required this.frame});

  final String url;
  final int frame;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final side = (constraints.maxWidth - 4).clamp(120.0, 320.0);
      return SizedBox(
        width: side,
        height: side,
        child: ClipRect(
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                left: -frame * side,
                top: 0,
                width: side * 13,
                height: side,
                child: Image.network(
                  url,
                  width: side * 13,
                  height: side,
                  fit: BoxFit.fill,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
