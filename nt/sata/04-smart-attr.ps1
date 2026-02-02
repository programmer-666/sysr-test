# Disk listesi dosyasi
$diskListFile = "s_disk"

if (-not (Test-Path $diskListFile)) {
    Write-Error "Disk listesi dosyasi bulunamadi: $diskListFile"
    exit 1
}

# Diskleri oku
Get-Content $diskListFile | ForEach-Object {

    $disk = $_.Trim()

    # Bos satir atla
    if ([string]::IsNullOrWhiteSpace($disk)) {
        return
    }

    Write-Host "SMART attribute'lari aliniyor: $disk"

    try {
        # SMART JSON al
        $jsonText = smartctl --json --all $disk 2>$null
        if (-not $jsonText) {
            Write-Warning "SMART verisi alinamadi: $disk"
            return
        }

        $json = $jsonText | ConvertFrom-Json

        # Seri numarasi (fallback'li)
        $serial = $json.serial_number
        if (-not $serial) {
            $serial = $json.device.serial_number
        }

        if (-not $serial) {
            Write-Warning "Seri numarasi okunamadi: $disk"
            return
        }

        # ATA SMART attribute kontrolu
        if (-not $json.ata_smart_attributes.table) {
            Write-Warning "ATA SMART attribute bulunamadi: $disk"
            return
        }

        # Seri numarasi klasoru
        $serialDir = Join-Path -Path (Get-Location) -ChildPath $serial
        if (-not (Test-Path $serialDir)) {
            New-Item -ItemType Directory -Path $serialDir | Out-Null
        }

        # UNIX timestamp (UTC)
        $timestamp = [int][double]::Parse(
            (Get-Date -Date (Get-Date).ToUniversalTime() -UFormat %s)
        )

        # CSV dosya yolu
        $csvFilePath = Join-Path $serialDir "${timestamp}_ATTR.csv"

        # Attribute'lari CSV objesine cevir
        $csvData = $json.ata_smart_attributes.table | ForEach-Object {
            [PSCustomObject]@{
                Attribute_ID   = $_.id
                Attribute_Name = $_.name
                Value          = $_.value
                Worst          = $_.worst
                Thresh         = $_.thresh
                Type           = $_.type
                Updated        = $_.updated
                When_Failed    = $_.when_failed
                Raw_Value      = $_.raw.value
            }
        }

        # CSV yaz
        $csvData | Export-Csv -Path $csvFilePath -NoTypeInformation -Encoding UTF8

        Write-Host "Kaydedildi -> $csvFilePath"

    } catch {
        Write-Warning "Hata olustu ($disk): $_"
    }
}

Write-Host "Tum diskler icin islem tamamlandi."
