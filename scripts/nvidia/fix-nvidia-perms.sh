#!/bin/bash
# Fix NVIDIA device permissions to root:video with 660
chown root:video /dev/nvidia0 /dev/nvidiactl /dev/nvidia-uvm /dev/nvidia-uvm-tools /dev/nvidia-modeset /dev/nvidia-caps/* 2>/dev/null
chmod 660 /dev/nvidia0 /dev/nvidiactl /dev/nvidia-uvm /dev/nvidia-uvm-tools /dev/nvidia-modeset /dev/nvidia-caps/* 2>/dev/null
