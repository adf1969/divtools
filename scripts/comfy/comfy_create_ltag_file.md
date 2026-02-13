I have a folder full of ComfyUI Loras.
I would like to build a file that contains information to use in building <lora:file:str> tags along with some other information about each.
I would like you to write a simple bash script named:
    comfy_create_ltag_file.sh
in this same folder that has the following args:
-debug: output debug text to help trace issues
-test: do not write the output file, just simulate the run
-output_file: path to output file (default: ltag_file.txt) (if not file is given, outputs to stdout)
-path: path to search for loras (default: current folder)

With the args, it does the following:
1) looks for every *.safetensors file in the path and sub-folders.
2) If it finds a safetensor file, looks for any file with the same name and "json" extension. That file will contain json like this:
{
  "file_name": "BouncyWalk02_HighWan2_2-000048",
  "model_name": "BouncyWalk02_HighWan2_2-000048",
  "file_path": "/opt/ai_models/sd_models/loras/wan2.2/BouncyWalk/BouncyWalk02_HighWan2_2-000048.safetensors",
  "size": 306847504,
  "modified": 1769382855.456661,
  "sha256": "99a9f47fc16dd5ff20ca8016245e5e9b460db5ea76c441bcf7d33fc326252996",
  "base_model": "Unknown",
  "preview_url": "",
  "preview_nsfw_level": 0,
  "notes": "This lora is for bounce walk videos. It's quite good in the continuation of the original image.\n\nUsed I2V-14B-720P as base.\n\nSince ppl were asking about my training Workflow:\n\nI have used 7 videos with about 4 second length, with faces cut off. I have described what happens e.g.\n\nHere some captions:\n\nA brunette girl, is sitting on the bed of her bedroom and standing up, she is walking into the direction of the turning camera\n\nThen I used Musubi-Tuner with default parameters and trained about 32 epochs and then 16 epochs with larger training set, with my 4090 it was done in about 1h 35 min.\n",
  "from_civitai": true,
  "civitai": {
    "trainedWords": [
      "walking into the direction of the moving camera",
      "walking into the direction of the static camera",
      "her breasts are bouncing"
    ]
  },
  "tags": [],
  "modelDescription": "",
  "civitai_deleted": false,
  "favorite": false,
  "exclude": false,
  "db_checked": false,
  "metadata_source": null,
  "last_checked_at": 0,
  "usage_tips": "{\"strength\":1,\"strength_min\":0.9,\"strength_max\":1.1}"
}

It needs to pull out the following items from the file:
* trainedWords
* notes
* usage_tips.strength
* usage_tips.strength_min
* usage_tips.strength_max

At the top of the file it needs to have a header like this:
    The following is a list of lora tags that can be used when building prompts.
    Use the <lora> tags to indicate that lora.
    Use the strength indicated to specify the default strength.
    Review the Notes to see any special instructions about the lora and when they should be used.
    When adding Loras to a prompt, adjust the strength as needed based on your prompt and desired effect.
    Do not add more than 2 loras to a single prompt to avoid overloading the model.
    In most cases, adding 1 is best.


For every lora it finds, it needs to output the following to the output file:
# Folder Name (if they are in the current folder, just use .)
<lora:file:{recommended strength}>
{recommended strength} is: 
    strength: if no min/max specified
    "strength_min - strength_max" if they exist
    "strength_min - 1.0", if min < 1 and max not set.
    "1.0 - strength_max", if max > 1 and min not set.
    1.0: if no strength usage_tips exist

Trained Words: {comma separated trainedWords}
Notes: {notes from json file}
<blank line>

# Folder Name (proceed with next lora file)

