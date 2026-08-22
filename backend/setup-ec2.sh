#!/bin/bash

# AWS EC2 Deployment Script
# This script sets up the backend on a fresh EC2 instance

set -e

echo "🚀 Starting EC2 Setup..."

# Update system
echo "📦 Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install Go
echo "🔧 Installing Go..."
sudo apt install -y golang-go git nginx

# Verify Go installation
go version

# Clone repository
echo "📥 Cloning repository..."
cd ~
if [ -d "backend" ]; then
    echo "⚠️  Backend directory exists, pulling latest changes..."
    cd backend
    git pull
else
    git clone https://github.com/MohammedAbdulwahab3/tree.git backend
    cd backend
fi

# Install dependencies and build
echo "🏗️  Building application..."
go mod download
go build -o server .

# Create systemd service
echo "⚙️  Creating systemd service..."
sudo tee /etc/systemd/system/family-tree.service > /dev/null << 'EOF'
[Unit]
Description=Family Tree Backend
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/backend
Environment="GIN_MODE=release"
Environment="PORT=8080"
ExecStart=/home/ubuntu/backend/server
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create environment file for secrets
echo "🔐 Creating environment file..."
sudo tee /home/ubuntu/backend/.env > /dev/null << 'EOF'
# Add your environment variables here
# DATABASE_URL=postgresql://...
# FIREBASE_CREDENTIALS=...
EOF

echo "⚠️  IMPORTANT: Edit /home/ubuntu/backend/.env and add your environment variables!"

# Update service to use env file
sudo tee /etc/systemd/system/family-tree.service > /dev/null << 'EOF'
[Unit]
Description=Family Tree Backend
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/backend
EnvironmentFile=/home/ubuntu/backend/.env
ExecStart=/home/ubuntu/backend/server
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Start service
echo "🎬 Starting service..."
sudo systemctl daemon-reload
sudo systemctl enable family-tree
sudo systemctl start family-tree

# Setup Nginx
echo "🌐 Configuring Nginx..."
sudo tee /etc/nginx/sites-available/family-tree > /dev/null << 'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/family-tree /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx

echo "✅ Setup complete!"
echo ""
echo "📊 Service status:"
sudo systemctl status family-tree --no-pager
echo ""
echo "🌐 Your backend is running at: http://$(curl -s ifconfig.me)"
echo ""
echo "📝 Next steps:"
echo "1. Edit environment variables: nano /home/ubuntu/backend/.env"
echo "2. Restart service: sudo systemctl restart family-tree"
echo "3. View logs: sudo journalctl -u family-tree -f"
