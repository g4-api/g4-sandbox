# Use a lightweight official Ubuntu as the base image
FROM ubuntu:24.04

# Expose the internal port which will be used by the listener
EXPOSE 8080

# Prevent interactive dialogs during package install
ENV DEBIAN_FRONTEND=noninteractive

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
RUN echo "BOT_NAME: ${BOT_NAME}" && \
    echo "BOT_URI: ${BOT_URI}" && \
    echo "CONTENT_TYPE: ${CONTENT_TYPE}" && \
    echo "DRIVER_BINARIES: ${DRIVER_BINARIES}" && \
    echo "HUB_URI: ${HUB_URI}" && \
    echo "RESPONSE_CONTENT: ${RESPONSE_CONTENT}" && \
    echo "TOKEN: ${TOKEN}"

# Create the /bots directory and ensure it has read/write permissions
RUN mkdir -p /bots && chmod 777 /bots

# Create a directory for your script
WORKDIR /app

# Copy the PowerShell script and .env file into the container
COPY .env /app/.env
COPY Start-HttpQsListenerBot.ps1 /app/Start-HttpQsListenerBot.ps1

# Make script executable (optional good practice)
RUN chmod +x /app/Start-HttpQsListenerBot.ps1

# Pass four parameters to the script:
#   1) The bot volume location (/bot)
#   2) BotName from environment variable
#   3) HubUri from environment variable
#   4) IntervalTime from environment variable
CMD ["pwsh", "-Command", "./Start-HttpQsListenerBot.ps1 /bots $env:BOT_NAME $env:BOT_PORT $env:CONTENT_TYPE $env:DRIVER_BINARIES $env:HUB_URI $env:RESPONSE_CONTENT $env:TOKEN"]
