#!/bin/bash
# Verify RunPod network volume is set up correctly for serverless
# Run on a CPU pod attached to the network volume
#
# Usage: bash setup_volume.sh

set -e

COMFYUI_MODELS="/workspace/runpod-slim/ComfyUI/models"

echo "=== RunPod Volume Verification ==="

# Check comfyui-base structure exists
if [ ! -d "$COMFYUI_MODELS" ]; then
    echo "ERROR: ComfyUI models not found at $COMFYUI_MODELS"
    echo "Make sure this volume was set up with comfyui-base"
    exit 1
fi
echo "OK: comfyui-base structure found"

# Clean up any previous manual symlinks/copies
if [ -e "/workspace/models" ]; then
    echo "WARNING: /workspace/models exists (from previous setup attempts)"
    echo "  The serverless worker creates its own symlink at runtime."
    echo "  Run: rm -rf /workspace/models"
fi

# Verify models
echo ""
echo "=== Models ==="
echo "Checkpoints:"
ls -lh "$COMFYUI_MODELS/checkpoints/"*.safetensors 2>/dev/null || echo "  (none)"
echo ""
echo "LoRAs:"
ls -lh "$COMFYUI_MODELS/loras/"*.safetensors 2>/dev/null || echo "  (none)"
echo ""
echo "Latent Upscale Models:"
ls -lh "$COMFYUI_MODELS/latent_upscale_models/"*.safetensors 2>/dev/null || echo "  (none)"
echo ""
echo "=== Done ==="
echo "Volume structure:"
echo "  Pod path:       /workspace/runpod-slim/ComfyUI/models/"
echo "  Serverless path: /runpod-volume/runpod-slim/ComfyUI/models/"
echo "  start.sh will symlink /runpod-volume/models -> above at runtime"
