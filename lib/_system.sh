#!/bin/bash
# 
# Gestión del sistema

#######################################
# Crea el usuario
# Argumentos:
#   Ninguno
#######################################
system_create_user() {
  print_banner
  printf "${WHITE} 💻 Verificando/Creando usuario deploy para la instancia...${GRAY_LIGHT}\n\n"

  sleep 2

  if ! id -u deploy &>/dev/null; then
    sudo adduser --disabled-password --gecos "" deploy
    echo "deploy:${mysql_root_password}" | sudo chpasswd
    sudo usermod -aG sudo deploy
  else
    echo "deploy:${mysql_root_password}" | sudo chpasswd
  fi
  sudo usermod -aG docker deploy 2>/dev/null || true

  sleep 2
}


#######################################
# Clona los repositorios usando git
# Argumentos:
#   Ninguno
#######################################
system_git_clone() {
  print_banner
  printf "${WHITE} 💻 Descargando el código de Clezapp Pro...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - deploy <<EOF
  if [ ! -d "/home/deploy/${instancia_add}" ]; then
    git clone ${link_git} /home/deploy/${instancia_add}/
  else
    cd /home/deploy/${instancia_add}
    git config --global --add safe.directory /home/deploy/${instancia_add}
    git fetch origin
    git reset --hard origin/main 2>/dev/null || git pull
  fi
EOF

  sleep 2
}

#######################################
# Actualiza el sistema
# Argumentos:
#   Ninguno
#######################################
system_update() {
  print_banner
  printf "${WHITE} 💻 Vamos a actualizar el sistema de Clezapp Pro...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - root <<EOF
  apt-get update -y
  apt-get install -y ffmpeg curl git wget unzip fontconfig locales ca-certificates

  # Configurar SWAP si hay menos de 1GB disponible para evitar falta de memoria en la compilación
  current_swap=\$(free -m | awk '/^Swap:/ {print \$2}')
  if [ "\${current_swap:-0}" -lt 1024 ]; then
    echo "💾 Configurando memoria SWAP de 4GB para compilación de frontend..."
    fallocate -l 4G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=4096
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    if ! grep -q "/swapfile" /etc/fstab; then
      echo "/swapfile none swap sw 0 0" >> /etc/fstab
    fi
  fi
EOF

  sleep 2
}

#######################################
# Elimina el sistema
# Argumentos:
#   Ninguno
#######################################
deletar_tudo() {
  print_banner
  printf "${WHITE} 💻 Vamos a eliminar Clezapp Pro...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - root <<EOF
  docker container rm redis-${empresa_delete} --force 2>/dev/null || true
  docker container rm evolution-${empresa_delete} --force 2>/dev/null || true
  cd && rm -rf /etc/nginx/sites-enabled/${empresa_delete}-frontend
  cd && rm -rf /etc/nginx/sites-enabled/${empresa_delete}-backend  
  cd && rm -rf /etc/nginx/sites-available/${empresa_delete}-frontend
  cd && rm -rf /etc/nginx/sites-available/${empresa_delete}-backend
  
  sleep 2

  sudo su - postgres <<EOSQL
  dropuser ${empresa_delete} 2>/dev/null || true
  dropdb ${empresa_delete} 2>/dev/null || true
EOSQL
EOF

  sleep 2

  sudo su - deploy <<EOF
  rm -rf /home/deploy/${empresa_delete}
  pm2 delete ${empresa_delete}-frontend ${empresa_delete}-backend 2>/dev/null || true
  pm2 save
EOF

  sleep 2

  print_banner
  printf "${WHITE} 💻 Eliminación de la Instancia/Empresa ${empresa_delete} realizada con éxito...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2
}

#######################################
# Bloquea el sistema
# Argumentos:
#   Ninguno
#######################################
configurar_bloqueio() {
  print_banner
  printf "${WHITE} 💻 Vamos a bloquear Clezapp Pro...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - deploy <<EOF
  pm2 stop ${empresa_bloquear}-backend
  pm2 save
EOF

  sleep 2

  print_banner
  printf "${WHITE} 💻 Bloqueo de la Instancia/Empresa ${empresa_bloquear} realizado con éxito...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2
}

#######################################
# Desbloquea el sistema
# Argumentos:
#   Ninguno
#######################################
configurar_desbloqueio() {
  print_banner
  printf "${WHITE} 💻 Vamos a desbloquear Clezapp Pro...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - deploy <<EOF
  pm2 start ${empresa_bloquear}-backend
  pm2 save
EOF

  sleep 2

  print_banner
  printf "${WHITE} 💻 Desbloqueo de la Instancia/Empresa ${empresa_desbloquear} realizado con éxito...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2
}

#######################################
# Cambia el dominio del sistema
# Argumentos:
#   Ninguno
#######################################
configurar_dominio() {
  print_banner
  printf "${WHITE} 💻 Vamos a cambiar los dominios de Clezapp Pro...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - root <<EOF
  cd && rm -rf /etc/nginx/sites-enabled/${empresa_dominio}-frontend
  cd && rm -rf /etc/nginx/sites-enabled/${empresa_dominio}-backend  
  cd && rm -rf /etc/nginx/sites-available/${empresa_dominio}-frontend
  cd && rm -rf /etc/nginx/sites-available/${empresa_dominio}-backend
EOF

  sleep 2

  sudo su - deploy <<EOF
  cd && cd /home/deploy/${empresa_dominio}/frontend
  sed -i "1c\REACT_APP_BACKEND_URL=https://${alter_backend_url}" .env
  cd && cd /home/deploy/${empresa_dominio}/backend
  sed -i "2c\BACKEND_URL=https://${alter_backend_url}" .env
  sed -i "3c\FRONTEND_URL=https://${alter_frontend_url}" .env 
EOF

  sleep 2
   
  backend_hostname=$(echo "${alter_backend_url/https:\/\/}")

  sudo su - root <<EOF
  cat > /etc/nginx/sites-available/${empresa_dominio}-backend << 'END'
server {
  server_name $backend_hostname;
  location / {
    proxy_pass http://127.0.0.1:${alter_backend_port};
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_cache_bypass \$http_upgrade;
  }
}
END
ln -s /etc/nginx/sites-available/${empresa_dominio}-backend /etc/nginx/sites-enabled
EOF

  sleep 2

  frontend_hostname=$(echo "${alter_frontend_url/https:\/\/}")

  sudo su - root << EOF
cat > /etc/nginx/sites-available/${empresa_dominio}-frontend << 'END'
server {
  server_name $frontend_hostname;
  location / {
    proxy_pass http://127.0.0.1:${alter_frontend_port};
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_cache_bypass \$http_upgrade;
  }
}
END
ln -s /etc/nginx/sites-available/${empresa_dominio}-frontend /etc/nginx/sites-enabled
EOF

  sleep 2

  sudo su - root <<EOF
  service nginx restart
EOF

  sleep 2

  backend_domain=$(echo "${backend_url/https:\/\/}")
  frontend_domain=$(echo "${frontend_url/https:\/\/}")

  sudo su - root <<EOF
  ufw allow 80
  ufw allow 443
  certbot -m $deploy_email \
          --nginx \
          --agree-tos \
          --non-interactive \
          --domains $backend_domain,$frontend_domain
EOF

  sleep 2

  print_banner
  printf "${WHITE} 💻 Cambio de dominio de la Instancia/Empresa ${empresa_dominio} realizado con éxito...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2
}

#######################################
#######################################
# Instala node
# Argumentos:
#   Ninguno
#######################################
system_node_install() {
  print_banner
  printf "${WHITE} 💻 Instalando nodejs y postgresql...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - root <<EOF
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  apt-get install -y nodejs
  sleep 2
  npm install -g npm@latest --loglevel=error
  sleep 2
  apt-get update -y && apt-get install -y postgresql postgresql-contrib
  systemctl enable postgresql
  systemctl start postgresql
  sleep 2
  sudo timedatectl set-timezone America/Mexico_City
EOF

  sleep 2
}

#######################################
# Instala docker
# Argumentos:
#   Ninguno
#######################################
system_docker_install() {
  print_banner
  printf "${WHITE} 💻 Instalando docker...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - root <<EOF
  if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sh /tmp/get-docker.sh
    rm -f /tmp/get-docker.sh
  fi
  systemctl enable docker
  systemctl start docker
EOF

  sleep 2
}

#######################################
# Ask for file location containing
# multiple URL for streaming.
# Globals:
#   WHITE
#   GRAY_LIGHT
#   BATCH_DIR
#   PROJECT_ROOT
# Arguments:
#   None
#######################################
system_puppeteer_dependencies() {
  print_banner
  printf "${WHITE} 💻 Instalando dependencias multimedia y de sistema...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - root <<EOF
  apt-get install -y \
    ca-certificates \
    curl \
    ffmpeg \
    fontconfig \
    fonts-liberation \
    git \
    libatk1.0-0 \
    libc6 \
    libcairo2 \
    libcups2 \
    libdbus-1-3 \
    libexpat1 \
    libfontconfig1 \
    libgbm-dev \
    libglib2.0-0 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libx11-6 \
    libx11-xcb1 \
    libxcb1 \
    libxcomposite1 \
    libxcursor1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxi6 \
    libxrandr2 \
    libxrender1 \
    libxshmfence-dev \
    libxss1 \
    libxtst6 \
    locales \
    lsb-release \
    unzip \
    wget \
    xdg-utils 2>/dev/null || true
EOF

  sleep 2
}

#######################################
# installs pm2
# Arguments:
#   None
#######################################
system_pm2_install() {
  print_banner
  printf "${WHITE} 💻 Instalando pm2...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - root <<EOF
  npm install -g pm2 --loglevel=error

EOF

  sleep 2
}

#######################################
# installs snapd
# Arguments:
#   None
#######################################
system_snapd_install() {
  print_banner
  printf "${WHITE} 💻 Instalando snapd...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - root <<EOF
  apt install -y snapd
  snap install core
  snap refresh core
EOF

  sleep 2
}

#######################################
# installs certbot
# Arguments:
#   None
#######################################
system_certbot_install() {
  print_banner
  printf "${WHITE} 💻 Instalando certbot...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - root <<EOF
  apt-get remove certbot
  snap install --classic certbot
  ln -s /snap/bin/certbot /usr/bin/certbot
EOF

  sleep 2
}

#######################################
# installs nginx
# Arguments:
#   None
#######################################
system_nginx_install() {
  print_banner
  printf "${WHITE} 💻 Instalando nginx...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - root <<EOF
  apt install -y nginx
  rm /etc/nginx/sites-enabled/default
EOF

  sleep 2
}

#######################################
# restarts nginx
# Arguments:
#   None
#######################################
system_nginx_restart() {
  print_banner
  printf "${WHITE} 💻 reiniciando nginx...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - root <<EOF
  service nginx restart
EOF

  sleep 2
}

#######################################
# setup for nginx.conf
# Arguments:
#   None
#######################################
system_nginx_conf() {
  print_banner
  printf "${WHITE} 💻 configurando nginx...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

sudo su - root << EOF

cat > /etc/nginx/conf.d/deploy.conf << 'END'
client_max_body_size 100M;
END

EOF

  sleep 2
}

#######################################
# installs nginx
# Arguments:
#   None
#######################################
system_certbot_setup() {
  print_banner
  printf "${WHITE} 💻 Configurando certbot...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  backend_domain=$(echo "$backend_url" | sed -E 's|https?://([^/]+).*|\1|')
  frontend_domain=$(echo "$frontend_url" | sed -E 's|https?://([^/]+).*|\1|')

  sudo ufw allow 80
  sudo ufw allow 443

  if certbot -m "$deploy_email" --nginx --agree-tos --non-interactive --domains "$backend_domain","$frontend_domain"; then
    echo "✅ Certbot se ejecutó correctamente y los certificados SSL están activos."
  else
    echo "⚠️ Certbot no pudo generar los certificados SSL automáticamente (comprueba que los registros DNS A de $frontend_domain y $backend_domain apunten a este VPS)."
    echo "➡️ Una vez que el DNS propague, puedes instalar el SSL en cualquier momento con la Opción [14] del instalador."
  fi

  sleep 2
}

system_self_update() {
  print_banner
  printf "${WHITE} 💻 Verificando actualizaciones del instalador...${GRAY_LIGHT}\n\n"
  cd "$PROJECT_ROOT" || return 0
  git config --global --add safe.directory "$PROJECT_ROOT"
  git fetch --quiet || true
  local_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  local_hash=$(git rev-parse HEAD 2>/dev/null)
  remote_hash=$(git rev-parse origin/$local_branch 2>/dev/null || git rev-parse @{u} 2>/dev/null)
  if [ -n "$remote_hash" ] && [ "$local_hash" != "$remote_hash" ]; then
    printf "${YELLOW} ⚠️ Hay una nueva versión disponible.${GRAY_LIGHT}\n\n"
    read -p "> ¿Deseas actualizar ahora? (s/N) " resp
    resp=${resp:-N}
    if [[ "$resp" =~ ^[sS]$ ]]; then
      git reset --hard "origin/$local_branch" || git pull --ff-only
      printf "\n✅ ${WHITE}Instalador actualizado.${GRAY_LIGHT}\n\n"
    else
      printf "\n➡️  Continuando sin actualizar.${GRAY_LIGHT}\n\n"
    fi
  else
    printf "✅ ${WHITE}Ya estás en la última versión.${GRAY_LIGHT}\n\n"
  fi
}

backend_logs() {
  print_banner
  printf "${WHITE} 💻 Logs Backend...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2
  sudo -u deploy pm2 logs $(echo "$instancia_add")-backend

  sleep 2
}

frontend_logs() {
  print_banner
  printf "${WHITE} 💻 Logs Frontend...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2
  sudo -u deploy pm2 logs $(echo "$instancia_add")-frontend

  sleep 2
}

backend_migrate() {
  print_banner
  printf "${WHITE} 💻 FIX MIGRACIONES - Sincronizando y ejecutando migraciones...${GRAY_LIGHT}\n\n"

  sleep 2
  cd /home/deploy/"${instancia_add}"/backend || return 1
  echo "🏗️  Compilando backend..."
  sudo -u deploy npm run build
  echo "🛢️  Ejecutando migraciones de base de datos..."
  sudo -u deploy npx sequelize db:migrate
  echo "🌱 Verificando semillas..."
  sudo -u deploy npx sequelize db:seed:all || true
  sleep 2
}

pm2_reinstall(){
  print_banner
  printf "${WHITE} 💻 INICIANDO FIX PM2 DE FRONTEND Y BACKEND...${GRAY_LIGHT}\n\n"
  sleep 1

  printf "${WHITE} ⏳ ESTE PROCESO PUEDE TARDAR UN POCO, POR FAVOR ESPERA...\n\n"

  FRONT_PATH="/home/deploy/${instancia_add}/frontend"
  BACK_PATH="/home/deploy/${instancia_add}/backend"

  ## Asegurar que PM2 esté instalado como deploy
  echo -e "\n🔧 Verificando PM2 para el usuario deploy..."
  sudo -u deploy bash -c 'command -v pm2 >/dev/null 2>&1 || npm install -g pm2'

  ## -------- FRONTEND -------- ##
  echo -e "\n🔧 Frontend:"
  cd "$FRONT_PATH" || { echo "❌ No se pudo acceder al frontend en $FRONT_PATH"; return 1; }
  sudo -u deploy pm2 start server.js --name "${instancia_add}-frontend"
  sudo -u deploy pm2 save --force

  ## -------- BACKEND -------- ##
  echo -e "\n🔧 Backend:"
  cd "$BACK_PATH" || { echo "❌ No se pudo acceder al backend en $BACK_PATH"; return 1; }
  sudo -u deploy pm2 start dist/server.js --node-args="--max-old-space-size=4096 --experimental-global-webcrypto" --name "${instancia_add}-backend"
  sudo -u deploy pm2 save --force

  echo -e "\n✅ ${WHITE}PM2 COMPLETO COMO DEPLOY${GRAY_LIGHT}\n"
  sleep 2
}

build_ambos() {
  print_banner
  printf "${WHITE} 💻 INICIANDO BUILD DE FRONTEND Y BACKEND...${GRAY_LIGHT}\n\n"
  sleep 1

  printf "${WHITE} ⏳ ESTE PROCESO PUEDE TARDAR UNOS MINUTOS, POR FAVOR ESPERA...\n\n"

  FRONT_PATH="/home/deploy/${instancia_add}/frontend"
  BACK_PATH="/home/deploy/${instancia_add}/backend"

  ## -------- FRONTEND -------- ##
  echo -e "\n🔧 Frontend:"
  cd "$FRONT_PATH" || { echo "❌ No se pudo acceder al frontend en $FRONT_PATH"; return 1; }

  echo "🧹 Limpiando build anterior..."
  sudo -u deploy rm -rf build

  echo "🏗️  Construyendo versión de producción del frontend..."
  sudo -u deploy bash -c "
    cd $FRONT_PATH && \
    export NODE_OPTIONS='--openssl-legacy-provider --max-old-space-size=4096' && \
    export GENERATE_SOURCEMAP=false && \
    export INLINE_RUNTIME_CHUNK=false && \
    npm run build
  "
  
  ## -------- BACKEND -------- ##
  echo -e "\n🔧 Backend:"
  cd "$BACK_PATH" || { echo "❌ No se pudo acceder al backend en $BACK_PATH"; return 1; }

  echo "🧹 Limpiando build anterior..."
  sudo -u deploy rm -rf dist build

  echo "🏗️  Construyendo nueva versión del backend..."
  sudo -u deploy npm run build

  echo -e "\n✅ ${WHITE}BUILD COMPLETO${GRAY_LIGHT}\n"
  sleep 2
}

backend_build() {
  print_banner
  printf "${WHITE} 💻 BUILD BACKEND...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2
  BACK_PATH="/home/deploy/${instancia_add}/backend"

  echo -e "\n🔧 Backend:"
  cd "$BACK_PATH" || { echo "❌ No se pudo acceder al backend en $BACK_PATH"; return 1; }

  echo "🧹 Limpiando build anterior..."
  sudo -u deploy rm -rf dist build 
  sleep 2
  echo "🏗️  Construyendo nueva versión del backend..."
  sudo -u deploy npm run build 
  sleep 2
  echo -e "\n✅ ${WHITE}BUILD COMPLETO${GRAY_LIGHT}\n"
}

frontend_build() {
  print_banner
  printf "${WHITE} 💻 BUILD FRONTEND...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2
  FRONT_PATH="/home/deploy/${instancia_add}/frontend"
  
  echo -e "\n🔧 Frontend:"
  cd "$FRONT_PATH" || { echo "❌ No se pudo acceder al frontend en $FRONT_PATH"; return 1; }

  echo "🧹 Limpiando build anterior..."
  sudo -u deploy rm -rf build
  sleep 2
  echo "🏗️  Construyendo nueva versión del frontend..."
  sudo -u deploy bash -c "
    cd $FRONT_PATH && \
    export NODE_OPTIONS='--openssl-legacy-provider --max-old-space-size=4096' && \
    export GENERATE_SOURCEMAP=false && \
    export INLINE_RUNTIME_CHUNK=false && \
    npm run build
  "
  sleep 2
  echo -e "\n✅ ${WHITE}BUILD COMPLETO${GRAY_LIGHT}\n"
}
change_version() {
  print_banner
  printf "${WHITE} 💻 CAMBIAR VERSIÓN...${GRAY_LIGHT}\n\n"

  sleep 2
  FRONT_PATH="/home/deploy/${empresa_atualizar}"
  GIT_URL="${link_git}"

  echo -e "\n🔧 Ruta:"
  cd "$FRONT_PATH" || { echo "❌ No se pudo acceder al frontend en $FRONT_PATH"; return 1; }

  echo -e "\n🔗 Cambiando URL del repositorio remoto a:\n$GIT_URL"
  
  # Agrega el directorio como seguro
  git config --global --add safe.directory "$FRONT_PATH"

  git remote set-url origin "$GIT_URL"

  echo -e "\n✅ Nueva URL remota establecida:"
  git remote -v
}

fix_502() {
  print_banner
  printf "${WHITE} 💻 FIX 502-Bad Gateway...${GRAY_LIGHT}\n\n"

  sleep 2

  # Extraer puerto del archivo NGINX
  frontend_port=$(grep "proxy_pass http://127.0.0.1:" /etc/nginx/sites-available/"$empresa_atualizar"-frontend | sed -E 's/.*127\.0\.0\.1:([0-9]+).*/\1/')

  # Validar que se detectó un puerto
  if [[ -z "$frontend_port" ]]; then
    echo -e "${RED}❌ No se pudo detectar el puerto del frontend. Verifica el archivo NGINX.${GRAY_LIGHT}"
    return 1
  fi

  printf "\n${GREEN}✅ Puerto detectado automáticamente: ${frontend_port}${GRAY_LIGHT}\n"

  sudo su - deploy <<EOF
mkdir -p /home/deploy/${empresa_atualizar}/frontend
cat > /home/deploy/${empresa_atualizar}/frontend/server.js <<'EOL'
const express = require("express");
const path = require("path");
let compression;
try {
  compression = require("compression");
} catch (e) {}

const app = express();
if (compression) {
  app.use(compression());
}
app.use(
  express.static(path.join(__dirname, "build"), {
    maxAge: "7d",
    etag: true
  })
);

app.get("/*", function (req, res) {
  res.sendFile(path.join(__dirname, "build", "index.html"));
});

const PORT = process.env.PORT || ${frontend_port};
app.listen(PORT, () => {
  console.log("Frontend running on port " + PORT);
});
EOL
EOF

  sleep 2
}
