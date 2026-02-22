# g4-sandboxBelow is a \*\*production-ready GitHub README\*\* tailored to your sandbox builder.

# It does \*\*not break down the script internals\*\*, includes \*\*Quick Start\*\*, and links to official PowerShell installation pages as requested.

# 

# ---

# 

# \# 🚀 G4 Sandbox Builder

# 

# A fully portable sandbox builder for the \*\*G4™ automation ecosystem\*\*.

# 

# The script assembles a deterministic, offline-ready runtime bundle that includes required runtimes, browsers, drivers, tools, and configuration assets — suitable for local execution, CI/CD pipelines, containers, and air-gapped environments.

# 

# ---

# 

# \## 📚 Table of Contents

# 

# \* \[Overview](#-overview)

# \* \[Features](#-features)

# \* \[Requirements](#-requirements)

# \* \[Quick Start](#-quick-start)

# \* \[PowerShell Installation (macOS/Linux)](#-powershell-installation-macoslinux)

# \* \[Usage](#-usage)

# \* \[Output](#-output)

# \* \[Compatibility Notes](#-compatibility-notes)

# \* \[License](#-license)

# 

# ---

# 

# \## 🔍 Overview

# 

# \*\*G4 Sandbox Builder\*\* creates a portable runtime environment for G4 automation workloads.

# 

# It is designed for:

# 

# \* 🧪 Local development

# \* 🤖 CI/CD artifact generation

# \* 📦 Offline / air-gapped deployments

# \* 🐳 Container volume mounting

# \* 🧱 Deterministic environment builds

# 

# The produced sandbox is self-contained and ready to run.

# 

# ---

# 

# \## ✨ Features

# 

# \* Fully portable sandbox output

# \* Deterministic builds

# \* Cross-platform support

# \* Automatic dependency retrieval

# \* Offline-friendly packaging

# \* CI/CD ready

# \* Clean rebuild support

# \* Chrome for Testing integration

# \* G4 tools staging

# 

# ---

# 

# \## 📦 Requirements

# 

# \### Windows

# 

# \* PowerShell 5.x \*\*or\*\* PowerShell Core

# \* Internet access (for initial build)

# \* Sufficient disk space

# 

# \### Linux / macOS

# 

# \* \*\*PowerShell Core (x64 only)\*\*

# \* `tar` available on PATH

# \* Internet access

# \* x64 architecture

# 

# ⚠️ \*\*ARM is currently not supported\*\*

# 

# ---

# 

# \## 🚀 Quick Start

# 

# \### 1️⃣ Clone the repository

# 

# ```bash

# git clone https://github.com/g4-api/g4-sandbox.git

# cd g4-sandbox

# ```

# 

# ---

# 

# \### 2️⃣ Run the sandbox builder

# 

# \#### Windows (PowerShell)

# 

# ```powershell

# pwsh ./Publish-G4Sandbox.ps1 `

# &nbsp; -BotVolume "C:\\g4-bot" `

# &nbsp; -OperatingSystem Windows `

# &nbsp; -OutputDirectory "C:\\G4"

# ```

# 

# ---

# 

# \#### Linux / macOS (PowerShell Core)

# 

# ```bash

# pwsh ./Publish-G4Sandbox.ps1 \\

# &nbsp; -BotVolume "/opt/g4-bot" \\

# &nbsp; -OperatingSystem Linux \\

# &nbsp; -OutputDirectory "/opt/g4"

# ```

# 

# ---

# 

# \## 🧰 PowerShell Installation (macOS/Linux)

# 

# PowerShell Core \*\*must be installed manually\*\* on non-Windows systems.

# 

# \### 🔗 Official Microsoft installation guide

# 

# 👉 \[https://learn.microsoft.com/powershell/scripting/install/installing-powershell](https://learn.microsoft.com/powershell/scripting/install/installing-powershell)

# 

# ---

# 

# \### Quick install examples

# 

# \#### Ubuntu (x64)

# 

# ```bash

# sudo apt-get update

# sudo apt-get install -y powershell

# ```

# 

# ---

# 

# \#### macOS (Homebrew, x64)

# 

# ```bash

# brew install --cask powershell

# ```

# 

# ---

# 

# \### Verify installation

# 

# ```bash

# pwsh --version

# ```

# 

# ---

# 

# \## ▶️ Usage

# 

# Run the script with your desired parameters:

# 

# ```powershell

# pwsh ./Publish-G4Sandbox.ps1 \[parameters]

# ```

# 

# \### Common parameters

# 

# | Parameter         | Description                      |

# | ----------------- | -------------------------------- |

# | `BotVolume`       | Root working volume for the bot  |

# | `ChormeVersion`   | Optional Chrome version selector |

# | `DotnetVersion`   | .NET major version (default: 10) |

# | `HubUri`          | G4 Hub endpoint                  |

# | `OperatingSystem` | Target OS (Windows/Linux/MacOs)  |

# | `OutputDirectory` | Final sandbox location           |

# | `Clean`           | Force clean rebuild              |

# 

# ---

# 

# \## 📁 Output

# 

# The script produces a \*\*fully portable G4 sandbox layout\*\* ready for:

# 

# \* Local execution

# \* CI artifacts

# \* Container mounting

# \* Offline environments

# 

# The output directory will contain all required runtime assets.

# 

# ---

# 

# \## ⚠️ Compatibility Notes

# 

# \* Linux/macOS support is \*\*x64 only\*\*

# \* ARM is not currently supported

# \* Requires outbound network access during build

# \* `tar` must be available for certain extractions

# \* Helper functions must be loaded in scope

# 

# ---

# 

# \## 📜 License

# 

# See repository license for details.

