# Disk listesi dosyasi
$diskListFile = "s_disk"

if (-not (Test-Path $diskListFile)) {
    Write-Error "Disk listesi dosyasi bulunamadi: $diskListFile"
    exit 1
}

# Diskleri oku
Get-Content $diskListFile | ForEach-Object {

    $disk = $_.Trim()

    # Bos satir kontrolu
    if ([string]::IsNullOrWhiteSpace($disk)) {
        return
    }

    Write-Host "SMART verisi aliniyor: $disk"

    try {
        # SMART JSON al
        $jsonText = smartctl --json --all $disk 2>$null
        if (-not $jsonText) {
            Write-Warning "SMART verisi alinamadi: $disk"
            return
        }

        $json = $jsonText | ConvertFrom-Json

        # Seri numarasi (fallback destekli)
        $serial = $json.serial_number
        if (-not $serial) {
            $serial = $json.device.serial_number
        }

        if (-not $serial) {
            Write-Warning "Seri numarasi okunamadi: $disk"
            return
        }

        # UNIX timestamp (UTC)
        $timestamp = [int][double]::Parse(
            (Get-Date -Date (Get-Date).ToUniversalTime() -UFormat %s)
        )

        # Dosya adi
        $fileName = "${timestamp}_${serial}_SMART.json"

        # JSON'u yaz
        $jsonText | Out-File -Encoding utf8 $fileName

        Write-Host "Kaydedildi -> $fileName"

    } catch {
        Write-Warning "Hata olustu ($disk): $_"
    }
}

Write-Host "Tum diskler icin islem tamamlandi."