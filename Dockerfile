# Use the SAME base image as our pod — zero path conflicts
FROM runpod/comfyui:1.2.5-5090

# Force cu130 PyTorch for RTX 5090 (sm_120)
RUN pip install --no-cache-dir --force-reinstall \
    torch==2.10.0 torchvision==0.25.0 torchaudio==2.10.0 \
    --index-url https://download.pytorch.org/whl/cu130

# Pre-install ALL known dependencies at build time (eliminates runtime pip install)
# ComfyUI requirements (minus torch)
RUN pip install --no-cache-dir \
    comfyui-frontend-package comfyui-workflow-templates comfyui-embedded-docs \
    torchsde numpy einops transformers tokenizers sentencepiece \
    safetensors aiohttp yarl pyyaml Pillow scipy tqdm psutil \
    alembic SQLAlchemy av comfy-kitchen comfy-aimdo requests \
    kornia spandrel pydantic pydantic-settings

# Pre-install ComfyUI-LTXVideo dependencies
RUN pip install --no-cache-dir \
    sentencepiece protobuf accelerate

# Install serverless handler dependencies
RUN pip install --no-cache-dir runpod requests websocket-client

# Copy serverless handler (from worker-comfyui, MIT licensed)
COPY handler.py /handler.py
COPY network_volume.py /network_volume.py

# Custom start.sh for serverless (ComfyUI + handler, no Jupyter/FileBrowser)
COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
