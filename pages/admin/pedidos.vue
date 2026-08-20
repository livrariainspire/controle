<template>
  <div>
    <div class="cabecalho">
      <div><h1>Pedidos</h1><p>Todos os pedidos da rede. Voce pode redirecionar um atendimento para outro atendente.</p></div>
      <button class="btn btn-neutro btn-p" @click="carregar">Atualizar</button>
    </div>

    <div v-if="msg" class="aviso" :class="erro ? 'aviso-erro' : 'aviso-ok'">{{ msg }}</div>
    <div v-if="carregando" class="carregando">Carregando pedidos...</div>

    <div v-else class="painel">
      <div class="painel-topo">
        <h2>{{ filtrados.length }} pedido(s)</h2>
        <div class="linha-acoes">
          <select v-model="situacao" class="campo" style="max-width:200px">
            <option value="">Todas as situacoes</option>
            <option value="fila">Na fila</option>
            <option value="em_atendimento">Em atendimento</option>
            <option value="enviado">Enviado</option>
            <option value="cancelado">Cancelado</option>
          </select>
          <input v-model="busca" class="campo" style="max-width:220px" type="search" placeholder="Codigo ou unidade" />
        </div>
      </div>
      <TabelaVazia v-if="!filtrados.length" titulo="Nenhum pedido" texto="Nada encontrado com esses filtros." />
      <div v-else class="tabela-rolagem">
        <table class="lista">
          <thead><tr><th>Codigo</th><th>Unidade</th><th>Solicitante</th><th>Situacao</th><th>Atendente</th><th>Criado</th><th></th></tr></thead>
          <tbody>
            <tr v-for="p in filtrados" :key="p.id">
              <td><strong>{{ p.code }}</strong></td>
              <td>{{ p.unit_name }}</td>
              <td>{{ p.requested_by_name }}</td>
              <td><span class="selo" :class="classeSelo(p.status)">{{ rotuloSituacao(p.status) }}</span></td>
              <td>{{ p.attendant_name || '—' }}</td>
              <td>{{ dataHora(p.created_at) }}</td>
              <td class="acoes-celula">
                <button class="btn btn-neutro btn-p" @click="ver(p)">Detalhes</button>
                <button v-if="['fila','em_atendimento'].includes(p.status)" class="btn btn-contorno btn-p" @click="abrirTransferencia(p)">Redirecionar</button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <JanelaModal v-if="aberto" :titulo="`Pedido ${aberto.code}`" @fechar="aberto = null">
      <div class="pilha" style="margin-bottom:16px">
        <div class="entre"><span class="mini">Unidade</span><strong>{{ aberto.unit_name }}</strong></div>
        <div class="entre"><span class="mini">Solicitante</span><strong>{{ aberto.requested_by_name }}</strong></div>
        <div class="entre"><span class="mini">Criado</span><strong>{{ dataHora(aberto.created_at) }}</strong></div>
        <div class="entre"><span class="mini">Puxado</span><strong>{{ dataHora(aberto.claimed_at) }}</strong></div>
        <div class="entre"><span class="mini">Enviado</span><strong>{{ dataHora(aberto.completed_at) }}</strong></div>
      </div>
      <div v-if="aberto.note" class="aviso aviso-info">{{ aberto.note }}</div>
      <table class="lista" style="font-size:13px">
        <thead><tr><th>Produto</th><th>Pedido</th><th>Enviado</th></tr></thead>
        <tbody>
          <tr v-for="i in aberto.order_items" :key="i.id">
            <td><strong>{{ i.product_title }}</strong></td><td>{{ i.qty_requested }}</td><td>{{ i.qty_sent }}</td>
          </tr>
        </tbody>
      </table>
      <template #acoes><button class="btn btn-neutro btn-p" @click="aberto = null">Fechar</button></template>
    </JanelaModal>

    <JanelaModal v-if="transferir" :titulo="`Redirecionar ${transferir.code}`" @fechar="transferir = null">
      <div class="grupo">
        <label class="rotulo">Novo atendente</label>
        <select v-model="novoAtendente" class="campo">
          <option value="">Selecione</option>
          <option v-for="a in atendentes" :key="a.id" :value="a.id">{{ a.full_name || a.email }}</option>
        </select>
      </div>
      <p class="mini">O pedido passa para o atendente escolhido e o registro fica salvo no historico.</p>
      <template #acoes>
        <button class="btn btn-neutro btn-p" @click="transferir = null">Cancelar</button>
        <button class="btn btn-principal btn-p" style="width:auto" :disabled="ocupado" @click="confirmarTransferencia">Redirecionar</button>
      </template>
    </JanelaModal>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'app' })

const supa = useSupa()
const pedidos = ref<any[]>([])
const atendentes = ref<any[]>([])
const carregando = ref(true)
const situacao = ref(''); const busca = ref('')
const aberto = ref<any>(null)
const transferir = ref<any>(null); const novoAtendente = ref('')
const msg = ref(''); const erro = ref(false); const ocupado = ref(false)

const filtrados = computed(() => {
  const t = busca.value.trim().toLowerCase()
  return pedidos.value.filter(p =>
    (!situacao.value || p.status === situacao.value) &&
    (!t || `${p.code} ${p.unit_name} ${p.requested_by_name}`.toLowerCase().includes(t))
  )
})

async function carregar() {
  carregando.value = true
  const [p, a] = await Promise.all([
    supa.from('orders').select('*, order_items(*)').order('created_at', { ascending: false }).limit(300),
    supa.from('profiles').select('id, full_name, email').eq('role', 'atendente').eq('status', 'aprovado').order('full_name')
  ])
  pedidos.value = p.data ?? []
  atendentes.value = a.data ?? []
  carregando.value = false
}
onMounted(carregar)

function ver(p: any) { aberto.value = p }
function abrirTransferencia(p: any) { transferir.value = p; novoAtendente.value = '' }

async function confirmarTransferencia() {
  msg.value = ''
  if (!novoAtendente.value) { erro.value = true; msg.value = 'Selecione o atendente.'; return }
  ocupado.value = true
  const { error } = await supa.rpc('fn_reassign_order', {
    p_order: transferir.value.id, p_attendant: novoAtendente.value
  })
  ocupado.value = false
  erro.value = !!error
  msg.value = error ? error.message : `Pedido ${transferir.value.code} redirecionado.`
  if (!error) { transferir.value = null; carregar() }
}
</script>
