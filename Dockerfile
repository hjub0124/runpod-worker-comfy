# Stage 1: Base image with dependencies
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04 as base

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PIP_PREFER_BINARY=1
ENV CMAKE_BUILD_PARALLEL_LEVEL=8

# Install base system tools
RUN apt-get update && apt-get install -y \
    python3.10 python3-pip git wget curl unzip libgl1 \
    && ln -sf /usr/bin/python3.10 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install comfy-cli
RUN pip install comfy-cli

# Install ComfyUI in /comfyui
RUN comfy --workspace /comfyui install --cuda-version 11.8 --nvidia

# Add HiDiffusion custom nodes (as zip to avoid auth issues)
RUN mkdir -p /comfyui/custom_nodes/ComfyUI-HiDiffusionNodes && \
    curl -L https://github.com/comfyanonymous/ComfyUI-HiDiffusionNodes/archive/refs/heads/main.zip -o /tmp/hidiff.zip && \
    unzip /tmp/hidiff.zip -d /tmp && \
    mv /tmp/ComfyUI-HiDiffusionNodes-main/* /comfyui/custom_nodes/ComfyUI-HiDiffusionNodes/ && \
    rm -rf /tmp/hidiff.zip /tmp/ComfyUI-HiDiffusionNodes-main

# Set workdir to comfy
WORKDIR /comfyui

# Optional: expose port for local test
EXPOSE 8188

# Install RunPod + utilities
RUN pip install runpod requests

# Add startup scripts
COPY src/start.sh /start.sh
COPY src/restore_snapshot.sh /restore_snapshot.sh
COPY src/rp_handler.py test_input.json ./
COPY extra_model_paths.yaml ./

RUN chmod +x /start.sh /restore_snapshot.sh

# Copy snapshot (optional for restoring UI/workflow config)
COPY *snapshot*.json ./

# Restore snapshot to register custom nodes
RUN /restore_snapshot.sh

# Start script
CMD ["/start.sh"]
