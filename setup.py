"""
Setup script for runpod-comfyui-cloud
This is a minimal setup.py for compatibility with various tools.
"""

from setuptools import setup, find_packages

# Read the README file
with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

setup(
    name="runpod-comfyui-cloud",
    version="2.0.0",
    author="Sebastian Hein",
    author_email="contact@ecomtree.com",
    description="Production-ready ComfyUI Docker image optimized for NVIDIA H200 and RTX 5090 GPUs",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/EcomTree/runpod-comfyui-cloud",
    packages=find_packages(),
    classifiers=[
        "Development Status :: 5 - Production/Stable",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.10",
        "Topic :: Scientific/Engineering :: Artificial Intelligence",
    ],
    python_requires=">=3.10",
    install_requires=[
        "requests>=2.31.0",
    ],
    extras_require={
        "dev": [
            "pytest>=7.4.0",
            "black>=23.7.0",
            "flake8>=6.1.0",
        ],
    },
)

