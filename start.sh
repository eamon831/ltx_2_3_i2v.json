#!/usr/bin/env bash
# Serverless start.sh — optimized for fast cold start
set -e

COMFYUI_DIR="/runpod-volume/runpod-slim/ComfyUI"
BAKED_DIR="/opt/comfyui-baked/ComfyUI"

# ---- Single debug check (one python3 invocation instead of 6) ----
echo "worker: $(python3 -c "
import torch
print(f'PyTorch {torch.__version__} | CUDA {torch.version.cuda} | GPU: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"none\"}')" 2>/dev/null || echo 'PyTorch not found')"

# ---- Memory optimization ----
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)" || true
[ -n "$TCMALLOC" ] && export LD_PRELOAD="${TCMALLOC}"

# ---- Locate ComfyUI ----
if [ -d "$COMFYUI_DIR" ]; then
    echo "worker: ComfyUI from volume"
elif [ -d "$BAKED_DIR" ]; then
    echo "worker: ComfyUI from baked image"
    COMFYUI_DIR="$BAKED_DIR"
else
    echo "worker: ERROR — ComfyUI not found"
    exit 1
fi

# ---- Quick dependency check (most already installed at build time) ----
# Only installs NEW packages not in the image — takes <2s if everything is pre-installed
if [ -f "$COMFYUI_DIR/requirements.txt" ]; then
    grep -v -i "^torch" "$COMFYUI_DIR/requirements.txt" | \
        pip install -q --no-cache-dir -r /dev/stdin 2>/dev/null || true
fi

# Install custom node deps (fast if pre-installed in Dockerfile)
for req in "$COMFYUI_DIR"/custom_nodes/*/requirements.txt; do
    [ -f "$req" ] && grep -v -i "^torch" "$req" | \
        pip install -q --no-cache-dir -r /dev/stdin 2>/dev/null || true
done

# ---- Set ComfyUI-Manager to offline mode ----
for cfg in "$COMFYUI_DIR/user/default/ComfyUI-Manager/config.ini" \
           "$COMFYUI_DIR/user/__manager/config.ini"; do
    [ -f "$cfg" ] && sed -i 's/network_mode = .*/network_mode = offline/' "$cfg" 2>/dev/null || true
done

# ---- Start ComfyUI ----
echo "worker: Starting ComfyUI"
python3 -u "$COMFYUI_DIR/main.py" \
    --listen 0.0.0.0 \
    --port 8188 \
    --disable-auto-launch \
    --disable-metadata \
    --log-stdout &
echo $! > /tmp/comfyui.pid

# ---- Start RunPod Handler ----
echo "worker: Starting handler"
python3 -u /handler.py
