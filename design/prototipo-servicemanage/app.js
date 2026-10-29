// Protótipo do Service Manage: navegação e dados de exemplo, sem API.
// Os campos seguem o contrato em backend/openapi/servicemanage.yaml.

(function () {
  'use strict';

  // ---------- Dados de exemplo ----------

  // "Agora" do protótipo: quinta, 29 de outubro de 2026, 9:41.
  var HOJE = new Date(2026, 9, 29, 9, 41);

  var CONSUMIDOR = {
    nome: 'Ana Souza',
    email: 'ana.souza@email.com',
    telefone: '(41) 99812-3456',
    cpf: '•••.456.789-••',
    nascimento: '14/03/1992',
  };

  var OBJETOS = [
    { id: 1, tipo: 'veiculo', nome: 'Honda Civic · ABC1D23', detalhe: 'Prata' },
    { id: 2, tipo: 'pet', nome: 'Thor', detalhe: 'Cachorro · Golden · Médio' },
  ];

  var NICHOS = [
    { slug: 'todos', rotulo: 'Todos' },
    { slug: 'barbearia', rotulo: 'Barbearia' },
    { slug: 'cabeleireiro', rotulo: 'Cabeleireiro(a)' },
    { slug: 'manicure', rotulo: 'Manicure' },
    { slug: 'lava_rapido', rotulo: 'Lava-rápido' },
    { slug: 'banho_tosa', rotulo: 'Banho e Tosa' },
    { slug: 'massagem', rotulo: 'Massagem' },
  ];

  // horarios: índice 0 = segunda ... 6 = domingo, como em HorarioNegocioSerializer.
  var SEG_SEX_9_20 = [['09:00', '20:00'], ['09:00', '20:00'], ['09:00', '20:00'], ['09:00', '20:00'], ['09:00', '20:00'], ['08:00', '18:00'], null];
  var SEG_SAB_8_18 = [['08:00', '18:00'], ['08:00', '18:00'], ['08:00', '18:00'], ['08:00', '18:00'], ['08:00', '18:00'], ['08:00', '14:00'], null];

  var NEGOCIOS = [
    {
      id: 'dom-rafael', nome: 'Barbearia Dom Rafael', nicho: 'barbearia', tipo_agenda: 'horario', tipo_objeto: null,
      bairro: 'Batel', distancia: 0.8, x: 128, y: 82,
      descricao: 'Corte clássico e barba na navalha, desde 2014. Atendimento com hora marcada.',
      horarios: SEG_SEX_9_20,
      servicos: [
        { id: 11, nome: 'Corte', descricao: 'Tesoura ou máquina, com lavagem.', duracao: 30, preco: 45, taxa: 10 },
        { id: 12, nome: 'Barba', descricao: 'Toalha quente e navalha.', duracao: 20, preco: 30, taxa: 0 },
        { id: 13, nome: 'Corte + barba', descricao: 'Os dois juntos, com desconto.', duracao: 45, preco: 70, taxa: 15 },
        { id: 14, nome: 'Pigmentação', descricao: 'Barba ou cabelo.', duracao: 40, preco: 60, taxa: 15 },
      ],
      equipe: [
        { id: 21, nome: 'Rafael Moura', funcao: 'Barbeiro · dono' },
        { id: 22, nome: 'Bruno Lima', funcao: 'Barbeiro' },
        { id: 23, nome: 'Caio Reis', funcao: 'Barbeiro' },
      ],
    },
    {
      id: 'brilho', nome: 'Brilho Lava-rápido', nicho: 'lava_rapido', tipo_agenda: 'kanban', tipo_objeto: 'veiculo',
      bairro: 'Água Verde', distancia: 1.4, x: 214, y: 128,
      descricao: 'Lavagem a seco e tradicional. Você deixa o carro e acompanha cada etapa pelo app.',
      horarios: SEG_SAB_8_18,
      etapas: ['Na fila', 'Lavando', 'Secagem', 'Pronto'],
      servicos: [
        { id: 31, nome: 'Lavagem simples', descricao: 'Externa, com secagem.', duracao: 40, preco: 50, taxa: 0 },
        { id: 32, nome: 'Lavagem completa', descricao: 'Externa, interna e aspiração.', duracao: 90, preco: 90, taxa: 20 },
        { id: 33, nome: 'Higienização interna', descricao: 'Bancos, carpete e teto.', duracao: 180, preco: 220, taxa: 40 },
      ],
      equipe: [],
    },
    {
      id: 'lumi', nome: 'Studio Lumi Cabelos', nicho: 'cabeleireiro', tipo_agenda: 'horario', tipo_objeto: null,
      bairro: 'Centro', distancia: 1.1, x: 70, y: 48,
      descricao: 'Corte, cor e tratamento.',
      horarios: SEG_SEX_9_20,
      servicos: [
        { id: 41, nome: 'Escova', descricao: '', duracao: 40, preco: 65, taxa: 10 },
        { id: 42, nome: 'Corte feminino', descricao: '', duracao: 60, preco: 120, taxa: 20 },
      ],
      equipe: [{ id: 51, nome: 'Carla Dias', funcao: 'Cabeleireira' }],
    },
    {
      id: 'patas', nome: 'Patas & Banho', nicho: 'banho_tosa', tipo_agenda: 'kanban', tipo_objeto: 'pet',
      bairro: 'Bigorrilho', distancia: 2.3, x: 54, y: 150,
      descricao: 'Banho, tosa e hidratação.',
      horarios: SEG_SAB_8_18,
      etapas: ['Recebido', 'Banho', 'Tosa', 'Pronto'],
      servicos: [{ id: 61, nome: 'Banho', descricao: 'Porte médio.', duracao: 60, preco: 70, taxa: 0 }],
      equipe: [],
    },
    {
      id: 'lu', nome: 'Unhas da Lu', nicho: 'manicure', tipo_agenda: 'horario', tipo_objeto: null,
      bairro: 'Mercês', distancia: 2.8, x: 266, y: 52,
      descricao: 'Mão, pé e alongamento.',
      horarios: SEG_SEX_9_20,
      servicos: [{ id: 71, nome: 'Mão e pé', descricao: '', duracao: 75, preco: 55, taxa: 10 }],
      equipe: [{ id: 81, nome: 'Luana Prado', funcao: 'Manicure' }],
    },
    {
      id: 'toque', nome: 'Toque Massoterapia', nicho: 'massagem', tipo_agenda: 'horario', tipo_objeto: null,
      bairro: 'Batel', distancia: 1.9, x: 176, y: 166,
      descricao: 'Massagem relaxante e terapêutica.',
      horarios: SEG_SEX_9_20,
      servicos: [{ id: 91, nome: 'Relaxante', descricao: '', duracao: 60, preco: 140, taxa: 30 }],
      equipe: [{ id: 95, nome: 'Marcos Tavares', funcao: 'Massoterapeuta' }],
    },
  ];

  function d(ano, mes, dia, h, m) { return new Date(ano, mes - 1, dia, h, m || 0); }

  // AgendamentoConsumidor: snapshot de serviços, valores e profissional.
  var AGENDAMENTOS = [
    { id: 1, negocio: 'brilho', origem: 'kanban', data: d(2026, 10, 29, 8, 30), servicos: ['Lavagem completa'], valor: 90, taxa: 20, duracao: 90, profissional: '', objeto: 'Honda Civic · ABC1D23', status: 'confirmado', etapa: 1 },
    { id: 2, negocio: 'lumi', origem: 'agenda', data: d(2026, 11, 2, 15, 0), servicos: ['Escova'], valor: 65, taxa: 10, duracao: 40, profissional: 'Carla Dias', objeto: null, status: 'agendado' },
    { id: 3, negocio: 'dom-rafael', origem: 'agenda', data: d(2026, 10, 15, 18, 30), servicos: ['Corte'], valor: 45, taxa: 10, duracao: 30, profissional: 'Rafael Moura', objeto: null, status: 'concluido' },
    { id: 4, negocio: 'patas', origem: 'kanban', data: d(2026, 10, 2, 9, 0), servicos: ['Banho'], valor: 70, taxa: 0, duracao: 60, profissional: '', objeto: 'Thor', status: 'concluido' },
    { id: 5, negocio: 'lumi', origem: 'agenda', data: d(2026, 9, 20, 11, 0), servicos: ['Corte feminino'], valor: 120, taxa: 20, duracao: 60, profissional: 'Carla Dias', objeto: null, status: 'cancelado' },
    { id: 6, negocio: 'lu', origem: 'agenda', data: d(2026, 9, 12, 16, 0), servicos: ['Mão e pé'], valor: 55, taxa: 10, duracao: 75, profissional: 'Luana Prado', objeto: null, status: 'faltou' },
  ];

  var STATUS = {
    agendado: 'Agendado', confirmado: 'Confirmado', concluido: 'Concluído', cancelado: 'Cancelado', faltou: 'Faltou',
  };

  var TELAS = [
    { id: 'entrar', rotulo: 'Entrar' },
    { id: 'explorar', rotulo: 'Explorar' },
    { id: 'negocio', rotulo: 'Negócio' },
    { id: 'agendar', rotulo: 'Agendar' },
    { id: 'confirmado', rotulo: 'Confirmado' },
    { id: 'agenda', rotulo: 'Agenda' },
    { id: 'conta', rotulo: 'Conta' },
  ];

  // ---------- Estado ----------

  var estado = {
    tela: 'entrar',
    nicho: 'todos',
    busca: '',
    pino: 'dom-rafael',
    negocio: 'dom-rafael',
    aba: 'servicos',
    passo: 1,
    escolha: novaEscolha('dom-rafael'),
    agendaAba: 'proximos',
    vinculos: ['dom-rafael', 'brilho', 'lumi'],
    ultimo: null,
    folha: null,
    aviso: null,
  };

  function novaEscolha(negocioId) {
    var n = negocio(negocioId);
    var padrao = negocioId === 'dom-rafael';
    return {
      servicos: padrao ? [13] : [],
      profissional: padrao ? 21 : 'qualquer',
      objeto: n && n.tipo_objeto ? (OBJETOS.filter(function (o) { return o.tipo === n.tipo_objeto; })[0] || {}).id : null,
      dia: chaveDia(addDias(HOJE, 1)),
      hora: padrao ? '14:00' : null,
    };
  }

  // ---------- Utilidades ----------

  var DIAS_CURTOS = ['dom', 'seg', 'ter', 'qua', 'qui', 'sex', 'sáb'];
  var DIAS_LONGOS = ['domingo', 'segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado'];
  var MESES = ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'];
  var MESES_CURTOS = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];

  var moeda = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' });
  function dinheiro(v) { return moeda.format(v); }

  function esc(s) {
    return String(s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }

  function negocio(id) { return NEGOCIOS.filter(function (n) { return n.id === id; })[0]; }
  function rotuloNicho(slug) { return (NICHOS.filter(function (n) { return n.slug === slug; })[0] || {}).rotulo || slug; }
  function iniciais(nome) {
    var curtas = ['da', 'de', 'do', 'das', 'dos', 'e', '&'];
    return nome.split(' ').filter(function (p) { return curtas.indexOf(p.toLowerCase()) < 0; }).slice(0, 2).map(function (p) { return p[0]; }).join('').toUpperCase();
  }
  function primeiroNome(nome) { return nome.split(' ')[0]; }

  function addDias(data, n) { var x = new Date(data); x.setDate(x.getDate() + n); return x; }
  function chaveDia(data) { return data.getFullYear() + '-' + (data.getMonth() + 1) + '-' + data.getDate(); }
  function deChave(chave) { var p = chave.split('-'); return new Date(+p[0], +p[1] - 1, +p[2]); }
  function mesmoDia(a, b) { return chaveDia(a) === chaveDia(b); }
  function indiceSemana(data) { return (data.getDay() + 6) % 7; } // 0 = segunda
  function hhmm(data) { return pad(data.getHours()) + ':' + pad(data.getMinutes()); }
  function pad(n) { return (n < 10 ? '0' : '') + n; }
  function horaFalada(data) { return data.getHours() + 'h' + (data.getMinutes() ? pad(data.getMinutes()) : ''); }
  function minutos(txt) { var p = txt.split(':'); return +p[0] * 60 + +p[1]; }
  function duracaoTxt(min) {
    if (min < 60) return min + ' min';
    var h = Math.floor(min / 60), m = min % 60;
    return h + ' h' + (m ? ' ' + m + ' min' : '');
  }
  function diaRelativo(data) {
    if (mesmoDia(data, HOJE)) return 'hoje';
    if (mesmoDia(data, addDias(HOJE, 1))) return 'amanhã';
    return DIAS_LONGOS[data.getDay()];
  }
  function dataLonga(data) { return DIAS_LONGOS[data.getDay()] + ', ' + data.getDate() + ' de ' + MESES[data.getMonth()]; }

  function abertoAte(n) {
    var h = n.horarios[indiceSemana(HOJE)];
    return h ? 'Aberto até ' + h[1] : 'Fechado hoje';
  }

  // Mesma regra de CancelarAgendamentoService._dentro_prazo.
  function prazoCancelamento(data, duracao) {
    var horas = duracao <= 30 ? 6 : duracao <= 90 ? 12 : 24;
    return { horas: horas, limite: new Date(data.getTime() - horas * 3600000) };
  }

  function servicosEscolhidos() {
    var n = negocio(estado.negocio);
    return n.servicos.filter(function (s) { return estado.escolha.servicos.indexOf(s.id) >= 0; });
  }
  function soma(lista, campo) { return lista.reduce(function (t, s) { return t + s[campo]; }, 0); }

  // Inícios livres de um dia, como em /disponibilidade/. Alguns ficam ocupados de forma fixa.
  function slotsDoDia(n, data, duracao) {
    var h = n.horarios[indiceSemana(data)];
    if (!h) return [];
    var ini = minutos(h[0]), fim = minutos(h[1]), out = [];
    for (var t = ini; t + duracao <= fim; t += 30) {
      var txt = pad(Math.floor(t / 60)) + ':' + pad(t % 60);
      var ocupado = ((data.getDate() * 7 + t / 30 * 3) % 5) === 0;
      if (txt === '14:00') ocupado = false;
      if (mesmoDia(data, HOJE) && t <= HOJE.getHours() * 60 + HOJE.getMinutes() + 30) ocupado = true;
      if (!ocupado) out.push(txt);
    }
    return out;
  }

  // ---------- Ícones (traço, pontas arredondadas) ----------

  var ICONES = {
    busca: '<circle cx="11" cy="11" r="6.5"/><path d="m20 20-4.2-4.2"/>',
    pino: '<path d="M12 21s-7-6.2-7-11.5a7 7 0 0 1 14 0C19 14.8 12 21 12 21z"/><circle cx="12" cy="9.5" r="2.5"/>',
    explorar: '<circle cx="12" cy="12" r="9"/><path d="m15.5 8.5-2 5-5 2 2-5z"/>',
    agenda: '<rect x="3.5" y="5" width="17" height="15" rx="3"/><path d="M8 3v4M16 3v4M3.5 10h17"/>',
    conta: '<circle cx="12" cy="8" r="4"/><path d="M4.5 20c1.2-3.6 4-5.5 7.5-5.5s6.3 1.9 7.5 5.5"/>',
    voltar: '<path d="M15 5l-7 7 7 7"/>',
    direita: '<path d="m9 5 7 7-7 7"/>',
    baixo: '<path d="m6 9 6 6 6-6"/>',
    check: '<path d="m5 12.5 4.5 4.5L19 7.5"/>',
    relogio: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
    cadeado: '<rect x="5" y="10.5" width="14" height="10" rx="2.5"/><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5"/>',
    carro: '<path d="M4.5 16v-3.6L6.6 7.6A2 2 0 0 1 8.4 6.5h7.2a2 2 0 0 1 1.8 1.1l2.1 4.8V16"/><path d="M4.5 12.5h15M3.5 16h17"/><circle cx="8" cy="16" r="1.6"/><circle cx="16" cy="16" r="1.6"/>',
    pata: '<circle cx="6.5" cy="10.5" r="1.7"/><circle cx="10" cy="6.8" r="1.7"/><circle cx="14" cy="6.8" r="1.7"/><circle cx="17.5" cy="10.5" r="1.7"/><path d="M8.5 17.6c0-2.6 1.6-4.6 3.5-4.6s3.5 2 3.5 4.6c0 1.4-1.2 2-2.2 1.6-.9-.3-1.7-.3-2.6 0-1 .4-2.2-.2-2.2-1.6z"/>',
    mais: '<path d="M12 5v14M5 12h14"/>',
    info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8h.01"/>',
    alerta: '<path d="M10.3 4.6 2.9 17.5A2 2 0 0 0 4.6 20.5h14.8a2 2 0 0 0 1.7-3L13.7 4.6a2 2 0 0 0-3.4 0z"/><path d="M12 10v4M12 17h.01"/>',
    sair: '<path d="M14 4h4a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2h-4"/><path d="M10 16l-4-4 4-4M6 12h10"/>',
    vinculo: '<path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1"/><path d="M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1"/>',
    editar: '<path d="M4 20h4L19 9l-4-4L4 16z"/><path d="m13.5 6.5 4 4"/>',
    usuarios: '<circle cx="9" cy="8.5" r="3.5"/><path d="M3 19.5c.9-3 3.2-4.5 6-4.5s5.1 1.5 6 4.5"/><path d="M15.5 5.2a3.5 3.5 0 0 1 0 6.6M17.5 15.3c1.6.6 2.9 2 3.5 4.2"/>',
  };
  function icone(nome, classe) {
    return '<svg class="icon ' + (classe || '') + '" viewBox="0 0 24 24" aria-hidden="true">' + ICONES[nome] + '</svg>';
  }

  // Símbolo S com os três caminhos do s-mark.svg, sem alterar nenhum ponto.
  var S_MARK =
    '<svg class="mark anima" viewBox="0 0 110.42 120" role="img" aria-label="Service Manage">' +
    '<path class="traco traco-1" d="M 30.219,10.039 C 26.859,10.502 25.083,11.014 22.748,12.214 C 18.188,14.534 14.764,18.534 13.196,23.350 C 12.508,25.413 12.332,26.869 12.428,29.397 C 12.556,33.237 13.436,35.525 16.252,39.300 C 17.180,40.532 19.724,43.956 21.916,46.900 C 26.299,52.788 28.347,55.555 36.747,66.979 C 54.297,90.833 63.721,103.376 65.145,104.784 C 68.552,108.112 73.304,109.984 78.376,109.999 C 80.775,109.999 82.231,109.776 84.375,109.104 C 91.495,106.832 96.822,100.848 98.246,93.457 C 98.582,91.697 98.582,88.401 98.246,86.497 C 97.622,82.961 96.438,80.594 93.303,76.498 C 87.447,68.834 71.272,48.004 64.617,39.540 C 62.233,36.501 58.009,31.141 55.257,27.621 C 47.530,17.750 46.106,16.006 45.082,15.078 C 42.474,12.694 39.130,11.030 35.611,10.358 C 34.315,10.118 31.067,9.911 30.219,10.039"/>' +
    '<path class="traco traco-2" d="M 27.019,82.897 C 16.652,82.993 16.108,83.041 14.220,83.921 C 12.300,84.817 10.860,86.433 10.284,88.369 C 9.852,89.761 9.916,91.649 10.444,92.993 C 11.244,95.089 15.948,102.352 17.740,104.304 C 20.060,106.800 22.492,108.144 25.867,108.768 C 26.923,108.960 29.147,109.024 37.450,109.088 C 44.026,109.136 48.106,109.104 48.778,108.992 C 50.826,108.688 52.377,107.632 53.065,106.112 C 53.529,105.120 53.513,103.568 53.049,102.528 C 52.489,101.264 41.434,85.217 40.330,84.065 C 39.658,83.361 38.714,82.945 37.578,82.865 C 37.050,82.833 32.299,82.833 27.019,82.897"/>' +
    '<path class="peca-azul" d="M 66.296,10.598 C 65.640,10.678 64.601,10.886 64.009,11.062 C 61.705,11.766 60.553,13.654 61.033,15.942 C 61.209,16.758 61.593,17.430 63.705,20.582 C 66.600,24.869 67.368,26.005 70.920,31.061 C 77.048,39.812 76.888,39.620 78.568,40.436 C 81.015,41.636 84.071,41.140 85.975,39.236 C 86.375,38.836 87.591,37.093 88.695,35.381 C 89.783,33.669 91.399,31.141 92.263,29.781 C 96.070,23.862 99.974,17.494 100.198,16.902 C 100.326,16.550 100.422,15.750 100.422,15.142 C 100.438,13.094 99.334,11.638 97.222,10.886 L 96.134,10.502 L 81.815,10.486 C 73.944,10.470 66.952,10.518 66.296,10.598"/>' +
    '</svg>';

  // Grafismo "faixas inclinadas": os traços do símbolo em sequência, a 29°.
  function faixas(classe) {
    var barras = '';
    for (var i = -4; i < 14; i++) {
      barras += '<rect x="' + (i * 46) + '" y="-60" width="22" height="320" rx="11" transform="rotate(-29 ' + (i * 46 + 11) + ' 100)"/>';
    }
    return '<svg class="' + classe + '" viewBox="0 0 390 200" preserveAspectRatio="xMidYMid slice" aria-hidden="true" fill="#ffffff">' + barras + '</svg>';
  }

  // ---------- Telas ----------

  var telas = {};

  telas.entrar = function () {
    return '' +
      '<div class="entrar">' +
      '  <div class="entrar-hero">' + faixas('entrar-faixas') +
      '    <img src="assets/s-logo-stacked-white.svg" alt="Service Manage" width="150" height="160">' +
      '    <p>Encontre quem cuida de você e marque o horário pelo app.</p>' +
      '  </div>' +
      '  <form class="entrar-panel" data-form="entrar" novalidate>' +
      '    <h1 class="h3">Entrar</h1>' +
      '    <div class="field"><label for="login-email">E-mail</label><input class="input" id="login-email" type="email" value="' + CONSUMIDOR.email + '" autocomplete="off"></div>' +
      '    <div class="field"><label for="login-senha">Senha</label><input class="input" id="login-senha" type="password" value="exemplo123" autocomplete="off"></div>' +
      '    <button class="btn btn-primary btn-block" type="submit">Entrar</button>' +
      '    <button class="btn btn-text" type="button" data-action="aviso" data-texto="Enviamos um código para ana.souza@email.com. Ele vale por 15 minutos.">Esqueci minha senha</button>' +
      '    <div class="divider-text">Primeira vez aqui?</div>' +
      '    <button class="btn btn-secondary btn-block" type="button" data-action="aviso" data-texto="O cadastro pede nome, e-mail, telefone e senha. Uma conta serve para todos os negócios.">Criar conta</button>' +
      '  </form>' +
      '</div>';
  };

  function filtrados() {
    var q = estado.busca.trim().toLowerCase();
    return NEGOCIOS.filter(function (n) {
      if (estado.nicho !== 'todos' && n.nicho !== estado.nicho) return false;
      if (!q) return true;
      return (n.nome + ' ' + rotuloNicho(n.nicho) + ' ' + n.bairro).toLowerCase().indexOf(q) >= 0;
    }).sort(function (a, b) { return a.distancia - b.distancia; });
  }

  function mapa(lista) {
    var ativo = lista.filter(function (n) { return n.id === estado.pino; })[0] || lista[0];
    var pinos = lista.map(function (n) {
      var cls = 'map-pin' + (ativo && n.id === ativo.id ? ' is-active' : '');
      return '<g class="' + cls + '" data-action="pino" data-id="' + n.id + '" tabindex="0" role="button" aria-label="' + esc(n.nome) + '">' +
        '<circle cx="' + n.x + '" cy="' + n.y + '" r="12"/>' +
        '<text x="' + n.x + '" y="' + (n.y + 4) + '" text-anchor="middle">' + iniciais(n.nome)[0] + '</text></g>';
    }).join('');
    var ruas =
      '<rect class="map-block" x="0" y="0" width="320" height="200"/>' +
      '<path class="map-park" d="M232 20h66v52h-66z"/>' +
      '<g class="map-street" stroke-width="7" stroke-linecap="round">' +
      '<path d="M-10 64H330"/><path d="M-10 140H330"/><path d="M100 -10V210"/><path d="M196 -10V210"/>' +
      '<path d="M-10 196 330 6" stroke-width="9"/></g>' +
      '<g class="map-street" stroke-width="3"><path d="M-10 102H330"/><path d="M40 -10V210"/><path d="M150 -10V210"/><path d="M250 -10V210"/><path d="M-10 26H330"/><path d="M-10 176H330"/></g>' +
      '<g class="map-me"><circle cx="160" cy="112" r="16"/><circle cx="160" cy="112" r="6"/></g>';
    var rotulo = ativo
      ? '<button type="button" class="map-label" data-action="abrir-negocio" data-id="' + ativo.id + '">' +
        '<span class="biz-tile sm">' + iniciais(ativo.nome) + '</span>' +
        '<span class="grow"><span class="name">' + esc(ativo.nome) + '</span><span class="caption">' + rotuloNicho(ativo.nicho) + ' · ' + String(ativo.distancia).replace('.', ',') + ' km</span></span>' +
        icone('direita', 'sm') + '</button>'
      : '';
    return '<div class="map"><svg viewBox="0 0 320 200" preserveAspectRatio="xMidYMid slice" aria-label="Mapa com os negócios perto de você">' + ruas + pinos + '</svg>' + rotulo + '</div>';
  }

  function linhaNegocio(n) {
    return '<button type="button" class="row" data-action="abrir-negocio" data-id="' + n.id + '">' +
      '<span class="biz-tile">' + iniciais(n.nome) + '</span>' +
      '<span class="grow"><span class="title">' + esc(n.nome) + '</span>' +
      '<span class="detail">' + rotuloNicho(n.nicho) + ' · ' + n.bairro + '</span>' +
      '<span class="detail ' + (n.horarios[indiceSemana(HOJE)] ? 'open-now' : '') + '">' + abertoAte(n) + '</span></span>' +
      '<span class="end"><span class="caption num">' + String(n.distancia).replace('.', ',') + ' km</span>' + icone('direita', 'sm') + '</span>' +
      '</button>';
  }

  telas.explorar = function () {
    var lista = filtrados();
    var meus = NEGOCIOS.filter(function (n) { return estado.vinculos.indexOf(n.id) >= 0; });
    var chips = NICHOS.map(function (c) {
      return '<button type="button" class="chip" data-action="nicho" data-slug="' + c.slug + '" aria-pressed="' + (estado.nicho === c.slug) + '">' + c.rotulo + '</button>';
    }).join('');
    var meusHtml = meus.length && estado.nicho === 'todos' && !estado.busca
      ? '<section class="section"><div class="section-head"><h2 class="h3">Seus negócios</h2></div><div class="mine-row">' +
        meus.map(function (n) {
          return '<button type="button" class="mine-card" data-action="abrir-negocio" data-id="' + n.id + '">' +
            '<span class="biz-tile sm">' + iniciais(n.nome) + '</span>' +
            '<span class="name">' + esc(n.nome) + '</span><span class="caption">' + rotuloNicho(n.nicho) + '</span></button>';
        }).join('') + '</div></section>'
      : '';
    return '' +
      '<div class="screen with-tabbar">' +
      '  <header class="topbar"><img class="topbar-logo logo-on-light" src="assets/s-logo.svg" alt="Service Manage" width="200" height="24"><img class="topbar-logo logo-on-dark" src="assets/s-logo-white.svg" alt="Service Manage" width="200" height="24"><span style="flex:1"></span>' +
      '    <button type="button" class="avatar" data-action="ir" data-tela="conta" aria-label="Sua conta">AS</button></header>' +
      '  <div class="greeting"><h1 class="h2">Olá, Ana</h1>' +
      '    <div class="city-row">' + icone('pino', 'sm') + '<span>Perto de</span><button type="button" data-action="aviso" data-texto="As cidades vêm dos negócios publicados na vitrine.">Batel, Curitiba' + icone('baixo', 'sm') + '</button></div></div>' +
      '  <div class="explorar-tools">' +
      '    <label class="search" for="busca">' + icone('busca') + '<input id="busca" type="search" placeholder="Buscar barbearia, lava-rápido…" value="' + esc(estado.busca) + '" autocomplete="off"></label>' +
      '    <div class="chips" role="group" aria-label="Filtrar por tipo de negócio">' + chips + '</div>' +
      '  </div>' +
      '  <section class="section">' + (lista.length ? mapa(lista) : '') + '</section>' +
      meusHtml +
      '  <section class="section"><div class="section-head"><h2 class="h3">Perto de você</h2><span class="caption num">' + lista.length + (lista.length === 1 ? ' negócio' : ' negócios') + '</span></div>' +
      (lista.length
        ? '<div class="list">' + lista.map(linhaNegocio).join('') + '</div>'
        : '<p class="empty">Nenhum negócio encontrado com esse filtro. Tente outro tipo ou limpe a busca.</p>') +
      '  </section>' +
      '</div>';
  };

  telas.negocio = function () {
    var n = negocio(estado.negocio);
    var vinculado = estado.vinculos.indexOf(n.id) >= 0;
    var abas = n.tipo_agenda === 'horario'
      ? [['servicos', 'Serviços'], ['equipe', 'Equipe'], ['horarios', 'Horários']]
      : [['servicos', 'Serviços'], ['horarios', 'Horários']];
    if (!abas.some(function (a) { return a[0] === estado.aba; })) estado.aba = 'servicos';

    var conteudo;
    if (estado.aba === 'servicos') {
      conteudo = '<div class="list">' + n.servicos.map(function (s) {
        var on = estado.escolha.servicos.indexOf(s.id) >= 0;
        return '<button type="button" class="svc" data-action="servico" data-id="' + s.id + '" aria-pressed="' + on + '">' +
          '<span class="check">' + icone('check') + '</span>' +
          '<span class="grow"><span class="title">' + esc(s.nome) + '</span>' +
          (s.descricao ? '<span class="detail">' + esc(s.descricao) + '</span>' : '') +
          '<span class="detail">' + duracaoTxt(s.duracao) + '</span></span>' +
          '<span class="price">' + dinheiro(s.preco) + '</span></button>';
      }).join('') + '</div>';
    } else if (estado.aba === 'equipe') {
      conteudo = '<div class="list">' + n.equipe.map(function (p) {
        return '<div class="row"><span class="avatar">' + iniciais(p.nome) + '</span><span class="grow"><span class="title">' + esc(p.nome) + '</span><span class="detail">' + esc(p.funcao) + '</span></span></div>';
      }).join('') + '</div>';
    } else {
      var hoje = indiceSemana(HOJE);
      var nomes = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];
      conteudo = '<div class="hours">' + n.horarios.map(function (h, i) {
        return '<div class="' + (i === hoje ? 'today' : '') + '"><span>' + nomes[i] + (i === hoje ? ' (hoje)' : '') + '</span><span class="' + (h ? '' : 'muted') + '">' + (h ? h[0] + ' – ' + h[1] : 'Fechado') + '</span></div>';
      }).join('') + '</div>';
    }

    var escolhidos = servicosEscolhidos();
    var resumo = escolhidos.length
      ? '<span class="body-strong num">' + dinheiro(soma(escolhidos, 'preco')) + '</span><span class="caption">' + escolhidos.length + (escolhidos.length === 1 ? ' serviço' : ' serviços') + ' · ' + duracaoTxt(soma(escolhidos, 'duracao')) + '</span>'
      : '<span class="caption">Escolha um ou mais serviços</span>';

    return '' +
      '<div class="screen">' +
      '  <div class="cover">' + faixas('faixas') + '<button type="button" class="icon-btn" data-action="ir" data-tela="explorar" aria-label="Voltar">' + icone('voltar', 'lg') + '</button></div>' +
      '  <div class="biz-head">' +
      '    <span class="biz-tile lg">' + iniciais(n.nome) + '</span>' +
      '    <div><h1 class="h2">' + esc(n.nome) + '</h1>' +
      '      <div class="biz-meta"><span>' + rotuloNicho(n.nicho) + '</span><span>' + icone('pino', 'sm') + n.bairro + ' · ' + String(n.distancia).replace('.', ',') + ' km</span><span class="open-now">' + icone('relogio', 'sm') + abertoAte(n) + '</span></div></div>' +
      '    <p class="muted" style="margin:0">' + esc(n.descricao) + '</p>' +
      '    <div class="biz-actions">' +
      (vinculado
        ? '<button type="button" class="btn btn-secondary btn-sm" data-action="aviso" data-texto="Você está vinculado. O negócio vê seu nome, telefone e o histórico de horários.">' + icone('check', 'sm') + 'Vinculado</button>'
        : '<button type="button" class="btn btn-secondary btn-sm" data-action="vincular" data-id="' + n.id + '">' + icone('vinculo', 'sm') + 'Vincular</button>') +
      '      <button type="button" class="btn btn-secondary btn-sm" data-action="aviso" data-texto="Abre o mapa com a rota até ' + esc(n.bairro) + '.">' + icone('pino', 'sm') + 'Como chegar</button>' +
      '    </div>' +
      '  </div>' +
      '  <div class="tabs" role="tablist">' + abas.map(function (a) {
        return '<button type="button" role="tab" data-action="aba" data-aba="' + a[0] + '" aria-selected="' + (estado.aba === a[0]) + '">' + a[1] + '</button>';
      }).join('') + '</div>' +
      '  <div class="screen-pad" style="padding-bottom:16px">' + conteudo + '</div>' +
      '  <div class="cta-bar"><div class="grow">' + resumo + '</div>' +
      '    <button type="button" class="btn btn-primary" data-action="ir" data-tela="agendar"' + (escolhidos.length ? '' : ' disabled') + '>Agendar</button></div>' +
      '</div>';
  };

  function passosDoFluxo(n) {
    var segundo = n.tipo_agenda === 'kanban' ? (n.tipo_objeto === 'pet' ? 'Pet' : 'Veículo') : 'Profissional';
    return ['Serviços', segundo, 'Quando', 'Revisar'];
  }

  telas.agendar = function () {
    var n = negocio(estado.negocio);
    var e = estado.escolha;
    var passos = passosDoFluxo(n);
    if (estado.passo < 2) estado.passo = 2;
    var p = estado.passo;
    var escolhidos = servicosEscolhidos();
    var duracao = soma(escolhidos, 'duracao');
    var corpo = '', titulo = '', sub = '', podeSeguir = true, botao = 'Continuar';

    if (p === 2 && n.tipo_agenda === 'horario') {
      titulo = 'Com quem?';
      sub = 'Os horários livres mudam conforme o profissional.';
      var ops = [{ id: 'qualquer', nome: 'Qualquer profissional', funcao: 'Mostra todos os horários livres' }].concat(n.equipe);
      corpo = '<div class="options" role="radiogroup">' + ops.map(function (o) {
        var sel = String(e.profissional) === String(o.id);
        return '<button type="button" class="option" role="radio" data-action="profissional" data-id="' + o.id + '" aria-checked="' + sel + '">' +
          '<span class="avatar">' + (o.id === 'qualquer' ? icone('usuarios') : iniciais(o.nome)) + '</span>' +
          '<span class="grow"><span class="title">' + esc(o.nome) + '</span><span class="detail">' + esc(o.funcao) + '</span></span>' +
          '<span class="radio"></span></button>';
      }).join('') + '</div>';
    } else if (p === 2) {
      var pet = n.tipo_objeto === 'pet';
      titulo = pet ? 'Qual pet?' : 'Qual veículo?';
      sub = pet ? 'O negócio recebe os dados do pet junto com o agendamento.' : 'O negócio recebe a placa e o modelo junto com o agendamento.';
      var objs = OBJETOS.filter(function (o) { return o.tipo === n.tipo_objeto; });
      podeSeguir = !!e.objeto;
      corpo = '<div class="options" role="radiogroup">' + objs.map(function (o) {
        var sel = e.objeto === o.id;
        return '<button type="button" class="option" role="radio" data-action="objeto" data-id="' + o.id + '" aria-checked="' + sel + '">' +
          '<span class="avatar">' + icone(pet ? 'pata' : 'carro') + '</span>' +
          '<span class="grow"><span class="title">' + esc(o.nome) + '</span><span class="detail">' + esc(o.detalhe) + '</span></span>' +
          '<span class="radio"></span></button>';
      }).join('') +
        '<button type="button" class="option option-add" data-action="aviso" data-texto="' + (pet ? 'O cadastro pede nome, espécie, porte e raça.' : 'O cadastro pede placa, marca, modelo e cor.') + '">' + icone('mais', 'sm') + (pet ? 'Adicionar pet' : 'Adicionar veículo') + '</button></div>';
    } else if (p === 3) {
      titulo = n.tipo_agenda === 'kanban' ? 'Quando você chega?' : 'Quando?';
      sub = n.tipo_agenda === 'kanban'
        ? 'Escolha o horário de chegada. Você acompanha cada etapa pelo app.'
        : duracaoTxt(duracao) + ' de atendimento' + (e.profissional !== 'qualquer' ? ' com ' + primeiroNome(n.equipe.filter(function (x) { return x.id === e.profissional; })[0].nome) : '') + '.';
      var dias = '';
      for (var i = 0; i < 10; i++) {
        var dia = addDias(HOJE, i);
        var fechado = !n.horarios[indiceSemana(dia)];
        dias += '<button type="button" class="day" role="radio" data-action="dia" data-dia="' + chaveDia(dia) + '" aria-checked="' + (e.dia === chaveDia(dia)) + '"' + (fechado ? ' disabled aria-label="Fechado"' : '') + '>' +
          '<span class="dow">' + (i === 0 ? 'hoje' : DIAS_CURTOS[dia.getDay()]) + '</span><span class="dnum">' + dia.getDate() + '</span></button>';
      }
      var escolhido = deChave(e.dia);
      var slots = slotsDoDia(n, escolhido, duracao);
      var grupos = [['Manhã', 0, 12], ['Tarde', 12, 18], ['Noite', 18, 24]].map(function (g) {
        var doGrupo = slots.filter(function (s) { var h = +s.split(':')[0]; return h >= g[1] && h < g[2]; });
        if (!doGrupo.length) return '';
        return '<p class="period">' + g[0] + '</p><div class="slots" role="radiogroup" aria-label="' + g[0] + '">' + doGrupo.map(function (s) {
          return '<button type="button" class="slot" role="radio" data-action="hora" data-hora="' + s + '" aria-checked="' + (e.hora === s) + '">' + s + '</button>';
        }).join('') + '</div>';
      }).join('');
      podeSeguir = !!e.hora && slots.indexOf(e.hora) >= 0;
      corpo = '<div class="days" role="radiogroup" aria-label="Dia">' + dias + '</div>' +
        '<h3 class="h3" style="margin-top:8px">' + dataLonga(escolhido).replace(/^./, function (c) { return c.toUpperCase(); }) + '</h3>' +
        (slots.length ? grupos : '<p class="empty">Sem horários livres neste dia. Escolha outro dia.</p>');
    } else {
      titulo = 'Revise o agendamento';
      sub = 'Confira antes de confirmar.';
      botao = 'Confirmar horário';
      var data = dataHoraEscolhida();
      var prazo = prazoCancelamento(data, duracao);
      var taxa = soma(escolhidos, 'taxa');
      var quem = n.tipo_agenda === 'horario'
        ? (e.profissional === 'qualquer' ? 'Primeiro profissional livre' : n.equipe.filter(function (x) { return x.id === e.profissional; })[0].nome)
        : OBJETOS.filter(function (o) { return o.id === e.objeto; })[0].nome;
      corpo = '' +
        '<div class="summary">' +
        '  <div class="summary-head"><span class="biz-tile">' + iniciais(n.nome) + '</span><span><span class="body-strong">' + esc(n.nome) + '</span><br><span class="caption">' + n.bairro + ', Curitiba</span></span></div>' +
        '  <dl class="kv">' +
        '    <dt>Quando</dt><dd>' + dataLonga(data) + ', ' + hhmm(data) + '</dd>' +
        '    <dt>' + (n.tipo_agenda === 'horario' ? 'Com' : passos[1]) + '</dt><dd>' + esc(quem) + '</dd>' +
        escolhidos.map(function (s) { return '<dt>' + esc(s.nome) + '</dt><dd>' + dinheiro(s.preco) + '</dd>'; }).join('') +
        '  </dl>' +
        '  <div class="total"><span>Total · ' + duracaoTxt(duracao) + '</span><strong>' + dinheiro(soma(escolhidos, 'preco')) + '</strong></div>' +
        '  <p class="caption" style="margin:0">Você paga no negócio, depois do atendimento.</p>' +
        '</div>' +
        (taxa
          ? '<div class="note warn">' + icone('alerta') + '<span>Cancelamento gratuito até <strong>' + DIAS_LONGOS[prazo.limite.getDay()] + ', ' + hhmm(prazo.limite) + '</strong> (' + prazo.horas + ' horas antes). Depois disso, taxa de ' + dinheiro(taxa) + '.</span></div>'
          : '<div class="note">' + icone('info') + '<span>Cancelamento gratuito a qualquer momento.</span></div>');
    }

    var barras = passos.map(function (_, i) { return '<span class="' + (i < p ? 'done' : '') + '"></span>'; }).join('');
    return '' +
      '<div class="screen">' +
      '  <header class="topbar"><button type="button" class="icon-btn" data-action="passo-voltar" aria-label="Voltar">' + icone('voltar', 'lg') + '</button>' +
      '    <span class="topbar-title">' + esc(n.nome) + '</span><span class="caption num" style="padding-right:8px">' + p + ' de ' + passos.length + '</span></header>' +
      '  <div class="stepper" aria-hidden="true">' + barras + '</div>' +
      '  <div class="step-head"><p class="eyebrow">' + passos[p - 1] + '</p><h1 class="h2">' + titulo + '</h1><p class="muted" style="margin:0">' + sub + '</p></div>' +
      '  <div class="section" style="padding-bottom:24px">' + corpo + '</div>' +
      '  <div class="cta-bar"><button type="button" class="btn btn-primary btn-block" data-action="' + (p === 4 ? 'confirmar' : 'passo-seguir') + '"' + (podeSeguir ? '' : ' disabled') + '>' + botao + '</button></div>' +
      '</div>';
  };

  function dataHoraEscolhida() {
    var dia = deChave(estado.escolha.dia), h = estado.escolha.hora || '14:00';
    dia.setHours(+h.split(':')[0], +h.split(':')[1], 0, 0);
    return dia;
  }

  telas.confirmado = function () {
    var a = estado.ultimo || {
      negocio: 'dom-rafael', origem: 'agenda', data: d(2026, 10, 30, 14, 0), profissional: 'Rafael Moura', objeto: null,
    };
    var n = negocio(a.negocio);
    var frase = a.origem === 'agenda'
      ? 'Ana, ' + diaRelativo(a.data) + ' às ' + horaFalada(a.data) + (a.profissional ? ' com ' + primeiroNome(a.profissional) : '') + '.'
      : 'Ana, ' + diaRelativo(a.data) + ' às ' + horaFalada(a.data) + '. Leve o ' + a.objeto.split(' · ')[0] + ' até o ' + n.nome + '.';
    return '' +
      '<div class="confirm">' + S_MARK +
      '  <h1 class="h2">Horário confirmado</h1>' +
      '  <p class="h3" style="font-weight:500">' + esc(frase) + '</p>' +
      '  <p class="muted">' + (a.origem === 'agenda' ? 'Ele já aparece na sua agenda. Se precisar, você remarca ou cancela por lá.' : 'Na sua agenda você acompanha cada etapa, da fila até o carro pronto.') + '</p>' +
      '  <div class="actions"><button type="button" class="btn btn-primary btn-block" data-action="ir" data-tela="agenda">Ver na agenda</button>' +
      '    <button type="button" class="btn btn-text" data-action="ir" data-tela="explorar">Voltar ao início</button></div>' +
      '</div>';
  };

  function cartaoAgendamento(a, destaque) {
    var n = negocio(a.negocio);
    var quem = a.origem === 'agenda' ? (a.profissional ? 'com ' + primeiroNome(a.profissional) : '') : a.objeto;
    var andamento = a.origem === 'kanban' && a.status === 'confirmado' && typeof a.etapa === 'number';
    var trilha = '';
    if (andamento) {
      trilha = '<div class="track"><div class="track-bar">' + n.etapas.map(function (_, i) { return '<span class="' + (i <= a.etapa ? 'done' : '') + '"></span>'; }).join('') + '</div>' +
        '<div class="track-labels">' + n.etapas.map(function (et, i) { return '<span class="' + (i === a.etapa ? 'now' : '') + '">' + et + '</span>'; }).join('') + '</div></div>';
    }
    var status = andamento
      ? '<span class="status status-andamento">' + n.etapas[a.etapa] + '</span>'
      : '<span class="status status-' + a.status + '">' + STATUS[a.status] + '</span>';
    return '<button type="button" class="appt' + (destaque ? ' is-next' : '') + '" data-action="detalhe" data-id="' + a.id + '">' +
      '<span class="appt-date"><span class="dow">' + (mesmoDia(a.data, HOJE) ? 'hoje' : DIAS_CURTOS[a.data.getDay()]) + '</span><span class="dnum">' + a.data.getDate() + '</span><span class="mon">' + MESES_CURTOS[a.data.getMonth()] + '</span></span>' +
      '<span class="grow"><span class="top"><span class="title">' + esc(n.nome) + '</span>' + status + '</span>' +
      '<span class="detail num">' + hhmm(a.data) + ' · ' + esc(a.servicos.join(' + ')) + (quem ? ' · ' + esc(quem) : '') + '</span>' +
      trilha + '</span></button>';
  }

  function ehProximo(a) {
    if (a.status === 'cancelado' || a.status === 'concluido' || a.status === 'faltou') return false;
    return a.data >= HOJE || mesmoDia(a.data, HOJE);
  }

  telas.agenda = function () {
    var proximos = AGENDAMENTOS.filter(ehProximo).sort(function (a, b) { return a.data - b.data; });
    var historico = AGENDAMENTOS.filter(function (a) { return !ehProximo(a); }).sort(function (a, b) { return b.data - a.data; });
    var lista = estado.agendaAba === 'proximos' ? proximos : historico;
    var vazio = estado.agendaAba === 'proximos'
      ? '<p class="empty">Nenhum horário marcado. Encontre um negócio em Explorar e agende o primeiro.</p>'
      : '<p class="empty">Os horários que já passaram aparecem aqui.</p>';
    return '' +
      '<div class="screen with-tabbar">' +
      '  <header class="topbar"><span class="topbar-title">Agenda</span></header>' +
      '  <div class="seg-wrap"><div class="segmented" role="tablist">' +
      '    <button type="button" role="tab" data-action="agenda-aba" data-aba="proximos" aria-checked="' + (estado.agendaAba === 'proximos') + '">Próximos · ' + proximos.length + '</button>' +
      '    <button type="button" role="tab" data-action="agenda-aba" data-aba="historico" aria-checked="' + (estado.agendaAba === 'historico') + '">Histórico</button>' +
      '  </div></div>' +
      '  <section class="section">' + (lista.length ? '<div class="appts">' + lista.map(function (a, i) { return cartaoAgendamento(a, estado.agendaAba === 'proximos' && i === 0); }).join('') + '</div>' : vazio) + '</section>' +
      '</div>';
  };

  telas.conta = function () {
    var vinc = NEGOCIOS.filter(function (n) { return estado.vinculos.indexOf(n.id) >= 0; });
    function dado(rotulo, valor, travado) {
      return '<div class="row"><span class="grow"><span class="detail">' + rotulo + '</span><span>' + esc(valor) + '</span></span>' + (travado ? '<span class="lock" title="Não pode ser alterado">' + icone('cadeado', 'sm') + '</span>' : '') + '</div>';
    }
    return '' +
      '<div class="screen with-tabbar">' +
      '  <header class="topbar"><span class="topbar-title">Conta</span><button type="button" class="icon-btn" data-action="aviso" data-texto="Você pode editar nome, telefone, CPF, nascimento, endereço e foto. Os negócios vinculados recebem a atualização." aria-label="Editar dados">' + icone('editar') + '</button></header>' +
      '  <div class="profile"><span class="avatar lg">AS</span><h1 class="h2">' + CONSUMIDOR.nome + '</h1><span class="caption">Cliente desde março de 2026</span></div>' +
      '  <section class="section"><h2 class="h3">Seus dados</h2><div class="card-list">' +
      dado('E-mail', CONSUMIDOR.email, true) + dado('Telefone', CONSUMIDOR.telefone) + dado('CPF', CONSUMIDOR.cpf) + dado('Nascimento', CONSUMIDOR.nascimento) +
      '  </div><p class="caption" style="margin:0">O e-mail é o seu login e não muda. O resto você edita, e os negócios vinculados recebem a versão nova.</p></section>' +
      '  <section class="section"><div class="section-head"><h2 class="h3">Veículos e pets</h2><button type="button" class="link" data-action="aviso" data-texto="Escolha entre veículo e pet para começar o cadastro.">Adicionar</button></div><div class="card-list">' +
      OBJETOS.map(function (o) {
        return '<div class="row"><span class="avatar">' + icone(o.tipo === 'pet' ? 'pata' : 'carro') + '</span><span class="grow"><span class="title">' + esc(o.nome) + '</span><span class="detail">' + esc(o.detalhe) + '</span></span></div>';
      }).join('') + '</div></section>' +
      '  <section class="section"><h2 class="h3">Negócios vinculados</h2><div class="card-list">' +
      (vinc.length ? vinc.map(function (n) {
        return '<div class="row"><span class="biz-tile sm">' + iniciais(n.nome) + '</span><span class="grow"><span class="title">' + esc(n.nome) + '</span><span class="detail">' + rotuloNicho(n.nicho) + '</span></span>' +
          '<button type="button" class="link" data-action="desvincular" data-id="' + n.id + '">Desvincular</button></div>';
      }).join('') : '<p class="empty">Nenhum negócio vinculado.</p>') + '</div></section>' +
      '  <section class="section" style="padding-bottom:24px"><button type="button" class="btn btn-secondary btn-block" data-action="ir" data-tela="entrar">' + icone('sair', 'sm') + 'Sair</button></section>' +
      '</div>';
  };

  // ---------- Folhas de baixo ----------

  function folhaHtml() {
    var f = estado.folha;
    if (!f) return '';
    var corpo = '';
    if (f.tipo === 'detalhe' || f.tipo === 'cancelar') {
      var a = AGENDAMENTOS.filter(function (x) { return x.id === f.id; })[0];
      var n = negocio(a.negocio);
      var prazo = prazoCancelamento(a.data, a.duracao);
      var dentro = HOJE <= prazo.limite;
      var podeCancelar = ehProximo(a) && !(a.origem === 'kanban' && typeof a.etapa === 'number');
      if (f.tipo === 'detalhe') {
        corpo = '<div class="summary-head"><span class="biz-tile">' + iniciais(n.nome) + '</span><span><span class="body-strong">' + esc(n.nome) + '</span><br><span class="caption">' + n.bairro + ', Curitiba</span></span></div>' +
          '<dl class="kv"><dt>Quando</dt><dd>' + dataLonga(a.data) + ', ' + hhmm(a.data) + '</dd>' +
          (a.profissional ? '<dt>Com</dt><dd>' + esc(a.profissional) + '</dd>' : '') +
          (a.objeto ? '<dt>' + (n.tipo_objeto === 'pet' ? 'Pet' : 'Veículo') + '</dt><dd>' + esc(a.objeto) + '</dd>' : '') +
          '<dt>Serviços</dt><dd>' + esc(a.servicos.join(' + ')) + '</dd><dt>Total</dt><dd>' + dinheiro(a.valor) + '</dd></dl>' +
          (a.origem === 'kanban' && typeof a.etapa === 'number' && a.status === 'confirmado'
            ? '<div class="note">' + icone('info') + '<span>O atendimento já começou. Agora está em <strong>' + n.etapas[a.etapa] + '</strong>.</span></div>' : '') +
          '<div class="actions">' + (podeCancelar ? '<button type="button" class="btn btn-danger btn-block" data-action="pedir-cancelamento" data-id="' + a.id + '">Cancelar horário</button>' : '') +
          '<button type="button" class="btn btn-secondary btn-block" data-action="fechar-folha">Fechar</button></div>';
      } else {
        corpo = '<h2 class="h3">Cancelar o horário de ' + diaRelativo(a.data) + ', ' + horaFalada(a.data) + '?</h2>' +
          (dentro || !a.taxa
            ? '<p class="muted" style="margin:0">Ainda está no prazo: o cancelamento é gratuito até ' + DIAS_LONGOS[prazo.limite.getDay()] + ', ' + hhmm(prazo.limite) + '.</p>'
            : '<div class="note warn">' + icone('alerta') + '<span>O prazo gratuito acabou. A taxa de <strong>' + dinheiro(a.taxa) + '</strong> fica como pendência no ' + esc(n.nome) + '.</span></div>') +
          '<div class="actions"><button type="button" class="btn btn-danger btn-block" data-action="cancelar" data-id="' + a.id + '">Cancelar horário</button>' +
          '<button type="button" class="btn btn-secondary btn-block" data-action="fechar-folha">Manter horário</button></div>';
      }
    } else if (f.tipo === 'desvincular') {
      var nb = negocio(f.id);
      corpo = '<h2 class="h3">Desvincular de ' + esc(nb.nome) + '?</h2>' +
        '<p class="muted" style="margin:0">O negócio deixa de ver seu CPF, endereço e data de nascimento. Seu nome, telefone e o histórico de horários continuam com ele.</p>' +
        '<div class="actions"><button type="button" class="btn btn-danger btn-block" data-action="confirmar-desvinculo" data-id="' + nb.id + '">Desvincular</button>' +
        '<button type="button" class="btn btn-secondary btn-block" data-action="fechar-folha">Manter vínculo</button></div>';
    }
    return '<div class="scrim" data-action="fechar-folha"></div><div class="sheet" role="dialog" aria-modal="true"><span class="sheet-grip"></span>' + corpo + '</div>';
  }

  // ---------- Renderização ----------

  var app = document.getElementById('app');
  var tabbar = document.getElementById('tabbar');
  var sheetRoot = document.getElementById('sheet-root');
  var tela = document.querySelector('.device-screen');
  var listaTelas = document.getElementById('screen-list');

  function render(manterRolagem) {
    var topo = app.scrollTop;
    app.innerHTML = telas[estado.tela]();
    tela.classList.toggle('is-brand', estado.tela === 'entrar' || estado.tela === 'negocio');

    var abas = [['explorar', 'Explorar', 'explorar'], ['agenda', 'Agenda', 'agenda'], ['conta', 'Conta', 'conta']];
    var comBarra = ['explorar', 'agenda', 'conta'].indexOf(estado.tela) >= 0;
    tabbar.hidden = !comBarra;
    tabbar.innerHTML = abas.map(function (a) {
      return '<button type="button" data-action="ir" data-tela="' + a[0] + '"' + (estado.tela === a[0] ? ' aria-current="page"' : '') + '><span class="pill">' + icone(a[2], 'lg') + '</span>' + a[1] + '</button>';
    }).join('');

    sheetRoot.innerHTML = folhaHtml() + (estado.aviso ? '<div class="toast" role="status">' + esc(estado.aviso) + '</div>' : '');

    listaTelas.innerHTML = TELAS.map(function (t, i) {
      return '<li><button type="button" data-action="ir" data-tela="' + t.id + '"' + (estado.tela === t.id ? ' aria-current="true"' : '') + '><span class="num">' + (i + 1) + '</span>' + t.rotulo + '</button></li>';
    }).join('');

    app.scrollTop = manterRolagem ? topo : 0;
    marcarTopo();
  }

  function marcarTopo() {
    var barra = app.querySelector('.topbar');
    if (barra) barra.classList.toggle('is-scrolled', app.scrollTop > 4);
  }
  app.addEventListener('scroll', marcarTopo, { passive: true });

  var timerAviso;
  function avisar(texto) {
    estado.aviso = texto;
    render(true);
    clearTimeout(timerAviso);
    timerAviso = setTimeout(function () { estado.aviso = null; render(true); }, 3200);
  }

  function ir(destino) {
    estado.folha = null;
    if (destino === 'agendar') {
      var n = negocio(estado.negocio);
      if (!estado.escolha.servicos.length) estado.escolha.servicos = [n.servicos[0].id];
      estado.passo = 2;
    }
    estado.tela = destino;
    render();
  }

  // ---------- Ações ----------

  var acoes = {
    ir: function (el) { ir(el.dataset.tela); },
    aviso: function (el) { avisar(el.dataset.texto); },
    nicho: function (el) { estado.nicho = el.dataset.slug; render(true); },
    pino: function (el) { estado.pino = el.dataset.id; render(true); },
    'abrir-negocio': function (el) {
      if (estado.negocio !== el.dataset.id) estado.escolha = novaEscolha(el.dataset.id);
      estado.negocio = el.dataset.id;
      estado.aba = 'servicos';
      ir('negocio');
    },
    'demo-negocio': function (el) {
      estado.negocio = el.dataset.id;
      estado.escolha = novaEscolha(el.dataset.id);
      if (!estado.escolha.servicos.length) estado.escolha.servicos = [negocio(el.dataset.id).servicos[1].id];
      estado.aba = 'servicos';
      ir('negocio');
    },
    aba: function (el) { estado.aba = el.dataset.aba; render(true); },
    servico: function (el) {
      var id = +el.dataset.id, lista = estado.escolha.servicos, i = lista.indexOf(id);
      if (i >= 0) lista.splice(i, 1); else lista.push(id);
      estado.escolha.hora = null;
      render(true);
    },
    vincular: function (el) {
      estado.vinculos.push(el.dataset.id);
      avisar('Vinculado. O ' + negocio(el.dataset.id).nome + ' agora vê seus dados de contato.');
    },
    profissional: function (el) {
      estado.escolha.profissional = el.dataset.id === 'qualquer' ? 'qualquer' : +el.dataset.id;
      render(true);
    },
    objeto: function (el) { estado.escolha.objeto = +el.dataset.id; render(true); },
    dia: function (el) { estado.escolha.dia = el.dataset.dia; estado.escolha.hora = null; render(true); },
    hora: function (el) { estado.escolha.hora = el.dataset.hora; render(true); },
    'passo-seguir': function () { estado.passo += 1; render(); },
    'passo-voltar': function () {
      if (estado.passo <= 2) { ir('negocio'); return; }
      estado.passo -= 1;
      render();
    },
    confirmar: function () {
      var n = negocio(estado.negocio), e = estado.escolha, esc2 = servicosEscolhidos();
      var prof = n.tipo_agenda === 'horario'
        ? (e.profissional === 'qualquer' ? n.equipe[0].nome : n.equipe.filter(function (x) { return x.id === e.profissional; })[0].nome)
        : '';
      var novo = {
        id: Date.now(), negocio: n.id, origem: n.tipo_agenda === 'kanban' ? 'kanban' : 'agenda', data: dataHoraEscolhida(),
        servicos: esc2.map(function (s) { return s.nome; }), valor: soma(esc2, 'preco'), taxa: soma(esc2, 'taxa'),
        duracao: soma(esc2, 'duracao'), profissional: prof,
        objeto: n.tipo_objeto ? OBJETOS.filter(function (o) { return o.id === e.objeto; })[0].nome : null,
        status: 'agendado',
      };
      AGENDAMENTOS.push(novo);
      if (estado.vinculos.indexOf(n.id) < 0) estado.vinculos.push(n.id);
      estado.ultimo = novo;
      estado.agendaAba = 'proximos';
      ir('confirmado');
    },
    'agenda-aba': function (el) { estado.agendaAba = el.dataset.aba; render(); },
    detalhe: function (el) { estado.folha = { tipo: 'detalhe', id: +el.dataset.id }; render(true); },
    'pedir-cancelamento': function (el) { estado.folha = { tipo: 'cancelar', id: +el.dataset.id }; render(true); },
    cancelar: function (el) {
      var a = AGENDAMENTOS.filter(function (x) { return x.id === +el.dataset.id; })[0];
      var dentro = HOJE <= prazoCancelamento(a.data, a.duracao).limite;
      a.status = 'cancelado';
      estado.folha = null;
      avisar(dentro || !a.taxa ? 'Horário cancelado, sem taxa.' : 'Horário cancelado. A taxa de ' + dinheiro(a.taxa) + ' ficou como pendência no negócio.');
    },
    desvincular: function (el) { estado.folha = { tipo: 'desvincular', id: el.dataset.id }; render(true); },
    'confirmar-desvinculo': function (el) {
      estado.vinculos = estado.vinculos.filter(function (id) { return id !== el.dataset.id; });
      estado.folha = null;
      avisar('Desvinculado do ' + negocio(el.dataset.id).nome + '.');
    },
    'fechar-folha': function () { estado.folha = null; render(true); },
    tema: function (el) {
      var t = el.dataset.tema;
      if (t === 'sistema') document.documentElement.removeAttribute('data-theme');
      else document.documentElement.setAttribute('data-theme', t);
      document.querySelectorAll('[data-action="tema"]').forEach(function (b) { b.setAttribute('aria-checked', String(b === el)); });
      try { localStorage.setItem('sm-prototipo-tema', t); } catch (err) { /* sem armazenamento: segue no tema do sistema */ }
    },
  };

  document.addEventListener('click', function (ev) {
    var el = ev.target.closest('[data-action]');
    if (!el || el.disabled) return;
    var acao = acoes[el.dataset.action];
    if (acao) { ev.preventDefault(); acao(el); }
  });

  document.addEventListener('keydown', function (ev) {
    if ((ev.key === 'Enter' || ev.key === ' ') && ev.target.matches('g[data-action]')) {
      ev.preventDefault();
      acoes[ev.target.dataset.action](ev.target);
    }
    if (ev.key === 'Escape' && estado.folha) acoes['fechar-folha']();
  });

  document.addEventListener('submit', function (ev) {
    if (ev.target.dataset.form === 'entrar') { ev.preventDefault(); ir('explorar'); }
  });

  document.addEventListener('input', function (ev) {
    if (ev.target.id === 'busca') {
      estado.busca = ev.target.value;
      var pos = ev.target.selectionStart;
      render(true);
      var campo = document.getElementById('busca');
      campo.focus();
      try { campo.setSelectionRange(pos, pos); } catch (err) { /* type=search em alguns navegadores */ }
    }
  });

  // ---------- Início ----------

  try {
    var temaSalvo = localStorage.getItem('sm-prototipo-tema');
    var botaoTema = temaSalvo && document.querySelector('[data-action="tema"][data-tema="' + temaSalvo + '"]');
    if (botaoTema) acoes.tema(botaoTema);
  } catch (err) { /* sem armazenamento: segue no tema do sistema */ }

  function abrirPeloEndereco() {
    var alvo = (location.hash || '').replace('#', '');
    if (!telas[alvo]) return false;
    estado.folha = null;
    estado.tela = alvo;
    if (alvo === 'agendar') estado.passo = 3;
    return true;
  }
  window.addEventListener('hashchange', function () { if (abrirPeloEndereco()) render(); });
  abrirPeloEndereco();
  render();
})();
