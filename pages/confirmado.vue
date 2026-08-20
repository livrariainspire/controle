<template>
  <div class="tela-auth">
    <div class="cartao cartao-auth centro">
      <MarcaInspire />
      <hr class="divisor" />

      <div style="font-size:40px;line-height:1">&#9989;</div>
      <h1 style="font-size:23px;margin-top:14px">E-mail confirmado</h1>

      <p style="color:var(--texto);font-size:14px;margin-top:12px;line-height:1.6">
        <template v-if="situacao === 'pendente'">
          Seu e-mail foi validado. Agora a administracao precisa aprovar seu acesso
          e vincular voce a uma unidade. Voce recebera o aviso pelo WhatsApp informado.
        </template>
        <template v-else-if="situacao === 'aprovado'">
          Seu e-mail foi validado e seu acesso ja esta liberado.
        </template>
        <template v-else>
          Seu e-mail foi validado. Ja pode entrar no sistema.
        </template>
      </p>

      <NuxtLink v-if="situacao === 'aprovado'" to="/painel" class="btn btn-principal" style="margin-top:22px">
        Ir para o painel
      </NuxtLink>
      <NuxtLink v-else to="/" class="btn btn-principal" style="margin-top:22px">
        Ir para a tela de entrada
      </NuxtLink>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'default' })

const situacao = ref('')

onMounted(async () => {
  const s = await carregarSessao()
  situacao.value = s.perfil?.status ?? ''
})
</script>
