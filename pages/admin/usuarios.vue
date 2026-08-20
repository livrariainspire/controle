<template>
  <div>
    <div class="cabecalho">
      <div><h1>Usuarios</h1><p>Aprove cadastros, defina o perfil e vincule cada pessoa a sua unidade.</p></div>
      <button class="btn btn-principal btn-p" @click="abrirNovo">Criar usuario</button>
    </div>

    <div v-if="msg" class="aviso" :class="erro ? 'aviso-erro' : 'aviso-ok'">{{ msg }}</div>
    <div v-if="carregando" class="carregando">Carregando usuarios...</div>

    <template v-else>
      <div class="painel">
        <div class="painel-topo"><h2>Aguardando aprovacao ({{ pendentes.length }})</h2></div>
        <TabelaVazia v-if="!pendentes.length" titulo="Nenhum cadastro pendente" texto="Novos cadastros aparecem aqui." />
        <div v-else class="tabela-rolagem">
          <table class="lista">
            <thead><tr><th>Nome</th><th>E-mail</th><th>WhatsApp</th><th>Cadastrado</th><th></th></tr></thead>
            <tbody>
              <tr v-for="u in pendentes" :key="u.id">
                <td><strong>{{ u.full_name || '—' }}</strong></td>
                <td>{{ u.email }}</td>
                <td><a :href="linkZap(u.whatsapp)" target="_blank" rel="noopener" class="zap">{{ mascaraZap(u.whatsapp) }}</a></td>
                <td>{{ dataHora(u.created_at) }}</td>
                <td class="acoes-celula">
                  <button class="btn btn-principal btn-p" @click="abrirAprovacao(u)">Aprovar</button>
                  <button class="btn btn-perigo btn-p" @click="recusar(u)">Recusar</button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div class="painel">
        <div class="painel-topo">
          <h2>Todos os usuarios</h2>
          <input v-model="busca" class="campo" style="max-width:260px" type="search" placeholder="Buscar por nome ou e-mail" />
        </div>
        <div class="tabela-rolagem">
          <table class="lista">
            <thead><tr><th>Nome</th><th>Contato</th><th>Perfil</th><th>Unidade</th><th>Situacao</th><th></th></tr></thead>
            <tbody>
              <tr v-for="u in filtrados" :key="u.id">
                <td><strong>{{ u.full_name || '—' }}</strong><div class="mini">{{ u.email }}</div></td>
                <td><a v-if="u.whatsapp" :href="linkZap(u.whatsapp)" target="_blank" rel="noopener" class="zap">{{ mascaraZap(u.whatsapp) }}</a><span v-else>—</span></td>
                <td>{{ rotuloPerfil(u.role) }}</td>
                <td>{{ nomeUnidade(u.unit_id) }}</td>
                <td><span class="selo" :class="classeSelo(u.status)">{{ rotuloSituacao(u.status) }}</span></td>
                <td class="acoes-celula">
                  <button class="btn btn-neutro btn-p" @click="abrirAprovacao(u)">Perfil</button>
                  <button class="btn btn-neutro btn-p" @click="abrirSenha(u)">Senha</button>
                  <button v-if="u.status === 'aprovado'" class="btn btn-neutro btn-p" @click="desativar(u)">Desativar</button>
                  <button class="btn btn-perigo btn-p" @click="abrirExclusao(u)">Excluir</button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </template>

    <!-- perfil / aprovacao -->
    <JanelaModal v-if="alvo" :titulo="`Perfil de ${alvo.full_name || alvo.email}`" @fechar="alvo = null">
      <div class="grupo">
        <label class="rotulo">Perfil de acesso</label>
        <select v-model="papel" class="campo">
          <option value="">Selecione</option>
          <option value="admin">Administracao</option>
          <option value="atendente">Atendimento</option>
          <option value="igreja">Igreja da Rede</option>
          <option value="ponto">Ponto de Partida</option>
        </select>
      </div>
      <div v-if="papel === 'igreja' || papel === 'ponto'" class="grupo">
        <label class="rotulo">Unidade</label>
        <select v-model="unidade" class="campo">
          <option value="">Selecione a unidade</option>
          <option v-for="u in unidadesDoTipo" :key="u.id" :value="u.id">{{ u.name }}</option>
        </select>
        <p v-if="!unidadesDoTipo.length" class="mini" style="margin-top:8px">
          Nenhuma unidade deste tipo cadastrada. Cadastre em "Unidades".
        </p>
      </div>
      <template #acoes>
        <button class="btn btn-neutro btn-p" @click="alvo = null">Cancelar</button>
        <button class="btn btn-principal btn-p" style="width:auto" :disabled="ocupado" @click="aprovar">Salvar e liberar acesso</button>
      </template>
    </JanelaModal>

    <!-- senha -->
    <JanelaModal v-if="alvoSenha" :titulo="`Nova senha de ${alvoSenha.full_name || alvoSenha.email}`" @fechar="alvoSenha = null">
      <div class="grupo">
        <label class="rotulo">Nova senha</label>
        <input v-model="senhaNova" class="campo" placeholder="Minimo 8 caracteres" />
      </div>
      <p class="mini">Informe a nova senha para a pessoa pelo WhatsApp. Ela pode trocar depois em "Minha conta".</p>
      <template #acoes>
        <button class="btn btn-neutro btn-p" @click="alvoSenha = null">Cancelar</button>
        <button class="btn btn-principal btn-p" style="width:auto" :disabled="ocupado" @click="salvarSenha">Definir senha</button>
      </template>
    </JanelaModal>

    <!-- excluir usuario -->
    <JanelaModal v-if="alvoExcluir" :titulo="`Excluir ${alvoExcluir.full_name || alvoExcluir.email}`" @fechar="alvoExcluir = null">
      <p style="font-size:14px;line-height:1.6;color:var(--texto)">
        A conta e o acesso serao apagados definitivamente. Pedidos, vendas e registros
        feitos por esta pessoa continuam no historico com o nome dela.
      </p>
      <div v-if="resumoExclusao" class="painel" style="margin-top:16px">
        <div class="painel-corpo pilha">
          <div class="entre"><span class="mini">Pedidos criados</span><strong>{{ resumoExclusao.pedidos }}</strong></div>
          <div class="entre"><span class="mini">Vendas registradas</span><strong>{{ resumoExclusao.vendas }}</strong></div>
          <div class="entre"><span class="mini">Pedidos atendidos</span><strong>{{ resumoExclusao.atendimentos }}</strong></div>
        </div>
      </div>
      <div class="grupo" style="margin-top:18px">
        <label class="rotulo">Para confirmar, digite EXCLUIR</label>
        <input v-model="confirmaExclusao" class="campo" placeholder="EXCLUIR" />
      </div>
      <template #acoes>
        <button class="btn btn-neutro btn-p" @click="alvoExcluir = null">Cancelar</button>
        <button class="btn btn-perigo btn-p" style="width:auto"
                :disabled="ocupado || confirmaExclusao.trim().toUpperCase() !== 'EXCLUIR'" @click="excluirUsuario">
          {{ ocupado ? 'Excluindo...' : 'Excluir definitivamente' }}
        </button>
      </template>
    </JanelaModal>

    <!-- criar usuario -->
    <JanelaModal v-if="novo" titulo="Criar usuario" @fechar="novo = null">
      <div class="grupo"><label class="rotulo">Nome completo</label><input v-model="novo.full_name" class="campo" /></div>
      <div class="grupo"><label class="rotulo">E-mail</label><input v-model="novo.email" class="campo" type="email" /></div>
      <div class="grupo">
        <label class="rotulo">WhatsApp</label>
        <input :value="mascaraZap(novo.whatsapp)" class="campo" inputmode="numeric"
               @input="e => novo.whatsapp = soDigitos((e.target as HTMLInputElement).value)" />
      </div>
      <div class="grupo"><label class="rotulo">Senha provisoria</label><input v-model="novo.password" class="campo" placeholder="Minimo 8 caracteres" /></div>
      <div class="grupo">
        <label class="rotulo">Perfil</label>
        <select v-model="novo.role" class="campo">
          <option value="">Deixar pendente</option>
          <option value="admin">Administracao</option>
          <option value="atendente">Atendimento</option>
          <option value="igreja">Igreja da Rede</option>
          <option value="ponto">Ponto de Partida</option>
        </select>
      </div>
      <div v-if="novo.role === 'igreja' || novo.role === 'ponto'" class="grupo">
        <label class="rotulo">Unidade</label>
        <select v-model="novo.unit_id" class="campo">
          <option value="">Selecione</option>
          <option v-for="u in unidades.filter(x => x.type === novo.role)" :key="u.id" :value="u.id">{{ u.name }}</option>
        </select>
      </div>
      <template #acoes>
        <button class="btn btn-neutro btn-p" @click="novo = null">Cancelar</button>
        <button class="btn btn-principal btn-p" style="width:auto" :disabled="ocupado" @click="criar">Criar usuario</button>
      </template>
    </JanelaModal>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'app' })

const supa = useSupa()
const usuarios = ref<any[]>([])
const unidades = ref<any[]>([])
const carregando = ref(true)
const busca = ref('')
const msg = ref(''); const erro = ref(false); const ocupado = ref(false)

const alvo = ref<any>(null); const papel = ref(''); const unidade = ref('')
const alvoSenha = ref<any>(null); const senhaNova = ref('')
const novo = ref<any>(null)
const alvoExcluir = ref<any>(null)
const resumoExclusao = ref<any>(null)
const confirmaExclusao = ref('')

const pendentes = computed(() => usuarios.value.filter(u => u.status === 'pendente'))
const filtrados = computed(() => {
  const t = busca.value.trim().toLowerCase()
  if (!t) return usuarios.value
  return usuarios.value.filter(u => `${u.full_name} ${u.email}`.toLowerCase().includes(t))
})
const unidadesDoTipo = computed(() => unidades.value.filter(u => u.type === papel.value))
const nomeUnidade = (id: string | null) => unidades.value.find(u => u.id === id)?.name ?? '—'

async function carregar() {
  const [u, un] = await Promise.all([
    supa.from('profiles').select('*').order('created_at', { ascending: false }),
    supa.from('units').select('*').order('name')
  ])
  usuarios.value = u.data ?? []
  unidades.value = un.data ?? []
  carregando.value = false
}
onMounted(carregar)

function abrirAprovacao(u: any) { alvo.value = u; papel.value = u.role ?? ''; unidade.value = u.unit_id ?? '' }
function abrirSenha(u: any) { alvoSenha.value = u; senhaNova.value = '' }
function abrirNovo() { novo.value = { full_name: '', email: '', whatsapp: '', password: '', role: '', unit_id: '' } }

async function aprovar() {
  msg.value = ''
  if (!papel.value) { erro.value = true; msg.value = 'Selecione o perfil.'; return }
  if (['igreja', 'ponto'].includes(papel.value) && !unidade.value) { erro.value = true; msg.value = 'Selecione a unidade.'; return }
  ocupado.value = true
  const { error } = await supa.rpc('fn_approve_user', {
    p_user: alvo.value.id, p_role: papel.value, p_unit: unidade.value || null
  })
  ocupado.value = false
  erro.value = !!error
  msg.value = error ? error.message : 'Acesso liberado.'
  if (!error) { alvo.value = null; carregar() }
}

async function recusar(u: any) {
  if (!confirm(`Recusar o cadastro de ${u.full_name || u.email}?`)) return
  await supa.rpc('fn_set_user_status', { p_user: u.id, p_status: 'rejeitado', p_note: null })
  carregar()
}

async function desativar(u: any) {
  if (!confirm(`Desativar o acesso de ${u.full_name || u.email}?`)) return
  await supa.rpc('fn_set_user_status', { p_user: u.id, p_status: 'inativo', p_note: null })
  carregar()
}

async function abrirExclusao(u: any) {
  alvoExcluir.value = u; confirmaExclusao.value = ''; resumoExclusao.value = null
  const { data } = await supa.rpc('fn_check_user_delete', { p_id: u.id })
  resumoExclusao.value = Array.isArray(data) ? data[0] : data
}

async function excluirUsuario() {
  msg.value = ''; ocupado.value = true
  try {
    await chamarApi('/delete-user', { user_id: alvoExcluir.value.id })
    erro.value = false; msg.value = 'Usuario excluido.'
    alvoExcluir.value = null; carregar()
  } catch (e: any) { erro.value = true; msg.value = e.message }
  ocupado.value = false
}

async function salvarSenha() {
  msg.value = ''
  if (senhaNova.value.length < 8) { erro.value = true; msg.value = 'A senha precisa ter ao menos 8 caracteres.'; return }
  ocupado.value = true
  try {
    await chamarApi('/set-password', { user_id: alvoSenha.value.id, password: senhaNova.value })
    erro.value = false; msg.value = 'Senha definida. Avise a pessoa pelo WhatsApp.'
    alvoSenha.value = null
  } catch (e: any) { erro.value = true; msg.value = e.message }
  ocupado.value = false
}

async function criar() {
  msg.value = ''; ocupado.value = true
  try {
    await chamarApi('/create-user', novo.value)
    erro.value = false; msg.value = 'Usuario criado.'
    novo.value = null; carregar()
  } catch (e: any) { erro.value = true; msg.value = e.message }
  ocupado.value = false
}
</script>
