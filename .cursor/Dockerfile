# syntax=docker/dockerfile:1
# Background Agent Dockerfile for ComfyUI RunPod Development
# Based on the main RunPod environment but optimized for development agents

FROM runpod/pytorch:2.8.0-py3.11-cuda12.8.1-cudnn-devel-ubuntu22.04

# Image metadata
LABEL maintainer="Sebastian"
LABEL description="Development environment for ComfyUI RunPod project with Background Agents"

# Environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV WORKSPACE=/home/ubuntu

# Create non-root user (Best Practice for Background Agents)
RUN useradd -m -s /bin/bash ubuntu && \
    usermod -aG sudo ubuntu && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Install essential development tools
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y \
    git \
    wget \
    curl \
    unzip \
    python3-venv \
    python3-pip \
    build-essential \
    vim \
    nano \
    htop \
    tree \
    jq \
    rsync \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install Python development dependencies
RUN pip install --no-cache-dir \
    requests \
    pyyaml \
    tqdm \
    python-dotenv

# Set user and working directory (Best Practice for Background Agents)
USER ubuntu
WORKDIR /home/ubuntu

# Create common development directories
RUN mkdir -p /home/ubuntu/workspace \
    && mkdir -p /home/ubuntu/.local/bin

# Add local bin to PATH
ENV PATH="/home/ubuntu/.local/bin:$PATH"

# Set default shell
SHELL ["/bin/bash", "-c"]

# Keep container running for development
CMD ["tail", "-f", "/dev/null"]