# clean base image containing only comfyui, comfy-cli and comfyui-manager
FROM runpod/worker-comfyui:5.5.1-base

# install custom nodes into comfyui
# No registry-verified custom nodes found.
# Unknown registry custom nodes were present but no aux_id provided, so they could not be resolved:
# - MarkdownNote (unknown_registry) - no aux_id; skipped
# - MarkdownNote (unknown_registry) - no aux_id; skipped

# download models into comfyui
# No models specified in workflow

# copy all input data (like images or videos) into comfyui (uncomment and adjust if needed)
# COPY input/ /comfyui/input/
