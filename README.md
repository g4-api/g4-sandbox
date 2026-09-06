# G4™ Sandbox Builder

A fully portable sandbox builder for the **G4™ automation ecosystem**.

## 📚 Table of Contents

* [One-line installation](#one-line-installation)
* [Overview](#-overview)
* [Features](#-features)
* [Requirements](#-requirements)
* [Quick Start](#-quick-start)
* [PowerShell Installation (macOS/Linux)](#-powershell-installation-macoslinux)
* [Usage](#usage)
* [LiteLLM Subsystem](#-litellm-subsystem)
* [Output](#-output)
* [Compatibility Notes](#compatibility-notes)
* [License](#-license)

---

### One-line installation

#### Windows

```powershell
irm https://raw.githubusercontent.com/g4-api/g4-sandbox/main/install-g4-sandbox.ps1 | iex
````

#### Linux

```bash
curl -fsSL https://raw.githubusercontent.com/g4-api/g4-sandbox/main/install-g4-sandbox.sh | bash
```

The installer bootstraps a portable PowerShell runtime, pulls the repository, runs the sandbox publish script, and cleans up temporary bootstrap files when complete.

The script assembles a deterministic, offline-ready runtime bundle that includes required runtimes, browsers, drivers, tools, and configuration assets — suitable for local execution, CI/CD pipelines, containers, and air-gapped environments.

---

## 🔍 Overview

**G4 Sandbox Builder** creates a portable runtime environment for G4 automation workloads.

It is designed for:

* 🧪 Local development
* 🤖 CI/CD artifact generation
* 📦 Offline / air-gapped deployments
* 🐳 Container volume mounting
* 🧱 Deterministic environment builds

The produced sandbox is self-contained and ready to run.

---

## ✨ Features

* Fully portable sandbox output
* Deterministic builds
* Cross-platform support
* Automatic dependency retrieval
* Offline-friendly packaging
* CI/CD ready
* Clean rebuild support
* Chrome for Testing integration
* G4 tools staging
* Portable LiteLLM proxy subsystem

---

## 📦 Requirements

### Windows

* PowerShell 5.x **or** PowerShell Core
* Internet access (for initial build)
* Sufficient disk space

### Linux / macOS

* **PowerShell Core (x64 only)**
* `tar` available on PATH
* Internet access
* x64 architecture

⚠️ **ARM is currently not supported**

---

## 🚀 Quick Start

### 1️⃣ Clone the repository

```bash
git clone https://github.com/g4-api/g4-sandbox.git
cd g4-sandbox
```

---

### 2️⃣ Run the sandbox builder

#### Windows (PowerShell)

```powershell
pwsh ./Publish-G4Sandbox.ps1 `
  -BotVolume "C:\g4-bot" `
  -OperatingSystem Windows `
  -OutputDirectory "C:\G4"
```

---

#### Linux / macOS (PowerShell Core)

```bash
pwsh ./Publish-G4Sandbox.ps1 \
  -BotVolume "/opt/g4-bot" \
  -OperatingSystem Linux \
  -OutputDirectory "/opt/g4"
```

---

## 🧰 PowerShell Installation (macOS/Linux)

PowerShell Core **must be installed manually** on non-Windows systems when you are running the builder directly instead of using the one-line bootstrap installer.

### 🔗 Official Microsoft installation guide

👉 [https://learn.microsoft.com/powershell/scripting/install/installing-powershell](https://learn.microsoft.com/powershell/scripting/install/installing-powershell)

---

### Quick install examples

#### Ubuntu (x64)

```bash
sudo apt-get update
sudo apt-get install -y powershell
```

---

#### macOS (Homebrew, x64)

```bash
brew install --cask powershell
```

---

### Verify installation

```bash
pwsh --version
```

---

## Usage

Run the script with your desired parameters:

```powershell
pwsh ./Publish-G4Sandbox.ps1 [parameters]
```

### Common parameters

| Parameter         | Description                      |
| ----------------- | -------------------------------- |
| `BotVolume`       | Root working volume for the bot  |
| `ChormeVersion`   | Optional Chrome version selector |
| `DotnetVersion`   | .NET major version (default: 10) |
| `HubUri`          | G4 Hub endpoint                  |
| `OperatingSystem` | Target OS (Windows/Linux/MacOs)  |
| `OutputDirectory` | Final sandbox location           |
| `Clean`           | Force clean rebuild              |
| `SkipLiteLLM`     | Skip the LiteLLM subsystem build |

---

## 🧠 LiteLLM Subsystem

The builder deploys a **fully portable LiteLLM proxy stack** into the sandbox, so the published bundle ships with LiteLLM already installed. Nothing is installed globally and no machine, user, registry, or profile state is changed.

### How it is built

The deployment scripts live under `src/scripts-subsystems/` and are **build-time tooling only** — they are not copied into the published sandbox. `Publish-G4Sandbox.ps1` selects one based on the `OperatingSystem` parameter:

| Target OS | Deployment script          |
| --------- | -------------------------- |
| `Windows` | `deploy-litellm-win.ps1`   |
| `Linux`   | `deploy-litellm-linux.ps1` |
| `MacOs`   | Not supported — skipped    |

The subsystem is deployed after all other downloads and staging steps, immediately before the stage is copied into the final sandbox directory. The portable PostgreSQL server is stopped once the deployment completes, so the bundle can safely be moved or archived.

If the deployment fails (for example, due to a network error), a warning is emitted and the publish continues **without** the LiteLLM subsystem. Use `-SkipLiteLLM` to skip the step entirely.

### Layout and usage

The box is created at the sandbox root as `litellm/`, and launchers are placed beside it in the sandbox root:

```text
<sandbox>/
  litellm/                  the portable LiteLLM box (runtimes, data, state, cache)
    start-litellm.cmd|sh    generated mirror — starts PostgreSQL + the LiteLLM proxy
    stop-litellm.cmd|sh     generated mirror — stops the portable PostgreSQL server
  start-litellm.cmd         Windows launcher (forwards to litellm/start-litellm.cmd)
  start-litellm.sh          Linux launcher   (forwards to litellm/start-litellm.sh)
  stop-litellm.cmd          Windows launcher (forwards to litellm/stop-litellm.cmd)
  stop-litellm.sh           Linux launcher   (forwards to litellm/stop-litellm.sh)
```

The `litellm/start-litellm.*` and `litellm/stop-litellm.*` mirror scripts are self-contained: they are generated by the deployment script at build time from standalone runtime logic and do **not** depend on `deploy-litellm-*.ps1` being present in the shipped sandbox (it isn't). Only Start/Stop are supported at runtime — Update, Rollback, Verify, and Status require the original build-time deployment tooling and are not available on a published sandbox.

Start/stop the proxy from the sandbox root:

```powershell
# Windows
.\start-litellm.cmd
.\stop-litellm.cmd
```

```bash
# Linux
./start-litellm.sh
./stop-litellm.sh
```

### Defaults

| Setting             | Default                     |
| ------------------- | --------------------------- |
| LiteLLM endpoint    | `127.0.0.1:4000`            |
| LiteLLM master key  | `sk-1234`                   |
| PostgreSQL endpoint | `127.0.0.1:54321`           |
| Upstream API base   | `http://127.0.0.1:8000/v1`  |
| Upstream model      | `Qwen/Qwen3-0.6B`           |

The proxy configuration is created once at `litellm/state/config.yaml` and is never overwritten afterwards, so hand-edited `model_list` entries survive. Models can also be managed from the admin UI, because `STORE_MODEL_IN_DB` is enabled by default.

> **Note:** The upstream inference server is **not** deployed. The default configuration expects an OpenAI-compatible endpoint to be reachable at `http://127.0.0.1:8000/v1`.

---

## 📁 Output

The script produces a **fully portable G4 sandbox layout** ready for:

* Local execution
* CI artifacts
* Container mounting
* Offline environments

The output directory will contain all required runtime assets.

---

## Compatibility Notes

* Linux/macOS support is **x64 only**
* ARM is not currently supported
* Requires outbound network access during build
* `tar` must be available for certain extractions
* Helper functions must be loaded in scope
* The LiteLLM subsystem is built for `Windows` and `Linux` targets only; `MacOs` targets skip it
* Building the LiteLLM subsystem executes the downloaded toolchain, so the build host must match the target platform (use `-SkipLiteLLM` for cross-platform builds)

---

## 📜 License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for details.
