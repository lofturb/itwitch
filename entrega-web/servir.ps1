<#
.SYNOPSIS
    Sirve la carpeta entrega-web por HTTP para instalar iTwitch desde el iPad.

.DESCRIPTION
    Hace lo mismo que el servidor de Tube9: abre un servidor HTTP plano en el
    puerto 80 (o 8080 si el 80 esta ocupado) sirviendo esta misma carpeta.
    Desde Safari del dispositivo se abre http://IP-DEL-PC/ y se tocan las dos
    tarjetas: primero los certificados, luego el .ipa.

    No hace falta instalar nada: usa Python 3, que ya viene en el sistema.

.EJEMPLO
    powershell -ExecutionPolicy Bypass -File servir.ps1
    powershell -ExecutionPolicy Bypass -File servir.ps1 -Puerto 8080
#>

param(
    [int]$Puerto = 80
)

$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $MyInvocation.MyCommand.Path

# --- IP local del PC (compatible con Windows 7) ---
function Get-IPLocal {
    $entrada = [System.Net.Dns]::GetHostEntry([System.Net.Dns]::GetHostName())
    foreach ($dir in $entrada.AddressList) {
        if ($dir.AddressFamily -eq 'InterNetwork' -and $dir.IPAddressToString -notmatch '^127\.') {
            return $dir.IPAddressToString
        }
    }
    return '127.0.0.1'
}

# --- Comprobar si un puerto se puede abrir ---
function Test-PuertoLibre([int]$p) {
    $escucha = $null
    try {
        $escucha = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $p)
        $escucha.Start()
        return $true
    } catch {
        return $false
    } finally {
        if ($escucha) { $escucha.Stop() }
    }
}

$ip = Get-IPLocal

if (-not (Test-PuertoLibre $Puerto)) {
    Write-Host "El puerto $Puerto esta ocupado; se usara el 8080." -ForegroundColor Yellow
    $Puerto = 8080
}

# --- Comprobar que estan los ficheros ---
$ipa = Join-Path $raiz 'entrega\iTwitch.ipa'
$perfil = Join-Path $raiz 'certificados\CertificadosModernos.mobileconfig'
if (-not (Test-Path $ipa)) {
    Write-Host "Falta el fichero: $ipa" -ForegroundColor Red
    Write-Host "Copialo desde dist\iTwitch-1.0.0-full.ipa" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $perfil)) {
    Write-Host "Falta el fichero: $perfil" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "  iTwitch - servidor de entrega" -ForegroundColor Magenta
Write-Host "  " + ("-" * 52)
Write-Host "  Carpeta         $raiz"
Write-Host "  En este PC      http://127.0.0.1:$Puerto/"
Write-Host "  En el iPad      http://${ip}:$Puerto/" -ForegroundColor Green
Write-Host "  " + ("-" * 52)
Write-Host "  1. Conecta el iPad a la misma WiFi que este PC."
Write-Host "  2. Abre Safari y entra en la direccion verde."
Write-Host "  3. Toca PASO 1 (certificados) e instalalo en Ajustes."
Write-Host "  4. Toca PASO 2 (iTwitch.ipa) y abrelo con Filza."
Write-Host "  " + ("-" * 52)
Write-Host "  Deja esta ventana abierta. Para parar: Ctrl+C"
Write-Host ""

Set-Location $raiz
python servir.py --puerto $Puerto
