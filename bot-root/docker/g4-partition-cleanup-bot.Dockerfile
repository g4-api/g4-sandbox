# Use a lightweight official Ubuntu as the base image
FROM ubuntu:24.04

# Expose the internal port which will be used by the listener
EXPOSE 8085

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

# Echo the variables in the desired format during build
RUN echo "CLEANUP_BOT_INTERVAL_TIME: ${CLEANUP_BOT_INTERVAL_TIME}" && \
    echo "CLEANUP_BOT_NUNBER_OF_FILES: ${CLEANUP_BOT_NUNBER_OF_FILES}" && \
    echo "HUB_URI: ${HUB_URI}" && \
    echo "LISTENER_PORT: ${LISTENER_PORT}"

# Create the /bots directory and ensure it has read/write permissions
RUN mkdir -p /bots && chmod 777 /bots

# Create a directory for your script
WORKDIR /app

# Copy the PowerShell script and .env file into the container
COPY .env /app/.env
COPY Start-CleanupBot.ps1 /app/Start-CleanupBot.ps1
COPY modules /app/modules/

# Make script executable (optional good practice)
RUN chmod +x /app/Start-CleanupBot.ps1

# Pass four parameters to the script:
#   1) The bot volume location (/bot)
#   2) BotName from environment variable
#   3) HubUri from environment variable
#   4) IntervalTime from environment variable
CMD ["pwsh", "-Command", "./Start-CleanupBot.ps1 /bots $env:CLEANUP_BOT_INTERVAL_TIME $env:HUB_URI $env:LISTENER_PORT $env:CLEANUP_BOT_NUNBER_OF_FILES"]
