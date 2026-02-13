## Initial Prompt Information
I would like you to create a set of docs for Wan2GP to explain how various features work.
I don't need full docs, but I do need some to cover certain models and options.

Assume that the current version is 10.70.
The Docs for Wan2GP can be found here:
* https://github.com/deepbeepmeep/Wan2GP/tree/main/docs
The Source Code can be found here:
* https://github.com/deepbeepmeep/Wan2GP/tree/main
When answer questions, do NOT rely on the Docs.
ALWAYS check the Source Code to confirm any area of functionality.

Create a Folder under docs called: "models", this will contain model-type doc files.
Create a Folder under docs called: "general", this will contain general UI related doc files.
Create Folders under the "models" folder that will contain any sub-model files.

For each Model with questions, create a file named: <ModelName>-<Sub-Model>.md
Example:
* Wan2.2-ImageEdit-14B.md
* Wan2.2-VACE-14B

In these files, you will put the answers to questions for each Model/Sub-Model with questions below.
When creating one of those files, always add at the top of the file the following:
* Heading with Model/Sub-Model
* General description of the Model/Sub-Model, provide a summary for the sub-model. Explain in general how it would be used and what they are best for.
* The Date of Release of the Model/Sub-Model and if there are other related models.
* A General count of Loras that exist for this Model, in the following categories:
  * Char, Style, Camera/Util


For each Model where I have question, I will make a list of questions/inquiries each marked with [ ] <question>
For each one, add that answer to the assocaited WAN2GP-<ModelName>.md file.
Mark the [X] question as X completed.
Add a "date" stamp for when you answered it, after the [X] <question> line, like this:
[X] <question>
* Answered: 2/8/2026 4:00:44 PM

If the item pertains to Wan2GP in general, put it in the:
WAN2GP-General.md file.

## Prompting Guide Organization

**As of 2/8/2026:** Comprehensive Prompting Guides for models are now maintained in separate dedicated files with the naming convention: `<ModelName>-<SubModel>-PromptGuide.md`

These standalone guide files:
- Contain condensed, LLM-friendly prompting instructions
- Are designed to be fed to LLMs for programmatic prompt generation  
- Include quick reference templates, key practices, and examples
- Have settings recommendations and reference tables
- Remove duplicate content from main model documentation

The main model documentation files now contain a brief reference to the dedicated guide file with a link.

**Examples:**
- [Wan2.2-SVI-Pro-14B-PromptGuide.md](models/Wan2.2/Wan2.2-SVI-Pro-14B-PromptGuide.md)
- [Qwen-ImageEdit-20B-PromptGuide.md](models/Qwen/Qwen-ImageEdit-20B-PromptGuide.md)

**Going Forward:** When creating or updating prompting guides for any model, create/update the separate `*-PromptGuide.md` file and add a reference note in the main model documentation file instead of including the full guide inline.

Questions I have about each model.

## General:
[X] On the Advanced > Misc tab, there is an "Output Filename" field, it has options like this:
Customize the Output Filename using Settings Values (date, seed, resolution, num_inference_steps, prompt, flow_shift, video_length, guidance_scale). For Instance:
"{date(YYYY-MM-DD_HH-mm-ss)}{seed}{prompt(50)}, {num_inference_steps}"

What other options exist?
Does it support subdirs? Or are "/" auto-removed and replaced with spaces?
Provide an entire list of the possible replacmenet settings that can be used.
When producing more than 1 image from a prompt, is the image # provided?
When producing more than 1 window in a video, is the Sliding Window # provided?
* Answered: 2/8/2026 4:30:15 PM CST


## Qwen Image Edit:
[X] Explain in great detail how the Qwen Image Edit 2511 works.
Specifically: 
* the Control Image Process, which has the following options:
  * None, Transfer Human Pose, Transfer Depth, Transfer Shapes, Recolorize, Qwen Raw Format.
* Area Processed:
  * Options: Whole Frame, Masked Area
* Inject Reference images, Options are:
  * Conditional Image is first Main Subject / Landscape and may be followed by People / Objects
  * Conditional Images are People / Objects

Explain the "Automatic Removal of Backgrounds" options.

Explain How I can render multiple images with the same reference image using a multi-line prompt.
Explain how "! line" macros work.

Explain all of the settings on the Advanced Mode section:
* General
* Loras
* Post-Processing
* Quality
* Misc
* Answered: 2/8/2026 5:00:00 PM CST

[X] Add a Section to the Qwen Image Edit Model MD file that functions as a Prompting Guide for how to write Prompts for Qwen Image Edit. Provide guidance for:
* Positive Prompt
* Negative Prompt
* Control Image Usage
Ensure this Guide is not too lengthy as it may be used to provide to other LLMs for usage in generating Prompts
    * Answered: 2/8/2026 5:45:00 PM CST

[X] Add information in the Qwen Image Edit Prompt Guidance section that covers what Camera Guidance Prompts exist, and how they could be used. In addition, if there are specific words or methods for directing character or person editing, add that as well.
    * Answered: 2/8/2026 5:50:00 PM CST


## Wan2.2 SVI Pro (Wan2.2 Image2Video 14B SVI 2 Pro):
[X] Explain in great detail how Wan2.2 ImageEdit SVI Pro works.
Specifically:
*  Start with Video Image
*  Continue Video
*  Continue Last Video
For each of those, explain how the:
* Images as starting Point 
* Anchor Images 
work for each.

Explain the impact of each option on the Number Of Frames of the Video produced, as it pertains to a starting Image, Continued Video, Continued Last Video.

Explain all of the settings on the Advanced Mode section:
* General
  * Specifically: 
    * Guidance/CFG, Guidance 2/CFG
    * Sampler Solver/Scheduler
    * Shift Scale
    * Negative Prompt
    * Num of generaged videos per prompt, Multiple Images as Text Prompts, Nag Scale, Nag Tau, Nag Alpha
* Loras
* Steps Skipping
* Post-Processing
* Audio
* Quality
* Sliding Window
* Misc
* Answered: 2/8/2026 5:30:00 PM CST

[X] Explain how the Wan2.2 SVI Pro handles timed prompts like this:
(at 0 seconds:a man open his fridge, takes a beer and drink it)
When writing prompts, when each is 81 frames, at 16fps, and using the Wan2GP Sliding Window, should the times listed reflect the time within the current 5-second prompt? Or within the full set of frames across multilpe sliding windows?
Ex: I am producing a video of 240frames, that includes 3 sliding windows of 81 frames each, at 16fps. This means the total video is: 15 sec, and each sliding window is 5 sec.
When providing timed prompt instructions, if I want to target an action that takes place 3 seconds into the 2nd sliding window (8 sec from the beginning) would I say this:
(at 8 second: do action)
Or would I say this:
(at 3 seconds: do action)
I assume the 2nd option, since that would be part of the 2nd prompt, but I would like this confirmed.

[X] Add a Section to the Wan2.2 SVI Pro Model MD file that functions as a Prompting Guide for how to write Prompts for Wan2.2 SVI Pro. Provide guidance for:
* Positive Prompt
* Negative Prompt
* Use of LORAs
Ensure this Guide is not too lengthy as it may be used to provide to other LLMs for usage in generating Prompts.
    * Answered: 2/8/2026 5:35:00 PM CST

[X] Add information in the Prompt Guidance section that covers what Camera Guidance Propmts exist, and how they could be used. In addition, if there are specific words or methods for directing character or person movement, add that as well.
    * Answered: 2/8/2026 5:50:00 PM CST


## Wan2.2 *
[X] Create a section below for Every Wan2.2 Sub-Model type, including:
* VACE 14B
* Image2Video 14B
* Lucy Edit 5B
* OVI 10B
* Text2Video 14B
* TextImage2Video 14B
Create Model Files for each.
* Answered: 2/8/2026 6:00:00 PM CST

## Motion Designer:
[X] Explain what this is. How would I use it. Why would I use it? What is it mainly for? Is it for a specific model, or for all models?
* Answered: 2/8/2026 6:10:00 PM CST

## Z-Image:
[X] Explain in great detail how the Z-Image Turbo and all sub-models work.
Create Files for every type of Z-Image model: Turbo, Base, Turbo-Fun
* Answered: 2/8/2026 6:20:00 PM CST

## TTS:
[X] Explain in great detail how the TTS models work
* Create a Model/Sub-Model file for EVERY TTS Model that Wan2GP supports.
* Add the necessary information required to each file.
* Answered: 2/8/2026 6:30:00 PM CST


