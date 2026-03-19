# Use the SAME base image as our pod — zero path conflicts
FROM runpod/comfyui:latest-5090

# Install serverless handler dependencies
RUN pip install --no-cache-dir runpod requests websocket-client

# Install LTX Video custom node (into baked ComfyUI)
RUN cd /opt/comfyui-baked/ComfyUI/custom_nodes && \
    git clone https://github.com/Lightricks/ComfyUI-LTXVideo.git && \
    cd ComfyUI-LTXVideo && \
    pip install -r requirements.txt || true

# Copy serverless handler (from worker-comfyui, MIT licensed)
COPY handler.py /handler.py
COPY network_volume.py /network_volume.py

# Custom start.sh for serverless (ComfyUI + handler, no Jupyter/FileBrowser)
COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
# force rebuild 1773911164
