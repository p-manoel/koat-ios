# Koat — App Store para treinadores (pt-BR)

Capturas reais do app iOS, com Rafael Mendes (`appstore.coach@example.com`)
acompanhando Mariana Oliveira (`appstore.mariana@example.com`). Todos os
arquivos finais usam a mesma base local existente; nenhum histórico foi recriado.

## Ambiente

- App iOS: este repositório, configuração **Release**, iPhone 17 Pro Max.
- `GOLDIE_CAPTURE` só permite o endereço local quando compilado para simulador.
  Builds normais de Release e builds para aparelhos continuam em `app.koat.io`.
- Web: `/Users/pedromanoel/Code/koat`, banco local `koat_development`.
- Inicie a aplicação web com Ruby 3.4.1 e `GOLDIE_CAPTURE=1 bin/rails server -b 0.0.0.0 -p 3000`.
- Idioma do simulador: `pt-BR`; idioma das duas contas: `pt`, a tradução brasileira da aplicação.
- Senha de demonstração: consulte `db/seeds/app_store/README.md` no repositório web.
  Configure `DEMO_PASSWORD` em `.argent/secrets.env` (ignorado pelo Git).
- `patches/koat-web-pt-BR.patch` registra as correções locais de idioma e a
  opção que desativa o rodapé de diagnóstico Bullet nas capturas.
  Elas já estão aplicadas no repositório web desta máquina. Em outro checkout,
  confira com `git apply --check` antes de aplicar.

## Reproduzir

```sh
./goldie/build-release.sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export GOLDIE_CONFIG="$PWD/goldie/goldie.config.ts"
goldie doctor
./goldie/configure-simulator.sh <UDID>
node --experimental-strip-types goldie/capture-session.mjs <UDID>
goldie frame
goldie preview
goldie manifest
goldie verify
goldie studio --no-open
```

A compilação fica em `/tmp/koat-goldie-build`; `KOAT_GOLDIE_APP` permite
substituir o caminho. Goldie desativa indicadores de toque e exige a marca
d'água do Argent desativada. A sessão desta máquina foi configurada assim.

## História e dados

1. Plano de Mariana: frequência semanal e Força e equilíbrio · Fase 2.
2. Prescrição da rotina A: seis exercícios, 18 séries, aproximadamente 35 minutos.
3. Análise: três treinos em sete dias, 13 em 30 dias, 100% das séries concluídas.
4. Agachamento com barra: histórico crescente, última carga de 45 kg em 11/09/2026.
5. Avaliações: comparação dos três registros mais recentes, abrangendo 60 dias.

O vídeo começa no plano de Mariana, mostra o treinador abrir a análise do treino e
consultar a progressão do agachamento. Sem legendas, molduras, música ou cenas
artificiais: somente a gravação do app e a faixa AAC silenciosa do Goldie.

As datas e os indicadores relativos mudam com o calendário. Para uma nova
campanha, confira os dados existentes antes de atualizar as capturas. Não rode
o seed completo sem intenção de atualizar o histórico de demonstração.

Saídas: `out/screenshots/iphone-6.9/pt-BR/` e `out/previews/iphone-6.9/pt-BR/`.
Os arquivos de saída são ignorados pelo Git; configuração e fluxos são duráveis.

## Captura com sessão preservada

`capture-session.mjs` executa os fluxos Argent, captura PNGs e grava os três
segmentos, escrevendo o manifesto que Goldie usa para renderizar. Essa adaptação
evita a reinstalação de `goldie capture`, que tornou o login inicial instável
neste WKWebView. Antes de executar, entre com a conta do treinador no simulador.
O fluxo `store-coach-login` automatiza o acesso quando a tela de login está
visível. Os demais fluxos pressupõem a sessão autenticada e reiniciam somente
o processo do app, sem apagar os dados.

Os seletores de texto nativos do executor não resolvem os elementos deste
WKWebView; usamos `await-ui-element` (árvore de acessibilidade) e posições
conferidas pelo Argent. Os comentários dos fluxos identificam cada toque.

`configure-simulator.sh` confirma o português brasileiro no sistema e no app.
É necessário porque esta versão do Goldie escreve preferências em disco que
não coincidiram com o idioma ativo do simulador.

Para regravar apenas o vídeo, acrescente `--preview-only` a
`capture-session.mjs`. Os fluxos `store-recording-*` são gerados a partir da
configuração: começam e encerram a gravação dentro do mesmo fluxo Argent para
impedir que a restauração do relógio apareça entre os segmentos.

Verificação de idioma: compile `verify-language.swift` com `xcrun swiftc` e
passe os PNGs finais e os quadros extraídos do vídeo. O OCR é evidência auxiliar;
a revisão visual continua necessária para avaliar recortes e legibilidade.
