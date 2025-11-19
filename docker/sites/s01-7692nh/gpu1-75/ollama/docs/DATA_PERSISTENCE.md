# Ollama Data Persistence Guide
# Last Updated: 11/7/2025 5:45:00 PM CST

## Volume Configuration

Ollama is configured with **persistent storage** to ensure models survive restarts and reboots.

### Volume Mounts

```yaml
volumes:
  - ${OLLAMA_MODELS_DIR}:/root/.ollama          # Models storage
  - ${DOCKERDATADIR}/ollama/config:/root/.config # Configuration
```

Where:
- `OLLAMA_MODELS_DIR` = `/opt/ollama/models`
- `DOCKERDATADIR` = `/opt`

## Data Locations

| Data Type | Container Path | Host Path | Purpose |
|-----------|---------------|-----------|---------|
| **Models** | `/root/.ollama` | `/opt/ollama/models` | Downloaded AI models |
| **Config** | `/root/.config` | `/opt/ollama/config` | Ollama configuration |

## Ensuring Data Persistence

### 1. Before Downloading Models

Run the verification script to ensure everything is configured correctly:

```bash
/home/divix/divtools/scripts/ollama/verify_ollama_setup.sh
```

This checks:
- ✓ Container is running
- ✓ Volumes are mounted correctly
- ✓ Directory exists and is writable
- ✓ Disk space is available

### 2. Download Models

Models can be downloaded via:

**Option A: OpenWebUI Interface**
- Navigate to Settings → Admin Panel → Models
- Enter model name (e.g., `qwen2.5-vl:7b`)
- Click "Pull Model"

**Option B: Command Line**
```bash
docker exec -it ollama ollama pull qwen2.5-vl:7b
docker exec -it ollama ollama pull deepseek-r1:8b
docker exec -it ollama ollama pull llama3.1:8b
```

### 3. Verify Models Persisted

After downloading, verify models are saved to the host:

```bash
# Check models in container
docker exec ollama ollama list

# Check files on host
sudo ls -lh /opt/ollama/models/manifests/
sudo ls -lh /opt/ollama/models/blobs/

# Check disk usage
sudo du -sh /opt/ollama/models/
```

### 4. After Reboot/Restart

Models should still be available:

```bash
# Restart containers
dcdown --profile ollama
dcup --profile ollama

# Verify models are still there
docker exec ollama ollama list
```

## What Went Wrong Before?

**The Issue:** Models downloaded before the volume was properly configured were stored in the container's **ephemeral storage** (inside the container, not on the host). When the container was removed/recreated, that data was lost.

**The Fix:** The volume mount is now correctly configured, so all future model downloads will be saved to `/opt/ollama/models` on the host and will persist across:
- Container restarts
- Container recreation
- System reboots
- Docker upgrades

## Storage Requirements

Model sizes vary significantly:

| Model | Size | VRAM | Recommended For |
|-------|------|------|----------------|
| qwen2.5-vl:7b | ~5.5GB | 8GB | Document OCR |
| deepseek-r1:8b | ~4.9GB | 8GB | Log analysis |
| llama3.1:8b | ~4.7GB | 8GB | General purpose |
| mistral:7b | ~4.1GB | 8GB | Fast queries |
| qwen2.5-vl:32b | ~20GB | 16GB+ | Advanced OCR |
| deepseek-r1:14b | ~9GB | 12GB+ | Better reasoning |

**Recommendation:** Keep at least **50GB free** on `/opt` for comfortable model storage.

Current available space:
```bash
df -h /opt
```

## Backup Strategy

Since models are large downloads, consider backing up the models directory:

```bash
# Backup models (as root)
sudo tar -czf /backup/ollama-models-$(date +%Y%m%d).tar.gz /opt/ollama/models/

# Restore models (as root)
sudo tar -xzf /backup/ollama-models-YYYYMMDD.tar.gz -C /
```

Or use syncthing/rsync to sync to another server.

## Troubleshooting

### Models Not Appearing After Download

1. **Check if download completed:**
   ```bash
   docker logs ollama --tail 100
   ```

2. **Verify models directory:**
   ```bash
   sudo ls -lR /opt/ollama/models/
   ```

3. **Check container can write:**
   ```bash
   docker exec ollama touch /root/.ollama/.test
   docker exec ollama ls -l /root/.ollama/.test
   docker exec ollama rm /root/.ollama/.test
   ```

4. **Restart OpenWebUI** (it caches model list):
   ```bash
   docker restart openwebui
   ```

### Container Shows "unhealthy"

The healthcheck queries the Ollama API. If unhealthy:

```bash
# Check API directly
curl http://localhost:11434/api/tags

# Check logs
docker logs ollama --tail 50

# Restart if needed
docker restart ollama
```

### Out of Disk Space

```bash
# Check disk usage
df -h /opt
sudo du -sh /opt/ollama/models/*

# Remove unused models
docker exec ollama ollama rm model-name:tag

# List all models
docker exec ollama ollama list
```

## Maintenance Commands

```bash
# List all models
docker exec ollama ollama list

# Show model details
docker exec ollama ollama show model-name:tag

# Remove a model
docker exec ollama ollama rm model-name:tag

# Check running models
docker exec ollama ollama ps

# View logs
docker logs ollama --tail 100 -f

# Container stats
docker stats ollama --no-stream

# Disk usage of models
sudo du -sh /opt/ollama/models/
```

## Verification Checklist

Before downloading large models, verify:

- [ ] Run `/home/divix/divtools/scripts/ollama/verify_ollama_setup.sh`
- [ ] Check available disk space: `df -h /opt`
- [ ] Verify Ollama container is healthy: `docker ps`
- [ ] Test API is responding: `curl http://localhost:11434/api/tags`
- [ ] Verify volume mount: `docker inspect ollama | grep -A 5 Mounts`

After downloading models:

- [ ] Verify model appears: `docker exec ollama ollama list`
- [ ] Check files on host: `sudo ls -lh /opt/ollama/models/blobs/`
- [ ] Restart container: `docker restart ollama`
- [ ] Verify model still appears: `docker exec ollama ollama list`
- [ ] Check OpenWebUI can see it: Login to http://10.1.1.75:3000

## Support

If models are still not persisting after following this guide:

1. Check compose file: `/home/divix/divtools/docker/sites/s01-7692nh/gpu1-75/ollama/dci-ollama.yml`
2. Check env variables: `/home/divix/divtools/docker/sites/s01-7692nh/gpu1-75/.env.gpu1-75`
3. Check Docker logs: `docker logs ollama --tail 100`
4. Verify mount points: `docker inspect ollama --format '{{json .Mounts}}' | python3 -m json.tool`
