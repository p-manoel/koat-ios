import path from 'node:path';
import { fileURLToPath } from 'node:url';
const appRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
export default {
  appRoot,
  appPath: process.env.KOAT_GOLDIE_APP || '/tmp/koat-goldie-build/Build/Products/Release-iphonesimulator/Koat.app',
  bundleId: 'Koat.Koat',
  devices: ['iphone-6.9'],
  locales: ['pt-BR'],
  appearance: 'light',
  frame: { variant: '17-pro-silver' },
  theme: {
    background: 'linear-gradient(155deg, #173EA5 0%, #2563EB 55%, #122B69 100%)',
    headlineColor: '#FFFFFF', subheadColor: '#E3ECFF',
    fontFamily: '-apple-system, "SF Pro Display", system-ui, sans-serif',
    copyHeightRatio: 0.20, deviceWidthRatio: 0.88,
    layout: 'classic',
  },
  store: {
    name: 'Koat', subtitle: { 'pt-BR': 'Treinos e evolução dos alunos' },
    developer: 'Koat', category: 'Saúde e fitness', rating: 0,
    ratingCount: 'Sem avaliações', ageRating: '4+', price: 'Grátis',
    description: { 'pt-BR': 'Prescreva treinos e acompanhe cada aluno de perto. Organize rotinas, séries e intervalos, consulte o histórico de cargas e compare avaliações ao longo do tempo.' },
  },
  scenes: [
    { kind: 'screenshot', id: '01-plano', flow: 'store-01-plano', headline: { 'pt-BR': 'Seu aluno, de perto' }, subhead: { 'pt-BR': 'Treino e frequência no mesmo lugar.' } },
    { kind: 'screenshot', id: '02-prescricao', flow: 'store-02-prescricao', headline: { 'pt-BR': 'Prescreva cada detalhe' }, subhead: { 'pt-BR': 'Organize exercícios, séries e intervalos.' } },
    { kind: 'screenshot', id: '03-analise', flow: 'store-03-analise', headline: { 'pt-BR': 'Saiba como está evoluindo' }, subhead: { 'pt-BR': 'Acompanhe a frequência e as cargas.' } },
    { kind: 'screenshot', id: '04-cargas', flow: 'store-04-cargas', headline: { 'pt-BR': 'Veja o progresso real' }, subhead: { 'pt-BR': 'Consulte as cargas de cada sessão.' } },
    { kind: 'screenshot', id: '05-avaliacoes', flow: 'store-05-avaliacoes', headline: { 'pt-BR': 'Compare a evolução' }, subhead: { 'pt-BR': 'Avaliações lado a lado ao longo do tempo.' } },
    { kind: 'preview', id: 'preview', segments: [
      { id: 'aluna', flow: 'store-preview-01-aluna' },
      { id: 'analise', flow: 'store-preview-02-analise' },
      { id: 'progresso', flow: 'store-preview-03-progresso', holdSeconds: 4 },
    ] },
  ],
};
