import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeGoTrueClient extends Fake implements GoTrueClient {
  final _authStateController = StreamController<AuthState>.broadcast();
  Session? _currentSession;
  User? _currentUser;

  bool loginCalled = false;
  bool signUpCalled = false;
  bool signOutCalled = false;
  bool signUpReturnsNullSession = false;

  String? lastEmail;
  String? lastPassword;

  FakeGoTrueClient({Session? initialSession}) {
    _currentSession = initialSession;
    _currentUser = initialSession?.user;
  }

  @override
  Session? get currentSession => _currentSession;

  @override
  User? get currentUser => _currentUser;

  @override
  Stream<AuthState> get onAuthStateChange {
    final controller = StreamController<AuthState>.broadcast();
    scheduleMicrotask(() {
      if (!controller.isClosed) {
        controller.add(
          AuthState(AuthChangeEvent.initialSession, _currentSession),
        );
      }
    });
    final sub = _authStateController.stream.listen(
      (event) {
        controller.add(event);
      },
      onError: (err) => controller.addError(err),
      onDone: () => controller.close(),
    );
    controller.onCancel = () {
      sub.cancel();
      controller.close();
    };
    return controller.stream;
  }

  void emitSession(Session? session) {
    _currentSession = session;
    _currentUser = session?.user;
    _authStateController.add(AuthState(AuthChangeEvent.signedIn, session));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName;

    if (name == #signInWithPassword) {
      loginCalled = true;
      final args = invocation.namedArguments;
      lastEmail = args[#email] as String?;
      lastPassword = args[#password] as String?;

      final mockUser = User(
        id: 'mock-user-id',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
        email: lastEmail,
      );
      final mockSession = Session(
        accessToken: 'mock-access-token',
        tokenType: 'bearer',
        user: mockUser,
      );

      return Future.delayed(const Duration(milliseconds: 50), () {
        emitSession(mockSession);
        return AuthResponse(session: mockSession, user: mockUser);
      });
    }

    if (name == #signUp) {
      signUpCalled = true;
      final args = invocation.namedArguments;
      lastEmail = args[#email] as String?;
      lastPassword = args[#password] as String?;

      final mockUser = User(
        id: 'mock-user-id',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
        email: lastEmail,
      );

      if (signUpReturnsNullSession) {
        return Future.delayed(const Duration(milliseconds: 50), () {
          return AuthResponse(session: null, user: mockUser);
        });
      }

      final mockSession = Session(
        accessToken: 'mock-access-token',
        tokenType: 'bearer',
        user: mockUser,
      );

      return Future.delayed(const Duration(milliseconds: 50), () {
        emitSession(mockSession);
        return AuthResponse(session: mockSession, user: mockUser);
      });
    }

    if (name == #signOut) {
      signOutCalled = true;
      emitSession(null);
      return Future.value();
    }

    return super.noSuchMethod(invocation);
  }
}

class FakePostgrestTransformBuilder<T> extends Fake
    implements PostgrestTransformBuilder<T> {
  final Future<T> _future;
  FakePostgrestTransformBuilder(this._future);

  @override
  Future<R> then<R>(FutureOr<R> Function(T) onValue, {Function? onError}) {
    return _future.then(onValue, onError: onError);
  }
}

class FakePostgrestFilterBuilder<T> extends Fake
    implements PostgrestFilterBuilder<T> {
  final Future<T> _future;
  FakePostgrestFilterBuilder(this._future);

  @override
  PostgrestFilterBuilder<T> ilike(String column, String pattern) {
    return this;
  }

  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) {
    return this;
  }

  @override
  PostgrestFilterBuilder<T> inFilter(String column, List values) {
    return this;
  }

  @override
  PostgrestTransformBuilder<Map<String, dynamic>?> maybeSingle() {
    final Future<Map<String, dynamic>?> mappedFuture = _future.then((value) {
      if (value is List && value.isNotEmpty) {
        return value.first as Map<String, dynamic>;
      }
      if (value is Map) {
        return value as Map<String, dynamic>;
      }
      return null;
    });
    return FakePostgrestTransformBuilder<Map<String, dynamic>?>(mappedFuture);
  }

  @override
  Future<R> then<R>(FutureOr<R> Function(T) onValue, {Function? onError}) {
    return _future.then(onValue, onError: onError);
  }
}

class FakeSupabaseQueryBuilder extends Fake implements SupabaseQueryBuilder {
  final List<Map<String, dynamic>> selectResult;
  final Function(Map<String, dynamic>)? onInsert;

  FakeSupabaseQueryBuilder({this.selectResult = const [], this.onInsert});

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> select([
    String columns = '*',
  ]) {
    return FakePostgrestFilterBuilder<List<Map<String, dynamic>>>(
      Future.value(selectResult),
    );
  }

  @override
  PostgrestFilterBuilder<Map<String, dynamic>> insert(
    Object values, {
    dynamic defaultToNull,
  }) {
    if (onInsert != null && values is Map<String, dynamic>) {
      onInsert!(values);
    }
    final insertedMap = values is Map<String, dynamic>
        ? values
        : <String, dynamic>{};
    return FakePostgrestFilterBuilder<Map<String, dynamic>>(
      Future.value(insertedMap),
    );
  }
}

class FakeSupabaseClient extends Fake implements SupabaseClient {
  final FakeGoTrueClient fakeAuth;
  final Map<String, List<Map<String, dynamic>>> mockData;
  final Function(String table, Map<String, dynamic> row)? onInsert;
  final List<FakeRealtimeChannel> activeChannels = [];

  FakeSupabaseClient({
    FakeGoTrueClient? auth,
    this.mockData = const {},
    this.onInsert,
  }) : fakeAuth = auth ?? FakeGoTrueClient();

  @override
  GoTrueClient get auth => fakeAuth;

  @override
  SupabaseQueryBuilder from(String table) {
    return FakeSupabaseQueryBuilder(
      selectResult: mockData[table] ?? [],
      onInsert: (row) {
        if (onInsert != null) {
          onInsert!(table, row);
        }
      },
    );
  }

  @override
  RealtimeChannel channel(
    String name, {
    RealtimeChannelConfig opts = const RealtimeChannelConfig(),
  }) {
    final ch = FakeRealtimeChannel(name);
    activeChannels.add(ch);
    return ch;
  }

  @override
  Future<String> removeChannel(RealtimeChannel channel) async {
    activeChannels.remove(channel as FakeRealtimeChannel);
    return 'ok';
  }
}

class FakeRealtimeChannel extends Fake implements RealtimeChannel {
  final String name;
  final List<void Function(PostgresChangePayload)> postgresChangesCallbacks =
      [];

  FakeRealtimeChannel(this.name);

  @override
  RealtimeChannel onPostgresChanges({
    required PostgresChangeEvent event,
    String? schema,
    String? table,
    PostgresChangeFilter? filter,
    required void Function(PostgresChangePayload payload) callback,
  }) {
    postgresChangesCallbacks.add(callback);
    return this;
  }

  @override
  RealtimeChannel subscribe([
    void Function(RealtimeSubscribeStatus status, Object? error)? callback,
    Duration? timeout,
  ]) {
    if (callback != null) {
      callback(RealtimeSubscribeStatus.subscribed, null);
    }
    return this;
  }

  @override
  Future<String> unsubscribe([Duration? timeout]) async {
    return 'ok';
  }

  void triggerPostgresChange({
    required PostgresChangeEvent event,
    required String schema,
    required String table,
    required Map<String, dynamic> newRecord,
    required Map<String, dynamic> oldRecord,
  }) {
    final payload = FakePostgresChangesPayload(
      eventType: event,
      schema: schema,
      table: table,
      newRecord: newRecord,
      oldRecord: oldRecord,
    );
    for (final cb in postgresChangesCallbacks) {
      cb(payload);
    }
  }
}

class FakePostgresChangesPayload extends Fake implements PostgresChangePayload {
  @override
  final PostgresChangeEvent eventType;
  @override
  final String schema;
  @override
  final String table;
  @override
  final Map<String, dynamic> newRecord;
  @override
  final Map<String, dynamic> oldRecord;

  FakePostgresChangesPayload({
    required this.eventType,
    required this.schema,
    required this.table,
    required this.newRecord,
    required this.oldRecord,
  });
}
