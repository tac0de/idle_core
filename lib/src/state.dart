import 'actions.dart';

abstract class IdleState {
  const IdleState();

  Map<String, dynamic> toJson();
}

typedef IdleReducer<S extends IdleState> = S Function(
  S state,
  IdleAction action,
);
