# IMTS.OS · Textos dos e-mails de login (Supabase > Authentication > Emails)

Valem para quem entra pelo link no e-mail: clientes, parceiros e convidados. Quem é de dentro entra com o Google e não recebe estes e-mails.
Cole em cada projeto (homologação e produção). As variáveis entre chaves duplas são do Supabase e ficam como estão.

## Magic Link

**Assunto:** Seu link de acesso ao IMTS.OS

```html
<p>Olá,</p>
<p>Recebemos um pedido de acesso ao IMTS.OS para {{ .Email }}.</p>
<p><a href="{{ .ConfirmationURL }}">Entrar no IMTS.OS</a></p>
<p>O link vale por pouco tempo e só pode ser usado uma vez. Se você não pediu este acesso, ignore este e-mail.</p>
<p>IMTS</p>
```

## Invite user

**Assunto:** Você foi convidado para o IMTS.OS

```html
<p>Olá,</p>
<p>Você recebeu acesso ao portal do IMTS.OS com o e-mail {{ .Email }}.</p>
<p><a href="{{ .ConfirmationURL }}">Aceitar o convite e entrar</a></p>
<p>Se não reconhece este convite, ignore este e-mail.</p>
<p>IMTS</p>
```

## Confirm signup

**Assunto:** Confirme seu e-mail no IMTS.OS

```html
<p>Olá,</p>
<p>Confirme o e-mail {{ .Email }} para concluir o acesso ao IMTS.OS.</p>
<p><a href="{{ .ConfirmationURL }}">Confirmar e entrar</a></p>
<p>Se você não pediu este acesso, ignore este e-mail.</p>
<p>IMTS</p>
```

## Envio (SMTP)

O envio padrão do Supabase serve só para teste: tem limite baixo e entrega apenas para endereços da equipe da organização no Supabase. Para clientes e parceiros receberem o link, configure um SMTP próprio em **Authentication > Emails > SMTP Settings** (https://supabase.com/docs/guides/auth/auth-smtp).

Remetente sugerido: `naoresponda@imts.email`. O serviço de envio é decisão do time.
