// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:build/build.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

import 'build_target.dart';
import 'common.dart';
import 'expandos.dart';
import 'input_set.dart';
import 'key_normalization.dart';

part 'builder_definition.g.dart';

enum AutoApply { none, dependents, allPackages, rootPackage }

enum BuildTo {
  /// Generated files are written to the source directory next to their primary
  /// inputs.
  source,

  /// Generated files are written to the hidden 'generated' directory.
  cache
}

/// Definition of a builder parsed from the `builders` section of `build.yaml`.
@JsonSerializable(createToJson: false)
class BuilderDefinition {
  /// The package which provides this Builder.
  String get package => packageExpando[this];

  /// A unique key for this Builder in `'$package|$builder'` format.
  String get key => builderKeyExpando[this];

  /// The names of the top-level methods in [import] from args -> Builder.
  @JsonKey(name: 'builder_factories', nullable: false)
  final List<String> builderFactories;

  /// The import to be used to load `clazz`.
  @JsonKey(nullable: false)
  final String import;

  /// A map from input extension to the output extensions created for matching
  /// inputs.
  @JsonKey(name: 'build_extensions', nullable: false)
  final Map<String, List<String>> buildExtensions;

  /// The name of the dart_library target that contains `import`.
  ///
  /// May be null or unreliable and should not be used.
  @deprecated
  final String target;

  /// Which packages should have this builder applied automatically.
  @JsonKey(name: 'auto_apply', fromJson: _autoApplyFromJson)
  final AutoApply autoApply;

  /// A list of file extensions which are required to run this builder.
  ///
  /// No builder which outputs any extension in this list is allowed to run
  /// after this builder.
  @JsonKey(name: 'required_inputs')
  final List<String> requiredInputs;

  /// Builder keys in `$package|$builder` format which should only be run after
  /// this Builder.
  @JsonKey(name: 'runs_before')
  final List<String> runsBefore;

  /// Builder keys in `$package|$builder` format which should be run on any
  /// target which also runs this Builder.
  @JsonKey(name: 'applies_builders')
  final List<String> appliesBuilders;

  /// Whether this Builder should be deferred until it's output is requested.
  ///
  /// Optional builders are lazy and will not run unless some later builder
  /// requests one of it's possible outputs through either `readAs*` or
  /// `canRead`.
  @JsonKey(name: 'is_optional')
  final bool isOptional;

  /// Where the outputs of this builder should be written.
  @JsonKey(name: 'build_to', fromJson: _buildToFromJson)
  final BuildTo buildTo;

  final TargetBuilderConfigDefaults defaults;

  BuilderDefinition({
    @required this.builderFactories,
    @required this.buildExtensions,
    @required this.import,
    String target,
    AutoApply autoApply,
    Iterable<String> requiredInputs,
    Iterable<String> runsBefore,
    Iterable<String> appliesBuilders,
    bool isOptional,
    BuildTo buildTo,
    TargetBuilderConfigDefaults defaults,
  })  :
        // ignore: deprecated_member_use
        this.target = target != null
            ? normalizeTargetKeyUsage(target, currentPackage)
            : null,
        this.autoApply = autoApply ?? AutoApply.none,
        this.requiredInputs = requiredInputs?.toList() ?? const [],
        this.runsBefore = runsBefore
                ?.map((builder) =>
                    normalizeBuilderKeyUsage(builder, currentPackage))
                ?.toList() ??
            const [],
        this.appliesBuilders = appliesBuilders
                ?.map((builder) =>
                    normalizeBuilderKeyUsage(builder, currentPackage))
                ?.toList() ??
            const [],
        this.isOptional = isOptional ?? false,
        this.buildTo = buildTo ?? BuildTo.cache,
        this.defaults = defaults ?? const TargetBuilderConfigDefaults() {
    if (builderFactories.isEmpty) {
      throw new ArgumentError.value(builderFactories, 'builderFactories',
          'Must have at least one value.');
    }
  }

  factory BuilderDefinition.fromJson(Map json) =>
      _$BuilderDefinitionFromJson(json);

  @override
  String toString() => {
        'autoApply': autoApply,
        'import': import,
        'builderFactories': builderFactories,
        'buildExtensions': buildExtensions,
        'requiredInputs': requiredInputs,
        'runsBefore': runsBefore,
        'isOptional': isOptional,
        'buildTo': buildTo,
        'defaults': defaults,
      }.toString();
}

/// The definition of a `PostProcessBuilder` in the `post_process_builders`
/// section of a `build.yaml`.
@JsonSerializable(createToJson: false)
class PostProcessBuilderDefinition {
  /// The package which provides this Builder.
  String get package => packageExpando[this];

  /// A unique key for this Builder in `'$package|$builder'` format.
  String get key => builderKeyExpando[this];

  /// The name of the top-level method in [import] from
  /// BuilderOptions -> Builder.
  @JsonKey(name: 'builder_factory', nullable: false)
  final String builderFactory;

  /// The import to be used to load `clazz`.
  @JsonKey(nullable: false)
  final String import;

  /// A list of input extensions for this builder.
  ///
  /// May be null or unreliable and should not be used.
  @deprecated
  @JsonKey(name: 'input_extensions')
  final Iterable<String> inputExtensions;

  /// The name of the dart_library target that contains `import`.
  ///
  /// May be null or unreliable and should not be used.
  @deprecated
  final String target;

  final TargetBuilderConfigDefaults defaults;

  PostProcessBuilderDefinition({
    @required this.builderFactory,
    @required this.import,
    this.inputExtensions,
    this.target,
    TargetBuilderConfigDefaults defaults,
  }) : this.defaults = defaults ?? const TargetBuilderConfigDefaults();

  factory PostProcessBuilderDefinition.fromJson(Map json) =>
      _$PostProcessBuilderDefinitionFromJson(json);

  @override
  String toString() => {
        'import': import,
        'builderFactory': builderFactory,
        'defaults': defaults,
      }.toString();
}

/// Default values that builder authors can specify when users don't fill in the
/// corresponding key for [TargetBuilderConfig].
@JsonSerializable(createToJson: false)
class TargetBuilderConfigDefaults {
  @JsonKey(name: 'generate_for')
  final InputSet generateFor;

  @JsonKey(fromJson: builderOptionsFromJson)
  final BuilderOptions options;

  @JsonKey(name: 'dev_options', fromJson: builderOptionsFromJson)
  final BuilderOptions devOptions;

  @JsonKey(name: 'release_options', fromJson: builderOptionsFromJson)
  final BuilderOptions releaseOptions;

  const TargetBuilderConfigDefaults({
    InputSet generateFor,
    BuilderOptions options,
    BuilderOptions devOptions,
    BuilderOptions releaseOptions,
  })  : generateFor = generateFor ?? InputSet.anything,
        options = options ?? BuilderOptions.empty,
        devOptions = devOptions ?? BuilderOptions.empty,
        releaseOptions = releaseOptions ?? BuilderOptions.empty;

  factory TargetBuilderConfigDefaults.fromJson(Map json) =>
      _$TargetBuilderConfigDefaultsFromJson(json);
}

const _autoApplyConvert = const {
  'none': AutoApply.none,
  'dependents': AutoApply.dependents,
  'all_packages': AutoApply.allPackages,
  'root_package': AutoApply.rootPackage
};

AutoApply _autoApplyFromJson(String input) {
  var value = _autoApplyConvert[input];
  if (value == null) {
    var allowed = _autoApplyConvert.keys.map((e) => '"$e"').join(', ');
    throw new ArgumentError.value(
        input, 'autoApply', '"$input" is not in the supported set: $allowed.');
  }
  return value;
}

BuildTo _buildToFromJson(String input) => BuildTo.values
        .firstWhere((e) => e.toString() == 'BuildTo.$input', orElse: () {
      var allowed = BuildTo.values.join(', ');
      throw new ArgumentError.value(
          input, 'build_to', '"$input" is not in the supported set: $allowed.');
    });
