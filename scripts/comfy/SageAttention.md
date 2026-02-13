# SageAttention Installation – Full Log & Instructions  
**Machine:** gpu1-97  
**OS:** Ubuntu 24.04 LTS  
**GPU:** NVIDIA GeForce RTX 3090 (24 GB VRAM)  
**Driver:** 570.195.03 (CUDA runtime reports 12.8)  
**ComfyUI venv path:** /opt/divtools/scripts/venvs/comfy-env  
**Date of install:** January 27, 2026  
**Goal:** Install stable SageAttention (V1) for ~20–40% speedup on Wan 2.2 video generation workflows

## Summary of what worked
- Installed CUDA Toolkit 12.6 (not 12.8) → most stable for RTX 3090 / Ampere (sm_86)
- Made CUDA visible system-wide via `/etc/profile.d/cuda-12-6.sh`
- Built SageAttention from the `sageattention-1` branch (V1, Triton-based)
- V1 does **NOT** have `__version__` attribute → the AttributeError is normal and expected
- Installation succeeded: `import sageattention` works, package is in venv

## Commands Run – Full Sequence (cleaned & annotated)

### 1. Initial checks (CUDA not yet installed)
```bash
nvcc --version                  # → Command not found (expected)
nvidia-smi                      # → Driver 570.195.03, CUDA 12.8 runtime visible
2. Add NVIDIA CUDA repo & install CUDA Toolkit 12.6
Bashwget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt update
sudo apt install -y cuda-toolkit-12-6
nvcc --version                  # → Now shows release 12.6 (success)
ls -l /usr/local/cuda-12.6/     # → Confirm bin/ and lib64/ exist
3. System-wide CUDA environment (best practice)
Created file /etc/profile.d/cuda-12-6.sh with:
Bash# CUDA 12.6 environment variables (system-wide)
if [ -d "/usr/local/cuda-12.6/bin" ]; then
    export PATH="/usr/local/cuda-12.6/bin$$   {PATH:+:   $${PATH}}"
fi
if [ -d "/usr/local/cuda-12.6/lib64" ]; then
    export LD_LIBRARY_PATH="/usr/local/cuda-12.6/lib64$$   {LD_LIBRARY_PATH:+:   $${LD_LIBRARY_PATH}}"
fi
export CUDA_HOME="/usr/local/cuda-12.6"
Then:
Bashsource /etc/profile             # or log out/in
echo $PATH | grep cuda-12.6     # → Should show path
nvcc --version                  # → Works everywhere now
4. System build dependencies
Bashsudo apt install -y build-essential git python3-dev python3-pip python3-venv ninja-build cmake
sudo apt install -y python3.12-dev      # extra safety for headers
(Note: Earlier attempts with python3.10-dev / 3.11-dev failed – not available on 24.04)
5. Clone & build SageAttention (V1 – stable for Ampere)
Bashmkdir -p ~/src
cd ~/src
git clone https://github.com/thu-ml/SageAttention.git
cd SageAttention
git checkout sageattention-1            # V1 branch (Triton-based, reliable on 3090)
# Alternative: git checkout v1.0.6

export TORCH_CUDA_ARCH_LIST="8.6"       # Force Ampere compute capability

# Activate the correct comfy venv FIRST!
cd /opt/divtools/scripts/venvs/comfy-env
source bin/activate

# Back to SageAttention and install
cd ~/src/SageAttention
pip install --upgrade pip setuptools wheel packaging pybind11
pip install triton==3.0.0
pip install . --verbose --no-build-isolation
6. Verification
Bashpython -c "import sageattention; print(sageattention.__version__)"
# → AttributeError: module 'sageattention' has no attribute '__version__'
# This is NORMAL for V1 – no __version__ exists

python -c "import sageattention; print(dir(sageattention))"
# → Should list functions like ['sageattn', 'sageattn_varlen', ...] → success

pip show sageattention
# → Location: /opt/divtools/scripts/venvs/comfy-env/lib/python3.12/site-packages
Next Steps – Immediate Actions

Update comfy_run.sh
Add the flag --use-sage-attention to your launch line.Example:Bash# Before
python main.py --listen --port 8188 ...

# After
python main.py --use-sage-attention --listen --port 8188 ...Optional extras to test (one at a time):text--use-sage-attention --attention-split