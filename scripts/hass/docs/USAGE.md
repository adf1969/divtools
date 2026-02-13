# Home Assistant Utility Usage Examples

## hass_util.py - Independent Utility

The `hass_util.py` script can be run independently to query Home Assistant data.

### List Areas
```bash
./hass_util.py --lsa
# or
./hass_util.py --ls-areas
```

### List Labels
```bash
./hass_util.py --lsl
# or
./hass_util.py --ls-labels
```

### List Both Areas and Labels
```bash
./hass_util.py
# (defaults to showing both)
```

### With Debug Output
```bash
./hass_util.py --debug
```

### Custom HA URL and Token
```bash
./hass_util.py --ha-url http://homeassistant.local:8123 --token YOUR_TOKEN
```

## gen_presence_sensors.py - Sensor Generation

### Exclude Areas by Label
```bash
./gen_presence_sensors.py --exclude-labels exclude_presence no_sensor
```

This will skip any areas that have the `exclude_presence` or `no_sensor` labels attached.

### Test Mode (View Output Without Changes)
```bash
./gen_presence_sensors.py --test
```

### Test Mode with Debug and Label Exclusion
```bash
./gen_presence_sensors.py --test --debug --exclude-labels exclude_presence
```

### Generate and Upload (Production)
```bash
./gen_presence_sensors.py
```

### Skip Upload (Generate Local File Only)
```bash
./gen_presence_sensors.py --skip-upload
```

## Import as Module

Both scripts can also be imported as Python modules:

```python
from hass_util import (
    fetch_areas_via_websocket,
    fetch_labels_via_websocket,
    get_ha_config,
    slugify,
)

# Get config
ha_url, token = get_ha_config()

# Fetch data
import asyncio
areas = asyncio.run(fetch_areas_via_websocket(ha_url, token, debug=True))
labels = asyncio.run(fetch_labels_via_websocket(ha_url, token, debug=True))

# Use slugify
area_slug = slugify("Living Room")  # "living_room"
```

## Environment Variables

Both scripts support environment variables via `.env.hass`:

```bash
HA_URL=http://10.1.1.215:8123
HA_TOKEN=your_long_lived_access_token_here
```

Command-line arguments override environment variables.
