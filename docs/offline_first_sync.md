# Sincronização offline-first do Example

## Princípios

O SQLite é a fonte de verdade da interface mobile. A coleção DDP é tratada
como transporte reativo, não como armazenamento durável. Assim, abrir, buscar,
editar e excluir documentos continua funcionando sem rede.

Os arquivos não ficam no SQLite. O banco guarda apenas metadados e caminhos;
os bytes ficam em `ApplicationSupport/example_assets/<documentId>`. Isso evita
bancos grandes, facilita retomada e permite que o sistema operacional gerencie
o sandbox normalmente.

## Dados locais

O banco `synergia_offline_v1.db` contém:

- `examples`: snapshot do documento, versão do servidor e estado de sync;
- `example_assets`: imagem, áudio ou anexo com caminho local/URL remota;
- `sync_queue`: outbox transacional, idempotente por entidade/ação;
- `sync_metadata`: cursor incremental confirmado.

Uma alteração é gravada no documento e na outbox na mesma transação. A UI lê
o novo valor imediatamente. A fila usa backoff exponencial (até 5 minutos) e é
retomada ao reconectar ou reabrir o app.

## Fluxo de documentos

1. O mobile gera UUID antes de depender do servidor.
2. `example.mobileUpsert` insere mantendo esse ID ou atualiza com controle
   otimista usando `baseVersion`.
3. Se a versão divergir, o servidor retorna `sync-conflict`; nenhum conteúdo é
   sobrescrito silenciosamente.
4. `example.mobilePull` pagina alterações por `lastupdate` e devolve tombstones
   de exclusões. O cursor só é confirmado depois da aplicação local.
5. Edições ainda presentes na outbox não são sobrescritas por uma publicação
   DDP concorrente.

## Fluxo de arquivos

Há três tipos explícitos:

- `image`: enviada pelo mobile/web e baixada automaticamente para uso offline;
- `audio`: arquivo ou gravação de voz, também baixado automaticamente;
- `attachment`: enviado do mobile/web, mas no sentido servidor → mobile apenas
  metadados e URL são sincronizados. O download acontece sob ação do usuário.

O catálogo é paginado por `example.mobileAssetsPage`, inclusive para os campos
legados `image` e `audio`. Ao fim de um snapshot completo, itens removidos no
servidor e seus caches locais órfãos são eliminados.

Uploads mobile usam `example.uploadAssetChunk`:

- blocos de 192 KiB;
- limite de 15 MB por arquivo;
- offset confirmado pelo servidor para retomada;
- UUID como chave idempotente;
- SHA-256 validado antes da promoção do `.part`;
- escrita em streaming e promoção atômica/cópia segura entre volumes;
- whitelist de MIME e validação de nome, tamanho, categoria e autenticação.

Downloads usam streaming para um arquivo `.part`, validam SHA-256 quando
disponível e só então renomeiam para o caminho definitivo.

## Estados apresentados

Documentos exibem `synced`, `pending`, `syncing`, `failed` ou `conflict`.
Arquivos exibem `localOnly`, `uploading`, `available`, `downloading` ou
`failed`.

Um anexo apenas remoto aparece:

- habilitado com ícone de download quando o DDP está conectado;
- desabilitado e com a mensagem “conecte-se para baixar” quando offline;
- disponível offline após o download.

## Backend e operação

O backend mantém índices para `example.lastupdate`, tombstones e metadados de
anexos. `UPLOADS_DIR` deve apontar para volume persistente e com backup. Em
produção, mantenha TLS/WSS e `MEDIA_ACCESS_TOKEN`; URLs legadas publicadas já
levam token e cache-buster. Não registre tokens nem conteúdo base64 em logs.

Arquivos `.part` ficam no diretório temporário do host e podem ser retomados
após queda do processo. Recomenda-se uma rotina operacional diária para remover
`.part` sem alteração por mais de 24 horas.

## Teste ponta a ponta

1. Inicie Mongo/Meteor e o frontend Web.
2. Na Web, crie um Example e adicione imagens, um áudio gravado e um PDF.
3. Entre no mobile online; confirme que imagem/áudio ficam disponíveis offline
   e o PDF mostra apenas disponibilidade para download.
4. Ative modo avião, edite o documento, fotografe, grave áudio e anexe arquivo.
5. Feche e reabra o app ainda offline; confirme que tudo permanece.
6. Reconecte e confira na Web o documento e os arquivos enviados.
7. Na Web, acrescente/remova mídia; sincronize o mobile e valide o cache.
8. Com o mobile offline, confirme que anexos remotos ainda não baixados ficam
   desabilitados; online, toque para baixar e depois abra novamente offline.
9. Edite o mesmo documento na Web e no mobile offline; ao reconectar, valide a
   sinalização de conflito em vez de perda silenciosa.

Validação automatizada mobile:

```bash
flutter analyze
flutter test
```
