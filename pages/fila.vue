<template>
  <div>
    <div class="cabecalho">
      <div><h1>Fila de pedidos</h1><p>Pedidos aguardando um atendente. Quem puxar primeiro assume o atendimento.</p></div>
      <button class="btn btn-neutro btn-p" @click="carregar">Atualizar</button>
    </div>

    <div v-if="aviso" class="aviso aviso-atencao">{{ aviso }}</div>
    <div v-if="carregando" class="carregando">Carregando fila...</div>

    <div v-else class="painel">
      <TabelaVazia v-if="!pedidos.length" titulo="Fila vazia"
        texto="Nenhum pedido aguardando no momento." />
      <div v-else class="tabela-rolagem">
        <table class="lista">
          <thead><tr><th>Codigo</th><th>Unidade</th><th>Solicitante</th><th>Itens</th><th>Na fila desde</th><th></th></tr></thead>
          <tbody>
            <tr v-for="p in pedidos" :key="p.id">
              <td><strong>{{ p.code }}</strong></td>
              <td>{{ p.unit_name }}</td>
              <td>{{ p.requested_by_name }}</td>
              <td>{{ p.order_items?.length ?? 0 }}</td>
              <td>{{ dataHora(p.created_at) }}</td>
              <td class="acoes-celula">
                <button class="btn btn-neutro btn-p" @click="ver(p)">Ver itens</button>
                <button class="btn btn-principal btn-p" @click="puxar(p)">Puxar pedido</button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <JanelaModal v-if="aberto" :titulo="`Pedido ${aberto.code}`" @fechar="aberto = null">
      <p class="mini" style="margin-bottom:14px">{{ aberto.unit_name }} · {{ aberto.requested_by_name }}</p>
      <div v-if="aberto.note" class="aviso aviso-info">{{ aberto.note }}</div>
      <table class="lista" style="font-size:13px">
        <thead><tr><th>Produto</th><th>Quantidade</th></tr></thead>
        <tbody>
          <tr v-for="i in aberto.order_items" :key="i.id">
            <td><strong>{{ i.product_title }}</strong></td><td>{{ i.qty_requested }}</td>
          </tr>
        </tbody>
      </table>
      <template #acoes>
        <button class="btn btn-neutro btn-p" @click="aberto = null">Fechar</button>
        <button class="btn btn-principal btn-p" style="width:auto" @click="puxar(aberto)">Puxar pedido</button>
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
const aviso = ref('')

async function carregar() {
  carregando.value = true
  const { data } = await supa.from('orders')
    .select('*, order_items(*)').eq('status', 'fila').order('created_at')
  pedidos.value = data ?? []
  carregando.value = false
}
onMounted(carregar)

function ver(p: any) { aberto.value = p }

async function puxar(p: any) {
  aviso.value = ''
  const { error } = await supa.rpc('fn_claim_order', { p_order: p.id })
  if (error) { aviso.value = error.message; aberto.value = null; carregar(); return }
  await navigateTo('/atendimentos')
}
</script>
