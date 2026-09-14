# Generate white 'down-arrow into base' PNG for the title-bar button. (ASCII only)
$ErrorActionPreference = 'Stop'
$outDir = $PSScriptRoot

Add-Type -AssemblyName System.Drawing

$cs = @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;

public static class BtnIcon
{
    static readonly Color White = Color.FromArgb(255, 236, 237, 240); // MainBrush #ECEDF0, matches other title-bar glyphs

    static GraphicsPath RoundedRect(float x, float y, float w, float h, float r)
    {
        var p = new GraphicsPath();
        float d = 2 * r;
        p.AddArc(x, y, d, d, 180, 90);
        p.AddArc(x + w - d, y, d, d, 270, 90);
        p.AddArc(x + w - d, y + h - d, d, d, 0, 90);
        p.AddArc(x, y + h - d, d, d, 90, 90);
        p.CloseFigure();
        return p;
    }

    public static Bitmap Draw(int size)
    {
        var bmp = new Bitmap(size, size, PixelFormat.Format32bppArgb);
        using (var g = Graphics.FromImage(bmp))
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            g.Clear(Color.Transparent);
            float s = size / 256f;
            using (var brush = new SolidBrush(White))
            {
                using (var shaft = RoundedRect(112 * s, 40 * s, 32 * s, 108 * s, 16 * s))
                    g.FillPath(brush, shaft);
                PointF[] head =
                {
                    new PointF(72 * s, 148 * s),
                    new PointF(184 * s, 148 * s),
                    new PointF(128 * s, 204 * s)
                };
                g.FillPolygon(brush, head);
                using (var tray = RoundedRect(48 * s, 196 * s, 160 * s, 32 * s, 16 * s))
                    g.FillPath(brush, tray);
            }
        }
        return bmp;
    }
}
'@

Add-Type -TypeDefinition $cs -ReferencedAssemblies System.Drawing

$sz = 128
$bmp = [BtnIcon]::Draw($sz)
$out = Join-Path $outDir '..\..\src\Assets\tray_btn.png'
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Host "wrote $out"