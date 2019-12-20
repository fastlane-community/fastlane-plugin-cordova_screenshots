# cordova_screenshots plugin

[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-cordova_screenshots) [![License](https://img.shields.io/badge/license-MIT-green.svg?style=flat)](https://github.com/ionic-zone/fastlane-plugin-cordova_screenshots/blob/master/LICENSE)
[![Gem](https://img.shields.io/gem/v/fastlane-plugin-cordova_screenshots.svg?style=flat)](http://rubygems.org/gems/fastlane-plugin-cordova_screenshots)

This _fastlane_ plugin enables you to **create automated screenshots** of your **Cordova (or Ionic) project**, both for iOS and Android, with _fastlane_ using the normal [`capture_ios_screenshots`](https://docs.fastlane.tools/actions/capture_ios_screenshots/) and [`capture_android_screenshots`](https://docs.fastlane.tools/actions/capture_android_screenshots/) actions or [`fastlane snapshot`](https://docs.fastlane.tools/actions/snapshot/) (for iOS) or [`fastlane screengrab`](https://docs.fastlane.tools/actions/screengrab/) (for Android) commands.

This usually is a challenge, as these require you to modify your native projects and add some files. Cordova projects are generated for you and not tracked by version control, so those changes (including the test files your wrote) would get lost frequently.

By keeping your test files in your `fastlane` folder and offering an action to "retrofit" them to your native projects each time before running the screenshot creation actions, this plugin offers a way around that.

## Getting Started

This project is a [_fastlane_](https://github.com/fastlane/fastlane) plugin. To get started with `fastlane-plugin-cordova_screenshots`, add it to your project by running:

```bash
fastlane add_plugin cordova_screenshots
```

## Actions

- [`init_cordova_screenshots_ios`](#init_cordova_screenshots_ios)
- [`retrofit_cordova_screenshots_ios`](#retrofit_cordova_screenshots_ios)
- [`init_cordova_screenshots_android`](#init_cordova_screenshots_android)
- [`retrofit_cordova_screenshots_android`](#retrofit_cordova_screenshots_android)

### iOS

#### `init_cordova_screenshots_ios`

This action creates a sample iOS UI Test file in `fastlane/cordova_screenshots/ios`. It takes an optional `scheme_name` parameter, that defines the scheme name that will be used when retrofitting the test file into your Xcode project later.

You can run it either manually with `fastlane run init_cordova_screenshots_ios scheme_name:"another_scheme_name"` (which will create the folder `fastlane/cordova_screenshots/ios/another_scheme_name`) or a lane in your `Fastfile`.

#### `retrofit_cordova_screenshots_ios`

After iOS the test files are created, you can [edit them and write some tests to take screenshots](WRITING_TESTS.md).

Then you retrofit the tests into your Xcode project using this action: It scans the `fastlane/cordova_screenshots/ios` folder for sub folders and retrofits each into the Cordova iOS Xcode project by linking them absolutely. (It then creates a UI Test Target and Scheme based on the name of the subfolder. The files are not copied over to the project, so the Xcode project refers to the files in your `fastlane` folder.)

The action has multiple options:

- `team_id` is automatically set if it is specified in your fastlane `Appfile`.
- `bundle_id` is set automatically if the `package_name` parameter is set in your fastlane `Appfile`.
- `ios_xcode_path` specifies which Xcode project to use. By default it attempts to pick the Xcode project from the `platforms/ios` folder.
- `min_target_ios` defines the minimum iOS version
- `swift_version` the Swift version to target for the ui test build, defaults to '4.2'

All these parameters can be overridden by specifying them in the call to the action.

This action should be executed each time before you use [`capture_ios_screenshots` action](https://docs.fastlane.tools/actions/capture_ios_screenshots/) (or command [`fastlane snapshot`](https://docs.fastlane.tools/actions/snapshot/) on the command line) to create screenshots as it makes sure the test files are linked into the current project.

### Android

#### `init_cordova_screenshots_android`

Copy over test file to `fastlane/cordova_screenshots/android` to be edited by the user.

This action creates a sample Android Test file and saves it to `fastlane/cordova_screenshots/android`. It needs a `package_name` parameter (for use in the created test file), that is read from your `Appfile` if set.

You can run it either manually with `fastlane run init_cordova_screenshots_android` or a lane in your `Fastfile`.

#### `retrofit_cordova_screenshots_android`

After the Android test files are created, you can [edit them and write some tests to take screenshots](WRITING_TESTS.md).

Then you retrofit the tests into your Android Studio project using this action.

**Note:** Right now, this action actually copies (!) the test file from its location into your Android project. A later version of this plugin will also link the Android test files into the project as it does for the iOS tests.

This action should be executed each time before you use [`capture_android_screenshots` action](https://docs.fastlane.tools/actions/capture_android_screenshots/) (or command [`fastlane screengrab`](https://docs.fastlane.tools/actions/screengrab/) on the command line) to create screenshots as it makes sure the test files are <!-- linked into --> present in the current project.

Note that you also have to build the test and debug APK manually before taking screenshots:

```shell
gradlew assembleDebug assembleAndroidTest
```

Or in your screenshot lane:

```ruby
    gradle(
      task: 'assemble',
      build_type: 'Debug',
      project_dir: 'platforms/android'
    )
    gradle(
      task: 'assemble',
      build_type: 'AndroidTest',
      project_dir: 'platforms/android'
    )
```

The action has no parameters.

## Example

Check out the [example `Fastfile`](fastlane/Fastfile) to see how to use this plugin.

## Why it works the way it does

Why do these actions not just copy over a test template to the native project before each run of the screenshots actions? Because then the user couldn't use the Xcode and Android Studio built in test recorders or editors to improve the tests. The tests would be saved only in `platforms` and overwritten or thrown away with the next platform regeneration. By linking the tests files from the `fastlane` folder, this can not happen.

## Acknowledgement

The iOS part of this plugin is fully based on knocknarea's excellent [`fastlane-plugin-ionic_integration`](https://github.com/knocknarea/fastlane-plugin-ionic_integration). I forked and simplified his existing plugin and added the Android implementation.

## Run tests for this plugin

To run both the tests, and code style validation, run

```shell
rake
```

To automatically fix many of the styling issues, use

```shell
rubocop -a
```

## Issues and Feedback

For any other issues and feedback about this plugin, please submit it to this repository.

## Troubleshooting

If you have trouble using plugins, check out the [Plugins Troubleshooting](https://docs.fastlane.tools/plugins/plugins-troubleshooting/) guide.

## Using _fastlane_ Plugins

For more information about how the `fastlane` plugin system works, check out the [Plugins documentation](https://docs.fastlane.tools/plugins/create-plugin/).

## About _fastlane_

_fastlane_ is the easiest way to automate beta deployments and releases for your iOS and Android apps. To learn more, check out [fastlane.tools](https://fastlane.tools).
