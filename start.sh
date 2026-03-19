#!/usr/bin/env bash
# Serverless start.sh — starts ComfyUI + RunPod handler
# Based on comfyui-base's start.sh but stripped for serverless use

set -e

# ---- Paths ----
COMFYUI_DIR="/runpod-volume/runpod-slim/ComfyUI"
BAKED_DIR="/opt/comfyui-baked/ComfyUI"

# ---- Debug: show environment ----
echo "worker: ============ DEBUG INFO ============"
echo "worker: Python: $(python3 --version)"
echo "worker: PyTorch: $(python3 -c 'import torch; print(torch.__version__)' 2>/dev/null || echo 'not found')"
echo "worker: CUDA available: $(python3 -c 'import torch; print(torch.cuda.is_available())' 2>/dev/null || echo 'unknown')"
echo "worker: CUDA version (torch): $(python3 -c 'import torch; print(torch.version.cuda)' 2>/dev/null || echo 'unknown')"
echo "worker: Base image: $(cat /etc/runpod-image-tag 2>/dev/null || echo 'unknown')"
echo "worker: Volume mount: $(ls -la /runpod-volume/ 2>/dev/null | head -3 || echo 'not mounted')"
echo "worker: ======================================="

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
# IMPORTANT: Skip torch/torchvision/torchaudio — the image has cu130 for RTX 5090,
# but the volume's requirements.txt has cu128 which would downgrade it
if [ -f "$COMFYUI_DIR/requirements.txt" ]; then
    echo "worker: Volume requirements.txt contents (torch lines):"
    grep -i "^torch" "$COMFYUI_DIR/requirements.txt" || echo "  (no torch lines found)"
    echo "worker: Installing non-torch requirements from volume..."
    grep -v -i "^torch" "$COMFYUI_DIR/requirements.txt" | pip install -q -r /dev/stdin 2>&1 | tail -5
    echo "worker: PyTorch after install: $(python3 -c 'import torch; print(torch.__version__)' 2>/dev/null)"
fi

# ---- Install custom node requirements from volume ----
echo "worker: Installing custom node requirements..."
for req in "$COMFYUI_DIR"/custom_nodes/*/requirements.txt; do
    if [ -f "$req" ]; then
        node_name=$(basename "$(dirname "$req")")
        echo "worker:   $node_name"
        grep -v -i "^torch" "$req" | pip install -q -r /dev/stdin 2>&1 | tail -3
    fi
done

# ---- List custom nodes ----
echo "worker: Custom nodes on volume:"
ls -1 "$COMFYUI_DIR/custom_nodes/" 2>/dev/null || echo "  (none)"

# ---- Set ComfyUI-Manager to offline mode ----
MANAGER_CONFIG="$COMFYUI_DIR/user/default/ComfyUI-Manager/config.ini"
MANAGER_CONFIG2="$COMFYUI_DIR/user/__manager/config.ini"
for cfg in "$MANAGER_CONFIG" "$MANAGER_CONFIG2"; do
    if [ -f "$cfg" ]; then
        sed -i 's/network_mode = .*/network_mode = offline/' "$cfg" 2>/dev/null || true
        echo "worker: Set offline mode in $cfg"
    fi
done

# ---- Start ComfyUI ----
echo "worker: Starting ComfyUI from $COMFYUI_DIR"
echo "worker: Final PyTorch version: $(python3 -c 'import torch; print(torch.__version__)' 2>/dev/null)"
echo "worker: Final CUDA version: $(python3 -c 'import torch; print(torch.version.cuda)' 2>/dev/null)"
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
