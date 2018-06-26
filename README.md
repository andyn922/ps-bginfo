# PS BGInfo lite
Draw static text on a static image with .NET and Powershell - BGINFO NOT REQUIRED

>All credit to u/xbullet ([original post](https://www.reddit.com/r/PowerShell/comments/8tu8vs/script_share_implementing_bginfo_in_powershell/))  
>This will definately come in useful! maybe some day i'll modify it.

## Examples

```Powershell
. .\ps-bginfo.ps1

$ci = @{
  "Date" = [PSObject]@{Text = $(Get-Date)}
  "PC Name" = [PSObject]@{Text = $env:COMPUTERNAME}
}

Add-BGInfo -SrcImage "sample-image.jpg" `
  -DestImage "sample-image-edit.jpg" `
  -TitleMessage "A Nice Title" `
  -ComputerInfo $ci
```
