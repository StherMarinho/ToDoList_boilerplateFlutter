import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/to_dos/data/to_dos_api.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/to_dos/data/to_dos_repository.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/to_dos/domain/to_do.dart';
import 'package:synergia_flutter_meteor_boilerplate/services/meteor/meteor_error_mapper.dart';

class ToDosListState {
  const ToDosListState({
    this.items = const [],
    this.loading = true,
    this.search = '',
    this.status = ToDosStatusFilter.all,
    this.page = 1,
    this.total = 0,
    this.failure,
    this.message,
  });

  final List<ToDo> items;
  final bool loading;
  final String search;
  final ToDosStatusFilter status;
  final int page;
  final int total;
  final MeteorFailure? failure;
  final String? message;

  int get pageCount => total == 0 ? 1 : (total / 4).ceil();

  ToDosListState copyWith({
    List<ToDo>? items,
    bool? loading,
    String? search,
    ToDosStatusFilter? status,
    int? page,
    int? total,
    MeteorFailure? failure,
    bool clearFailure = false,
    String? message,
    bool clearMessage = false,
  }) {
    return ToDosListState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      search: search ?? this.search,
      status: status ?? this.status,
      page: page ?? this.page,
      total: total ?? this.total,
      failure: clearFailure ? null : failure ?? this.failure,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

final toDosControllerProvider =
    NotifierProvider.autoDispose<ToDosController, ToDosListState>(
      ToDosController.new,
    );

class ToDosController extends Notifier<ToDosListState> {
  StreamSubscription<List<ToDo>>? _itemsListener;
  StreamSubscription<int>? _totalListener;
  Timer? _searchDebounce;

  var _subscriptionVersion = 0;

  late final ToDosRepository _repository;

  @override
  ToDosListState build() {
    _repository = ref.read(toDosRepositoryProvider);

    ref.onDispose(_dispose);

    Future<void>.microtask(_start);

    return const ToDosListState();
  }

  void _start() {
    if (!ref.mounted) return;

    _itemsListener = _repository.watchListTodos().listen(
      _onRemoteItems,
      onError: _onError,
    );

    _totalListener = _repository.watchFilteredTotal().listen(
      _onRemoteTotal,
      onError: _onError,
    );

    unawaited(_subscribe());
  }

  Future<void> refresh() => _subscribe();

  void setSearch(String value) {
    state = state.copyWith(
      search: value,
      page: 1,
    );

    _searchDebounce?.cancel();

    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(_subscribe()),
    );
  }

  void setStatus(ToDosStatusFilter status) {
    state = state.copyWith(
      status: status,
      page: 1,
    );

    unawaited(_subscribe());
  }

  void goToPage(int page) {
    final safePage = page.clamp(1, state.pageCount).toInt();

    if (safePage == state.page) return;

    state = state.copyWith(page: safePage);

    unawaited(_subscribe());
  }

  Future<bool> remove(String id) async {
    try {
      await _repository.remove(id);

      state = state.copyWith(
        message: 'Tarefa excluída com sucesso.',
      );

      return true;
    } catch (error) {
      _onError(error);
      return false;
    }
  }

  Future<bool> toggleCompletion(String id) async {
    try {
      final result = await _repository.toggleCompletion(id);

      state = state.copyWith(
        message: result.message,
      );
      unawaited(_subscribe());
      return true;
    } catch (error) {
      _onError(error);
      return false;
    }
  }

  void clearFailure() {
    state = state.copyWith(
      clearFailure: true,
    );
  }

  void clearMessage() {
    state = state.copyWith(
      clearMessage: true,
    );
  }

  Future<void> _subscribe() async {
    final version = ++_subscriptionVersion;

    state = state.copyWith(
      loading: true,
      clearFailure: true,
      clearMessage: true,
    );

    try {
      await _repository.subscribeList(
        search: state.search,
        status: state.status,
        page: state.page,
      );

      if (!ref.mounted || version != _subscriptionVersion) return;

      state = state.copyWith(
        loading: false,
      );
    } catch (error) {
      if (!ref.mounted || version != _subscriptionVersion) return;

      _onError(error);
    }
  }

  void _onRemoteItems(List<ToDo> items) {
    state = state.copyWith(
      items: items,
    );
  }

  void _onRemoteTotal(int total) {
    state = state.copyWith(
      total: total,
    );

    if (state.loading || state.page <= state.pageCount) return;

    state = state.copyWith(
      page: state.pageCount,
    );

    unawaited(_subscribe());
  }

  void _onError(Object error) {
    state = state.copyWith(
      loading: false,
      failure: MeteorErrorMapper.map(error),
    );
  }

  void _dispose() {
    _subscriptionVersion++;

    _searchDebounce?.cancel();

    _itemsListener?.cancel();

    _totalListener?.cancel();

    _repository.stopList();
  }
}