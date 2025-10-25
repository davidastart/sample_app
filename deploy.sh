#!/bin/bash

set -e  # Exit on any error

echo "=========================================="
echo "  Therapist App Deployment Script"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    print_error "Please do not run this script as root"
    exit 1
fi

# Check if podman is installed
if ! command -v podman &> /dev/null; then
    print_error "Podman is not installed. Please install it first:"
    echo "  sudo dnf install -y podman podman-compose"
    exit 1
fi

# Check if podman-compose is installed
if ! command -v podman-compose &> /dev/null; then
    print_warning "podman-compose not found, installing..."
    sudo dnf install -y podman-compose || {
        print_error "Failed to install podman-compose"
        exit 1
    }
fi

print_info "Checking for .env file..."
if [ ! -f "backend/.env" ]; then
    print_warning "backend/.env not found. Creating from example..."
    if [ -f "backend/.env.example" ]; then
        cp backend/.env.example backend/.env
        print_warning "Please edit backend/.env with your actual configuration!"
        print_warning "Required: DATABASE_PASSWORD, SECRET_KEY, OCI_COMPARTMENT_ID"
        read -p "Press Enter after editing backend/.env to continue..."
    else
        print_error "backend/.env.example not found!"
        exit 1
    fi
fi

if [ ! -f "frontend/.env" ]; then
    print_info "Creating frontend/.env..."
    echo "NEXT_PUBLIC_API_URL=http://localhost:8000" > frontend/.env
fi

print_info "Stopping existing containers (if any)..."
podman-compose down 2>/dev/null || true

print_info "Building containers (this may take 10-15 minutes)..."
podman-compose build

print_info "Starting services..."
podman-compose up -d

print_info "Waiting for database to be ready (this can take 5-10 minutes)..."
echo "Checking database health..."
COUNTER=0
MAX_TRIES=60
while [ $COUNTER -lt $MAX_TRIES ]; do
    if podman exec therapist-db sh -c "echo 'SELECT 1 FROM DUAL;' | sqlplus -s system/\${ORACLE_PWD}@//localhost:1521/FREEPDB1 2>/dev/null | grep -q '^1'" 2>/dev/null; then
        print_info "Database is ready!"
        break
    fi
    COUNTER=$((COUNTER+1))
    echo -n "."
    sleep 10
done
echo ""

if [ $COUNTER -eq $MAX_TRIES ]; then
    print_error "Database failed to start within expected time"
    print_info "Check logs with: podman logs therapist-db"
    exit 1
fi

print_info "Configuring vector memory..."
podman exec therapist-db sh -c "echo 'ALTER SYSTEM SET vector_memory_size=500M SCOPE=SPFILE;' | sqlplus -s sys/\${ORACLE_PWD}@FREEPDB1 as sysdba" || true

print_info "Creating application user..."
podman exec therapist-db sh -c "cat <<EOF | sqlplus -s sys/\${ORACLE_PWD}@FREEPDB1 as sysdba
CREATE USER therapist_app IDENTIFIED BY AppPassword123! DEFAULT TABLESPACE users TEMPORARY TABLESPACE temp QUOTA UNLIMITED ON users;
GRANT CONNECT, RESOURCE TO therapist_app;
GRANT CREATE VIEW, CREATE SYNONYM TO therapist_app;
GRANT EXECUTE ON SYS.DBMS_VECTOR TO therapist_app;
GRANT EXECUTE ON SYS.DBMS_VECTOR_CHAIN TO therapist_app;
EXIT;
EOF" 2>/dev/null || print_info "User might already exist, continuing..."

print_info "Running database schema..."
if [ -f "database/schema.sql" ]; then
    podman cp database/schema.sql therapist-db:/tmp/
    podman exec therapist-db sh -c "sqlplus therapist_app/AppPassword123!@FREEPDB1 @/tmp/schema.sql" || {
        print_warning "Schema installation had warnings, but continuing..."
    }
else
    print_warning "database/schema.sql not found, skipping schema creation"
fi

print_info "Restarting database to apply vector memory settings..."
podman restart therapist-db
sleep 30

print_info "Waiting for all services to be healthy..."
sleep 20

print_info "Checking service status..."
echo ""
echo "=========================================="
echo "  Deployment Summary"
echo "=========================================="
echo ""

# Check each service
if podman ps | grep -q therapist-db; then
    print_info "✓ Database is running"
else
    print_error "✗ Database is not running"
fi

if podman ps | grep -q therapist-backend; then
    print_info "✓ Backend is running"
else
    print_error "✗ Backend is not running"
fi

if podman ps | grep -q therapist-frontend; then
    print_info "✓ Frontend is running"
else
    print_error "✗ Frontend is not running"
fi

echo ""
echo "=========================================="
echo "  Access Information"
echo "=========================================="
echo ""
echo "Frontend:  http://localhost:3000"
echo "Backend:   http://localhost:8000"
echo "Database:  localhost:1521/FREEPDB1"
echo ""
echo "Backend Health: curl http://localhost:8000/health"
echo ""
echo "=========================================="
echo "  Useful Commands"
echo "=========================================="
echo ""
echo "View logs:"
echo "  podman logs -f therapist-backend"
echo "  podman logs -f therapist-frontend"
echo "  podman logs -f therapist-db"
echo ""
echo "Stop services:"
echo "  podman-compose down"
echo ""
echo "Restart services:"
echo "  podman-compose restart"
echo ""
echo "Connect to database:"
echo "  podman exec -it therapist-db sqlplus therapist_app/AppPassword123!@FREEPDB1"
echo ""
echo "=========================================="
print_info "Deployment complete!"
echo "=========================================="
