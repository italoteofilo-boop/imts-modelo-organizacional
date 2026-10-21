// Botões do bot ligados ao Mini App (P6). Sem dependências, para o teste importar sem banco.
// Botão web_app em teclado embutido só vale em conversa privada (Bot API, InlineKeyboardButton.web_app); em grupo vira link comum.

type Botao = Record<string, unknown> & { text?: string; web_app?: { url?: string } };

export function ajustarBotoes(botoes: unknown, chatId: string): unknown {
  if (!Array.isArray(botoes) || !chatId.startsWith("-")) return botoes;
  return botoes.map((linha) => Array.isArray(linha)
    ? linha.map((b: Botao) => b && typeof b === "object" && b.web_app?.url ? { text: b.text, url: b.web_app.url } : b)
    : linha);
}

// Botão de menu do bot (setChatMenuButton, MenuButtonWebApp): abre a Mesa no Telegram
export function menuMesa(url: string | null) {
  return url ? { menu_button: { type: "web_app", text: "Mesa", web_app: { url } } } : { menu_button: { type: "commands" } };
}
