# Therapist Office Application

HIPAA-compliant treatment planning application with AI-powered recommendations using Oracle Cloud Infrastructure.

## 🏥 Features

- **Secure Patient Management** - Each therapist can only access their own patients
- **Session Notes** - Comprehensive note-taking with HIPAA compliance
- **AI-Powered Treatment Plans** - Evidence-based recommendations using OCI Generative AI
- **Office Templates** - Shared treatment templates across the practice
- **Audit Logging** - Complete access tracking for HIPAA compliance

## 🛠️ Technology Stack

- **Frontend**: Next.js 14 (React, TypeScript, Tailwind CSS)
- **Backend**: FastAPI (Python)
- **Database**: Oracle Database 23ai (with AI Vector Search)
- **AI**: OCI Generative AI (Cohere Command A)
- **Containers**: Podman
- **Deployment**: Oracle Linux 9 on OCI

## 📋 Prerequisites

### On Your Mac (Development)
- Visual Studio Code
- GitHub Desktop
- Git

### On Your OCI VM (Deployment)
- Oracle Linux 9 instance
- Podman installed
- Access to OCI Generative AI service
- 2 OCPUs, 16GB RAM recommended

## 🚀 Quick Start

### Step 1: Clone to Your Mac

```bash
# Clone the repository
cd ~/projects
git clone https://github.com/davidastart/sample_app.git
cd sample_app

# Review and customize .env files
cp backend/.env.example backend/.env
cp frontend/.env.example frontend/.env

# Edit backend/.env with your settings:
# - DATABASE_PASSWORD
# - SECRET_KEY (generate with: openssl rand -hex 32)
# - OCI_COMPARTMENT_ID
```

### Step 2: Push to GitHub

Use GitHub Desktop to:
1. Open the repository
2. Review changes
3. Commit with message "Initial deployment setup"
4. Push to origin/main

### Step 3: Deploy to Your VM

```bash
# SSH into your OCI VM
ssh opc@<your-vm-ip>

# Clone the repository
cd ~
git clone https://github.com/davidastart/sample_app.git
cd sample_app

# Make deploy script executable
chmod +x deploy.sh

# Edit the backend .env file with your actual values
vi backend/.env
# Update: DATABASE_PASSWORD, SECRET_KEY, OCI_COMPARTMENT_ID

# Run the deployment (takes 15-20 minutes first time)
./deploy.sh
```

That's it! The script will:
1. ✅ Check for required tools
2. ✅ Build all containers
3. ✅ Start the database
4. ✅ Configure vector memory
5. ✅ Create database schema
6. ✅ Start backend and frontend
7. ✅ Run health checks

### Step 4: Access the Application

Once deployment completes:

- **Frontend**: http://<your-vm-ip>:3000
- **Backend API**: http://<your-vm-ip>:8000
- **API Docs**: http://<your-vm-ip>:8000/docs

## 📁 Project Structure

```
therapist-app/
├── backend/                 # FastAPI backend
│   ├── Dockerfile
│   ├── main.py             # API entry point
│   ├── config.py           # Configuration
│   ├── database.py         # Database connection
│   └── requirements.txt
├── frontend/                # Next.js frontend
│   ├── Dockerfile
│   ├── app/
│   │   ├── page.tsx        # Home page
│   │   └── layout.tsx
│   ├── package.json
│   └── next.config.js
├── database/
│   └── schema.sql          # Database schema
├── docker-compose.yml       # Podman compose config
├── deploy.sh               # Deployment script
└── README.md
```

## 🔐 Security Configuration

### 1. Generate Secure Keys

```bash
# Generate SECRET_KEY
openssl rand -hex 32

# Add to backend/.env
SECRET_KEY=<generated-key>
```

### 2. Configure OCI Credentials

```bash
# On your Mac, set up OCI CLI
oci setup config

# Copy config to VM
scp -r ~/.oci opc@<vm-ip>:~/
```

### 3. Set Database Password

```bash
# Edit backend/.env
DATABASE_PASSWORD=YourSecurePassword123!

# Also update in docker-compose.yml
ORACLE_PASSWORD=YourSecurePassword123!
```

## 🔧 Common Commands

### View Logs
```bash
# Backend logs
podman logs -f therapist-backend

# Frontend logs
podman logs -f therapist-frontend

# Database logs
podman logs -f therapist-db
```

### Restart Services
```bash
# Restart all services
podman-compose restart

# Restart specific service
podman restart therapist-backend
```

### Stop/Start Services
```bash
# Stop all
podman-compose down

# Start all
podman-compose up -d
```

### Database Access
```bash
# Connect to database
podman exec -it therapist-db sqlplus therapist_app/AppPassword123!@FREEPDB1

# Run SQL commands
SQL> SELECT table_name FROM user_tables;
SQL> EXIT;
```

### Update Deployment
```bash
# On your Mac: make changes and push to GitHub

# On your VM: pull and redeploy
cd ~/sample_app
git pull origin main
./deploy.sh
```

## 🐛 Troubleshooting

### Database won't start
```bash
# Check logs
podman logs therapist-db

# Check if port is in use
sudo netstat -tlnp | grep 1521

# Remove old volumes and restart
podman-compose down -v
./deploy.sh
```

### Backend can't connect to database
```bash
# Verify database is running
podman ps | grep therapist-db

# Test database connection
podman exec therapist-db sqlplus therapist_app/AppPassword123!@FREEPDB1

# Check backend environment
podman exec therapist-backend env | grep DATABASE
```

### Containers won't build
```bash
# Clean up old images
podman system prune -a

# Rebuild without cache
podman-compose build --no-cache
```

### Port conflicts
```bash
# Check what's using the ports
sudo netstat -tlnp | grep -E '3000|8000|1521'

# Change ports in docker-compose.yml if needed
# Example: "3001:3000" instead of "3000:3000"
```

## 📊 Health Checks

```bash
# Check all services
curl http://localhost:8000/health

# Expected response:
# {"status":"healthy","database":"connected","version":"1.0.0"}

# Check database directly
podman exec therapist-db sqlplus -s therapist_app/AppPassword123!@FREEPDB1 <<< "SELECT 'OK' FROM DUAL;"
```

## 🔄 Development Workflow

### 1. Develop Locally on Mac
```bash
cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload

# In another terminal
cd frontend
npm install
npm run dev
```

### 2. Test Changes
- Make changes in VS Code
- Test locally

### 3. Deploy to VM
```bash
# Commit and push via GitHub Desktop
# Then on VM:
git pull origin main
podman-compose restart
```

## 📚 Additional Documentation

- [Full Project Plan](docs/therapist_app_project_plan.md)
- [Quick Start Guide](docs/QUICK_START_GUIDE.md)
- [OCI Generative AI Docs](https://docs.oracle.com/iaas/Content/generative-ai/home.htm)
- [Oracle Database 23ai Docs](https://docs.oracle.com/en/database/oracle/oracle-database/23/)

## 🆘 Support

### Check Service Status
```bash
podman ps
podman-compose ps
```

### View All Logs
```bash
podman-compose logs -f
```

### Complete Reset
```bash
# ⚠️ WARNING: This deletes all data!
podman-compose down -v
./deploy.sh
```

## 📝 Environment Variables

### Backend (.env)
```env
DATABASE_HOST=oracle-db
DATABASE_PORT=1521
DATABASE_SERVICE=FREEPDB1
DATABASE_USER=therapist_app
DATABASE_PASSWORD=your_password

SECRET_KEY=your_secret_key
OCI_COMPARTMENT_ID=ocid1.compartment...
OCI_REGION=us-ashburn-1

CORS_ORIGINS=http://localhost:3000
```

### Frontend (.env)
```env
NEXT_PUBLIC_API_URL=http://localhost:8000
```

## 🎯 Next Steps

After successful deployment:

1. **Access the application** at http://<vm-ip>:3000
2. **Verify backend health** at http://<vm-ip>:8000/health
3. **Review logs** to ensure everything is working
4. **Start building features** - authentication, patient management, etc.

## 📄 License

Private use for therapist office. Not for redistribution.

## 👥 Contributors

- Development Team

---

**Version**: 1.0.0  
**Last Updated**: October 2025
