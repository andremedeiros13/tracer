# Tracker

> 🔔 Painel de To-Do com **notificações nativas do sistema** — para quebrar o
> hiperfoco e lembrar das pendências que importam.

O Tracker roda como um **daemon no seu computador**: um processo de fundo que lembra
você das suas pendências via **notificações nativas** (Linux, macOS, Windows) e serve
um **painel no browser** com a *fila de atenção* — suas pendências ordenadas pelo que
vence primeiro.

---

## ✅ Pré-requisitos

| Requisito | Como verificar |
|---|---|
| **Ruby 4.x** | `ruby --version` → precisa mostrar `4.0.x` ou superior |
| **Linux**: `notify-send` | `which notify-send` (já vem na maioria das distros) |

<details>
<summary><b>Instalar o Ruby (só se você não tiver)</b></summary>

- **Linux (Debian/Ubuntu)**: `sudo apt install ruby-full`
- **macOS**: `brew install ruby` (ou use `asdf`/`rbenv`)
- **Windows**: [RubyInstaller](https://rubyinstaller.org/) (versão + Devkit)

</details>

---

## 🚀 Instalação (2 passos)

```bash
# 1. Clone o repositório
git clone git@github.com:andremedeiros13/tracker.git
cd tracker

# 2. Setup — instala gems, prepara o banco e testa as notificações
bin/setup
```

O `bin/setup` faz tudo: instala as dependências, prepara o banco SQLite com tarefas
de exemplo, e **dispara uma notificação de teste** — se ela aparecer no seu sistema,
tudo certo. (No macOS/Windows, conceda a permissão quando o S.O. perguntar.)

## ▶️ Execução

```bash
bin/start
```

Abra **http://localhost:3000** — o painel com a fila de atenção. O daemon fica
rodando em segundo plano e dispara o lembrete no intervalo configurado
(padrão: a cada 45 min, das 09:00 às 18:00).

O painel mostra:

- 🔔 **Fila de atenção** — pendências ordenadas pelo que vence primeiro
- **Ações por item** — Concluir ou Adiar 1h (adiar silencia o lembrete; a tarefa
  continua na fila até ser concluída)
- **Origem das tarefas** — manual, via Jira ou de transcrição de 1-on-1
  (na POC, tarefas de exemplo; as integrações vêm depois)
- **Configuração de lembretes** — frequência e período ativo, embutidos no painel

---

## 🖥️ Rodar no login (opcional, recomendado)

Se o daemon não sobe no login, você precisa lembrar de iniciar — o que mata o
propósito. Registre-o para iniciar sozinho:

<details>
<summary><b>Linux (systemd user unit)</b></summary>

```bash
cp dist/tracker.service ~/.config/systemd/user/
# Ajuste o WorkingDirectory no arquivo se o repo não estiver em ~/Repositories/tracker
systemctl --user daemon-reload
systemctl --user enable --now tracker.service

# (opcional) fazer o daemon sobreviver ao logout:
sudo loginctl enable-linger $USER
```

Logs: `journalctl --user -u tracker.service -f`

</details>

<details>
<summary><b>macOS (LaunchAgent)</b></summary>

Crie `~/Library/LaunchAgents/com.tracker.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.tracker</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/zsh</string>
    <string>-c</string>
    <string>cd ~/Repositories/tracker &amp;&amp; ./bin/start</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
</dict>
</plist>
```

```bash
launchctl load ~/Library/LaunchAgents/com.tracker.plist
```

</details>

<details>
<summary><b>Windows (Tarefa agendada)</b></summary>

No PowerShell (como seu usuário):

```powershell
$action = New-ScheduledTaskAction -Execute "powershell" `
  -Argument "-NoProfile -Command cd $HOME\Repositories\tracker; ./bin/start"
$trigger = New-ScheduledTaskTrigger -AtLogOn
Register-ScheduledTask -TaskName "Tracker" -Action $action -Trigger $trigger
```

</details>

---

## 🧪 Qualidade (para contribuir)

```bash
bundle exec rubocop        # lint + formatação
bundle exec rspec          # specs
bundle exec brakeman       # security scan
```

Veja [CONTRIBUTING.md](CONTRIBUTING.md) para a estrutura do código.

## 🗺️ O projeto

- **Decisões e roadmap**: [wayfinder map](https://github.com/andremedeiros13/tracker/issues/1)
  (issues do repo) e [spec da POC](.scratch/wayfinder-tracker/spec.md)
- **Módulos futuros** (após a validação da POC): rastreio de entregas
  (Jira + commits/PRs) e parsing de transcrições de 1-on-1
- **Sem IA/LLM**: todo parsing é nativo da aplicação

---

<sub>POC · Rails 8 + SQLite · daemon no host + painel no browser · notificações nativas</sub>
