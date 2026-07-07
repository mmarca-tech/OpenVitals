// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mindfulness_entry_notifier.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MindfulnessEntryState {

 String get manualMinutesText; Set<String> get writePermissions; bool get canWrite; bool get mindfulnessAvailable; bool get isCheckingPermission; bool get isSavingEntry; String? get editRecordId; DateTime? get editStartTime; bool get saveCompleted; MindfulnessEntryError? get entryError; ScreenError? get writeError;
/// Create a copy of MindfulnessEntryState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MindfulnessEntryStateCopyWith<MindfulnessEntryState> get copyWith => _$MindfulnessEntryStateCopyWithImpl<MindfulnessEntryState>(this as MindfulnessEntryState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MindfulnessEntryState&&(identical(other.manualMinutesText, manualMinutesText) || other.manualMinutesText == manualMinutesText)&&const DeepCollectionEquality().equals(other.writePermissions, writePermissions)&&(identical(other.canWrite, canWrite) || other.canWrite == canWrite)&&(identical(other.mindfulnessAvailable, mindfulnessAvailable) || other.mindfulnessAvailable == mindfulnessAvailable)&&(identical(other.isCheckingPermission, isCheckingPermission) || other.isCheckingPermission == isCheckingPermission)&&(identical(other.isSavingEntry, isSavingEntry) || other.isSavingEntry == isSavingEntry)&&(identical(other.editRecordId, editRecordId) || other.editRecordId == editRecordId)&&(identical(other.editStartTime, editStartTime) || other.editStartTime == editStartTime)&&(identical(other.saveCompleted, saveCompleted) || other.saveCompleted == saveCompleted)&&(identical(other.entryError, entryError) || other.entryError == entryError)&&(identical(other.writeError, writeError) || other.writeError == writeError));
}


@override
int get hashCode => Object.hash(runtimeType,manualMinutesText,const DeepCollectionEquality().hash(writePermissions),canWrite,mindfulnessAvailable,isCheckingPermission,isSavingEntry,editRecordId,editStartTime,saveCompleted,entryError,writeError);

@override
String toString() {
  return 'MindfulnessEntryState(manualMinutesText: $manualMinutesText, writePermissions: $writePermissions, canWrite: $canWrite, mindfulnessAvailable: $mindfulnessAvailable, isCheckingPermission: $isCheckingPermission, isSavingEntry: $isSavingEntry, editRecordId: $editRecordId, editStartTime: $editStartTime, saveCompleted: $saveCompleted, entryError: $entryError, writeError: $writeError)';
}


}

/// @nodoc
abstract mixin class $MindfulnessEntryStateCopyWith<$Res>  {
  factory $MindfulnessEntryStateCopyWith(MindfulnessEntryState value, $Res Function(MindfulnessEntryState) _then) = _$MindfulnessEntryStateCopyWithImpl;
@useResult
$Res call({
 String manualMinutesText, Set<String> writePermissions, bool canWrite, bool mindfulnessAvailable, bool isCheckingPermission, bool isSavingEntry, String? editRecordId, DateTime? editStartTime, bool saveCompleted, MindfulnessEntryError? entryError, ScreenError? writeError
});




}
/// @nodoc
class _$MindfulnessEntryStateCopyWithImpl<$Res>
    implements $MindfulnessEntryStateCopyWith<$Res> {
  _$MindfulnessEntryStateCopyWithImpl(this._self, this._then);

  final MindfulnessEntryState _self;
  final $Res Function(MindfulnessEntryState) _then;

/// Create a copy of MindfulnessEntryState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? manualMinutesText = null,Object? writePermissions = null,Object? canWrite = null,Object? mindfulnessAvailable = null,Object? isCheckingPermission = null,Object? isSavingEntry = null,Object? editRecordId = freezed,Object? editStartTime = freezed,Object? saveCompleted = null,Object? entryError = freezed,Object? writeError = freezed,}) {
  return _then(_self.copyWith(
manualMinutesText: null == manualMinutesText ? _self.manualMinutesText : manualMinutesText // ignore: cast_nullable_to_non_nullable
as String,writePermissions: null == writePermissions ? _self.writePermissions : writePermissions // ignore: cast_nullable_to_non_nullable
as Set<String>,canWrite: null == canWrite ? _self.canWrite : canWrite // ignore: cast_nullable_to_non_nullable
as bool,mindfulnessAvailable: null == mindfulnessAvailable ? _self.mindfulnessAvailable : mindfulnessAvailable // ignore: cast_nullable_to_non_nullable
as bool,isCheckingPermission: null == isCheckingPermission ? _self.isCheckingPermission : isCheckingPermission // ignore: cast_nullable_to_non_nullable
as bool,isSavingEntry: null == isSavingEntry ? _self.isSavingEntry : isSavingEntry // ignore: cast_nullable_to_non_nullable
as bool,editRecordId: freezed == editRecordId ? _self.editRecordId : editRecordId // ignore: cast_nullable_to_non_nullable
as String?,editStartTime: freezed == editStartTime ? _self.editStartTime : editStartTime // ignore: cast_nullable_to_non_nullable
as DateTime?,saveCompleted: null == saveCompleted ? _self.saveCompleted : saveCompleted // ignore: cast_nullable_to_non_nullable
as bool,entryError: freezed == entryError ? _self.entryError : entryError // ignore: cast_nullable_to_non_nullable
as MindfulnessEntryError?,writeError: freezed == writeError ? _self.writeError : writeError // ignore: cast_nullable_to_non_nullable
as ScreenError?,
  ));
}

}


/// Adds pattern-matching-related methods to [MindfulnessEntryState].
extension MindfulnessEntryStatePatterns on MindfulnessEntryState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MindfulnessEntryState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MindfulnessEntryState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MindfulnessEntryState value)  $default,){
final _that = this;
switch (_that) {
case _MindfulnessEntryState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MindfulnessEntryState value)?  $default,){
final _that = this;
switch (_that) {
case _MindfulnessEntryState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String manualMinutesText,  Set<String> writePermissions,  bool canWrite,  bool mindfulnessAvailable,  bool isCheckingPermission,  bool isSavingEntry,  String? editRecordId,  DateTime? editStartTime,  bool saveCompleted,  MindfulnessEntryError? entryError,  ScreenError? writeError)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MindfulnessEntryState() when $default != null:
return $default(_that.manualMinutesText,_that.writePermissions,_that.canWrite,_that.mindfulnessAvailable,_that.isCheckingPermission,_that.isSavingEntry,_that.editRecordId,_that.editStartTime,_that.saveCompleted,_that.entryError,_that.writeError);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String manualMinutesText,  Set<String> writePermissions,  bool canWrite,  bool mindfulnessAvailable,  bool isCheckingPermission,  bool isSavingEntry,  String? editRecordId,  DateTime? editStartTime,  bool saveCompleted,  MindfulnessEntryError? entryError,  ScreenError? writeError)  $default,) {final _that = this;
switch (_that) {
case _MindfulnessEntryState():
return $default(_that.manualMinutesText,_that.writePermissions,_that.canWrite,_that.mindfulnessAvailable,_that.isCheckingPermission,_that.isSavingEntry,_that.editRecordId,_that.editStartTime,_that.saveCompleted,_that.entryError,_that.writeError);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String manualMinutesText,  Set<String> writePermissions,  bool canWrite,  bool mindfulnessAvailable,  bool isCheckingPermission,  bool isSavingEntry,  String? editRecordId,  DateTime? editStartTime,  bool saveCompleted,  MindfulnessEntryError? entryError,  ScreenError? writeError)?  $default,) {final _that = this;
switch (_that) {
case _MindfulnessEntryState() when $default != null:
return $default(_that.manualMinutesText,_that.writePermissions,_that.canWrite,_that.mindfulnessAvailable,_that.isCheckingPermission,_that.isSavingEntry,_that.editRecordId,_that.editStartTime,_that.saveCompleted,_that.entryError,_that.writeError);case _:
  return null;

}
}

}

/// @nodoc


class _MindfulnessEntryState extends MindfulnessEntryState {
  const _MindfulnessEntryState({this.manualMinutesText = '', final  Set<String> writePermissions = const <String>{}, this.canWrite = false, this.mindfulnessAvailable = true, this.isCheckingPermission = true, this.isSavingEntry = false, this.editRecordId, this.editStartTime, this.saveCompleted = false, this.entryError, this.writeError}): _writePermissions = writePermissions,super._();
  

@override@JsonKey() final  String manualMinutesText;
 final  Set<String> _writePermissions;
@override@JsonKey() Set<String> get writePermissions {
  if (_writePermissions is EqualUnmodifiableSetView) return _writePermissions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_writePermissions);
}

@override@JsonKey() final  bool canWrite;
@override@JsonKey() final  bool mindfulnessAvailable;
@override@JsonKey() final  bool isCheckingPermission;
@override@JsonKey() final  bool isSavingEntry;
@override final  String? editRecordId;
@override final  DateTime? editStartTime;
@override@JsonKey() final  bool saveCompleted;
@override final  MindfulnessEntryError? entryError;
@override final  ScreenError? writeError;

/// Create a copy of MindfulnessEntryState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MindfulnessEntryStateCopyWith<_MindfulnessEntryState> get copyWith => __$MindfulnessEntryStateCopyWithImpl<_MindfulnessEntryState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MindfulnessEntryState&&(identical(other.manualMinutesText, manualMinutesText) || other.manualMinutesText == manualMinutesText)&&const DeepCollectionEquality().equals(other._writePermissions, _writePermissions)&&(identical(other.canWrite, canWrite) || other.canWrite == canWrite)&&(identical(other.mindfulnessAvailable, mindfulnessAvailable) || other.mindfulnessAvailable == mindfulnessAvailable)&&(identical(other.isCheckingPermission, isCheckingPermission) || other.isCheckingPermission == isCheckingPermission)&&(identical(other.isSavingEntry, isSavingEntry) || other.isSavingEntry == isSavingEntry)&&(identical(other.editRecordId, editRecordId) || other.editRecordId == editRecordId)&&(identical(other.editStartTime, editStartTime) || other.editStartTime == editStartTime)&&(identical(other.saveCompleted, saveCompleted) || other.saveCompleted == saveCompleted)&&(identical(other.entryError, entryError) || other.entryError == entryError)&&(identical(other.writeError, writeError) || other.writeError == writeError));
}


@override
int get hashCode => Object.hash(runtimeType,manualMinutesText,const DeepCollectionEquality().hash(_writePermissions),canWrite,mindfulnessAvailable,isCheckingPermission,isSavingEntry,editRecordId,editStartTime,saveCompleted,entryError,writeError);

@override
String toString() {
  return 'MindfulnessEntryState(manualMinutesText: $manualMinutesText, writePermissions: $writePermissions, canWrite: $canWrite, mindfulnessAvailable: $mindfulnessAvailable, isCheckingPermission: $isCheckingPermission, isSavingEntry: $isSavingEntry, editRecordId: $editRecordId, editStartTime: $editStartTime, saveCompleted: $saveCompleted, entryError: $entryError, writeError: $writeError)';
}


}

/// @nodoc
abstract mixin class _$MindfulnessEntryStateCopyWith<$Res> implements $MindfulnessEntryStateCopyWith<$Res> {
  factory _$MindfulnessEntryStateCopyWith(_MindfulnessEntryState value, $Res Function(_MindfulnessEntryState) _then) = __$MindfulnessEntryStateCopyWithImpl;
@override @useResult
$Res call({
 String manualMinutesText, Set<String> writePermissions, bool canWrite, bool mindfulnessAvailable, bool isCheckingPermission, bool isSavingEntry, String? editRecordId, DateTime? editStartTime, bool saveCompleted, MindfulnessEntryError? entryError, ScreenError? writeError
});




}
/// @nodoc
class __$MindfulnessEntryStateCopyWithImpl<$Res>
    implements _$MindfulnessEntryStateCopyWith<$Res> {
  __$MindfulnessEntryStateCopyWithImpl(this._self, this._then);

  final _MindfulnessEntryState _self;
  final $Res Function(_MindfulnessEntryState) _then;

/// Create a copy of MindfulnessEntryState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? manualMinutesText = null,Object? writePermissions = null,Object? canWrite = null,Object? mindfulnessAvailable = null,Object? isCheckingPermission = null,Object? isSavingEntry = null,Object? editRecordId = freezed,Object? editStartTime = freezed,Object? saveCompleted = null,Object? entryError = freezed,Object? writeError = freezed,}) {
  return _then(_MindfulnessEntryState(
manualMinutesText: null == manualMinutesText ? _self.manualMinutesText : manualMinutesText // ignore: cast_nullable_to_non_nullable
as String,writePermissions: null == writePermissions ? _self._writePermissions : writePermissions // ignore: cast_nullable_to_non_nullable
as Set<String>,canWrite: null == canWrite ? _self.canWrite : canWrite // ignore: cast_nullable_to_non_nullable
as bool,mindfulnessAvailable: null == mindfulnessAvailable ? _self.mindfulnessAvailable : mindfulnessAvailable // ignore: cast_nullable_to_non_nullable
as bool,isCheckingPermission: null == isCheckingPermission ? _self.isCheckingPermission : isCheckingPermission // ignore: cast_nullable_to_non_nullable
as bool,isSavingEntry: null == isSavingEntry ? _self.isSavingEntry : isSavingEntry // ignore: cast_nullable_to_non_nullable
as bool,editRecordId: freezed == editRecordId ? _self.editRecordId : editRecordId // ignore: cast_nullable_to_non_nullable
as String?,editStartTime: freezed == editStartTime ? _self.editStartTime : editStartTime // ignore: cast_nullable_to_non_nullable
as DateTime?,saveCompleted: null == saveCompleted ? _self.saveCompleted : saveCompleted // ignore: cast_nullable_to_non_nullable
as bool,entryError: freezed == entryError ? _self.entryError : entryError // ignore: cast_nullable_to_non_nullable
as MindfulnessEntryError?,writeError: freezed == writeError ? _self.writeError : writeError // ignore: cast_nullable_to_non_nullable
as ScreenError?,
  ));
}


}

// dart format on
