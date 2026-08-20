<template>
  <div>
    <div class="busca">
      <span class="busca-icone">&#128269;</span>
      <input
        v-model="termo"
        class="campo"
        type="search"
        placeholder="Buscar por titulo, autor, edicao ou resumo"
        @input="buscarComEspera"
      />
    </div>

    <p v-if="carregando" class="mini" style="margin-top:12px">Buscando...</p>

    <div v-else-if="resultados.length" style="margin-top:14px">
      <div v-for="p in resultados" :key="p.id" class="carrinho-item">
        <FotoProduto :url="p.photo_url" :titulo="p.title" :tipo="p.type" />
        <div class="cresce">
          <div class="produto-nome">{{ p.title }}</div>
          <div class="produto-meta">
            <span v-if="p.author">{{ p.author }}</span>
            <span v-if="p.author && p.edition"> · </span>
            <span v-if="p.edition">{{ p.edition }}</span>
            <span v-if="!p.author && !p.edition">{{ p.type === 'livro' ? 'Livro' : 'Item da livraria' }}</span>
          </div>
          <div v-if="p.summary" class="produto-resumo">{{ p.summary }}</div>
        </div>
        <button class="btn btn-contorno btn-p" @click="$emit('escolher', p)">Adicionar</button>
      </div>
    </div>

    <p v-else-if="termo.length >= 2" class="mini" style="margin-top:14px">
      Nada encontrado para "{{ termo }}". Tente outra palavra.
    </p>
    <p v-else class="mini" style="margin-top:14px">
      Digite ao menos 2 letras para buscar no catalogo.
    </p>
  </div>
</template>

<script setup lang="ts">
const props = defineProps<{ somenteComEstoque?: boolean; unidadeId?: string | null }>()
defineEmits(['escolher'])

const supa = useSupa()
const termo = ref('')
const resultados = ref<any[]>([])
const carregando = ref(false)
let temporizador: any = null

function buscarComEspera() {
  clearTimeout(temporizador)
  temporizador = setTimeout(buscar, 280)
}

async function buscar() {
  const t = termo.value.trim().toLowerCase()
  if (t.length < 2) { resultados.value = []; return }
  carregando.value = true

  if (props.somenteComEstoque && props.unidadeId) {
    const { data } = await supa
      .from('stock')
      .select('qty, products!inner(id,title,author,edition,summary,photo_url,type)')
      .eq('unit_id', props.unidadeId)
      .gt('qty', 0)
      .ilike('products.search_text', `%${t}%`)
      .limit(20)
    resultados.value = (data ?? []).map((r: any) => ({ ...r.products, estoque: r.qty }))
  } else {
    const { data } = await supa
      .from('products')
      .select('id,title,author,edition,summary,photo_url,type')
      .eq('active', true)
      .ilike('search_text', `%${t}%`)
      .order('title')
      .limit(20)
    resultados.value = data ?? []
  }
  carregando.value = false
}

defineExpose({ limpar: () => { termo.value = ''; resultados.value = [] } })
</script>
