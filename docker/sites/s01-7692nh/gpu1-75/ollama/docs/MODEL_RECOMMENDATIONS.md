# Ollama Model Recommendations for gpu1-75
# Last Updated: 11/7/2025 4:45:00 PM CST

## Hardware Specifications

### Current Setup - gpu1-75
- **GPU**: NVIDIA RTX 4000
- **VRAM**: 8GB
- **Use Cases**: 
  - Invoice OCR and text extraction
  - Log file analysis
  - Document analysis
  - General text processing

### Future Setup - Additional Server
- **GPU**: NVIDIA RTX 3060
- **VRAM**: 12GB
- **Planned**: Secondary Ollama instance

---

## 🎯 Recommended Models by Use Case

### 1. **Qwen2.5-VL** ⭐⭐⭐⭐⭐ (TOP CHOICE FOR VISION/OCR)

**Ollama Command:**
```bash
# For 8GB GPU (RTX 4000)
docker exec -it ollama ollama pull qwen2.5-vl:7b
docker exec -it ollama ollama pull qwen2.5-vl:2b  # Lighter alternative

# For 12GB GPU (RTX 3060) - Future
docker exec -it ollama ollama pull qwen2.5-vl:32b
```

**Specifications:**
- **Available Sizes**: 2B (~2.3GB), 7B (~5.5GB), 32B (~20GB), 72B (~45GB)
- **Context Window**: 32K tokens
- **Type**: Vision + Text (Multimodal)
- **License**: Apache 2.0

**Best For:**
- ✅ **Invoice OCR** - Superior text extraction from images
- ✅ **Document Understanding** - Tables, forms, structured data
- ✅ **Multi-language OCR** - Supports multiple languages
- ✅ **Handwriting Recognition** - Can read handwritten text
- ✅ **Chart/Graph Interpretation** - Understands visual data
- ✅ **Image + Text Analysis** - Combined reasoning

**Why Choose This:**
- Specifically designed for document processing
- Better OCR accuracy than llama3.2-vision for business documents
- Excellent at structured data extraction (critical for invoices)
- Handles complex layouts and tables efficiently

**Recommended for RTX 4000 (8GB):** `qwen2.5-vl:7b`

---

### 2. **DeepSeek-R1** ⭐⭐⭐⭐⭐ (TOP CHOICE FOR REASONING)

**Ollama Command:**
```bash
# For 8GB GPU (RTX 4000)
docker exec -it ollama ollama pull deepseek-r1:8b
docker exec -it ollama ollama pull deepseek-r1:7b  # Alternative

# For 12GB GPU (RTX 3060) - Future
docker exec -it ollama ollama pull deepseek-r1:14b
docker exec -it ollama ollama pull deepseek-r1:32b
```

**Specifications:**
- **Available Sizes**: 1.5B, 7B, 8B, 14B, 32B, 70B
- **Context Window**: 64K-128K tokens (varies by size)
- **Type**: Text-only
- **License**: MIT

**Best For:**
- ✅ **Log File Analysis** - Pattern detection and troubleshooting
- ✅ **Complex Reasoning** - Shows chain-of-thought process
- ✅ **Code Analysis** - Debugging and understanding scripts
- ✅ **Problem Solving** - Step-by-step reasoning
- ✅ **Document Analysis** - Deep understanding of text documents
- ✅ **System Troubleshooting** - Great for technical diagnostics

**Special Features:**
- **Chain-of-Thought Reasoning**: Shows its thinking process
- **Debugging-Friendly**: See exactly how it arrives at conclusions
- **Strong Logic**: Excellent at following complex instructions
- **Technical Knowledge**: Great for DevOps/SysAdmin tasks

**Why Choose This:**
- Perfect for analyzing server logs and finding patterns
- Shows reasoning steps (helpful for validating conclusions)
- Excellent at understanding technical documentation
- Strong at following multi-step instructions

**Recommended for RTX 4000 (8GB):** `deepseek-r1:8b`

---

### 3. **GPT-OSS (OpenAI)** ⭐⭐⭐⭐ (ENTERPRISE-GRADE REASONING)

**Ollama Command:**
```bash
# For 8GB GPU (RTX 4000) - Will NOT fit
# Minimum 16GB RAM required for 20B model

# For 12GB GPU (RTX 3060) - Will NOT fit
# Requires 16GB+ RAM for gpt-oss:20b

# For future upgrades with more VRAM:
docker exec -it ollama ollama pull gpt-oss:20b   # Requires 16GB+ RAM
docker exec -it ollama ollama pull gpt-oss:120b  # Requires 80GB GPU
```

**Specifications:**
- **Available Sizes**: 20B (~14GB), 120B (~65GB)
- **Context Window**: 128K tokens
- **Type**: Text-only
- **License**: Apache 2.0
- **Quantization**: MXFP4 format (4.25 bits per parameter)

**Best For:**
- ✅ **Agentic Tasks** - Function calling, tool use
- ✅ **Web Browsing Integration** - Built-in web search capability
- ✅ **Python Tool Calls** - Native code execution support
- ✅ **Structured Outputs** - JSON, XML, formatted data
- ✅ **Complex Reasoning** - Full chain-of-thought access
- ✅ **Commercial Use** - Permissive licensing

**Special Features:**
- **Native Function Calling**: Built-in tool integration
- **Web Search**: Optional web browsing capability
- **Configurable Reasoning**: Adjust effort (low/medium/high)
- **Fine-tunable**: Can be customized for specific use cases
- **OpenAI Quality**: State-of-the-art reasoning capabilities

**Why Choose This:**
- Enterprise-grade reasoning and reliability
- Excellent for complex, multi-step workflows
- Strong agentic capabilities (automation potential)
- Full access to reasoning process for debugging

**⚠️ Hardware Limitation:**
- **RTX 4000 (8GB)**: Cannot run - needs 16GB minimum
- **RTX 3060 (12GB)**: Cannot run - needs 16GB minimum
- **Future Consideration**: Excellent choice when upgrading hardware

---

### 4. **Llama3.1** ⭐⭐⭐⭐ (FAST GENERAL PURPOSE)

**Ollama Command:**
```bash
# For 8GB GPU (RTX 4000)
docker exec -it ollama ollama pull llama3.1:8b

# For 12GB GPU (RTX 3060) - Future
docker exec -it ollama ollama pull llama3.1:70b
```

**Specifications:**
- **Available Sizes**: 8B (~4.7GB), 70B (~40GB), 405B (~231GB)
- **Context Window**: 128K tokens
- **Type**: Text-only
- **License**: Llama 3.1 Community License

**Best For:**
- ✅ **Fast Responses** - Quick text generation
- ✅ **General Purpose** - Versatile for many tasks
- ✅ **Document Summarization** - Efficient text processing
- ✅ **Quick Analysis** - When speed matters
- ✅ **Backup Model** - Reliable fallback option

**Why Choose This:**
- Proven reliability and performance
- Fast inference speed
- Good balance of quality and speed
- Widely used and well-documented

**Recommended for RTX 4000 (8GB):** `llama3.1:8b`

---

### 5. **Llama3.2-Vision** ⭐⭐⭐ (VISION ALTERNATIVE)

**Ollama Command:**
```bash
# For 8GB GPU (RTX 4000)
docker exec -it ollama ollama pull llama3.2-vision:11b

# For 12GB GPU (RTX 3060) - Future
docker exec -it ollama ollama pull llama3.2-vision:90b
```

**Specifications:**
- **Available Sizes**: 11B (~7GB), 90B (~55GB)
- **Context Window**: 128K tokens
- **Type**: Vision + Text (Multimodal)
- **License**: Llama 3.2 Community License

**Best For:**
- ✅ **Image Analysis** - General image understanding
- ✅ **Visual Q&A** - Questions about images
- ✅ **Document OCR** - Text extraction (but not as good as Qwen for this)
- ✅ **Multi-purpose Vision** - Versatile vision tasks

**Why Choose This:**
- Meta's official multimodal model
- Good general-purpose vision capabilities
- Well-integrated with ecosystem

**Note:** While capable, **Qwen2.5-VL is superior for document/invoice OCR** specifically.

**Recommended for RTX 4000 (8GB):** `llama3.2-vision:11b` (if not using Qwen)

---

### 6. **Mistral** ⭐⭐⭐ (LIGHTWEIGHT FAST MODEL)

**Ollama Command:**
```bash
docker exec -it ollama ollama pull mistral:7b
```

**Specifications:**
- **Size**: 7B (~4.1GB)
- **Context Window**: 32K tokens
- **Type**: Text-only
- **License**: Apache 2.0

**Best For:**
- ✅ **Quick Tasks** - Fast responses
- ✅ **Resource-Efficient** - Low memory usage
- ✅ **Simple Queries** - Basic text processing
- ✅ **Testing** - Quick experimentation

**Why Choose This:**
- Very fast inference
- Low resource usage
- Good for simple, quick tasks

---

## 📊 Recommended Setup by GPU

### RTX 4000 (8GB) - Current Setup

**Primary Stack (Recommended):**
```bash
# Vision/OCR tasks
docker exec -it ollama ollama pull qwen2.5-vl:7b

# Reasoning/Log analysis
docker exec -it ollama ollama pull deepseek-r1:8b

# Fast general purpose
docker exec -it ollama ollama pull llama3.1:8b

# Lightweight backup
docker exec -it ollama ollama pull mistral:7b
```

**Total VRAM Usage:** ~20GB on disk, but only one model loaded at a time (~5-7GB in VRAM)

**Use Case Mapping:**
- **Invoice OCR** → `qwen2.5-vl:7b`
- **Log Analysis** → `deepseek-r1:8b`
- **Document Processing** → `qwen2.5-vl:7b`
- **General Chat** → `llama3.1:8b`
- **Quick Tasks** → `mistral:7b`

---

### RTX 3060 (12GB) - Future Setup

**Enhanced Stack (Future):**
```bash
# Vision/OCR tasks - larger model
docker exec -it ollama ollama pull qwen2.5-vl:32b

# Reasoning - larger model
docker exec -it ollama ollama pull deepseek-r1:14b

# High-quality text
docker exec -it ollama ollama pull llama3.1:70b  # May need careful memory management
```

**Note:** With 12GB, you can run larger models but still one at a time. Consider memory management for the 70B model.

---

## 🎯 Use Case Decision Matrix

| Task | Priority Model | Alternative | Why |
|------|----------------|-------------|-----|
| **Invoice OCR** | qwen2.5-vl:7b | llama3.2-vision:11b | Best text extraction accuracy |
| **Server Log Analysis** | deepseek-r1:8b | llama3.1:8b | Chain-of-thought reasoning |
| **Document Analysis (Text)** | deepseek-r1:8b | llama3.1:8b | Deep understanding |
| **Document Analysis (Image)** | qwen2.5-vl:7b | llama3.2-vision:11b | Vision + text understanding |
| **Quick Queries** | mistral:7b | llama3.1:8b | Speed |
| **Complex Problem Solving** | deepseek-r1:8b | N/A | Shows reasoning steps |
| **Code Analysis** | deepseek-r1:8b | llama3.1:8b | Technical knowledge |
| **General Chat** | llama3.1:8b | mistral:7b | Balanced performance |

---

## 💡 Model Selection Tips

### Memory Management
- **One model at a time**: Ollama loads one model into VRAM when in use
- **Auto-unload**: Models unload after inactivity (configurable)
- **Context length vs VRAM**: Longer conversations use more VRAM

### Performance Optimization
1. **Start with smaller models** - Test before pulling large models
2. **Use task-specific models** - Don't use vision models for text-only tasks
3. **Monitor VRAM usage** - Use `nvidia-smi` to check GPU memory
4. **Keep frequently used models** - Delete rarely used models to save disk space

### Quality vs Speed Trade-offs
- **Need speed?** → Use smaller models (7B-8B)
- **Need quality?** → Use larger models (14B+) if VRAM allows
- **Need both?** → Use appropriately-sized models for each task

---

## 🚀 Quick Start Commands

### Pull Recommended Stack
```bash
# Connect to gpu1-75
ssh gpu1-75

# Pull recommended models
docker exec -it ollama ollama pull qwen2.5-vl:7b
docker exec -it ollama ollama pull deepseek-r1:8b
docker exec -it ollama ollama pull llama3.1:8b
docker exec -it ollama ollama pull mistral:7b

# List installed models
docker exec -it ollama ollama list
```

### Check Model Info
```bash
# Show model details
docker exec -it ollama ollama show qwen2.5-vl:7b

# Check running models
docker exec -it ollama ollama ps
```

### Remove Models
```bash
# Remove a model to free disk space
docker exec -it ollama ollama rm model-name:tag
```

---

## 📚 Additional Resources

### Official Links
- **Ollama Library**: https://ollama.com/library
- **Qwen2.5-VL**: https://ollama.com/library/qwen2.5-vl
- **DeepSeek-R1**: https://ollama.com/library/deepseek-r1
- **GPT-OSS**: https://ollama.com/library/gpt-oss
- **Llama3.1**: https://ollama.com/library/llama3.1
- **Llama3.2-Vision**: https://ollama.com/library/llama3.2-vision

### Documentation
- **Ollama Docs**: https://docs.ollama.com/
- **OpenWebUI Docs**: https://docs.openwebui.com/

### Model Cards & Papers
- **Qwen**: https://qwenlm.github.io/
- **DeepSeek**: https://github.com/deepseek-ai/DeepSeek-R1
- **GPT-OSS**: https://openai.com/index/introducing-gpt-oss
- **Llama**: https://ai.meta.com/llama/

---

## 🔄 Version History

| Date | Change | Author |
|------|--------|--------|
| 11/7/2025 | Initial document creation | Copilot |

---

## 📝 Notes

- Models are stored in: `$DOCKERDATADIR/ollama/models` (`/opt/ollama/models`)
- Model disk usage can be significant - monitor available space
- For production use, consider dedicated models per use case
- Test models before deploying in critical workflows
- Keep this document updated as new models are released

---

**Current Ollama Configuration:**
- Host: gpu1-75 (10.1.1.75)
- Port: 11434
- OpenWebUI: http://10.1.1.75:3000
- GPU: NVIDIA RTX 4000 (8GB VRAM)
