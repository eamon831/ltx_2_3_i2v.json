#!/usr/bin/env bash
# Serverless start.sh — starts ComfyUI + RunPod handler
# Based on comfyui-base's start.sh but stripped for serverless use

set -e

# ---- Paths ----
# comfyui-base stores ComfyUI on the network volume at this path
# On pods: /workspace/runpod-slim/ComfyUI
# On serverless: /runpod-volume/runpod-slim/ComfyUI
COMFYUI_DIR="/runpod-volume/runpod-slim/ComfyUI"
BAKED_DIR="/opt/comfyui-baked/ComfyUI"

# ---- Memory optimization ----
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)" || true
if [ -n "$TCMALLOC" ]; then
    export LD_PRELOAD="${TCMALLOC}"
fi

# ---- GPU pre-flight check ----
echo "worker: Checking GPU availability..."
if ! GPU_CHECK=$(python3 -c "
import torch
try:
    torch.cuda.init()
    name = torch.cuda.get_device_name(0)
    print(f'OK: {name}')
except Exception as e:
    print(f'FAIL: {e}')
    exit(1)
" 2>&1); then
    echo "worker: GPU not available: $GPU_CHECK"
    exit 1
fi
echo "worker: GPU available — $GPU_CHECK"

# ---- Locate ComfyUI ----
if [ -d "$COMFYUI_DIR" ]; then
    echo "worker: Using ComfyUI from network volume: $COMFYUI_DIR"
elif [ -d "$BAKED_DIR" ]; then
    echo "worker: Network volume ComfyUI not found, using baked: $BAKED_DIR"
    COMFYUI_DIR="$BAKED_DIR"
else
    echo "worker: ERROR — ComfyUI not found at $COMFYUI_DIR or $BAKED_DIR"
    exit 1
fi

# ---- Install ComfyUI dependencies from volume ----
# Volume's ComfyUI may need packages not in the base image (e.g. comfy_aimdo)
if [ -f "$COMFYUI_DIR/requirements.txt" ]; then
    echo "worker: Installing ComfyUI requirements from volume..."
    pip install -q -r "$COMFYUI_DIR/requirements.txt" 2>&1 | tail -5
fi

# ---- Install custom node dependencies from baked image ----
# The LTX Video node was installed into /opt/comfyui-baked at build time
# Symlink it into the volume's ComfyUI if not already there
if [ -d "/opt/comfyui-baked/ComfyUI/custom_nodes/ComfyUI-LTXVideo" ] && \
   [ ! -d "$COMFYUI_DIR/custom_nodes/ComfyUI-LTXVideo" ]; then
    echo "worker: Linking ComfyUI-LTXVideo custom node"
    ln -s /opt/comfyui-baked/ComfyUI/custom_nodes/ComfyUI-LTXVideo \
          "$COMFYUI_DIR/custom_nodes/ComfyUI-LTXVideo"
fi

# ---- Set ComfyUI-Manager to offline mode ----
MANAGER_CONFIG="$COMFYUI_DIR/user/default/ComfyUI-Manager/config.ini"
if [ -f "$MANAGER_CONFIG" ]; then
    sed -i 's/network_mode = .*/network_mode = offline/' "$MANAGER_CONFIG" 2>/dev/null || true
    echo "worker: ComfyUI-Manager set to offline mode"
fi

# ---- Start ComfyUI ----
echo "worker: Starting ComfyUI from $COMFYUI_DIR"
COMFY_PID_FILE="/tmp/comfyui.pid"

python3 -u "$COMFYUI_DIR/main.py" \
    --listen 0.0.0.0 \
    --port 8188 \
    --disable-auto-launch \
    --disable-metadata \
    --log-stdout &

echo $! > "$COMFY_PID_FILE"

# ---- Start RunPod Handler ----
echo "worker: Starting RunPod serverless handler"
python3 -u /handler.py
