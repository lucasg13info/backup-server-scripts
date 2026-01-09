# server-scripts

# 🗄️ Server Backup Automation

Production-ready server backup solution using **Bash**, **tar**, **Docker**, and **rclone**, with **Google Drive integration**, **database dumps**, **retention policy**, and **email notifications**.

This repository documents and stores the backup strategy used on my Linux server.

---

## 📌 Overview

This backup system was designed to be:

- ✔ Production-ready  
- ✔ DevOps / SRE grade  
- ✔ Fully automated  
- ✔ Auditable  
- ✔ Restore-safe  
- ✔ Incremental with retention policy  

It performs:
- System and application backups
- Docker data persistence backups
- PostgreSQL database dumps
- Sync to Google Drive
- Email notifications via SMTP (msmtp)

---

## 🧰 Technologies Used

- **Bash Script**
- **tar** (compression & archiving)
- **rclone** (Google Drive integration)
- **Docker**
- **PostgreSQL**
- **msmtp** (SMTP email service)
- **cron** (automation)

---

## ☁️ Cloud Storage – rclone

`rclone` is used to connect to **Google Drive** with full access to the account.

Purpose:
- Upload backups securely
- Sync local backups to cloud
- Enable disaster recovery

---

## 📂 Backup Scope

The following directories are included in the backup:

```bash
/etc        # System configuration files
/srv        # Docker persistent data (volumes / bind mounts)
/var/www    # Websites and web applications
/home       # User data
All files are archived using tar before being sent to Google Drive.

🐳 Docker & Database Backup
PostgreSQL Dump (Docker)
The database runs inside a Docker container and is backed up using pg_dump.

Dump Command:
bash
Copy code
docker exec -t postgres-blog-Lucas \
pg_dump -U amigoscode -F c -b -v bloglucas \
> /root/backupServerGoogleDrive/backup/postgres-bloglucas.dump
Format: Custom (-F c)

Includes blobs (-b)

Verbose mode enabled (-v)

Restore-safe

📜 Backup Script
Script Location
bash
Copy code
/root/backup.sh
Features
Incremental backups

Retention policy (auto cleanup of old backups)

Docker-safe

Database dump included

Cloud sync (Google Drive)

Email notifications

⏱ Automation (Cron)
The backup script is executed automatically via cron, typically during off-peak hours (night).

Example:

bash
Copy code
0 2 * * * /root/backup.sh
📧 Email Notifications (msmtp)
The server sends email notifications to confirm backup execution and status.

Test Email Command
bash
Copy code
echo -e "Subject: Test Hostinger SMTP\n\nThis is a test email from server" \
| msmtp -a hostinger lucccasestefano1@gmail.com
SMTP configured via msmtp

Used for backup alerts and monitoring

Lightweight and reliable

🔐 Security Notes
Google Drive access handled securely via rclone config

Scripts executed as root (recommended to restrict access)

Backup files can be encrypted if required (future improvement)

♻️ Restore Strategy
tar archives allow full or partial restore

PostgreSQL dumps are compatible with pg_restore

Cloud backups ensure disaster recovery

🚀 Status
✅ Active
✅ Stable
✅ Production environment


👤 Author
Lucas Estefano
Australia 🇦🇺