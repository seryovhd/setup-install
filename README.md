# Instalador VPS para Clezapp Pro + Evolution API v2

Este script permite realizar la instalación automática y optimizada del entorno necesario para ejecutar **Clezapp Pro** junto con el motor de WhatsApp **Evolution API v2** en un servidor VPS o Cloud.

## Requisitos previos

- Servidor VPS con **Linux Ubuntu** (Ubuntu 22.04 LTS o Ubuntu 24.04 LTS Recomendado).
- Al menos 4 GB de RAM (Recomendado 8 GB a 32 GB para alta concurrencia; el script configura SWAP de 4GB automáticamente).
- Dominios o subdominios apuntando a la IP de tu VPS (ej. `clezapp.pro` o `app.clezapp.pro` para el Frontend y `api.clezapp.pro` para el Backend/API).
- Puertos 80 y 443 libres en el servidor.

## Instrucciones de instalación

1. **Clona el repositorio en tu servidor VPS:**

    ```bash
    git clone https://github.com/seryovhd/setup-install.git setup
    ```

2. **Asigna permisos de ejecución:**

    ```bash
    sudo chmod -R 777 setup
    ```

3. **Accede al directorio del script:**

    ```bash
    cd setup
    ```

4. **Ejecuta el script de instalación:**

    ```bash
    sudo ./setup
    ```

**O EN UNA SOLA LÍNEA:**

```bash
git clone https://github.com/seryovhd/install-vps setup && sudo chmod -R 777 setup && cd setup && sudo ./setup
```

El script configurará automáticamente:
- **Node.js 20.x** & **PM2** con soporte de memoria extendida.
- **PostgreSQL** y **Redis**.
- **Evolution API v2** en Docker para conexiones de WhatsApp instantáneas sin lag.
- **Nginx** con proxy inverso y certificados SSL automáticos con **Certbot**.
- Repositorio por defecto: `https://github.com/seryovhd/clezapp.git`

