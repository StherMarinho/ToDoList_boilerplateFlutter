import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:share_plus/share_plus.dart';
import 'package:synergia_flutter_meteor_boilerplate/app/auth/auth_providers.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/example/data/example_repository.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/example/domain/example.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/example/domain/example_asset.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/example/domain/example_resources.dart';
import 'package:synergia_flutter_meteor_boilerplate/services/meteor/meteor_error_mapper.dart';
import 'package:synergia_flutter_meteor_boilerplate/services/meteor/meteor_transport.dart';

enum _AttachmentAction { open, share }

class ExampleDetailPage extends ConsumerStatefulWidget {
  const ExampleDetailPage({
    required this.exampleId,
    required this.editing,
    super.key,
  });

  final String? exampleId;
  final bool editing;

  bool get creating => exampleId == null;

  @override
  ConsumerState<ExampleDetailPage> createState() => _ExampleDetailPageState();
}

class _ExampleDetailPageState extends ConsumerState<ExampleDetailPage> {
  static const categories = ['Categoria A', 'Categoria B', 'Categoria C'];
  static const priorities = ['alta', 'media', 'baixa'];

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cpfController = TextEditingController();
  StreamSubscription<Example?>? _exampleListener;
  StreamSubscription<List<ExampleAsset>>? _assetListener;
  Example? _example;
  List<ExampleAsset> _assets = const [];
  late final String _documentId;
  final _recorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  bool _recording = false;
  String? _category;
  String? _priority;
  double _slider = 0;
  bool _statusToggle = false;
  bool _loading = false;
  bool _loadedForm = false;

  bool get _canEdit {
    if (widget.creating) {
      return ref.read(canAccessResourceProvider(ExampleResources.create));
    }
    if (widget.editing) {
      return ref.read(canAccessResourceProvider(ExampleResources.update));
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _documentId =
        widget.exampleId ?? ref.read(exampleRepositoryProvider).newId();
    _assetListener = ref
        .read(exampleRepositoryProvider)
        .watchAssets(_documentId)
        .listen((assets) {
          if (mounted) setState(() => _assets = assets);
        });
    if (widget.exampleId == null) {
      _category = categories.first;
      _priority = priorities.last;
      return;
    }
    _loading = true;
    Future<void>.microtask(_watchLocal);
  }

  void _watchLocal() {
    _exampleListener = ref
        .read(exampleRepositoryProvider)
        .watchExample(_documentId)
        .listen((example) {
          if (example == null || !mounted) return;
          setState(() {
            _example = example;
            _loading = false;
            if (!_loadedForm) {
              _loadedForm = true;
              _titleController.text = example.title;
              _descriptionController.text = example.description ?? '';
              _phoneController.text =
                  example.contacts['phone']?.toString() ?? '';
              _cpfController.text = example.contacts['cpf']?.toString() ?? '';
              _category = example.type;
              _priority = example.priority;
              _slider = example.slider;
              _statusToggle = example.statusToggle;
            }
          });
        });
    unawaited(ref.read(exampleRepositoryProvider).syncNow());
  }

  @override
  void dispose() {
    _exampleListener?.cancel();
    _assetListener?.cancel();
    _recorder.dispose();
    _audioPlayer.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _cpfController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final previous = _example;
    final document = Example(
      id: _documentId,
      title: _titleController.text,
      description: _descriptionController.text,
      type: _category!,
      priority: _priority!,
      image: previous?.image,
      date: previous?.date,
      check: previous?.check ?? const [],
      chips: previous?.chips ?? const [],
      files: previous?.files ?? const [],
      contacts: <String, dynamic>{
        if (_phoneController.text.trim().isNotEmpty)
          'phone': _phoneController.text.trim(),
        if (_cpfController.text.trim().isNotEmpty)
          'cpf': _cpfController.text.trim(),
      },
      tasks: previous?.tasks ?? const [],
      audio: previous?.audio,
      address: previous?.address ?? const {},
      slider: _slider,
      statusRadio: previous?.statusRadio,
      statusToggle: _statusToggle,
      createdAt: previous?.createdAt,
      lastUpdate: previous?.lastUpdate,
      createdBy: previous?.createdBy,
      updatedBy: previous?.updatedBy,
    );
    try {
      await ref.read(exampleRepositoryProvider).save(document);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Salvo no aparelho. A sincronização ocorrerá quando houver conexão.',
          ),
        ),
      );
      context.pop();
    } catch (error) {
      if (!mounted) return;
      final failure = MeteorErrorMapper.map(error);
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure.message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 88,
      maxWidth: 2048,
    );
    if (picked == null) return;
    await _addAsset(
      picked.path,
      ExampleAssetKind.image,
      _mimeFor(picked.name, fallback: 'image/jpeg'),
    );
  }

  Future<void> _pickFile(ExampleAssetKind kind) async {
    final result = await FilePicker.pickFiles(
      type: kind == ExampleAssetKind.audio ? FileType.audio : FileType.any,
      allowMultiple: true,
      withData: false,
    );
    for (final file in result?.files ?? const <PlatformFile>[]) {
      if (file.path == null) continue;
      await _addAsset(
        file.path!,
        kind,
        _mimeFor(
          file.name,
          fallback: kind == ExampleAssetKind.audio
              ? 'audio/mpeg'
              : 'application/octet-stream',
        ),
      );
    }
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      final recordedPath = await _recorder.stop();
      if (mounted) setState(() => _recording = false);
      if (recordedPath != null) {
        await _addAsset(recordedPath, ExampleAssetKind.audio, 'audio/mp4');
      }
      return;
    }
    if (!await _recorder.hasPermission()) return;
    final temp = await getTemporaryDirectory();
    final output = path.join(
      temp.path,
      'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: output,
    );
    if (mounted) setState(() => _recording = true);
  }

  Future<void> _addAsset(
    String sourcePath,
    ExampleAssetKind kind,
    String mimeType,
  ) async {
    try {
      await ref
          .read(exampleRepositoryProvider)
          .addAsset(
            exampleId: _documentId,
            sourcePath: sourcePath,
            kind: kind,
            mimeType: mimeType,
          );
      if (widget.creating && mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível adicionar: $error')),
      );
    }
  }

  String _mimeFor(String fileName, {required String fallback}) {
    final extension = path.extension(fileName).toLowerCase();
    return switch (extension) {
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      '.gif' => 'image/gif',
      '.m4a' || '.mp4' => 'audio/mp4',
      '.mp3' => 'audio/mpeg',
      '.wav' => 'audio/wav',
      '.ogg' => 'audio/ogg',
      '.pdf' => 'application/pdf',
      '.txt' => 'text/plain',
      _ => fallback,
    };
  }

  Future<void> _openAsset(ExampleAsset asset) async {
    var current = asset;
    final localFileExists =
        current.localPath != null && await File(current.localPath!).exists();
    if (!localFileExists) {
      if (!ref.read(meteorConnectedProvider) || current.remoteUrl == null) {
        return;
      }
      try {
        await ref.read(exampleRepositoryProvider).downloadAttachment(current);
        current =
            await ref.read(exampleRepositoryProvider).getAsset(asset.id) ??
            current;
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao baixar o arquivo: $error')),
        );
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Arquivo disponível offline. Toque novamente para abrir ou compartilhar.',
          ),
        ),
      );
      return;
    }
    if (current.localPath == null) return;
    if (current.kind == ExampleAssetKind.audio) {
      await _audioPlayer.play(DeviceFileSource(current.localPath!));
    } else if (current.kind == ExampleAssetKind.attachment) {
      await _showAttachmentActions(current);
    }
  }

  Future<void> _showAttachmentActions(ExampleAsset asset) async {
    final action = await showModalBottomSheet<_AttachmentAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Abrir com outro aplicativo'),
              subtitle: Text(asset.name),
              onTap: () => Navigator.pop(sheetContext, _AttachmentAction.open),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Compartilhar'),
              onTap: () => Navigator.pop(sheetContext, _AttachmentAction.share),
            ),
          ],
        ),
      ),
    );
    if (action == null || asset.localPath == null || !mounted) return;
    if (action == _AttachmentAction.open) {
      final result = await OpenFilex.open(
        asset.localPath!,
        type: asset.mimeType,
      );
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.type == ResultType.noAppToOpen
                  ? 'Nenhum aplicativo instalado consegue abrir este arquivo. Use Compartilhar para enviá-lo.'
                  : 'Não foi possível abrir o arquivo: ${result.message}',
            ),
          ),
        );
      }
      return;
    }

    final renderBox = context.findRenderObject() as RenderBox?;
    try {
      final shareDirectory = Directory(
        path.join((await getTemporaryDirectory()).path, 'example_share'),
      );
      await shareDirectory.create(recursive: true);
      final sharePath = path.join(
        shareDirectory.path,
        path.basename(asset.name),
      );
      await File(asset.localPath!).copy(sharePath);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(sharePath, mimeType: asset.mimeType)],
          subject: asset.name,
          sharePositionOrigin: renderBox == null
              ? null
              : renderBox.localToGlobal(Offset.zero) & renderBox.size,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível compartilhar: $error')),
      );
    }
  }

  Future<void> _resolveConflict({required bool keepLocal}) async {
    setState(() {
      _loading = true;
      _loadedForm = false;
    });
    try {
      final repository = ref.read(exampleRepositoryProvider);
      if (keepLocal) {
        await repository.resolveConflictKeepingLocal(_documentId);
      } else {
        await repository.resolveConflictWithServer(_documentId);
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            keepLocal
                ? 'Sua versão foi reenviada ao servidor.'
                : 'A versão do servidor foi restaurada.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível resolver o conflito: $error')),
      );
    }
  }

  Widget _buildConflictBanner(BuildContext context) {
    if (_example?.syncStatus != ExampleSyncStatus.conflict) {
      return const SizedBox.shrink();
    }
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Conflito de edição',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            const Text(
              'Este documento também mudou no servidor. Escolha conscientemente qual versão deve prevalecer.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _loading
                      ? null
                      : () => _resolveConflict(keepLocal: false),
                  child: const Text('Usar versão do servidor'),
                ),
                FilledButton(
                  onPressed: _loading
                      ? null
                      : () => _resolveConflict(keepLocal: true),
                  child: const Text('Manter minha versão'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetsSection(BuildContext context, {required bool online}) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 40),
        Text('Mídias e anexos', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(
          online
              ? 'Online — itens pendentes serão sincronizados automaticamente.'
              : 'Offline — você pode continuar trabalhando; os envios ficam na fila.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: online ? colors.primary : colors.onSurfaceVariant,
          ),
        ),
        if (_canEdit) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Câmera'),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Imagem'),
              ),
              OutlinedButton.icon(
                onPressed: _toggleRecording,
                icon: Icon(_recording ? Icons.stop : Icons.mic_none),
                style: _recording
                    ? OutlinedButton.styleFrom(foregroundColor: colors.error)
                    : null,
                label: Text(_recording ? 'Parar gravação' : 'Gravar áudio'),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickFile(ExampleAssetKind.audio),
                icon: const Icon(Icons.audio_file_outlined),
                label: const Text('Áudio'),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickFile(ExampleAssetKind.attachment),
                icon: const Icon(Icons.attach_file),
                label: const Text('Anexo'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        if (_assets.isEmpty)
          const Text('Nenhuma mídia ou anexo associado.')
        else
          ..._assets.map((asset) {
            final canOpen =
                asset.hasLocalCopy ||
                (online && asset.remoteUrl?.isNotEmpty == true);
            final remoteAttachment =
                asset.kind == ExampleAssetKind.attachment && asset.isRemoteOnly;
            return Card.outlined(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                enabled: canOpen,
                onTap: canOpen ? () => _openAsset(asset) : null,
                leading:
                    asset.kind == ExampleAssetKind.image &&
                        asset.localPath != null &&
                        File(asset.localPath!).existsSync()
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(
                          File(asset.localPath!),
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Icon(switch (asset.kind) {
                        ExampleAssetKind.image => Icons.image_outlined,
                        ExampleAssetKind.audio => Icons.graphic_eq,
                        ExampleAssetKind.attachment =>
                          Icons.description_outlined,
                      }),
                title: Text(
                  asset.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(switch (asset.status) {
                  ExampleAssetSyncStatus.localOnly => 'Pendente de envio',
                  ExampleAssetSyncStatus.uploading => 'Enviando…',
                  ExampleAssetSyncStatus.downloading => 'Baixando…',
                  ExampleAssetSyncStatus.failed =>
                    'Falha — será tentado novamente',
                  ExampleAssetSyncStatus.available
                      when remoteAttachment && !online =>
                    'Disponível no servidor — conecte-se para baixar',
                  ExampleAssetSyncStatus.available when remoteAttachment =>
                    'Disponível para baixar',
                  ExampleAssetSyncStatus.available => 'Disponível offline',
                }),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    if (remoteAttachment)
                      Icon(
                        asset.hasLocalCopy
                            ? Icons.offline_pin
                            : Icons.cloud_download_outlined,
                        color: canOpen ? colors.primary : colors.outline,
                      )
                    else if (asset.status == ExampleAssetSyncStatus.uploading ||
                        asset.status == ExampleAssetSyncStatus.downloading)
                      const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(
                        asset.status == ExampleAssetSyncStatus.available
                            ? Icons.cloud_done_outlined
                            : Icons.cloud_upload_outlined,
                        color: colors.primary,
                      ),
                    if (_canEdit)
                      IconButton(
                        tooltip: 'Remover',
                        onPressed: () => ref
                            .read(exampleRepositoryProvider)
                            .removeAsset(asset),
                        icon: const Icon(Icons.delete_outline),
                      ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(meteorConnectedProvider);
    final canUpdate = ref.watch(
      canAccessResourceProvider(ExampleResources.update),
    );
    if (widget.creating) {
      ref.watch(canAccessResourceProvider(ExampleResources.create));
    }
    final title = widget.creating
        ? 'Novo exemplo'
        : widget.editing
        ? 'Editar exemplo'
        : 'Detalhes do exemplo';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (!_canEdit && canUpdate && widget.exampleId != null)
            IconButton(
              tooltip: 'Editar',
              onPressed: () =>
                  context.pushReplacement('/examples/${widget.exampleId}/edit'),
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: _loading && _example == null && !widget.creating
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildConflictBanner(context),
                              if (_example?.syncStatus ==
                                  ExampleSyncStatus.conflict)
                                const SizedBox(height: 16),
                              TextFormField(
                                controller: _titleController,
                                enabled: _canEdit,
                                decoration: const InputDecoration(
                                  labelText: 'Nome',
                                ),
                                validator: (value) =>
                                    value?.trim().isEmpty == true
                                    ? 'Informe o nome'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _descriptionController,
                                enabled: _canEdit,
                                minLines: 3,
                                maxLines: 6,
                                decoration: const InputDecoration(
                                  labelText: 'Descrição',
                                ),
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                initialValue: _category,
                                decoration: const InputDecoration(
                                  labelText: 'Categoria',
                                ),
                                items: categories
                                    .map(
                                      (value) => DropdownMenuItem(
                                        value: value,
                                        child: Text(value),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _canEdit
                                    ? (value) =>
                                          setState(() => _category = value)
                                    : null,
                                validator: (value) => value == null
                                    ? 'Informe a categoria'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                initialValue: _priority,
                                decoration: const InputDecoration(
                                  labelText: 'Prioridade',
                                ),
                                items: priorities
                                    .map(
                                      (value) => DropdownMenuItem(
                                        value: value,
                                        child: Text(
                                          value[0].toUpperCase() +
                                              value.substring(1),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _canEdit
                                    ? (value) =>
                                          setState(() => _priority = value)
                                    : null,
                                validator: (value) => value == null
                                    ? 'Informe a prioridade'
                                    : null,
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Contatos',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _phoneController,
                                      enabled: _canEdit,
                                      keyboardType: TextInputType.phone,
                                      decoration: const InputDecoration(
                                        labelText: 'Telefone',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _cpfController,
                                      enabled: _canEdit,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'CPF',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Text('Slider: ${_slider.round()}'),
                              Slider(
                                value: _slider.clamp(0, 100),
                                max: 100,
                                divisions: 100,
                                label: _slider.round().toString(),
                                onChanged: _canEdit
                                    ? (value) => setState(() => _slider = value)
                                    : null,
                              ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Exigir comprovação'),
                                value: _statusToggle,
                                onChanged: _canEdit
                                    ? (value) =>
                                          setState(() => _statusToggle = value)
                                    : null,
                              ),
                              _buildAssetsSection(context, online: online),
                              if (_canEdit) ...[
                                const SizedBox(height: 24),
                                FilledButton.icon(
                                  onPressed: _loading ? null : _save,
                                  icon: _loading
                                      ? const SizedBox.square(
                                          dimension: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.save_outlined),
                                  label: const Text('Salvar'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
