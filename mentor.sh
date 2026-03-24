#!/usr/bin/env bash

# Mentor: A Socratic tutor powered by Gemini
# Inspired by CS50.ai

# Check for API Key
if [[ -z "$GEMINI_API_KEY" ]]; then
    echo "Error: GEMINI_API_KEY environment variable is not set."
    echo "Please export it: export GEMINI_API_KEY='your_key_here'"
    exit 1
fi

# Check for dependencies
for cmd in jq glow gum; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: $cmd is not installed. Please install it to continue."
        exit 1
    fi
done

# Use gemini-2.5-flash based on your available models
API_URL="https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:streamGenerateContent?key=${GEMINI_API_KEY}&alt=sse"
HISTORY_FILE=$(mktemp)
SYSTEM_PROMPT="You are a patient and encouraging Socratic tutor. Your goal is to lead students to the solution through discovery.
- **Socratic by default**: For coding problems or bugs, never provide the direct fix. Instead, guide by questioning.
- **Direct for general knowledge**: If the student asks for general information, definitions, or broad concepts (e.g., 'What is a JVM?', 'What is a buzzword?'), provide a clear and direct answer without being cryptic.
- **Teach the 'Why'**: Explain the underlying concepts (loops, logic, syntax) using simple, unrelated examples rather than the student's specific code.
- **Be Adaptive**: If a student is clearly frustrated or stuck on a minor detail (like a typo), provide a more specific hint rather than a cryptic question to keep them moving.
- **Acknowledge Progress**: Start by mentioning what they got right before diving into what needs fixing.
- **One Step at a Time**: Keep responses short and focused on a single issue. Don't overwhelm them with multiple corrections at once."

# Disable patsub_replacement if available to prevent '&' in file contents
# from being replaced by the matched pattern in string substitutions.
shopt -u patsub_replacement 2>/dev/null || true

# Initialize history
echo "[]" > "$HISTORY_FILE"
trap 'rm -f "$HISTORY_FILE"' EXIT

function show_banner() {
    clear
    cat << "EOF" | gum style \
        --foreground 34 \
        --border-foreground 34 \
        --border double \
        --align center \
        --margin "1 2" \
        --padding "1 2"
   __  __   ______   __   __   ______  ______   ______
 /\ \/\ \ /\  ___\ /\ "-.\ \ /\__  _\/\  __ \ /\  == \
 \ \ \_\ \\ \  __\ \ \ \-.  \\/_/\ \/\ \ \/\ \\ \  __<
  \ \_____\\ \_____\\ \_\\"\_\   \ \_\ \ \_____\\ \_\ \_\
   \/_____/ \/_____/ \/_/ \/_/    \/_/  \/_____/ \/_/ /_/
EOF

    echo "--- Your Socratic Mentor is online (Gemini 2.5 Flash) ---" | gum style --foreground 212
    echo "Tip: Use @filename to include code from a file. Type 'exit' to quit." | gum style --foreground 240
    echo ""
}

function process_prompt() {
    local final_prompt="$1"

    # Detect all @filename patterns and replace with file content
    while [[ "$final_prompt" =~ @([a-zA-Z0-9_.-]+) ]]; do
        local filename="${BASH_REMATCH[1]}"
        local pattern="@$filename"
        if [[ -f "$filename" ]]; then
            local file_content=$(cat "$filename")
            final_prompt="${final_prompt//$pattern/ [File: $filename contents: $file_content]}"
        else
            echo -e "\n\e[33mWarning:\e[0m File '$filename' not found.\n"
            # Replace the pattern with a marker to avoid infinite loop
            final_prompt="${final_prompt//$pattern/[File not found: $filename]}"
        fi
    done
    echo "$final_prompt"
}

function ask_gemini() {
    local user_input="$1"
    local is_direct="${2:-false}"
    local processed_input=$(process_prompt "$user_input")
    
    # Update history with user message
    jq --arg text "$processed_input" '. += [{"role": "user", "parts": [{"text": $text}]}]' "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" && mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"

    # Use a direct prompt if requested, otherwise use the Socratic one
    local current_sys_prompt="$SYSTEM_PROMPT"
    if [[ "$is_direct" == "true" ]]; then
        current_sys_prompt="You are a helpful, concise technical assistant. Provide direct, correct, and efficient solutions to the user's questions or code problems. Skip the Socratic questioning and lead directly with the answer or fix. Use Markdown for code blocks."
    fi

    # Prepare request JSON
    local request_json=$(jq -n \
        --arg sys "$current_sys_prompt" \
        --argjson history "$(cat "$HISTORY_FILE")" \
        '{ "system_instruction": {"parts": [{"text": $sys}]}, "contents": $history, "generationConfig": { "temperature": 0.2, "maxOutputTokens": 1024 } }')

    # Call API with gum spin
    local raw_response_file=$(mktemp)
    local request_file=$(mktemp)
    echo "$request_json" > "$request_file"

    gum spin --spinner dot --title "Mentor is thinking..." -- curl -s -N -X POST "$API_URL" -H "Content-Type: application/json" -d @"$request_file" > "$raw_response_file"

    local mentor_text=""
    while IFS= read -r line; do
        if [[ "$line" =~ ^data:\ (.*) ]]; then
            local json_data="${BASH_REMATCH[1]}"
            local chunk=$(echo "$json_data" | jq -j '.candidates[0].content.parts[0].text // empty' 2>/dev/null)
            if [[ -n "$chunk" ]]; then
                mentor_text+="$chunk"
            fi
        fi
    done < "$raw_response_file"
    
    rm -f "$raw_response_file" "$request_file"

    if [[ -z "$mentor_text" ]]; then
        gum style --foreground 196 "Error: Unable to get response from Gemini."
        return
    fi

    # After streaming is done, render the whole thing
    if command -v glow >/dev/null 2>&1; then
        echo "$mentor_text" | glow -
    else
        echo "$mentor_text"
    fi

    echo ""

    # Update history with model response
    jq --arg text "$mentor_text" '. += [{"role": "model", "parts": [{"text": $text}]}]' "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" && mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"
}

# --- Execution ---

# Non-interactive mode (Direct Answers)
if [[ $# -gt 0 ]]; then
    ask_gemini "$*" "true"
    exit 0
fi

# Interactive mode
show_banner

while true; do
    user_input=$(gum input --placeholder "What's on your mind? (type 'exit' to quit)")
    
    # Handle Ctrl+C or escape (non-zero exit code from gum)
    if [[ $? -ne 0 ]]; then
        gum style --foreground 212 "Goodbye! Happy coding."
        break
    fi

    if [[ "$user_input" == "exit" || "$user_input" == "quit" ]]; then
        gum style --foreground 212 "Goodbye! Happy coding."
        break
    fi
    
    if [[ -z "$user_input" ]]; then
        continue
    fi

    echo ""
    gum style --foreground 34 "You: $user_input"

    ask_gemini "$user_input"
done
