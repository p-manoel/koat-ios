# Validação — 12/09/2026

Concluída a revisão dos cinco PNGs e do vídeo final, todos capturados da conta
do treinador Rafael, com os dados existentes de Mariana Oliveira.

- Build iOS: Release, simulador iPhone 17 Pro Max; compilação concluída.
- Idioma ativo consultado no simulador: `AppleLanguages = (pt-BR)`, `AppleLocale = pt_BR`.
- Aplicação: conta com locale `pt` (tradução brasileira).
- Cinco PNGs: 1320 × 2868, sem transparência; `goldie verify` aprovado.
- Vídeo: 16,8 segundos, 886 × 1920, H.264, 30 fps, AAC estéreo a 48 kHz;
  `goldie verify` aprovado. Apenas gravação do app, sem molduras, legendas ou marca d'água.
- Revisão visual de cada PNG final: títulos legíveis, mesma fonte e composição,
  moldura consistente, telas preenchidas e identidade azul do Koat.
- Revisão de idioma: OCR dos cinco PNGs e de 34 quadros do vídeo (2 por segundo),
  mais inspeção visual das telas e da sequência. Nenhum texto visível não traduzido
  identificado. Nomes de exercícios usados no Brasil, como leg press e stiff,
  foram preservados conforme o cadastro existente.
- Vídeo: plano de Mariana → análise de treino → progressão do agachamento.
  Relógio estável em 09:37 durante todos os segmentos; dados e conta consistentes.
- Fontes locais corrigidas: meses no gráfico, título “Análise de treino” e
  abreviações “Mín - Máx”. Rodapé Bullet desativado no ambiente de captura.
  Patch reproduzível salvo em `patches/koat-web-pt-BR.patch`.
- Nenhum dado de treino, avaliação ou mensagem foi alterado.

Evidências adicionais, ignoradas pelo Git, em `out/`: `verification.txt`,
`screenshot-language-review.txt`, `video-language-review-final.txt`,
`qa/video-contact-final.png` e relatórios de execução em `raw/iphone-6.9/`.

A validação técnica segue as verificações do Goldie; a aprovação editorial
final da App Store pertence à Apple. Não houve publicação ou upload.
