$headers = @{'Accept'='application/vnd.github+json'}
$runs = Invoke-RestMethod -Uri 'https://api.github.com/repos/ryouta-dev/SemeyCarDriving/actions/runs?per_page=1' -Headers $headers
$runId = $runs.workflow_runs[0].id
Write-Host "Run ID: $runId"
$jobs = Invoke-RestMethod -Uri "https://api.github.com/repos/ryouta-dev/SemeyCarDriving/actions/runs/$runId/jobs" -Headers $headers
foreach ($job in $jobs.jobs) {
    Write-Host "--- JOB: $($job.name) STATUS: $($job.conclusion)"
    foreach ($step in $job.steps) {
        if ($step.conclusion -eq 'failure') {
            Write-Host "  FAILED STEP [$($step.number)]: $($step.name)"
        }
    }
}
