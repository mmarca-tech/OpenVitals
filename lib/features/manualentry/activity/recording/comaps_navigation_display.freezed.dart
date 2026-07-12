// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'comaps_navigation_display.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CoMapsGuidanceDisplay {

/// The arrow to draw.
 CoMapsTurnKind get turnKind;/// The distance printed under the arrow, on the badge and on the overlay.
 String get turnDistance;/// The street the guidance is about — the headline of the overlay.
 String get primaryStreet;/// "450 m - Elm Street - Turn right - Exit 3", as much of it as exists.
 String get nextTurn; String get currentStreet; String get destination; String get progress; String get timeToNextStop; String get routeTime; String get sessionState;/// The overlay's two secondary lines, already joined.
 String get overlaySecondary; String get overlayFooter;
/// Create a copy of CoMapsGuidanceDisplay
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CoMapsGuidanceDisplayCopyWith<CoMapsGuidanceDisplay> get copyWith => _$CoMapsGuidanceDisplayCopyWithImpl<CoMapsGuidanceDisplay>(this as CoMapsGuidanceDisplay, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CoMapsGuidanceDisplay&&(identical(other.turnKind, turnKind) || other.turnKind == turnKind)&&(identical(other.turnDistance, turnDistance) || other.turnDistance == turnDistance)&&(identical(other.primaryStreet, primaryStreet) || other.primaryStreet == primaryStreet)&&(identical(other.nextTurn, nextTurn) || other.nextTurn == nextTurn)&&(identical(other.currentStreet, currentStreet) || other.currentStreet == currentStreet)&&(identical(other.destination, destination) || other.destination == destination)&&(identical(other.progress, progress) || other.progress == progress)&&(identical(other.timeToNextStop, timeToNextStop) || other.timeToNextStop == timeToNextStop)&&(identical(other.routeTime, routeTime) || other.routeTime == routeTime)&&(identical(other.sessionState, sessionState) || other.sessionState == sessionState)&&(identical(other.overlaySecondary, overlaySecondary) || other.overlaySecondary == overlaySecondary)&&(identical(other.overlayFooter, overlayFooter) || other.overlayFooter == overlayFooter));
}


@override
int get hashCode => Object.hash(runtimeType,turnKind,turnDistance,primaryStreet,nextTurn,currentStreet,destination,progress,timeToNextStop,routeTime,sessionState,overlaySecondary,overlayFooter);

@override
String toString() {
  return 'CoMapsGuidanceDisplay(turnKind: $turnKind, turnDistance: $turnDistance, primaryStreet: $primaryStreet, nextTurn: $nextTurn, currentStreet: $currentStreet, destination: $destination, progress: $progress, timeToNextStop: $timeToNextStop, routeTime: $routeTime, sessionState: $sessionState, overlaySecondary: $overlaySecondary, overlayFooter: $overlayFooter)';
}


}

/// @nodoc
abstract mixin class $CoMapsGuidanceDisplayCopyWith<$Res>  {
  factory $CoMapsGuidanceDisplayCopyWith(CoMapsGuidanceDisplay value, $Res Function(CoMapsGuidanceDisplay) _then) = _$CoMapsGuidanceDisplayCopyWithImpl;
@useResult
$Res call({
 CoMapsTurnKind turnKind, String turnDistance, String primaryStreet, String nextTurn, String currentStreet, String destination, String progress, String timeToNextStop, String routeTime, String sessionState, String overlaySecondary, String overlayFooter
});




}
/// @nodoc
class _$CoMapsGuidanceDisplayCopyWithImpl<$Res>
    implements $CoMapsGuidanceDisplayCopyWith<$Res> {
  _$CoMapsGuidanceDisplayCopyWithImpl(this._self, this._then);

  final CoMapsGuidanceDisplay _self;
  final $Res Function(CoMapsGuidanceDisplay) _then;

/// Create a copy of CoMapsGuidanceDisplay
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? turnKind = null,Object? turnDistance = null,Object? primaryStreet = null,Object? nextTurn = null,Object? currentStreet = null,Object? destination = null,Object? progress = null,Object? timeToNextStop = null,Object? routeTime = null,Object? sessionState = null,Object? overlaySecondary = null,Object? overlayFooter = null,}) {
  return _then(_self.copyWith(
turnKind: null == turnKind ? _self.turnKind : turnKind // ignore: cast_nullable_to_non_nullable
as CoMapsTurnKind,turnDistance: null == turnDistance ? _self.turnDistance : turnDistance // ignore: cast_nullable_to_non_nullable
as String,primaryStreet: null == primaryStreet ? _self.primaryStreet : primaryStreet // ignore: cast_nullable_to_non_nullable
as String,nextTurn: null == nextTurn ? _self.nextTurn : nextTurn // ignore: cast_nullable_to_non_nullable
as String,currentStreet: null == currentStreet ? _self.currentStreet : currentStreet // ignore: cast_nullable_to_non_nullable
as String,destination: null == destination ? _self.destination : destination // ignore: cast_nullable_to_non_nullable
as String,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as String,timeToNextStop: null == timeToNextStop ? _self.timeToNextStop : timeToNextStop // ignore: cast_nullable_to_non_nullable
as String,routeTime: null == routeTime ? _self.routeTime : routeTime // ignore: cast_nullable_to_non_nullable
as String,sessionState: null == sessionState ? _self.sessionState : sessionState // ignore: cast_nullable_to_non_nullable
as String,overlaySecondary: null == overlaySecondary ? _self.overlaySecondary : overlaySecondary // ignore: cast_nullable_to_non_nullable
as String,overlayFooter: null == overlayFooter ? _self.overlayFooter : overlayFooter // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [CoMapsGuidanceDisplay].
extension CoMapsGuidanceDisplayPatterns on CoMapsGuidanceDisplay {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CoMapsGuidanceDisplay value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CoMapsGuidanceDisplay() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CoMapsGuidanceDisplay value)  $default,){
final _that = this;
switch (_that) {
case _CoMapsGuidanceDisplay():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CoMapsGuidanceDisplay value)?  $default,){
final _that = this;
switch (_that) {
case _CoMapsGuidanceDisplay() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( CoMapsTurnKind turnKind,  String turnDistance,  String primaryStreet,  String nextTurn,  String currentStreet,  String destination,  String progress,  String timeToNextStop,  String routeTime,  String sessionState,  String overlaySecondary,  String overlayFooter)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CoMapsGuidanceDisplay() when $default != null:
return $default(_that.turnKind,_that.turnDistance,_that.primaryStreet,_that.nextTurn,_that.currentStreet,_that.destination,_that.progress,_that.timeToNextStop,_that.routeTime,_that.sessionState,_that.overlaySecondary,_that.overlayFooter);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( CoMapsTurnKind turnKind,  String turnDistance,  String primaryStreet,  String nextTurn,  String currentStreet,  String destination,  String progress,  String timeToNextStop,  String routeTime,  String sessionState,  String overlaySecondary,  String overlayFooter)  $default,) {final _that = this;
switch (_that) {
case _CoMapsGuidanceDisplay():
return $default(_that.turnKind,_that.turnDistance,_that.primaryStreet,_that.nextTurn,_that.currentStreet,_that.destination,_that.progress,_that.timeToNextStop,_that.routeTime,_that.sessionState,_that.overlaySecondary,_that.overlayFooter);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( CoMapsTurnKind turnKind,  String turnDistance,  String primaryStreet,  String nextTurn,  String currentStreet,  String destination,  String progress,  String timeToNextStop,  String routeTime,  String sessionState,  String overlaySecondary,  String overlayFooter)?  $default,) {final _that = this;
switch (_that) {
case _CoMapsGuidanceDisplay() when $default != null:
return $default(_that.turnKind,_that.turnDistance,_that.primaryStreet,_that.nextTurn,_that.currentStreet,_that.destination,_that.progress,_that.timeToNextStop,_that.routeTime,_that.sessionState,_that.overlaySecondary,_that.overlayFooter);case _:
  return null;

}
}

}

/// @nodoc


class _CoMapsGuidanceDisplay implements CoMapsGuidanceDisplay {
  const _CoMapsGuidanceDisplay({required this.turnKind, required this.turnDistance, required this.primaryStreet, required this.nextTurn, required this.currentStreet, required this.destination, required this.progress, required this.timeToNextStop, required this.routeTime, required this.sessionState, required this.overlaySecondary, required this.overlayFooter});
  

/// The arrow to draw.
@override final  CoMapsTurnKind turnKind;
/// The distance printed under the arrow, on the badge and on the overlay.
@override final  String turnDistance;
/// The street the guidance is about — the headline of the overlay.
@override final  String primaryStreet;
/// "450 m - Elm Street - Turn right - Exit 3", as much of it as exists.
@override final  String nextTurn;
@override final  String currentStreet;
@override final  String destination;
@override final  String progress;
@override final  String timeToNextStop;
@override final  String routeTime;
@override final  String sessionState;
/// The overlay's two secondary lines, already joined.
@override final  String overlaySecondary;
@override final  String overlayFooter;

/// Create a copy of CoMapsGuidanceDisplay
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CoMapsGuidanceDisplayCopyWith<_CoMapsGuidanceDisplay> get copyWith => __$CoMapsGuidanceDisplayCopyWithImpl<_CoMapsGuidanceDisplay>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CoMapsGuidanceDisplay&&(identical(other.turnKind, turnKind) || other.turnKind == turnKind)&&(identical(other.turnDistance, turnDistance) || other.turnDistance == turnDistance)&&(identical(other.primaryStreet, primaryStreet) || other.primaryStreet == primaryStreet)&&(identical(other.nextTurn, nextTurn) || other.nextTurn == nextTurn)&&(identical(other.currentStreet, currentStreet) || other.currentStreet == currentStreet)&&(identical(other.destination, destination) || other.destination == destination)&&(identical(other.progress, progress) || other.progress == progress)&&(identical(other.timeToNextStop, timeToNextStop) || other.timeToNextStop == timeToNextStop)&&(identical(other.routeTime, routeTime) || other.routeTime == routeTime)&&(identical(other.sessionState, sessionState) || other.sessionState == sessionState)&&(identical(other.overlaySecondary, overlaySecondary) || other.overlaySecondary == overlaySecondary)&&(identical(other.overlayFooter, overlayFooter) || other.overlayFooter == overlayFooter));
}


@override
int get hashCode => Object.hash(runtimeType,turnKind,turnDistance,primaryStreet,nextTurn,currentStreet,destination,progress,timeToNextStop,routeTime,sessionState,overlaySecondary,overlayFooter);

@override
String toString() {
  return 'CoMapsGuidanceDisplay(turnKind: $turnKind, turnDistance: $turnDistance, primaryStreet: $primaryStreet, nextTurn: $nextTurn, currentStreet: $currentStreet, destination: $destination, progress: $progress, timeToNextStop: $timeToNextStop, routeTime: $routeTime, sessionState: $sessionState, overlaySecondary: $overlaySecondary, overlayFooter: $overlayFooter)';
}


}

/// @nodoc
abstract mixin class _$CoMapsGuidanceDisplayCopyWith<$Res> implements $CoMapsGuidanceDisplayCopyWith<$Res> {
  factory _$CoMapsGuidanceDisplayCopyWith(_CoMapsGuidanceDisplay value, $Res Function(_CoMapsGuidanceDisplay) _then) = __$CoMapsGuidanceDisplayCopyWithImpl;
@override @useResult
$Res call({
 CoMapsTurnKind turnKind, String turnDistance, String primaryStreet, String nextTurn, String currentStreet, String destination, String progress, String timeToNextStop, String routeTime, String sessionState, String overlaySecondary, String overlayFooter
});




}
/// @nodoc
class __$CoMapsGuidanceDisplayCopyWithImpl<$Res>
    implements _$CoMapsGuidanceDisplayCopyWith<$Res> {
  __$CoMapsGuidanceDisplayCopyWithImpl(this._self, this._then);

  final _CoMapsGuidanceDisplay _self;
  final $Res Function(_CoMapsGuidanceDisplay) _then;

/// Create a copy of CoMapsGuidanceDisplay
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? turnKind = null,Object? turnDistance = null,Object? primaryStreet = null,Object? nextTurn = null,Object? currentStreet = null,Object? destination = null,Object? progress = null,Object? timeToNextStop = null,Object? routeTime = null,Object? sessionState = null,Object? overlaySecondary = null,Object? overlayFooter = null,}) {
  return _then(_CoMapsGuidanceDisplay(
turnKind: null == turnKind ? _self.turnKind : turnKind // ignore: cast_nullable_to_non_nullable
as CoMapsTurnKind,turnDistance: null == turnDistance ? _self.turnDistance : turnDistance // ignore: cast_nullable_to_non_nullable
as String,primaryStreet: null == primaryStreet ? _self.primaryStreet : primaryStreet // ignore: cast_nullable_to_non_nullable
as String,nextTurn: null == nextTurn ? _self.nextTurn : nextTurn // ignore: cast_nullable_to_non_nullable
as String,currentStreet: null == currentStreet ? _self.currentStreet : currentStreet // ignore: cast_nullable_to_non_nullable
as String,destination: null == destination ? _self.destination : destination // ignore: cast_nullable_to_non_nullable
as String,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as String,timeToNextStop: null == timeToNextStop ? _self.timeToNextStop : timeToNextStop // ignore: cast_nullable_to_non_nullable
as String,routeTime: null == routeTime ? _self.routeTime : routeTime // ignore: cast_nullable_to_non_nullable
as String,sessionState: null == sessionState ? _self.sessionState : sessionState // ignore: cast_nullable_to_non_nullable
as String,overlaySecondary: null == overlaySecondary ? _self.overlaySecondary : overlaySecondary // ignore: cast_nullable_to_non_nullable
as String,overlayFooter: null == overlayFooter ? _self.overlayFooter : overlayFooter // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
