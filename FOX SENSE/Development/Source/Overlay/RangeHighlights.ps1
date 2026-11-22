function Update-RangeHighlights {
    foreach($group in @(@('Range',[int]$controls.FindName('DatalinkRange').SelectedValue),@('LaunchRange',[int]$controls.FindName('LaunchWarningRangeNm').Value))){
        foreach($nm in @(20,40,60)){
            $button=$controls.FindName($group[0]+$nm)
            $selected=$nm -eq $group[1]
            $button.Background=if($selected){'#237B9C'}else{'#1A3046'}
            $button.BorderBrush=if($selected){'#8AE6FF'}else{'#48667D'}
            $button.FontWeight=if($selected){'SemiBold'}else{'Normal'}
        }
    }
}
