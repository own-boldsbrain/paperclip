param(
    [string]$Root = ".\doc",
    [string]$TargetLanguage = "pt-BR",
    [string]$Provider = "Auto",
    [int]$ThrottleLimit = 2,
    [switch]$DryRun,
    [switch]$Force
)

$Root = (Resolve-Path $Root).Path
$transDir = Join-Path $Root "..\.translation"
if (-not (Test-Path $transDir)) { New-Item -ItemType Directory -Path $transDir | Out-Null }
$manifestPath = Join-Path $transDir "manifest.jsonl"
$failedPath = Join-Path $transDir "FAILED.json"
$completedPath = Join-Path $transDir "COMPLETED.json"

function Get-FileSha256 {
    param([string]$Path)
    (Get-FileHash $Path -Algorithm SHA256).Hash
}

$manifest = @{}
if (Test-Path $manifestPath) {
    Get-Content $manifestPath | ForEach-Object {
        try {
            $entry = $_ | ConvertFrom-Json
            if ($entry.source) {
                $manifest[$entry.source] = $entry
            }
        } catch {}
    }
}

$mdFiles = Get-ChildItem -Path $Root -Recurse -Filter "*.md" | Where-Object {
    $_.Name -notmatch "\.pt-br\.md$" -and $_.Name -notmatch "\.pt-BR\.md$"
}

$eligibleFiles = @()

foreach ($file in $mdFiles) {
    $relPath = $file.FullName.Substring($Root.Length + 1).Replace('\', '/')
    $sourcePath = "doc/$relPath"
    $targetName = $file.Name -replace '\.md$', ".$TargetLanguage.md"
    $targetPath = Join-Path -Path $file.DirectoryName -ChildPath $targetName
    $targetRelPath = $sourcePath -replace '\.md$', ".$TargetLanguage.md"

    $hash = Get-FileSha256 $file.FullName
    
    $skip = $false
    if (-not $Force -and $manifest.ContainsKey($sourcePath)) {
        $entry = $manifest[$sourcePath]
        if ($entry.source_sha256 -eq $hash -and $entry.status -eq "completed" -and (Test-Path $targetPath)) {
            $skip = $true
        }
    }

    if (-not $skip) {
        $eligibleFiles += [PSCustomObject]@{
            File = $file
            SourcePath = $sourcePath
            TargetPath = $targetPath
            TargetRelPath = $targetRelPath
            Hash = $hash
            SizeKb = [math]::Round($file.Length / 1KB, 2)
        }
    }
}

Write-Output "Inventário completo. Encontrados $($mdFiles.Count) arquivos totais."
Write-Output "Arquivos elegíveis para tradução: $($eligibleFiles.Count)"

if ($DryRun) {
    $eligibleFiles | Format-Table SourcePath, SizeKb
    exit
}

if ($eligibleFiles.Count -eq 0) {
    Write-Output "Nenhum arquivo para traduzir. Gerando COMPLETED.json."
    @{ status="completed"; timestamp=(Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz") } | ConvertTo-Json | Out-File $completedPath -Encoding utf8
    exit
}

$eligibleFiles | ForEach-Object {
    $item = $_
    $file = $item.File
    $transDir = $transDir
    $manifestPath = $manifestPath
    $ProviderChoice = $Provider
    
    $content = Get-Content -LiteralPath $file.FullName -Raw
    if ([string]::IsNullOrWhiteSpace($content)) { return }
    
    $selectedProvider = $ProviderChoice
    $model = "DeepLX"
    if ($selectedProvider -eq "Auto") {
        if ($item.SizeKb -le 1.4) {
            $selectedProvider = "DeepLX"
        } else {
            $selectedProvider = "Ollama"
            $model = "translategemma:4b"
        }
    } elseif ($selectedProvider -eq "Ollama") {
        $model = "translategemma:4b"
    }

    $tmpPath = $item.TargetPath + ".tmp"
    $startedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
    
    $attempt = 1
    $success = $false
    
    while ($attempt -le 3 -and -not $success) {
        try {
            if ($selectedProvider -eq "DeepLX") {
                $body = @{text=$content; source_lang="EN"; target_lang="PT"} | ConvertTo-Json -Depth 10 -Compress
                $r = Invoke-RestMethod -Uri "http://localhost:1188/translate" -Method Post -ContentType "application/json" -Body $body -TimeoutSec 30
                $r.data | Out-File -FilePath $tmpPath -Encoding utf8
                $success = $true
            } else {
                $prompt = "Translate the following English text to Brazilian Portuguese. Return ONLY the translated text, with no explanations, notes, or alternatives. Keep all markdown formatting, code blocks, and URLs intact.`n`nText:`n$content"
                $body = @{model=$model; prompt=$prompt; stream=$false} | ConvertTo-Json -Depth 10 -Compress
                $r = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method Post -ContentType "application/json" -Body $body -TimeoutSec 3600
                $r.response | Out-File -FilePath $tmpPath -Encoding utf8
                $success = $true
            }
        } catch {
            Write-Output "Falha ao processar $($item.SourcePath) na tentativa $attempt com $selectedProvider. $($_.Exception.Message)"
            if ($selectedProvider -eq "DeepLX" -and $attempt -eq 2) {
                Write-Output "Fazendo fallback para Ollama..."
                $selectedProvider = "Ollama"
                $model = "translategemma:4b"
            }
            $attempt++
            Start-Sleep -Seconds (2 * $attempt)
        }
    }
    
    $finishedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
    
    if ($success) {
        Move-Item -Path $tmpPath -Destination $item.TargetPath -Force
        $logEntry = @{
            source = $item.SourcePath
            output = $item.TargetRelPath
            source_sha256 = $item.Hash
            provider = $selectedProvider
            model = $model
            status = "completed"
            attempts = $attempt
            started_at = $startedAt
            finished_at = $finishedAt
        }
        $jsonLine = $logEntry | ConvertTo-Json -Compress
        Add-Content -Path $manifestPath -Value $jsonLine -Encoding utf8
        Write-Output "[$selectedProvider] Concluído: $($item.SourcePath)"
    } else {
        if (Test-Path $tmpPath) { Remove-Item $tmpPath -Force }
        $logEntry = @{
            source = $item.SourcePath
            status = "failed"
        }
        $jsonLine = $logEntry | ConvertTo-Json -Compress
        Add-Content -Path $manifestPath -Value $jsonLine -Encoding utf8
        Write-Output "FALHA: $($item.SourcePath)"
    }
}

$finalManifest = Get-Content $manifestPath -ErrorAction SilentlyContinue | ForEach-Object { try { $_ | ConvertFrom-Json } catch {} }
if ($finalManifest) {
    $failed = $finalManifest | Where-Object { $_.status -eq "failed" }
    if ($failed) {
        $failed | ConvertTo-Json | Out-File $failedPath -Encoding utf8
    }
}

$tmpFiles = Get-ChildItem -Path $Root -Recurse -Filter "*.tmp"
if ($tmpFiles.Count -eq 0) {
    @{ status="completed"; timestamp=(Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz") } | ConvertTo-Json | Out-File $completedPath -Encoding utf8
    Write-Output "Processo concluído com sucesso. COMPLETED.json gerado."
} else {
    Write-Output "Aviso: Arquivos .tmp restantes foram encontrados."
}
