# Run after validation/capture finish; run no other GPU or authoring jobs alongside.
param([int]$Seconds = 240, [switch]$GameplayOnly)
$engine = (Resolve-Path '.local/godot/Godot_v4.7.2-stable_win64_console.exe').Path
$previousAppData = $env:APPDATA
$env:APPDATA = Join-Path (Resolve-Path '.local') 'godot-art-userdata-v11'
$results = @()
if ($GameplayOnly -and (Test-Path (Join-Path $PSScriptRoot 'benchmark-run.json'))) {
	$previousResults = Get-Content (Join-Path $PSScriptRoot 'benchmark-run.json') -Raw | ConvertFrom-Json
	foreach ($record in $previousResults) {
		if ($record.id -ne 'after-gameplay') { $results += $record }
	}
}
try {
	$jobs = @('after-gameplay')
	if (-not $GameplayOnly) { $jobs = @('before-render','after-render','after-gameplay') }
	foreach ($id in $jobs) {
		$arguments = @('--path','.','--rendering-method','gl_compatibility','--resolution','1280x720',
			'--script','res://maps/isg_museum/tools/benchmark_environment_art.gd','--','--exclusive')
		if ($id -eq 'before-render') { $arguments += '--before' }
		if ($id -eq 'after-gameplay') { $arguments += @('--gameplay',('--seconds=' + $Seconds)) }
		$started = Get-Date
		& $engine @arguments *> (Join-Path $PSScriptRoot ($id + '.log'))
		$code = $LASTEXITCODE
		$results += [pscustomobject]@{
			id = $id; arguments = $arguments; exit_code = $code
			started = $started.ToString('o'); finished = (Get-Date).ToString('o')
		}
		$results | ConvertTo-Json -Depth 5 | Set-Content -Encoding utf8 (Join-Path $PSScriptRoot 'benchmark-run.json')
		Write-Output ($id + ': exit ' + $code)
		if ($code -ne 0) { exit $code }
	}
} finally {
	$env:APPDATA = $previousAppData
}
