<template>
  <div class="marca">
    <img :src="logo" alt="Livraria Inspire" />
    <div class="marca-barra"></div>
    <div>
      <div class="marca-nome">Presence</div>
      <div class="marca-sub">Gestao da equipe</div>
    </div>
  </div>
</template>

<script setup lang="ts">
const logo = useRuntimeConfig().app.baseURL + 'logo-inspire.png'
</script>
