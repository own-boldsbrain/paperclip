import os
import glob
import subprocess
import json
import time
from pathlib import Path

def main():
    target_dir = r"C:\Users\fjuni\OneDrive\Documentos\GitHub\paperclip\doc\plans"
    translate_script = r"C:\Users\fjuni\.gemini\config\skills\translation\scripts\translate_doc.py"
    
    # Get all .md files that don't end with .pt-BR.md
    md_files = []
    for file_path in glob.glob(os.path.join(target_dir, "*.md")):
        if not file_path.endswith(".pt-BR.md"):
            md_files.append(file_path)
            
    print(f"Found {len(md_files)} Markdown files to process.")
    
    results = {
        "total_files": len(md_files),
        "successful": 0,
        "failed": 0,
        "skipped": 0,
        "details": []
    }
    
    start_time = time.time()
    
    for i, md_file in enumerate(md_files, 1):
        filename = os.path.basename(md_file)
        out_file = md_file[:-3] + ".pt-BR.md"
        
        print(f"[{i}/{len(md_files)}] Processing {filename}...")
        
        if os.path.exists(out_file):
            print(f"  -> Skipping. Output file already exists: {os.path.basename(out_file)}")
            results["skipped"] += 1
            results["details"].append({"file": filename, "status": "skipped", "reason": "Already exists"})
            continue
            
        # Build command: python translate_doc.py -f input.md -o output.md --validate -e deeplx
        cmd = [
            "python", 
            translate_script, 
            "-f", md_file, 
            "-o", out_file,
            "--validate",
            "-e", "deeplx",
            "-w", "1",
            "--stream-log"
        ]
        
        try:
            result = subprocess.run(cmd, capture_output=True, text=True)
            if result.returncode == 0:
                print(f"  -> Success.")
                results["successful"] += 1
                results["details"].append({"file": filename, "status": "success"})
            else:
                print(f"  -> Failed. Check logs.")
                print(f"STDOUT: {result.stdout}")
                print(f"STDERR: {result.stderr}")
                results["failed"] += 1
                results["details"].append({
                    "file": filename, 
                    "status": "failed", 
                    "error": result.stderr or result.stdout
                })
        except Exception as e:
            print(f"  -> Error: {str(e)}")
            results["failed"] += 1
            results["details"].append({"file": filename, "status": "error", "error": str(e)})
            
    duration = time.time() - start_time
    results["duration_seconds"] = round(duration, 2)
    
    # Generate JSON report
    json_report_path = os.path.join(target_dir, "translation_report.json")
    with open(json_report_path, "w", encoding="utf-8") as f:
        json.dump(results, f, indent=2, ensure_ascii=False)
        
    # Generate Markdown report
    md_report_path = os.path.join(target_dir, "translation_report.md")
    with open(md_report_path, "w", encoding="utf-8") as f:
        f.write("# Translation Batch Report\n\n")
        f.write(f"- **Total Files**: {results['total_files']}\n")
        f.write(f"- **Successful**: {results['successful']}\n")
        f.write(f"- **Skipped**: {results['skipped']}\n")
        f.write(f"- **Failed**: {results['failed']}\n")
        f.write(f"- **Duration**: {results['duration_seconds']} seconds\n\n")
        
        if results["failed"] > 0:
            f.write("## Failed Files\n")
            for item in results["details"]:
                if item["status"] in ["failed", "error"]:
                    f.write(f"- **{item['file']}**: {item.get('error', 'Unknown error')}\n")
                    
    print(f"\nBatch processing complete. Generated reports:")
    print(f"- {json_report_path}")
    print(f"- {md_report_path}")

if __name__ == "__main__":
    main()
