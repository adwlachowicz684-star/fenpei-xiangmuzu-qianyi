# 生成「向下箭头入底座」托盘图标（多尺寸 .ico + PNG 预览）
# 用法: powershell -ExecutionPolicy Bypass -File gen-tray-icon.ps1
# 输出: tray.ico（多尺寸）+ preview_*.png（各尺寸预览）
$ErrorActionPreference = 'Stop'
$outDir = $PSScriptRoot

Add-Type -AssemblyName System.Drawing

$cs = @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;

public static class TrayIconGen
{
    // 主设计（256x256 坐标）：
    //   箭头杆: 圆角矩形 x[112,144] y[40,148]
    //   箭头尖: 三角形 (72,148) (184,148) (128,204)
    //   底座托盘: 圆角矩形 x[48,208] y[196,228]
    static readonly Color Accent = Color.FromArgb(255, 59, 130, 246); // #3B82F6

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
            using (var brush = new SolidBrush(Accent))
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

    public static void SaveIco(string path, int[] sizes)
    {
        var blobs = new byte[sizes.Length][];
        var offsets = new int[sizes.Length];
        int count = sizes.Length;
        int dataOffset = 6 + 16 * count;

        for (int i = 0; i < count; i++)
        {
            using (var bmp = Draw(sizes[i]))
            using (var ms = new MemoryStream())
            {
                bmp.Save(ms, ImageFormat.Png);
                blobs[i] = ms.ToArray();
            }
            offsets[i] = dataOffset;
            dataOffset += blobs[i].Length;
        }

        using (var fs = File.Create(path))
        using (var bw = new BinaryWriter(fs))
        {
            bw.Write((ushort)0);        // reserved
            bw.Write((ushort)1);        // type = icon
            bw.Write((ushort)count);    // image count

            for (int i = 0; i < count; i++)
            {
                int sz = sizes[i];
                bw.Write((byte)(sz >= 256 ? 0 : sz)); // width
                bw.Write((byte)(sz >= 256 ? 0 : sz)); // height
                bw.Write((byte)0);                    // color count
                bw.Write((byte)0);                    // reserved
                bw.Write((ushort)1);                  // planes
                bw.Write((ushort)32);                 // bit count
                bw.Write((uint)blobs[i].Length);      // bytes in res
                bw.Write((uint)offsets[i]);           // offset
            }

            for (int i = 0; i < count; i++)
                bw.Write(blobs[i]);
        }
    }
}
'@

Add-Type -TypeDefinition $cs -ReferencedAssemblies System.Drawing

$sizes = @(16, 24, 32, 48, 64, 128, 256)
foreach ($sz in $sizes) {
    $bmp = [TrayIconGen]::Draw($sz)
    $pngPath = Join-Path $outDir ("preview_{0}.png" -f $sz)
    $bmp.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

$icoPath = Join-Path $outDir 'tray.ico'
[TrayIconGen]::SaveIco($icoPath, $sizes)
Write-Host "已生成: $icoPath ($($sizes.Count) 个尺寸: $($sizes -join ', '))"
