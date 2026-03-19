# clean base image containing only comfyui, comfy-cli and comfyui-manager
FROM runpod/worker-comfyui:5.5.1-base

# update ComfyUI to latest (base image has v0.3.68 which is too old for LTX 2.3)
RUN cd /comfyui && \
    git pull origin master

# install custom nodes
RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/Lightricks/ComfyUI-LTXVideo.git && \
    cd ComfyUI-LTXVideo && \
    pip install -r requirements.txt || true

# models are pre-loaded on the RunPod network volume — no download needed
# Expected paths on network volume:
#   checkpoints/ltx-2.3-22b-dev-fp8.safetensors
#   loras/ltx-2.3-22b-distilled-lora-384.safetensors
#   loras/gemma-3-12b-it-abliterated_lora_rank64_bf16.safetensors
#   latent_upscale_models/ltx-2.3-spatial-upscaler-x2-1.0.safetensors

# copy all input data (like images or videos) into comfyui (uncomment and adjust if needed)
# COPY input/ /comfyui/input/
