<template>
  <div>
    <div class="cabecalho">
      <div><h1>Meus pedidos</h1><p>Acompanhe cada etapa do atendimento.</p></div>
      <NuxtLink to="/pedidos/novo" class="btn btn-principal btn-p">Fazer um pedido</NuxtLink>
    </div>

    <div v-if="carregando" class="carregando">Carregando pedidos...</div>

    <div v-else class="painel">
      <TabelaVazia v-if="!pedidos.length" titulo="Nenhum pedido ainda"
        texto="Quando sua unidade fizer um pedido, ele aparece aqui." />
      <div v-else class="tabela-rolagem">
        <table class="lista">
          <thead>
            <tr><th>Codigo</th><th>Situacao</th><th>Atendente</th><th>Criado</th><th>Enviado</th><th></th></tr>
          </thead>
          <tbody>
            <tr v-for="p in pedidos" :key="p.id">
              <td><strong>{{ p.code }}</strong></td>
              <td><span class="selo" :class="classeSelo(p.status)">{{ rotuloSituacao(p.status) }}</span></td>
              <td>{{ p.attendant_name || '—' }}</td>
              <td>{{ dataHora(p.created_at) }}</td>
              <td>{{ dataHora(p.completed_at) }}</td>
              <td class="acoes-celula">
                <button class="btn btn-neutro btn-p" @click="abrir(p)">Detalhes</button>
                <button v-if="p.status === 'fila'" class="btn btn-perigo btn-p" @click="cancelar(p)">Cancelar</button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <JanelaModal v-if="aberto" :titulo="`Pedido ${aberto.code}`" @fechar="aberto = null">
      <p class="mini" style="margin-bottom:14px">
        Criado em {{ dataHora(aberto.created_at) }} por {{ aberto.requested_by_name }}
      </p>
      <div v-if="aberto.note" class="aviso aviso-info">{{ aberto.note }}</div>
      <table class="lista" style="font-size:13px">
        <thead><tr><th>Produto</th><th>Pedido</th><th>Enviado</th></tr></thead>
        <tbody>
          <tr v-for="i in itens" :key="i.id">
            <td><strong>{{ i.product_title }}</strong></td>
            <td>{{ i.qty_requested }}</td>
            <td>{{ aberto.status === 'enviado' ? i.qty_sent : '—' }}</td>
          </tr>
        </tbody>
      </table>
      <template #acoes>
        <button class="btn btn-neutro btn-p" @click="aberto = null">Fechar</button>
      </template>
    </JanelaModal>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'app' })

const supa = useSupa()
const pedidos = ref<any[]>([])
const carregando = ref(true)
const aberto = ref<any>(null)
const itens = ref<any[]>([])

async function carregar() {
  const { data } = await supa.from('orders').select('*').order('created_at', { ascending: false })
  pedidos.value = data ?? []
  carregando.value = false
}
onMounted(carregar)

async function abrir(p: any) {
  aberto.value = p
  const { data } = await supa.from('order_items').select('*').eq('order_id', p.id)
  itens.value = data ?? []
}

async function cancelar(p: any) {
  if (!confirm(`Cancelar o pedido ${p.code}?`)) return
  const { error } = await supa.rpc('fn_cancel_order', { p_order: p.id, p_reason: 'Cancelado pela unidade' })
  if (error) { alert(error.message); return }
  carregar()
}
</script>
