function ConvertFrom-F4RwrLine {
    param([string]$Line)
    if ($Line -notmatch 'F4RWR_V1\|(\d{1,12})\|(UNAVAILABLE|TEST|CLEAR|LAUNCH|CONTACT)\|(\d{1,2})\|([\w .-]{0,48})\|([\w .-]{0,48})\s*$') { return $null }
    $h = [int]$Matches[3]
    if ($h -gt 12) { return $null }
    [pscustomobject]@{Sequence=[long]$Matches[1];Mode=$Matches[2];Hour=$h;Activity=$Matches[4];Category=$Matches[5]}
}
