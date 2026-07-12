// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'activity_navigation_display.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ActivityNavigationRow {

/// The street the guidance was about.
 String get title;/// "450 m to turn - 1.2 km to destination - Turn right - Exit 3".
 String get detail;/// "10:32 - Following route - 63% complete".
 String get meta;
/// Create a copy of ActivityNavigationRow
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ActivityNavigationRowCopyWith<ActivityNavigationRow> get copyWith => _$ActivityNavigationRowCopyWithImpl<ActivityNavigationRow>(this as ActivityNavigationRow, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ActivityNavigationRow&&(identical(other.title, title) || other.title == title)&&(identical(other.detail, detail) || other.detail == detail)&&(identical(other.meta, meta) || other.meta == meta));
}


@override
int get hashCode => Object.hash(runtimeType,title,detail,meta);

@override
String toString() {
  return 'ActivityNavigationRow(title: $title, detail: $detail, meta: $meta)';
}


}

/// @nodoc
abstract mixin class $ActivityNavigationRowCopyWith<$Res>  {
  factory $ActivityNavigationRowCopyWith(ActivityNavigationRow value, $Res Function(ActivityNavigationRow) _then) = _$ActivityNavigationRowCopyWithImpl;
@useResult
$Res call({
 String title, String detail, String meta
});




}
/// @nodoc
class _$ActivityNavigationRowCopyWithImpl<$Res>
    implements $ActivityNavigationRowCopyWith<$Res> {
  _$ActivityNavigationRowCopyWithImpl(this._self, this._then);

  final ActivityNavigationRow _self;
  final $Res Function(ActivityNavigationRow) _then;

/// Create a copy of ActivityNavigationRow
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = null,Object? detail = null,Object? meta = null,}) {
  return _then(_self.copyWith(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,detail: null == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as String,meta: null == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ActivityNavigationRow].
extension ActivityNavigationRowPatterns on ActivityNavigationRow {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ActivityNavigationRow value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ActivityNavigationRow() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ActivityNavigationRow value)  $default,){
final _that = this;
switch (_that) {
case _ActivityNavigationRow():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ActivityNavigationRow value)?  $default,){
final _that = this;
switch (_that) {
case _ActivityNavigationRow() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String title,  String detail,  String meta)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ActivityNavigationRow() when $default != null:
return $default(_that.title,_that.detail,_that.meta);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String title,  String detail,  String meta)  $default,) {final _that = this;
switch (_that) {
case _ActivityNavigationRow():
return $default(_that.title,_that.detail,_that.meta);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String title,  String detail,  String meta)?  $default,) {final _that = this;
switch (_that) {
case _ActivityNavigationRow() when $default != null:
return $default(_that.title,_that.detail,_that.meta);case _:
  return null;

}
}

}

/// @nodoc


class _ActivityNavigationRow implements ActivityNavigationRow {
  const _ActivityNavigationRow({required this.title, required this.detail, required this.meta});
  

/// The street the guidance was about.
@override final  String title;
/// "450 m to turn - 1.2 km to destination - Turn right - Exit 3".
@override final  String detail;
/// "10:32 - Following route - 63% complete".
@override final  String meta;

/// Create a copy of ActivityNavigationRow
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ActivityNavigationRowCopyWith<_ActivityNavigationRow> get copyWith => __$ActivityNavigationRowCopyWithImpl<_ActivityNavigationRow>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ActivityNavigationRow&&(identical(other.title, title) || other.title == title)&&(identical(other.detail, detail) || other.detail == detail)&&(identical(other.meta, meta) || other.meta == meta));
}


@override
int get hashCode => Object.hash(runtimeType,title,detail,meta);

@override
String toString() {
  return 'ActivityNavigationRow(title: $title, detail: $detail, meta: $meta)';
}


}

/// @nodoc
abstract mixin class _$ActivityNavigationRowCopyWith<$Res> implements $ActivityNavigationRowCopyWith<$Res> {
  factory _$ActivityNavigationRowCopyWith(_ActivityNavigationRow value, $Res Function(_ActivityNavigationRow) _then) = __$ActivityNavigationRowCopyWithImpl;
@override @useResult
$Res call({
 String title, String detail, String meta
});




}
/// @nodoc
class __$ActivityNavigationRowCopyWithImpl<$Res>
    implements _$ActivityNavigationRowCopyWith<$Res> {
  __$ActivityNavigationRowCopyWithImpl(this._self, this._then);

  final _ActivityNavigationRow _self;
  final $Res Function(_ActivityNavigationRow) _then;

/// Create a copy of ActivityNavigationRow
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = null,Object? detail = null,Object? meta = null,}) {
  return _then(_ActivityNavigationRow(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,detail: null == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as String,meta: null == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
