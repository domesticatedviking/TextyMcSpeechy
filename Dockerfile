# Use a more minimal base image with CUDA 11.8 support and Ubuntu 22.04
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04 AS base
ARG USERNAME=nonrootuser
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Set working directory
WORKDIR /app

# Install system dependencies, Python, Pip, and known working version of Piper without revision history to minimize container size.
RUN apt-get update && apt-get install -y \
    python3.10 python3.10-venv python3.10-dev \
    git espeak-ng tmux ffmpeg inotify-tools \
    build-essential && \
    git init piper && cd piper && git fetch --depth 1 https://github.com/rhasspy/piper.git a0f09cdf9155010a45c243bc8a4286b94f286ef4 && git checkout FETCH_HEAD &&\
    rm -rf /var/lib/apt/lists/* 

# Create virtual environment, install piper without deps, manually install piper deps with known working versions
WORKDIR /app/piper/src/python
RUN python3.10 -m venv .venv && \
    /app/piper/src/python/.venv/bin/pip install --upgrade pip==24.0 wheel setuptools && \
    /app/piper/src/python/.venv/bin/pip install build && \
    /app/piper/src/python/.venv/bin/pip install -e . && \
    /app/piper/src/python/.venv/bin/pip install --no-deps piper-tts && \ 
    /app/piper/src/python/.venv/bin/pip install cython==0.29.37 piper-phonemize==1.1.0 librosa==0.10.2.post1 numpy==1.23.5 onnxruntime>=1.20.1  torch==1.13.1 pytorch-lightning==1.7.7 torchmetrics==0.11.4 && \
    /app/piper/src/python/.venv/bin/python -m build && \
    bash /app/piper/src/python/build_monotonic_align.sh

#create non root user 
WORKDIR /
RUN groupadd --gid $USER_GID $USERNAME && useradd -m -s /bin/bash -u $USER_UID -g $USER_GID $USERNAME && \
chown -R $USER_UID:$USER_GID /home/$USERNAME && usermod --uid $USER_UID --gid $USER_GID $USERNAME 


# Set environment variables for CUDA and virtual environment
ENV PATH="/app/piper/src/python/.venv/bin:$PATH"
ENV CUDA_VISIBLE_DEVICES=0  

# Mount volume
VOLUME ["/app/tts_dojo"]

# Set default command to bash
CMD ["/bin/bash"]


