import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synergia_flutter_meteor_boilerplate/app/auth/auth_providers.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/to_dos/data/to_dos_repository.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/to_dos/domain/to_do.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/to_dos/domain/to_do_resources.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/to_dos/presentation/components/to_do_form.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/user_profile/presentation/user_profile_providers.dart';
import 'package:synergia_flutter_meteor_boilerplate/shared/widgets/app_scaffold.dart';

class ToDoDetailPage extends ConsumerStatefulWidget {
  const ToDoDetailPage({
    required this.todoId,
    required this.editing,
    super.key,
  });

  final String? todoId;
  final bool editing;

  bool get creating => todoId == null;

  @override
  ConsumerState<ToDoDetailPage> createState() => _ToDoDetailPageState();
}

class _ToDoDetailPageState extends ConsumerState<ToDoDetailPage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  StreamSubscription<ToDo?>? _collectionListener;

  ToDo? _todo;
  ToDoPriority _priority = ToDoPriority.low;
  DateTime? _deadline;
  bool _personal = false;
  bool _loading = false;
  bool _formInitialized = false;
  bool _notFoundOrDenied = false;

  @override
  void initState() {
    super.initState();

    if (!widget.creating) {
      Future<void>.microtask(_load);
    }
  }

  @override
  void dispose() {
    _collectionListener?.cancel();
    ref.read(toDosRepositoryProvider).stopDetail();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = widget.todoId;

    if (id == null) return;

    setState(() => _loading = true);

    final repository = ref.read(toDosRepositoryProvider);

    _collectionListener = repository.watchDetailTodo(id).listen((todo) {
      if (!mounted) return;

      if (todo == null) {
        if (_formInitialized) {
          setState(() {
            _todo = null;
            _loading = false;
            _notFoundOrDenied = true;
          });
        }

        return;
      }

      _acceptTodo(todo);
    });

    try {
      final current = await repository.subscribeDetail(id);

      if (!mounted) return;

      if (current != null) {
        _acceptTodo(current);
        return;
      }

      setState(() {
        _loading = false;
        _notFoundOrDenied = true;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() => _loading = false);
      _showFailure(error);
    }
  }

  void _acceptTodo(ToDo todo) {
    if (!mounted) return;

    setState(() {
      _todo = todo;
      _loading = false;
      _notFoundOrDenied = false;

      if (!_formInitialized) {
        _formInitialized = true;
        _descriptionController.text = todo.description;
        _priority = todo.priority;
        _deadline = todo.deadline;
        _personal = todo.personal;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    final document = ToDo(
      id: widget.todoId ?? '',
      description: _descriptionController.text,
      priority: _priority,
      deadline: _deadline,
      personal: _personal,
      completed: _todo?.completed ?? false,
      completedAt: _todo?.completedAt,
      authorName: _todo?.authorName,
      createdBy: _todo?.createdBy,
      createdAt: _todo?.createdAt,
      lastUpdate: _todo?.lastUpdate,
    );

    try {
      final id = await ref.read(toDosRepositoryProvider).save(document);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tarefa salva com sucesso.'),
        ),
      );

      if (widget.creating && id != null) {
        context.go('/to-dos');
      } else {
        context.pop();
      }
    } catch (error) {
      if (!mounted) return;

      setState(() => _loading = false);
      _showFailure(error);
    }
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now(),
      firstDate: DateTime.now().subtract(
        const Duration(days: 365),
      ),
      lastDate: DateTime.now().add(
        const Duration(days: 365 * 5),
      ),
    );

    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }

  void _showFailure(Object error) {
    if (!mounted) return;

    final message = error is Exception
        ? error.toString()
        : 'Ocorreu um erro.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProfileProvider);

    final owns =
        widget.creating || _todo?.isOwnedBy(profile?.id) == true;

    final hasResource = ref.watch(
      canAccessResourceProvider(
        widget.creating
            ? ToDoResources.create
            : ToDoResources.update,
      ),
    );

    final canEdit = widget.editing && owns && hasResource;

    final title = widget.creating
        ? 'Nova tarefa'
        : widget.editing
            ? 'Editar tarefa'
            : 'Detalhes da tarefa';

    if (_loading) {
      return AppScaffold(
        title: title,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_notFoundOrDenied) {
      return AppScaffold(
        title: title,
        body: const Center(
          child: Text(
            'Tarefa não encontrada ou sem permissão de acesso.',
          ),
        ),
      );
    }

    return AppScaffold(
      title: title,
      actions: [
        if (canEdit)
          _loading
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                )
              : IconButton(
                  tooltip: 'Salvar',
                  onPressed: _save,
                  icon: const Icon(Icons.check),
                ),
        if (!widget.editing &&
            !widget.creating &&
            _todo != null)
          IconButton(
            tooltip: 'Editar',
            onPressed: () => context.push(
              '/to-dos/${widget.todoId}/edit',
            ),
            icon: const Icon(Icons.edit_outlined),
          ),
      ],
      body: ToDoForm(
        formKey: _formKey,
        descriptionController: _descriptionController,
        priority: _priority,
        deadline: _deadline,
        personal: _personal,
        todo: _todo,
        canEdit: canEdit,
        onPriorityChanged: (value) {
          setState(() => _priority = value ?? _priority);
        },
        onPickDeadline: _pickDeadline,
        onRemoveDeadline: () {
          setState(() => _deadline = null);
        },
        onPersonalChanged: (value) {
          setState(() => _personal = value);
        },
        formatDate: _formatDate,
      ),
    );
  }
}