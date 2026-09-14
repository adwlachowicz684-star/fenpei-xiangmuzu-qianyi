# Generate final button icon: down arrow into a right-angle U-shaped tray. (ASCII only)
$ErrorActionPreference = 'Stop'
$outDir = $PSScriptRoot
Add-Type -AssemblyName System.Drawing

$cs = @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;

public static class BtnFinal
{
    static readonly Color Main = Color.FromArgb(255, 236, 237, 240); // #ECEDF0

    static GraphicsPath RR(float x, float y, float w, float h, float r)
    {
        var p = new GraphicsPath();
        if (r <= 0f) { p.AddRectangle(new RectangleF(x,y,w,h)); p.CloseFigure(); return p; }
        float d = 2*r;
        p.AddArc(x,y,d,d,180,90); p.AddArc(x+w-d,y,d,d,270,90);
        p.AddArc(x+w-d,y+h-d,d,d,0,90); p.AddArc(x,y+h-d,d,d,90,90);
        p.CloseFigure(); return p;
    }

    public static Bitmap Draw(int size)
    {
        var bmp = new Bitmap(size,size,PixelFormat.Format32bppArgb);
        using (var g = Graphics.FromImage(bmp))
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            g.Clear(Color.Transparent);
            float s = size/256f;
            using (var br = new SolidBrush(Main))
            {
                // arrow shaft
                g.FillPath(br, RR(112*s, 52*s, 32*s, 88*s, 15*s));
                // arrow head
                g.FillPolygon(br, new[] { new PointF(76*s,150*s), new PointF(180*s,150*s), new PointF(128*s,192*s) });
                // U tray : right-angle, no rounded bulge on legs/bottom
                g.FillPath(br, RR(50*s, 204*s, 16*s, 32*s, 0f));  // left leg
                g.FillPath(br, RR(190*s, 204*s, 16*s, 32*s, 0f)); // right leg
                g.FillPath(br, RR(50*s, 220*s, 156*s, 16*s, 0f)); // bottom bar (90 deg joints)
            }
        }
        return bmp;
    }
}
'@

Add-Type -TypeDefinition $cs -ReferencedAssemblies System.Drawing

$sz = 128
$bmp = [BtnFinal]::Draw($sz)
$out = Join-Path $outDir '..\..\src\Assets\tray_btn.png'
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Host "wrote tray_btn.png"