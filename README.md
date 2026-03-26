# Mentor CLI

A Socratic tutor powered by Gemini, inspired by CS50.ai. It leads students to solutions through discovery rather than direct answers.

## Requirements

- `bash`: A Linux shell
- `glow`: A markdown renderer
- `gum`: For interactive prompts and inputs
- `jq`: A JSON parser
- Gemini API Key

## Installation

You can install the script system-wide by running the provided `install.sh` script:

```bash
./install.sh
```

This will install the script as `mentor` in `/usr/local/bin/`.

## Usage

Set your Gemini API key in your shell profile:

```bash
export GEMINI_API_KEY='your_api_key_here'
```

Then run the mentor:

```bash
# Start interactive mode
mentor

# Get a direct answer for a technical question (non-interactive)
mentor "What is a JVM?"
```

In interactive mode, you can include file contents in your prompt using the `@filename` pattern.
Example: `How can I fix the bug in @main.py?`
