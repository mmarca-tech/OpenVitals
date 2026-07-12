// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'comaps_navigation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CoMapsNavigationSnapshot {

 DateTime get sampledAt; String get sessionState; String get currentStreet; String get nextStreet; String get distanceToTurn; String get distanceToTarget; String get distanceToNextStop; int? get totalTimeSeconds; int? get timeToNextStopSeconds; double? get completionPercent; String get carDirection; String get pedestrianDirection; String get exitNumber;
/// Create a copy of CoMapsNavigationSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CoMapsNavigationSnapshotCopyWith<CoMapsNavigationSnapshot> get copyWith => _$CoMapsNavigationSnapshotCopyWithImpl<CoMapsNavigationSnapshot>(this as CoMapsNavigationSnapshot, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CoMapsNavigationSnapshot&&(identical(other.sampledAt, sampledAt) || other.sampledAt == sampledAt)&&(identical(other.sessionState, sessionState) || other.sessionState == sessionState)&&(identical(other.currentStreet, currentStreet) || other.currentStreet == currentStreet)&&(identical(other.nextStreet, nextStreet) || other.nextStreet == nextStreet)&&(identical(other.distanceToTurn, distanceToTurn) || other.distanceToTurn == distanceToTurn)&&(identical(other.distanceToTarget, distanceToTarget) || other.distanceToTarget == distanceToTarget)&&(identical(other.distanceToNextStop, distanceToNextStop) || other.distanceToNextStop == distanceToNextStop)&&(identical(other.totalTimeSeconds, totalTimeSeconds) || other.totalTimeSeconds == totalTimeSeconds)&&(identical(other.timeToNextStopSeconds, timeToNextStopSeconds) || other.timeToNextStopSeconds == timeToNextStopSeconds)&&(identical(other.completionPercent, completionPercent) || other.completionPercent == completionPercent)&&(identical(other.carDirection, carDirection) || other.carDirection == carDirection)&&(identical(other.pedestrianDirection, pedestrianDirection) || other.pedestrianDirection == pedestrianDirection)&&(identical(other.exitNumber, exitNumber) || other.exitNumber == exitNumber));
}


@override
int get hashCode => Object.hash(runtimeType,sampledAt,sessionState,currentStreet,nextStreet,distanceToTurn,distanceToTarget,distanceToNextStop,totalTimeSeconds,timeToNextStopSeconds,completionPercent,carDirection,pedestrianDirection,exitNumber);

@override
String toString() {
  return 'CoMapsNavigationSnapshot(sampledAt: $sampledAt, sessionState: $sessionState, currentStreet: $currentStreet, nextStreet: $nextStreet, distanceToTurn: $distanceToTurn, distanceToTarget: $distanceToTarget, distanceToNextStop: $distanceToNextStop, totalTimeSeconds: $totalTimeSeconds, timeToNextStopSeconds: $timeToNextStopSeconds, completionPercent: $completionPercent, carDirection: $carDirection, pedestrianDirection: $pedestrianDirection, exitNumber: $exitNumber)';
}


}

/// @nodoc
abstract mixin class $CoMapsNavigationSnapshotCopyWith<$Res>  {
  factory $CoMapsNavigationSnapshotCopyWith(CoMapsNavigationSnapshot value, $Res Function(CoMapsNavigationSnapshot) _then) = _$CoMapsNavigationSnapshotCopyWithImpl;
@useResult
$Res call({
 DateTime sampledAt, String sessionState, String currentStreet, String nextStreet, String distanceToTurn, String distanceToTarget, String distanceToNextStop, int? totalTimeSeconds, int? timeToNextStopSeconds, double? completionPercent, String carDirection, String pedestrianDirection, String exitNumber
});




}
/// @nodoc
class _$CoMapsNavigationSnapshotCopyWithImpl<$Res>
    implements $CoMapsNavigationSnapshotCopyWith<$Res> {
  _$CoMapsNavigationSnapshotCopyWithImpl(this._self, this._then);

  final CoMapsNavigationSnapshot _self;
  final $Res Function(CoMapsNavigationSnapshot) _then;

/// Create a copy of CoMapsNavigationSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sampledAt = null,Object? sessionState = null,Object? currentStreet = null,Object? nextStreet = null,Object? distanceToTurn = null,Object? distanceToTarget = null,Object? distanceToNextStop = null,Object? totalTimeSeconds = freezed,Object? timeToNextStopSeconds = freezed,Object? completionPercent = freezed,Object? carDirection = null,Object? pedestrianDirection = null,Object? exitNumber = null,}) {
  return _then(_self.copyWith(
sampledAt: null == sampledAt ? _self.sampledAt : sampledAt // ignore: cast_nullable_to_non_nullable
as DateTime,sessionState: null == sessionState ? _self.sessionState : sessionState // ignore: cast_nullable_to_non_nullable
as String,currentStreet: null == currentStreet ? _self.currentStreet : currentStreet // ignore: cast_nullable_to_non_nullable
as String,nextStreet: null == nextStreet ? _self.nextStreet : nextStreet // ignore: cast_nullable_to_non_nullable
as String,distanceToTurn: null == distanceToTurn ? _self.distanceToTurn : distanceToTurn // ignore: cast_nullable_to_non_nullable
as String,distanceToTarget: null == distanceToTarget ? _self.distanceToTarget : distanceToTarget // ignore: cast_nullable_to_non_nullable
as String,distanceToNextStop: null == distanceToNextStop ? _self.distanceToNextStop : distanceToNextStop // ignore: cast_nullable_to_non_nullable
as String,totalTimeSeconds: freezed == totalTimeSeconds ? _self.totalTimeSeconds : totalTimeSeconds // ignore: cast_nullable_to_non_nullable
as int?,timeToNextStopSeconds: freezed == timeToNextStopSeconds ? _self.timeToNextStopSeconds : timeToNextStopSeconds // ignore: cast_nullable_to_non_nullable
as int?,completionPercent: freezed == completionPercent ? _self.completionPercent : completionPercent // ignore: cast_nullable_to_non_nullable
as double?,carDirection: null == carDirection ? _self.carDirection : carDirection // ignore: cast_nullable_to_non_nullable
as String,pedestrianDirection: null == pedestrianDirection ? _self.pedestrianDirection : pedestrianDirection // ignore: cast_nullable_to_non_nullable
as String,exitNumber: null == exitNumber ? _self.exitNumber : exitNumber // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [CoMapsNavigationSnapshot].
extension CoMapsNavigationSnapshotPatterns on CoMapsNavigationSnapshot {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CoMapsNavigationSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CoMapsNavigationSnapshot() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CoMapsNavigationSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _CoMapsNavigationSnapshot():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CoMapsNavigationSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _CoMapsNavigationSnapshot() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime sampledAt,  String sessionState,  String currentStreet,  String nextStreet,  String distanceToTurn,  String distanceToTarget,  String distanceToNextStop,  int? totalTimeSeconds,  int? timeToNextStopSeconds,  double? completionPercent,  String carDirection,  String pedestrianDirection,  String exitNumber)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CoMapsNavigationSnapshot() when $default != null:
return $default(_that.sampledAt,_that.sessionState,_that.currentStreet,_that.nextStreet,_that.distanceToTurn,_that.distanceToTarget,_that.distanceToNextStop,_that.totalTimeSeconds,_that.timeToNextStopSeconds,_that.completionPercent,_that.carDirection,_that.pedestrianDirection,_that.exitNumber);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime sampledAt,  String sessionState,  String currentStreet,  String nextStreet,  String distanceToTurn,  String distanceToTarget,  String distanceToNextStop,  int? totalTimeSeconds,  int? timeToNextStopSeconds,  double? completionPercent,  String carDirection,  String pedestrianDirection,  String exitNumber)  $default,) {final _that = this;
switch (_that) {
case _CoMapsNavigationSnapshot():
return $default(_that.sampledAt,_that.sessionState,_that.currentStreet,_that.nextStreet,_that.distanceToTurn,_that.distanceToTarget,_that.distanceToNextStop,_that.totalTimeSeconds,_that.timeToNextStopSeconds,_that.completionPercent,_that.carDirection,_that.pedestrianDirection,_that.exitNumber);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime sampledAt,  String sessionState,  String currentStreet,  String nextStreet,  String distanceToTurn,  String distanceToTarget,  String distanceToNextStop,  int? totalTimeSeconds,  int? timeToNextStopSeconds,  double? completionPercent,  String carDirection,  String pedestrianDirection,  String exitNumber)?  $default,) {final _that = this;
switch (_that) {
case _CoMapsNavigationSnapshot() when $default != null:
return $default(_that.sampledAt,_that.sessionState,_that.currentStreet,_that.nextStreet,_that.distanceToTurn,_that.distanceToTarget,_that.distanceToNextStop,_that.totalTimeSeconds,_that.timeToNextStopSeconds,_that.completionPercent,_that.carDirection,_that.pedestrianDirection,_that.exitNumber);case _:
  return null;

}
}

}

/// @nodoc


class _CoMapsNavigationSnapshot extends CoMapsNavigationSnapshot {
  const _CoMapsNavigationSnapshot({required this.sampledAt, required this.sessionState, this.currentStreet = '', this.nextStreet = '', this.distanceToTurn = '', this.distanceToTarget = '', this.distanceToNextStop = '', this.totalTimeSeconds, this.timeToNextStopSeconds, this.completionPercent, this.carDirection = '', this.pedestrianDirection = '', this.exitNumber = ''}): super._();
  

@override final  DateTime sampledAt;
@override final  String sessionState;
@override@JsonKey() final  String currentStreet;
@override@JsonKey() final  String nextStreet;
@override@JsonKey() final  String distanceToTurn;
@override@JsonKey() final  String distanceToTarget;
@override@JsonKey() final  String distanceToNextStop;
@override final  int? totalTimeSeconds;
@override final  int? timeToNextStopSeconds;
@override final  double? completionPercent;
@override@JsonKey() final  String carDirection;
@override@JsonKey() final  String pedestrianDirection;
@override@JsonKey() final  String exitNumber;

/// Create a copy of CoMapsNavigationSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CoMapsNavigationSnapshotCopyWith<_CoMapsNavigationSnapshot> get copyWith => __$CoMapsNavigationSnapshotCopyWithImpl<_CoMapsNavigationSnapshot>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CoMapsNavigationSnapshot&&(identical(other.sampledAt, sampledAt) || other.sampledAt == sampledAt)&&(identical(other.sessionState, sessionState) || other.sessionState == sessionState)&&(identical(other.currentStreet, currentStreet) || other.currentStreet == currentStreet)&&(identical(other.nextStreet, nextStreet) || other.nextStreet == nextStreet)&&(identical(other.distanceToTurn, distanceToTurn) || other.distanceToTurn == distanceToTurn)&&(identical(other.distanceToTarget, distanceToTarget) || other.distanceToTarget == distanceToTarget)&&(identical(other.distanceToNextStop, distanceToNextStop) || other.distanceToNextStop == distanceToNextStop)&&(identical(other.totalTimeSeconds, totalTimeSeconds) || other.totalTimeSeconds == totalTimeSeconds)&&(identical(other.timeToNextStopSeconds, timeToNextStopSeconds) || other.timeToNextStopSeconds == timeToNextStopSeconds)&&(identical(other.completionPercent, completionPercent) || other.completionPercent == completionPercent)&&(identical(other.carDirection, carDirection) || other.carDirection == carDirection)&&(identical(other.pedestrianDirection, pedestrianDirection) || other.pedestrianDirection == pedestrianDirection)&&(identical(other.exitNumber, exitNumber) || other.exitNumber == exitNumber));
}


@override
int get hashCode => Object.hash(runtimeType,sampledAt,sessionState,currentStreet,nextStreet,distanceToTurn,distanceToTarget,distanceToNextStop,totalTimeSeconds,timeToNextStopSeconds,completionPercent,carDirection,pedestrianDirection,exitNumber);

@override
String toString() {
  return 'CoMapsNavigationSnapshot(sampledAt: $sampledAt, sessionState: $sessionState, currentStreet: $currentStreet, nextStreet: $nextStreet, distanceToTurn: $distanceToTurn, distanceToTarget: $distanceToTarget, distanceToNextStop: $distanceToNextStop, totalTimeSeconds: $totalTimeSeconds, timeToNextStopSeconds: $timeToNextStopSeconds, completionPercent: $completionPercent, carDirection: $carDirection, pedestrianDirection: $pedestrianDirection, exitNumber: $exitNumber)';
}


}

/// @nodoc
abstract mixin class _$CoMapsNavigationSnapshotCopyWith<$Res> implements $CoMapsNavigationSnapshotCopyWith<$Res> {
  factory _$CoMapsNavigationSnapshotCopyWith(_CoMapsNavigationSnapshot value, $Res Function(_CoMapsNavigationSnapshot) _then) = __$CoMapsNavigationSnapshotCopyWithImpl;
@override @useResult
$Res call({
 DateTime sampledAt, String sessionState, String currentStreet, String nextStreet, String distanceToTurn, String distanceToTarget, String distanceToNextStop, int? totalTimeSeconds, int? timeToNextStopSeconds, double? completionPercent, String carDirection, String pedestrianDirection, String exitNumber
});




}
/// @nodoc
class __$CoMapsNavigationSnapshotCopyWithImpl<$Res>
    implements _$CoMapsNavigationSnapshotCopyWith<$Res> {
  __$CoMapsNavigationSnapshotCopyWithImpl(this._self, this._then);

  final _CoMapsNavigationSnapshot _self;
  final $Res Function(_CoMapsNavigationSnapshot) _then;

/// Create a copy of CoMapsNavigationSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sampledAt = null,Object? sessionState = null,Object? currentStreet = null,Object? nextStreet = null,Object? distanceToTurn = null,Object? distanceToTarget = null,Object? distanceToNextStop = null,Object? totalTimeSeconds = freezed,Object? timeToNextStopSeconds = freezed,Object? completionPercent = freezed,Object? carDirection = null,Object? pedestrianDirection = null,Object? exitNumber = null,}) {
  return _then(_CoMapsNavigationSnapshot(
sampledAt: null == sampledAt ? _self.sampledAt : sampledAt // ignore: cast_nullable_to_non_nullable
as DateTime,sessionState: null == sessionState ? _self.sessionState : sessionState // ignore: cast_nullable_to_non_nullable
as String,currentStreet: null == currentStreet ? _self.currentStreet : currentStreet // ignore: cast_nullable_to_non_nullable
as String,nextStreet: null == nextStreet ? _self.nextStreet : nextStreet // ignore: cast_nullable_to_non_nullable
as String,distanceToTurn: null == distanceToTurn ? _self.distanceToTurn : distanceToTurn // ignore: cast_nullable_to_non_nullable
as String,distanceToTarget: null == distanceToTarget ? _self.distanceToTarget : distanceToTarget // ignore: cast_nullable_to_non_nullable
as String,distanceToNextStop: null == distanceToNextStop ? _self.distanceToNextStop : distanceToNextStop // ignore: cast_nullable_to_non_nullable
as String,totalTimeSeconds: freezed == totalTimeSeconds ? _self.totalTimeSeconds : totalTimeSeconds // ignore: cast_nullable_to_non_nullable
as int?,timeToNextStopSeconds: freezed == timeToNextStopSeconds ? _self.timeToNextStopSeconds : timeToNextStopSeconds // ignore: cast_nullable_to_non_nullable
as int?,completionPercent: freezed == completionPercent ? _self.completionPercent : completionPercent // ignore: cast_nullable_to_non_nullable
as double?,carDirection: null == carDirection ? _self.carDirection : carDirection // ignore: cast_nullable_to_non_nullable
as String,pedestrianDirection: null == pedestrianDirection ? _self.pedestrianDirection : pedestrianDirection // ignore: cast_nullable_to_non_nullable
as String,exitNumber: null == exitNumber ? _self.exitNumber : exitNumber // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
