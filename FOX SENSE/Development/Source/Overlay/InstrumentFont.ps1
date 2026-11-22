# Private bundled font: no machine-wide font registration or installation.
$script:instrumentFontUri=([uri]((Join-Path $PSScriptRoot 'Fonts')+[IO.Path]::DirectorySeparatorChar)).AbsoluteUri+'#Share Tech Mono'
$script:instrumentFont=[Windows.Media.FontFamily]::new($script:instrumentFontUri)
function ConvertTo-InstrumentXaml([string]$Text){
    $family=[Security.SecurityElement]::Escape($script:instrumentFontUri)
    $Text=$Text.Replace('FontFamily="Segoe UI"',('FontFamily="'+$family+'"')).Replace('FontFamily="Consolas"',('FontFamily="'+$family+'"'))
    return $Text.Replace('Property="FontFamily" Value="Consolas"',('Property="FontFamily" Value="'+$family+'"'))
}
