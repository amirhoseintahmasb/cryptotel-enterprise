#!/bin/bash

# Cryptotel Enterprise - GitHub Setup Script
# This script helps set up the GitHub repository and push the code

set -e

echo "🚀 Setting up GitHub repository for Cryptotel Enterprise..."

# Configuration
REPO_NAME="cryptotel-enterprise"
GITHUB_USERNAME="amirhoseintahmasb"
REPO_URL="https://github.com/$GITHUB_USERNAME/$REPO_NAME.git"

echo "📋 Repository Details:"
echo "   Name: $REPO_NAME"
echo "   Username: $GITHUB_USERNAME"
echo "   URL: $REPO_URL"
echo ""

# Check if remote already exists
if git remote get-url origin >/dev/null 2>&1; then
    echo "⚠️  Remote 'origin' already exists:"
    git remote get-url origin
    echo ""
    read -p "Do you want to update it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git remote set-url origin $REPO_URL
        echo "✅ Updated remote origin"
    else
        echo "❌ Skipped remote update"
        exit 1
    fi
else
    echo "➕ Adding remote origin..."
    git remote add origin $REPO_URL
    echo "✅ Added remote origin"
fi

echo ""
echo "📝 Instructions for GitHub repository creation:"
echo "================================================"
echo "1. Go to https://github.com/new"
echo "2. Repository name: $REPO_NAME"
echo "3. Description: Enterprise Multi-Project Management Platform"
echo "4. Make it Public"
echo "5. Do NOT initialize with README (we already have one)"
echo "6. Click 'Create repository'"
echo ""
echo "After creating the repository, run:"
echo "   git push -u origin master"
echo ""
echo "Or if you want to use the main branch:"
echo "   git branch -M main"
echo "   git push -u origin main"
echo ""

read -p "Have you created the repository on GitHub? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚀 Pushing to GitHub..."
    
    # Check if we should use main branch
    read -p "Use 'main' branch instead of 'master'? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        git push -u origin master
    else
        git branch -M main
        git push -u origin main
    fi
    
    echo ""
    echo "🎉 Success! Your repository is now available at:"
    echo "   https://github.com/$GITHUB_USERNAME/$REPO_NAME"
    echo ""
    echo "📊 Repository Statistics:"
    echo "   Files: $(git ls-files | wc -l)"
    echo "   Lines of Code: $(find . -name '*.sh' -o -name '*.yml' -o -name '*.yaml' -o -name '*.md' | xargs wc -l | tail -1)"
    echo ""
    echo "🔗 Next Steps:"
    echo "   1. Add topics to your repository: devops, docker, swarm, traefik, monitoring"
    echo "   2. Create issues for future enhancements"
    echo "   3. Set up GitHub Actions for CI/CD"
    echo "   4. Share with the DevOps community!"
else
    echo "❌ Please create the repository first, then run this script again."
fi 