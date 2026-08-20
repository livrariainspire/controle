<template>
  <div>
    <div class="cabecalho">
      <div><h1>Meus atendimentos</h1><p>Informe a quantidade enviada de cada item para concluir o pedido.</p></div>
      <NuxtLink to="/fila" class="btn btn-neutro btn-p">Ir para a fila</NuxtLink>
    </div>

    <div v-if="msg" class="aviso" :class="erro ? 'aviso-erro' : 'aviso-ok'">{{ msg }}</div>
    <div v-if="carregando" class="carregando">Carregando atendimentos...</div>

    <template v-else>
      <div class="painel">
        <div class="painel-topo"><h2>Em atendimento ({{ abertos.length }})</h2></div>
        <TabelaVazia v-if="!abertos.length" titulo="Nada em atendimento"
          texto="Puxe um pedido da fila para comecar." />
        <div v-else class="tabela-rolagem">
          <table class="lista">
            <thead><tr><th>Codigo</th><th>Unidade</th><th>Itens</th><th>Puxado em</th><th></th></tr></thead>
            <tbody>
              <tr v-for="p in abertos" :key="p.id">
                <td><strong>{{ p.code }}</strong></td>
                <td>{{ p.unit_name }}</td>
                <td>{{ p.order_items.length }}</td>
                <td>{{ dataHora(p.claimed_at) }}</td>
                <td class="acoes-celula">
                  <button class="btn btn-principal btn-p" @click="atender(p)">Separar e enviar</button>
                  <button class="btn btn-neutro btn-p" @click="devolver(p)">Devolver a fila</button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div class="painel">
        <div class="painel-topo"><h2>Concluidos por mim</h2></div>
        <TabelaVazia v-if="!concluidos.length" titulo="Nenhum pedido concluido" texto="Seus envios aparecem aqui." />
        <div v-else class="tabela-rolagem">
          <table class="lista">
            <thead><tr><th>Codigo</th><th>Unidade</th><th>Enviado em</th></tr></thead>
            <tbody>
              <tr v-for="p in concluidos" :key="p.id">
                <td><strong>{{ p.code }}</strong></td><td>{{ p.unit_name }}</td><td>{{ dataHora(p.completed_at) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </template>

    <JanelaModal v-if="atual" :titulo="`Separar ${atual.code}`" @fechar="atual = null">
      <p class="mini" style="margin-bottom:14px">{{ atual.unit_name }} · {{ atual.requested_by_name }}</p>
      <div v-if="atual.note" class="aviso aviso-info">{{ atual.note }}</div>
      <div v-for="i in atual.order_items" :key="i.id" class="carrinho-item">
        <div class="cresce">
          <div class="produto-nome">{{ i.product_title }}</div>
          <div class="produto-meta">Pedido: {{ i.qty_requested }}</div>
        </div>
        <div>
          <label class="rotulo" style="margin-bottom:4px">Enviado</label>
          <input v-model.number="i.qty_sent" class="campo qtd" type="number" min="0" />
        </div>
      </div>
      <template #acoes>
        <button class="btn btn-neutro btn-p" @click="atual = null">Cancelar</button>
        <button class="btn btn-principal btn-p" style="width:auto" :disabled="ocupado" @click="concluir">
          {{ ocupado ? 'Enviando...' : 'Confirmar envio' }}
        </button>
      </template>
    </JanelaModal>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'app' })

const supa = useSupa()
const sessao = useSessao()
const abertos = ref<any[]>([])
const concluidos = ref<any[]>([])
const carregando = ref(true)
const atual = ref<any>(null)
const ocupado = ref(false)
const msg = ref(''); const erro = ref(false)

async function carregar() {
  const id = sessao.value.perfil!.id
  const [a, c] = await Promise.all([
    supa.from('orders').select('*, order_items(*)').eq('attendant_id', id).eq('status', 'em_atendimento').order('claimed_at'),
    supa.from('orders').select('*').eq('attendant_id', id).eq('status', 'enviado').order('completed_at', { ascending: false }).limit(30)
  ])
  abertos.value = a.data ?? []
  concluidos.value = c.data ?? []
  carregando.value = false
}
onMounted(carregar)

function atender(p: any) {
  atual.value = { ...p, order_items: p.order_items.map((i: any) => ({ ...i, qty_sent: i.qty_requested })) }
}

async function concluir() {
  ocupado.value = true; msg.value = ''
  const { error } = await supa.rpc('fn_fulfill_order', {
    p_order: atual.value.id,
    p_items: atual.value.order_items.map((i: any) => ({ item_id: i.id, qty_sent: Number(i.qty_sent) || 0 }))
  })
  ocupado.value = false
  erro.value = !!error
  msg.value = error ? error.message : `Pedido ${atual.value.code} enviado e estoque da unidade atualizado.`
  atual.value = null
  carregar()
}

async function devolver(p: any) {
  if (!confirm(`Devolver o pedido ${p.code} para a fila?`)) return
  await supa.rpc('fn_release_order', { p_order: p.id })
  carregar()
}
</script>
