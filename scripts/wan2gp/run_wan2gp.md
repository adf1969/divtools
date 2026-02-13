I would like a script I can use for running wan2gp using systemctl services.

I need you to build 2 scripts:
* install_wan2gp_service.sh
    This is the script that will install run_wan2gp.sh as the service.
    It should create the service file, that calls the /opt/divtools/scripts/wan2gp/run_wan2gp.sh script

* run_wan2gp.sh
    This is the script that is called by the service. 
    It should include what is needed to launch wan2gp as a service.
    It shoudl also include reading from teh local .env.wan2gp file
    That file can contain env vars that may be used for configuring wan2gp.
    It should also contain settings/args for specfying various alternative folders for loras and other models used by wan2gp

The folder where these scripts reside is:
* $DIVTOOLS/scripts/wan2gp

The folder that contains the executables for wan2gp is at:
/opt/wan2gp/Wan2GP
    This is the folder where I cloned the Wan2GP git repository


If you need insights into what has been done before the ./scripts/comfy/ folder contains:
* install_service.sh
* run_comfy.sh


[ ] Update: 2/7/2026 10:49:13 AM
The comfy_lora_update_links.sh has incorrect --lora-dir-* args.
Did you review the Code at GitHub to get the CLI Args?
The docs are OUT OF DATE.
If you review the GitHub repo, you can check this folder:
https://github.com/deepbeepmeep/Wan2GP/tree/6a5022fb247425bf78224628e9227c1eec1b355e/models
That includes ALL the models.
Then in EACH model folder, there is a <model_name>_handler.py file ex:
https://github.com/deepbeepmeep/Wan2GP/blob/6a5022fb247425bf78224628e9227c1eec1b355e/models/wan/wan_handler.py

That file then includes a register_lora_cli_args() function.
That's the KEY.
That function includes EVERY CLI Arg that is accepted for this model.
In there, you will see the --lora-dir-* arg that will be read for EACH model.
I think you got the ltx2 one correct, since it indicates it is:
--lora-dir-ltx2
But the wan ones, do NOT look right, they look like this:
```
def register_lora_cli_args(parser, lora_root):
        parser.add_argument(
            "--lora-dir-i2v",
            type=str,
            default=None,
            help=f"Path to a directory that contains Wan i2v Loras (default: {os.path.join(lora_root, 'wan_i2v')})"
        )
        parser.add_argument(
            "--lora-dir",
            type=str,
            default=None,
            help=f"Path to a directory that contains Wan t2v Loras (default: {os.path.join(lora_root, 'wan')})"
        )
        parser.add_argument(
            "--lora-dir-wan-1-3b",
            type=str,
            default=None,
            help=f"Path to a directory that contains Wan 1.3B Loras (default: {os.path.join(lora_root, 'wan_1.3B')})"
        )
        parser.add_argument(
            "--lora-dir-wan-5b",
            type=str,
            default=None,
            help=f"Path to a directory that contains Wan 5B Loras (default: {os.path.join(lora_root, 'wan_5B')})"
        )
        parser.add_argument(
            "--lora-dir-wan-i2v",
            type=str,
            default=None,
            help=f"Path to a directory that contains Wan i2v Loras (default: {os.path.join(lora_root, 'wan_i2v')})"
        )
```

As you can see, --lora-dir-wan-2-1 is NOT in that list.
It has entries like:
--lora-dir-wan-i2v
--lora-dir-wan-5B
And so on.

Those are the args that need to be specified, and there needs to be an associated ENV VAR that can be set for each one.

Update the script by reviewing the code, and ensuring that every arg exists and is correct to match the code.

[X] Update: 2/7/2026 11:32:46 AM
* Check EVERY ENV FOR LORA loading --lora-dir-* in the ENV file.
* ENSURE!!!! It is being READ AND PROCESSED and that SOMETHING is being done with it!
* If NOT, if it was DEPRECATED, MAKE A NOTE OF THAT IN THE .env.wan2gp FILE!


[ ] Update: 2/7/2026 12:12:02 PM:
* Things are working better now.
* I would like the following change made to the Output that appears currently like this (I stripped the timestamps)
 ┌─ LoRA Directories (Model-Specific) ─────────────────────────────────────────────┐
 │                                                                                 │
 │ ✗ Wan t2v (WAN2GP_LORA_DIR) - NOT SET                                        │
 │ ✗ Wan 5B (WAN2GP_LORA_DIR_WAN_5B) - NOT SET                                  │
 │ ✗ Wan 1.3B (WAN2GP_LORA_DIR_WAN_1_3B) - NOT SET                              │
 │ ✗ Wan i2v (WAN2GP_LORA_DIR_I2V) - NOT SET                                    │
 │ ✓ Wan i2v Alt (WAN2GP_LORA_DIR_WAN_I2V)                                      │
 │   → /opt/nfs_test/nsfw/sd_models/loras/links-wan2.2
 │ ✗ Hunyuan t2v (WAN2GP_LORA_DIR_HUNYUAN) - NOT SET                            │
 │ ✗ Hunyuan i2v (WAN2GP_LORA_DIR_HUNYUAN_I2V) - NOT SET                        │
 │ ✗ LTX Video (WAN2GP_LORA_DIR_LTXV) - NOT SET                                 │
 │ ✗ Flux (WAN2GP_LORA_DIR_FLUX) - NOT SET                                      │
 │ ✗ Flux2 (WAN2GP_LORA_DIR_FLUX2) - NOT SET                                    │
 │ ✓ LTX-2 (WAN2GP_LORA_DIR_LTX2)                                               │
 │   → /opt/nfs_test/nsfw/sd_models/loras/links-ltx
 │ ✗ Flux2 Klein 4B (WAN2GP_LORA_DIR_FLUX2_KLEIN_4B) - NOT SET                  │
 │ ✗ Flux2 Klein 9B (WAN2GP_LORA_DIR_FLUX2_KLEIN_9B) - NOT SET                  │
 │ ✓ Qwen (WAN2GP_LORA_DIR_QWEN)                                                │
 │   → /opt/nfs_test/nsfw/sd_models/loras/links-qwen
 │ ✓ Z-Image (WAN2GP_LORA_DIR_Z_IMAGE)                                          │
 │   → /opt/nfs_test/nsfw/sd_models/loras/links-zit
 │ ✗ TTS (WAN2GP_LORA_DIR_TTS) - NOT SET                                        │
 │                                                                                 │
 └─────────────────────────────────────────────────────────────────────────────────┘

Since the Docs obviously indicate that MANY of the various Lora files get loras from either the ROOT (--loras) or from other places as "defaults" THAT should be reflected in that list.

First, I want ALL of the Lora Dirs specifed in the Lora Directories box, NOT just the "override" ones.
It is confusing having SOME listed like this:
✓ Root LoRAs (--loras)
✓ Wan i2v Alt (--lora-dir-wan-i2v)

And then them ALSO displayed below. That's not good UI.

At the top of the Lora Directories box, if there is a Lora Default specified, it should be indicated like this:
│ ✓ Lora Default (WAN2GP_LORAS_ROOT)                                        │
│   → /opt/nfs_test/nsfw/sd_models/loras/links
Output that in green if you can.

And EVERY other Lora File that you have listed under "Configuring Loras Directories" should be there AS WELL.
It is fine to have the "Configuring Lora Directories" section, those show in a nice row WHAT
--lora* command line args are added, but they don't show what that result will be.
Also, if you are going to indiate that there is a --loras command line, WHY NOT SPECIFY WHAT IT IS?
The output shoudl look like this:
✓ Root LoRAs (--loras) → /opt/nfs_test/nsfw/sd_models/loras/links
The others should reflect similar formatting.

In addition, if there is NOT an override specified, the entry should indicate WHERE it is pulling
the values from.

For example,:
Flux 2 Klein, is NOT set, so it should indicate it is coming from the DEFAULT location (the location specified by --loras)
It should say something like this:
 │ ✗ Flux2 (WAN2GP_LORA_DIR_FLUX2) - Using lora-default                                    │

And Wan t2v is NOT specified, but I DID specify:
WAN2GP_LORA_DIR
Which means THAT will be used for ALL of the Wan* entries, so THAT should be specified.
Also, I do NOT like this env var:
WAN2GP_LORA_DIR

That does NOT fit with the other ENV Vars.
I realize the Devs just over-loaded --lora-dir for WAN but we don't have to repeat that mistake.
Change that ENV Var so it FITS with the other vars.
It should be renamed to:
WAN2GP_LORA_WAN_DEFAULT
That makes MORE sense and indicates WHAT that var does.
The fact it sets --lora-dir isn't really an issue.

[X] Update: 2/7/2026 01:50:22 PM:
Implemented all requested changes:
* Renamed WAN2GP_LORA_DIR → WAN2GP_LORA_WAN_DEFAULT for clarity
* Updated .env.wan2gp to use the new variable name
* Updated run_wan2gp.sh to initialize and use new variable in CLI argument
* Improved LoRA Directories display:
  - Root LoRAs (--loras) shown at TOP with actual path
  - All model-specific LoRA dirs displayed with full context
  - Explicit paths show ✓ with path value
  - Unset entries show ○ with "Using LoRA Root Default" + path
  - Clear visual hierarchy showing sources of each LoRA directory
* Tested with -test flag confirming correct CLI output generated

Implemented: 2/7/2026 01:50:22 PM CST

