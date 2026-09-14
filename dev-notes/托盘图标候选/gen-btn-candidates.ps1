# Generate a preview strip of button-icon candidates (hide/to-tray theme), MainBrush color.
$ErrorActionPreference = 'Stop'
$outDir = $PSScriptRoot
Add-Type -AssemblyName System.Drawing

$cs = @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Collections.Generic;

public static class BtnCands
{
    static readonly Color Main = Color.FromArgb(255, 236, 237, 240); // #ECEDF0

    static GraphicsPath RR(float x, float y, float w, float h, float r)
    {
        var p = new GraphicsPath();
        float d = 2*r;
        p.AddArc(x,y,d,d,180,90); p.AddArc(x+w-d,y,d,d,270,90);
        p.AddArc(x+w-d,y+h-d,d,d,0,90); p.AddArc(x,y+h-d,d,d,90,90);
        p.CloseFigure(); return p;
    }
    static void Tri(Graphics g, Brush b, float s, float x1,float y1,float x2,float y2,float x3,float y3)
        { g.FillPolygon(b, new[] { new PointF(x1*s,y1*s), new PointF(x2*s,y2*s), new PointF(x3*s,y3*s) }); }
    static void Box(Graphics g, Brush b, float s, float x,float y,float w,float h,float r)
        { g.FillPath(b, RR(x*s,y*s,w*s,h*s,r*s)); }

    static Bitmap NewCanvas(int size){ var b=new Bitmap(size,size,PixelFormat.Format32bppArgb); using(var g=Graphics.FromImage(b)){ g.Clear(Color.Transparent);} return b; }
    static Graphics G(Bitmap b){ var g=Graphics.FromImage(b); g.SmoothingMode=SmoothingMode.AntiAlias; g.PixelOffsetMode=PixelOffsetMode.HighQuality; return g; }

    // 1: down arrow into U-shaped tray (tray open at top)
    public static Bitmap C1(int size){
        var b=NewCanvas(size); var g=G(b); var br=new SolidBrush(Main); float s=size/256f;
        Box(g,br,s,112,56,32,92,15); Tri(g,br,s,74,150,182,150,128,198);
        Box(g,br,s,54,202,16,28,8); Box(g,br,s,186,202,16,28,8); Box(g,br,s,46,222,164,18,9);
        br.Dispose(); g.Dispose(); return b;
    }
    // 2: down arrow onto double base bars
    public static Bitmap C2(int size){
        var b=NewCanvas(size); var g=G(b); var br=new SolidBrush(Main); float s=size/256f;
        Box(g,br,s,112,44,32,96,15); Tri(g,br,s,74,148,182,148,128,194);
        Box(g,br,s,48,206,160,20,10); Box(g,br,s,48,234,160,13,7);
        br.Dispose(); g.Dispose(); return b;
    }
    // 3: down arrow onto single tray bar (minimize to a line)
    public static Bitmap C3(int size){
        var b=NewCanvas(size); var g=G(b); var br=new SolidBrush(Main); float s=size/256f;
        Box(g,br,s,112,52,32,88,15); Tri(g,br,s,76,148,180,148,128,192);
        Box(g,br,s,48,200,160,18,9);
        br.Dispose(); g.Dispose(); return b;
    }
    // 4: down arrow onto half-disc tray base
    public static Bitmap C4(int size){
        var b=NewCanvas(size); var g=G(b); var br=new SolidBrush(Main); float s=size/256f;
        Box(g,br,s,112,44,32,96,15); Tri(g,br,s,74,148,182,148,128,194);
        Box(g,br,s,48,190,160,48,24);
        br.Dispose(); g.Dispose(); return b;
    }
    // 5: down arrow into flat base (the current button shape)
    public static Bitmap C5(int size){
        var b=NewCanvas(size); var g=G(b); var br=new SolidBrush(Main); float s=size/256f;
        Box(g,br,s,112,40,32,108,16); Tri(g,br,s,72,148,184,148,128,204);
        Box(g,br,s,48,196,160,32,16);
        br.Dispose(); g.Dispose(); return b;
    }

    public static Bitmap Strip(){
        int cell=128, pad=20, gap=8, n=5;
        int w = n*(cell+2*gap), h = cell+pad;
        var b = new Bitmap(w,h,PixelFormat.Format32bppArgb);
        var g = G(b);
        g.Clear(Color.FromArgb(255,43,47,56)); // NeuSurface backdrop
        Bitmap[] imgs = { C1(cell), C2(cell), C3(cell), C4(cell), C5(cell) };
        for(int i=0;i<n;i++){
            int cx = gap + i*(cell+2*gap);
            g.DrawImage(imgs[i], (float)cx, (float)(pad*0.15f), (float)cell, (float)cell);
            // number label
            var f = new Font("Segoe UI", 15f, FontStyle.Bold);
            var lab = (i+1).ToString();
            var sz = g.MeasureString(lab, f);
            g.DrawString(lab, f, new SolidBrush(Color.FromArgb(255,154,160,170)), (float)(cx+cell/2-sz.Width/2), (float)(cell+ (float)pad*0.15f - 4));
            f.Dispose();
            imgs[i].Dispose();
        }
        g.Dispose();
        return b;
    }
}
'@

Add-Type -TypeDefinition $cs -ReferencedAssemblies System.Drawing

$bmp = [BtnCands]::Strip()
$out = Join-Path $outDir 'btn_candidates.png'
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Host "wrote $out"