# frozen_string_literal: true

module Tracer
  # Notificador nativo do S.O. — shell-out para os comandos nativos de cada
  # plataforma, sem gem/biblioteca de notificação (decisão do mapa: notificações
  # nativas via comandos do S.O. diretos).
  #
  #   notify-send (Linux) | osascript -e 'display notification ...' (macOS)
  #   PowerShell toast (Windows)
  class NativeNotifier
    def notify(title, body)
      case platform
      when :linux   then system("notify-send", title, body)
      when :macos   then system("osascript", "-e", "display notification \"#{body}\" with title \"#{title}\"")
      when :windows then windows_toast(title, body)
      end
    end

    # Notificação de teste na primeira execução (bin/setup) — o usuário concede
    # permissão na hora (macOS/Windows pedem permissão na 1ª notificação).
    def self.test!
      new.notify("Tracer", "Notificações funcionando! O Tracer vai lembrar você das pendências.")
    end

    private

    def platform
      @platform ||= case RbConfig::CONFIG["host_os"]
      when /linux/   then :linux
      when /darwin/  then :macos
      when /mswin|mingw|cygwin/ then :windows
      end
    end

    def windows_toast(title, body)
      script = <<~PS
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
        $text = $template.GetElementsByTagName("text")
        $text.Item(0).AppendChild($template.CreateTextNode("#{title}")) | Out-Null
        $text.Item(1).AppendChild($template.CreateTextNode("#{body}")) | Out-Null
        $toast = [Windows.UI.Notifications.ToastNotification]::new($template)
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Tracer").Show($toast)
      PS
      system("powershell", "-NoProfile", "-Command", script)
    end
  end
end
