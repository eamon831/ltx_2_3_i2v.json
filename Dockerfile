# clean base image containing only comfyui, comfy-cli and comfyui-manager
FROM runpod/worker-comfyui:5.8.3-base

# fix model paths — network volume uses comfyui-base layout
COPY extra_model_paths.yaml /comfyui/extra_model_paths.yaml

# install custom nodes
RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/Lightricks/ComfyUI-LTXVideo.git && \
    cd ComfyUI-LTXVideo && \
    pip install -r requirements.txt || true

# models are pre-loaded on the RunPod network volume at:
#   /runpod-volume/runpod-slim/ComfyUI/models/
