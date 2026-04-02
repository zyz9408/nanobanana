import re

def fix():
    with open('index.html', 'r', encoding='utf-8') as f:
        content = f.read()
        
    with open('snippet.txt', 'r', encoding='utf-8') as f:
        snippet = f.read()
        
    # Find the block we want to preserve before the damage
    match1 = re.search(r'\{ category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_NONE" \},\s*', content)
    if not match1:
        print("Could not find start point")
        return
        
    # In the original file, after SEXUALLY_EXPLICIT, the next intact function is pollOperation
    match2 = re.search(r'\s*async function pollOperation\(operationName, apiKey', content)
    if not match2:
        print("Could not find end point")
        return
        
    start_idx = match1.end()
    end_idx = match2.start()
    
    print(f"Replacing from {start_idx} to {end_idx}")
    
    # We still need to include the line `{ category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_NONE" }` 
    # which is at the start of snippet.txt
    
    new_content = content[:start_idx] + '\n                            { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_NONE" }\n                        ],\n                        generationConfig: {\n                            responseModalities: ["IMAGE", "TEXT"],\n                            imageConfig: { aspectRatio: aspectRatio, imageSize: resolution }\n                        }\n                    };\n\n                    let baseUrl = apiBaseUrl || "https://generativelanguage.googleapis.com";\n                    baseUrl = baseUrl.replace(/\\/+$/, \'\');\n\n                    const response = await fetch(`${baseUrl}/v1beta/models/${requestModel}:generateContent?key=${apiKey}`, {\n                        method: \'POST\',\n                        headers: { \'Content-Type\': \'application/json\' },\n                        body: JSON.stringify(payload),\n                        signal: imageAbortController.signal\n                    });\n\n                    if (!response.ok) {\n                        const err = await response.json();\n                        throw new Error(err.error?.message || response.status);\n                    }\n\n' + snippet + '\n\n        ' + content[end_idx:]
    
    with open('index.html', 'w', encoding='utf-8') as f:
        f.write(new_content)
        
    print("Patch applied")

fix()
