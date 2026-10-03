// Gerado por supabase/gerar_tipos.py a partir de 001_esquema.sql. Não editar à mão.
export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[]

export type Database = {
  org: {
    Tables: {
      executor_tipo: {
        Row: {
          codigo: Database['org']['Enums']['executor']
          nome: string
          e_pessoa: boolean
          e_maquina: boolean
        }
        Insert: {
          codigo: Database['org']['Enums']['executor']
          nome: string
          e_pessoa: boolean
          e_maquina: boolean
        }
        Update: {
          codigo?: Database['org']['Enums']['executor']
          nome?: string
          e_pessoa?: boolean
          e_maquina?: boolean
        }
        Relationships: []
      }
      circulo: {
        Row: {
          numero: number
          nome: string
          sigla: string
          prefixo: string
          descricao: string
          principio: string | null
          situacao: string
        }
        Insert: {
          numero: number
          nome: string
          sigla: string
          prefixo: string
          descricao: string
          principio?: string | null
          situacao: string
        }
        Update: {
          numero?: number
          nome?: string
          sigla?: string
          prefixo?: string
          descricao?: string
          principio?: string | null
          situacao?: string
        }
        Relationships: []
      }
      dominio: {
        Row: {
          id: number
          circulo: number
          nome: string
          descricao: string | null
        }
        Insert: {
          id?: number
          circulo: number
          nome: string
          descricao?: string | null
        }
        Update: {
          id?: number
          circulo?: number
          nome?: string
          descricao?: string | null
        }
        Relationships: []
      }
      jornada: {
        Row: {
          codigo: string
          circulo: number
          nome: string
          dominio: string
          classe: string
          onda: number
          objetivo: string
          frequencia: string
          automacao_nivel: string
          automacao_motivo: string
          raias: string[]
        }
        Insert: {
          codigo: string
          circulo: number
          nome: string
          dominio: string
          classe: string
          onda: number
          objetivo: string
          frequencia: string
          automacao_nivel: string
          automacao_motivo: string
          raias: string[]
        }
        Update: {
          codigo?: string
          circulo?: number
          nome?: string
          dominio?: string
          classe?: string
          onda?: number
          objetivo?: string
          frequencia?: string
          automacao_nivel?: string
          automacao_motivo?: string
          raias?: string[]
        }
        Relationships: []
      }
      evento: {
        Row: {
          id: number
          jornada: string
          tipo: string
          nome: string
          raia: string | null
          gatilho: string | null
        }
        Insert: {
          id?: number
          jornada: string
          tipo: string
          nome: string
          raia?: string | null
          gatilho?: string | null
        }
        Update: {
          id?: number
          jornada?: string
          tipo?: string
          nome?: string
          raia?: string | null
          gatilho?: string | null
        }
        Relationships: []
      }
      etapa: {
        Row: {
          id: number
          jornada: string
          numero: number
          nome: string
          dono: string
          modo: Database['org']['Enums']['modo']
          risco: Database['org']['Enums']['risco']
          classe_real: string
        }
        Insert: {
          id?: number
          jornada: string
          numero: number
          nome: string
          dono: string
          modo: Database['org']['Enums']['modo']
          risco: Database['org']['Enums']['risco']
          classe_real: string
        }
        Update: {
          id?: number
          jornada?: string
          numero?: number
          nome?: string
          dono?: string
          modo?: Database['org']['Enums']['modo']
          risco?: Database['org']['Enums']['risco']
          classe_real?: string
        }
        Relationships: []
      }
      tarefa: {
        Row: {
          id: number
          etapa: number
          ordem: number
          nome: string
          executor: Database['org']['Enums']['executor']
          raia: string
          tipo_bpmn: string | null
          condicao: string | null
        }
        Insert: {
          id?: number
          etapa: number
          ordem: number
          nome: string
          executor: Database['org']['Enums']['executor']
          raia: string
          tipo_bpmn?: string | null
          condicao?: string | null
        }
        Update: {
          id?: number
          etapa?: number
          ordem?: number
          nome?: string
          executor?: Database['org']['Enums']['executor']
          raia?: string
          tipo_bpmn?: string | null
          condicao?: string | null
        }
        Relationships: []
      }
      decisao_caminho: {
        Row: {
          id: number
          etapa: number
          ordem: number
          pergunta: string
          quem: string
          saidas: Json
        }
        Insert: {
          id?: number
          etapa: number
          ordem: number
          pergunta: string
          quem: string
          saidas: Json
        }
        Update: {
          id?: number
          etapa?: number
          ordem?: number
          pergunta?: string
          quem?: string
          saidas?: Json
        }
        Relationships: []
      }
      entrada: {
        Row: {
          id: number
          etapa: number
          produto: string
          origem: string
        }
        Insert: {
          id?: number
          etapa: number
          produto: string
          origem: string
        }
        Update: {
          id?: number
          etapa?: number
          produto?: string
          origem?: string
        }
        Relationships: []
      }
      saida: {
        Row: {
          id: number
          etapa: number
          produto: string
          destinos: string[]
        }
        Insert: {
          id?: number
          etapa: number
          produto: string
          destinos: string[]
        }
        Update: {
          id?: number
          etapa?: number
          produto?: string
          destinos?: string[]
        }
        Relationships: []
      }
      troca: {
        Row: {
          id: number
          produto: string
          de_circulo: string
          para_circulo: string
          via: string | null
          sai_em: string[]
          entra_em: string[]
        }
        Insert: {
          id?: number
          produto: string
          de_circulo: string
          para_circulo: string
          via?: string | null
          sai_em: string[]
          entra_em: string[]
        }
        Update: {
          id?: number
          produto?: string
          de_circulo?: string
          para_circulo?: string
          via?: string | null
          sai_em?: string[]
          entra_em?: string[]
        }
        Relationships: []
      }
      cadeia: {
        Row: {
          codigo: string
          nome: string
          dono: string | null
          nota: string | null
          circulos: string[]
          jornadas: string[]
        }
        Insert: {
          codigo: string
          nome: string
          dono?: string | null
          nota?: string | null
          circulos: string[]
          jornadas: string[]
        }
        Update: {
          codigo?: string
          nome?: string
          dono?: string | null
          nota?: string | null
          circulos?: string[]
          jornadas?: string[]
        }
        Relationships: []
      }
      cadeia_elo: {
        Row: {
          id: number
          cadeia: string
          ordem: number
          de_jornada: string
          para_jornada: string
          produtos: string[]
        }
        Insert: {
          id?: number
          cadeia: string
          ordem: number
          de_jornada: string
          para_jornada: string
          produtos: string[]
        }
        Update: {
          id?: number
          cadeia?: string
          ordem?: number
          de_jornada?: string
          para_jornada?: string
          produtos?: string[]
        }
        Relationships: []
      }
      fonte: {
        Row: {
          chave: string
          referencia: string
          conferencia: string
          links: Json
        }
        Insert: {
          chave: string
          referencia: string
          conferencia: string
          links: Json
        }
        Update: {
          chave?: string
          referencia?: string
          conferencia?: string
          links?: Json
        }
        Relationships: []
      }
      fonte_uso: {
        Row: {
          circulo: number
          fonte: string
          uso: string
        }
        Insert: {
          circulo: number
          fonte: string
          uso: string
        }
        Update: {
          circulo?: number
          fonte?: string
          uso?: string
        }
        Relationships: []
      }
      jornada_fonte: {
        Row: {
          jornada: string
          fonte: string
        }
        Insert: {
          jornada: string
          fonte: string
        }
        Update: {
          jornada?: string
          fonte?: string
        }
        Relationships: []
      }
      decisao_registrada: {
        Row: {
          id: number
          circulo: number
          ordem: number
          decisao: string
          origem: string
          efeito: string
        }
        Insert: {
          id?: number
          circulo: number
          ordem: number
          decisao: string
          origem: string
          efeito: string
        }
        Update: {
          id?: number
          circulo?: number
          ordem?: number
          decisao?: string
          origem?: string
          efeito?: string
        }
        Relationships: []
      }
      limite: {
        Row: {
          id: number
          circulo: number
          ordem: number
          texto: string
        }
        Insert: {
          id?: number
          circulo: number
          ordem: number
          texto: string
        }
        Update: {
          id?: number
          circulo?: number
          ordem?: number
          texto?: string
        }
        Relationships: []
      }
      parametro: {
        Row: {
          id: number
          tipo: Database['org']['Enums']['tipo_parametro']
          nome: string
          onde: string | null
          quem_propoe: string | null
          quem_decide: string | null
          valor: string | null
        }
        Insert: {
          id?: number
          tipo: Database['org']['Enums']['tipo_parametro']
          nome: string
          onde?: string | null
          quem_propoe?: string | null
          quem_decide?: string | null
          valor?: string | null
        }
        Update: {
          id?: number
          tipo?: Database['org']['Enums']['tipo_parametro']
          nome?: string
          onde?: string | null
          quem_propoe?: string | null
          quem_decide?: string | null
          valor?: string | null
        }
        Relationships: []
      }
      gate: {
        Row: {
          codigo: string
          nome: string
          entra: string
          quem_fornece: string
          criterio_saida: string
          desbloqueia: string
          situacao: Database['org']['Enums']['situacao_gate']
        }
        Insert: {
          codigo: string
          nome: string
          entra: string
          quem_fornece: string
          criterio_saida: string
          desbloqueia: string
          situacao?: Database['org']['Enums']['situacao_gate']
        }
        Update: {
          codigo?: string
          nome?: string
          entra?: string
          quem_fornece?: string
          criterio_saida?: string
          desbloqueia?: string
          situacao?: Database['org']['Enums']['situacao_gate']
        }
        Relationships: []
      }
      achado_auditoria: {
        Row: {
          id: number
          gravidade: string
          tipo: string
          onde: string
          detalhe: string
        }
        Insert: {
          id?: number
          gravidade: string
          tipo: string
          onde: string
          detalhe: string
        }
        Update: {
          id?: number
          gravidade?: string
          tipo?: string
          onde?: string
          detalhe?: string
        }
        Relationships: []
      }
      empresa: {
        Row: {
          id: string
          nome: string
          regime_tributario: string | null
          porte: string | null
          agente_pequeno_porte: boolean | null
          criado_em: string
        }
        Insert: {
          id?: string
          nome: string
          regime_tributario?: string | null
          porte?: string | null
          agente_pequeno_porte?: boolean | null
          criado_em?: string
        }
        Update: {
          id?: string
          nome?: string
          regime_tributario?: string | null
          porte?: string | null
          agente_pequeno_porte?: boolean | null
          criado_em?: string
        }
        Relationships: []
      }
      pessoa: {
        Row: {
          id: string
          nome: string
          email: string | null
          criado_em: string
        }
        Insert: {
          id?: string
          nome: string
          email?: string | null
          criado_em?: string
        }
        Update: {
          id?: string
          nome?: string
          email?: string | null
          criado_em?: string
        }
        Relationships: []
      }
      atribuicao: {
        Row: {
          id: string
          pessoa: string
          papel: string
          circulo: number | null
          empresa: string | null
          inicio: string
          fim: string | null
        }
        Insert: {
          id?: string
          pessoa: string
          papel: string
          circulo?: number | null
          empresa?: string | null
          inicio?: string
          fim?: string | null
        }
        Update: {
          id?: string
          pessoa?: string
          papel?: string
          circulo?: number | null
          empresa?: string | null
          inicio?: string
          fim?: string | null
        }
        Relationships: []
      }
    }
    Views: {
      v_etapa: {
        Row: {
          id: number | null
          circulo: number | null
          circulo_nome: string | null
          jornada: string | null
          numero: number | null
          nome: string | null
          dono: string | null
          modo: Database['org']['Enums']['modo'] | null
          risco: Database['org']['Enums']['risco'] | null
          classe_real: string | null
          tarefas: number | null
          tarefas_maquina: number | null
          tarefas_pessoa: number | null
          tarefas_outro_circulo: number | null
        }
        Relationships: []
      }
      v_jornada: {
        Row: {
          codigo: string | null
          circulo: number | null
          circulo_nome: string | null
          nome: string | null
          dominio: string | null
          classe: string | null
          onda: number | null
          automacao_nivel: string | null
          etapas: number | null
          tarefas: number | null
          pct_maquina: number | null
        }
        Relationships: []
      }
    }
    Functions: { [_ in never]: never }
    Enums: {
      modo: "Assistido" | "Copiloto" | "Autopiloto" | "Autômato"
      risco: "baixo" | "médio" | "alto"
      executor: "P" | "A" | "R" | "H" | "C" | "X"
      tipo_parametro: "alçada" | "cadência" | "conteúdo" | "fonte"
      situacao_gate: "aberto" | "em andamento" | "cumprido"
    }
    CompositeTypes: { [_ in never]: never }
  }
}

export type Tabela<T extends keyof Database['org']['Tables']> = Database['org']['Tables'][T]['Row']
export type Visao<V extends keyof Database['org']['Views']> = Database['org']['Views'][V]['Row']
