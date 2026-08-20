<template>
  <div>
    <div class="cabecalho">
      <div>
        <h1>Ola, {{ primeiroNome }}</h1>
        <p>{{ frase }}</p>
      </div>
      <NuxtLink v-if="ehUnidade" to="/pedidos/novo" class="btn btn-principal btn-p">Fazer um pedido</NuxtLink>
      <NuxtLink v-if="perfil?.role === 'atendente'" to="/fila" class="btn btn-principal btn-p">Ver a fila</NuxtLink>
    </div>

    <div v-if="carregando" class="carregando">Carregando informacoes...</div>

    <template v-else>
      <div class="resumos">
        <div v-for="c in cartoes" :key="c.rotulo" class="resumo">
          <div class="resumo-rotulo">{{ c.rotulo }}</div>
          <div class="resumo-valor">{{ c.valor }}</div>
          <div class="resumo-nota">{{ c.nota }}</div>
        </div>
      </div>

      <div class="painel">
        <div class="painel-topo">
          <h2>{{ ehStaff ? 'Pedidos mais recentes' : 'Meus pedidos recentes' }}</h2>
          <NuxtLink :to="ehStaff ? (perfil?.role === 'admin' ? '/admin/pedidos' : '/fila') : '/pedidos'" class="btn-linha">Ver todos</NuxtLink>
        </div>
        <TabelaVazia v-if="!pedidos.length" titulo="Nenhum pedido ainda"
          :texto="ehUnidade ? 'Assim que voce fizer um pedido, ele aparece aqui.' : 'Os pedidos das unidades aparecem aqui.'" />
        <div v-else class="tabela-rolagem">
          <table class="lista">
            <thead>
              <tr><th>Codigo</th><th>Unidade</th><th>Situacao</th><th>Atendente</th><th>Criado em</th></tr>
            </thead>
            <tbody>
              <tr v-for="p in pedidos" :key="p.id">
                <td><strong>{{ p.code }}</strong></td>
                <td>{{ p.unit_name }}</td>
                <td><span class="selo" :class="classeSelo(p.status)">{{ rotuloSituacao(p.status) }}</span></td>
                <td>{{ p.attendant_name || '—' }}</td>
                <td>{{ dataHora(p.created_at) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </template>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'app' })

const supa = useSupa()
const sessao = useSessao()
const perfil = computed(() => sessao.value.perfil)
const ehUnidade = computed(() => ['igreja', 'ponto'].includes(perfil.value?.role ?? ''))
const ehStaff = computed(() => ['admin', 'atendente'].includes(perfil.value?.role ?? ''))
const primeiroNome = computed(() => (perfil.value?.full_name || '').split(' ')[0] || 'tudo bem')

const frase = computed(() => ({
  admin: 'Visao geral da operacao da livraria.',
  atendente: 'Acompanhe a fila e seus atendimentos.',
  igreja: 'Peca livros e itens, controle o estoque e registre as vendas.',
  ponto: 'Peca livros e itens, controle o estoque e registre as vendas.'
}[perfil.value?.role ?? ''] ?? ''))

const carregando = ref(true)
const pedidos = ref<any[]>([])
const cartoes = ref<any[]>([])

onMounted(async () => {
  const q = supa.from('orders').select('*').order('created_at', { ascending: false }).limit(8)
  const { data } = await q
  pedidos.value = data ?? []

  if (perfil.value?.role === 'admin') {
    const [fila, atend, unid, usu] = await Promise.all([
      supa.from('orders').select('id', { count: 'exact', head: true }).eq('status', 'fila'),
      supa.from('orders').select('id', { count: 'exact', head: true }).eq('status', 'em_atendimento'),
      supa.from('units').select('id', { count: 'exact', head: true }).eq('active', true),
      supa.from('profiles').select('id', { count: 'exact', head: true }).eq('status', 'pendente')
    ])
    cartoes.value = [
      { rotulo: 'Na fila', valor: fila.count ?? 0, nota: 'Pedidos aguardando atendente' },
      { rotulo: 'Em atendimento', valor: atend.count ?? 0, nota: 'Sendo separados agora' },
      { rotulo: 'Unidades ativas', valor: unid.count ?? 0, nota: 'Igrejas e pontos de partida' },
      { rotulo: 'Cadastros a aprovar', valor: usu.count ?? 0, nota: 'Aguardando sua analise' }
    ]
  } else if (perfil.value?.role === 'atendente') {
    const [fila, meus, feitos] = await Promise.all([
      supa.from('orders').select('id', { count: 'exact', head: true }).eq('status', 'fila'),
      supa.from('orders').select('id', { count: 'exact', head: true }).eq('status', 'em_atendimento').eq('attendant_id', perfil.value.id),
      supa.from('orders').select('id', { count: 'exact', head: true }).eq('status', 'enviado').eq('attendant_id', perfil.value.id)
    ])
    cartoes.value = [
      { rotulo: 'Na fila', valor: fila.count ?? 0, nota: 'Disponiveis para puxar' },
      { rotulo: 'Comigo agora', valor: meus.count ?? 0, nota: 'Em atendimento' },
      { rotulo: 'Ja enviados', valor: feitos.count ?? 0, nota: 'Concluidos por voce' }
    ]
  } else {
    const uid = perfil.value?.unit_id
    const [abertos, est, vendas] = await Promise.all([
      supa.from('orders').select('id', { count: 'exact', head: true }).eq('unit_id', uid).in('status', ['fila', 'em_atendimento']),
      supa.from('stock').select('qty').eq('unit_id', uid),
      supa.from('sales').select('total').eq('unit_id', uid)
    ])
    const totalEstoque = (est.data ?? []).reduce((s: number, r: any) => s + r.qty, 0)
    const totalVendas = (vendas.data ?? []).reduce((s: number, r: any) => s + Number(r.total), 0)
    cartoes.value = [
      { rotulo: 'Pedidos abertos', valor: abertos.count ?? 0, nota: 'Na fila ou em atendimento' },
      { rotulo: 'Itens em estoque', valor: totalEstoque, nota: 'Somando todos os produtos' },
      { rotulo: 'Total vendido', valor: moeda(totalVendas), nota: `${(vendas.data ?? []).length} vendas registradas` }
    ]
  }
  carregando.value = false
})
</script>
