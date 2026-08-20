<template>
  <div class="tela-auth">
    <div class="cartao cartao-auth">
      <MarcaInspire />
      <hr class="divisor" />
      <h1 style="font-size:24px">Criar nova senha</h1>
      <p style="color:var(--texto);font-size:14px;margin:8px 0 22px">Escolha uma senha com pelo menos 8 caracteres.</p>

      <div v-if="erro" class="aviso aviso-erro">{{ erro }}</div>
      <div v-if="ok" class="aviso aviso-ok">Senha alterada. Voce ja pode entrar.</div>

      <form v-if="!ok" @submit.prevent="salvar">
        <div class="grupo">
          <label class="rotulo">Nova senha</label>
          <input v-model="senha" class="campo" type="password" required minlength="8" />
        </div>
        <div class="grupo">
          <label class="rotulo">Repetir senha</label>
          <input v-model="senha2" class="campo" type="password" required minlength="8" />
        </div>
        <button class="btn btn-principal" :disabled="ocupado">{{ ocupado ? 'Salvando...' : 'Salvar senha' }}</button>
      </form>

      <div class="centro" style="margin-top:18px">
        <NuxtLink to="/" class="btn-linha">Ir para o inicio</NuxtLink>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'default' })
const senha = ref(''); const senha2 = ref(''); const erro = ref(''); const ok = ref(false); const ocupado = ref(false)

async function salvar() {
  erro.value = ''
  if (senha.value !== senha2.value) { erro.value = 'As duas senhas precisam ser iguais.'; return }
  ocupado.value = true
  const { error } = await useSupa().auth.updateUser({ password: senha.value })
  ocupado.value = false
  if (error) { erro.value = 'Nao foi possivel salvar: ' + error.message; return }
  ok.value = true
}
</script>
