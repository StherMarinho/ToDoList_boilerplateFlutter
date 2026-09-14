import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/example/data/example_repository.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/example/domain/example.dart';
import 'package:synergia_flutter_meteor_boilerplate/services/meteor/meteor_error_mapper.dart';

class ExampleListState {
  const ExampleListState({
    this.examples = const [],
    this.loading = true,
    this.total = 0,
    this.search = '',
    this.category,
    this.newestFirst = true,
    this.failure,
  });

  final List<Example> examples;
  final bool loading;
  final int total;
  final String search;
  final String? category;
  final bool newestFirst;
  final MeteorFailure? failure;

  ExampleListState copyWith({
    List<Example>? examples,
    bool? loading,
    int? total,
    String? search,
    String? category,
    bool clearCategory = false,
    bool? newestFirst,
    MeteorFailure? failure,
    bool clearFailure = false,
  }) {
    return ExampleListState(
      examples: examples ?? this.examples,
      loading: loading ?? this.loading,
      total: total ?? this.total,
      search: search ?? this.search,
      category: clearCategory ? null : category ?? this.category,
      newestFirst: newestFirst ?? this.newestFirst,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}

final exampleControllerProvider =
    NotifierProvider<ExampleController, ExampleListState>(
      ExampleController.new,
    );

class ExampleController extends Notifier<ExampleListState> {
  StreamSubscription<List<Example>>? _collectionListener;
  Timer? _searchDebounce;
  List<Example> _allExamples = const [];
  bool _receivedLocalSnapshot = false;

  ExampleRepository get _repository => ref.read(exampleRepositoryProvider);

  @override
  ExampleListState build() {
    ref.onDispose(_dispose);
    _collectionListener = _repository.watchExamples().listen(
      (examples) {
        _allExamples = examples;
        _applyLocalFilters();
        if (!_receivedLocalSnapshot) {
          _receivedLocalSnapshot = true;
          state = state.copyWith(loading: false);
        }
      },
      onError: (Object error) {
        state = state.copyWith(
          loading: false,
          failure: MeteorErrorMapper.map(error),
        );
      },
    );
    Future<void>.microtask(() async {
      try {
        await _repository.start();
      } catch (error) {
        if (ref.mounted) {
          state = state.copyWith(failure: MeteorErrorMapper.map(error));
        }
      } finally {
        if (ref.mounted) state = state.copyWith(loading: false);
      }
    });
    return const ExampleListState();
  }

  Future<void> refresh() async {
    state = state.copyWith(loading: true, clearFailure: true);
    try {
      await _repository.refresh();
      state = state.copyWith(loading: false);
    } catch (error) {
      state = state.copyWith(
        loading: false,
        failure: MeteorErrorMapper.map(error),
      );
    }
  }

  void setSearch(String value) {
    state = state.copyWith(search: value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 250),
      _applyLocalFilters,
    );
  }

  void setCategory(String? value) {
    state = state.copyWith(
      category: value,
      clearCategory: value == null || value.isEmpty,
    );
    _applyLocalFilters();
  }

  void toggleSort() {
    state = state.copyWith(newestFirst: !state.newestFirst);
    _applyLocalFilters();
  }

  Future<bool> remove(String id) async {
    try {
      await _repository.remove(id);
      return true;
    } catch (error) {
      state = state.copyWith(failure: MeteorErrorMapper.map(error));
      return false;
    }
  }

  void clearFailure() => state = state.copyWith(clearFailure: true);

  void _applyLocalFilters() {
    final query = state.search.trim().toLowerCase();
    final filtered =
        _allExamples.where((example) {
          if (query.isNotEmpty &&
              !example.title.toLowerCase().contains(query)) {
            return false;
          }
          return state.category?.isNotEmpty != true ||
              example.type == state.category;
        }).toList()..sort((a, b) {
          final left =
              a.createdAt ??
              a.lastUpdate ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final right =
              b.createdAt ??
              b.lastUpdate ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return state.newestFirst
              ? right.compareTo(left)
              : left.compareTo(right);
        });
    state = state.copyWith(examples: filtered, total: filtered.length);
  }

  void _dispose() {
    _searchDebounce?.cancel();
    _collectionListener?.cancel();
  }
}
