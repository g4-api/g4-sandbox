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
    apt-get install -y wget apt-transport-https software-properties-common gnupg curl && \
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
RUN echo "BASE64_RESPONSE_CONTENT: ${BASE64_RESPONSE_CONTENT}" && \
    echo "BOT_ID: ${BOT_ID}" && \
    echo "BOT_NAME: ${BOT_NAME}" && \
    echo "CALLBACK_INGRESS: ${CALLBACK_INGRESS}" && \
    echo "CALLBACK_URI: ${CALLBACK_URI}" && \
    echo "CONTENT_TYPE: ${CONTENT_TYPE}" && \    
    echo "DRIVER_BINARIES: ${DRIVER_BINARIES}" && \
    echo "ENTRY_POINT_INGRESS: ${ENTRY_POINT_INGRESS}" && \
    echo "ENTRY_POINT_URI: ${ENTRY_POINT_URI}" && \
    echo "HUB_URI: ${HUB_URI}" && \
    echo "SAVE_ERRORS: ${SAVE_ERRORS}" && \
    echo "SAVE_RESPONSE: ${SAVE_RESPONSE}" && \
    echo "TOKEN: ${TOKEN}"

# Create the /bots directory and ensure it has read/write permissions
RUN mkdir -p /bots && chmod 777 /bots

# Create a directory for your script
WORKDIR /app

# Copy the PowerShell script and .env file into the container
COPY .env /app/.env
COPY Start-HttpStaticListenerBot.ps1 /app/Start-HttpStaticListenerBot.ps1
COPY modules /app/modules/

# Make script executable (optional good practice)
RUN chmod +x /app/Start-HttpStaticListenerBot.ps1

SHELL ["/bin/sh", "-c"]
ENTRYPOINT pwsh -NoLogo -File ./Start-HttpStaticListenerBot.ps1 \
  -Base64ResponseContent "$BASE64_RESPONSE_CONTENT" \
  -BotId                 "$BOT_ID" \  
  -BotName               "$BOT_NAME" \
  -BotVolume             "/bots" \
  -CallbackIngress       "$CALLBACK_INGRESS" \
  -CallbackUri           "$CALLBACK_URI" \
  -ContentType           "$CONTENT_TYPE" \
  -DriverBinaries        "$DRIVER_BINARIES" \
  -EntryPointIngress     "$ENTRY_POINT_INGRESS" \
  -EntryPointUri         "$ENTRY_POINT_URI" \
  -HubUri                "$HUB_URI" \
  -Token                 "$TOKEN"