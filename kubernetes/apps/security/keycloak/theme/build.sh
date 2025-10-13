#!/bin/bash
set -e

THEME_NAME="custom-redhat"
VERSION="1.0.0"
REGISTRY="ghcr.io/trosvald"
IMAGE_NAME="keycloak-theme"

echo "Building Keycloak theme: ${THEME_NAME}"

# Build Docker image
docker build -t ${REGISTRY}/${IMAGE_NAME}:${VERSION} .
docker tag ${REGISTRY}/${IMAGE_NAME}:${VERSION} ${REGISTRY}/${IMAGE_NAME}:latest

echo "Pushing to registry..."
docker push ${REGISTRY}/${IMAGE_NAME}:${VERSION}
docker push ${REGISTRY}/${IMAGE_NAME}:latest

echo "✅ Theme built and pushed successfully!"
echo "Image: ${REGISTRY}/${IMAGE_NAME}:${VERSION}"
