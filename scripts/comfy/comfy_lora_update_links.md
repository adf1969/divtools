Lora Update Links Script Notes:

[X] Update: 2/7/2026 10:13:48 AM:
* Add a new arg to the script named:
  * -add-path-prefix -app and --add-path-prefix <optional-depth>
  * This arg does the following
  * Adds the path from the root of the loras SOURCE_DIR to a prefix to the link it creates
  * If an optional # depth is provided, only adds that many prefixes max, starting at 0 (add no prefix).
  * If the optional # depth is NEGATIVE, it starts from the BOTTOM and goes up

Here are some examples:
* SOURCE_DIR = /opt/foo/loras
  * Depth: not specified
  * Full Path to Lora: /opt/foo/loras/lfolder/lora-file.safetensors
  * Link name produced: lfolder_lora-file.safetensors
* SOURCE_DIR = /opt/foo/loras
  * Depth: not specified
  * Full Path to Lora: /opt/foo/loras/lcat/lfolder/lora-file.safetensors
  * Link name produced: lcat_lfolder_lora-file.safetensors
* SOURCE_DIR = /opt/foo/loras
  * Depth: 1
  * Full Path to Lora: /opt/foo/loras/lcat/lfolder/lora-file.safetensors
  * Link name produced: lcat_lora-file.safetensors
* SOURCE_DIR = /opt/foo/loras
  * Depth: -1
  * Full Path to Lora: /opt/foo/loras/lcat/lfolder/lora-file.safetensors
  * Link name produced: lfolder_lora-file.safetensors
* SOURCE_DIR = /opt/foo/loras
  * Depth: -1
  * Full Path to Lora: /opt/foo/loras/lcat/lsub/lfolder/lora-file.safetensors
  * Link name produced: lfolder_lora-file.safetensors 
* SOURCE_DIR = /opt/foo/loras
  * Depth: 2
  * Full Path to Lora: /opt/foo/loras/lcat/lsub/lfolder/lora-file.safetensors
  * Link name produced: lcat_lsub_lora-file.safetensors  
* SOURCE_DIR = /opt/foo/loras/lcat
  * Depth: not specified
  * Full Path to Lora: /opt/foo/loras/lcat/lfolder/lora-file.safetensors
  * Link name produced: lfolder_lora-file.safetensors

[X] Update: 2/7/2026 10:28:18 AM:
That works great.
I need you to add an optional prefix that is ALWAYS added to links.
The arg should be called:
--link-prefix <prefix-name>
It would be added to EVERY link that is created
Example:
* SOURCE_DIR = /opt/foo/loras/lcat
  * Depth: not specified
  * PrefixName: lc
  * Full Path to Lora: /opt/foo/loras/lcat/lfolder/lora-file.safetensors
  * Link name produced: lc_lfolder_lora-file.safetensors
* SOURCE_DIR = /opt/foo/loras
  * Depth: -1
  * PrefixName: lc
  * Full Path to Lora: /opt/foo/loras/lcat/lsub/lfolder/lora-file.safetensors
  * Link name produced: lc_lfolder_lora-file.safetensors
 


