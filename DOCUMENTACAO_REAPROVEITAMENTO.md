# Reaproveitamento dos gabaritos do professor

Este pacote foi reorganizado para seguir a separação pedida no projeto final:

- um arquivo só para montar tabelas;
- um arquivo só para carga;
- arquivos separados para limpeza, views, functions/procedures, triggers e índices.

## T1

O arquivo `03_deduplicacao_metricas.sql` segue a ideia do T1:

- substituir nacionalidade textual de pilotos e construtores por `country_id`;
- adicionar `nationality` em `countries`;
- tratar cidades duplicadas e manter métricas de conferência.

## T2

O arquivo `05_functions.sql` reaproveita o estilo das funções/procedures do gabarito T2:

- `Nome_Nacionalidade`;
- `Pilotos_Nacionalidade`;
- `Cidade_Chamada`;
- `Numero_Vitorias`;
- `Pais_Continente`.

Além disso, adiciona as funções específicas do P4 para dashboards, relatórios e ações.

## T3

O arquivo `07_triggers.sql` segue o padrão do T3:

- `CREATE OR REPLACE FUNCTION ... RETURNS TRIGGER`;
- `CREATE TRIGGER`;
- validação com `RAISE EXCEPTION`.

No P4, isso é usado para criar/atualizar usuários automaticamente quando pilotos ou escuderias são inseridos/alterados.

## T4

O arquivo `04_views.sql` cria views inspiradas no T4:

- `Aeroportos_Brasileiros`;
- `Aeroportos_sem_cidades`;
- `Cidades_brasileiras`;
- `Circuitos_completa`;
- `Problemas_aeroportos`;
- `Correcao_aeroportos`.

Também cria views auxiliares para os dashboards e relatórios do P4.

## T5

O arquivo `08_indices.sql` segue a ideia do T5:

- índice Hash para busca exata por nome completo de piloto;
- índice B-tree parcial com `INCLUDE` e `WHERE` para cidades brasileiras;
- índices adicionais para relatórios do P4.
