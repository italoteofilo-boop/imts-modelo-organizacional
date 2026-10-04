"""D1 · Catálogo de tipos de documento formal do Ecossistema, ligado às saídas do modelo (saida/c*/circulo.json).
Catálogo fechado (curado), não inferido: cada tipo tem família, modelo de design, alcance (interno/externo pela natureza do
documento) e uma regra de texto que liga o tipo às saídas que o originam. Saída sem tipo = registro do motor (cartão da Mesa,
evento), não vira PDF. A ligação por regra é heurística: sai marcada para revisão da ID-04."""
import json, re, glob, os, unicodedata, collections
AQUI = os.path.dirname(os.path.abspath(__file__)); BASE = os.path.dirname(AQUI)
def sa(s): return ''.join(c for c in unicodedata.normalize('NFD', s.lower()) if unicodedata.category(c) != 'Mn')

# (id, nome, família, modelo, alcance, regra sobre o nome da saída, sem acento)
TIPOS = [
 ('contrato-cliente', 'Contrato de prestação de serviços a cliente', 'contratual', 'contratual', 'externo', r'contrato de cliente|contrato assinado|contratos? (encerrad|vencimento|com vencimento)|vencimento do contrato'),
 ('contrato-fornecedor', 'Contrato com fornecedor', 'contratual', 'contratual', 'externo', r'contrato de fornecedor|contrato de tecnologia'),
 ('aditivo', 'Termo aditivo, renovação ou distrato', 'contratual', 'contratual', 'externo', r'aditivo|renovacao, aditivo|encerramento assinado|distrato'),
 ('acordo-parceria', 'Acordo de parceria ou de oferta conjunta', 'contratual', 'contratual', 'externo', r'acordo de oferta conjunta|termos da parceria|encerramento de parceria'),
 ('contrato-societario', 'Contrato de compra e venda de participação', 'contratual', 'contratual', 'externo', r'contrato de compra ou venda'),
 ('licenca-marca', 'Autorização de uso de marca', 'contratual', 'contratual', 'externo', r'autorizac\w* de uso da marca|uso da marca por terceiros'),
 ('acordo-servico', 'Acordo de serviço entre círculos ou empresas', 'contratual', 'contratual', 'interno', r'acordo de servico'),
 ('termo-negociacao', 'Termo de pagamento, parcelamento ou transação', 'contratual', 'contratual', 'externo', r'parcelamento|transacao formalizad|termos negociados'),
 ('proposta-comercial', 'Proposta comercial', 'proposta', 'proposta', 'externo', r'proposta (aprovada para envio|aceita|de renovacao)|modelos de proposta|proposta comercial'),
 ('proposta-interna', 'Proposta para decisão (memorando)', 'relatorio', 'institucional', 'interno', r'^proposta'),
 ('racional-financeiro', 'Racional financeiro de contrato', 'demonstrativo', 'demonstrativo', 'interno', r'racional financeiro|condicoes acordadas'),
 ('proposta-b2g', 'Proposta de preço e habilitação em licitação', 'licitacao', 'licitacao', 'externo', r'habilitac|edital|licitac|pregao|proposta de preco'),
 ('arp', 'Ata de registro de preços', 'licitacao', 'licitacao', 'externo', r'ata de registro de precos'),
 ('ata', 'Ata de reunião ou de deliberação', 'ata', 'ata', 'interno', r'^ata\b|deliberac|decisao dos socios|decididos? pelo comite|acoes do ritual'),
 ('pauta', 'Pauta e convocação', 'ata', 'ata', 'interno', r'pauta|convocac'),
 ('politica', 'Política', 'politica', 'politica', 'interno', r'politica'),
 ('regra-alcadas', 'Regras e alçadas', 'politica', 'politica', 'interno', r'alcadas|regra de uso|^regras? (vigente|aprovad)'),
 ('manual-metodo', 'Manual, método ou padrão', 'politica', 'politica', 'interno', r'manual|metodo|padroes|^padrao|kit\b|guia\b|protocolo de crise'),
 ('mandato', 'Mandato da empresa', 'politica', 'politica', 'interno', r'^mandato'),
 ('declaracao-identidade', 'Declaração de identidade', 'politica', 'institucional', 'externo', r'declaracao de identidade|essencia da marca'),
 ('estrategia', 'Documento de estratégia', 'relatorio', 'institucional', 'interno', r'^estrategia vigente|hipoteses da estrategia'),
 ('plano-contas', 'Plano de contas e plano tributário', 'demonstrativo', 'demonstrativo', 'interno', r'plano de contas|plano tributario'),
 ('plano', 'Plano (estratégico, de ação, de saída, de correção)', 'relatorio', 'relatorio', 'interno', r'^plano (de|da|do)|^planejamento'),
 ('diagnostico', 'Diagnóstico, estudo ou análise', 'relatorio', 'relatorio', 'interno', r'^diagnostico|^estudo|^analise|^sintese'),
 ('relatorio', 'Relatório de resultado ou de situação', 'relatorio', 'relatorio', 'interno', r'^relatorio|^resultado|^situacao da|^avaliacao'),
 ('parecer', 'Parecer', 'parecer', 'relatorio', 'interno', r'parecer|conformidade|^revisao'),
 ('auditoria', 'Relatório de auditoria ou de apuração', 'parecer', 'relatorio', 'interno', r'auditoria|apuracao'),
 ('demonstracoes', 'Demonstrações contábeis (DRE, balancete, balanço)', 'demonstrativo', 'demonstrativo', 'externo', r'demonstrac|balancete|balanco|\bdre\b'),
 ('orcamento', 'Orçamento e previsão financeira', 'demonstrativo', 'demonstrativo', 'interno', r'orcamento|previsao (financeira|de caixa)|planejado|rateio'),
 ('fatura', 'Fatura e cobrança', 'demonstrativo', 'demonstrativo', 'externo', r'fatura emitida|pedido de cobranca do fornecedor'),
 ('folha', 'Folha e demonstrativo de pagamento', 'demonstrativo', 'demonstrativo', 'interno', r'folha'),
 ('ordem-compra', 'Ordem de compra a fornecedor', 'oficio', 'oficio', 'externo', r'pedido emitido ao fornecedor|ordem de compra'),
 ('resposta-titular', 'Resposta a titular de dados (LGPD)', 'oficio', 'oficio', 'externo', r'resposta ao titular|pedido do titular cumprido'),
 ('resposta-externa', 'Resposta a cliente, parceiro ou público', 'oficio', 'oficio', 'externo', r'resposta ao (parceiro|relato|pedido de uso)|comunicacao da posicao|solucao aplicada ao cliente'),
 ('comunicado', 'Comunicado interno', 'oficio', 'oficio', 'interno', r'^comunicado|a comunicar$|^aviso de mudanca'),
 ('notificacao', 'Notificação formal', 'oficio', 'oficio', 'externo', r'notificac|retirada de marca|suspensao de novas entregas'),
 ('certificado', 'Certificado de reconhecimento', 'certificado', 'certificado', 'interno', r'reconhecimento'),
 ('declaracao', 'Declaração', 'certificado', 'certificado', 'externo', r'^declaracao(?! de identidade)'),
]
# saídas que são passo de fluxo (pedido, lista, decisão de rever...), não documento: ficam como registro do motor
NAO_DOC = r'^(lista|pedido|escopo|base|casos|indicadores|mudanca|decisoes? de|contestacao|vaga|cadastro|entregas confirmadas|situacao de faturas|receitas|pratica|metodo (recusado|retirado|da oferta nao)|padrao ambiguo|plano de saida (que mostra|fechado)|proposta de arquivar|avaliacao da experiencia sem)'
VERBOS_DOC = r'^(redigir|elaborar|emitir|publicar|preparar|montar|gerar|escrever|consolidar|formalizar|assinar|enviar|apresentar|documentar|lavrar|expedir|divulgar|comunicar|responder|registrar a ata|fechar o texto|revisar o texto)'

def main():
    cat = {t[0]: {'id': t[0], 'nome': t[1], 'familia': t[2], 'modelo': t[3], 'alcance': t[4], 'regra': t[5],
                  'origens': [], 'tarefas': [], 'ligacao': 'heuristica'} for t in TIPOS}
    registros = collections.Counter(); total = 0; ligadas = 0
    for arq in sorted(glob.glob(os.path.join(BASE, 'saida', 'c[1-9]', 'circulo.json'))):
        d = json.load(open(arq)); c = os.path.basename(os.path.dirname(arq))
        for j in d['jornadas']:
            for e in j['etapas']:
                for s in e.get('saidas', []):
                    total += 1; n = sa(s['o'].strip())
                    hit = None if re.search(NAO_DOC, n) else next((t for t in TIPOS if re.search(t[5], n)), None)
                    if not hit: registros[s['o'].strip()] += 1; continue
                    ligadas += 1; t = cat[hit[0]]
                    t['origens'].append({'circulo': c, 'jornada': j['code'], 'etapa': e['n'], 'saida': s['o'], 'para': s.get('para', [])})
                    for k, ta in enumerate(e.get('tarefas', []), 1):
                        if re.search(VERBOS_DOC, sa(ta['nome'])):
                            ref = {'jornada': j['code'], 'etapa': e['n'], 'tarefa': k, 'nome': ta['nome'], 'exec': ta.get('exec')}
                            if ref not in t['tarefas']: t['tarefas'].append(ref)
    lista = list(cat.values())
    resumo = {'tipos': len(lista), 'tipos_com_origem': sum(1 for t in lista if t['origens']),
              'saidas_total': total, 'saidas_ligadas': ligadas, 'saidas_registro_do_motor': total - ligadas,
              'saidas_distintas_sem_tipo': len(registros),
              'por_familia': dict(collections.Counter(t['familia'] for t in lista)),
              'por_alcance': dict(collections.Counter(t['alcance'] for t in lista)),
              'tarefas_documentais': sum(len(t['tarefas']) for t in lista)}
    out = {'fonte': 'saida/c1..c9/circulo.json, modelo 2026-10-03.2', 'metodo': 'catálogo fechado; ligação às saídas por regra de texto, para revisão da ID-04',
           'resumo': resumo, 'tipos': lista, 'registros_do_motor': sorted(registros)}
    json.dump(out, open(os.path.join(AQUI, 'tipos', 'catalogo.json'), 'w'), ensure_ascii=False, indent=1)
    print(json.dumps(resumo, ensure_ascii=False))
    for t in lista: print(f"{t['id']:24} {len(t['origens']):3} origens {len(t['tarefas']):3} tarefas")

if __name__ == '__main__': main()
