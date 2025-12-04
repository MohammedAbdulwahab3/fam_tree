#!/bin/bash

# AWS Elastic Beanstalk Deployment Script
# Usage: ./deploy-eb.sh

set -e

echo "🚀 Starting Elastic Beanstalk Deployment..."

# Check if EB CLI is installed
if ! command -v eb &> /dev/null; then
    echo "❌ EB CLI not found. Installing..."
    pip install awsebcli --upgrade --user
fi

cd "$(dirname "$0")"

# Create necessary files
echo "📝 Creating configuration files..."

# Create .ebextensions directory
mkdir -p .ebextensions

# Create 01_go.config
cat > .ebextensions/01_go.config << 'EOF'
option_settings:
  aws:elasticbeanstalk:environment:proxy:
    ProxyServer: nginx
  aws:elasticbeanstalk:container:golang:
    GOPATH: /go
  aws:elasticbeanstalk:application:environment:
    PORT: 5000
EOF

# Create Buildfile
cat > Buildfile << 'EOF'
make: go build -o application .
EOF

# Create Procfile
cat > Procfile << 'EOF'
web: ./application
EOF

echo "✅ Configuration files created"

# Initialize EB (if not already initialized)
if [ ! -f ".elasticbeanstalk/config.yml" ]; then
    echo "🔧 Initializing Elastic Beanstalk..."
    eb init --platform go --region "${AWS_DEFAULT_REGION:-eu-north-1}"
fi

# Check if environment exists
if ! eb list | grep -q "family-tree-prod"; then
    echo "🏗️  Creating environment..."
    eb create family-tree-prod \
        --single \
        --instance-type t2.micro \
        --envvars "GIN_MODE=release,PORT=5000"
else
    echo "✅ Environment already exists"
fi

echo "📦 Deploying application..."
eb deploy

echo "🎉 Deployment complete!"
echo ""
echo "📊 Environment status:"
eb status

echo ""
echo "🌐 Open your application:"
echo "Run: eb open"
echo ""
echo "📝 View logs:"
echo "Run: eb logs"
echo ""
echo "⚙️  Set environment variables:"
echo "Run: eb setenv DATABASE_URL=\"postgresql://...\" FIREBASE_CREDENTIALS='{...}'"
