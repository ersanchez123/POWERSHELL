Param(
   [Parameter(Mandatory)]
   $Path
)
New-Item $Path
Write-Host "File created at path $Path"