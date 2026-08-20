<template>
  <div class="tela-auth">
    <div class="cartao cartao-auth">
      <MarcaInspire />
      <hr class="divisor" />
      <h1 style="font-size:24px">Recuperar senha</h1>
      <p style="color:var(--texto);font-size:14px;margin:8px 0 22px;line-height:1.5">
        Informe seu e-mail. Enviaremos um link para criar uma nova senha.
      </p>

      <div v-if="erro" class="aviso aviso-erro">{{ erro }}</div>
      <div v-if="ok" class="aviso aviso-ok">
        Link enviado. Confira sua caixa de entrada e o spam.
      </div>

      <form v-if="!ok" @submit.prevent="enviar">
        <div class="grupo">
          <label class="rotulo">E-mail</label>
          <input v-model="email" class="campo" type="email" required placeholder="nome@exemplo.com.br" />
        </div>
        <button class="btn btn-principal" :disabled="ocupado">
          {{ ocupado ? 'Enviando...' : 'Enviar link' }}
        </button>
      </form>

      <div class="centro" style="margin-top:18px">
        <NuxtLink to="/" class="btn-linha">Voltar para o inicio</NuxtLink>
      </div>
      <p class="pe-auth">
        Sem acesso ao e-mail? A administracao pode redefinir sua senha.
      </p>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'default' })
const email = ref(''); const erro = ref(''); const ok = ref(false); const ocupado = ref(false)

async function enviar() {
  erro.value = ''; ocupado.value = true
  const destino = window.location.origin + useRuntimeConfig().app.baseURL + 'nova-senha'
  const { error } = await useSupa().auth.resetPasswordForEmail(email.value.trim(), { redirectTo: destino })
  ocupado.value = false
  if (error) { erro.value = 'Nao foi possivel enviar: ' + error.message; return }
  ok.value = true
}
</script>
