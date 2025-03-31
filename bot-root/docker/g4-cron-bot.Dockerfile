# Use a lightweight official Ubuntu as the base image
FROM ubuntu:24.04

# Prevent interactive dialogs during package install
ENV DEBIAN_FRONTEND=noninteractive

# Install prerequisites and cron
RUN apt-get update && \
    apt-get install -y wget apt-transport-https software-properties-common gnupg cron && \
    rm -rf /var/lib/apt/lists/*

# Download and install Microsoft repository GPG keys
RUN wget -q https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && \
    rm packages-microsoft-prod.deb

# Update package lists and install PowerShell
RUN apt-get update && \
    apt-get install -y powershell && \
    rm -rf /var/lib/apt/lists/*

# Create the /bots directory and ensure it has read/write permissions
RUN mkdir -p /bots && chmod 777 /bots

# Create a directory for your script
WORKDIR /app

# Copy the PowerShell script and .env file into the container
COPY .env /app/.env
COPY Start-CronBot.ps1 /app/Start-CronBot.ps1

# Make the PowerShell script executable (optional good practice)
RUN chmod +x /app/Start-CronBot.ps1

# Create the entrypoint script dynamically with echo statements to indicate parameter loading.
RUN echo '#!/bin/bash\n\
# Ensure the cron directory exists\n\
mkdir -p /etc/cron.d\n\
\n\
# Echo loaded parameters to confirm they are set correctly\n\
echo "Loaded parameters:"\n\
echo "BOT_NAME: ${BOT_NAME}"\n\
echo "CRON_SCHEDULES: ${CRON_SCHEDULES}"\n\
echo "DRIVER_BINARIES: ${DRIVER_BINARIES}"\n\
echo "HUB_URI: ${HUB_URI}"\n\
echo "TOKEN: ${TOKEN}"\n\
\n\
# Define the cron file name dynamically based on BOT_NAME\n\
CRON_FILE="/etc/cron.d/${BOT_NAME}-cron"\n\
\n\
# Create cron job file dynamically from the CRON_SCHEDULES environment variable\n\
IFS="," read -ra SCHEDULES <<< "$CRON_SCHEDULES"\n\
for schedule in "${SCHEDULES[@]}"; do\n\
  echo "$schedule pwsh /app/Start-CronBot.ps1 -BotVolume '/bots' -BotName '\$BOT_NAME' -DriverBinaries '\$DRIVER_BINARIES' -HubUri '\$HUB_URI' -Token '\$TOKEN' >> /var/log/cron.log 2>&1" >> $CRON_FILE\n\
done\n\
\n\
# Set proper permissions for the cron job file\n\
chmod 0644 $CRON_FILE\n\
\n\
# Apply the cron jobs\n\
crontab $CRON_FILE\n\
\n\
# Start the cron service\n\
cron\n\
\n\
# Tail the log file to keep the container running\n\
touch /var/log/cron.log\n\
tail -f /var/log/cron.log' > /app/entrypoint.sh

# Ensure the entrypoint script is executable
RUN chmod +x /app/entrypoint.sh

# Set the entrypoint to start the cron service and keep the container running
ENTRYPOINT ["/app/entrypoint.sh"]