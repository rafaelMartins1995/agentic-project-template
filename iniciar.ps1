[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$RootDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ClaudeCommand = if ($env:AGENTIC_CLAUDE_BIN) { $env:AGENTIC_CLAUDE_BIN } else { 'claude' }

if (-not (Get-Command $ClaudeCommand -ErrorAction SilentlyContinue)) {
    Write-Host 'Claude Code não foi encontrado. Nenhuma alteração foi realizada.'
    Write-Host ''
    Write-Host 'Instalação oficial:'
    Write-Host '  Windows PowerShell: irm https://claude.ai/install.ps1 | iex'
    Write-Host '  Windows WinGet: winget install Anthropic.ClaudeCode'
    Write-Host ''
    Write-Host 'Documentação: https://code.claude.com/docs/en/setup'
    Write-Host ''
    Write-Host 'Depois de instalar e autenticar, execute novamente: .\iniciar.ps1'
    exit 2
}

Set-Location $RootDir

Write-Host 'Verificando o plugin Superpowers...'
$PluginList = (& $ClaudeCommand plugin list 2>$null | Out-String)
if ($PluginList -match '(?i)superpowers') {
    Write-Host 'Superpowers já está instalado.'
} else {
    & $ClaudeCommand plugin install superpowers@claude-plugins-official --scope user
    if ($LASTEXITCODE -ne 0) {
        Write-Error 'Não foi possível instalar o Superpowers. Execute claude doctor e tente novamente.'
        exit 3
    }
}

Write-Host 'Abrindo a entrevista de inicialização...'
& $ClaudeCommand --name setup-projeto 'Leia prompts/INICIAR_PROJETO.md e conduza a entrevista agora. Siga AGENTS.md. Faça uma pergunta por vez, em português do Brasil. Não crie código do produto.'
exit $LASTEXITCODE
