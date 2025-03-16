#!/bin/bash

echo "🚀 Starting n8n Self-Hosted Deployment..."

# 1️⃣ Ask for user inputs
read -p "Enter subdomain for n8n (e.g., n8n.clientdomain.com): " N8N_DOMAIN
read -p "Enter email for SSL certificate (Let's Encrypt): " SSL_EMAIL
read -sp "Enter PostgreSQL password (for n8n database): " POSTGRES_PASSWORD
echo ""
read -p "Enter Google Drive folder name for backups (default: n8n-backups): " GDRIVE_FOLDER
GDRIVE_FOLDER=${GDRIVE_FOLDER:-n8n-backups}

# 2️⃣ Set Timezone
echo "🌍 Configuring system timezone..."
read -p "Enter your timezone (e.g., Asia/Kolkata): " TIMEZONE
sudo timedatectl set-timezone "$TIMEZONE"

# 3️⃣ Ask if the user wants to configure SMTP
read -p "Do you want to set up SMTP for email notifications? (yes/no): " SMTP_SETUP

SMTP_ENV=""
if [[ "$SMTP_SETUP" == "yes" ]]; then
    read -p "Enter SMTP Host (e.g., smtp.gmail.com): " SMTP_HOST
    read -p "Enter SMTP Port (e.g., 465): " SMTP_PORT
    read -p "Enter SMTP User (email address): " SMTP_USER
    read -sp "Enter SMTP Password: " SMTP_PASS
    echo ""
    read -p "Use SSL? (true/false): " SMTP_SSL

    SMTP_ENV="
      - N8N_EMAIL_MODE=smtp
      - N8N_SMTP_HOST=$SMTP_HOST
      - N8N_SMTP_PORT=$SMTP_PORT
      - N8N_SMTP_USER=$SMTP_USER
      - N8N_SMTP_PASS=$SMTP_PASS
      - N8N_SMTP_SSL=$SMTP_SSL"
else
    SMTP_ENV="
      # Uncomment and configure SMTP if needed
      # - N8N_EMAIL_MODE=smtp
      # - N8N_SMTP_HOST=smtp.gmail.com
      # - N8N_SMTP_PORT=465
      # - N8N_SMTP_USER=admin@admin.com
      # - N8N_SMTP_PASS=password
      # - N8N_SMTP_SSL=true"
fi

# 4️⃣ Ask if the user wants to enable n8n metrics
read -p "Enable n8n metrics? (true/false): " N8N_METRICS
N8N_METRICS=${N8N_METRICS:-true}  # Default to true if empty

# 5️⃣ Install Required Packages
echo "🔧 Installing dependencies..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io docker-compose nginx certbot python3-certbot-nginx unzip curl

# 6️⃣ Create n8n Deployment Folder
echo "📂 Creating n8n deployment folder..."
mkdir -p ~/n8n && cd ~/n8n

# 7️⃣ Generate Docker-Compose File
echo "📜 Creating docker-compose.yml..."
cat <<EOF > docker-compose.yml
version: '3.7'

services:
  n8n:
    image: n8nio/n8n:latest
    restart: always
    ports:
      - "5678:5678"
    environment:
      - TZ=$TIMEZONE
      - GENERIC_TIMEZONE=$TIMEZONE
      - N8N_PROTOCOL=http
      - N8N_HOST=$N8N_DOMAIN
      - WEBHOOK_URL=https://$N8N_DOMAIN/
      - N8N_EDITOR_BASE_URL=https://$N8N_DOMAIN/
      - N8N_ENDPOINT_WEBHOOK=prod
      - N8N_ENDPOINT_WEBHOOK_TEST=test
      - N8N_METRICS=$N8N_METRICS
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=db
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=n8n_user
      - DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}
      $SMTP_ENV
    volumes:
      - ~/.n8n:/home/node/.n8n

  db:
    image: postgres:15
    restart: always
    environment:
      - POSTGRES_DB=n8n
      - POSTGRES_USER=n8n_user
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
EOF

# 8️⃣ Start n8n
echo "🚀 Starting n8n and PostgreSQL..."
docker-compose up -d

# 9️⃣ Set Up Nginx Reverse Proxy with SSL
echo "🔒 Configuring Nginx and SSL..."
sudo bash -c "cat > /etc/nginx/sites-available/n8n <<EOF
server {
    server_name ${N8N_DOMAIN};
    listen 80;

    location / {
        proxy_pass http://localhost:5678;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \"Upgrade\";
        proxy_set_header Host \$host;
        proxy_http_version 1.1;
        chunked_transfer_encoding off;
        proxy_buffering off;
        proxy_cache off;
    }
}
EOF"

sudo ln -s /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/
sudo systemctl restart nginx
sudo certbot --nginx -d ${N8N_DOMAIN} --non-interactive --agree-tos -m ${SSL_EMAIL}

# 🔟 Install & Configure rclone for Google Drive Backups
echo "☁️ Installing rclone..."
curl https://rclone.org/install.sh | sudo bash

# 🔟 Configure rclone for Google Drive
echo "⚙️ Setting up Google Drive storage for backups..."
cat <<EOF > rclone.conf
[gdrive]
type = drive
scope = drive
token = {"access_token":"","token_type":"Bearer","refresh_token":"","expiry":""}
EOF

rclone authorize "drive" --config=rclone.conf
mkdir -p ~/.config/rclone
mv rclone.conf ~/.config/rclone/rclone.conf
rclone mkdir gdrive:${GDRIVE_FOLDER}

# 1️⃣1️⃣ Setup Backup Scripts
echo "💾 Setting up daily backups..."
mkdir -p ~/backups

cat <<EOF > ~/backups/backup-n8n.sh
#!/bin/bash
DATE=\$(date +\%F)
pg_dump -U n8n_user -h localhost n8n > ~/backups/n8n_backup_\$DATE.sql
tar -czf ~/backups/n8n_files_\$DATE.tar.gz ~/.n8n
rclone copy ~/backups gdrive:${GDRIVE_FOLDER}
EOF

chmod +x ~/backups/backup-n8n.sh
(crontab -l 2>/dev/null; echo "0 2 * * * TZ=${TIMEZONE} ~/backups/backup-n8n.sh") | crontab -

# ✅ Done!
echo "✅ n8n deployment is complete!"
echo "🌍 Visit: https://${N8N_DOMAIN}"
echo "🔑 Set up your admin account on first login!"
echo "📂 Modify ~/n8n/docker-compose.yml anytime and restart with: 'docker-compose up -d'."
echo "☁️ Backups are stored in Google Drive under: '${GDRIVE_FOLDER}'"
echo "📧 SMTP is $( [[ "$SMTP_SETUP" == "yes" ]] && echo "enabled" || echo "disabled" )."
echo "📊 Metrics are set to: $N8N_METRICS."
