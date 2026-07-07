// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'activities_notifier.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ActivitiesState {

 LocalDate get selectedDate; TimeRange get selectedRange; bool get isLoading; ScreenError? get error; List<ExerciseData> get workouts; List<PlannedExerciseData> get plannedWorkouts;
/// Create a copy of ActivitiesState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ActivitiesStateCopyWith<ActivitiesState> get copyWith => _$ActivitiesStateCopyWithImpl<ActivitiesState>(this as ActivitiesState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ActivitiesState&&(identical(other.selectedDate, selectedDate) || other.selectedDate == selectedDate)&&(identical(other.selectedRange, selectedRange) || other.selectedRange == selectedRange)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.error, error) || other.error == error)&&const DeepCollectionEquality().equals(other.workouts, workouts)&&const DeepCollectionEquality().equals(other.plannedWorkouts, plannedWorkouts));
}


@override
int get hashCode => Object.hash(runtimeType,selectedDate,selectedRange,isLoading,error,const DeepCollectionEquality().hash(workouts),const DeepCollectionEquality().hash(plannedWorkouts));

@override
String toString() {
  return 'ActivitiesState(selectedDate: $selectedDate, selectedRange: $selectedRange, isLoading: $isLoading, error: $error, workouts: $workouts, plannedWorkouts: $plannedWorkouts)';
}


}

/// @nodoc
abstract mixin class $ActivitiesStateCopyWith<$Res>  {
  factory $ActivitiesStateCopyWith(ActivitiesState value, $Res Function(ActivitiesState) _then) = _$ActivitiesStateCopyWithImpl;
@useResult
$Res call({
 LocalDate selectedDate, TimeRange selectedRange, bool isLoading, ScreenError? error, List<ExerciseData> workouts, List<PlannedExerciseData> plannedWorkouts
});




}
/// @nodoc
class _$ActivitiesStateCopyWithImpl<$Res>
    implements $ActivitiesStateCopyWith<$Res> {
  _$ActivitiesStateCopyWithImpl(this._self, this._then);

  final ActivitiesState _self;
  final $Res Function(ActivitiesState) _then;

/// Create a copy of ActivitiesState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? selectedDate = null,Object? selectedRange = null,Object? isLoading = null,Object? error = freezed,Object? workouts = null,Object? plannedWorkouts = null,}) {
  return _then(_self.copyWith(
selectedDate: null == selectedDate ? _self.selectedDate : selectedDate // ignore: cast_nullable_to_non_nullable
as LocalDate,selectedRange: null == selectedRange ? _self.selectedRange : selectedRange // ignore: cast_nullable_to_non_nullable
as TimeRange,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as ScreenError?,workouts: null == workouts ? _self.workouts : workouts // ignore: cast_nullable_to_non_nullable
as List<ExerciseData>,plannedWorkouts: null == plannedWorkouts ? _self.plannedWorkouts : plannedWorkouts // ignore: cast_nullable_to_non_nullable
as List<PlannedExerciseData>,
  ));
}

}


/// Adds pattern-matching-related methods to [ActivitiesState].
extension ActivitiesStatePatterns on ActivitiesState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ActivitiesState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ActivitiesState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ActivitiesState value)  $default,){
final _that = this;
switch (_that) {
case _ActivitiesState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ActivitiesState value)?  $default,){
final _that = this;
switch (_that) {
case _ActivitiesState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LocalDate selectedDate,  TimeRange selectedRange,  bool isLoading,  ScreenError? error,  List<ExerciseData> workouts,  List<PlannedExerciseData> plannedWorkouts)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ActivitiesState() when $default != null:
return $default(_that.selectedDate,_that.selectedRange,_that.isLoading,_that.error,_that.workouts,_that.plannedWorkouts);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LocalDate selectedDate,  TimeRange selectedRange,  bool isLoading,  ScreenError? error,  List<ExerciseData> workouts,  List<PlannedExerciseData> plannedWorkouts)  $default,) {final _that = this;
switch (_that) {
case _ActivitiesState():
return $default(_that.selectedDate,_that.selectedRange,_that.isLoading,_that.error,_that.workouts,_that.plannedWorkouts);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LocalDate selectedDate,  TimeRange selectedRange,  bool isLoading,  ScreenError? error,  List<ExerciseData> workouts,  List<PlannedExerciseData> plannedWorkouts)?  $default,) {final _that = this;
switch (_that) {
case _ActivitiesState() when $default != null:
return $default(_that.selectedDate,_that.selectedRange,_that.isLoading,_that.error,_that.workouts,_that.plannedWorkouts);case _:
  return null;

}
}

}

/// @nodoc


class _ActivitiesState extends ActivitiesState {
  const _ActivitiesState({required this.selectedDate, this.selectedRange = TimeRange.week, this.isLoading = true, this.error, final  List<ExerciseData> workouts = const <ExerciseData>[], final  List<PlannedExerciseData> plannedWorkouts = const <PlannedExerciseData>[]}): _workouts = workouts,_plannedWorkouts = plannedWorkouts,super._();
  

@override final  LocalDate selectedDate;
@override@JsonKey() final  TimeRange selectedRange;
@override@JsonKey() final  bool isLoading;
@override final  ScreenError? error;
 final  List<ExerciseData> _workouts;
@override@JsonKey() List<ExerciseData> get workouts {
  if (_workouts is EqualUnmodifiableListView) return _workouts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_workouts);
}

 final  List<PlannedExerciseData> _plannedWorkouts;
@override@JsonKey() List<PlannedExerciseData> get plannedWorkouts {
  if (_plannedWorkouts is EqualUnmodifiableListView) return _plannedWorkouts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_plannedWorkouts);
}


/// Create a copy of ActivitiesState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ActivitiesStateCopyWith<_ActivitiesState> get copyWith => __$ActivitiesStateCopyWithImpl<_ActivitiesState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ActivitiesState&&(identical(other.selectedDate, selectedDate) || other.selectedDate == selectedDate)&&(identical(other.selectedRange, selectedRange) || other.selectedRange == selectedRange)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.error, error) || other.error == error)&&const DeepCollectionEquality().equals(other._workouts, _workouts)&&const DeepCollectionEquality().equals(other._plannedWorkouts, _plannedWorkouts));
}


@override
int get hashCode => Object.hash(runtimeType,selectedDate,selectedRange,isLoading,error,const DeepCollectionEquality().hash(_workouts),const DeepCollectionEquality().hash(_plannedWorkouts));

@override
String toString() {
  return 'ActivitiesState(selectedDate: $selectedDate, selectedRange: $selectedRange, isLoading: $isLoading, error: $error, workouts: $workouts, plannedWorkouts: $plannedWorkouts)';
}


}

/// @nodoc
abstract mixin class _$ActivitiesStateCopyWith<$Res> implements $ActivitiesStateCopyWith<$Res> {
  factory _$ActivitiesStateCopyWith(_ActivitiesState value, $Res Function(_ActivitiesState) _then) = __$ActivitiesStateCopyWithImpl;
@override @useResult
$Res call({
 LocalDate selectedDate, TimeRange selectedRange, bool isLoading, ScreenError? error, List<ExerciseData> workouts, List<PlannedExerciseData> plannedWorkouts
});




}
/// @nodoc
class __$ActivitiesStateCopyWithImpl<$Res>
    implements _$ActivitiesStateCopyWith<$Res> {
  __$ActivitiesStateCopyWithImpl(this._self, this._then);

  final _ActivitiesState _self;
  final $Res Function(_ActivitiesState) _then;

/// Create a copy of ActivitiesState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? selectedDate = null,Object? selectedRange = null,Object? isLoading = null,Object? error = freezed,Object? workouts = null,Object? plannedWorkouts = null,}) {
  return _then(_ActivitiesState(
selectedDate: null == selectedDate ? _self.selectedDate : selectedDate // ignore: cast_nullable_to_non_nullable
as LocalDate,selectedRange: null == selectedRange ? _self.selectedRange : selectedRange // ignore: cast_nullable_to_non_nullable
as TimeRange,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as ScreenError?,workouts: null == workouts ? _self._workouts : workouts // ignore: cast_nullable_to_non_nullable
as List<ExerciseData>,plannedWorkouts: null == plannedWorkouts ? _self._plannedWorkouts : plannedWorkouts // ignore: cast_nullable_to_non_nullable
as List<PlannedExerciseData>,
  ));
}


}

// dart format on
