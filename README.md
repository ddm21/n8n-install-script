# 🚀 n8n Self-Hosted Setup (Automated)

This script fully automates the deployment of **n8n** on an **Ubuntu server** with:  
✅ **Docker + PostgreSQL**  
✅ **Nginx Reverse Proxy + SSL (Let's Encrypt)**  
✅ **Google Drive backups (via rclone)**  
✅ **SMTP Configuration (Optional)**  
✅ **Automatic Timezone Configuration**  

---

## 📌 **Prerequisites**  
1. Ubuntu 20.04+ Server (with root access)  
2. A domain/subdomain pointed to your server (e.g., `n8n.yourdomain.com`)  
3. (Optional) SMTP credentials for email notifications  

---

## 🔧 **Installation Steps**  

1️⃣ **Download the setup script**  
```bash
curl -O https://your-server.com/setup-n8n.sh
```

2️⃣ **Make it executable**  
```bash
chmod +x setup-n8n.sh
```

3️⃣ **Run the script**  
```bash
./setup-n8n.sh
```

4️⃣ **Follow the prompts** to enter:  
   - Your **n8n domain (subdomain)**
   - Your **email** for SSL  
   - **PostgreSQL password**  
   - (Optional) **SMTP details**  
   - **Timezone** for scheduling backups  

---

## 🌍 **Access n8n**  
Once setup is complete, visit:  
👉 **`https://n8n.yourdomain.com`**  

---

## ☁️ **Google Drive Backups**  
- Backups are stored in **Google Drive** under the folder you specified.  
- Runs **daily at 2 AM** (server time).  
- You can manually trigger a backup:  
  ```bash
  ~/backups/backup-n8n.sh
  ```

---

## 🔄 **Managing n8n**  
Start / Restart n8n:  
```bash
cd ~/n8n && docker-compose up -d
```
Stop n8n:  
```bash
cd ~/n8n && docker-compose down
```

---

## 🛠 **Modifying Configuration**  
- **n8n Environment Variables**: Edit `~/n8n/docker-compose.yml`  
- **Nginx Proxy Settings**: Edit `/etc/nginx/sites-available/n8n`  
- **Rclone Google Drive Config**: Edit `~/.config/rclone/rclone.conf`  
- Restart services after changes:  
  ```bash
  docker-compose up -d && sudo systemctl restart nginx
  ```

---

## 📧 **SMTP Email Setup**  
If skipped earlier, manually add SMTP settings in **docker-compose.yml**:  
```yaml
      - N8N_EMAIL_MODE=smtp
      - N8N_SMTP_HOST=smtp.gmail.com
      - N8N_SMTP_PORT=465
      - N8N_SMTP_USER=your-email@gmail.com
      - N8N_SMTP_PASS=your-password
      - N8N_SMTP_SSL=true
```
Then restart n8n:  
```bash
cd ~/n8n && docker-compose up -d
```

---

## 📊 **Enable/Disable n8n Metrics**  
Edit `docker-compose.yml` and modify:  
```yaml
      - N8N_METRICS=true  # Change to false if you want to disable
```
Then restart n8n:  
```bash
docker-compose up -d
```

---

## 🎯 **Uninstalling n8n**  
To remove **n8n, PostgreSQL, and backups**, run:  
```bash
cd ~
docker-compose down
rm -rf ~/n8n ~/backups ~/.n8n ~/.config/rclone
sudo rm /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/n8n
sudo systemctl restart nginx
```

---

## ✅ **Done!**  
n8n is now deployed and fully configured. 🚀  

For support, visit [n8n.io](https://n8n.io/).
