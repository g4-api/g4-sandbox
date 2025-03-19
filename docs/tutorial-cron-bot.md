# Tutorial: Using and Running Start-CronBot.ps1

This PowerShell script processes an `automation.json` file by encoding its content in Base64, sending it to a remote endpoint, and saving the response and any errors. It supports running directly on your system as well as inside a Docker container. The script is designed to run once and does not loop indefinitely.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Script Overview](#script-overview)
3. [Usage Instructions](#usage-instructions)
   - [Parameters Explained](#parameters-explained)
4. [Running the Script](#running-the-script)
   - [Windows: Using Task Scheduler](#windows-using-task-scheduler)
   - [Linux](#running-on-linux)
   - [Docker Mode](#using-docker-mode)
5. [Example Commands](#example-commands)
6. [Troubleshooting & Additional Notes](#troubleshooting--additional-notes)

---

## Prerequisites

### PowerShell
- **Windows:**  
  - Requires Windows PowerShell 5.1 or later (included with Windows 10+).
  
- **Linux:**  
  - Install [PowerShell (PowerShell Core)](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell) following the [official installation instructions](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-linux).

### Docker (Optional)
- **Installation:**  
  - If you plan to run the script in Docker mode, install Docker on your system.  
  - Visit [Docker's official website](https://docs.docker.com/get-docker/) for installation details.

### File Structure & Environment Setup
- **Folder Structure:**  
  Create a directory structure similar to the following:
  ```
  BotVolume/
    └── demo-bot/
         ├── bot/
         │    └── automation.json
         ├── output/    (for saving responses)
         └── errors/    (for logging errors)
  ```
- **automation.json:**  
  Ensure that this file is present in the `bot` subdirectory and is valid JSON.

---

## Script Overview

**Start-CronBot.ps1** performs the following actions:
1. **Locate Bot Folder:**  
   Searches for a subfolder in the specified **BotVolume** that matches **BotName**.
2. **Process automation.json:**  
   Reads the file from the `bot` subdirectory, parses it, updates the `driverBinaries` and `authentication.token` properties, re-serializes it to JSON, and encodes it in Base64.
3. **Send to Remote Endpoint:**  
   Sends the Base64 encoded JSON via a POST request to the remote endpoint (constructed from **HubUri**).
4. **Save Output & Log Errors:**  
   Saves the remote service’s response in an output directory with a timestamp and logs any errors in an errors directory.
5. **Docker Mode:**  
   If the **Docker** switch is specified, the script starts a Docker container using the provided parameters and then exits.

**Note on Scheduling:**  
- **Windows:** The **CronSchedules** parameter is **not used**. Instead, schedule the script using Windows Task Scheduler.
- **Linux/Docker:** The **CronSchedules** parameter is available to define cron expressions for scheduling automation jobs. For help in creating cron expressions, consider using [Crontab Guru](https://crontab.guru), an excellent online cron expression builder.

---

## Usage Instructions

### Parameters Explained

- **`BotVolume`**  
  The main directory path where your bot’s subfolder is located.

- **`BotName`**  
  The name of the bot folder. This folder must contain a `bot` subdirectory that holds the `automation.json` file.

- **`CronSchedules`**  
  A comma-separated string of cron expressions for scheduling automation jobs.  
  - **Windows:** This parameter is not applicable. Use Windows Task Scheduler to run the script on your desired schedule.
  - **Linux/Docker:** The parameter can be used to pass scheduling information if your setup supports cron-based scheduling. For help constructing cron expressions, visit [Crontab Guru](https://crontab.guru).

- **`DriverBinaries`**  
  The URL for the driver binaries, which will be injected into the `automation.json` file.

- **`HubUri`**  
  The base URI for the remote service (e.g., `http://host.docker.internal:9944`).

- **`Token`**  
  The authentication token required for the bot’s operation. This token is injected into the JSON’s `authentication.token` property and is also passed to Docker mode.

- **`Docker`** (switch)  
  When set, the script runs in Docker container mode. The container is started with the specified parameters and the script exits after launching the container.

---

## Running the Script

### Windows: Using Task Scheduler

On Windows, since cron expressions are not natively supported, you must schedule the **Start-CronBot.ps1** script using Windows Task Scheduler:

1. **Open Task Scheduler:**  
   - Press `Win + R`, type `taskschd.msc`, and press Enter.
   
2. **Create a New Task:**  
   - In the Task Scheduler, click **Action > Create Task...**
   
3. **General Tab:**  
   - **Name:** Enter a descriptive name, e.g., "Start-CronBot Task".
   - **Security Options:** Choose "Run whether user is logged on or not" if needed.
   
4. **Triggers Tab:**  
   - Click **New...** to add a trigger.
   - Set the schedule according to your needs (daily, weekly, etc.).  
   - **Note:** The **CronSchedules** parameter is not used on Windows.
   
5. **Actions Tab:**  
   - Click **New...**
   - **Action:** Choose "Start a program".
   - **Program/script:**  
     Enter the path to `powershell.exe` (e.g., `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`).
   - **Add arguments (optional):**  
     Use the following format:
     ```plaintext
     -ExecutionPolicy Bypass -File "C:\Path\To\Start-CronBot.ps1" -BotVolume "E:\Garbage\bot-volume" -BotName "demo-bot" -DriverBinaries "http://host.docker.internal:4444/wd/hub" -HubUri "http://host.docker.internal:9944" -Token "your_auth_token"
     ```
   - **Start in (optional):**  
     Specify the directory where the script is located.
   
6. **Conditions and Settings Tabs:**  
   - Adjust any additional settings as necessary, such as network availability or power conditions.
   
7. **Save and Test:**  
   - Save the task and test it manually from Task Scheduler to ensure it works as expected.

### Running on Linux

1. **Install PowerShell Core:**  
   Follow the official instructions to install PowerShell on your Linux distribution.
   
2. **Open a Terminal:**  
   Launch your terminal application.
   
3. **Navigate to Script Directory:**  
   ```bash
   cd /path/to/script/directory
   ```
   
4. **Run the Script Using PowerShell:**  
   Since Linux supports cron, you can use the **CronSchedules** parameter:
   ```bash
   pwsh ./Start-CronBot.ps1 -BotVolume "/path/to/bot-volume" -BotName "demo-bot" -CronSchedules "*/5 * * * *,30 8 * * *,0 18 * * *" -DriverBinaries "http://host.docker.internal:4444/wd/hub" -HubUri "http://host.docker.internal:9944" -Token "your_auth_token"
   ```

### Using Docker Mode

1. **Ensure Docker Is Running:**  
   Confirm that Docker is installed and the daemon is running on your system.
   
2. **Run the Script with the Docker Switch:**  
   When you include the `-Docker` switch, the script launches a Docker container with the provided parameters.
   
3. **Command Examples:**  
   - **Windows:**
     ```powershell
     .\Start-CronBot.ps1 -BotVolume "E:\Garbage\bot-volume" -BotName "demo-bot" -CronSchedules "*/5 * * * *,30 8 * * *,0 18 * * *" -DriverBinaries "http://host.docker.internal:4444/wd/hub" -HubUri "http://host.docker.internal:9944" -Token "your_auth_token" -Docker
     ```
   - **Linux:**
     ```bash
     pwsh ./Start-CronBot.ps1 -BotVolume "/path/to/bot-volume" -BotName "demo-bot" -CronSchedules "*/5 * * * *,30 8 * * *,0 18 * * *" -DriverBinaries "http://host.docker.internal:4444/wd/hub" -HubUri "http://host.docker.internal:9944" -Token "your_auth_token" -Docker
     ```
   In Docker mode, the **CronSchedules** parameter is relevant if your Docker container or orchestrator supports cron-based scheduling.

---

## Example Commands

### Windows (Using Task Scheduler)

Create a scheduled task that runs the following command with PowerShell:
```plaintext
powershell.exe -ExecutionPolicy Bypass -File "C:\Path\To\Start-CronBot.ps1" -BotVolume "E:\Garbage\bot-volume" -BotName "demo-bot" -DriverBinaries "http://host.docker.internal:4444/wd/hub" -HubUri "http://host.docker.internal:9944" -Token "your_auth_token"
```
*(Note: **CronSchedules** is omitted on Windows.)*

### Linux (Direct Run)
```bash
pwsh ./Start-CronBot.ps1 -BotVolume "/path/to/bot-volume" -BotName "demo-bot" -CronSchedules "*/5 * * * *,30 8 * * *,0 18 * * *" -DriverBinaries "http://host.docker.internal:4444/wd/hub" -HubUri "http://host.docker.internal:9944" -Token "your_auth_token"
```

### Docker Mode (Works on Windows and Linux)
```bash
pwsh ./Start-CronBot.ps1 -BotVolume "/path/to/bot-volume" -BotName "demo-bot" -CronSchedules "*/5 * * * *,30 8 * * *,0 18 * * *" -DriverBinaries "http://host.docker.internal:4444/wd/hub" -HubUri "http://host.docker.internal:9944" -Token "your_auth_token" -Docker
```

---

## Troubleshooting & Additional Notes

- **Missing or Invalid automation.json:**  
  Ensure that the file exists in the `bot` subdirectory and that it contains valid JSON.

- **File Permissions:**  
  Verify you have read/write permissions for the BotVolume, especially for the `output` and `errors` directories.

- **Docker Issues:**  
  - Confirm Docker is installed and running.
  - Ensure that your user account has the necessary privileges to execute Docker commands.
  
- **Endpoint Accessibility:**  
  Check that the remote service at **HubUri** is accessible and configured to handle POST requests.

- **Windows Task Scheduler:**  
  If using Task Scheduler, test your task manually to confirm that the script runs as expected. Check the Task Scheduler logs for errors.

- **Cron Expression Building:**  
  For Linux or Docker setups using cron expressions, use a tool like [Crontab Guru](https://crontab.guru) to help build and validate your cron schedules.