function build () {
  cd ..
  cd bia
  npm install
  echo "Iniciando o build ..."
  NODE_OPTIONS=--openssl-legacy-provider REACT_APP_API_URL=https://52.90.106.60 SKIP_PREFLIGHT_CHECK=true npm run build --prefix client
  echo "Build finalizado"
}

build

