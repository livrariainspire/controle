<template>
  <div class="tela-auth">
    <div class="cartao cartao-auth">
      <MarcaInspire />
      <hr class="divisor" />

      <template v-if="!enviado">
        <h1 style="font-size:26px">Criar minha conta</h1>
        <p style="color:var(--texto);font-size:14px;margin:8px 0 22px;line-height:1.5">
          Preencha seus dados. A administracao aprova o acesso e vincula voce a sua unidade.
        </p>

        <div v-if="erro" class="aviso aviso-erro">{{ erro }}</div>

        <form @submit.prevent="cadastrar">
          <div class="grupo">
            <label class="rotulo">Nome completo</label>
            <input v-model="nome" class="campo" required placeholder="Seu nome e sobrenome" />
          </div>
          <div class="grupo">
            <label class="rotulo">E-mail</label>
            <input v-model="email" class="campo" type="email" required placeholder="nome@exemplo.com.br" />
          </div>
          <div class="grupo">
            <label class="rotulo">WhatsApp</label>
            <input :value="zap" class="campo" required inputmode="numeric"
                   placeholder="(11) 90000-0000" @input="digitarZap" />
          </div>
          <div class="grade-2">
            <div class="grupo">
              <label class="rotulo">Senha</label>
              <input v-model="senha" class="campo" type="password" required minlength="8" placeholder="Minimo 8 caracteres" />
            </div>
            <div class="grupo">
              <label class="rotulo">Repetir senha</label>
              <input v-model="senha2" class="campo" type="password" required minlength="8" placeholder="Digite de novo" />
            </div>
          </div>
          <button class="btn btn-principal" :disabled="ocupado" style="margin-top:6px">
            {{ ocupado ? 'Enviando...' : 'Enviar cadastro' }}
          </button>
        </form>

        <div class="centro" style="margin-top:18px">
          <NuxtLink to="/" class="btn-linha">Ja tenho conta</NuxtLink>
        </div>
      </template>

      <template v-else>
        <h1 style="font-size:24px">Cadastro enviado</h1>
        <p style="color:var(--texto);font-size:14px;margin:12px 0 22px;line-height:1.6">
          A administracao vai revisar seus dados e liberar o acesso. Voce recebera o aviso
          pelo WhatsApp informado.
        </p>
        <NuxtLink to="/" class="btn btn-principal">Voltar para o inicio</NuxtLink>
      </template>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'default' })

const nome = ref(''); const email = ref(''); const zap = ref('')
const senha = ref(''); const senha2 = ref('')
const erro = ref(''); const ocupado = ref(false); const enviado = ref(false)

function digitarZap(e: Event) { zap.value = mascaraZap((e.target as HTMLInputElement).value) }

async function cadastrar() {
  erro.value = ''
  if (senha.value !== senha2.value) { erro.value = 'As duas senhas precisam ser iguais.'; return }
  if (soDigitos(zap.value).length < 10) { erro.value = 'Informe o WhatsApp com DDD.'; return }

  ocupado.value = true
  const { error } = await useSupa().auth.signUp({
    email: email.value.trim(),
    password: senha.value,
    options: { data: { full_name: nome.value.trim(), whatsapp: soDigitos(zap.value) } }
  })
  ocupado.value = false
  if (error) {
    erro.value = error.message.includes('already')
      ? 'Este e-mail ja tem cadastro. Use "Esqueci minha senha".'
      : 'Nao foi possivel cadastrar: ' + error.message
    return
  }
  enviado.value = true
}
</script>
