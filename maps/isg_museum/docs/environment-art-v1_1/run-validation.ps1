# Run from the repository root; only evidence logs are written by this runner.
param([switch]$Resume)
$ErrorActionPreference = 'Continue'
$engine = (Resolve-Path '.local/godot/Godot_v4.7.2-stable_win64_console.exe').Path
$python = 'C:/Users/Gia Manh/AppData/Roaming/uv/python/cpython-3.15-windows-x86_64-none/python.exe'
$evidence = $PSScriptRoot
$previousAppData = $env:APPDATA
$results = @()
if ($Resume -and (Test-Path (Join-Path $evidence 'validation-run.json'))) {
	$previousResults = Get-Content (Join-Path $evidence 'validation-run.json') -Raw | ConvertFrom-Json
	foreach ($record in $previousResults) { $results += $record }
}
$env:APPDATA = Join-Path (Resolve-Path '.local') 'godot-art-userdata-v11'

function Invoke-Check([string]$id, [string]$executable, [string[]]$arguments) {
	if ($Resume -and $id -ne 'check-scripts' -and ($script:results | Where-Object { $_.id -eq $id -and $_.exit_code -eq 0 }).Count -gt 0) {
		Write-Output ($id + ': previous exit 0 retained')
		return
	}
	$script:results = @($script:results | Where-Object { $_.id -ne $id })
	$started = Get-Date
	& $executable @arguments *> (Join-Path $evidence ($id + '.log'))
	$code = $LASTEXITCODE
	$script:results += [pscustomobject]@{
		id = $id; executable = $executable; arguments = $arguments
		exit_code = $code; started = $started.ToString('o'); finished = (Get-Date).ToString('o')
	}
	$script:results | ConvertTo-Json -Depth 6 | Set-Content -Encoding utf8 (Join-Path $evidence 'validation-run.json')
	Write-Output ($id + ': exit ' + $code)
}

try {
	Invoke-Check 'version' $engine @('--version')
	Invoke-Check 'final-import' $engine @('--headless','--path','.','--editor','--quit')
	Invoke-Check 'check-scripts' $engine @('--headless','--path','.','--script','res://tools/ci/check_scripts.gd')
	Invoke-Check 'check-layout' $python @('-B','tools/ci/check_layout.py')
	$targets = @(Get-ChildItem 'maps/isg_museum/scenes' -Recurse -File -Filter '*.tscn') + @(Get-Item 'maps/isg_museum/resources/environment_art_manifest.json')
	$before = @($targets | Get-FileHash -Algorithm SHA256 | Select-Object Path,Hash)
	Invoke-Check 'check-art' $engine @('--headless','--path','.','--script','res://maps/isg_museum/tools/apply_environment_art.gd','--','--check')
	$after = @($targets | Get-FileHash -Algorithm SHA256 | Select-Object Path,Hash)
	$same = ($before | ConvertTo-Json -Compress) -eq ($after | ConvertTo-Json -Compress)
	[pscustomobject]@{unchanged=$same; before=$before; after=$after} | ConvertTo-Json -Depth 5 | Set-Content -Encoding utf8 (Join-Path $evidence 'readonly-check.json')
	foreach ($suite in @('environment_art','blockout','contract_variants','empty_frame','carry','staff_room','storage','service','exhibits','room_feedback')) {
		Invoke-Check ('verify-' + $suite) $engine @('--headless','--path','.','--fixed-fps','60','--script',('res://maps/isg_museum/tools/verify_' + $suite + '.gd'))
	}
	Invoke-Check 'integrated' $engine @('--headless','--path','.','--fixed-fps','60','res://tests/test_scene.tscn')
} finally {
	$env:APPDATA = $previousAppData
}
if (($results | Where-Object { $_.exit_code -ne 0 }).Count -gt 0 -or -not $same) { exit 1 }
