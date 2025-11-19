# Ollama Model Fetcher - Usage Guide
# Last Updated: 11/7/2025 5:00:00 PM CST

## Overview

The `ollama_model_fetcher.py` script fetches current model information from ollama.com and allows you to:
- View up-to-date model specifications (context windows, sizes, capabilities)
- Compare multiple models side-by-side
- Interactively select and download models

## Installation

### 1. Install Python Dependencies

```bash
# Create a virtual environment (recommended)
cd /opt/divtools/scripts
python3 -m venv venvs/ollama_fetcher
source venvs/ollama_fetcher/bin/activate

# Install required packages
pip install requests beautifulsoup4 rich
```

### 2. Make Script Executable

```bash
chmod +x /opt/divtools/scripts/ollama_model_fetcher.py
```

## Usage

### Basic Usage - View Model Information

```bash
# View models from config file
./ollama_model_fetcher.py --config models_of_interest.txt

# View specific models
./ollama_model_fetcher.py --models qwen2.5-vl deepseek-r1 llama3.1

# Output as JSON
./ollama_model_fetcher.py --models qwen2.5-vl --format json
```

### Create a Config File

```bash
# Create a sample config file
./ollama_model_fetcher.py --create-config

# Edit it to add your models of interest
nano models_of_interest.txt
```

### Interactive Download Mode

```bash
# View models and interactively select which to download
./ollama_model_fetcher.py --config models_of_interest.txt --download

# Specify a different Ollama container name
./ollama_model_fetcher.py --models qwen2.5-vl --download --container my-ollama
```

## Command-Line Options

| Option | Short | Description |
|--------|-------|-------------|
| `--config FILE` | `-c` | Config file with model names (default: models_of_interest.txt) |
| `--models MODEL [MODEL...]` | `-m` | Space-separated list of models to fetch |
| `--download` | `-d` | Enable interactive download mode |
| `--format FORMAT` | `-f` | Output format: `table` (default) or `json` |
| `--container NAME` | | Ollama container name (default: `ollama`) |
| `--create-config` | | Create a sample config file |

## Config File Format

The config file is a simple text file with one model name per line:

```
# Comments start with #
# Use base model names without version tags

qwen2.5-vl
deepseek-r1
llama3.1
mistral
```

## Examples

### Example 1: Check Models Before Downloading

```bash
cd /opt/divtools/docker/sites/s01-7692nh/gpu1-75/ollama

# View info about your models of interest
/opt/divtools/scripts/ollama_model_fetcher.py --config models_of_interest.txt
```

### Example 2: Compare Specific Models

```bash
# Compare vision models
/opt/divtools/scripts/ollama_model_fetcher.py \
    --models qwen2.5-vl llama3.2-vision llava
```

### Example 3: Interactive Download

```bash
# Fetch info and download selected models
/opt/divtools/scripts/ollama_model_fetcher.py \
    --config models_of_interest.txt \
    --download
```

### Example 4: Export to JSON for Processing

```bash
# Get JSON output for further processing
/opt/divtools/scripts/ollama_model_fetcher.py \
    --models qwen2.5-vl deepseek-r1 \
    --format json > model_info.json
```

## Sample Output

### Table Format

```
┏━━━━━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━┓
┃ Model        ┃ Context   ┃ Variants        ┃ Capabilities ┃ Description     ┃
┡━━━━━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━━━━━━━━╇━━━━━━━━━━━━━━╇━━━━━━━━━━━━━━━━━┩
│ qwen2.5-vl   │ 128K      │ qwen2.5-vl:2b   │ Vision       │ Advanced vision │
│              │ tokens    │ qwen2.5-vl:7b   │              │ and language    │
│              │           │ qwen2.5-vl:32b  │              │ model           │
├──────────────┼───────────┼─────────────────┼──────────────┼─────────────────┤
│ deepseek-r1  │ 64K       │ deepseek-r1:7b  │ Code         │ Reasoning model │
│              │ tokens    │ deepseek-r1:8b  │              │ with CoT        │
└──────────────┴───────────┴─────────────────┴──────────────┴─────────────────┘
```

## Troubleshooting

### Error: Module Not Found

```bash
# Make sure you're in the virtual environment
source /opt/divtools/scripts/venvs/ollama_fetcher/bin/activate

# Reinstall dependencies
pip install requests beautifulsoup4 rich
```

### Error: Cannot Connect to Ollama

Make sure your Ollama container is running:

```bash
docker ps | grep ollama
```

### Rate Limiting

If you get rate-limited by ollama.com, add delays between requests by modifying the script or running it less frequently.

## Tips

1. **Keep Config File Updated**: Maintain your `models_of_interest.txt` with models you're evaluating
2. **Check Before Download**: Always view model info before downloading to verify sizes
3. **Use Virtual Environment**: Keeps Python dependencies isolated
4. **Version Control**: Track changes to your model selections over time

## Integration with Divtools

You can add this to your workflow:

```bash
# Add alias to .bash_aliases
alias ollama-fetch='/opt/divtools/scripts/venvs/ollama_fetcher/bin/python /opt/divtools/scripts/ollama_model_fetcher.py'

# Then use it easily:
ollama-fetch --config ~/models.txt
ollama-fetch --models qwen2.5-vl --download
```

## Future Enhancements

Potential improvements:
- [ ] Cache model information locally
- [ ] Compare model benchmarks
- [ ] Show VRAM requirements per model
- [ ] Batch download mode
- [ ] Export comparison reports
