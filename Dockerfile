# clean base image containing only comfyui, comfy-cli and comfyui-manager
FROM runpod/worker-comfyui:latest-base

# Install LTX Video custom node
RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/Lightricks/ComfyUI-LTXVideo.git && \
    cd ComfyUI-LTXVideo && \
    pip install -r requirements.txt || true

# Add latent_upscale_models to model search paths (not in default config)
COPY extra_model_paths.yaml /comfyui/extra_model_paths.yaml

# Override start.sh to create runtime symlink for comfyui-base volume layout
COPY start.sh /start.sh
RUN chmod +x /start.sh
