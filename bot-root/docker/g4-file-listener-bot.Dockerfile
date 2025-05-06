# Use a lightweight official Ubuntu as the base image
FROM ubuntu:24.04

# Expose the internal port which will be used by the listener
EXPOSE 9213

# Prevent interactive dialogs during package install
ENV DEBIAN_FRONTEND=noninteractive

# Ensure that PowerShell and any utilities that depend on it have the necessary terminal information
ENV TERM=xterm

# Install prerequisites
RUN apt-get update && \
    apt-get install -y wget apt-transport-https software-properties-common gnupgc curl && \
    rm -rf /var/lib/apt/lists/*

# Download and install Microsoft repository GPG keys
RUN wget -q https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && \
    rm packages-microsoft-prod.deb

# Update package lists and install PowerShell
RUN apt-get update && \
    apt-get install -y powershell && \
    rm -rf /var/lib/apt/lists/*

# Echo the variables in the desired format during build
RUN echo "BOT_ID: ${BOT_ID}" && \
    echo "BOT_NAME: ${BOT_NAME}" && \
    echo "CALLBACK_INGRESS: ${CALLBACK_INGRESS}" && \
    echo "CALLBACK_URI: ${CALLBACK_URI}" && \
    echo "DRIVER_BINARIES: ${DRIVER_BINARIES}" && \
    echo "HUB_URI: ${HUB_URI}" && \    
    echo "INTERVAL_TIME: ${INTERVAL_TIME}" && \
    echo "TOKEN: ${TOKEN}"

# Create the /bots directory and ensure it has read/write permissions
RUN mkdir -p /bots && chmod 777 /bots

# Create a directory for your script
WORKDIR /app

# Copy the PowerShell script and .env file into the container
COPY .env /app/.env
COPY Start-FileListenerBot.ps1 /app/Start-FileListenerBot.ps1
COPY modules /app/modules/

# Make script executable (optional good practice)
RUN chmod +x /app/Start-FileListenerBot.ps1

SHELL ["/bin/sh", "-c"]
ENTRYPOINT pwsh -NoLogo -File ./Start-FileListenerBot.ps1 \
  -BotId           "$BOT_ID" \
  -BotName         "$BOT_NAME" \  
  -BotVolume       "/bots" \
  -CallbackIngress "$CALLBACK_INGRESS" \
  -CallbackUri     "$CALLBACK_URI" \
  -DriverBinaries  "$DRIVER_BINARIES" \
  -HubUri          "$HUB_URI" \
  -IntervalTime    "$INTERVAL_TIME" \
  -Token           "$TOKEN"
