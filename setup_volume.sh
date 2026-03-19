#!/bin/bash
# Setup script for RunPod network volume
# Makes comfyui-base models available to serverless workers
# Run once on a CPU pod attached to the network volume
#
# Usage: bash setup_volume.sh

set -e

COMFYUI_MODELS="/workspace/runpod-slim/ComfyUI/models"
SERVERLESS_MODELS="/workspace/models"

echo "=== RunPod Volume Setup for Serverless ==="

# Check if comfyui-base models exist
if [ ! -d "$COMFYUI_MODELS" ]; then
    echo "ERROR: ComfyUI models not found at $COMFYUI_MODELS"
    echo "Make sure you're running this on a volume set up with comfyui-base"
    exit 1
fi

# Remove existing symlink or directory if it exists
if [ -L "$SERVERLESS_MODELS" ]; then
    echo "Removing existing symlink at $SERVERLESS_MODELS"
    rm "$SERVERLESS_MODELS"
elif [ -d "$SERVERLESS_MODELS" ]; then
    echo "Removing existing directory at $SERVERLESS_MODELS"
    rm -rf "$SERVERLESS_MODELS"
fi

# Create directory structure with hard links (zero extra disk space)
echo "Creating model directories..."
MODEL_DIRS="checkpoints loras clip clip_vision configs controlnet embeddings upscale_models vae unet latent_upscale_models"

for dir in $MODEL_DIRS; do
    mkdir -p "$SERVERLESS_MODELS/$dir"
    SRC="$COMFYUI_MODELS/$dir"
    if [ -d "$SRC" ]; then
        # Hard link all files (no extra disk space)
        find "$SRC" -maxdepth 1 -type f -exec ln -f {} "$SERVERLESS_MODELS/$dir/" \; 2>/dev/null || true
        COUNT=$(find "$SERVERLESS_MODELS/$dir" -type f | wc -l)
        echo "  $dir: $COUNT files linked"
    else
        echo "  $dir: source not found, skipping"
    fi
done

echo ""
echo "=== Verification ==="
echo "Checkpoints:"
ls -lh "$SERVERLESS_MODELS/checkpoints/" 2>/dev/null | grep -v "^total" | grep -v "put_" || echo "  (none)"
echo ""
echo "LoRAs:"
ls -lh "$SERVERLESS_MODELS/loras/" 2>/dev/null | grep -v "^total" | grep -v "put_" || echo "  (none)"
echo ""
echo "Latent Upscale Models:"
ls -lh "$SERVERLESS_MODELS/latent_upscale_models/" 2>/dev/null | grep -v "^total" | grep -v "put_" || echo "  (none)"
echo ""
echo "=== Done! Serverless workers will find models at /runpod-volume/models/ ==="
