# Integração com MeteorReactBaseMUI

## Fluxo de login

O Flutter usa o protocolo DDP do Meteor, não uma API REST paralela.

1. `MeteorClient` conecta em `METEOR_URL/websocket`.
2. O usuário informa email e senha já cadastrados pela aplicação Web.
3. `MeteorAuthService.loginWithPassword` chama o método DDP nativo `login`. O
   pacote envia o identificador `{email: ...}` e o digest SHA-256 exigido pelo
   Accounts Password.
4. O Meteor executa as mesmas validações usadas pelo React, incluindo
   `Accounts.validateLoginAttempt`. No boilerplate atual, email não verificado
   é recusado.
5. O servidor devolve `id`, `token` e `tokenExpires`. O Flutter salva esses
   valores com `flutter_secure_storage` (Keychain no ecossistema Apple e
   armazenamento seguro da plataforma nos demais alvos).
6. O app assina `userprofile.getLoggedUserProfile` e lê a coleção
   `userprofile`. O modelo replica `IUserProfile` (`photo`, `username`, `email`,
   `phone`, `roles` e `status`) e os metadados de `IDoc` (`_id`, `createdat`,
   `updatedby`, `createdby`, `lastupdate`, `sincronizadoEm` e `needSync`).
7. Ao reabrir, o app chama `login` com `{resume: token}`. Cada cliente Web ou
   mobile mantém seu próprio token de sessão para o mesmo usuário.
8. No logout, o método DDP `logout` revoga a sessão atual e o token local é
   apagado mesmo se a conexão cair.

Se a publicação terminar com erro, não devolver um perfil ou devolver um perfil
desativado, o app encerra a sessão e remove o cache. O cache vincula o ID da
sessão Meteor ao `_id` do perfil sem assumir que sejam sempre iguais, permitindo
contas associadas ao mesmo perfil funcional.

Não existe rota de cadastro, botão de cadastro ou chamada `createUser` no
mobile.

Em desenvolvimento, o backend pode ser executado em `http://localhost:3200`.
O emulador Android acessa o mesmo processo por `http://10.0.2.2:3200`.

O verificador `tool/verify_meteor_integration.dart` confirma login, perfil
autenticado, insert, lista, contador, detalhe, update e remove reativos,
retomada do token e logout.

## Contratos do módulo example

Os nomes abaixo vêm diretamente do boilerplate Web:

| Operação | Contrato DDP |
| --- | --- |
| Lista | publicação `example.exampleList(filter, options)` |
| Total | publicação `example.countexampleList(filter)` |
| Detalhe | publicação `example.exampleDetail({_id})` |
| Criar | método `example.insert(doc)` |
| Alterar | método `example.update(doc)` |
| Excluir | método `example.remove({_id})` |
| Coleção reativa | `example` |

`ExampleApi` estende `ProductMobileApiBase`, o equivalente mobile de
`ProductBase`. Novos módulos devem repetir esse padrão e manter no Dart os
mesmos nomes do `ProductServerBase`.

## Mudanças/configurações no backend Web

Para login por email/senha, não é necessário criar um endpoint novo nem mudar
o Accounts: o método `login` já é exposto pelo pacote `accounts-password`.
Também não se deve habilitar cadastro pelo cliente. Mantenha
`ALLOW_CLIENT_ACCOUNT_CREATION` ausente ou diferente de `true`; assim a
configuração atual continua com `forbidClientAccountCreation: true`.

Devem ser garantidos estes pontos no deploy e na gestão Web:

1. O proxy reverso deve aceitar WebSocket em `/websocket`, repassando os
   cabeçalhos `Upgrade` e `Connection`. Em produção publique apenas via TLS
   (`https`/`wss`) e configure `ROOT_URL` com a URL externa.
2. A tela de gestão Web deve criar o registro do Accounts e o documento
   `userprofile` vinculados pelo `_id` ou por `otheraccounts._id`. O email é
   mantido como fallback de compatibilidade e deve permanecer consistente.
3. A gestão Web deve verificar o email (ou concluir o fluxo de email de
   verificação) antes de liberar o acesso. A validação atual do servidor
   bloqueia credenciais cujo `emails[0].verified` seja falso.
   Perfis com `status: disabled` também são recusados e têm seus tokens de
   retomada revogados quando são desativados.
4. O perfil deve possuir a role `Usuario`. O mapeamento atual já concede a
   essa role os recursos `EXAMPLE_VIEW`, `EXAMPLE_CREATE`, `EXAMPLE_UPDATE` e
   `EXAMPLE_REMOVE`.
5. `imports/server/registerApi.ts` já registra `exampleServerApi` e
   `userProfileServerApi`; esses imports devem permanecer no bundle do
   servidor.
6. Recomenda-se limitar tentativas do método DDP `login` por conexão/IP com
   `DDPRateLimiter` e monitorar falhas. Essa proteção é do backend e vale para
   Web e Flutter.

CORS não substitui a configuração de WebSocket. Para apps nativos, o ponto
essencial é o proxy/TLS aceitar DDP; origens CORS continuam relevantes para as
rotas HTTP consumidas pelo frontend Web.

## Tema Material

`AppTheme` replica os tokens principais do MUI Web: roxo `#6768F2`, verde
`#00E280`, neon `#00FFCE`, escala de cinzas, Poppins, espaçamento base de 8 px,
raios e estilos de botões/campos. O tema claro segue a paleta Web e o tema
escuro é uma adaptação mobile que preserva os mesmos tokens de marca.
