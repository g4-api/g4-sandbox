# Tutorial: Using and Running Start-StaticBot.ps1

**Start-StaticBot.ps1** periodically processes an **automation.json** file by reading its contents, updating specific properties, encoding the content in Base64, and sending it via a POST request to a remote endpoint. The script saves responses and error logs in designated directories and then waits for a specified interval before repeating the process. In addition, it supports a Docker mode that launches the script inside a Docker container.

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Script Functionality](#script-functionality)
4. [Parameters Explained](#parameters-explained)
5. [Usage Instructions](#usage-instructions)
   - [Running on Windows](#running-on-windows)
   - [Running on Linux](#running-on-linux)
   - [Running in Docker Mode](#running-in-docker-mode)
6. [Example Commands](#example-commands)
7. [Troubleshooting & Additional Notes](#troubleshooting--additional-notes)

---

## Overview

**Start-StaticBot.ps1** performs the following actions in an infinite loop:

1. **File Discovery:**  
   It locates a bot subfolder (named after the provided **BotName**) within a main directory (**BotVolume**) and searches for an **automation.json** file in its "bot" subdirectory.

2. **File Processing:**  
   The script reads the JSON file, updates properties such as `driverBinaries` within the `driverParameters` object and the `token` within the `authentication` object, then re-serializes and Base64 encodes the JSON content.

3. **Remote Invocation:**  
   It sends the Base64-encoded data via a POST request to a remote endpoint. The endpoint URL is constructed by appending `/api/v4/g4/automation/base64/invoke` to the provided **HubUri**.

4. **Output & Error Logging:**  
   The response from the remote endpoint is saved in an **output** directory with a timestamped filename, and any errors are recorded in an **errors** directory.

5. **Interval Delay:**  
   After each invocation, the script calculates the next run time by adding **IntervalTime** seconds to the current time, displays the scheduled time in ISO 8601 format, and then pauses for the full interval.

6. **Docker Mode:**  
   When the **Docker** switch is specified, the script starts a Docker container with the given parameters and then exits.

---

## Prerequisites

### PowerShell
- **Windows:**  
  - Requires Windows PowerShell 5.1 or later (included by default on Windows 10+).

- **Linux:**  
  - Install [PowerShell (PowerShell Core)](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell) by following the [official installation instructions](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-linux).

### Docker (Optional)
- **Installation:**  
  - To run the script in Docker mode, install Docker on your system.
  - For installation details, see [Docker's official website](https://docs.docker.com/get-docker/).

### File & Directory Setup
- **Folder Structure:**  
  Create a directory (referred to as **BotVolume**) that contains your bot’s folder. For example, if your bot’s name is **demo-bot**, the structure should resemble:
  ```
  BotVolume/
    └── demo-bot/
         ├── bot/
         │    └── automation.json
         ├── output/    (for saving responses)
         └── errors/    (for logging errors)
  ```
- **automation.json:**  
  Ensure that this file exists in the `bot` subdirectory and contains valid JSON.

---

## Script Functionality

**Start-StaticBot.ps1** continuously executes the following steps:

1. **Locate and Validate File:**  
   - Verifies the existence of **automation.json** within the bot's "bot" subdirectory.
   - If the file is missing, the script waits for the next interval and then retries.

2. **Process the File:**  
   - Reads the entire file as raw text.
   - Parses the JSON, updates the `driverBinaries` property in the `driverParameters` object and the `token` property in the `authentication` object.
   - Re-serializes the JSON with sufficient depth and converts it to a Base64-encoded string.

3. **Send Data & Save Response:**  
   - Sends the Base64 string to the remote endpoint using a POST request.
   - Saves the response to the **output** directory with a timestamped filename.
   - Logs any encountered errors into the **errors** directory.

4. **Wait Before Next Invocation:**  
   - Calculates the next scheduled invocation time by adding **IntervalTime** seconds to the current time.
   - Displays the scheduled time in ISO 8601 format.
   - Pauses for the duration of **IntervalTime**.

5. **Loop:**  
   - Repeats the entire process indefinitely until terminated.

---

## Parameters Explained

- **`BotVolume`**  
  The main directory path where your bot’s folder is located.

- **`BotName`**  
  The name of the bot’s folder. This folder should include a "bot" subdirectory containing **automation.json**.

- **`DriverBinaries`**  
  The URL for the driver binaries that will be inserted into the JSON file.

- **`HubUri`**  
  The base URI of the remote service (for example, `http://host.docker.internal:9944`). The script appends `/api/v4/g4/automation/base64/invoke` to this URI.

- **`IntervalTime`**  
  The interval (in seconds) between successive invocations. For instance, use `120` for a 2-minute interval.

- **`Token`**  
  The authentication token required for the bot’s operation. This token is injected into the JSON's `authentication.token` property.

- **`Docker`**  
  A switch that, when specified, runs the script inside a Docker container with the provided parameters and then exits.

---

## Usage Instructions

### Running on Windows

1. **Open PowerShell:**  
   Launch Windows PowerShell (consider running as Administrator if necessary).

2. **Navigate to the Script Directory:**  
   Change the directory to where **Start-StaticBot.ps1** is stored:
   ```powershell
   cd "C:\Path\To\Script\Directory"
   ```

3. **Execute the Script:**  
   Run the script with the required parameters:
   ```powershell
   .\Start-StaticBot.ps1 -BotVolume "E:\Garbage\bot-volume" -BotName "demo-bot" -DriverBinaries "http://host.k8s.internal" -HubUri "http://host.docker.internal:9944" -IntervalTime 120 -Token "your_token"
   ```
   **Note:** The script runs continuously. To stop it, press **Ctrl + C** in the PowerShell window.

4. **(Optional) Running as a Service:**  
   For production environments, consider running the script as a Windows Service or using a scheduler that supports long-running processes.

### Running on Linux

1. **Install PowerShell Core:**  
   Follow the official instructions to install PowerShell on your Linux distribution.

2. **Open a Terminal:**  
   Launch your terminal emulator.

3. **Navigate to the Script Directory:**  
   ```bash
   cd /path/to/script/directory
   ```

4. **Run the Script Using PowerShell:**  
   Execute the script with the necessary parameters:
   ```bash
   pwsh ./Start-StaticBot.ps1 -BotVolume "/path/to/bot-volume" -BotName "demo-bot" -DriverBinaries "http://host.k8s.internal" -HubUri "http://host.docker.internal:9944" -IntervalTime 120 -Token "your_token"
   ```
   The script will continue running until you terminate it (for example, by pressing **Ctrl + C**).

### Running in Docker Mode

1. **Ensure Docker is Installed and Running:**  
   Confirm that Docker is set up on your system.

2. **Execute with the Docker Switch:**  
   Run the script with the **-Docker** parameter to launch it inside a Docker container:
   - **Windows:**
     ```powershell
     .\Start-StaticBot.ps1 -BotVolume "E:\Garbage\bot-volume" -BotName "demo-bot" -DriverBinaries "http://host.k8s.internal" -HubUri "http://host.docker.internal:9944" -IntervalTime 120 -Token "your_token" -Docker
     ```
   - **Linux:**
     ```bash
     pwsh ./Start-StaticBot.ps1 -BotVolume "/path/to/bot-volume" -BotName "demo-bot" -DriverBinaries "http://host.k8s.internal" -HubUri "http://host.docker.internal:9944" -IntervalTime 120 -Token "your_token" -Docker
     ```
   In Docker mode, the script will launch a Docker container (for example, using an image like **g4-static-bot:latest**) with the supplied environment variables. Once the container is started, the script exits.

---

## Example Commands

### Windows (Direct Run)
```powershell
.\Start-StaticBot.ps1 -BotVolume "E:\Garbage\bot-volume" -BotName "demo-bot" -DriverBinaries "http://host.k8s.internal" -HubUri "http://host.docker.internal:9944" -IntervalTime 120 -Token "your_token"
```

### Linux (Direct Run)
```bash
pwsh ./Start-StaticBot.ps1 -BotVolume "/path/to/bot-volume" -BotName "demo-bot" -DriverBinaries "http://host.k8s.internal" -HubUri "http://host.docker.internal:9944" -IntervalTime 120 -Token "your_token"
```

### Docker Mode (Windows & Linux)
```bash
pwsh ./Start-StaticBot.ps1 -BotVolume "/path/to/bot-volume" -BotName "demo-bot" -DriverBinaries "http://host.k8s.internal" -HubUri "http://host.docker.internal:9944" -IntervalTime 120 -Token "your_token" -Docker
```

---

## Troubleshooting & Additional Notes

- **File Not Found:**  
  If **automation.json** is not found in the specified bot subdirectory, the script will wait for the next interval and then retry. Verify that the file exists and contains valid JSON.

- **Permissions:**  
  Ensure that the user account running the script has appropriate read/write permissions for **BotVolume** and its subdirectories (including **output** and **errors**).

- **Network Issues:**  
  Check that the remote service at **HubUri** is reachable and correctly configured to accept POST requests.

- **Docker Issues:**  
  - Confirm Docker is installed and running.
  - Ensure you have permissions to run Docker commands.
  - Check Docker logs if the container fails to start.

- **Script Termination:**  
  Since the script runs indefinitely, you must manually terminate it (for example, by pressing **Ctrl + C** in the terminal).