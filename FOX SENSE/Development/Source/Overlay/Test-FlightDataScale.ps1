$menu=Load-Xaml 'Controls.xaml'
$scale=$menu.FindName('FlightDataScale')
if($scale.Value -ne 1){throw 'Old settings must default flight data scale to 100 percent'}
Set-FlightDataScale 1.25
$transform=$hudWindow.FindName('FlightData').RenderTransform
$point=$transform.Transform([Windows.Point]::new(1848,440))
if($transform.CenterX -ne 1280 -or $transform.CenterY -ne 720 -or $point.X -ne 1990 -or $point.Y -ne 370){throw 'Flight data does not scale about HUD center'}
if($transform.ScaleX -ne 1.25 -or $transform.ScaleY -ne 1.25){throw 'Flight data scaling must be uniform'}
$scale.Value=1.25
$path=Join-Path $env:TEMP ('fox-flight-scale-'+[guid]::NewGuid().ToString('N')+'.json')
try{
    Save-HudSettings $menu $path
    $reopened=Load-Xaml 'Controls.xaml';Load-HudSettings $reopened $path
    if($reopened.FindName('FlightDataScale').Value -ne 1.25){throw 'Flight data scale persistence failed'}
}finally{Remove-Item -LiteralPath $path -ErrorAction SilentlyContinue}
Set-FlightDataScale 1
Write-Output 'PASS: shared flight-data scale defaults, uniform center transform and saved setting round-trip'
