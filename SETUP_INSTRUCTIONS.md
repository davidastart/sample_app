# Complete Setup Instructions

## Overview
This guide will walk you through deploying the Therapist Office Application from your Mac to your OCI VM.

---

## Phase 1: Prepare Your Mac (5 minutes)

### 1. Create local project directory
```bash
mkdir -p ~/projects/therapist-app
cd ~/projects/therapist-app
```

### 2. Copy all files from the deployment package
Download the deployment package and extract all files to `~/projects/therapist-app/`

Your directory structure should look like:
```
therapist-app/
├── backend/
│   ├── Dockerfile
│   ├── main.py
│   ├── config.py
│   ├── database.py
│   ├── requirements.txt
│   └── .env.example
├── frontend/
│   ├── Dockerfile
│   ├── app/
│   ├── package.json
│   ├── next.config.js
│   ├── tsconfig.json
│   └── .env.example
├── database/
│   └── schema.sql
├── docker-compose.yml
├── deploy.sh
├── .gitignore
└── README.md
```

### 3. Configure environment variables

```bash
# Copy example files
cp backend/.env.example backend/.env
cp frontend/.env.example frontend/.env
```

Edit `backend/.env`:
```bash
# Generate a secure SECRET_KEY
openssl rand -hex 32

# Edit the file
nano backend/.env
```

Update these values in `backend/.env`:
```env
DATABASE_PASSWORD=YourSecurePassword123!
SECRET_KEY=<paste-the-generated-key-here>
OCI_COMPARTMENT_ID=<your-oci-compartment-ocid>
OCI_REGION=us-ashburn-1
```

**How to find your OCI Compartment ID:**
1. Log into OCI Console
2. Click Profile → Tenancy
3. Copy the OCID (starts with `ocid1.compartment.oc1..`)

---

## Phase 2: Push to GitHub (5 minutes)

### Option A: Using GitHub Desktop (Recommended)

1. Open GitHub Desktop
2. File → Add Local Repository
3. Choose `~/projects/therapist-app`
4. Click "Publish repository"
5. Name: `sample_app`
6. Uncheck "Keep this code private" or leave checked based on preference
7. Click "Publish Repository"

### Option B: Using Command Line

```bash
cd ~/projects/therapist-app

# Initialize git
git init

# Add GitHub remote
git remote add origin https://github.com/davidastart/sample_app.git

# Add all files
git add .

# Commit
git commit -m "Initial deployment setup"

# Push to GitHub
git branch -M main
git push -u origin main
```

### ⚠️ Important: Verify .gitignore
Make sure `.gitignore` is working - your `.env` files should NOT be in GitHub:

```bash
# Check what will be committed
git status

# You should NOT see:
# - backend/.env
# - frontend/.env
# - .oci/ directory
```

---

## Phase 3: Prepare Your OCI VM (10 minutes)

### 1. SSH into your VM
```bash
ssh opc@<your-vm-public-ip>
```

### 2. Install required software
```bash
# Update system
sudo dnf update -y

# Install Podman and tools
sudo dnf install -y podman podman-compose git

# Verify installations
podman --version
git --version
```

### 3. Configure firewall (if needed)
```bash
# Open ports for the application
sudo firewall-cmd --permanent --add-port=3000/tcp
sudo firewall-cmd --permanent --add-port=8000/tcp
sudo firewall-cmd --permanent --add-port=1521/tcp
sudo firewall-cmd --reload

# Verify
sudo firewall-cmd --list-all
```

### 4. Copy OCI configuration (for Generative AI)

**On your Mac:**
```bash
# Set up OCI CLI if you haven't already
bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)"

# Configure OCI CLI
oci setup config

# Copy to VM
scp -r ~/.oci opc@<your-vm-ip>:~/
```

**On your VM:**
```bash
# Verify OCI config
ls -la ~/.oci/
# Should see: config, oci_api_key.pem
```

---

## Phase 4: Deploy the Application (20 minutes)

### 1. Clone repository on VM
```bash
cd ~
git clone https://github.com/davidastart/sample_app.git
cd sample_app
```

### 2. Create .env files
```bash
# Copy examples
cp backend/.env.example backend/.env
cp frontend/.env.example frontend/.env

# Edit backend .env with your actual values
nano backend/.env
```

Update these in `backend/.env`:
- `DATABASE_PASSWORD` (same as you set on Mac)
- `SECRET_KEY` (same as you generated on Mac)
- `OCI_COMPARTMENT_ID` (your OCI compartment OCID)

**💡 Tip:** You can paste the exact `.env` content from your Mac

### 3. Make deploy script executable
```bash
chmod +x deploy.sh
```

### 4. Run deployment
```bash
./deploy.sh
```

This will take 15-20 minutes on first run. The script will:
- ✅ Build all containers
- ✅ Pull Oracle Database 23ai
- ✅ Configure the database
- ✅ Create schema
- ✅ Start all services

**☕ Grab a coffee while it runs!**

---

## Phase 5: Verify Deployment (5 minutes)

### 1. Check services are running
```bash
podman ps
```

You should see 3 containers:
- `therapist-db`
- `therapist-backend`
- `therapist-frontend`

### 2. Check backend health
```bash
curl http://localhost:8000/health
```

Expected response:
```json
{
  "status": "healthy",
  "database": "connected",
  "version": "1.0.0"
}
```

### 3. Check frontend
Open your browser to:
```
http://<your-vm-public-ip>:3000
```

You should see the Therapist Office Application home page with system status.

### 4. Check database
```bash
podman exec -it therapist-db sqlplus therapist_app/AppPassword123!@FREEPDB1
```

```sql
-- List tables
SELECT table_name FROM user_tables ORDER BY table_name;

-- Check sample data
SELECT COUNT(*) FROM therapists;

-- Exit
EXIT;
```

---

## 🎉 Success!

If all checks pass, your application is running!

**Access Points:**
- Frontend: http://<vm-ip>:3000
- Backend API: http://<vm-ip>:8000
- API Docs: http://<vm-ip>:8000/docs
- Database: localhost:1521/FREEPDB1

---

## 🔄 Making Updates

### Update workflow:

1. **On Mac:** Make changes in VS Code
2. **Test locally** (optional)
3. **Commit & Push** with GitHub Desktop
4. **On VM:** Pull and restart

```bash
# On VM
cd ~/sample_app
git pull origin main

# Restart only changed services
podman-compose restart backend
# OR restart everything
podman-compose restart
```

---

## 🐛 Troubleshooting

### Issue: Deployment script fails

**Check logs:**
```bash
podman logs therapist-db
podman logs therapist-backend
podman logs therapist-frontend
```

### Issue: Database won't start

```bash
# Check database logs
podman logs therapist-db | tail -50

# Common fix: Remove and recreate
podman-compose down -v
./deploy.sh
```

### Issue: Backend can't connect to database

```bash
# Verify database is accessible
podman exec therapist-db sqlplus therapist_app/AppPassword123!@FREEPDB1

# Check backend environment
podman exec therapist-backend env | grep DATABASE

# Verify .env file
cat backend/.env
```

### Issue: Port already in use

```bash
# Check what's using the port
sudo netstat -tlnp | grep -E '3000|8000|1521'

# Stop conflicting service or change ports in docker-compose.yml
```

### Issue: OCI Generative AI not accessible

```bash
# Verify OCI config on VM
cat ~/.oci/config

# Test OCI CLI
oci iam region list

# Check compartment access
oci iam compartment get --compartment-id <your-compartment-id>
```

### Complete Reset (⚠️ Deletes all data)

```bash
cd ~/sample_app
podman-compose down -v
./deploy.sh
```

---

## 📞 Getting Help

### View all logs
```bash
podman-compose logs -f
```

### Check service health
```bash
# All services
podman ps

# Detailed status
podman-compose ps
```

### Connect to containers
```bash
# Backend
podman exec -it therapist-backend bash

# Database
podman exec -it therapist-db bash

# Frontend
podman exec -it therapist-frontend sh
```

---

## 📝 Quick Reference

### Essential Commands

```bash
# Start services
podman-compose up -d

# Stop services
podman-compose down

# Restart services
podman-compose restart

# View logs
podman logs -f <container-name>

# List running containers
podman ps

# Pull latest code
git pull origin main
```

### File Locations

- **Application:** `~/sample_app/`
- **Database data:** Docker volume `oracle-data`
- **OCI config:** `~/.oci/`
- **Logs:** `podman logs <container>`

---

## ✅ Checklist

- [ ] Copied all files to Mac
- [ ] Configured backend/.env
- [ ] Pushed to GitHub
- [ ] VM has Podman installed
- [ ] Copied OCI config to VM
- [ ] Cloned repo on VM
- [ ] Configured backend/.env on VM
- [ ] Ran ./deploy.sh
- [ ] Verified all services running
- [ ] Tested frontend URL
- [ ] Tested backend /health
- [ ] Tested database connection

---

**🎯 Next Steps:**

Now that your infrastructure is running, you can start building features:
1. User authentication system
2. Patient management
3. Session notes
4. Treatment plan generation with OCI AI

See the main project documentation for the full implementation plan!
