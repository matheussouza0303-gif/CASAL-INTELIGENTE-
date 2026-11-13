# Casal Inteligente

Aplicação financeira compartilhada para Matheus e Letícia.

## Situação do projeto

- `index.html`: aplicação web com login por e-mail/senha, conexão com Supabase, sincronização em tempo real e backup/exportação.
- `supabase/migrations/`: três migrações já aplicadas no projeto Supabase `casal-inteligente` (região São Paulo, plano Free).
- As informações financeiras são armazenadas em `public.ci_records` como JSON por caminho lógico, com isolamento por família.
- O projeto não usa chave `service_role` no navegador. A chave publishable e a URL do projeto ficam no cliente e não concedem acesso aos dados sem autenticação e políticas RLS.

## Recursos implementados

- Login e cadastro de usuário por e-mail/senha.
- Criação inicial de um espaço familiar.
- Vinculação do segundo usuário pelo responsável, usando o e-mail já cadastrado no Supabase Auth.
- Dados compartilhados de planejamento, lançamentos, meses, metas, patrimônio e histórico.
- Sincronização Realtime entre dispositivos.
- Migração automática do backup `localStorage` anterior quando o espaço remoto ainda está vazio.
- Exportação de backup JSON, Excel e CSV.

## Segurança do banco

Tabelas:

- `public.households`
- `public.household_members`
- `public.ci_records`

RLS está habilitado em todas. Acesso anônimo foi revogado explicitamente. Usuários autenticados só podem ler/alterar registros associados a um `household_id` no qual sejam membros. As funções auxiliares de autorização foram movidas para o esquema `private`, fora da API pública. Permanecem duas RPCs autenticadas em `public`: `create_household` e `add_household_member`; ambas usam `SECURITY DEFINER`, `search_path` vazio e validações de autenticação/posse. O Advisor do Supabase emite aviso para essas duas RPCs porque elas precisam executar com privilégios elevados; esse comportamento é intencional.

## Primeira configuração de contas

1. Abra o app e crie a conta do primeiro usuário.
2. Se a conta for a primeira do casal, crie o espaço familiar e selecione o perfil correto.
3. Crie a conta da segunda pessoa no Supabase Auth. No plano Free, o SMTP padrão do Supabase só envia e-mails para endereços que fazem parte da organização e tem limite baixo de envio. Para evitar contratar SMTP, o administrador pode criar a segunda conta manualmente em **Authentication > Users** no painel Supabase e definir/confirmar as credenciais por lá.
4. Entre no app com a conta responsável, acesse **Ajustes > Compartilhar** e vincule o e-mail exato da segunda conta.
5. A segunda pessoa entra com as próprias credenciais; os dados da família serão carregados após o vínculo.

Não crie uma segunda família para a segunda pessoa. Ela deve ser vinculada ao espaço que o primeiro usuário criou.

## Dados antigos

Se o navegador já tiver dados da versão local anterior, o app importa esse backup automaticamente na primeira conexão, mas apenas quando o espaço remoto está vazio. O arquivo local não é apagado. Ainda assim, faça um backup JSON antes de trocar de versão.

## Custos e limites

A organização Supabase está no plano Free e o projeto foi criado com cotação de US$ 0/mês. O plano gratuito pode pausar projetos com pouca atividade e tem limites de uso. O SMTP padrão não é um serviço de e-mail de produção. Não habilite add-ons nem faça upgrade pago sem revisar o custo.

## Configuração técnica

- O SDK `@supabase/supabase-js` é carregado por CDN em versão fixada `2.119.0`.
- `SUPABASE_URL` e `SUPABASE_PUBLISHABLE_KEY` são dados públicos do cliente.
- Nunca incluir senhas, tokens de acesso, chaves secretas ou `service_role` neste repositório.
- Para rodar localmente, execute `python -m http.server 8000` nesta pasta e abra `http://localhost:8000`. No painel Supabase, em Authentication > URL Configuration, adicione `http://localhost:8000/**` às Redirect URLs. Ao hospedar o app, troque/adicione o endereço público nessa lista e ajuste o Site URL.

## Verificações executadas

- Sintaxe JavaScript validada com `node --check`.
- Migrações aplicadas e listadas no Supabase.
- Tabelas e RLS conferidos.
- Permissões testadas: `anon` sem leitura; `authenticated` com acesso condicionado às políticas RLS.
- Security Advisor: dois avisos intencionais para as RPCs autenticadas de criação/vinculação de membros. Health Advisor sem alertas.
- O fluxo completo de login, cadastro, convite e Realtime ainda depende de criar as duas contas reais e testar em dois dispositivos.


## Estado atual

- Repositório GitHub privado: `matheussouza0303-gif/CASAL-INTELIGENTE-`.
- Projeto Supabase `casal-inteligente` criado e ativo na região São Paulo (`sa-east-1`), no plano Free.
- O esquema de banco e as políticas de segurança já foram aplicados e verificados no Supabase.
- O código foi preparado para autenticação e sincronização entre os dois usuários.
- O aplicativo ainda não está publicado em uma hospedagem web. O próximo passo é configurar uma hospedagem estática gratuita e incluir o endereço final nas Redirect URLs do Supabase.

Não há cobrança de plano Pro ou serviços pagos contratados neste projeto.