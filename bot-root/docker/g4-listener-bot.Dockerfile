# Use a lightweight official Ubuntu as the base image
FROM ubuntu:24.04

# Prevent interactive dialogs during package install
ENV DEBIAN_FRONTEND=noninteractive

# Ensure that PowerShell and any utilities that depend on it have the necessary terminal information
ENV TERM=xterm

# Install prerequisites
RUN apt-get update && \
    apt-get install -y wget apt-transport-https software-properties-common gnupg && \
    rm -rf /var/lib/apt/lists/*

# Download and install Microsoft repository GPG keys
RUN wget -q https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && \
    rm packages-microsoft-prod.deb

# Update package lists and install PowerShell
RUN apt-get update && \
    apt-get install -y powershell && \
    rm -rf /var/lib/apt/lists/*

# Optional default values for the ENV variables
ENV BOT_NAME=
ENV DRIVER_BINARIES=
ENV HUB_URI=
ENV INTERVAL_TIME=
ENV TOKEN=

# Echo the variables in the desired format during build
RUN echo "BOT_NAME: ${BOT_NAME}" && \
    echo "DRIVER_BINARIES: ${DRIVER_BINARIES}" && \
    echo "HUB_URI: ${HUB_URI}" && \
    echo "INTERVAL_TIME: ${INTERVAL_TIME}" && \
    echo "TOKEN: ${TOKEN}"

# Create the /bots directory and ensure it has read/write permissions
RUN mkdir -p /bots && chmod 777 /bots

# Create a directory for your script
WORKDIR /app

# Copy the PowerShell script into the container
COPY Start-ListenerBot.ps1 /app/Start-ListenerBot.ps1

# Make script executable (optional good practice)
RUN chmod +x /app/Start-ListenerBot.ps1

# Pass four parameters to the script:
#   1) The bot volume location (/bot)
#   2) BotName from environment variable
#   3) HubUri from environment variable
#   4) IntervalTime from environment variable
CMD ["pwsh", "-Command", "./Start-ListenerBot.ps1 /bots $env:BOT_NAME $env:DRIVER_BINARIES $env:HUB_URI $env:INTERVAL_TIME $env:TOKEN"]
