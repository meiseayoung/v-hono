# Quick concurrent test using runspaces
$url = "http://127.0.0.1:8888/"
$concurrency = 300
$requestsEach = 20

Write-Host "Testing $url with $concurrency concurrent workers, $requestsEach requests each"
Write-Host "Total: $($concurrency * $requestsEach) requests"

$runspacePool = [runspacefactory]::CreateRunspacePool(1, $concurrency)
$runspacePool.Open()

$scriptBlock = {
    param($url, $count)
    $s = 0; $f = 0
    for ($i = 0; $i -lt $count; $i++) {
        try {
            $req = [System.Net.WebRequest]::Create($url)
            $req.Timeout = 30000
            $resp = $req.GetResponse()
            if ($resp.StatusCode -eq "OK") { $s++ } else { $f++ }
            $resp.Close()
        } catch {
            $f++
        }
    }
    return @{Success=$s; Failed=$f}
}

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$runspaces = @()

for ($i = 0; $i -lt $concurrency; $i++) {
    $ps = [powershell]::Create()
    $ps.RunspacePool = $runspacePool
    $ps.AddScript($scriptBlock).AddArgument($url).AddArgument($requestsEach) | Out-Null
    $runspaces += @{PS=$ps; Handle=$ps.BeginInvoke()}
}

$totalSuccess = 0
$totalFailed = 0

foreach ($rs in $runspaces) {
    $result = $rs.PS.EndInvoke($rs.Handle)
    $totalSuccess += $result.Success
    $totalFailed += $result.Failed
    $rs.PS.Dispose()
}

$sw.Stop()
$runspacePool.Close()

$total = $totalSuccess + $totalFailed
$rps = [math]::Round($total * 1000 / $sw.ElapsedMilliseconds, 2)
$rate = [math]::Round($totalSuccess * 100 / $total, 2)

Write-Host ""
Write-Host "Results:"
Write-Host "  Total: $total"
Write-Host "  Success: $totalSuccess"
Write-Host "  Failed: $totalFailed"
Write-Host "  Duration: $($sw.ElapsedMilliseconds) ms"
Write-Host "  RPS: $rps"
Write-Host "  Success Rate: $rate%"

if ($totalFailed -eq 0) {
    Write-Host "PASSED - No connection errors!" -ForegroundColor Green
} else {
    Write-Host "FAILED - $totalFailed errors occurred" -ForegroundColor Red
}
