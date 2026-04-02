import re

def implant():
    with open('index.html', 'r', encoding='utf-8') as f:
        content = f.read()

    with open('snippet.txt', 'r', encoding='utf-8') as f:
        snippet = f.read()
        
    # Extract only generateVideo and pollThirdPartyTask from snippet.txt
    match1 = re.search(r'// ================= Veo 视频生成 =================', snippet)
    poll_code = snippet[match1.start():]
    
    # Locate where to replace in index.html
    # We want to replace from // ================= Veo 视频生成 (FPS Removed) =================
    # (Because the diff showed it as FPS Removed or just Veo视频生成 depending on what git restore did)
    # until the start of async function pollOperation
    match_html_start = re.search(r'// ================= Veo.+?生成.+?=================', content)
    match_html_end = re.search(r'\s*async function pollOperation\(operationName', content)
    
    if match_html_start and match_html_end:
        print(f"Replacing at {match_html_start.start()} to {match_html_end.start()}")
        new_content = content[:match_html_start.start()] + poll_code + '\n' + content[match_html_end.start():]
        with open('index.html', 'w', encoding='utf-8') as f:
            f.write(new_content)
        print("Done")
    else:
        print("Match failed in index.html")
        print(f"start: {bool(match_html_start)}, end: {bool(match_html_end)}")

implant()
