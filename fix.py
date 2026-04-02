import sys

def fix_html():
    with open('index.html', 'r', encoding='utf-8') as f:
        lines = f.readlines()
        
    with open('snippet.txt', 'r', encoding='utf-8') as f:
        snippet_lines = f.readlines()
        
    start_idx = -1
    end_idx = -1
    
    for i, line in enumerate(lines):
        if 'HARM_CATEGORY_SEXUALLY_EXPLICIT' in line:
            start_idx = i
            break
            
    for i in range(start_idx, len(lines)):
        if 'async function pollOperation(operationName' in line:
            end_idx = i
            break
            
    if start_idx != -1 and end_idx != -1:
        print(f"Found match: start={start_idx}, end={end_idx}")
        new_lines = lines[:start_idx] + snippet_lines + lines[end_idx:]
        with open('index.html', 'w', encoding='utf-8') as f:
            f.writelines(new_lines)
        print("Fixed!")
    else:
        print(f"Failed to find match: start={start_idx}, end={end_idx}")

fix_html()
