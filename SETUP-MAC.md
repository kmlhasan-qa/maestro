# Install and run Maestro on macOS

Maestro runs UI flows against apps installed on a simulator or device.
**Loopdhands is only the sample project in this repository.** You can test
another app with its own test build and flows; app source does not need to be
in the same repository.

## Requirements

- Java 17 or newer.
- The test build for your app: Android APK, or iOS project/workspace or
  simulator-compatible `.app`.
- Test credentials only if your flows require them.
- GitHub access to this private repository if you want to run the included
  sample flows.

The Loopdhands login sample uses MailSlurp for OTP. Its API key and account
credentials are only needed for flows that use MailSlurp.

## 1. Install prerequisites

Install Apple's command-line tools if Git is not available:

```sh
xcode-select --install
```

Install Homebrew from [brew.sh](https://brew.sh/), then install Java 17 and
Python 3. Python is only needed by the Loopdhands sample runner:

```sh
brew install --cask temurin@17
brew install python
```

For Android, install Android Studio and, in **SDK Manager**, install Android
SDK, Android SDK Platform-Tools, and Android Emulator. If `adb` is not found,
add the default SDK tools to zsh:

```sh
cat >> ~/.zshrc <<'EOF'
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
EOF
source ~/.zshrc
```

## 2. Install Maestro CLI

Install the version used when this repository's sample flows were last
verified:

```sh
curl -Ls "https://get.maestro.mobile.dev" | MAESTRO_VERSION=2.12.0 bash
```

Open a new Terminal window and verify:

```sh
java -version
maestro --version
```

Java should report 17 or newer; Maestro should report `2.12.0`. See the
[official Maestro CLI installation guide](https://docs.maestro.dev/maestro-cli/how-to-install-maestro-cli)
for other versions.

## 3. Prepare a device

### Android

In Android Studio's **Device Manager**, create and start an emulator with a
system image compatible with your app. Android 13 (API 33) is a reasonable
starting point. Check that it is available:

```sh
adb devices -l
```

Install your APK, replacing the example path:

```sh
adb install -r "$HOME/Downloads/MyApp-test.apk"
```

### iOS with Xcode

Install Xcode from the
[Mac App Store](https://apps.apple.com/us/app/xcode/id497799835?mt=12), open
it, and complete first-run setup. In **Xcode > Settings > Locations**, select
the installed Xcode version under **Command Line Tools**. Run:

```sh
xcodebuild -runFirstLaunch
```

If prompted to accept the license, follow the prompt or run:

```sh
sudo xcodebuild -license accept
```

In **Xcode > Settings > Platforms**, install an iOS Simulator runtime. Open
**Xcode > Open Developer Tool > Simulator** and start a simulator. List
available simulators:

```sh
xcrun simctl list devices available
```

Open your app's `.xcworkspace` (preferred when provided) or `.xcodeproj` in
Xcode, select its scheme and the booted simulator, then press **Run**.
Alternatively install a simulator-compatible `.app` build:

```sh
xcrun simctl install booted "$HOME/Downloads/MyApp.app"
```

## 4. Get flows and run them

To use the sample flows in this repository:

```sh
git clone https://github.com/ictech-projects/maestro.git
cd maestro
```

The repo is private; ask the project owner for access if needed. For another
app, obtain or write flows for that app; its flows can be in a separate
repository.

Set the flow's `appId` to the installed app's Android package ID or iOS bundle
identifier. These can differ across platforms. Update selectors and steps to
match the app's screens. For example:

```yaml
appId: com.example.myapp
---
- launchApp:
    clearState: true
- assertVisible: "Welcome"
```

With the simulator/device running and app installed, run a flow or folder:

```sh
maestro test flows/smoke.yaml
maestro test OtherProject/flows
```

The repo's `./run.sh` can run any project folder that provides a `run.sh`
runner, including `loopdhands` and `still-aware`. For another app without a
project runner, use `maestro test` directly. Use `maestro hierarchy` to inspect
UI selectors when a flow does not match.

## Loopdhands sample only

The sample login flow requires test account values and a MailSlurp API key.
From the repository root, create the local environment file:

```sh
cp Loopdhands/.env.example Loopdhands/.env
chmod 600 Loopdhands/.env
```

Fill in values supplied by the Loopdhands test environment. `.env` is ignored
by Git; do not commit or share it. These values are not needed for unrelated
apps or flows.

Run the sample login or food-request flow:

```sh
./run.sh loopdhands flows/login.yaml
./run.sh loopdhands flows/food_request.yaml
```

The food-request flow submits data to the backend configured in the installed
app. Confirm it points to test/staging before running; repeated runs create
additional requests.

## Troubleshooting

- **No device:** start an emulator/simulator. Check Android with
  `adb devices -l`, or iOS with `xcrun simctl list devices available`.
- **App does not launch:** confirm it is installed and `appId` matches its
  package ID or bundle identifier.
- **Selector fails:** inspect the screen and `maestro hierarchy`; adapt the
  flow for the app and platform.
- **Loopdhands OTP times out:** verify the test account, MailSlurp API key,
  inbox ID, email delivery, and network access.
