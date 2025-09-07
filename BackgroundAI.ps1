<#
.SYNOPSIS
    BackgroundAI - Local ChatGPT-like PowerShell GUI using Ollama's LLaMA 2 model.

.DESCRIPTION
    A Windows PowerShell GUI that provides an AI chat interface.
    Features include:
    - Rich text chat window with color-coded user/AI messages
    - Typing effect for intro messages
    - Code block highlighting in AI responses
    - Save chat logs to file
    - Copy chat log to clipboard

.VERSION
    Alpha v0.1.1

.AUTHOR
    Hotdog Water Industries
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# -------------------------
# Paths & Config
# -------------------------
$scriptRoot   = Split-Path -Parent $MyInvocation.MyCommand.Path
$ollamaExe    = Join-Path $env:LOCALAPPDATA "Programs\Ollama\ollama.exe"
$defaultModel = "llama2:7b"

# -------------------------
# Verify Ollama
# -------------------------
if (-not (Test-Path $ollamaExe)) {
    [System.Windows.Forms.MessageBox]::Show(
        "Ollama CLI not found at:`n$ollamaExe`nPlease install Ollama first.",
        "BackgroundAI - Error"
    )
    exit
}

# -------------------------
# GUI Setup
# -------------------------
$form                  = New-Object System.Windows.Forms.Form
$form.Text             = "BackgroundAI - Alpha v0.1.1"
$form.Size             = New-Object System.Drawing.Size(900,650)
$form.StartPosition    = "CenterScreen"
$form.BackColor        = [System.Drawing.Color]::FromArgb(245,245,245)
$form.Topmost          = $true

$txtOutput             = New-Object System.Windows.Forms.RichTextBox
$txtOutput.Multiline   = $true
$txtOutput.ReadOnly    = $true
$txtOutput.ScrollBars  = "Vertical"
$txtOutput.WordWrap    = $true
$txtOutput.Dock        = 'Top'
$txtOutput.Height      = 400
$txtOutput.BackColor   = [System.Drawing.Color]::WhiteSmoke
$txtOutput.Font        = New-Object System.Drawing.Font("Consolas",10)
$form.Controls.Add($txtOutput)

$txtInput              = New-Object System.Windows.Forms.RichTextBox
$txtInput.Dock         = 'Bottom'
$txtInput.Height       = 100
$txtInput.Font         = New-Object System.Drawing.Font("Consolas",10)
$form.Controls.Add($txtInput)

$panel                 = New-Object System.Windows.Forms.Panel
$panel.Dock            = 'Bottom'
$panel.Height          = 40
$form.Controls.Add($panel)

# -------------------------
# Buttons
# -------------------------
$btnSend               = New-Object System.Windows.Forms.Button
$btnSend.Text          = "Send"
$btnSend.Size          = New-Object System.Drawing.Size(100,30)
$btnSend.Location      = New-Object System.Drawing.Point(10,5)
$btnSend.BackColor     = [System.Drawing.Color]::FromArgb(70,130,180)
$btnSend.ForeColor     = [System.Drawing.Color]::White
$btnSend.FlatStyle     = 'Flat'
$panel.Controls.Add($btnSend)

$btnSave               = New-Object System.Windows.Forms.Button
$btnSave.Text          = "Save Log"
$btnSave.Size          = New-Object System.Drawing.Size(100,30)
$btnSave.Location      = New-Object System.Drawing.Point(120,5)
$btnSave.BackColor     = [System.Drawing.Color]::Gray
$btnSave.ForeColor     = [System.Drawing.Color]::White
$btnSave.FlatStyle     = 'Flat'
$panel.Controls.Add($btnSave)

$btnCopy               = New-Object System.Windows.Forms.Button
$btnCopy.Text          = "Copy AI"
$btnCopy.Size          = New-Object System.Drawing.Size(100,30)
$btnCopy.Location      = New-Object System.Drawing.Point(230,5)
$btnCopy.BackColor     = [System.Drawing.Color]::Gray
$btnCopy.ForeColor     = [System.Drawing.Color]::White
$btnCopy.FlatStyle     = 'Flat'
$panel.Controls.Add($btnCopy)

# -------------------------
# Helper: Append Messages
# -------------------------
function Append-Message {
    param([string]$message, [string]$sender = "BackgroundAI")

    $txtOutput.SelectionStart = $txtOutput.TextLength
    $txtOutput.SelectionLength = 0

    if ($sender -eq "You") {
        # User Message
        $txtOutput.SelectionColor      = [System.Drawing.Color]::White
        $txtOutput.SelectionBackColor  = [System.Drawing.Color]::DodgerBlue
        $txtOutput.SelectionFont       = New-Object System.Drawing.Font("Consolas",10,[System.Drawing.FontStyle]::Bold)
        $txtOutput.AppendText("You:`r`n")
        $txtOutput.SelectionFont       = New-Object System.Drawing.Font("Consolas",10)
        $txtOutput.AppendText("$message`r`n`r`n")
    } else {
        # AI Message (with code block detection)
        $txtOutput.SelectionColor      = [System.Drawing.Color]::Black
        $txtOutput.SelectionBackColor  = [System.Drawing.Color]::LightGreen
        $txtOutput.SelectionFont       = New-Object System.Drawing.Font("Consolas",10,[System.Drawing.FontStyle]::Bold)
        $txtOutput.AppendText("BackgroundAI:`r`n")
        $txtOutput.SelectionFont       = New-Object System.Drawing.Font("Consolas",10)

        $parts = [regex]::Split($message, "(```[\s\S]*?```)")

        foreach ($part in $parts) {
            if ($part -match "^```([\s\S]*?)```$") {
                # Code block formatting
                $code = $matches[1]
                $txtOutput.SelectionBackColor = [System.Drawing.Color]::Gainsboro
                $txtOutput.AppendText("$code`r`n`r`n")
                $txtOutput.SelectionBackColor = [System.Drawing.Color]::LightGreen
            } elseif (-not [string]::IsNullOrWhiteSpace($part)) {
                $txtOutput.AppendText("$part`r`n`r`n")
            }
        }
    }

    $txtOutput.SelectionStart = $txtOutput.Text.Length
    $txtOutput.ScrollToCaret()
}

# -------------------------
# Typing Effect
# -------------------------
function Append-Message-Typing {
    param([string]$message, [string]$sender = "BackgroundAI", [int]$delay = 20)

    $txtOutput.SelectionStart = $txtOutput.TextLength
    $txtOutput.SelectionLength = 0

    if ($sender -eq "You") {
        $txtOutput.SelectionColor      = [System.Drawing.Color]::White
        $txtOutput.SelectionBackColor  = [System.Drawing.Color]::DodgerBlue
        $txtOutput.SelectionFont       = New-Object System.Drawing.Font("Consolas",10,[System.Drawing.FontStyle]::Bold)
        $txtOutput.AppendText("You:`r`n")
        $txtOutput.SelectionFont       = New-Object System.Drawing.Font("Consolas",10)
    } else {
        $txtOutput.SelectionColor      = [System.Drawing.Color]::Black
        $txtOutput.SelectionBackColor  = [System.Drawing.Color]::LightGreen
        $txtOutput.SelectionFont       = New-Object System.Drawing.Font("Consolas",10,[System.Drawing.FontStyle]::Bold)
        $txtOutput.AppendText("BackgroundAI:`r`n")
        $txtOutput.SelectionFont       = New-Object System.Drawing.Font("Consolas",10)
    }

    foreach ($char in $message.ToCharArray()) {
        $txtOutput.AppendText($char)
        Start-Sleep -Milliseconds $delay
        $txtOutput.SelectionStart = $txtOutput.Text.Length
        $txtOutput.ScrollToCaret()
    }
    $txtOutput.AppendText("`r`n`r`n")
}

# -------------------------
# Core Send Function
# -------------------------
function Send-Message {
    $userText = $txtInput.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($userText)) { return }

    Append-Message -message $userText -sender "You"
    $txtInput.Clear()

    try {
        $response = & $ollamaExe run $defaultModel "$userText"
        if ([string]::IsNullOrWhiteSpace($response)) {
            Append-Message -message "⚠️ No response from Ollama." -sender "BackgroundAI"
        } else {
            Append-Message -message $response -sender "BackgroundAI"
        }
    }
    catch {
        Append-Message -message "❌ Error: Could not get response from Ollama.`r`n$_" -sender "BackgroundAI"
    }
}

# -------------------------
# Button Actions
# -------------------------
$btnSend.Add_Click({ Send-Message })
$txtInput.Add_KeyDown({
    param($s,$e)
    if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Enter -and -not $e.Shift) {
        Send-Message
        $e.SuppressKeyPress = $true
    }
})
$btnSave.Add_Click({
    $logFile = Join-Path $scriptRoot "chat_log.txt"
    $txtOutput.Text | Out-File $logFile -Encoding UTF8
    [System.Windows.Forms.MessageBox]::Show("Log saved to $logFile","Saved")
})
$btnCopy.Add_Click({
    [System.Windows.Forms.Clipboard]::SetText($txtOutput.Text)
    [System.Windows.Forms.MessageBox]::Show("Chat log copied to clipboard","Copied")
})

# -------------------------
# Startup Message
# -------------------------
Append-Message-Typing -message "Hello! I'm BackgroundAI, your local assistant. How can I help you today?" -sender "BackgroundAI" -delay 20

# -------------------------
# Run
# -------------------------
[void]$form.ShowDialog()
