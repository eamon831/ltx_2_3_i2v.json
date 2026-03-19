# Use the SAME base image as our pod — zero path conflicts
FROM runpod/comfyui:1.2.5-5090

# Force cu130 PyTorch for RTX 5090 (sm_120) — same approach as comfyui-base cuda13 target
# RunPod's builder caches the base layer with cu128, so we explicitly install cu130
RUN pip install --no-cache-dir \
    torch==2.10.0 torchvision==0.25.0 torchaudio==2.10.0 \
    --index-url https://download.pytorch.org/whl/cu130

# Install serverless handler dependencies
RUN pip install --no-cache-dir runpod requests websocket-client

# Copy serverless handler (from worker-comfyui, MIT licensed)
COPY handler.py /handler.py
COPY network_volume.py /network_volume.py

# Custom start.sh for serverless (ComfyUI + handler, no Jupyter/FileBrowser)
COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
