# Install and run Maestro on Windows

Maestro runs UI flows against apps installed on a simulator or device.
**Loopdhands is only the sample project in this repository.** You can test
another app with its own Android test APK and flows; app source does not need
to be in the same repository.

Windows setup in this guide is for Android. Xcode and the iOS Simulator are
macOS-only.

## Requirements

- Windows 10/11 and PowerShell.
- Java 17 or newer.
- An Android test APK for your app.
- Test credentials only if your flows require them.
- GitHub access to this private repository if you want to run the included
  sample flows.

The Loopdhands login sample uses MailSlurp for OTP. Its API key and account
credentials are only needed for flows that use MailSlurp.

## 1. Install prerequisites

Install:

- [Git for Windows](https://git-scm.com/download/win)
- [Java 17](https://adoptium.net/temurin/releases/?version=17)
- [Python 3](https://www.python.org/downloads/windows/) (only needed for the
  Loopdhands sample runner)
- [Android Studio](https://developer.android.com/studio)

During Java setup, note the JDK folder. Open **Windows Search > Edit the
system environment variables > Environment Variables**. Set the user
variable `JAVA_HOME` to the JDK folder (not its `bin` folder), and add
`%JAVA_HOME%\bin` to the user `Path`.

In Android Studio's **SDK Manager**, install Android SDK, Android SDK
Platform-Tools, and Android Emulator. The default SDK location is:

```text
%LOCALAPPDATA%\Android\Sdk
```

Add this folder to your user `Path` if `adb` is not recognized:

```text
%LOCALAPPDATA%\Android\Sdk\platform-tools
```

Open a new PowerShell window and verify:

```powershell
java -version
adb version
```

## 2. Install Maestro CLI

Download the pinned CLI release:

```text
https://github.com/mobile-dev-inc/Maestro/releases/download/cli-2.12.0/maestro.zip
```

In PowerShell, extract it to a stable location:

```powershell
New-Item -ItemType Directory -Force C:\Tools\maestro | Out-Null
Expand-Archive "$HOME\Downloads\maestro.zip" C:\Tools\maestro -Force
```

Find the extracted `bin` folder containing `maestro.bat`. Add that folder to
your user `Path` using **Windows Search > Edit the system environment
variables > Environment Variables**. Reopen PowerShell and verify:

```powershell
maestro --version
```

It should report `2.12.0`. For the latest instructions, see the
[official Maestro CLI installation guide](https://docs.maestro.dev/maestro-cli/how-to-install-maestro-cli).

## 3. Prepare an Android device

In Android Studio's **Device Manager**, create and start an emulator with a
system image compatible with your app. Check it is available:

```powershell
adb devices -l
```

The emulator should appear with state `device`. You can also use a physical
Android device with USB debugging enabled. Install your APK, replacing the
example path:

```powershell
adb install -r "$HOME\Downloads\MyApp-test.apk"
```

## 4. Get flows and run them

To use the sample flows in this repository, clone it in PowerShell:

```powershell
git clone https://github.com/ictech-projects/maestro.git
cd maestro
```

The repo is private; ask the project owner for access if needed. For another
app, obtain or write flows for that app; its flows can be in a separate
repository.

Set the flow's `appId` to your app's Android package ID and update its
selectors and steps for the app's screens. For example:

```yaml
appId: com.example.myapp
---
- launchApp:
    clearState: true
- assertVisible: "Welcome"
```

With the emulator/device running and the app installed, run a flow or folder:

```powershell
maestro test flows/smoke.yaml
maestro test OtherProject/flows
```

The repo's `run.sh` is a Bash convenience wrapper for its `loopdhands` and
`still-aware` sample projects. You can run it from Git Bash; otherwise, use
the direct `maestro test` commands above. For UI selectors, use
`maestro hierarchy` to inspect the running app.

## Loopdhands sample only

The sample login flow requires test account values and a MailSlurp API key.
To run its shell wrapper, use Git Bash from the repository root:

```sh
cp Loopdhands/.env.example Loopdhands/.env
```

Fill in the test values supplied by the Loopdhands team. `.env` is ignored by
Git; do not commit or share it.

Alternatively, run a sample flow directly in PowerShell and pass the required
environment values:

```powershell
$env:EMAIL = "your-test-email"
$env:PASSWORD = "your-test-password"
$env:MAILSLURP_API_KEY = "your-mailslurp-api-key"
$env:MAILSLURP_INBOX_ID = ""
maestro test -e "EMAIL=$env:EMAIL" -e "PASSWORD=$env:PASSWORD" `
  -e "MAILSLURP_API_KEY=$env:MAILSLURP_API_KEY" `
  -e "MAILSLURP_INBOX_ID=$env:MAILSLURP_INBOX_ID" `
  Loopdhands/flows/login.yaml
```

These variables last only for the current PowerShell session. MailSlurp and
the Loopdhands credentials are not required for unrelated apps or flows.

**The sample food-request flow submits data** to the backend configured in
the installed Loopdhands app. Confirm it points to test/staging before
running; repeated runs create additional requests.

## Troubleshooting

- **No device:** start an emulator or connect a USB-debugging device; then
  check with `adb devices -l`.
- **App does not launch:** confirm it is installed and `appId` matches its
  package ID.
- **Selector fails:** inspect the screen and `maestro hierarchy`; adapt the
  flow for the app.
- **Loopdhands OTP times out:** verify the test account, MailSlurp API key,
  inbox ID, email delivery, and network access.
- **`maestro` or `adb` is not found:** reopen PowerShell and confirm the
  correct `bin` or Android platform-tools folder is in `Path`.
