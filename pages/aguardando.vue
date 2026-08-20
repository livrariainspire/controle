<template>
  <div class="tela-auth">
    <div class="cartao cartao-auth centro">
      <MarcaInspire />
      <hr class="divisor" />
      <template v-if="perfil?.status === 'pendente'">
        <div style="font-size:34px">&#9203;</div>
        <h1 style="font-size:22px;margin-top:12px">Cadastro em analise</h1>
        <p style="color:var(--texto);font-size:14px;margin-top:10px;line-height:1.6">
          A administracao precisa aprovar seu acesso e vincular voce a uma unidade.
          Assim que isso acontecer, e so entrar normalmente.
        </p>
      </template>
      <template v-else>
        <div style="font-size:34px">&#128274;</div>
        <h1 style="font-size:22px;margin-top:12px">Acesso indisponivel</h1>
        <p style="color:var(--texto);font-size:14px;margin-top:10px;line-height:1.6">
          Sua conta esta {{ rotuloSituacao(perfil?.status || '') .toLowerCase() }}.
          Fale com a administracao da Livraria Inspire.
        </p>
      </template>
      <button class="btn btn-neutro" style="margin-top:22px;width:100%" @click="sair">Sair</button>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'default' })
const perfil = computed(() => useSessao().value.perfil)
</script>
