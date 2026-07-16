$body = @{
    prompt = "Say hello in Arabic"
    model = "gemini-2.0-flash-lite"
    maxTokens = 100
} | ConvertTo-Json -Compress

$headers = @{
    "X-Parse-Application-Id" = "uWUMmdbdRjcuOKuCcl9Pg7zEYxnYGVaLXjmveGF2"
    "X-Parse-REST-API-Key" = "Zsvk14ko9rvXD25G1hflNeY2Dg2hJtkocPvh6tMp"
    "X-Parse-Master-Key" = "8qRzu0pBFkDo0urIjpXeFGb23xR5C23JoOlD05ze"
    "Content-Type" = "application/json"
}

try {
    $response = Invoke-RestMethod -Uri "https://parseapi.back4app.com/functions/aiGateway" -Method POST -Headers $headers -Body $body
    Write-Host "SUCCESS:" -ForegroundColor Green
    $response | ConvertTo-Json -Depth 5
} catch {
    Write-Host "ERROR:" -ForegroundColor Red
    Write-Host "Status: $($_.Exception.Response.StatusCode.value__)"
    Write-Host "Message: $($_.Exception.Message)"
    if ($_.ErrorDetails.Message) {
        Write-Host "Details: $($_.ErrorDetails.Message)"
    }
}
