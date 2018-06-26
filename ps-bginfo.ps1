<#
.SYNOPSIS
    Render information on Windows lock screens or desktop background image. Intended to be similar to BGInfo (SysInternalsSuite) using .NET and Powershell
   
.DESCRIPTION
    The Add-BGInfo function uses .NET classes/assemblies to render dynamic content over a static image. 
    Intended to render use or diagnostic information on top of the Windows lock screen or desktop background image for a workstation or server.

.PARAMETER SrcImage
    The path of the image to manipulate.

.PARAMETER DestImage
    The path to save the manipulated image.

.PARAMETER TitleMessage
    The title string to render above the description box.

.PARAMETER ComputerInfo
    A hashtable of PSCustomObjects containing the information to display.

    $ComputerInfoText = [Hashtable]@{
        Hostname          = [PSCustomObject] @{ Text = $Hostname }
        IP                = [PSCustomObject] @{ Text = $IP }
        Room              = [PSCustomObject] @{ Text = $OU }
        TrustRelationship = [PSCustomObject] @{ Text = $TrustRelationshipStatus }
    }

.EXAMPLE 
    # Initialise hashtable 
    $ComputerInfoText = [Hashtable]@{
        Hostname          = [PSCustomObject] @{ Text = "server1" }
        IP                = [PSCustomObject] @{ Text = "192.168.1.20" }
        Location          = [PSCustomObject] @{ Text = "DC01" }
        TrustRelationship = [PSCustomObject] @{ Text = "True" }
    }

    # Initialise optional TitleMessage
    $TitleMessage = "A title message to display."

    # Append data to new image
    Add-BGInfo -SrcImage ".\background1920x1080.jpg" -DestImage ".\background1920x1080-edit.jpg" -ComputerInfo $ComputerInfoText -TitleMessage $TitleMessage

.NOTES
    Author: Stephen Mills
    Version: 1.0
    Date: 21/06/2018

    Misc: 
        Requires .NET Framework

    TODO:
        - Provide regions to render to as a parameter (ie: bottom left, top right, etc)
        - Accept offset as an optional parameter

    LICENSE:
        This project is licensed under the terms of the MIT license.

        Copyright (c) 2018 Stephen Mills

        Permission is hereby granted, free of charge, to any person obtaining a copy
        of this software and associated documentation files (the "Software"), to deal
        in the Software without restriction, including without limitation the rights
        to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
        copies of the Software, and to permit persons to whom the Software is
        furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all
        copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
        IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
        FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
        AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
        LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
        OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
        SOFTWARE.
#>

Function Add-BGInfo {
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory = $true)][String] $SrcImage,
        [Parameter(Mandatory = $true)][String] $DestImage,
        [Parameter()][String] $TitleMessage = $null,
        [Parameter()][Hashtable] $ComputerInfo = $null
    )
 
    # Lockscreen offset (to deal with Windows 10 zooming on lock screen)
    $XOffset = 18
    $YOffset = 12

    # Load image
    [Reflection.Assembly]::LoadWithPartialName("System.Drawing") | Out-Null
    $SrcImg = [System.Drawing.Image]::FromFile($SrcImage)
    $ImgFile = new-object System.Drawing.Bitmap([int]($SrcImg.width)), ([int]($SrcImg.height))
    $Image = [System.Drawing.Graphics]::FromImage($ImgFile)
    
    # Set image and encoder quality
    $Image.SmoothingMode = "HighQuality"
    $MyEncoder = [System.Drawing.Imaging.Encoder]::Quality
    $EncoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
    $EncoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter($MyEncoder, 100)
    $ImageCodecInfo = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object {$_.MimeType -eq 'image/jpeg'}
    
    # Draw original image
    $Rectangle = New-Object Drawing.Rectangle 0, 0, $SrcImg.Width, $SrcImg.Height
    $Image.DrawImage($SrcImg, $Rectangle, 0, 0, $SrcImg.Width, $SrcImg.Height, ([Drawing.GraphicsUnit]::Pixel))

    # Initialise fonts
    $ComputerInfoFontSize = 8
    $ComputerInfoFont = New-Object System.Drawing.Font("Helvetica", $ComputerInfoFontSize)
    $ComputerInfoTitleFontSize = 12
    $ComputerInfoTitleFont = New-Object System.Drawing.Font("Helvetica", $ComputerInfoTitleFontSize)

    # Initialise brushes
    $RectBrush = New-Object Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 0, 0, 0)) 
    $CompInfoBrush = New-Object Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 57, 255, 20))

    # Calculate Key and Value string size
    $ComputerInfo.Keys | ForEach-Object { 
        $_currItem = $_
        $ComputerInfo.Item($_currItem) | Add-Member -NotePropertyName "KeyDimensions" -NotePropertyValue $Image.MeasureString($_currItem, $ComputerInfoFont)
        $ComputerInfo.Item($_currItem) | Add-Member -NotePropertyName "ValueDimensions" -NotePropertyValue $Image.MeasureString($ComputerInfo.Item($_currItem).Text, $ComputerInfoFont)
        $ComputerInfo.Item($_currItem) | Add-Member -NotePropertyName "CombinedWidth" -NotePropertyValue $CombinedWidth
        $CombinedWidth = $ComputerInfo.Item($_currItem).KeyDimensions.Width + $ComputerInfo.Item($_currItem).ValueDimensions.Width
    }

    # Fetch max string sizes
    # $maxCombined = $ComputerInfo.GetEnumerator() | Sort-Object { $_.Value.CombinedWidth } -Descending | Select-Object -First 1
    $MaxKey = $ComputerInfo.GetEnumerator() | Sort-Object { $_.Value.KeyDimensions.Width } -Descending | Select-Object -First 1
    $MaxValue = $ComputerInfo.GetEnumerator() | Sort-Object { $_.Value.ValueDimensions.Width } -Descending | Select-Object -First 1
    
    # Dimensions and position
    $BoxHeight += $MaxValue.Value.KeyDimensions.Height * $ComputerInfo.Count
    $BoxWidth = $MaxKey.Value.KeyDimensions.Width + $MaxValue.Value.ValueDimensions.Width
    $BoxPosX = 0 + $XOffset # Default to 0 for X-position
    $BoxPosY = $SrcImg.Height - $BoxHeight - $YOffset # Calculate Y-position

    # Draw bounding rectangle
    $Image.FillRectangle($RectBrush, $BoxPosX, $BoxPosY, $BoxWidth, $BoxHeight);

    # Set content X and Y positions
    $cPosX = $BoxPosX
    $cPosY = $BoxPosY

    # Draw title message
    if ($TitleMessage) {
        $RectangleF = New-Object Drawing.RectangleF($BoxPosX, ($BoxPosY - $Image.MeasureString($TitleMessage, $ComputerInfoTitleFont).Height -1), $Image.MeasureString($TitleMessage, $ComputerInfoTitleFont).Width, $Image.MeasureString($TitleMessage, $ComputerInfoTitleFont).Height)
        $Image.FillRectangle($RectBrush, [System.Drawing.Rectangle]::Round($RectangleF));
        $Image.DrawString($TitleMessage, $ComputerInfoTitleFont, $CompInfoBrush, $RectangleF);
    }

    # Draw each Key -> Value pair
    $ComputerInfo.GetEnumerator() | ForEach-Object {
        $Image.DrawString($_.Key, $ComputerInfoFont, $CompInfoBrush, $cPosX, $cPosY)
        $Image.DrawString($_.Value.Text, $ComputerInfoFont, $CompInfoBrush, $MaxKey.Value.KeyDimensions.Width + $cPosX + $OffsetX, $cPosY)
        $cPosY += $_.Value.KeyDimensions.Height
    }

    # Save new image and dispose of in-memory images.
    $ImgFile.save($DestImage, $ImageCodecInfo, $($EncoderParams))
    $ImgFile.Dispose()
    $SrcImg.Dispose()
}
